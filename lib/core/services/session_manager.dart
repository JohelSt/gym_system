import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger_service.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final _supabase = Supabase.instance.client;
  Timer? _inactivityTimer;
  Timer? _sessionValidationTimer;
  int _timeoutMinutes = 15;
  String? _currentSessionId;
  RealtimeChannel? _profileSubscription;
  ValueChanged<String>? _onLogoutCallback;

  Future<void> startSession({
    required int rolId,
    required String sessionId,
    required ValueChanged<String> onLogout,
  }) async {
    stopSession();
    _currentSessionId = sessionId;
    _onLogoutCallback = onLogout;

    try {
      final config = await _supabase
          .from('configuracion_seguridad')
          .select('tiempo_inactividad_minutos')
          .eq('rol_id', rolId)
          .single();
      _timeoutMinutes = config['tiempo_inactividad_minutos'] ?? 15;
    } catch (e, stack) {
      await LoggerService.logError(
        e,
        stack,
        contexto: 'SessionManager.startSession',
      );
      debugPrint('No se pudo cargar la config, usando 15 min por defecto: $e');
    }

    _startInactivityTimer();
    _listenToSessionChanges();
    _startSessionValidationTimer();
  }

  void resetTimer() {
    if (_currentSessionId != null) {
      _startInactivityTimer();
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      unawaited(
        _cerrarSesion(motivo: 'Inactividad de $_timeoutMinutes minutos'),
      );
    });
  }

  void _listenToSessionChanges() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      _profileSubscription = _supabase
          .channel('public:perfiles:id=eq.$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'perfiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              final newSessionId = payload.newRecord['sesion_actual_id'];
              if (newSessionId != null && newSessionId != _currentSessionId) {
                unawaited(
                  _cerrarSesion(
                    motivo: 'Se inicio sesion en otro dispositivo',
                  ),
                );
              }
            },
          )
          .subscribe();
    } catch (e, stack) {
      unawaited(
        LoggerService.logError(
          e,
          stack,
          contexto: 'SessionManager._listenToSessionChanges',
        ),
      );
    }
  }

  void _startSessionValidationTimer() {
    _sessionValidationTimer?.cancel();
    _sessionValidationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_validateCurrentSession());
    });
  }

  Future<void> _validateCurrentSession() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _currentSessionId == null) {
      return;
    }

    try {
      final perfil = await _supabase
          .from('perfiles')
          .select('sesion_actual_id')
          .eq('id', userId)
          .maybeSingle();

      final latestSessionId = perfil?['sesion_actual_id']?.toString();
      if (latestSessionId != null && latestSessionId != _currentSessionId) {
        await _cerrarSesion(
          motivo: 'Se inicio sesion en otro dispositivo',
        );
      }
    } catch (e, stack) {
      await LoggerService.logError(
        e,
        stack,
        contexto: 'SessionManager._validateCurrentSession',
      );
    }
  }

  Future<void> _cerrarSesion({required String motivo}) async {
    try {
      _inactivityTimer?.cancel();
      _sessionValidationTimer?.cancel();
      await _profileSubscription?.unsubscribe();
      _currentSessionId = null;

      await LoggerService.logEvento(
        tipo: 'LOGOUT_AUTOMATICO',
        detalle: motivo,
      );

      await _supabase.auth.signOut();

      if (_onLogoutCallback != null) {
        _onLogoutCallback!(motivo);
      }
    } catch (e, stack) {
      await LoggerService.logError(
        e,
        stack,
        contexto: 'SessionManager._cerrarSesion',
      );
    }
  }

  void stopSession() {
    try {
      _inactivityTimer?.cancel();
      _sessionValidationTimer?.cancel();
      _profileSubscription?.unsubscribe();
      _currentSessionId = null;
    } catch (e, stack) {
      unawaited(
        LoggerService.logError(
          e,
          stack,
          contexto: 'SessionManager.stopSession',
        ),
      );
    }
  }
}

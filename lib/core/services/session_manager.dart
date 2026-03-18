import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart'; 

class SessionManager {
  // Singleton para tener una única instancia en toda la app
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final _supabase = Supabase.instance.client;
  
  Timer? _inactivityTimer;
  int _timeoutMinutes = 15; // Valor por defecto
  String? _currentSessionId;
  RealtimeChannel? _profileSubscription;
  VoidCallback? _onLogoutCallback;

  /// Inicia el control de la sesión (Llamar al hacer Login)
  Future<void> startSession({
    required int rolId,
    required String sessionId,
    required VoidCallback onLogout,
  }) async {
    _currentSessionId = sessionId;
    _onLogoutCallback = onLogout;

    // 1. Obtener el tiempo de inactividad configurado para este rol
    try {
      final config = await _supabase
          .from('configuracion_seguridad')
          .select('tiempo_inactividad_minutos')
          .eq('rol_id', rolId)
          .single();
      _timeoutMinutes = config['tiempo_inactividad_minutos'] ?? 15;
    } catch (e) {
      debugPrint('No se pudo cargar la config, usando 15 min por defecto: $e');
    }

    // 2. Iniciar el temporizador y escuchar cambios de sesión
    _startInactivityTimer();
    _listenToSessionChanges();
  }

  /// Reinicia el temporizador (Llamar cada vez que el usuario toca la pantalla)
  void resetTimer() {
    if (_currentSessionId != null) {
      _startInactivityTimer();
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      _cerrarSesion(motivo: 'Inactividad de $_timeoutMinutes minutos');
    });
  }

  /// Escucha en tiempo real si el `sesion_actual_id` cambia en la base de datos
  void _listenToSessionChanges() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

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
            // Si el ID en la BD es diferente al ID de este dispositivo...
            if (newSessionId != null && newSessionId != _currentSessionId) {
              _cerrarSesion(motivo: 'Se inició sesión en otro dispositivo');
            }
          },
        )
        .subscribe();
  }

  /// Ejecuta el cierre de sesión, limpia variables y redirige
  Future<void> _cerrarSesion({required String motivo}) async {
    _inactivityTimer?.cancel();
    await _profileSubscription?.unsubscribe();
    _currentSessionId = null;

    // Dejamos registro en auditoría
    await LoggerService.logEvento(
      tipo: 'LOGOUT_AUTOMATICO',
      detalle: motivo,
    );

    await _supabase.auth.signOut();
    
    // Ejecutamos el callback para llevar al usuario a la pantalla de Login
    if (_onLogoutCallback != null) {
      _onLogoutCallback!();
    }
  }

  /// Limpiar al hacer logout manual
  void stopSession() {
    _inactivityTimer?.cancel();
    _profileSubscription?.unsubscribe();
    _currentSessionId = null;
  }
}
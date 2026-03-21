import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import 'app_error_handler.dart';
import 'campanas_service.dart';
import 'logger_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const String _webVapidKey = String.fromEnvironment(
    'FCM_WEB_VAPID_KEY',
    defaultValue:
        'BKfQjBe2F-avYzfJtprJu1vq0j0eIj435GBtFhTwT6xZId1yaY6quZD7X-dKUrqi9stfV9XfcuGAcMd87h80zLs',
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _initialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }

    _initialized = true;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await LoggerService.logEvento(
          tipo: 'PUSH_PERMISO_DENEGADO',
          detalle: 'El usuario denego permisos de notificaciones push',
        );
      }

      await _registrarTokenActual();

      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        unawaited(_guardarToken(newToken));
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedAppMessage);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_handleOpenedAppMessage(initialMessage));
      }

      _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
        switch (state.event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            unawaited(_registrarTokenActual());
            break;
          case AuthChangeEvent.signedOut:
            unawaited(_desactivarTokensUsuario(state.session?.user.id));
            break;
          default:
            break;
        }
      });
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'NotificationService.initialize',
        showSnackBar: false,
      );
    }
  }

  Future<void> _registrarTokenActual() async {
    try {
      final token = kIsWeb
          ? await _messaging.getToken(
              vapidKey: _webVapidKey.isEmpty ? null : _webVapidKey,
            )
          : await _messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await _guardarToken(token);
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'NotificationService._registrarTokenActual',
        showSnackBar: false,
      );
    }
  }

  Future<void> _guardarToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _supabase.rpc(
        'register_device_push_token',
        params: {
          'p_token': token,
          'p_plataforma': _platformLabel(),
        },
      );

      await LoggerService.logEvento(
        tipo: 'PUSH_TOKEN_REGISTRADO',
        detalle: 'Se registro o actualizo un token push',
        metadata: {
          'usuario_id': user.id,
          'plataforma': _platformLabel(),
        },
      );
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'NotificationService._guardarToken',
        showSnackBar: false,
      );
    }
  }

  Future<void> _desactivarTokensUsuario(String? userId) async {
    final resolvedUserId = userId ?? _supabase.auth.currentUser?.id;
    if (resolvedUserId == null) {
      return;
    }

    try {
      await _supabase.rpc(
        'deactivate_device_push_tokens',
        params: {'p_usuario_id': resolvedUserId},
      );
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'NotificationService._desactivarTokensUsuario',
        showSnackBar: false,
      );
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final title =
        message.notification?.title ?? 'Nueva notificacion del sistema';
    final body = message.notification?.body ?? 'Tienes una novedad disponible.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        duration: const Duration(seconds: 5),
      ),
    );

    if (_isCampaignMessage(message)) {
      await CampanasService.mostrarBannerSiAplica(context);
    }
  }

  Future<void> _handleOpenedAppMessage(RemoteMessage message) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    if (_isCampaignMessage(message)) {
      await CampanasService.mostrarBannerSiAplica(context);
    }
  }

  bool _isCampaignMessage(RemoteMessage message) {
    final tipo = message.data['tipo']?.toString().toLowerCase();
    return tipo == 'campana' || tipo == 'campana_activa';
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:gym_system/ui/auth/welcome_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/app_error_handler.dart';
import 'core/services/notification_service.dart';
import 'core/services/session_manager.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'ui/auth/reset_password_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await runZonedGuarded<Future<void>>(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await Supabase.initialize(
      url: 'https://rrleqgebkktbsckxvgwk.supabase.co',
      anonKey: 'sb_publishable_wG4AyZvS5ZT75R_11_P7nA_EEBbotGw',
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.instance.initialize();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        AppErrorHandler.handle(
          details.exception,
          details.stack ?? StackTrace.current,
          context: 'Flutter Error (Global)',
          showSnackBar: false,
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        AppErrorHandler.handle(
          error,
          stack,
          context: 'PlatformDispatcher Error',
          showSnackBar: false,
        ),
      );
      return true;
    };

    runApp(const GymApp());
  }, (error, stack) {
    unawaited(
      AppErrorHandler.handle(
        error,
        stack,
        context: 'runZonedGuarded Error',
        showSnackBar: false,
      ),
    );
  });
}

class GymApp extends StatefulWidget {
  const GymApp({super.key});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _showingPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _abrirRecuperacionContrasena();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_esCallbackDeRecuperacion(Uri.base)) {
        _abrirRecuperacionContrasena();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _abrirRecuperacionContrasena() {
    if (_showingPasswordRecovery) {
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _showingPasswordRecovery = true;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      (route) => false,
    ).whenComplete(() {
      _showingPasswordRecovery = false;
    });
  }

  bool _esCallbackDeRecuperacion(Uri uri) {
    final queryType = uri.queryParameters['type']?.toLowerCase();
    if (queryType == 'recovery') {
      return true;
    }

    return uri.fragment.toLowerCase().contains('type=recovery');
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        SessionManager().resetTimer();
      },
      child: MaterialApp(
        title: 'Gym System',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: GymTheme.darkTheme,
        home: const WelcomeScreen(),
      ),
    );
  }
}

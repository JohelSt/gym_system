import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:gym_system/ui/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/app_error_handler.dart';
import 'core/services/notification_service.dart';
import 'core/services/session_manager.dart';
import 'core/theme.dart';
import 'firebase_options.dart';

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

class GymApp extends StatelessWidget {
  const GymApp({super.key});

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
        home: const LoginScreen(),
      ),
    );
  }
}

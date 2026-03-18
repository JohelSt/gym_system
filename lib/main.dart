import 'package:flutter/material.dart';
import 'package:gym_system/ui/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'core/services/logger_service.dart';
import 'core/services/session_manager.dart';

// Definimos una clave global para navegar sin necesidad de context en el Service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase
  await Supabase.initialize(
    url: 'https://rrleqgebkktbsckxvgwk.supabase.co',
    anonKey: 'sb_publishable_wG4AyZvS5ZT75R_11_P7nA_EEBbotGw',
  );

  // Captura errores de Flutter (UI) y los envía a tu tabla de logs_errores
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LoggerService.logError(details.exception, details.stack, contexto: "Flutter Error (Global)");
  };

  runApp(const GymApp());
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Este behavior es CRÍTICO: permite que el toque pase a los botones 
      // de abajo pero que el Listener también lo registre.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        // Reinicia el temporizador de inactividad con cada toque en la pantalla
        SessionManager().resetTimer();
      },
      child: MaterialApp(
        title: 'Gym System',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey, // Asignamos la clave global
        theme: GymTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
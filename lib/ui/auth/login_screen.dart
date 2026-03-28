import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/session_manager.dart';
import '../../core/theme.dart';
import '../../models/perfil_model.dart';
import '../admin/admin_home.dart';
import '../client/client_home.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message = widget.initialMessage;
      if (message == null || message.isEmpty || !mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: GymTheme.neonGreen,
        ),
      );
    });
  }

  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user == null) {
        throw const AuthException('No se pudo iniciar sesion.');
      }

      final data = await supabase
          .from('perfiles')
          .select()
          .eq('id', response.user!.id)
          .single();

      final perfil = Perfil.fromMap(data);

      if (!perfil.estado) {
        await LoggerService.logEvento(
          tipo: 'LOGIN_BLOQUEADO',
          detalle: 'Usuario intento ingresar pero su perfil esta inactivo',
          metadata: {
            'email': _emailController.text.trim(),
            'id': response.user!.id,
          },
        );

        await supabase.auth.signOut();
        throw const AuthException('Tu usuario esta inactivo. Contacta a IT.');
      }

      final nuevaSesionId = const Uuid().v4();

      await supabase
          .from('perfiles')
          .update({'sesion_actual_id': nuevaSesionId})
          .eq('id', response.user!.id);

      await LoggerService.logEvento(
        tipo: 'LOGIN_EXITOSO',
        detalle: 'Usuario ingreso al sistema',
        metadata: {
          'rol_id': perfil.rolId,
          'email': response.user!.email,
          'sesion_id': nuevaSesionId,
        },
      );

      if (!mounted) {
        return;
      }

      await SessionManager().startSession(
        rolId: perfil.rolId,
        sessionId: nuevaSesionId,
        onLogout: (motivo) {
          if (!mounted) {
            return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
          _showSnackBar(
            motivo,
            color: Colors.orange,
          );
        },
      );

      if (!mounted) {
        return;
      }

      if (perfil.rolId == 4) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientHome()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHome()),
        );
      }
    } on AuthException catch (e) {
      await LoggerService.logEvento(
        tipo: 'LOGIN_FALLIDO',
        detalle: 'Fallo en autenticacion: ${e.message}',
        metadata: {'email': _emailController.text.trim()},
      );
      _showSnackBar(e.message);
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'LoginScreen._iniciarSesion',
        uiContext: context,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String msg, {Color color = Colors.redAccent}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: GymTheme.darkGray,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: GymTheme.neonGreen,
                ),
                const SizedBox(height: 16),
                const Text(
                  'GYM SYSTEM',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: GymTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Correo Electronico',
                    labelStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.email, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena',
                    labelStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.lock, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _iniciarSesion,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: GymTheme.black,
                          )
                        : const Text(
                            'INGRESAR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                  child: const Text('Olvidaste tu contrasena?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

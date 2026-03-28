import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviarCorreoRecuperacion() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un correo valido.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final redirectTo = kIsWeb ? '${Uri.base.origin}/reset-password' : null;

      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se envio un enlace de recuperacion. Revisa tu correo.',
          ),
          backgroundColor: GymTheme.neonGreen,
        ),
      );

      Navigator.of(context).pop();
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'ForgotPasswordScreen._enviarCorreoRecuperacion',
        uiContext: context,
        fallbackMessage: 'No se pudo enviar el enlace de recuperacion.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('RECUPERAR CONTRASENA'),
        backgroundColor: GymTheme.black,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GymTheme.darkGray,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recupera tu acceso',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ingresa tu correo y te enviaremos un enlace para cambiar la contrasena.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Correo electronico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _enviarCorreoRecuperacion,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ENVIAR ENLACE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

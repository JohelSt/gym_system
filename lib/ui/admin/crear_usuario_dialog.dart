import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';

class CrearUsuarioDialog extends StatefulWidget {
  const CrearUsuarioDialog({super.key});

  @override
  State<CrearUsuarioDialog> createState() => _CrearUsuarioDialogState();
}

class _CrearUsuarioDialogState extends State<CrearUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _cedulaCtrl = TextEditingController();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _rolCtrl = TextEditingController(text: 'Cliente');
  final TextEditingController _estadoCtrl = TextEditingController(text: 'Activo');
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      var rolId = 4;
      final rolInput = _rolCtrl.text.trim().toLowerCase();
      if (rolInput == 'administrador') rolId = 2;
      if (rolInput == 'gerente') rolId = 1;
      if (rolInput == 'it') rolId = 3;

      final estadoBool = _estadoCtrl.text.trim().toLowerCase() == 'activo';

      await supabase.rpc(
        'crear_usuario_admin',
        params: {
          'p_email': _emailCtrl.text.trim(),
          'p_password': _passwordCtrl.text.trim(),
          'p_cedula': _cedulaCtrl.text.trim(),
          'p_nombre_completo': _nombreCtrl.text.trim(),
          'p_telefono': _telefonoCtrl.text.trim(),
          'p_direccion': _direccionCtrl.text.trim(),
          'p_rol_id': rolId,
          'p_estado': estadoBool,
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario creado correctamente'),
          backgroundColor: GymTheme.neonGreen,
        ),
      );
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CrearUsuarioDialog._guardarUsuario',
        uiContext: context,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _rolCtrl.dispose();
    _estadoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GymTheme.darkGray,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text(
        'NUEVO REGISTRO DE USUARIO',
        style: TextStyle(
          color: GymTheme.neonGreen,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(
                  _emailCtrl,
                  'Correo Electronico',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildField(_cedulaCtrl, 'Cedula / ID', Icons.badge),
                const SizedBox(height: 16),
                _buildField(
                  _nombreCtrl,
                  'Nombre Completo',
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildField(
                  _telefonoCtrl,
                  'Numero de Telefono',
                  Icons.phone_android,
                ),
                const SizedBox(height: 16),
                _buildField(
                  _direccionCtrl,
                  'Direccion de Habitacion',
                  Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildField(
                  _rolCtrl,
                  'Rol (Cliente, Administrador, Gerente)',
                  Icons.settings_accessibility,
                ),
                const SizedBox(height: 16),
                _buildField(
                  _estadoCtrl,
                  'Estado (Activo / Inactivo)',
                  Icons.toggle_on_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCELAR',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _guardarUsuario,
          style: ElevatedButton.styleFrom(
            backgroundColor: GymTheme.neonGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text('GUARDAR USUARIO'),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: GymTheme.neonGreen, size: 20),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF121212),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[850]!),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: GymTheme.neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo es obligatorio';
        }
        if (controller == _emailCtrl) {
          final email = value.trim();
          if (!email.contains('@') || !email.contains('.')) {
            return 'Ingresa un correo valido';
          }
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Contrasena Temporal',
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: GymTheme.neonGreen,
          size: 20,
        ),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white54,
          ),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF121212),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[850]!),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: GymTheme.neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo es obligatorio';
        }
        if (value.trim().length < 6) {
          return 'La contrasena debe tener al menos 6 caracteres';
        }
        return null;
      },
    );
  }
}

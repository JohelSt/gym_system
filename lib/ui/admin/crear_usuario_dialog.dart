import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class CrearUsuarioDialog extends StatefulWidget {
  const CrearUsuarioDialog({super.key});

  @override
  State<CrearUsuarioDialog> createState() => _CrearUsuarioDialogState();
}

class _CrearUsuarioDialogState extends State<CrearUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para capturar la información
  final TextEditingController _cedulaCtrl = TextEditingController();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _rolCtrl = TextEditingController(text: 'Cliente');
  final TextEditingController _estadoCtrl = TextEditingController(text: 'Activo');

  bool _isLoading = false;

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Mapeo simple de roles (Ajusta los IDs según tu base de datos)
      int rolId = 4; // Default: Cliente
      String rolInput = _rolCtrl.text.trim().toLowerCase();
      if (rolInput == 'administrador') rolId = 2;
      if (rolInput == 'gerente') rolId = 1;
      if (rolInput == 'it') rolId = 3;

      // Mapeo de estado
      bool estadoBool = _estadoCtrl.text.trim().toLowerCase() == 'activo';

      // Inserción en la tabla 'perfiles'
      await supabase.from('perfiles').insert({
        'cedula': _cedulaCtrl.text.trim(),
        'nombre_completo': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'rol_id': rolId,
        'estado': estadoBool,
      });

      if (mounted) {
        Navigator.of(context).pop(true); // Cierra y avisa a la tabla que debe refrescar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario creado correctamente'),
            backgroundColor: GymTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error en insert: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          letterSpacing: 1.2
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
                _buildField(_cedulaCtrl, 'Cédula / ID', Icons.badge),
                const SizedBox(height: 16),
                _buildField(_nombreCtrl, 'Nombre Completo', Icons.person_outline),
                const SizedBox(height: 16),
                _buildField(_telefonoCtrl, 'Número de Teléfono', Icons.phone_android),
                const SizedBox(height: 16),
                _buildField(_direccionCtrl, 'Dirección de Habitación', Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 16),
                _buildField(_rolCtrl, 'Rol (Cliente, Administrador, Gerente)', Icons.settings_accessibility),
                const SizedBox(height: 16),
                _buildField(_estadoCtrl, 'Estado (Activo / Inactivo)', Icons.toggle_on_outlined),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _guardarUsuario,
          style: ElevatedButton.styleFrom(
            backgroundColor: GymTheme.neonGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            // Corrección del error anterior: fontWeight dentro de textStyle
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Text('GUARDAR USUARIO'),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: GymTheme.neonGreen, size: 20),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF121212),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
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
      validator: (value) => value == null || value.isEmpty ? 'Este campo es obligatorio' : null,
    );
  }
}
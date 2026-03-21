import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme.dart';

class EditarUsuarioDialog extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditarUsuarioDialog({super.key, required this.userData});

  @override
  State<EditarUsuarioDialog> createState() => _EditarUsuarioDialogState();
}

class _EditarUsuarioDialogState extends State<EditarUsuarioDialog> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _direccionCtrl;
  bool _esActivo = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.userData['nombre_completo']?.toString() ??
          widget.userData['nombre']?.toString() ??
          '',
    );
    _telefonoCtrl = TextEditingController(
      text: widget.userData['telefono']?.toString() ?? '',
    );
    _direccionCtrl = TextEditingController(
      text: widget.userData['direccion']?.toString() ?? '',
    );
    _esActivo = widget.userData['estado'] == true;
  }

  Future<void> _actualizarUsuario() async {
    setState(() => _isLoading = true);

    final payload = {
      'nombre_completo': _nombreCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'estado': _esActivo,
    };

    try {
      await Supabase.instance.client
          .from('perfiles')
          .update(payload)
          .eq('cedula', widget.userData['cedula']);

      await LoggerService.logEvento(
        tipo: 'CAMBIO_USUARIO',
        detalle: 'Se actualizaron los datos del usuario: ${_nombreCtrl.text}',
        metadata: {
          'cedula': widget.userData['cedula'],
          'cambios': payload,
          'editado_por': Supabase.instance.client.auth.currentUser?.email,
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'EditarUsuarioDialog._actualizarUsuario',
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
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'EDITAR: ${widget.userData['cedula']}',
        style: const TextStyle(
          color: GymTheme.neonGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(_nombreCtrl, 'Nombre Completo'),
            _buildTextField(_telefonoCtrl, 'Telefono'),
            _buildTextField(_direccionCtrl, 'Direccion'),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text(
                'Estado Activo',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                _esActivo ? 'Usuario puede ingresar' : 'Acceso restringido',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              value: _esActivo,
              activeColor: GymTheme.neonGreen,
              onChanged: (val) => setState(() => _esActivo = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCELAR',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _actualizarUsuario,
          style: ElevatedButton.styleFrom(
            backgroundColor: GymTheme.neonGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'GUARDAR',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: GymTheme.neonGreen,
            fontSize: 14,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: GymTheme.neonGreen),
          ),
        ),
      ),
    );
  }
}

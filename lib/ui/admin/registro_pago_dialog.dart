import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme.dart';

class RegistroPagoDialog extends StatefulWidget {
  final Map<String, dynamic> cliente;
  final double precioMensualSugerido;

  const RegistroPagoDialog({
    super.key,
    required this.cliente,
    required this.precioMensualSugerido,
  });

  @override
  State<RegistroPagoDialog> createState() => _RegistroPagoDialogState();
}

class _RegistroPagoDialogState extends State<RegistroPagoDialog> {
  bool _isLoading = false;
  String _metodoPago = 'Efectivo';
  bool _esPrecioRegular = true;
  String _motivoDescuento = 'Descuento aprobado por el gerente';
  bool _actualizarFechaHoy = false;
  int _mesesAPagar = 1;
  final TextEditingController _montoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _actualizarMontoTotal();
  }

  void _actualizarMontoTotal() {
    if (_esPrecioRegular) {
      _montoCtrl.text =
          (widget.precioMensualSugerido * _mesesAPagar).toStringAsFixed(0);
    }
  }

  DateTime _resolverFechaBasePago(DateTime hoy) {
    if (_actualizarFechaHoy || widget.cliente['fecha_proximo_cobro'] == null) {
      return DateTime(hoy.year, hoy.month, hoy.day);
    }

    final fechaRegistrada = DateTime.tryParse(
      widget.cliente['fecha_proximo_cobro']?.toString() ?? '',
    );

    if (fechaRegistrada == null) {
      return DateTime(hoy.year, hoy.month, hoy.day);
    }

    return DateTime(
      fechaRegistrada.year,
      fechaRegistrada.month,
      fechaRegistrada.day,
    );
  }

  String _resolverEstadoMembresia(DateTime nuevaFecha, DateTime hoy) {
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final nuevaFechaSinHora = DateTime(
      nuevaFecha.year,
      nuevaFecha.month,
      nuevaFecha.day,
    );

    if (nuevaFechaSinHora.isAfter(hoySinHora) ||
        nuevaFechaSinHora.isAtSameMomentAs(hoySinHora)) {
      return 'Sin pendientes';
    }

    return 'Pago pendiente';
  }

  Future<void> _confirmarPago() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final montoFinal = double.parse(_montoCtrl.text.trim());
      final hoy = DateTime.now();
      final fechaBase = _resolverFechaBasePago(hoy);
      final nuevaFecha = fechaBase.add(Duration(days: 30 * _mesesAPagar));
      final nuevoEstado = _resolverEstadoMembresia(nuevaFecha, hoy);

      await supabase.from('historial_membresia').insert({
        'cedula_cliente': widget.cliente['cedula'],
        'tipo_evento': 'PAGO',
        'monto': montoFinal,
        'metodo_pago': _metodoPago,
        'motivo_descuento': _esPrecioRegular ? null : _motivoDescuento,
        'detalle':
            'Pago de $_mesesAPagar mes(es) por adelantado - $_metodoPago',
      });

      await LoggerService.logEvento(
        tipo: 'PAGO_REGISTRADO',
        detalle: 'Pago recibido de ${widget.cliente['nombre_completo']}',
        metadata: {
          'monto': montoFinal,
          'meses': _mesesAPagar,
          'cliente_cedula': widget.cliente['cedula'],
        },
      );

      await supabase.from('perfiles').update({
        'estado_membresia': nuevoEstado,
        'fecha_proximo_cobro': nuevaFecha.toIso8601String().split('T')[0],
      }).eq('cedula', widget.cliente['cedula']);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'RegistroPagoDialog._confirmarPago',
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
    _montoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        'PAGO: ${widget.cliente['nombre_completo']}',
        style: const TextStyle(color: GymTheme.neonGreen),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CANTIDAD DE MESES',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _botonMeses(Icons.remove, () {
                  if (_mesesAPagar > 1) {
                    setState(() {
                      _mesesAPagar--;
                      _actualizarMontoTotal();
                    });
                  }
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$_mesesAPagar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _botonMeses(Icons.add, () {
                  if (_mesesAPagar < 12) {
                    setState(() {
                      _mesesAPagar++;
                      _actualizarMontoTotal();
                    });
                  }
                }),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'METODO',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _optionChip('Efectivo'),
                const SizedBox(width: 10),
                _optionChip('SINPE'),
              ],
            ),
            const Divider(color: Colors.white10, height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Precio Regular',
                  style: TextStyle(color: Colors.white),
                ),
                Switch(
                  value: _esPrecioRegular,
                  activeColor: GymTheme.neonGreen,
                  onChanged: (val) => setState(() {
                    _esPrecioRegular = val;
                    _actualizarMontoTotal();
                  }),
                ),
              ],
            ),
            TextField(
              controller: _montoCtrl,
              enabled: !_esPrecioRegular,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: _esPrecioRegular ? GymTheme.neonGreen : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                prefixText: 'CRC ',
                border: InputBorder.none,
              ),
            ),
            const Divider(color: Colors.white10, height: 30),
            CheckboxListTile(
              title: const Text(
                'Resetear ciclo de cobro a hoy',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              value: _actualizarFechaHoy,
              activeColor: GymTheme.neonGreen,
              onChanged: (val) => setState(() => _actualizarFechaHoy = val!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCELAR',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: GymTheme.neonGreen),
          onPressed: _isLoading ? null : _confirmarPago,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'CONFIRMAR PAGO',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _botonMeses(IconData icono, VoidCallback accion) {
    return IconButton(
      onPressed: accion,
      icon: Icon(icono, color: GymTheme.neonGreen),
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(backgroundColor: Colors.white10),
    );
  }

  Widget _optionChip(String label) {
    final isSelected = _metodoPago == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _metodoPago = label),
      selectedColor: GymTheme.neonGreen,
      labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
      backgroundColor: Colors.white10,
    );
  }
}

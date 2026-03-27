import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/email_notification_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme.dart';
import 'registro_pago_dialog.dart';

class PagosAdminScreen extends StatefulWidget {
  const PagosAdminScreen({super.key});

  @override
  State<PagosAdminScreen> createState() => _PagosAdminScreenState();
}

class _PagosAdminScreenState extends State<PagosAdminScreen> {
  bool _isLoading = true;
  double _precioMensual = 0;
  double _precioSemanal = 0;
  double _precioDiario = 0;
  List<Map<String, dynamic>> _clientesOriginales = [];
  List<Map<String, dynamic>> _clientesFiltrados = [];
  final TextEditingController _nombreCtrl = TextEditingController();
  String _estadoSeleccionado = 'Todos';
  DateTime? _fechaFiltro;
  String? _sendingReminderForClientId;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final preciosData = await supabase
          .from('configuracion_precios')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (preciosData != null) {
        _precioMensual = (preciosData['precio_mensual'] as num).toDouble();
        _precioSemanal = (preciosData['precio_semanal'] as num).toDouble();
        _precioDiario = (preciosData['precio_diario'] as num).toDouble();
      }

      final data = await supabase
          .from('perfiles')
          .select('*, roles(nombre)')
          .order('nombre_completo', ascending: true);

      final soloClientes = (data as List<dynamic>)
          .where((user) {
            final rol = user['roles'] != null
                ? user['roles']['nombre'].toString().toLowerCase()
                : '';
            return rol == 'cliente';
          })
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _clientesOriginales = soloClientes;
        _clientesFiltrados = soloClientes;
        _isLoading = false;
      });
      _aplicarFiltros();
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await _handleError(e, stack, 'PagosAdminScreen._cargarDatos');
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _clientesFiltrados = _clientesOriginales.where((cliente) {
        final nombre = (cliente['nombre_completo'] ?? '')
            .toString()
            .toLowerCase();
        final estado = cliente['estado_membresia'] ?? 'Sin pendientes';
        final fechaVence = cliente['fecha_proximo_cobro'];

        final matchNombre = nombre.contains(_nombreCtrl.text.toLowerCase());
        final matchEstado =
            _estadoSeleccionado == 'Todos' || estado == _estadoSeleccionado;
        var matchFecha = true;

        if (_fechaFiltro != null && fechaVence != null) {
          final fechaParsed = DateTime.parse(fechaVence);
          matchFecha = fechaParsed.year == _fechaFiltro!.year &&
              fechaParsed.month == _fechaFiltro!.month &&
              fechaParsed.day == _fechaFiltro!.day;
        }

        return matchNombre && matchEstado && matchFecha;
      }).toList();
    });
  }

  void _limpiarFiltros() {
    _nombreCtrl.clear();
    setState(() {
      _estadoSeleccionado = 'Todos';
      _fechaFiltro = null;
      _clientesFiltrados = _clientesOriginales;
    });
  }

  Future<void> _cambiarEstadoPausa(Map<String, dynamic> cliente) async {
    final estaPausado = cliente['estado_membresia'] == 'Membresia pausada';
    final nuevoEstado = estaPausado ? 'Sin pendientes' : 'Membresia pausada';

    try {
      await Supabase.instance.client.from('historial_membresia').insert({
        'cedula_cliente': cliente['cedula'],
        'tipo_evento': estaPausado ? 'REANUDACION' : 'PAUSA',
        'detalle': estaPausado
            ? 'Membresia reanudada'
            : 'Membresia pausada por administracion',
      });

      await Supabase.instance.client
          .from('perfiles')
          .update({'estado_membresia': nuevoEstado})
          .eq('cedula', cliente['cedula']);

      await LoggerService.logEvento(
        tipo: 'MEMBRESIA_ESTADO_CAMBIO',
        detalle:
            '${estaPausado ? "Reanudacion" : "Pausa"} de membresia para ${cliente['nombre_completo']}',
        metadata: {
          'cedula': cliente['cedula'],
          'nuevo_estado': nuevoEstado,
          'ejecutado_por': Supabase.instance.client.auth.currentUser?.email,
        },
      );

      _cargarDatos();
      _showSnackBar(
        estaPausado ? 'Membresia Reanudada' : 'Membresia Pausada',
      );
    } catch (e, stack) {
      await _handleError(e, stack, 'PagosAdminScreen._cambiarEstadoPausa');
    }
  }

  Future<void> _cambiarEstadoCancelacion(Map<String, dynamic> cliente) async {
    final estaCancelado = cliente['estado_membresia'] == 'Membresia cancelada';
    final nuevoEstado = estaCancelado ? 'Sin pendientes' : 'Membresia cancelada';

    try {
      await Supabase.instance.client.from('historial_membresia').insert({
        'cedula_cliente': cliente['cedula'],
        'tipo_evento': estaCancelado ? 'REACTIVACION' : 'CANCELACION',
        'detalle': estaCancelado
            ? 'Cuenta reactivada'
            : 'Cuenta cancelada por administracion',
      });

      await Supabase.instance.client
          .from('perfiles')
          .update({'estado_membresia': nuevoEstado})
          .eq('cedula', cliente['cedula']);

      await LoggerService.logEvento(
        tipo: 'MEMBRESIA_ESTADO_CAMBIO',
        detalle:
            '${estaCancelado ? "Reactivacion" : "Cancelacion"} de membresia para ${cliente['nombre_completo']}',
        metadata: {'cedula': cliente['cedula'], 'nuevo_estado': nuevoEstado},
      );

      _cargarDatos();
      _showSnackBar(
        estaCancelado ? 'Membresia Reactivada' : 'Membresia Cancelada',
      );
    } catch (e, stack) {
      await _handleError(
        e,
        stack,
        'PagosAdminScreen._cambiarEstadoCancelacion',
      );
    }
  }

  Future<void> _enviarRecordatorioCorreo(Map<String, dynamic> cliente) async {
    final clienteId = cliente['id']?.toString();
    if (clienteId == null || clienteId.isEmpty) {
      _showSnackBar('No se pudo identificar al cliente.', isError: true);
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: const Text(
          'ENVIAR RECORDATORIO',
          style: TextStyle(color: GymTheme.neonGreen),
        ),
        content: Text(
          'Se enviara un correo de pago vencido a ${cliente['nombre_completo'] ?? 'este cliente'}. Deseas continuar?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ENVIAR'),
          ),
        ],
      ),
    );

    if (confirmado != true) {
      return;
    }

    setState(() => _sendingReminderForClientId = clienteId);
    try {
      await EmailNotificationService.enviarRecordatorioPagoVencido(
        clienteId: clienteId,
      );
      await LoggerService.logEvento(
        tipo: 'RECORDATORIO_PAGO_VENCIDO_EMAIL',
        detalle:
            'Se envio un recordatorio de pago vencido por correo a ${cliente['nombre_completo']}',
        metadata: {
          'cliente_id': clienteId,
          'cedula': cliente['cedula'],
        },
      );
      _showSnackBar('Correo de recordatorio enviado');
    } catch (e, stack) {
      await _handleError(
        e,
        stack,
        'PagosAdminScreen._enviarRecordatorioCorreo',
      );
    } finally {
      if (mounted) {
        setState(() => _sendingReminderForClientId = null);
      }
    }
  }

  void _editarPrecioGlobal(String titulo, String columna, double actual) {
    final c = TextEditingController(text: actual.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: Text(
          'EDITAR PRECIO $titulo',
          style: const TextStyle(color: GymTheme.neonGreen),
        ),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Monto en CRC',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final montoNuevo = double.parse(c.text.trim());
                await LoggerService.logEvento(
                  tipo: 'CAMBIO_PRECIO',
                  detalle: 'Se cambio el precio de $titulo',
                  metadata: {
                    'columna': columna,
                    'monto_nuevo': montoNuevo,
                    'monto_anterior': actual,
                  },
                );

                await Supabase.instance.client
                    .from('configuracion_precios')
                    .update({columna: montoNuevo})
                    .eq('id', 1);

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _cargarDatos();
              } catch (e, stack) {
                await _handleError(
                  e,
                  stack,
                  'PagosAdminScreen._editarPrecioGlobal',
                );
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleError(
    dynamic error,
    StackTrace stack,
    String contextLabel,
  ) async {
    await AppErrorHandler.handle(
      error,
      stack,
      context: contextLabel,
      uiContext: context,
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : GymTheme.neonGreen,
      ),
    );
  }

  Widget _buildSeccionFiltros() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILTRAR POR:',
            style: TextStyle(
              color: GymTheme.neonGreen,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _nombreCtrl,
                  onChanged: (_) => _aplicarFiltros(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Nombre...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white24,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: Colors.black,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _estadoSeleccionado,
                      dropdownColor: GymTheme.darkGray,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      isExpanded: true,
                      onChanged: (val) {
                        setState(() => _estadoSeleccionado = val!);
                        _aplicarFiltros();
                      },
                      items: [
                        'Todos',
                        'Sin pendientes',
                        'Pago pendiente',
                        'Membresia cancelada',
                        'Membresia pausada',
                      ]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: GymTheme.neonGreen,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => _fechaFiltro = picked);
                      _aplicarFiltros();
                    }
                  },
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: _fechaFiltro == null
                          ? Colors.white24
                          : GymTheme.neonGreen,
                      size: 18,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _limpiarFiltros,
                icon: const Icon(
                  Icons.filter_alt_off,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ],
          ),
          if (_fechaFiltro != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Filtrando fecha: ${DateFormat('dd/MM/yyyy').format(_fechaFiltro!)}',
                style: const TextStyle(
                  color: GymTheme.neonGreen,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(String label, double precio, String columna) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _editarPrecioGlobal(label, columna, precio),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              Text(
                'CRC ${precio.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: GymTheme.neonGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    if (estado == 'Sin pendientes') return GymTheme.neonGreen;
    if (estado == 'Pago pendiente') return Colors.orangeAccent;
    if (estado == 'Membresia cancelada') return Colors.redAccent;
    return Colors.blueGrey;
  }

  bool _puedeEnviarRecordatorio(Map<String, dynamic> cliente) {
    final estado = (cliente['estado_membresia'] ?? '').toString();
    if (estado == 'Pago pendiente') {
      return true;
    }

    final fecha = DateTime.tryParse(
      cliente['fecha_proximo_cobro']?.toString() ?? '',
    );
    if (fecha == null) {
      return false;
    }

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);
    return fechaSinHora.isBefore(hoySinHora);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('GESTION DE PAGOS'),
        backgroundColor: GymTheme.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GymTheme.neonGreen),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildPriceCard('MENSUAL', _precioMensual, 'precio_mensual'),
                      const SizedBox(width: 8),
                      _buildPriceCard('SEMANAL', _precioSemanal, 'precio_semanal'),
                      const SizedBox(width: 8),
                      _buildPriceCard('DIARIO', _precioDiario, 'precio_diario'),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildSeccionFiltros(),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DataTable2(
                        columnSpacing: 12,
                        minWidth: 900,
                        headingTextStyle: const TextStyle(
                          color: GymTheme.neonGreen,
                          fontWeight: FontWeight.bold,
                        ),
                        columns: const [
                          DataColumn2(label: Text('CLIENTE'), size: ColumnSize.L),
                          DataColumn2(label: Text('ESTADO'), size: ColumnSize.M),
                          DataColumn2(label: Text('VENCE'), size: ColumnSize.M),
                          DataColumn2(label: Text('ACCIONES'), size: ColumnSize.L),
                        ],
                        rows: _clientesFiltrados.map((cliente) {
                          final estado =
                              cliente['estado_membresia'] ?? 'Sin pendientes';
                          final estaPausado = estado == 'Membresia pausada';
                          final estaCancelado = estado == 'Membresia cancelada';
                          final puedeEnviarRecordatorio =
                              _puedeEnviarRecordatorio(cliente);
                          final estaEnviando =
                              _sendingReminderForClientId ==
                              cliente['id']?.toString();

                          return DataRow2(
                            cells: [
                              DataCell(
                                Text(
                                  cliente['nombre_completo'] ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              DataCell(
                                Text(
                                  estado,
                                  style: TextStyle(
                                    color: _colorEstado(estado),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  cliente['fecha_proximo_cobro'] ?? 'S/N',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.payments_outlined,
                                        color: GymTheme.neonGreen,
                                      ),
                                      onPressed: () async {
                                        final res = await showDialog(
                                          context: context,
                                          builder: (c) => RegistroPagoDialog(
                                            cliente: cliente,
                                            precioMensualSugerido: _precioMensual,
                                          ),
                                        );
                                        if (res == true) {
                                          _cargarDatos();
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: puedeEnviarRecordatorio
                                          ? 'Enviar recordatorio por correo'
                                          : 'Disponible solo para pagos vencidos',
                                      icon: estaEnviando
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.lightBlueAccent,
                                              ),
                                            )
                                          : Icon(
                                              Icons.email_outlined,
                                              color: puedeEnviarRecordatorio
                                                  ? Colors.lightBlueAccent
                                                  : Colors.white24,
                                            ),
                                      onPressed: !puedeEnviarRecordatorio || estaEnviando
                                          ? null
                                          : () => _enviarRecordatorioCorreo(
                                                cliente,
                                              ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        estaPausado
                                            ? Icons.play_circle
                                            : Icons.pause_circle,
                                        color: Colors.blueAccent,
                                      ),
                                      onPressed: () =>
                                          _cambiarEstadoPausa(cliente),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        estaCancelado
                                            ? Icons.settings_backup_restore
                                            : Icons.cancel,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _cambiarEstadoCancelacion(cliente),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

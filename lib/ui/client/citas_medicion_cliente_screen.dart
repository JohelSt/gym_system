import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';

class CitasMedicionClienteScreen extends StatefulWidget {
  const CitasMedicionClienteScreen({super.key});

  @override
  State<CitasMedicionClienteScreen> createState() =>
      _CitasMedicionClienteScreenState();
}

class _CitasMedicionClienteScreenState
    extends State<CitasMedicionClienteScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _pendientes = [];

  @override
  void initState() {
    super.initState();
    _cargarCitas();
  }

  Future<void> _cargarCitas() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AuthException('La sesion no esta disponible.');
      }

      final data = await _supabase
          .from('citas_medicion')
          .select()
          .eq('persona_asignada_id', user.id)
          .order('fecha', ascending: false)
          .order('hora_inicio', ascending: true);

      final citas = List<Map<String, dynamic>>.from(data);
      final hoy = DateTime.now();
      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);

      final pendientes = citas.where((cita) {
        final estado = (cita['estado'] ?? 'Programada').toString();
        if (estado != 'Programada') {
          return false;
        }
        final fecha = DateTime.tryParse(cita['fecha']?.toString() ?? '');
        if (fecha == null) {
          return false;
        }
        return !fecha.isBefore(hoySinHora);
      }).toList()
        ..sort((a, b) {
          final fechaA = DateTime.tryParse(a['fecha']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final fechaB = DateTime.tryParse(b['fecha']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final byDate = fechaA.compareTo(fechaB);
          if (byDate != 0) {
            return byDate;
          }
          return (a['hora_inicio']?.toString() ?? '')
              .compareTo(b['hora_inicio']?.toString() ?? '');
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _citas = citas;
        _pendientes = pendientes;
        _isLoading = false;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CitasMedicionClienteScreen._cargarCitas',
        uiContext: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('CITAS DE MEDICION'),
        backgroundColor: GymTheme.black,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargarCitas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GymTheme.neonGreen),
            )
          : RefreshIndicator(
              color: GymTheme.neonGreen,
              onRefresh: _cargarCitas,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPendingBanner(),
                  const SizedBox(height: 20),
                  if (_citas.isEmpty)
                    _buildEmptyState()
                  else ...[
                    const Text(
                      'HISTORIAL DE CITAS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._citas.map(_buildAppointmentCard),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPendingBanner() {
    if (_pendientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: GymTheme.darkGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado actual',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            SizedBox(height: 8),
            Text(
              'No tienes citas pendientes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final proxima = _pendientes.first;
    final fecha = DateTime.tryParse(proxima['fecha']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.lightBlueAccent.withOpacity(0.18),
            GymTheme.darkGray,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.35)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pendientes.length == 1
                    ? 'Tienes 1 cita pendiente'
                    : 'Tienes ${_pendientes.length} citas pendientes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fecha == null
                    ? 'La proxima cita no tiene fecha valida'
                    : 'Proxima cita: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                '${proxima['hora_inicio']} - ${proxima['hora_fin']}',
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Chip(
            label: const Text('Pendiente'),
            backgroundColor: Colors.lightBlueAccent.withOpacity(0.16),
            labelStyle: const TextStyle(
              color: Colors.lightBlueAccent,
              fontWeight: FontWeight.bold,
            ),
            side: BorderSide(color: Colors.lightBlueAccent.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_busy_outlined, color: Colors.white38, size: 52),
          SizedBox(height: 12),
          Text(
            'No hay citas registradas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Cuando se te asigne una cita de medicion aparecera aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> cita) {
    final estado = (cita['estado'] ?? 'Programada').toString();
    final color = _statusColor(estado);
    final fecha = DateTime.tryParse(cita['fecha']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fecha == null
                        ? 'Fecha no disponible'
                        : DateFormat('dd/MM/yyyy').format(fecha),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${cita['hora_inicio']} - ${cita['hora_fin']}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Chip(
                label: Text(estado),
                backgroundColor: color.withOpacity(0.14),
                labelStyle: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                side: BorderSide(color: color.withOpacity(0.3)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDetailRow('Notas', cita['notas']?.toString() ?? 'Sin notas registradas'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: GymTheme.neonGreen,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Color _statusColor(String estado) {
    switch (estado) {
      case 'Completada':
        return GymTheme.neonGreen;
      case 'Cancelada':
        return Colors.redAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }
}

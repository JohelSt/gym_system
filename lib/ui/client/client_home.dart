import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/campanas_service.dart';
import '../../core/services/session_manager.dart';
import '../../core/theme.dart';
import '../auth/login_screen.dart';
import 'citas_medicion_cliente_screen.dart';
import 'historial_pagos_cliente_screen.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _perfil;
  int _totalPagos = 0;
  int _totalCitas = 0;
  Map<String, dynamic>? _proximaCita;
  Map<String, dynamic>? _campanaActiva;

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        CampanasService.mostrarBannerSiAplica(context);
      }
    });
  }

  Future<void> _cargarDashboard() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AuthException('La sesion no esta disponible.');
      }

      final perfil = await _supabase
          .from('perfiles')
          .select('id, cedula, nombre_completo, estado_membresia, fecha_proximo_cobro')
          .eq('id', user.id)
          .single();

      final cedula = perfil['cedula']?.toString();

      var totalPagos = 0;
      if (cedula != null && cedula.isNotEmpty) {
        final pagos = await _supabase
            .from('historial_membresia')
            .select('id')
            .eq('cedula_cliente', cedula)
            .eq('tipo_evento', 'PAGO');
        totalPagos = (pagos as List<dynamic>).length;
      }

      final citas = await _supabase
          .from('citas_medicion')
          .select('id, fecha, hora_inicio, hora_fin, estado, notas')
          .eq('persona_asignada_id', user.id)
          .order('fecha', ascending: true)
          .order('hora_inicio', ascending: true);

      final campanaActiva = await CampanasService.obtenerCampanaPrincipal();

      final citasList = List<Map<String, dynamic>>.from(citas);
      final hoy = DateTime.now();
      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      Map<String, dynamic>? proximaCita;

      for (final cita in citasList) {
        if ((cita['estado'] ?? 'Programada') != 'Programada') {
          continue;
        }
        final fecha = DateTime.tryParse(cita['fecha']?.toString() ?? '');
        if (fecha == null) {
          continue;
        }
        if (fecha.isBefore(hoySinHora)) {
          continue;
        }
        proximaCita = cita;
        break;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _perfil = perfil;
        _totalPagos = totalPagos;
        _totalCitas = citasList.length;
        _proximaCita = proximaCita;
        _campanaActiva = campanaActiva;
        _isLoading = false;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'ClientHome._cargarDashboard',
        uiContext: context,
      );
    }
  }

  Future<void> _cerrarSesion() async {
    SessionManager().stopSession();
    await _supabase.auth.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('PANEL DE CLIENTE'),
        backgroundColor: GymTheme.black,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargarDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GymTheme.neonGreen),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1000;
                final horizontalPadding = isWide ? 32.0 : 16.0;
                final bottomPadding =
                    MediaQuery.of(context).padding.bottom + 32;

                return RefreshIndicator(
                  color: GymTheme.neonGreen,
                  onRefresh: _cargarDashboard,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      horizontalPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    children: [
                      _buildHeroCard(),
                      if (_campanaActiva != null) ...[
                        const SizedBox(height: 20),
                        _buildCampaignStrip(),
                      ],
                      const SizedBox(height: 20),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildSummaryColumn()),
                            const SizedBox(width: 20),
                            Expanded(child: _buildModulesColumn()),
                          ],
                        )
                      else ...[
                        _buildSummaryColumn(),
                        const SizedBox(height: 20),
                        _buildModulesColumn(),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeroCard() {
    final nombre = _perfil?['nombre_completo']?.toString().trim();
    final estado = _perfil?['estado_membresia']?.toString() ?? 'Sin pendientes';
    final fechaCobro = _perfil?['fecha_proximo_cobro']?.toString();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GymTheme.neonGreen.withOpacity(0.18),
            GymTheme.darkGray,
            const Color(0xFF0A0A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        runSpacing: 16,
        spacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MI ESPACIO',
                  style: TextStyle(
                    color: Colors.white54,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nombre != null && nombre.isNotEmpty ? nombre : 'Cliente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Estado de membresia: $estado',
                  style: TextStyle(
                    color: _membershipColor(estado),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fechaCobro == null || fechaCobro.isEmpty
                      ? 'Sin fecha de cobro definida'
                      : 'Proximo cobro: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaCobro))}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          _buildPendingAppointmentBadge(),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn() {
    return Column(
      children: [
        _buildStatCard(
          title: 'Pagos Registrados',
          value: '$_totalPagos',
          subtitle: 'Historial de pagos del cliente',
          icon: Icons.payments_outlined,
          color: GymTheme.neonGreen,
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: 'Citas de Medicion',
          value: '$_totalCitas',
          subtitle: _proximaCita == null
              ? 'No hay citas pendientes'
              : 'Hay una cita pendiente por revisar',
          icon: Icons.straighten_rounded,
          color: Colors.lightBlueAccent,
        ),
      ],
    );
  }

  Widget _buildCampaignStrip() {
    final imageUrl = _campanaActiva?['imagen_url']?.toString().trim();
    final titulo = _campanaActiva?['titulo']?.toString() ?? 'Campaña activa';
    final descripcion = _campanaActiva?['descripcion']?.toString() ?? 'Sin descripcion.';
    final fechaFin = _campanaActiva?['fecha_fin']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10161A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.22)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 700;
            final textContent = Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'PROMOCION VIGENTE',
                      style: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descripcion,
                    maxLines: stacked ? 4 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (fechaFin != null && fechaFin.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Disponible hasta ${DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaFin))}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            );

            final imageWidget = imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: stacked ? 190 : 220,
                    width: stacked ? double.infinity : 280,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildCampaignFallback(stacked),
                  )
                : _buildCampaignFallback(stacked);

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [imageWidget, textContent],
              );
            }

            return Row(
              children: [
                Expanded(child: textContent),
                imageWidget,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModulesColumn() {
    return Column(
      children: [
        _buildModuleCard(
          title: 'Historial de Pagos',
          description:
              'Consulta tus pagos registrados, fechas, montos y detalles asociados a cada cobro.',
          icon: Icons.receipt_long_outlined,
          color: GymTheme.neonGreen,
          actionLabel: 'Abrir historial',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HistorialPagosClienteScreen(),
              ),
            );
            _cargarDashboard();
          },
        ),
        const SizedBox(height: 16),
        _buildModuleCard(
          title: 'Citas de Medicion',
          description:
              'Revisa tu historial de citas y confirma si tienes una medicion pendiente.',
          icon: Icons.event_note_rounded,
          color: Colors.lightBlueAccent,
          actionLabel: 'Ver citas',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CitasMedicionClienteScreen(),
              ),
            );
            _cargarDashboard();
          },
        ),
      ],
    );
  }

  Widget _buildPendingAppointmentBadge() {
    if (_proximaCita == null) {
      return Container(
        constraints: const BoxConstraints(minWidth: 260),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proxima cita',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            SizedBox(height: 8),
            Text(
              'No hay citas pendientes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    final fecha = DateTime.tryParse(_proximaCita!['fecha']?.toString() ?? '');
    final fechaLabel = fecha == null
        ? 'Fecha no disponible'
        : DateFormat('dd/MM/yyyy').format(fecha);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CitasMedicionClienteScreen()),
        );
        _cargarDashboard();
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 260),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cita pendiente',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              fechaLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_proximaCita!['hora_inicio']} - ${_proximaCita!['hora_fin']}',
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Color _membershipColor(String estado) {
    switch (estado) {
      case 'Pago pendiente':
        return Colors.orangeAccent;
      case 'Membresia cancelada':
        return Colors.redAccent;
      case 'Membresia pausada':
        return Colors.blueGrey;
      default:
        return GymTheme.neonGreen;
    }
  }

  Widget _buildCampaignFallback(bool stacked) {
    return Container(
      height: stacked ? 190 : 220,
      width: stacked ? double.infinity : 280,
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.campaign_outlined,
          color: Colors.lightBlueAccent,
          size: 64,
        ),
      ),
    );
  }
}

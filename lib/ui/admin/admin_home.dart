import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_system/ui/admin/pagos_admin_screen.dart';
import 'package:gym_system/ui/admin/usuarios_table_screen.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/session_manager.dart';
import '../../core/theme.dart';
import '../auth/login_screen.dart';
import 'campanas_screen.dart';
import 'citas_medicion_screen.dart';
import 'configuracion_seguridad_screen.dart';
import 'estadisticas_screen.dart';
import 'reportes_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final _supabase = Supabase.instance.client;
  final Map<String, Future<String>> _userNameCache = {};

  Future<void> _logout() async {
    SessionManager().stopSession();
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      drawer: Drawer(
        backgroundColor: const Color(0xFF121212),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fitness_center,
                      color: GymTheme.neonGreen,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ADMIN PANEL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildDrawerItem(
              'USUARIOS',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsuariosTableScreen()),
              ),
            ),
            _buildDrawerItem(
              'PAGOS',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PagosAdminScreen()),
              ),
            ),
            _buildDrawerItem(
              'CITAS DE MEDICION',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CitasMedicionScreen()),
              ),
            ),
            _buildDrawerItem(
              'ESTADISTICAS',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EstadisticasScreen()),
              ),
            ),
            _buildDrawerItem(
              'CAMPAÑAS',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CampanasScreen()),
              ),
            ),
            _buildDrawerItem(
              'AUDITORIA Y LOGS',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportesScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.security_update_good_rounded,
                color: GymTheme.neonGreen,
              ),
              title: const Text(
                'SEGURIDAD DE SESION',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConfigSeguridadScreen(),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'CERRAR SESION',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: GymTheme.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: GymTheme.neonGreen),
        title: GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminHome()),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, color: GymTheme.neonGreen),
              SizedBox(width: 8),
              Text(
                'GYM SYSTEM',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TABLERO PRINCIPAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            _buildSectionHeader(
              'Pagos Vencidos',
              Icons.warning_amber_rounded,
              Colors.orange,
            ),
            _buildPendingPaymentsList(),
            const SizedBox(height: 30),
            _buildSectionHeader(
              'Citas de Hoy',
              Icons.event_available_rounded,
              Colors.lightBlueAccent,
            ),
            _buildTodayAppointmentsList(),
            const SizedBox(height: 30),
            _buildSectionHeader(
              'Errores Activos',
              Icons.bug_report_rounded,
              Colors.redAccent,
            ),
            _buildRecentErrorsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(String title, VoidCallback action) {
    return ListTile(
      leading: const Icon(
        Icons.analytics_outlined,
        color: GymTheme.neonGreen,
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        action();
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('clientes_vencidos')
          .stream(primaryKey: ['id'])
          .order('fecha_proximo_cobro', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.white),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: GymTheme.neonGreen),
          );
        }

        final vencidos = snapshot.data!;
        if (vencidos.isEmpty) {
          return const Card(
            color: GymTheme.darkGray,
            child: ListTile(
              leading: Icon(
                Icons.check_circle_outline,
                color: GymTheme.neonGreen,
              ),
              title: Text(
                'Todo al dia',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'No hay clientes con mensualidades vencidas.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vencidos.length,
          itemBuilder: (context, index) {
            final user = vencidos[index];
            final vencimiento = DateTime.parse(user['fecha_proximo_cobro']);

            return Card(
              color: GymTheme.darkGray,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  user['nombre_completo'] ?? 'Sin nombre',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Vencio el: ${DateFormat('dd/MM/yyyy').format(vencimiento)}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentErrorsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRecentErrors(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            color: GymTheme.darkGray,
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              title: const Text(
                'No se pudieron cargar los errores',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: GymTheme.neonGreen),
          );
        }

        final errores = snapshot.data!;
        if (errores.isEmpty) {
          return const Card(
            color: GymTheme.darkGray,
            child: ListTile(
              leading: Icon(Icons.shield_outlined, color: GymTheme.neonGreen),
              title: Text(
                'Sin errores activos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'No hay errores en estado Descubierto o En proceso.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          );
        }

        final erroresRecientes = errores.take(5).toList();
        final hayMasErrores = errores.length > 5;

        return Column(
          children: [
            ...erroresRecientes.map((error) {
              final timestamp = error['timestamp'];
              final fecha = timestamp != null
                  ? DateFormat('dd/MM/yyyy hh:mm a')
                      .format(DateTime.parse(timestamp.toString()).toLocal())
                  : 'Sin fecha';

              return Card(
                color: GymTheme.darkGray,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _showErrorDetailsDialog(error),
                  leading: CircleAvatar(
                    backgroundColor: _estadoColor(error['estado_revision']),
                    child: const Icon(Icons.priority_high, color: Colors.white),
                  ),
                  title: Text(
                    error['error_mensaje'] ?? 'Error desconocido',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      _buildEstadoChip(error['estado_revision']),
                      const SizedBox(height: 6),
                      Text(
                        'Contexto: ${error['contexto'] ?? 'No definido'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildErrorUserLabel(error['usuario_id']?.toString()),
                      const SizedBox(height: 2),
                      Text(
                        fecha,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_all_rounded, color: Colors.white54),
                    tooltip: 'Copiar mensaje de error',
                    onPressed: () => _copyErrorMessage(
                      error['error_mensaje']?.toString() ?? 'Error desconocido',
                    ),
                  ),
                ),
              );
            }),
            if (hayMasErrores)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportesScreen()),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver todos los errores'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTodayAppointmentsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchTodayAppointments(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            color: GymTheme.darkGray,
            child: ListTile(
              leading: const Icon(Icons.event_busy, color: Colors.redAccent),
              title: const Text(
                'No se pudieron cargar las citas de hoy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: GymTheme.neonGreen),
          );
        }

        final citas = snapshot.data!;
        if (citas.isEmpty) {
          return Card(
            color: GymTheme.darkGray,
            child: ListTile(
              leading: const Icon(
                Icons.calendar_today_outlined,
                color: GymTheme.neonGreen,
              ),
              title: const Text(
                'Sin citas para hoy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'No hay mediciones programadas para la fecha actual.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: _openTodayAppointments,
                child: const Text('Abrir agenda'),
              ),
            ),
          );
        }

        return Column(
          children: citas.map((cita) {
            final estado = (cita['estado'] ?? 'Programada').toString();
            return Card(
              color: GymTheme.darkGray,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: _openTodayAppointments,
                leading: CircleAvatar(
                  backgroundColor: _appointmentStatusColor(estado),
                  child: const Icon(Icons.straighten, color: Colors.white),
                ),
                title: Text(
                  cita['persona_nombre']?.toString() ?? 'Sin asignar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${cita['hora_inicio']} - ${cita['hora_fin']}',
                      style: TextStyle(
                        color: _appointmentStatusColor(estado),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estado: $estado',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                  tooltip: 'Ir a la agenda de hoy',
                  onPressed: _openTodayAppointments,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTodayAppointments() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final citas = await _supabase
        .from('citas_medicion')
        .select()
        .eq('fecha', today)
        .order('hora_inicio', ascending: true);

    final citasList = List<Map<String, dynamic>>.from(citas);
    final ids = citasList
        .map((cita) => cita['persona_asignada_id']?.toString())
        .whereType<String>()
        .toList();

    if (ids.isEmpty) {
      return citasList;
    }

    final users = await _supabase
        .from('perfiles')
        .select('id, nombre_completo')
        .inFilter('id', ids);

    final userMap = {
      for (final user in List<Map<String, dynamic>>.from(users))
        user['id']?.toString(): user['nombre_completo']?.toString(),
    };

    for (final cita in citasList) {
      final userId = cita['persona_asignada_id']?.toString();
      cita['persona_nombre'] = userMap[userId] ?? 'Usuario desconocido';
    }

    return citasList;
  }

  Color _appointmentStatusColor(String estado) {
    switch (estado) {
      case 'Completada':
        return GymTheme.neonGreen;
      case 'Cancelada':
        return Colors.redAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }

  void _openTodayAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CitasMedicionScreen(initialDate: DateTime.now()),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentErrors() async {
    final data = await _supabase
        .from('logs_errores')
        .select()
        .filter('estado_revision', 'in', '(1,2)')
        .order('timestamp', ascending: false)
        .limit(6);

    return List<Map<String, dynamic>>.from(data);
  }

  Widget _buildErrorUserLabel(String? userId) {
    if (userId == null || userId.isEmpty) {
      return const Text(
        'Usuario: Sistema o no disponible',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      );
    }

    final future = _userNameCache.putIfAbsent(
      userId,
      () => _fetchUserDisplayName(userId),
    );

    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        final label = snapshot.data ?? 'Cargando usuario...';
        return Text(
          'Usuario: $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        );
      },
    );
  }

  Future<String> _fetchUserDisplayName(String userId) async {
    try {
      final perfil = await _supabase
          .from('perfiles')
          .select('nombre_completo, cedula')
          .eq('id', userId)
          .maybeSingle();

      if (perfil == null) {
        return userId;
      }

      final nombre = perfil['nombre_completo']?.toString().trim();
      final cedula = perfil['cedula']?.toString().trim();

      if (nombre != null && nombre.isNotEmpty) {
        return cedula != null && cedula.isNotEmpty
            ? '$nombre ($cedula)'
            : nombre;
      }

      if (cedula != null && cedula.isNotEmpty) {
        return cedula;
      }

      return userId;
    } catch (_) {
      return userId;
    }
  }

  void _showErrorDetailsDialog(Map<String, dynamic> error) {
    final timestamp = error['timestamp'];
    final fecha = timestamp != null
        ? DateFormat('dd/MM/yyyy hh:mm:ss a')
            .format(DateTime.parse(timestamp.toString()).toLocal())
        : 'Sin fecha';
    final stackTrace = error['stack_trace']?.toString().trim();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: const Text(
          'DETALLE DEL ERROR',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildErrorDetailRow(
                  'Mensaje',
                  error['error_mensaje']?.toString() ?? 'Error desconocido',
                  trailing: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copiar mensaje',
                    onPressed: () => _copyErrorMessage(
                      error['error_mensaje']?.toString() ?? 'Error desconocido',
                    ),
                    icon: const Icon(
                      Icons.copy_all_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildErrorDetailRow(
                  'Estado',
                  _estadoLabel(error['estado_revision']),
                ),
                const SizedBox(height: 12),
                _buildErrorDetailRow(
                  'Contexto',
                  error['contexto']?.toString() ?? 'No definido',
                ),
                const SizedBox(height: 12),
                _buildErrorDetailRow('Fecha', fecha),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: _buildUserFuture(error['usuario_id']?.toString()),
                  builder: (context, snapshot) {
                    return _buildErrorDetailRow(
                      'Usuario',
                      snapshot.data ?? 'Cargando usuario...',
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Stack trace',
                  style: TextStyle(
                    color: GymTheme.neonGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SelectableText(
                    stackTrace == null || stackTrace.isEmpty
                        ? 'Sin stack trace registrado.'
                        : stackTrace,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                this.context,
                MaterialPageRoute(builder: (_) => const ReportesScreen()),
              );
            },
            child: const Text('VER AUDITORIA'),
          ),
        ],
      ),
    );
  }

  Future<String> _buildUserFuture(String? userId) {
    if (userId == null || userId.isEmpty) {
      return Future.value('Sistema o no disponible');
    }
    return _userNameCache.putIfAbsent(
      userId,
      () => _fetchUserDisplayName(userId),
    );
  }

  Widget _buildErrorDetailRow(
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: GymTheme.neonGreen,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _copyErrorMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensaje de error copiado al portapapeles'),
        backgroundColor: GymTheme.neonGreen,
      ),
    );
  }

  Widget _buildEstadoChip(dynamic estado) {
    final color = _estadoColor(estado);
    return Chip(
      label: Text(
        _estadoLabel(estado),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  String _estadoLabel(dynamic estado) {
    switch (_parseEstado(estado)) {
      case 1:
        return 'Descubierto';
      case 2:
        return 'En proceso';
      case 3:
        return 'Reparado';
      case 4:
        return 'Error en Revision';
      default:
        return 'Descubierto';
    }
  }

  Color _estadoColor(dynamic estado) {
    switch (_parseEstado(estado)) {
      case 1:
        return Colors.orangeAccent;
      case 2:
        return Colors.lightBlueAccent;
      case 3:
        return GymTheme.neonGreen;
      case 4:
        return Colors.amberAccent;
      default:
        return Colors.white54;
    }
  }

  int _parseEstado(dynamic estado) {
    if (estado is int) {
      return estado;
    }
    return int.tryParse(estado?.toString() ?? '') ?? 1;
  }
}

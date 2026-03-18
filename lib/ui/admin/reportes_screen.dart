import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: GymTheme.black,
        appBar: AppBar(
          title: const Text('AUDITORÍA Y REPORTES'),
          backgroundColor: GymTheme.black,
          bottom: const TabBar(
            indicatorColor: GymTheme.neonGreen,
            labelColor: GymTheme.neonGreen,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.history_rounded), text: 'Actividad'),
              Tab(icon: Icon(Icons.bug_report_rounded), text: 'Errores'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListaLogs(),
            _buildListaErrores(),
          ],
        ),
      ),
    );
  }

  // --- PESTAÑA 1: LOGS DE ACTIVIDAD ---
  Widget _buildListaLogs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('logs_sistema')
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: GymTheme.neonGreen));

        final logs = snapshot.data!;
        if (logs.isEmpty) return const Center(child: Text('No hay actividad registrada', style: TextStyle(color: Colors.white54)));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10),
          itemBuilder: (context, index) {
            final log = logs[index];
            final fecha = DateTime.parse(log['timestamp']).toLocal();
            
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _getIconForTipo(log['tipo_evento']),
              title: Text(log['detalle'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Por: ${log['usuario_ejecutor']}", style: const TextStyle(color: GymTheme.neonGreen, fontSize: 12)),
                  Text(DateFormat('dd/MM/yyyy hh:mm a').format(fecha), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              trailing: log['metadata'] != null 
                ? IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white24),
                    onPressed: () => _showMetadataDialog(log['metadata']),
                  )
                : null,
            );
          },
        );
      },
    );
  }

  // --- PESTAÑA 2: LOGS DE ERRORES ---
  Widget _buildListaErrores() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('logs_errores')
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: GymTheme.neonGreen));
        
        final errores = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: errores.length,
          itemBuilder: (context, index) {
            final err = errores[index];
            return Card(
              color: const Color(0xFF1A1A1A),
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                iconColor: Colors.redAccent,
                collapsedIconColor: Colors.redAccent,
                title: Text(err['error_mensaje'] ?? 'Error desconocido', maxLines: 2, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text("Contexto: ${err['contexto']} | ${DateFormat('dd/MM HH:mm').format(DateTime.parse(err['timestamp']))}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.black,
                      child: Text(err['stack_trace'] ?? 'Sin stack trace', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- MÉTODOS DE APOYO ---
  Widget _getIconForTipo(String tipo) {
    IconData icon;
    Color color;
    switch (tipo) {
      case 'LOGIN_EXITOSO': icon = Icons.login; color = GymTheme.neonGreen; break;
      case 'PAGO_REGISTRADO': icon = Icons.monetization_on; color = Colors.amber; break;
      case 'CAMBIO_PRECIO': icon = Icons.settings_applications; color = Colors.blue; break;
      case 'CAMBIO_USUARIO': icon = Icons.person_search; color = Colors.purpleAccent; break;
      default: icon = Icons.notifications; color = Colors.white54;
    }
    return CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20));
  }

  void _showMetadataDialog(dynamic metadata) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: const Text('DETALLES TÉCNICOS', style: TextStyle(color: GymTheme.neonGreen, fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(metadata.toString(), style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR'))],
      ),
    );
  }
}
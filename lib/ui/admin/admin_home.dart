import 'package:flutter/material.dart';
import 'package:gym_system/ui/admin/pagos_admin_screen.dart';
import 'package:gym_system/ui/admin/usuarios_table_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/services/session_manager.dart';
import '../auth/login_screen.dart';
import 'reportes_screen.dart'; // Asegúrate de que las rutas sean correctas
import 'configuracion_seguridad_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final _supabase = Supabase.instance.client;

  // Función para cerrar sesión correctamente
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
      
      // --- BARRA LATERAL (RESTAURADA) ---
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
                    const Icon(Icons.fitness_center, color: GymTheme.neonGreen, size: 40),
                    const SizedBox(height: 10),
                    Text('ADMIN PANEL', 
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),

            // Opción: Usuarios
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: GymTheme.neonGreen),
              title: const Text('USUARIOS', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UsuariosTableScreen()));
              },
            ),

            // Opción: Pagos
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: GymTheme.neonGreen),
              title: const Text('PAGOS', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PagosAdminScreen()));
              },
            ),
            
            // Opción: Reportes y Auditoría
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: GymTheme.neonGreen),
              title: const Text('AUDITORÍA Y LOGS', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportesScreen()));
              },
            ),

            // Opción: Configuración de Seguridad
            ListTile(
              leading: const Icon(Icons.security_update_good_rounded, color: GymTheme.neonGreen),
              title: const Text('SEGURIDAD DE SESIÓN', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigSeguridadScreen()));
              },
            ),

            const Divider(color: Colors.white10),

            // Opción: Cerrar Sesión
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('CERRAR SESIÓN', style: TextStyle(color: Colors.redAccent)),
              onTap: _logout,
            ),
          ],
        ),
      ),

      appBar: AppBar(
        backgroundColor: GymTheme.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: GymTheme.neonGreen), // Para que el icono del menú sea verde
        title: GestureDetector(
          onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHome()));
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, color: GymTheme.neonGreen),
              SizedBox(width: 8),
              Text('GYM SYSTEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),

            // SECCIÓN 1: PAGOS PENDIENTES
            _buildSectionHeader('Pagos Vencidos', Icons.warning_amber_rounded, Colors.orange),
            _buildPendingPaymentsList(),

            const SizedBox(height: 30),

            // SECCIÓN 2: ESPACIO PARA FUTURO MÓDULO
            _buildSectionHeader('Próximas Actividades', Icons.foundation_rounded, Colors.blue),
            _buildPlaceholderSection(),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
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
        if (snapshot.hasError) return Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: GymTheme.neonGreen));
        
        final vencidos = snapshot.data!;
        if (vencidos.isEmpty) return _buildEmptyCard();

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
                title: Text(user['nombre_completo'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Venció el: ${DateFormat('dd/MM/yyyy').format(vencimiento)}',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyCard() {
    return const Card(
      color: GymTheme.darkGray,
      child: ListTile(
        leading: Icon(Icons.check_circle_outline, color: GymTheme.neonGreen),
        title: Text('¡Todo al día!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('No hay clientes con mensualidades vencidas.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ),
    );
  }

  Widget _buildPlaceholderSection() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: GymTheme.darkGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white24, size: 40),
            SizedBox(height: 10),
            Text('Módulo en desarrollo...', style: TextStyle(color: Colors.white24)),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/services/logger_service.dart';

class ConfigSeguridadScreen extends StatefulWidget {
  const ConfigSeguridadScreen({super.key});

  @override
  State<ConfigSeguridadScreen> createState() => _ConfigSeguridadScreenState();
}

class _ConfigSeguridadScreenState extends State<ConfigSeguridadScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _configuraciones = [];

  @override
  void initState() {
    super.initState();
    _cargarConfiguraciones();
  }

  Future<void> _cargarConfiguraciones() async {
    try {
      // Traemos los tiempos unidos con el nombre del rol
      final data = await _supabase
          .from('configuracion_seguridad')
          .select('rol_id, tiempo_inactividad_minutos, roles(nombre)')
          .order('rol_id');
      
      setState(() {
        _configuraciones = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando config: $e");
    }
  }

  Future<void> _actualizarTiempo(int rolId, int nuevoTiempo, String nombreRol) async {
    try {
      await _supabase
          .from('configuracion_seguridad')
          .update({'tiempo_inactividad_minutos': nuevoTiempo})
          .eq('rol_id', rolId);

      await LoggerService.logEvento(
        tipo: 'CONFIG_SEGURIDAD_CAMBIO',
        detalle: 'Se cambió tiempo de sesión de $nombreRol a $nuevoTiempo min',
        metadata: {'rol_id': rolId, 'nuevo_tiempo': nuevoTiempo},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuración de $nombreRol actualizada')),
        );
      }
      _cargarConfiguraciones();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('CONFIGURACIÓN DE SESIÓN'),
        backgroundColor: GymTheme.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GymTheme.neonGreen))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _configuraciones.length,
              itemBuilder: (context, index) {
                final config = _configuraciones[index];
                final rolNombre = config['roles']['nombre'];
                final tiempoActual = config['tiempo_inactividad_minutos'];

                return Card(
                  color: GymTheme.darkGray,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, color: GymTheme.neonGreen),
                            const SizedBox(width: 10),
                            Text(
                              'Rol: $rolNombre',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 25),
                        const Text(
                          'Tiempo de cierre automático por inactividad:',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$tiempoActual minutos',
                              style: const TextStyle(
                                color: GymTheme.neonGreen,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [5, 15, 30, 60].map((min) {
                                return ChoiceChip(
                                  label: Text('$min min'),
                                  selected: tiempoActual == min,
                                  selectedColor: GymTheme.neonGreen,
                                  labelStyle: TextStyle(
                                    color: tiempoActual == min ? Colors.black : Colors.white,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      _actualizarTiempo(config['rol_id'], min, rolNombre);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
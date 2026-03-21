import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme.dart';

class ConfigSeguridadScreen extends StatefulWidget {
  const ConfigSeguridadScreen({super.key});

  @override
  State<ConfigSeguridadScreen> createState() => _ConfigSeguridadScreenState();
}

class _ConfigSeguridadScreenState extends State<ConfigSeguridadScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _configuraciones = [];
  List<Map<String, dynamic>> _deviceTokens = [];

  @override
  void initState() {
    super.initState();
    _cargarConfiguraciones();
  }

  Future<void> _cargarConfiguraciones() async {
    try {
      final data = await _supabase
          .from('configuracion_seguridad')
          .select('rol_id, tiempo_inactividad_minutos, roles(nombre)')
          .order('rol_id');

      final tokensData = await _supabase
          .from('device_push_tokens')
          .select('id, usuario_id, token, plataforma, activo, updated_at')
          .order('updated_at', ascending: false);

      final tokens = List<Map<String, dynamic>>.from(tokensData);
      final userIds = tokens
          .map((token) => token['usuario_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> perfilesMap = {};
      if (userIds.isNotEmpty) {
        final perfiles = await _supabase
            .from('perfiles')
            .select('id, nombre_completo, cedula')
            .inFilter('id', userIds);

        perfilesMap = {
          for (final perfil in List<Map<String, dynamic>>.from(perfiles))
            perfil['id']?.toString() ?? '': perfil,
        };
      }

      if (!mounted) {
        return;
      }

      final tokensEnriquecidos = tokens.map((token) {
        final userId = token['usuario_id']?.toString() ?? '';
        final perfil = perfilesMap[userId];
        return {
          ...token,
          'nombre_completo': perfil?['nombre_completo']?.toString() ?? 'Usuario desconocido',
          'cedula': perfil?['cedula']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        _configuraciones = List<Map<String, dynamic>>.from(data);
        _deviceTokens = tokensEnriquecidos;
        _isLoading = false;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'ConfigSeguridadScreen._cargarConfiguraciones',
        uiContext: context,
      );
    }
  }

  Future<void> _actualizarTiempo(
    int rolId,
    int nuevoTiempo,
    String nombreRol,
  ) async {
    try {
      await _supabase
          .from('configuracion_seguridad')
          .update({'tiempo_inactividad_minutos': nuevoTiempo})
          .eq('rol_id', rolId);

      await LoggerService.logEvento(
        tipo: 'CONFIG_SEGURIDAD_CAMBIO',
        detalle: 'Se cambio tiempo de sesion de $nombreRol a $nuevoTiempo min',
        metadata: {'rol_id': rolId, 'nuevo_tiempo': nuevoTiempo},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuracion de $nombreRol actualizada')),
        );
      }

      await _cargarConfiguraciones();
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'ConfigSeguridadScreen._actualizarTiempo',
        uiContext: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('CONFIGURACION DE SESION'),
        backgroundColor: GymTheme.black,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargarConfiguraciones,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GymTheme.neonGreen),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _configuraciones.length + 2,
              itemBuilder: (context, index) {
                if (index < _configuraciones.length) {
                  final config = _configuraciones[index];
                  final rolNombre = config['roles']['nombre'];
                  final tiempoActual = config['tiempo_inactividad_minutos'];

                  return Card(
                    color: GymTheme.darkGray,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.security,
                                color: GymTheme.neonGreen,
                              ),
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
                            'Tiempo de cierre automatico por inactividad:',
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
                                      color: tiempoActual == min
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        _actualizarTiempo(
                                          config['rol_id'],
                                          min,
                                          rolNombre,
                                        );
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
                }

                if (index == _configuraciones.length) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10161A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active, color: Colors.lightBlueAccent),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'TOKENS PUSH POR USUARIO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_deviceTokens.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: GymTheme.darkGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Text(
                      'No hay tokens push registrados todavia.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final token = _deviceTokens[index - _configuraciones.length - 1];
                final nombre = token['nombre_completo']?.toString() ?? 'Usuario desconocido';
                final cedula = token['cedula']?.toString() ?? '';
                final plataforma = token['plataforma']?.toString() ?? 'unknown';
                final actualizado = DateTime.tryParse(
                  token['updated_at']?.toString() ?? '',
                );

                return Card(
                  color: GymTheme.darkGray,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _platformIcon(plataforma),
                              color: _platformColor(plataforma),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cedula.isEmpty ? nombre : '$nombre ($cedula)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildEstadoTokenChip(token['activo'] == true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Plataforma: ${plataforma.toUpperCase()}',
                          style: TextStyle(
                            color: _platformColor(plataforma),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          actualizado == null
                              ? 'Ultima actualizacion: Sin fecha'
                              : 'Ultima actualizacion: ${DateFormat('dd/MM/yyyy hh:mm a').format(actualizado.toLocal())}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: SelectableText(
                            token['token']?.toString() ?? 'Sin token',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final texto = token['token']?.toString() ?? '';
                              if (texto.isEmpty) {
                                return;
                              }
                              await Clipboard.setData(ClipboardData(text: texto));
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Token copiado al portapapeles'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_all_rounded, size: 18),
                            label: const Text('Copiar token'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEstadoTokenChip(bool activo) {
    final color = activo ? GymTheme.neonGreen : Colors.redAccent;
    final label = activo ? 'Activo' : 'Inactivo';

    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
    );
  }

  IconData _platformIcon(String plataforma) {
    switch (plataforma.toLowerCase()) {
      case 'android':
        return Icons.android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'web':
        return Icons.public_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  Color _platformColor(String plataforma) {
    switch (plataforma.toLowerCase()) {
      case 'android':
        return Colors.greenAccent;
      case 'ios':
        return Colors.lightBlueAccent;
      case 'web':
        return Colors.orangeAccent;
      default:
        return Colors.white54;
    }
  }
}

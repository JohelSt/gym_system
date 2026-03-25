import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/reload_error_state.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final supabase = Supabase.instance.client;
  final Set<int> _selectedErrorIds = <int>{};
  final Map<int, TextEditingController> _commentControllers = {};
  final Map<String, Future<String>> _userNameCache = {};
  int _estadoFiltro = 0;

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: GymTheme.black,
        appBar: AppBar(
          title: const Text('AUDITORIA Y REPORTES'),
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

  Widget _buildListaLogs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('logs_sistema')
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: ReloadErrorState(
              message: 'No se pudo cargar la actividad del sistema.',
              onRetry: () => setState(() {}),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: GymTheme.neonGreen),
          );
        }

        final logs = snapshot.data!;
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              'No hay actividad registrada',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

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
              title: Text(
                log['detalle'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por: ${log['usuario_ejecutor']}',
                    style: const TextStyle(
                      color: GymTheme.neonGreen,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy hh:mm a').format(fecha),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              trailing: log['metadata'] != null
                  ? IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        color: Colors.white24,
                      ),
                      onPressed: () => _showMetadataDialog(log['metadata']),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildListaErrores() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchErrores(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ReloadErrorState(
                message: 'No se pudo cargar la lista de errores.',
                onRetry: () => setState(() {}),
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

        return RefreshIndicator(
          onRefresh: () async {
            if (mounted) {
              setState(() {});
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: errores.isEmpty ? 2 : errores.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildErrorToolbar();
              }

              if (errores.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: GymTheme.darkGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    _estadoFiltro == 0
                        ? 'No hay errores registrados'
                        : 'No hay errores en el estado seleccionado',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                );
              }

              final err = errores[index - 1];
              final timestamp = err['timestamp'];
              final fecha = timestamp != null
                  ? DateTime.parse(timestamp.toString()).toLocal()
                  : null;
              final errorId = _parseErrorId(err['id']);
              final isSelected = errorId != null && _selectedErrorIds.contains(errorId);

              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: Checkbox(
                    value: isSelected,
                    activeColor: GymTheme.neonGreen,
                    onChanged: errorId == null
                        ? null
                        : (value) => _toggleErrorSelection(errorId, value ?? false),
                  ),
                  iconColor: Colors.redAccent,
                  collapsedIconColor: Colors.redAccent,
                  title: Text(
                    err['error_mensaje'] ?? 'Error desconocido',
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _buildEstadoChip(err['estado_revision']),
                      const SizedBox(height: 6),
                      Text(
                        'Contexto: ${err['contexto'] ?? 'No definido'}'
                        '${fecha != null ? ' | ${DateFormat('dd/MM HH:mm').format(fecha)}' : ''}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.copy_all_rounded,
                      color: Colors.white54,
                    ),
                    tooltip: 'Copiar mensaje de error',
                    onPressed: () => _copiarTexto(
                      err['error_mensaje']?.toString() ?? 'Error desconocido',
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado de Revision',
                            style: TextStyle(
                              color: GymTheme.neonGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _parseEstado(err['estado_revision']),
                                dropdownColor: GymTheme.darkGray,
                                style: const TextStyle(color: Colors.white),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('1 - Descubierto'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('2 - En proceso'),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text('3 - Reparado'),
                                  ),
                                  DropdownMenuItem(
                                    value: 4,
                                    child: Text('4 - Error en Revision'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    _actualizarEstadoError(
                                      err,
                                      value,
                                      fromBulk: false,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text(
                                'Mensaje del error',
                                style: TextStyle(
                                  color: GymTheme.neonGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Copiar mensaje',
                                onPressed: () => _copiarTexto(
                                  err['error_mensaje']?.toString() ??
                                      'Error desconocido',
                                ),
                                icon: const Icon(
                                  Icons.copy_all_rounded,
                                  size: 18,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: SelectableText(
                              err['error_mensaje']?.toString() ??
                                  'Error desconocido',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            color: Colors.black,
                            child: SelectableText(
                              err['stack_trace'] ?? 'Sin stack trace',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCommentsSection(err),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchErrores() async {
    dynamic query = supabase.from('logs_errores').select();

    if (_estadoFiltro != 0) {
      query = query.eq('estado_revision', _estadoFiltro);
    }

    final data = await query.order('timestamp', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _actualizarEstadoError(
    Map<String, dynamic> error,
    int nuevoEstado,
    {bool fromBulk = false}
  ) async {
    try {
      final updated = await supabase
          .from('logs_errores')
          .update({'estado_revision': nuevoEstado})
          .eq('id', error['id'])
          .select('id, estado_revision')
          .maybeSingle();

      if (updated == null) {
        throw const FormatException(
          'No se pudo actualizar el estado del error. Revisa permisos de update en Supabase.',
        );
      }

      await LoggerService.logEvento(
        tipo: 'ERROR_ESTADO_CAMBIO',
        detalle: 'Se actualizo estado de error #${error['id']}',
        metadata: {
          'error_id': error['id'],
          'estado_anterior': _parseEstado(error['estado_revision']),
          'estado_nuevo': nuevoEstado,
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fromBulk
                ? 'Estado actualizado para errores seleccionados'
                : 'Estado cambiado a ${_estadoLabel(nuevoEstado)}',
          ),
          backgroundColor: GymTheme.neonGreen,
        ),
      );

      setState(() {});
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'ReportesScreen._actualizarEstadoError',
        uiContext: context,
      );
    }
  }

  Widget _buildErrorToolbar() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GymTheme.darkGray,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Filtrar por estado',
                style: TextStyle(
                  color: GymTheme.neonGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _estadoFiltro,
                    dropdownColor: GymTheme.darkGray,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Todos')),
                      DropdownMenuItem(value: 1, child: Text('1 - Descubierto')),
                      DropdownMenuItem(value: 2, child: Text('2 - En proceso')),
                      DropdownMenuItem(value: 3, child: Text('3 - Reparado')),
                      DropdownMenuItem(value: 4, child: Text('4 - Error en Revision')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _estadoFiltro = value;
                        _selectedErrorIds.clear();
                      });
                    },
                  ),
                ),
              ),
              if (_estadoFiltro != 0)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _estadoFiltro = 0;
                      _selectedErrorIds.clear();
                    });
                  },
                  icon: const Icon(
                    Icons.filter_alt_off_rounded,
                    size: 18,
                  ),
                  label: const Text('Limpiar filtro'),
                ),
            ],
          ),
        ),
        if (_selectedErrorIds.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10161A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.25)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_selectedErrorIds.length} error(es) seleccionados',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBulkButton('En proceso', 2),
                    _buildBulkButton('Reparado', 3),
                    _buildBulkButton('En revision', 4),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedErrorIds.clear());
                      },
                      child: const Text('Limpiar seleccion'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBulkButton(String label, int estado) {
    return ElevatedButton(
      onPressed: () => _actualizarEstadoErroresSeleccionados(estado),
      child: Text(label),
    );
  }

  void _toggleErrorSelection(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedErrorIds.add(id);
      } else {
        _selectedErrorIds.remove(id);
      }
    });
  }

  Future<void> _actualizarEstadoErroresSeleccionados(int nuevoEstado) async {
    if (_selectedErrorIds.isEmpty) {
      return;
    }

    try {
      final ids = _selectedErrorIds.toList();
      final updated = await supabase
          .from('logs_errores')
          .update({'estado_revision': nuevoEstado})
          .inFilter('id', ids)
          .select('id');

      final updatedRows = List<Map<String, dynamic>>.from(updated);
      if (updatedRows.isEmpty) {
        throw const FormatException(
          'No se pudo actualizar el estado de los errores seleccionados.',
        );
      }

      await LoggerService.logEvento(
        tipo: 'ERROR_ESTADO_MASIVO_CAMBIO',
        detalle: 'Se actualizo el estado de varios errores',
        metadata: {
          'error_ids': ids,
          'estado_nuevo': nuevoEstado,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedErrorIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se actualizaron ${updatedRows.length} error(es) a ${_estadoLabel(nuevoEstado)}',
          ),
          backgroundColor: GymTheme.neonGreen,
        ),
      );
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'ReportesScreen._actualizarEstadoErroresSeleccionados',
        uiContext: context,
      );
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildCommentsSection(Map<String, dynamic> err) {
    final errorId = _parseErrorId(err['id']);
    if (errorId == null) {
      return const SizedBox.shrink();
    }

    final controller = _commentControllers.putIfAbsent(
      errorId,
      () => TextEditingController(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comentarios',
          style: TextStyle(
            color: GymTheme.neonGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Agregar comentario tecnico o seguimiento...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _agregarComentario(errorId),
              child: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchComentarios(errorId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(color: GymTheme.neonGreen),
              );
            }

            if (snapshot.hasError) {
              return ReloadErrorState(
                message: 'No se pudieron cargar los comentarios.',
                onRetry: () => setState(() {}),
                compact: true,
              );
            }

            final comentarios = snapshot.data ?? [];
            if (comentarios.isEmpty) {
              return const Text(
                'No hay comentarios registrados para este error.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              );
            }

            return Column(
              children: comentarios.map((comentario) {
                final fecha = DateTime.tryParse(
                  comentario['created_at']?.toString() ?? '',
                );
                final fechaTexto = fecha == null
                    ? 'Sin fecha'
                    : DateFormat('dd/MM/yyyy hh:mm a').format(fecha.toLocal());

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comentario['usuario_id'] != null) ...[
                        FutureBuilder<String>(
                          future: _buildUserFuture(
                            comentario['usuario_id']?.toString(),
                          ),
                          builder: (context, userSnapshot) {
                            return Text(
                              userSnapshot.data ?? 'Cargando usuario...',
                              style: const TextStyle(
                                color: GymTheme.neonGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        comentario['comentario']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fechaTexto,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchComentarios(int errorId) async {
    final data = await supabase
        .from('logs_errores_comentarios')
        .select()
        .eq('error_id', errorId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _agregarComentario(int errorId) async {
    final controller = _commentControllers[errorId];
    final texto = controller?.text.trim() ?? '';
    if (texto.isEmpty) {
      return;
    }

    try {
      await supabase.from('logs_errores_comentarios').insert({
        'error_id': errorId,
        'usuario_id': supabase.auth.currentUser?.id,
        'comentario': texto,
      });

      await LoggerService.logEvento(
        tipo: 'ERROR_COMENTARIO_AGREGADO',
        detalle: 'Se agrego comentario a error #$errorId',
        metadata: {'error_id': errorId},
      );

      controller?.clear();
      if (mounted) {
        setState(() {});
      }
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'ReportesScreen._agregarComentario',
        uiContext: context,
      );
    }
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

  Widget _getIconForTipo(String tipo) {
    IconData icon;
    Color color;
    switch (tipo) {
      case 'LOGIN_EXITOSO':
        icon = Icons.login;
        color = GymTheme.neonGreen;
        break;
      case 'PAGO_REGISTRADO':
        icon = Icons.monetization_on;
        color = Colors.amber;
        break;
      case 'CAMBIO_PRECIO':
        icon = Icons.settings_applications;
        color = Colors.blue;
        break;
      case 'CAMBIO_USUARIO':
        icon = Icons.person_search;
        color = Colors.purpleAccent;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.white54;
    }
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
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

  int? _parseErrorId(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
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

  Future<String> _fetchUserDisplayName(String userId) async {
    try {
      final perfil = await supabase
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

  void _showMetadataDialog(dynamic metadata) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: const Text(
          'DETALLES TECNICOS',
          style: TextStyle(color: GymTheme.neonGreen, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Text(
            metadata.toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarTexto(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
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
}

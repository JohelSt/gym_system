import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';
import 'crear_usuario_dialog.dart';
import 'editar_usuario_dialog.dart';

class UsuariosTableScreen extends StatefulWidget {
  const UsuariosTableScreen({super.key});

  @override
  State<UsuariosTableScreen> createState() => _UsuariosTableScreenState();
}

class _UsuariosTableScreenState extends State<UsuariosTableScreen> {
  List<Map<String, dynamic>> _usuariosOriginales = [];
  List<Map<String, dynamic>> _usuariosFiltrados = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsuarios();
  }

  Future<void> _fetchUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('perfiles')
          .select('*, roles(nombre)')
          .order('nombre_completo', ascending: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _usuariosOriginales = List<Map<String, dynamic>>.from(data);
        _usuariosFiltrados = _usuariosOriginales;
        _isLoading = false;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'UsuariosTableScreen._fetchUsuarios',
        uiContext: context,
      );
    }
  }

  void _filtrarUsuarios(String query) {
    final s = query.toLowerCase();
    setState(() {
      _usuariosFiltrados = _usuariosOriginales.where((user) {
        final nombre = (user['nombre_completo'] ?? '').toString().toLowerCase();
        final cedula = (user['cedula'] ?? '').toString().toLowerCase();
        final telefono = (user['telefono'] ?? '').toString().toLowerCase();
        final rol = user['roles'] != null
            ? user['roles']['nombre'].toString().toLowerCase()
            : '';

        return nombre.contains(s) ||
            cedula.contains(s) ||
            telefono.contains(s) ||
            rol.contains(s);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('CONTROL DE MIEMBROS'),
        backgroundColor: GymTheme.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: GymTheme.neonGreen),
            onPressed: _fetchUsuarios,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GymTheme.neonGreen,
        onPressed: () async {
          final res = await showDialog(
            context: context,
            builder: (c) => const CrearUsuarioDialog(),
          );
          if (res == true) {
            _fetchUsuarios();
          }
        },
        label: const Text(
          'NUEVO USUARIO',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.person_add, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _filtrarUsuarios,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, cedula, tel o rol...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.search,
                  color: GymTheme.neonGreen,
                ),
                filled: true,
                fillColor: const Color(0xFF121212),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: GymTheme.neonGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarUsuarios('');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const LinearProgressIndicator(
                color: GymTheme.neonGreen,
                backgroundColor: Colors.black,
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 15,
                  minWidth: 900,
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF1A1A1A),
                  ),
                  headingTextStyle: const TextStyle(
                    color: GymTheme.neonGreen,
                    fontWeight: FontWeight.bold,
                  ),
                  columns: const [
                    DataColumn2(label: Text('NOMBRE'), size: ColumnSize.L),
                    DataColumn2(label: Text('TELEFONO'), size: ColumnSize.M),
                    DataColumn2(label: Text('ROL'), size: ColumnSize.M),
                    DataColumn2(label: Text('ESTADO'), size: ColumnSize.S),
                    DataColumn2(label: Text('ACCIONES'), size: ColumnSize.S),
                  ],
                  rows: _usuariosFiltrados.map((user) {
                    final isActive = user['estado'] == true;
                    final nombreRol = user['roles'] != null
                        ? user['roles']['nombre']
                        : 'Cliente';

                    return DataRow2(
                      cells: [
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['nombre_completo'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                user['cedula'].toString(),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            user['telefono'] ?? 'N/A',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        DataCell(
                          Chip(
                            label: Text(
                              nombreRol,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: GymTheme.neonGreen.withOpacity(0.1),
                            labelStyle: const TextStyle(
                              color: GymTheme.neonGreen,
                            ),
                            side: BorderSide(
                              color: GymTheme.neonGreen.withOpacity(0.3),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        DataCell(
                          Icon(
                            isActive ? Icons.check_circle : Icons.cancel,
                            color: isActive
                                ? GymTheme.neonGreen
                                : Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                  size: 18,
                                ),
                                onPressed: () => _abrirEditar(user),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                onPressed: () => _confirmarEliminar(user),
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

  void _confirmarEliminar(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: const Text(
          'ELIMINAR MIEMBRO?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Esta accion no se puede deshacer.\nUsuario: ${usuario['nombre_completo']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('perfiles')
                    .delete()
                    .eq('cedula', usuario['cedula']);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _fetchUsuarios();
              } catch (e, stack) {
                await AppErrorHandler.handle(
                  e,
                  stack,
                  context: 'UsuariosTableScreen._confirmarEliminar',
                  uiContext: context,
                );
              }
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  void _abrirEditar(Map<String, dynamic> usuario) async {
    final res = await showDialog(
      context: context,
      builder: (c) => EditarUsuarioDialog(
        userData: {
          'cedula': usuario['cedula'],
          'nombre_completo': usuario['nombre_completo'],
          'telefono': usuario['telefono'],
          'direccion': usuario['direccion'],
          'estado': usuario['estado'],
        },
      ),
    );
    if (res == true) {
      _fetchUsuarios();
    }
  }
}

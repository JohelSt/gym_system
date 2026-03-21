import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme.dart';

class CampanasScreen extends StatefulWidget {
  const CampanasScreen({super.key});

  @override
  State<CampanasScreen> createState() => _CampanasScreenState();
}

class _CampanasScreenState extends State<CampanasScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _campanas = [];

  @override
  void initState() {
    super.initState();
    _cargarCampanas();
  }

  Future<void> _cargarCampanas() async {
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('campanas')
          .select()
          .order('fecha_inicio', ascending: false)
          .order('created_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _campanas = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CampanasScreen._cargarCampanas',
        uiContext: context,
      );
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? campana}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _CampanaDialog(campana: campana),
    );

    if (result == true) {
      _cargarCampanas();
    }
  }

  Future<void> _eliminarCampana(Map<String, dynamic> campana) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: const Text(
          'ELIMINAR CAMPAÑA',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Se eliminara "${campana['titulo']}". Esta accion no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmado != true) {
      return;
    }

    try {
      await _supabase.from('campanas').delete().eq('id', campana['id']);

      await LoggerService.logEvento(
        tipo: 'CAMPANA_ELIMINADA',
        detalle: 'Se elimino una campana',
        metadata: {
          'campana_id': campana['id'],
          'titulo': campana['titulo'],
        },
      );

      _cargarCampanas();
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CampanasScreen._eliminarCampana',
        uiContext: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('CAMPAÑAS'),
        backgroundColor: GymTheme.black,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargarCampanas,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Nueva campaña',
            onPressed: () => _abrirFormulario(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: GymTheme.neonGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nueva campaña'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GymTheme.neonGreen),
            )
          : RefreshIndicator(
              color: GymTheme.neonGreen,
              onRefresh: _cargarCampanas,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  if (_campanas.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        _CampanaEmptyState(),
                      ],
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 2 : 1,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: isWide ? 1.8 : 0.95,
                    ),
                    itemCount: _campanas.length,
                    itemBuilder: (context, index) {
                      final campana = _campanas[index];
                      return _CampanaCard(
                        campana: campana,
                        onEdit: () => _abrirFormulario(campana: campana),
                        onDelete: () => _eliminarCampana(campana),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _CampanaCard extends StatelessWidget {
  const _CampanaCard({
    required this.campana,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> campana;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = campana['imagen_url']?.toString().trim();
    final estado = _buildEstadoCampana(campana);
    final estadoColor = _estadoColor(estado);

    return Container(
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackImage(),
                  )
                : _buildFallbackImage(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          campana['titulo']?.toString() ?? 'Sin titulo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(estado),
                        backgroundColor: estadoColor.withValues(alpha: 0.14),
                        side: BorderSide(color: estadoColor.withValues(alpha: 0.35)),
                        labelStyle: TextStyle(
                          color: estadoColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    campana['descripcion']?.toString() ?? 'Sin descripcion',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const Spacer(),
                  Text(
                    'Inicio: ${_formatDate(campana['fecha_inicio'])}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fin: ${_formatDate(campana['fecha_fin'])}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFallbackImage() {
    return Container(
      height: 170,
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white38, size: 56),
      ),
    );
  }

  static String _buildEstadoCampana(Map<String, dynamic> campana) {
    final activa = campana['activa'] == true;
    final hoy = DateTime.now();
    final inicio = DateTime.tryParse(campana['fecha_inicio']?.toString() ?? '');
    final fin = DateTime.tryParse(campana['fecha_fin']?.toString() ?? '');
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);

    if (!activa) {
      return 'Inactiva';
    }
    if (inicio != null && hoySinHora.isBefore(inicio)) {
      return 'Programada';
    }
    if (fin != null && hoySinHora.isAfter(fin)) {
      return 'Finalizada';
    }
    return 'Activa';
  }

  static Color _estadoColor(String estado) {
    switch (estado) {
      case 'Activa':
        return GymTheme.neonGreen;
      case 'Programada':
        return Colors.lightBlueAccent;
      case 'Finalizada':
        return Colors.orangeAccent;
      default:
        return Colors.white54;
    }
  }

  static String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return 'Sin fecha';
    }
    return DateFormat('dd/MM/yyyy').format(parsed);
  }
}

class _CampanaEmptyState extends StatelessWidget {
  const _CampanaEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.campaign_outlined, color: Colors.white38, size: 64),
          SizedBox(height: 12),
          Text(
            'No hay campañas registradas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Crea una campaña con titulo, descripcion, vigencia e imagen para mostrarla a los clientes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _CampanaDialog extends StatefulWidget {
  const _CampanaDialog({this.campana});

  final Map<String, dynamic>? campana;

  @override
  State<_CampanaDialog> createState() => _CampanaDialogState();
}

class _CampanaDialogState extends State<_CampanaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _imagenCtrl = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _activa = true;
  bool _isSaving = false;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool get _isEditing => widget.campana != null;

  @override
  void initState() {
    super.initState();
    final campana = widget.campana;
    if (campana != null) {
      _tituloCtrl.text = campana['titulo']?.toString() ?? '';
      _descripcionCtrl.text = campana['descripcion']?.toString() ?? '';
      _imagenCtrl.text = campana['imagen_url']?.toString() ?? '';
      _activa = campana['activa'] == true;
      _fechaInicio = DateTime.tryParse(campana['fecha_inicio']?.toString() ?? '');
      _fechaFin = DateTime.tryParse(campana['fecha_fin']?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _imagenCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha({required bool esInicio}) async {
    final inicial = esInicio
        ? (_fechaInicio ?? DateTime.now())
        : (_fechaFin ?? _fechaInicio ?? DateTime.now());

    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: GymTheme.neonGreen),
        ),
        child: child!,
      ),
    );

    if (fecha == null) {
      return;
    }

    setState(() {
      if (esInicio) {
        _fechaInicio = fecha;
        if (_fechaFin != null && _fechaFin!.isBefore(fecha)) {
          _fechaFin = fecha;
        }
      } else {
        _fechaFin = fecha;
      }
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_fechaInicio == null || _fechaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes definir fecha de inicio y fecha limite.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_fechaFin!.isBefore(_fechaInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha limite no puede ser menor a la fecha de inicio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'imagen_url': _imagenCtrl.text.trim().isEmpty ? null : _imagenCtrl.text.trim(),
        'fecha_inicio': DateFormat('yyyy-MM-dd').format(_fechaInicio!),
        'fecha_fin': DateFormat('yyyy-MM-dd').format(_fechaFin!),
        'activa': _activa,
        'created_by': _supabase.auth.currentUser?.id,
      };

      if (_isEditing) {
        await _supabase
            .from('campanas')
            .update(payload)
            .eq('id', widget.campana!['id']);

        await LoggerService.logEvento(
          tipo: 'CAMPANA_ACTUALIZADA',
          detalle: 'Se actualizo una campana',
          metadata: {
            'campana_id': widget.campana!['id'],
            'titulo': _tituloCtrl.text.trim(),
          },
        );
      } else {
        await _supabase.from('campanas').insert(payload);

        await LoggerService.logEvento(
          tipo: 'CAMPANA_CREADA',
          detalle: 'Se creo una nueva campana',
          metadata: {'titulo': _tituloCtrl.text.trim()},
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CampanasScreen._guardar',
        uiContext: context,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GymTheme.darkGray,
      title: Text(
        _isEditing ? 'EDITAR CAMPAÑA' : 'NUEVA CAMPAÑA',
        style: const TextStyle(color: GymTheme.neonGreen),
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _tituloCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Titulo',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un titulo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descripcionCtrl,
                  style: const TextStyle(color: Colors.white),
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa una descripcion.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _imagenCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'URL de imagen',
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: 'https://...',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Fecha inicio',
                        value: _fechaInicio,
                        onTap: () => _seleccionarFecha(esInicio: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Fecha limite',
                        value: _fechaFin,
                        onTap: () => _seleccionarFecha(esInicio: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _activa,
                  activeColor: GymTheme.neonGreen,
                  title: const Text(
                    'Campaña activa',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Solo las campañas activas y vigentes se mostraran al cliente.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onChanged: (value) => setState(() => _activa = value),
                ),
                if (_imagenCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _imagenCtrl.text.trim(),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: const Text(
                          'No se pudo cargar la imagen',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _guardar,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('GUARDAR'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value == null ? 'Seleccionar' : DateFormat('dd/MM/yyyy').format(value!),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

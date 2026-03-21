import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';

enum CalendarScope { day, week, month }

class CitasMedicionScreen extends StatefulWidget {
  final DateTime? initialDate;

  const CitasMedicionScreen({super.key, this.initialDate});

  @override
  State<CitasMedicionScreen> createState() => _CitasMedicionScreenState();
}

class _CitasMedicionScreenState extends State<CitasMedicionScreen> {
  final _supabase = Supabase.instance.client;
  CalendarScope _scope = CalendarScope.month;
  DateTime _selectedDate = DateTime.now();
  String _estadoFiltro = 'Todos';
  bool _isLoading = true;
  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _usuariosAsignables = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      _scope = CalendarScope.day;
    }
    _cargarAgenda();
  }

  Future<void> _cargarAgenda() async {
    setState(() => _isLoading = true);

    try {
      final usuarios = await _supabase
          .from('perfiles')
          .select('id, nombre_completo, rol_id, estado')
          .inFilter('rol_id', [1, 4])
          .eq('estado', true)
          .order('nombre_completo', ascending: true);

      final range = _visibleRange();
      final citas = await _supabase
          .from('citas_medicion')
          .select()
          .gte('fecha', DateFormat('yyyy-MM-dd').format(range.$1))
          .lte('fecha', DateFormat('yyyy-MM-dd').format(range.$2))
          .order('fecha', ascending: true)
          .order('hora_inicio', ascending: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _usuariosAsignables = List<Map<String, dynamic>>.from(usuarios);
        _citas = List<Map<String, dynamic>>.from(citas);
        _isLoading = false;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CitasMedicionScreen._cargarAgenda',
        uiContext: context,
      );
    }
  }

  (DateTime, DateTime) _visibleRange() {
    switch (_scope) {
      case CalendarScope.day:
        final date = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        return (date, date);
      case CalendarScope.week:
        final start = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final normalizedStart = DateTime(start.year, start.month, start.day);
        final end = normalizedStart.add(const Duration(days: 6));
        return (normalizedStart, end);
      case CalendarScope.month:
        final start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final end = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        return (start, end);
    }
  }

  void _changeScope(CalendarScope scope) {
    setState(() => _scope = scope);
    _cargarAgenda();
  }

  void _movePeriod(int direction) {
    setState(() {
      switch (_scope) {
        case CalendarScope.day:
          _selectedDate = _selectedDate.add(Duration(days: direction));
          break;
        case CalendarScope.week:
          _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
          break;
        case CalendarScope.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + direction,
            _selectedDate.day,
          );
          break;
      }
    });
    _cargarAgenda();
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
    _cargarAgenda();
  }

  Future<void> _crearCita() async {
    final creado = await showDialog<bool>(
      context: context,
      builder: (_) => _CrearCitaMedicionDialog(
        fechaInicial: _selectedDate,
        usuarios: _usuariosAsignables,
      ),
    );

    if (creado == true) {
      _cargarAgenda();
    }
  }

  Future<void> _editarCita(Map<String, dynamic> cita) async {
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (_) => _CrearCitaMedicionDialog(
        fechaInicial: DateTime.parse(cita['fecha']),
        usuarios: _usuariosAsignables,
        citaExistente: cita,
      ),
    );

    if (actualizado == true) {
      _cargarAgenda();
    }
  }

  Future<void> _cambiarEstadoCita(Map<String, dynamic> cita, String estado) async {
    if (estado == 'Completada') {
      final confirmado = await _confirmarCompletarCita(cita);
      if (confirmado != true) {
        return;
      }
    }

    try {
      await _supabase
          .from('citas_medicion')
          .update({'estado': estado})
          .eq('id', cita['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a $estado'),
          backgroundColor: GymTheme.neonGreen,
        ),
      );
      _cargarAgenda();
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CitasMedicionScreen._cambiarEstadoCita',
        uiContext: context,
      );
    }
  }

  Future<bool?> _confirmarCompletarCita(Map<String, dynamic> cita) {
    final userId = cita['persona_asignada_id']?.toString();
    final nombre = _nombreUsuario(userId);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GymTheme.darkGray,
        title: const Text(
          'MARCAR COMO COMPLETADA',
          style: TextStyle(color: GymTheme.neonGreen),
        ),
        content: Text(
          'Vas a marcar como completada la cita de $nombre '
          'programada para ${cita['fecha']} de ${cita['hora_inicio']} a ${cita['hora_fin']}.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarCita(Map<String, dynamic> cita) async {
    try {
      await _supabase.from('citas_medicion').delete().eq('id', cita['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita eliminada'),
          backgroundColor: GymTheme.neonGreen,
        ),
      );
      _cargarAgenda();
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CitasMedicionScreen._eliminarCita',
        uiContext: context,
      );
    }
  }

  List<Map<String, dynamic>> _citasParaDia(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return _citas.where((cita) {
      final sameDay = cita['fecha'] == key;
      final sameEstado = _estadoFiltro == 'Todos' ||
          (cita['estado'] ?? 'Programada').toString() == _estadoFiltro;
      return sameDay && sameEstado;
    }).toList();
  }

  String _nombreUsuario(String? userId) {
    if (userId == null) {
      return 'Sin asignar';
    }
    final match = _usuariosAsignables.cast<Map<String, dynamic>?>().firstWhere(
          (u) => u?['id'] == userId,
          orElse: () => null,
        );
    return match?['nombre_completo']?.toString() ?? 'Usuario desconocido';
  }

  String _rolUsuario(String? userId) {
    if (userId == null) {
      return '';
    }
    final match = _usuariosAsignables.cast<Map<String, dynamic>?>().firstWhere(
          (u) => u?['id'] == userId,
          orElse: () => null,
        );
    final rolId = match?['rol_id'];
    if (rolId == 1) return 'Gerente';
    if (rolId == 4) return 'Cliente';
    return '';
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'Completada':
        return GymTheme.neonGreen;
      case 'Cancelada':
        return Colors.redAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        backgroundColor: GymTheme.black,
        title: const Text('CITAS DE MEDICION'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: GymTheme.neonGreen),
            onPressed: _goToToday,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: GymTheme.neonGreen),
            onPressed: _cargarAgenda,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GymTheme.neonGreen,
        foregroundColor: Colors.black,
        onPressed: _crearCita,
        icon: const Icon(Icons.add),
        label: const Text(
          'NUEVA CITA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GymTheme.neonGreen),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildToolbar(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildCalendarBody()),
                ],
              ),
            ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _movePeriod(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  _periodTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _movePeriod(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<CalendarScope>(
            segments: const [
              ButtonSegment(
                value: CalendarScope.day,
                label: Text('Dia'),
                icon: Icon(Icons.view_day),
              ),
              ButtonSegment(
                value: CalendarScope.week,
                label: Text('Semana'),
                icon: Icon(Icons.view_week),
              ),
              ButtonSegment(
                value: CalendarScope.month,
                label: Text('Mes'),
                icon: Icon(Icons.calendar_month),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (value) => _changeScope(value.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return GymTheme.neonGreen;
                }
                return const Color(0xFF1E1E1E);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEstadoFiltroChip('Todos'),
              _buildEstadoFiltroChip('Programada'),
              _buildEstadoFiltroChip('Completada'),
              _buildEstadoFiltroChip('Cancelada'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoFiltroChip(String estado) {
    final isSelected = _estadoFiltro == estado;
    final color = estado == 'Todos' ? Colors.white70 : _estadoColor(estado);

    return ChoiceChip(
      label: Text(estado),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: const Color(0xFF1E1E1E),
      labelStyle: TextStyle(
        color: isSelected
            ? (estado == 'Todos' ? Colors.black : Colors.black)
            : color,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(color: color.withOpacity(0.5)),
      onSelected: (_) {
        setState(() => _estadoFiltro = estado);
      },
    );
  }

  Widget _buildCalendarBody() {
    switch (_scope) {
      case CalendarScope.day:
        return _buildDayView();
      case CalendarScope.week:
        return _buildWeekView();
      case CalendarScope.month:
        return _buildMonthView();
    }
  }

  Widget _buildDayView() {
    final citas = _citasParaDia(_selectedDate);
    return _buildAgendaList(_selectedDate, citas);
  }

  Widget _buildWeekView() {
    final start = _visibleRange().$1;
    return ListView.separated(
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final date = start.add(Duration(days: index));
        return _buildAgendaList(date, _citasParaDia(date), compact: true);
      },
    );
  }

  Widget _buildMonthView() {
    final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final firstWeekdayOffset = monthStart.weekday - 1;
    final gridStart = monthStart.subtract(Duration(days: firstWeekdayOffset));

    return Column(
      children: [
        Row(
          children: const [
            _WeekdayHeader('Lun'),
            _WeekdayHeader('Mar'),
            _WeekdayHeader('Mie'),
            _WeekdayHeader('Jue'),
            _WeekdayHeader('Vie'),
            _WeekdayHeader('Sab'),
            _WeekdayHeader('Dom'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.05,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = gridStart.add(Duration(days: index));
              final citas = _citasParaDia(day);
              final isCurrentMonth = day.month == _selectedDate.month;
              final isSelected = DateUtils.isSameDay(day, _selectedDate);
              final colorPrincipal = citas.isEmpty
                  ? null
                  : _estadoColor((citas.first['estado'] ?? 'Programada').toString());

              return InkWell(
                onTap: () {
                  setState(() => _selectedDate = day);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GymTheme.neonGreen.withOpacity(0.16)
                        : const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? GymTheme.neonGreen
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isCurrentMonth ? Colors.white : Colors.white30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (citas.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorPrincipal!.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${citas.length} cita(s)',
                            style: TextStyle(
                              color: colorPrincipal,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildAgendaList(
            _selectedDate,
            _citasParaDia(_selectedDate),
            titleOverride: 'Detalle del dia seleccionado',
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaList(
    DateTime date,
    List<Map<String, dynamic>> citas, {
    bool compact = false,
    String? titleOverride,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleOverride ?? DateFormat('EEEE dd MMMM yyyy').format(date),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (citas.isEmpty)
            Text(
              'No hay citas programadas.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: compact ? 12 : 13,
              ),
            )
          else
            ...citas.map((cita) {
              final userId = cita['persona_asignada_id']?.toString();
              final nombre = _nombreUsuario(userId);
              final rol = _rolUsuario(userId);
              final estado = (cita['estado'] ?? 'Programada').toString();
              final estaCompletada = estado == 'Completada';
              final estadoColor = _estadoColor(estado);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: estadoColor.withOpacity(0.45)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: estadoColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cita['hora_inicio']} - ${cita['hora_fin']}',
                            style: TextStyle(
                              color: estadoColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (rol.isNotEmpty)
                            Text(
                              rol,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _EstadoCitaChip(estado: estado),
                              TextButton.icon(
                                onPressed: estaCompletada
                                    ? null
                                    : () => _editarCita(cita),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Editar'),
                              ),
                              PopupMenuButton<String>(
                                color: GymTheme.darkGray,
                                onSelected: (value) {
                                  if (value == 'Eliminar') {
                                    _eliminarCita(cita);
                                  } else {
                                    _cambiarEstadoCita(cita, value);
                                  }
                                },
                                itemBuilder: (context) => estaCompletada
                                    ? const [
                                        PopupMenuItem(
                                          value: 'Programada',
                                          child: Text('Marcar Programada'),
                                        ),
                                        PopupMenuItem(
                                          value: 'Cancelada',
                                          child: Text('Marcar Cancelada'),
                                        ),
                                      ]
                                    : const [
                                        PopupMenuItem(
                                          value: 'Programada',
                                          child: Text('Marcar Programada'),
                                        ),
                                        PopupMenuItem(
                                          value: 'Completada',
                                          child: Text('Marcar Completada'),
                                        ),
                                        PopupMenuItem(
                                          value: 'Cancelada',
                                          child: Text('Marcar Cancelada'),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'Eliminar',
                                          child: Text('Eliminar cita'),
                                        ),
                                      ],
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.more_horiz,
                                        color: estaCompletada
                                            ? Colors.white38
                                            : Colors.white70,
                                        size: 18,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Acciones',
                                        style: TextStyle(
                                          color: estaCompletada
                                              ? Colors.white38
                                              : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((cita['notas'] ?? '').toString().trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                cita['notas'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _periodTitle() {
    switch (_scope) {
      case CalendarScope.day:
        return DateFormat('dd MMMM yyyy').format(_selectedDate);
      case CalendarScope.week:
        final range = _visibleRange();
        return '${DateFormat('dd MMM').format(range.$1)} - ${DateFormat('dd MMM yyyy').format(range.$2)}';
      case CalendarScope.month:
        return DateFormat('MMMM yyyy').format(_selectedDate);
    }
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;

  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white54,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CrearCitaMedicionDialog extends StatefulWidget {
  final DateTime fechaInicial;
  final List<Map<String, dynamic>> usuarios;
  final Map<String, dynamic>? citaExistente;

  const _CrearCitaMedicionDialog({
    required this.fechaInicial,
    required this.usuarios,
    this.citaExistente,
  });

  @override
  State<_CrearCitaMedicionDialog> createState() =>
      _CrearCitaMedicionDialogState();
}

class _CrearCitaMedicionDialogState extends State<_CrearCitaMedicionDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  bool _isLoading = false;
  late DateTime _fechaSeleccionada;
  String? _personaAsignadaId;
  TimeOfDay _horaInicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = DateTime(
      widget.fechaInicial.year,
      widget.fechaInicial.month,
      widget.fechaInicial.day,
    );
    final cita = widget.citaExistente;
    if (cita != null) {
      _personaAsignadaId = cita['persona_asignada_id']?.toString();
      _notasCtrl.text = (cita['notas'] ?? '').toString();
      _horaInicio = _parseTime(cita['hora_inicio']?.toString() ?? '08:00:00');
      _horaFin = _parseTime(cita['hora_fin']?.toString() ?? '09:00:00');
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!_horaEsValida()) {
        throw const FormatException(
          'La hora final debe ser mayor que la hora inicial.',
        );
      }

      final hayConflicto = await _existeTraslape();
      if (hayConflicto) {
        throw const FormatException(
          'Ya existe una cita para esta persona en ese rango horario.',
        );
      }

      final payload = {
        'fecha': DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
        'hora_inicio': _formatTime(_horaInicio),
        'hora_fin': _formatTime(_horaFin),
        'persona_asignada_id': _personaAsignadaId,
        'notas': _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      };

      if (widget.citaExistente == null) {
        await _supabase.from('citas_medicion').insert({
          ...payload,
          'creado_por': _supabase.auth.currentUser?.id,
        });
      } else {
        await _supabase
            .from('citas_medicion')
            .update(payload)
            .eq('id', widget.citaExistente!['id']);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'CrearCitaMedicionDialog._guardar',
        uiContext: context,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _horaEsValida() {
    final inicio = _horaInicio.hour * 60 + _horaInicio.minute;
    final fin = _horaFin.hour * 60 + _horaFin.minute;
    return fin > inicio;
  }

  Future<bool> _existeTraslape() async {
    if (_personaAsignadaId == null || _personaAsignadaId!.isEmpty) {
      return false;
    }

    final fecha = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
    final inicio = _formatTime(_horaInicio);
    final fin = _formatTime(_horaFin);

    final data = await _supabase
        .from('citas_medicion')
        .select('id, hora_inicio, hora_fin')
        .eq('fecha', fecha)
        .eq('persona_asignada_id', _personaAsignadaId!)
        .lt('hora_inicio', fin)
        .gt('hora_fin', inicio)
        .neq('id', widget.citaExistente?['id'] ?? -1)
        .limit(1);

    return (data as List).isNotEmpty;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _fechaSeleccionada = date);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _horaInicio : _horaFin,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _horaInicio = picked;
        } else {
          _horaFin = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GymTheme.darkGray,
      title: Text(
        widget.citaExistente == null
            ? 'NUEVA CITA DE MEDICION'
            : 'EDITAR CITA DE MEDICION',
        style: const TextStyle(color: GymTheme.neonGreen),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_today,
                    color: GymTheme.neonGreen,
                  ),
                  title: const Text(
                    'Fecha',
                    style: TextStyle(color: Colors.white70),
                  ),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: TextButton(
                    onPressed: _pickDate,
                    child: const Text('Cambiar'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TimeCard(
                        label: 'Hora Inicio',
                        value: _horaInicio.format(context),
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeCard(
                        label: 'Hora Fin',
                        value: _horaFin.format(context),
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _personaAsignadaId,
                  dropdownColor: GymTheme.darkGray,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Asignar a',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: widget.usuarios.map((usuario) {
                    final rol = usuario['rol_id'] == 1 ? 'Gerente' : 'Cliente';
                    return DropdownMenuItem<String>(
                      value: usuario['id'],
                      child: Text('${usuario['nombre_completo']} - $rol'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _personaAsignadaId = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona una persona';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notasCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _guardar,
          child: _isLoading
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

class _EstadoCitaChip extends StatelessWidget {
  final String estado;

  const _EstadoCitaChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'Completada' => GymTheme.neonGreen,
      'Cancelada' => Colors.redAccent,
      _ => Colors.lightBlueAccent,
    };

    return Chip(
      label: Text(
        estado,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(10),
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
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

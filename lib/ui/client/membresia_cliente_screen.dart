import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';

class MembresiaClienteScreen extends StatefulWidget {
  const MembresiaClienteScreen({super.key});

  @override
  State<MembresiaClienteScreen> createState() => _MembresiaClienteScreenState();
}

class _MembresiaClienteScreenState extends State<MembresiaClienteScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _perfil;
  List<Map<String, dynamic>> _historial = [];
  double _precioMensual = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosCliente();
  }

  Future<void> _cargarDatosCliente() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final perfilData = await Supabase.instance.client
          .from('perfiles')
          .select()
          .eq('id', user.id)
          .single();

      final historialData = await Supabase.instance.client
          .from('historial_membresia')
          .select()
          .eq('cedula_cliente', perfilData['cedula'])
          .order('fecha_registro', ascending: false);

      final precioData = await Supabase.instance.client
          .from('configuracion_precios')
          .select('precio_mensual')
          .eq('id', 1)
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _perfil = perfilData;
        _historial = List<Map<String, dynamic>>.from(historialData);
        _precioMensual = (precioData['precio_mensual'] as num).toDouble();
        _isLoading = false;
      });
    } catch (e, stack) {
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'MembresiaClienteScreen._cargarDatosCliente',
        uiContext: context,
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: GymTheme.black,
        body: Center(
          child: CircularProgressIndicator(color: GymTheme.neonGreen),
        ),
      );
    }

    final estado = _perfil?['estado_membresia'] ?? 'Sin pendientes';
    final fechaCobro = _perfil?['fecha_proximo_cobro'];

    return Scaffold(
      backgroundColor: GymTheme.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            backgroundColor: GymTheme.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      GymTheme.neonGreen.withOpacity(0.2),
                      GymTheme.black,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'MI ESTADO',
                      style: TextStyle(
                        color: Colors.white54,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        color: _getColorEstado(estado),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: _getColorEstado(estado).withOpacity(0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    'Siguiente fecha de cobro',
                    fechaCobro != null
                        ? DateFormat('dd MMMM, yyyy')
                            .format(DateTime.parse(fechaCobro))
                        : 'No definida',
                    Icons.calendar_month,
                  ),
                  const SizedBox(height: 15),
                  _buildInfoCard(
                    'Precio Mensual Actual',
                    'CRC ${_precioMensual.toStringAsFixed(0)}',
                    Icons.sell_outlined,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'HISTORIAL DE PAGOS Y ACCIONES',
                    style: TextStyle(
                      color: GymTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final evento = _historial[index];
              return _buildTimelineItem(evento);
            }, childCount: _historial.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: GymTheme.neonGreen, size: 30),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> evento) {
    final fecha = DateTime.parse(evento['fecha_registro']);
    final esPago = evento['tipo_evento'] == 'PAGO';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: esPago ? GymTheme.neonGreen : Colors.blueGrey,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 50, color: Colors.white10),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        evento['tipo_evento'],
                        style: TextStyle(
                          color: esPago ? GymTheme.neonGreen : Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(fecha),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    evento['detalle'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  if (esPago)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Monto: CRC ${(evento['monto'] as num).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'Sin pendientes':
        return GymTheme.neonGreen;
      case 'Pago pendiente':
        return Colors.orangeAccent;
      case 'Membresia cancelada':
        return Colors.redAccent;
      case 'Membresia pausada':
        return Colors.blueGrey;
      default:
        return Colors.white;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';
import '../../core/widgets/reload_error_state.dart';

class HistorialPagosClienteScreen extends StatefulWidget {
  const HistorialPagosClienteScreen({super.key});

  @override
  State<HistorialPagosClienteScreen> createState() =>
      _HistorialPagosClienteScreenState();
}

class _HistorialPagosClienteScreenState
    extends State<HistorialPagosClienteScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  String? _nombreCliente;
  List<Map<String, dynamic>> _pagos = [];

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AuthException('La sesion no esta disponible.');
      }

      final perfil = await _supabase
          .from('perfiles')
          .select('cedula, nombre_completo')
          .eq('id', user.id)
          .single();

      final cedula = perfil['cedula']?.toString();
      List<Map<String, dynamic>> pagos = [];

      if (cedula != null && cedula.isNotEmpty) {
        final data = await _supabase
            .from('historial_membresia')
            .select()
            .eq('cedula_cliente', cedula)
            .eq('tipo_evento', 'PAGO')
            .order('fecha_registro', ascending: false);
        pagos = List<Map<String, dynamic>>.from(data);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _nombreCliente = perfil['nombre_completo']?.toString();
        _pagos = pagos;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudo cargar el historial de pagos.';
        });
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'HistorialPagosClienteScreen._cargarPagos',
        uiContext: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('HISTORIAL DE PAGOS'),
        backgroundColor: GymTheme.black,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargarPagos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GymTheme.neonGreen),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ReloadErrorState(
                      message: _errorMessage!,
                      onRetry: _cargarPagos,
                    ),
                  ),
                )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return RefreshIndicator(
                  color: GymTheme.neonGreen,
                  onRefresh: _cargarPagos,
                  child: ListView(
                    padding: EdgeInsets.all(isWide ? 28 : 16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      if (_pagos.isEmpty)
                        _buildEmptyState()
                      else if (isWide)
                        _buildDesktopTable()
                      else
                        ..._pagos.map(_buildMobileCard),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeader() {
    final ultimoPago = _pagos.isNotEmpty
        ? DateTime.tryParse(_pagos.first['fecha_registro']?.toString() ?? '')
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CLIENTE',
                style: TextStyle(color: Colors.white54, letterSpacing: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                _nombreCliente?.trim().isNotEmpty == true
                    ? _nombreCliente!
                    : 'Sin nombre',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderStat('Total pagos', '${_pagos.length}'),
              const SizedBox(width: 16),
              _buildHeaderStat(
                'Ultimo pago',
                ultimoPago == null
                    ? 'Sin registros'
                    : DateFormat('dd/MM/yyyy').format(ultimoPago),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: GymTheme.neonGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: Colors.white38, size: 52),
          SizedBox(height: 12),
          Text(
            'No hay pagos registrados',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Cuando se registre un pago para este cliente aparecera aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: DataTable(
        headingTextStyle: const TextStyle(
          color: GymTheme.neonGreen,
          fontWeight: FontWeight.bold,
        ),
        dataTextStyle: const TextStyle(color: Colors.white70),
        columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Monto')),
          DataColumn(label: Text('Metodo')),
          DataColumn(label: Text('Detalle')),
        ],
        rows: _pagos.map((pago) {
          final fecha = DateTime.tryParse(pago['fecha_registro']?.toString() ?? '');
          final monto = (pago['monto'] as num?)?.toDouble();
          return DataRow(
            cells: [
              DataCell(
                Text(
                  fecha == null
                      ? 'Sin fecha'
                      : DateFormat('dd/MM/yyyy hh:mm a').format(fecha.toLocal()),
                ),
              ),
              DataCell(Text(_formatCurrency(monto))),
              DataCell(Text(pago['metodo_pago']?.toString() ?? 'No definido')),
              DataCell(
                SizedBox(
                  width: 360,
                  child: Text(
                    pago['detalle']?.toString() ?? 'Sin detalle',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> pago) {
    final fecha = DateTime.tryParse(pago['fecha_registro']?.toString() ?? '');
    final monto = (pago['monto'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: GymTheme.neonGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: GymTheme.neonGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(monto),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fecha == null
                          ? 'Sin fecha'
                          : DateFormat('dd/MM/yyyy hh:mm a').format(fecha.toLocal()),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDetailLine('Metodo', pago['metodo_pago']?.toString() ?? 'No definido'),
          const SizedBox(height: 8),
          _buildDetailLine('Detalle', pago['detalle']?.toString() ?? 'Sin detalle'),
        ],
      ),
    );
  }

  Widget _buildDetailLine(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: GymTheme.neonGreen,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  String _formatCurrency(double? value) {
    if (value == null) {
      return 'CRC 0';
    }
    return 'CRC ${value.toStringAsFixed(0)}';
  }
}

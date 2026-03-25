import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_handler.dart';
import '../../core/theme.dart';
import '../../core/widgets/reload_error_state.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  int _comparisonYear = DateTime.now().year;
  int _comparisonMonth = DateTime.now().month;
  int _annualYear = DateTime.now().year;
  _MonthlyComparisonData? _monthlyData;
  List<double> _annualTotals = List<double>.filled(12, 0);

  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List<int>.generate(6, (index) => currentYear - index);
  }

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final comparison = await _fetchMonthlyComparison(
        year: _comparisonYear,
        month: _comparisonMonth,
      );
      final annual = await _fetchAnnualTotals(_annualYear);

      if (!mounted) {
        return;
      }

      setState(() {
        _monthlyData = comparison;
        _annualTotals = annual;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudieron cargar las estadisticas.';
        });
      }
      await AppErrorHandler.handle(
        e,
        stack,
        context: 'EstadisticasScreen._loadStatistics',
        uiContext: context,
      );
    }
  }

  Future<_MonthlyComparisonData> _fetchMonthlyComparison({
    required int year,
    required int month,
  }) async {
    final currentStart = DateTime(year, month, 1);
    final currentEnd = DateTime(year, month + 1, 1).subtract(
      const Duration(milliseconds: 1),
    );
    final previousStart = DateTime(year, month - 1, 1);
    final previousEnd = currentStart.subtract(const Duration(milliseconds: 1));

    final data = await _supabase
        .from('historial_membresia')
        .select('fecha_registro, monto')
        .eq('tipo_evento', 'PAGO')
        .gte('fecha_registro', previousStart.toIso8601String())
        .lte('fecha_registro', currentEnd.toIso8601String());

    final rows = List<Map<String, dynamic>>.from(data);
    double currentTotal = 0;
    double previousTotal = 0;

    for (final row in rows) {
      final fecha = DateTime.tryParse(row['fecha_registro']?.toString() ?? '');
      if (fecha == null) {
        continue;
      }

      final amount = (row['monto'] as num?)?.toDouble() ?? 0;
      if (!fecha.isBefore(currentStart) && !fecha.isAfter(currentEnd)) {
        currentTotal += amount;
      } else if (!fecha.isBefore(previousStart) && !fecha.isAfter(previousEnd)) {
        previousTotal += amount;
      }
    }

    final difference = currentTotal - previousTotal;
    double percentageChange;
    if (previousTotal == 0) {
      percentageChange = currentTotal == 0 ? 0 : 100;
    } else {
      percentageChange = (difference / previousTotal) * 100;
    }

    return _MonthlyComparisonData(
      currentTotal: currentTotal,
      previousTotal: previousTotal,
      difference: difference,
      percentageChange: percentageChange,
      currentLabel: _monthLabel(currentStart),
      previousLabel: _monthLabel(previousStart),
    );
  }

  Future<List<double>> _fetchAnnualTotals(int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1).subtract(
      const Duration(milliseconds: 1),
    );

    final data = await _supabase
        .from('historial_membresia')
        .select('fecha_registro, monto')
        .eq('tipo_evento', 'PAGO')
        .gte('fecha_registro', start.toIso8601String())
        .lte('fecha_registro', end.toIso8601String());

    final totals = List<double>.filled(12, 0);
    for (final row in List<Map<String, dynamic>>.from(data)) {
      final fecha = DateTime.tryParse(row['fecha_registro']?.toString() ?? '');
      if (fecha == null || fecha.year != year) {
        continue;
      }
      totals[fecha.month - 1] += (row['monto'] as num?)?.toDouble() ?? 0;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymTheme.black,
      appBar: AppBar(
        title: const Text('ESTADISTICAS'),
        backgroundColor: GymTheme.black,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadStatistics,
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
                      onRetry: _loadStatistics,
                    ),
                  ),
                )
          : RefreshIndicator(
              color: GymTheme.neonGreen,
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMonthlyComparisonCard(),
                  const SizedBox(height: 20),
                  _buildAnnualChartCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthlyComparisonCard() {
    final data = _monthlyData;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final positive = data.difference >= 0;
    final trendColor = positive ? GymTheme.neonGreen : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'COMPARACION MENSUAL',
                style: TextStyle(
                  color: GymTheme.neonGreen,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMonthDropdown(),
                  _buildYearDropdown(
                    value: _comparisonYear,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _comparisonYear = value);
                      _loadStatistics();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  title: data.currentLabel,
                  value: _formatCurrency(data.currentTotal),
                  color: GymTheme.neonGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  title: data.previousLabel,
                  value: _formatCurrency(data.previousTotal),
                  color: Colors.lightBlueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: trendColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${positive ? '+' : ''}${data.percentageChange.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: trendColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Diferencia: ${_formatCurrency(data.difference)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualChartCard() {
    final totalAnnual = _annualTotals.fold<double>(0, (sum, value) => sum + value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GymTheme.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'GANANCIAS ANUALES',
                style: TextStyle(
                  color: GymTheme.neonGreen,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              _buildYearDropdown(
                value: _annualYear,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _annualYear = value);
                  _loadStatistics();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Total anual: ${_formatCurrency(totalAnnual)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: _AnnualBarChart(values: _annualTotals),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(12, (index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  '${_shortMonth(index + 1)}: ${_formatCurrency(_annualTotals[index])}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _comparisonMonth,
          dropdownColor: GymTheme.darkGray,
          style: const TextStyle(color: Colors.white),
          items: List.generate(12, (index) {
            final month = index + 1;
            return DropdownMenuItem(
              value: month,
              child: Text(_monthName(month)),
            );
          }),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _comparisonMonth = value);
            _loadStatistics();
          },
        ),
      ),
    );
  }

  Widget _buildYearDropdown({
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          dropdownColor: GymTheme.darkGray,
          style: const TextStyle(color: Colors.white),
          items: _availableYears.map((year) {
            return DropdownMenuItem(
              value: year,
              child: Text(year.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }

  String _shortMonth(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return months[month - 1];
  }

  String _monthLabel(DateTime date) {
    return '${_monthName(date.month)} ${date.year}';
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat.decimalPattern('es');
    final absolute = formatter.format(value.abs().round());
    return value < 0 ? '-CRC $absolute' : 'CRC $absolute';
  }
}

class _MonthlyComparisonData {
  const _MonthlyComparisonData({
    required this.currentTotal,
    required this.previousTotal,
    required this.difference,
    required this.percentageChange,
    required this.currentLabel,
    required this.previousLabel,
  });

  final double currentTotal;
  final double previousTotal;
  final double difference;
  final double percentageChange;
  final String currentLabel;
  final String previousLabel;
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnualBarChart extends StatelessWidget {
  const _AnnualBarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 0 : values.reduce(math.max);
    final chartMax = maxValue <= 0 ? 1.0 : maxValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(12, (index) {
        final value = values[index];
        final factor = value / chartMax;
        final barColor = value == 0
            ? Colors.white24
            : Color.lerp(
                Colors.lightBlueAccent,
                GymTheme.neonGreen,
                factor.clamp(0, 1),
              )!;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  value == 0 ? '0' : _compactValue(value),
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: math.max(6, 180 * factor),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _shortMonthLabel(index + 1),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  static String _shortMonthLabel(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return months[month - 1];
  }

  static String _compactValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

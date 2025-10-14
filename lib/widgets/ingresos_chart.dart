import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class IngresosStackedBarChart extends StatelessWidget {
  final Map<String, List<double>> data;
  const IngresosStackedBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    const categorias = ['Capital','Interés','Mora','Seguro','Otros','Gastos'];

    final groups = <BarChartGroupData>[];
    double maxValor = 0;

    // Construcción de grupos con tolerancia a datos faltantes
    for (int i = 0; i < 12; i++) {
      double running = 0;
      final rods = <BarChartRodStackItem>[];

      for (final cat in categorias) {
        final list = data[cat];
        // list puede ser null o más corta que 12; cada item es double (no null)
        final v = (list != null && i < list.length) ? list[i] : 0.0;
        rods.add(BarChartRodStackItem(running, running + v, _colorFor(cat)));
        running += v;
      }

      if (running > maxValor) maxValor = running;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: running,
              rodStackItems: rods,
              width: 14,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    // Si todo es cero, muestra una grilla placeholder
    if (maxValor == 0) {
      return SizedBox(
        height: 280,
        child: BarChart(
          BarChartData(
            maxY: 1,
            barGroups: groups,
            gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(i >= 0 && i < 12 ? meses[i] : ''),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      );
    }

    final maxY = (maxValor * 1.2).clamp(1, double.infinity).toDouble();
    final step = (maxY / 5).clamp(1, double.infinity).toDouble();

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: groups,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: step),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(_abbrMoney(v)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(i >= 0 && i < 12 ? meses[i] : ''),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final i = group.x.toInt();
                final mes = (i >= 0 && i < 12) ? meses[i] : '';
                return BarTooltipItem(
                  '$mes\n${_abbrMoney(rod.toY)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _abbrMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  Color _colorFor(String cat) {
    switch (cat) {
      case 'Capital': return Colors.blue;
      case 'Interés': return Colors.teal;
      case 'Mora': return Colors.red;
      case 'Seguro': return Colors.orange;
      case 'Otros': return Colors.purple;
      case 'Gastos': return Colors.green;
      default: return Colors.grey;
    }
  }
}

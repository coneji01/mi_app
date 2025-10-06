import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class IngresosStackedBarChart extends StatelessWidget {
  final Map<String, List<double>> data;
  const IngresosStackedBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final meses = const ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final categorias = ['Capital','Interés','Mora','Seguro','Otros','Gastos'];

    List<BarChartGroupData> groups = [];
    for (int i = 0; i < 12; i++) {
      double running = 0;
      final rods = <BarChartRodStackItem>[];
      for (final cat in categorias) {
        final v = (data[cat]?[i] ?? 0).toDouble();
        rods.add(BarChartRodStackItem(running, running + v, _colorFor(cat)));
        running += v;
      }
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: running,
            rodStackItems: rods,
            width: 14,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ));
    }

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: groups,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(meses[i % 12]),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
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


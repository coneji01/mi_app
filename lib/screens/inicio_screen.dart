import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_drawer.dart';
import '../data/db_service.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final _db = DbService.instance;

  bool _loading = true;
  String? _error;

  // Filtros (año/mes seleccionados)
  late int _year;
  late int _month;

  // Datos
  ({int activos, int total})? _clientes;
  ({int activos, int total})? _prestamos;
  double _totalPrestado = 0;
  double _proyInteresMes = 0;
  ({double ingreso, double egreso}) _ingEg = (ingreso: 0, egreso: 0);
  Map<int, Map<String, double>> _ingresosPorMes = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final clientes = await _db.conteoClientesActivosYTotal();
      final prestamos = await _db.conteoPrestamosActivosYTotal();
      final totalPrestado = await _db.totalPrestado();
      final proy = await _db.proyeccionInteresMes(_year, _month);
      final ie = await _db.ingresoEgresoMes(_year, _month);
      final bars = await _db.resumenPagosPorMesDelAnio(_year);

      if (!mounted) return;
      setState(() {
        _clientes = clientes;
        _prestamos = prestamos;
        _totalPrestado = totalPrestado;
        _proyInteresMes = proy;
        _ingEg = ie;
        _ingresosPorMes = bars;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _money(num v) {
    final d = v.toDouble();
    final s = d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'RD\$$intPart${parts.length > 1 && parts[1] != '00' ? '.${parts[1]}' : ''}';
  }

  List<DropdownMenuItem<int>> _yearItems() {
    final y = DateTime.now().year;
    return List.generate(6, (i) => y - 2 + i)
        .map((yy) => DropdownMenuItem(value: yy, child: Text('$yy')))
        .toList();
  }

  List<DropdownMenuItem<int>> _monthItems() {
    const meses = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sep.', 'oct.', 'nov.', 'dic.'];
    return List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(meses[i])));
  }

  // ================= UI ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: AppSection.inicio),
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _filtros(context),
                      const SizedBox(height: 8),
                      _statsGrid(context),
                      const SizedBox(height: 12),
                      _graficoCard(context),
                    ],
                  ),
                )),
    );
  }

  Widget _filtros(BuildContext context) {
    return Row(
      children: [
        // Mes
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Mes',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _month,
                isExpanded: true,
                items: _monthItems(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _month = v);
                  _load();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Año
        SizedBox(
          width: 120,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Año',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _year,
                isExpanded: true,
                items: _yearItems(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _year = v);
                  _load();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String top, String bottom) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(top, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(bottom, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _statsGrid(BuildContext context) {
    final cl = _clientes ?? (activos: 0, total: 0);
    final pr = _prestamos ?? (activos: 0, total: 0);

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      children: [
        _statBox('${cl.activos} de ${cl.total}', 'Clientes Activos'),
        _statBox('${pr.activos} de ${pr.total}', 'Préstamos Activos'),
        _statBox(_money(_totalPrestado), 'Total Prestado'),
        _statBox(_money(_proyInteresMes), 'Proyección Interés'),
        _statBox(_money(_ingEg.ingreso), 'Ingreso'),
        _statBox(_money(_ingEg.egreso), 'Egresos'),
      ],
    );
  }

  Widget _graficoCard(BuildContext context) {
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ingresos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SizedBox(height: 280, child: _barChart()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: const [
                _Legend(color: Color(0xFF1E88E5), label: 'Capital'),
                _Legend(color: Color(0xFF26A69A), label: 'Interés'),
                _Legend(color: Color(0xFFE53935), label: 'Mora'),
                _Legend(color: Color(0xFFFFB300), label: 'Seguro'),
                _Legend(color: Color(0xFF7E57C2), label: 'Otros'),
                _Legend(color: Color(0xFF8D6E63), label: 'Gastos'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BarChart _barChart() {
    // Colores por categoría (coinciden con la leyenda)
    const capitalC = Color(0xFF1E88E5);
    const interesC = Color(0xFF26A69A);
    const moraC    = Color(0xFFE53935);
    const seguroC  = Color(0xFFFFB300);
    const otrosC   = Color(0xFF7E57C2);
    const gastosC  = Color(0xFF8D6E63);

    List<BarChartGroupData> groups = [];
    for (int m = 1; m <= 12; m++) {
      final mm = _ingresosPorMes[m] ?? const {
        'capital': 0, 'interes': 0, 'mora': 0, 'seguro': 0, 'otros': 0, 'gastos': 0,
      };

      final cap = (mm['capital'] ?? 0).toDouble();
      final intx = (mm['interes'] ?? 0).toDouble();
      final mor = (mm['mora'] ?? 0).toDouble();
      final seg = (mm['seguro'] ?? 0).toDouble();
      final otr = (mm['otros'] ?? 0).toDouble();
      final gas = (mm['gastos'] ?? 0).toDouble();

      final total = cap + intx + mor + seg + otr + gas;
      double cursor = 0;

      final stacks = <BarChartRodStackItem>[
        if (cap > 0)  BarChartRodStackItem(cursor, cursor += cap, capitalC),
        if (intx > 0) BarChartRodStackItem(cursor, cursor += intx, interesC),
        if (mor > 0)  BarChartRodStackItem(cursor, cursor += mor, moraC),
        if (seg > 0)  BarChartRodStackItem(cursor, cursor += seg, seguroC),
        if (otr > 0)  BarChartRodStackItem(cursor, cursor += otr, otrosC),
        if (gas > 0)  BarChartRodStackItem(cursor, cursor += gas, gastosC),
      ];

      groups.add(
        BarChartGroupData(
          x: m,
          barRods: [
            BarChartRodData(
              toY: total,
              rodStackItems: stacks,
              width: 14,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

    return BarChart(
      BarChartData(
        barGroups: groups,
        gridData: FlGridData(show: true, horizontalInterval: 20000),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(_abbrMoney(v)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 1 || i > 12) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(meses[i - 1]),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  static String _abbrMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

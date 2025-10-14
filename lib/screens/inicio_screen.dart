// lib/screens/inicio_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/app_drawer.dart';
import '../data/repository.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});
  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  bool _loading = true;
  String? _error;

  late int _year;
  late int _month;

  ({int activos, int total})? _clientes;
  ({int activos, int total})? _prestamos;
  double _totalPrestado = 0;
  double _proyInteresMes = 0;

  // Ingreso/Egreso "legacy" del backend (mantenido por compatibilidad)
  ({double ingreso, double egreso}) _ingEg = (ingreso: 0, egreso: 0);

  /// mes -> rubros normalizados: capital, interes, mora, seguro, otros, gastos
  Map<int, Map<String, double>> _ingresosPorMes = {};

  // Filtro por rubro (null = stacked completo)
  String? _categoriaSeleccionada;

  // ───────── Helpers ─────────
  double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  String _normalizeCat(String raw) {
    var k = raw.trim().toLowerCase();
    k = k
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    switch (k) {
      case 'capital':
        return 'capital';
      case 'interes':
        return 'interes';
      case 'mora':
        return 'mora';
      case 'seguro':
        return 'seguro';
      case 'gastos':
        return 'gastos';
      case 'otro':
      case 'otros':
        return 'otros';
      default:
        return 'otros';
    }
  }

  int _mKey(dynamic k) {
    final n = int.tryParse(k.toString());
    if (n == null) return 0;
    if (n >= 1 && n <= 12) return n;
    if (n >= 0 && n <= 11) return n + 1; // zero-based backend
    return 0;
  }

  Map<int, Map<String, double>> _mesesVacios() => {
        for (var m = 1; m <= 12; m++)
          m: {
            'capital': 0,
            'interes': 0,
            'mora': 0,
            'seguro': 0,
            'otros': 0,
            'gastos': 0,
          }
      };

  void _accumMonth(Map<int, Map<String, double>> target, int mes, Map src) {
    final base = target[mes] ??
        {
          'capital': 0,
          'interes': 0,
          'mora': 0,
          'seguro': 0,
          'otros': 0,
          'gastos': 0,
        };
    for (final e in src.entries) {
      final cat = _normalizeCat('${e.key}');
      base[cat] = (base[cat] ?? 0) + _d(e.value);
    }
    target[mes] = base;
  }

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
      final dash = await Repository.i.dashboard(year: _year, month: _month);

      Map<String, dynamic> _m(Map? x) =>
          (x ?? const {}) as Map<String, dynamic>;

      final cl = _m(dash['clientes']);
      final pr = _m(dash['prestamos']);

      final byMonth = _mesesVacios();
      final src = dash['ingresos_por_mes'];

      if (src is Map) {
        for (final k in src.keys) {
          final mes = _mKey(k);
          if (mes < 1 || mes > 12) continue;
          final mapMes = src[k];
          if (mapMes is Map) _accumMonth(byMonth, mes, mapMes);
        }
      } else if (src is List) {
        for (final it in src) {
          if (it is! Map) continue;
          final mes = _mKey(it['mes']);
          if (mes < 1 || mes > 12) continue;
          final copy = Map.of(it)..remove('mes');
          _accumMonth(byMonth, mes, copy);
        }
      }

      if (!mounted) return;
      setState(() {
        _clientes = (
          activos: (cl['activos'] as num? ?? 0).toInt(),
          total: (cl['total'] as num? ?? 0).toInt()
        );
        _prestamos = (
          activos: (pr['activos'] as num? ?? 0).toInt(),
          total: (pr['total'] as num? ?? 0).toInt()
        );
        _totalPrestado = _d(dash['total_prestado']);
        _proyInteresMes = _d(dash['proyeccion_interes_mes']);
        _ingEg = (
          ingreso: _d(dash['ingreso_mes']),
          egreso: _d(dash['egreso_mes'])
        );
        _ingresosPorMes = byMonth;
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
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'RD\$$intPart${parts.length > 1 && parts[1] != '00' ? '.${parts[1]}' : ''}';
  }

  static String _abbrMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  List<DropdownMenuItem<int>> _yearItems() {
    final y = DateTime.now().year;
    return List.generate(6, (i) => y - 2 + i)
        .map((yy) => DropdownMenuItem(value: yy, child: Text('$yy')))
        .toList();
  }

  List<DropdownMenuItem<int>> _monthItems() {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sep.', 'oct.', 'nov.', 'dic.'
    ];
    return List.generate(
        12, (i) => DropdownMenuItem(value: i + 1, child: Text(meses[i])));
  }

  // ——— Sumas rápidas por mes/categoría ———
  double _mesCat(int mes, String cat) => _d(_ingresosPorMes[mes]?[cat] ?? 0);
  double get _capitalMesActual => _mesCat(_month, 'capital');
  double get _interesMesActual => _mesCat(_month, 'interes');

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

  // ───────────────────── Widgets de UI ─────────────────────
  Widget _filtros(BuildContext context) {
    return Row(
      children: [
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(top, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(bottom, style: TextStyle(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _statsGrid(BuildContext context) {
    final cl = _clientes ?? (activos: 0, total: 0);
    final pr = _prestamos ?? (activos: 0, total: 0);

    // Ingreso = Capital + Interés del mes seleccionado
    final ingresoTotalMes = _capitalMesActual + _interesMesActual;

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
        _statBox(_money(ingresoTotalMes), 'Ingreso'),
        _statBox(_money(_ingEg.egreso), 'Egresos'),
      ],
    );
  }

  Widget _graficoCard(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ingresos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            // Sin overlay persistente: solo gráfico + tooltip al tocar
            SizedBox(height: 300, child: _barChart()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Legend(
                  color: const Color(0xFF1E88E5),
                  label: 'Capital',
                  selected: _categoriaSeleccionada == 'capital',
                  onTap: () => _toggleCat('capital'),
                ),
                _Legend(
                  color: const Color(0xFF26A69A),
                  label: 'Interés',
                  selected: _categoriaSeleccionada == 'interes',
                  onTap: () => _toggleCat('interes'),
                ),
                _Legend(
                  color: const Color(0xFFE53935),
                  label: 'Mora',
                  selected: _categoriaSeleccionada == 'mora',
                  onTap: () => _toggleCat('mora'),
                ),
                _Legend(
                  color: const Color(0xFFFFB300),
                  label: 'Seguro',
                  selected: _categoriaSeleccionada == 'seguro',
                  onTap: () => _toggleCat('seguro'),
                ),
                _Legend(
                  color: const Color(0xFF7E57C2),
                  label: 'Otros',
                  selected: _categoriaSeleccionada == 'otros',
                  onTap: () => _toggleCat('otros'),
                ),
                _Legend(
                  color: const Color(0xFF8D6E63),
                  label: 'Gastos',
                  selected: _categoriaSeleccionada == 'gastos',
                  onTap: () => _toggleCat('gastos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCat(String cat) {
    setState(() {
      _categoriaSeleccionada =
          (_categoriaSeleccionada == cat) ? null : cat;
    });
  }

  BarChart _barChart() {
    const capitalC = Color(0xFF1E88E5);
    const interesC = Color(0xFF26A69A);
    const moraC = Color(0xFFE53935);
    const seguroC = Color(0xFFFFB300);
    const otrosC = Color(0xFF7E57C2);
    const gastosC = Color(0xFF8D6E63);

    Color colorFor(String cat) {
      switch (cat) {
        case 'capital': return capitalC;
        case 'interes': return interesC;
        case 'mora': return moraC;
        case 'seguro': return seguroC;
        case 'otros': return otrosC;
        case 'gastos': return gastosC;
      }
      return otrosC;
    }

    final groups = <BarChartGroupData>[];
    double maxValor = 0;
    final filtro = _categoriaSeleccionada; // null => stacked

    for (var m = 1; m <= 12; m++) {
      final mm = _ingresosPorMes[m] ?? const {
        'capital': 0.0, 'interes': 0.0, 'mora': 0.0,
        'seguro': 0.0, 'otros': 0.0, 'gastos': 0.0
      };

      final cap = _d(mm['capital']);
      final intx = _d(mm['interes']);
      final mor = _d(mm['mora']);
      final seg = _d(mm['seguro']);
      final otr = _d(mm['otros']);
      final gas = _d(mm['gastos']);

      if (filtro != null) {
        // —— Modo filtro por rubro: barra simple con solo ese valor ——
        final value = _d(mm[filtro] ?? 0);
        if (value > maxValor) maxValor = value;
        groups.add(
          BarChartGroupData(
            x: m,
            barRods: [
              BarChartRodData(
                toY: value,
                width: 14,
                color: colorFor(filtro),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      } else {
        // —— Modo stacked normal ——
        final total = cap + intx + mor + seg + otr + gas;
        if (total > maxValor) maxValor = total;

        double cur = 0;
        final stacks = <BarChartRodStackItem>[
          if (cap > 0) BarChartRodStackItem(cur, cur += cap, capitalC),
          if (intx > 0) BarChartRodStackItem(cur, cur += intx, interesC),
          if (mor > 0) BarChartRodStackItem(cur, cur += mor, moraC),
          if (seg > 0) BarChartRodStackItem(cur, cur += seg, seguroC),
          if (otr > 0) BarChartRodStackItem(cur, cur += otr, otrosC),
          if (gas > 0) BarChartRodStackItem(cur, cur += gas, gastosC),
        ];

        groups.add(
          BarChartGroupData(
            x: m,
            groupVertically: true,
            barRods: [
              BarChartRodData(
                toY: total,
                rodStackItems: stacks,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }
    }

    if (maxValor == 0) {
      return BarChart(
        BarChartData(
          maxY: 1,
          barGroups: groups,
          gridData: const FlGridData(show: true, horizontalInterval: 1),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      );
    }

    final double maxY = (maxValor * 1.2).clamp(1, double.infinity).toDouble();
    final double step = (maxY / 5).clamp(1, double.infinity).toDouble();
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: groups,
        gridData: FlGridData(show: true, horizontalInterval: step),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(_abbrMoney(v)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
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

        // —— Tooltip compatible: SOLO monto si hay filtro por leyenda; si no, muestra cap+int ——
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) {
              final map = _ingresosPorMes[group.x] ?? const {
                'capital': 0.0, 'interes': 0.0, 'mora': 0.0,
                'seguro': 0.0, 'otros': 0.0, 'gastos': 0.0
              };

              // Si hay filtro por leyenda → mostrar SOLO el monto de ese rubro
              final cat = _categoriaSeleccionada;
              if (cat != null) {
                final value = _d(map[cat]);
                return BarTooltipItem(
                  _money(value),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                );
              }

              // Sin filtro: apilado → mostrar Interés + Capital
              final interes = _d(map['interes']);
              final capital = _d(map['capital']);
              return BarTooltipItem(
                'Interés ${_money(interes)}\nCapital ${_money(capital)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────── Soporte visual ─────────────────────

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Legend({
    required this.color,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

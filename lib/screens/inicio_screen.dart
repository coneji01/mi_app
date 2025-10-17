// lib/screens/inicio_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/app_drawer.dart';
import '../data/repository.dart';
import 'pagos_screen.dart';

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

  /// Top cuentas por cobrar que devuelve el backend
  List<Map<String, dynamic>> _cuentasPorCobrar = const [];

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

      List<Map<String, dynamic>> cuentas = [];
      final cuentasRaw = dash['cuentas_por_cobrar'] ?? dash['cuentasPorCobrar'];
      if (cuentasRaw is List) {
        cuentas = cuentasRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else if (cuentasRaw is Map) {
        cuentas = cuentasRaw.values
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
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
        _cuentasPorCobrar = cuentas;
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1080;
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _topSection(context, constraints.maxWidth),
                          const SizedBox(height: 18),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _cuentasPorCobrarCard(context),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 7,
                                  child: _graficoCard(context),
                                ),
                              ],
                            )
                          else ...[
                            _cuentasPorCobrarCard(context),
                            const SizedBox(height: 18),
                            _graficoCard(context),
                          ],
                        ],
                      );
                    },
                  ),
                )),
    );
  }

  // ───────────────────── Widgets de UI ─────────────────────
  Widget _topSection(BuildContext context, double maxWidth) {
    final filters = _filtersCard(context);
    final summary = _summaryMetrics(context);
    final isWide = maxWidth >= 1024;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: summary),
          const SizedBox(width: 18),
          SizedBox(width: 240, child: filters),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filters,
        const SizedBox(height: 18),
        summary,
      ],
    );
  }

  Widget _filtersCard(BuildContext context) {
    final theme = Theme.of(context);
    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DropdownButtonHideUnderline(
            child: DropdownButtonFormField<int>(
              value: _month,
              items: _monthItems(),
              decoration: dec('Mes'),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _month = v);
                _load();
              },
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonHideUnderline(
            child: DropdownButtonFormField<int>(
              value: _year,
              items: _yearItems(),
              decoration: dec('Año'),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _year = v);
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetrics(BuildContext context) {
    final cl = _clientes ?? (activos: 0, total: 0);
    final pr = _prestamos ?? (activos: 0, total: 0);
    final ingresoTotalMes = _capitalMesActual + _interesMesActual;

    final cards = [
      _MetricCard(
        title: 'Clientes Activos',
        value: '${cl.activos} de ${cl.total}',
      ),
      _MetricCard(
        title: 'Préstamos Activos',
        value: '${pr.activos} de ${pr.total}',
      ),
      _MetricCard(
        title: 'Total Prestado',
        value: _money(_totalPrestado),
        highlight: true,
      ),
      _MetricCard(
        title: 'Proyección Interés',
        value: _money(_proyInteresMes),
      ),
      _MetricCard(
        title: 'Ingreso',
        value: _money(ingresoTotalMes),
      ),
      _MetricCard(
        title: 'Egresos',
        value: _money(_ingEg.egreso),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards,
    );
  }

  Widget _cuentasPorCobrarCard(BuildContext context) {
    final theme = Theme.of(context);
    final cuentas = _cuentasPorCobrar;

    ColorScheme colorScheme = theme.colorScheme;

    Widget emptyState = Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: const Text('No hay cuentas por cobrar pendientes.'),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cuentas por cobrar',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PagosScreen(),
                      ),
                    );
                  },
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (cuentas.isEmpty)
              emptyState
            else
              Column(
                children: [
                  for (var i = 0; i < cuentas.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == cuentas.length - 1 ? 0 : 12),
                      child: _CuentaItem(
                        data: cuentas[i],
                        money: _money,
                        colorScheme: colorScheme,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final bool highlight;

  const _MetricCard({
    required this.title,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surface;
    final primary = theme.colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: highlight ? primary : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7A7F87),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CuentaItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(num) money;
  final ColorScheme colorScheme;

  const _CuentaItem({
    required this.data,
    required this.money,
    required this.colorScheme,
  });

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  String _pick(List<String> keys) {
    for (final k in keys) {
      final value = data[k];
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _pick(['cliente', 'nombre', 'full_name', 'fullName']);
    final telefono = _pick(['telefono', 'phone', 'telefono_cliente']);
    final cuota = _pick(['cuota', 'cuota_actual', 'numero_cuota', 'cuotaPendiente']);
    final venc = _pick([
      'vencimiento',
      'fecha_vencimiento',
      'proximo_pago',
      'fechaProximoPago'
    ]);
    final status = _pick(['estado', 'status']);
    final balance = _asDouble(
      data['balance_pendiente'] ?? data['balancePendiente'] ?? data['saldo_capital'],
    );
    final cuotaLabel = cuota.isNotEmpty ? 'Cuota $cuota' : '';
    final diasAtraso = _asInt(data['dias_atraso'] ?? data['diasAtraso'] ?? data['atraso_dias']);

    Color accent;
    Color background;
    if (diasAtraso != null && diasAtraso > 15) {
      accent = const Color(0xFFE53935);
      background = const Color(0xFFFFEBEE);
    } else if (diasAtraso != null && diasAtraso > 0) {
      accent = const Color(0xFFFFA000);
      background = const Color(0xFFFFF3E0);
    } else {
      accent = colorScheme.primary;
      background = colorScheme.primary.withOpacity(.08);
    }

    final statusText = status.isNotEmpty
        ? status
        : (diasAtraso != null && diasAtraso > 0
            ? '$diasAtraso días atraso'
            : 'Pendiente');

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre.isEmpty ? 'Cliente sin nombre' : nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (cuotaLabel.isNotEmpty)
                Text(
                  cuotaLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Balance pendiente: ${money(balance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (venc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Vencimiento: $venc',
              style: const TextStyle(color: Color(0xFF6C7480)),
            ),
          ],
          if (telefono.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Tel: $telefono',
              style: const TextStyle(color: Color(0xFF6C7480)),
            ),
          ],
        ],
      ),
    );
  }
}

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

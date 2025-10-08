import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/prestamo_propuesta.dart';
import '../widgets/app_drawer.dart';

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key, this.returnMode = false});
  final bool returnMode;

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  final _formKey = GlobalKey<FormState>();

  // Entradas
  final _montoCtrl = TextEditingController();
  final _tasaCtrl = TextEditingController();   // % por período
  final _cuotasCtrl = TextEditingController();
  final _cuotaAjustadaCtrl = TextEditingController(); // NUEVO

  // Por defecto
  String _modalidad = 'Quincenal';
  String _tipoAmort = 'Interés Fijo';

  // Resultado
  List<_AmRow> _tabla = [];
  double? _cuota;          // cuota constante (para Interés Fijo/Francés)
  double? _total;          // total a pagar (suma cuotas)
  double _totalInteres = 0; // ganancia por interés
  double _capPorCuota = 0;  // para mostrar en resumen
  double _intPorCuota = 0;  // para mostrar en resumen (1ra cuota p/Francés/Alemán)

  final _money = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$');
  final _date = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _cuotasCtrl.dispose();
    _cuotaAjustadaCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {IconData? icon, String? helper}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      );

  double _parseDouble(String s) =>
      double.parse(s.trim().replaceAll(',', '.'));

  // ─────────────────── LÓGICA ───────────────────

  double _cuotaSegunAmortizacion({
    required double monto,
    required double tasaPorPeriodoPct,
    required int n,
    required String tipoAmort,
  }) {
    final i = tasaPorPeriodoPct / 100.0;

    switch (tipoAmort) {
      case 'Interés Fijo':
        // cuota fija = capital/n + monto*i
        return (monto / n) + (monto * i);

      case 'Francés':
        // cuota fija de anualidad
        if (i == 0) return monto / n;
        final factor = i / (1 - math.pow(1 + i, -n));
        return monto * factor;

      case 'Alemán':
        // en alemán la cuota NO es constante; tomamos la 1ra cuota
        final amort = monto / n;
        final interesPrimera = monto * i;
        return amort + interesPrimera;

      default:
        return (monto / n) + (monto * i);
    }
  }

  /// Recalculamos el % por período para igualar una cuota deseada (Interés Fijo/Francés).
  double _tasaAjustadaPorCuota({
    required double monto,
    required int n,
    required String tipoAmort,
    required double cuotaDeseada,
  }) {
    // Caso inválido
    if (monto <= 0 || n <= 0 || cuotaDeseada <= 0) return 0;

    if (tipoAmort == 'Interés Fijo') {
      // cuota = monto/n + monto * i  →  i = (cuota - monto/n) / monto
      final capitalPorCuota = monto / n;
      final i = (cuotaDeseada - capitalPorCuota) / monto;
      return i <= 0 ? 0 : i * 100;
    }

    if (tipoAmort == 'Francés') {
      // Resolver en r: cuota = M * r / (1 - (1+r)^-n)
      // bisección en r ∈ [0, 1] (0%..100% por período)
      double lo = 0.0, hi = 1.0; // 0% ... 100% por período
      for (int it = 0; it < 60; it++) {
        final mid = (lo + hi) / 2;
        final pago = (mid == 0)
            ? monto / n
            : monto * (mid / (1 - math.pow(1 + mid, -n)));
        if (pago > cuotaDeseada) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      final r = (lo + hi) / 2;
      if (r < 0) return 0;
      return r * 100;
    }

    // Alemán: no tiene cuota fija → devolvemos el % actual (no ajustamos)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El ajuste de "Cuota (ajustada)" aplica a Interés Fijo o Francés. '
          'En Alemán la cuota no es constante.'
        ),
      ),
    );
    return _parseDouble(_tasaCtrl.text);
  }

  DateTime _sumarPeriodo(DateTime d) {
    switch (_modalidad) {
      case 'Diario':      return d.add(const Duration(days: 1));
      case 'Interdiario': return d.add(const Duration(days: 2));
      case 'Semanal':     return d.add(const Duration(days: 7));
      case 'Bisemanal':   return d.add(const Duration(days: 14));
      case 'Quincenal':   return d.add(const Duration(days: 15));
      case 'Mensual':     return DateTime(d.year, d.month + 1, d.day);
      default:            return d.add(const Duration(days: 15));
    }
  }

  List<_AmRow> _armarTabla({
    required double monto,
    required double tasaPct,
    required int n,
    required String tipoAmort,
  }) {
    final i = tasaPct / 100.0;
    final rows = <_AmRow>[];
    var saldo = monto;
    var f = _sumarPeriodo(DateTime.now());

    final cuotaRef = _cuotaSegunAmortizacion(
        monto: monto, tasaPorPeriodoPct: tasaPct, n: n, tipoAmort: tipoAmort);

    for (var k = 1; k <= n; k++) {
      double interes;
      double amort;
      double cuota;

      switch (tipoAmort) {
        case 'Interés Fijo':
          interes = monto * i;     // fijo
          amort   = monto / n;     // fijo
          cuota   = amort + interes;
          if (k == n) amort = saldo;
          break;

        case 'Francés':
          interes = saldo * i;
          amort   = cuotaRef - interes;
          if (k == n) {
            amort = saldo;
            cuota = amort + interes;
          } else {
            cuota = cuotaRef;
          }
          break;

        case 'Alemán':
          amort = monto / n;
          if (k == n) amort = saldo;
          interes = saldo * i;
          cuota   = amort + interes;
          break;

        default:
          interes = monto * i;
          amort   = monto / n;
          cuota   = amort + interes;
      }

      saldo = (saldo - amort);
      if (saldo.abs() < 0.01) saldo = 0;

      // Redondeos estéticos a 2 decimales
      cuota   = double.parse(cuota.toStringAsFixed(2));
      amort   = double.parse(amort.toStringAsFixed(2));
      interes = double.parse(interes.toStringAsFixed(2));
      final saldoShow = double.parse((saldo < 0 ? 0 : saldo).toStringAsFixed(2));

      rows.add(_AmRow(k, f, cuota, saldoShow, amort, interes));
      f = _sumarPeriodo(f);
    }
    return rows;
  }

  // ─────────────────── ACCIONES ───────────────────

 void _calcular() {
  if (!_formKey.currentState!.validate()) return;

  final monto  = _parseDouble(_montoCtrl.text);
  final cuotas = int.parse(_cuotasCtrl.text.trim());

  // ⬇️ antes: final cuotaDeseada = ... ? 0 : _parseDouble(...);
  final double cuotaDeseada = _cuotaAjustadaCtrl.text.trim().isEmpty
      ? 0.0
      : _parseDouble(_cuotaAjustadaCtrl.text);

  double tasaPct = _parseDouble(_tasaCtrl.text); // % por período
  if (cuotaDeseada > 0.0) {
    tasaPct = _tasaAjustadaPorCuota(
      monto: monto,
      n: cuotas,
      tipoAmort: _tipoAmort,
      cuotaDeseada: cuotaDeseada, // ahora es double ✔️
    );
    _tasaCtrl.text = tasaPct.toStringAsFixed(4);
  }

    // cuota de referencia (constante en Interés Fijo / Francés)
    final cuota  = _cuotaSegunAmortizacion(
        monto: monto, tasaPorPeriodoPct: tasaPct, n: cuotas, tipoAmort: _tipoAmort);

    final tabla  = _armarTabla(
        monto: monto, tasaPct: tasaPct, n: cuotas, tipoAmort: _tipoAmort);

    final total  = tabla.fold<double>(0, (s, r) => s + r.cuota);
    final totInt = tabla.fold<double>(0, (s, r) => s + r.interes);

    // para el resumen: tomamos la 1ra fila
    final first = tabla.isNotEmpty ? tabla.first : null;
    _capPorCuota = first?.abonoCapital ?? (monto / cuotas);
    _intPorCuota = first?.interes ?? (monto * (tasaPct / 100.0));

    setState(() {
      _cuota = double.parse(cuota.toStringAsFixed(2));
      _total = double.parse(total.toStringAsFixed(2));
      _totalInteres = double.parse(totInt.toStringAsFixed(2));
      _tabla = tabla;
    });
  }

  void _compartirOpcionesBasicas(double monto, double tasa, String tipo) {
    const opciones = [4, 6, 8, 10, 12];
    final sb = StringBuffer();
    sb.writeln('Opciones de cuotas para un préstamo de ${_money.format(monto)}');

    for (final n in opciones) {
      final c = _cuotaSegunAmortizacion(
          monto: monto, tasaPorPeriodoPct: tasa, n: n, tipoAmort: tipo);
      sb.writeln('• $n cuotas: ${_money.format(c)}');
    }
    sb.writeln('\n¿Cuál de estas cuotas te gustaría pagar?');

    Share.share(sb.toString());
  }

  void _compartirTabla() {
    if (_tabla.isEmpty) return;
    final monto  = _parseDouble(_montoCtrl.text);
    final tasa   = _parseDouble(_tasaCtrl.text);
    final cuotas = int.parse(_cuotasCtrl.text.trim());

    final sb = StringBuffer();
    sb.writeln('Amortización');
    sb.writeln('Monto: ${_money.format(monto)} | Interés: ${tasa.toStringAsFixed(4)}%');
    sb.writeln('Modalidad: $_modalidad | Amortización: $_tipoAmort | #Cuotas: $cuotas\n');

    for (final r in _tabla) {
      sb.writeln(
        '${r.n.toString().padLeft(2, '0')}  ${_date.format(r.fecha)}  '
        'Cuota: ${_money.format(r.cuota)}  '
        'Abono: ${_money.format(r.abonoCapital)}  '
        'Interés: ${_money.format(r.interes)}  '
        'Saldo: ${_money.format(r.saldo)}'
      );
    }
    sb.writeln('\nTotal a pagar: ${_money.format(_total ?? 0)}');
    sb.writeln('Total interés (ganancia): ${_money.format(_totalInteres)}');

    Share.share(sb.toString());
  }

  void _usarPropuestaActual() {
    if (_cuota == null) return;

    final monto  = _parseDouble(_montoCtrl.text);
    final tasa   = _parseDouble(_tasaCtrl.text);
    final cuotas = int.tryParse(_cuotasCtrl.text) ?? 0;

    final propuesta = PrestamoPropuesta(
      monto: monto,
      interes: tasa,                 // requerido por tu modelo
      cuotas: cuotas,
      modalidad: _modalidad,
      tipoAmortizacion: _tipoAmort,
      tasaPorPeriodo: tasa,          // alias que también usas
      tipo: _tipoAmort,
      cuota: _cuota!,
      total: _total ?? (_cuota! * cuotas),
    );

    Navigator.pop(context, propuesta);
  }

  // ─────────────────── UI ───────────────────

  @override
  Widget build(BuildContext context) {
    const double maxCardWidth = 760.0;
    final screenW = MediaQuery.of(context).size.width;
    final cardW = screenW > maxCardWidth ? maxCardWidth : screenW;

    return Scaffold(
      drawer: const AppDrawer(current: AppSection.calculadora),
      appBar: AppBar(
        title: const Text('Calculadora'),
        actions: [
          if (_tabla.isNotEmpty)
            IconButton(
              tooltip: 'Compartir tabla',
              onPressed: _compartirTabla,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: cardW,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _dec('Monto del préstamo', icon: Icons.attach_money),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tasaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _dec('Tasa por período (%)', icon: Icons.percent),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cuotasCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _dec('# de cuotas', icon: Icons.onetwothree),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // NUEVO: cuota ajustada
                      TextFormField(
                        controller: _cuotaAjustadaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _dec(
                          'Cuota (ajustada opcional)',
                          icon: Icons.tune,
                          helper:
                              'Si la escribes, se recalcula el % para que la cuota sea exactamente esta.\n'
                              'Aplica para Interés Fijo y Francés.',
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _modalidad,
                        decoration: _dec('Modalidad de pago', icon: Icons.calendar_month),
                        items: const [
                          DropdownMenuItem(value: 'Diario', child: Text('Diario')),
                          DropdownMenuItem(value: 'Interdiario', child: Text('Interdiario')),
                          DropdownMenuItem(value: 'Semanal', child: Text('Semanal')),
                          DropdownMenuItem(value: 'Bisemanal', child: Text('Bisemanal')),
                          DropdownMenuItem(value: 'Quincenal', child: Text('Quincenal')),
                          DropdownMenuItem(value: 'Mensual', child: Text('Mensual')),
                        ],
                        onChanged: (v) => setState(() => _modalidad = v ?? _modalidad),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _tipoAmort,
                        decoration: _dec('Tipo de amortización', icon: Icons.rule),
                        items: const [
                          DropdownMenuItem(value: 'Interés Fijo', child: Text('Interés Fijo')),
                          DropdownMenuItem(value: 'Francés', child: Text('Francés')),
                          DropdownMenuItem(value: 'Alemán', child: Text('Alemán')),
                        ],
                        onChanged: (v) => setState(() => _tipoAmort = v ?? _tipoAmort),
                      ),
                      const SizedBox(height: 20),

                      FilledButton.icon(
                        onPressed: _calcular,
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Calcular'),
                      ),
                    ],
                  ),
                ),

                if (_tabla.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _ResumenCard(
                    cuota: _money.format(_cuota),
                    total: _money.format(_total),
                    totalInteres: _money.format(_totalInteres),
                    capPorCuota: _money.format(_capPorCuota),
                    intPorCuota: _money.format(_intPorCuota),
                    tasaAplicada: '${_tasaCtrl.text}% por período',
                  ),
                  const SizedBox(height: 10),
                  _TablaAmortizacion(
                    rows: _tabla,
                    money: _money,
                    date: _date,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Ver opciones 4/6/8/10/12 y compartir'),
                    onPressed: () {
                      final monto = _parseDouble(_montoCtrl.text);
                      final tasa  = _parseDouble(_tasaCtrl.text);
                      _compartirOpcionesBasicas(monto, tasa, _tipoAmort);
                    },
                  ),

                  if (widget.returnMode && _cuota != null) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _usarPropuestaActual,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Usar esta propuesta'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.cuota,
    required this.total,
    required this.totalInteres,
    required this.capPorCuota,
    required this.intPorCuota,
    required this.tasaAplicada,
  });

  final String cuota;
  final String total;
  final String totalInteres;
  final String capPorCuota;
  final String intPorCuota;
  final String tasaAplicada;

  @override
  Widget build(BuildContext context) {
    Text _kv(String k, String v) =>
        Text('$k  $v', style: const TextStyle(fontWeight: FontWeight.w600));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Cuota:', cuota),
            const SizedBox(height: 4),
            _kv('Capital por cuota:', capPorCuota),
            _kv('Interés por cuota (1ra):', intPorCuota),
            const Divider(height: 18),
            _kv('Total interés (ganancia):', totalInteres),
            _kv('Total a pagar:', total),
            const SizedBox(height: 6),
            Text('Tasa aplicada: $tasaAplicada'),
          ],
        ),
      ),
    );
  }
}

class _TablaAmortizacion extends StatelessWidget {
  const _TablaAmortizacion({
    required this.rows,
    required this.money,
    required this.date,
  });

  final List<_AmRow> rows;
  final NumberFormat money;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, r) => s + r.cuota);

    return Card(
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Cuota')),
                DataColumn(label: Text('Abono capital')),
                DataColumn(label: Text('Interés')),
                DataColumn(label: Text('Saldo')),
              ],
              rows: rows.map((r) {
                return DataRow(cells: [
                  DataCell(Text(r.n.toString())),
                  DataCell(Text(date.format(r.fecha))),
                  DataCell(Text(money.format(r.cuota))),
                  DataCell(Text(money.format(r.abonoCapital))),
                  DataCell(Text(money.format(r.interes))),
                  DataCell(Text(money.format(r.saldo))),
                ]);
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('Total: ${money.format(total)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// Fila de la tabla
class _AmRow {
  final int n;
  final DateTime fecha;
  final double cuota;
  final double saldo;           // después de pagar
  final double abonoCapital;
  final double interes;

  _AmRow(this.n, this.fecha, this.cuota, this.saldo, this.abonoCapital, this.interes);
}

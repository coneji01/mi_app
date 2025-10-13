// lib/screens/calculadora_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

// Si tienes utilidades en core/amortizacion.dart, puedes dejarlas importadas.
// Este archivo es autosuficiente, así que no dependemos de ellas estrictamente.

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
  final _cuotaAjustadaCtrl = TextEditingController(); // opcional: ajusta tasa

  // Por defecto
  String _modalidad = 'Quincenal';
  String _tipoAmort = 'Interés Fijo';

  // Resultado
  List<_AmRow> _tabla = [];
  double? _cuota;            // cuota "de referencia" (ver notas abajo)
  double? _total;            // suma de cuotas
  double _totalInteres = 0;  // suma de intereses
  double _capPorCuota = 0;   // para resumen (primera cuota)
  double _intPorCuota = 0;   // para resumen (primera cuota)

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

  double _parseDouble(String s) => double.parse(s.trim().replaceAll(',', '.'));

  // ─────────────────── LÓGICA ───────────────────
  // Nota de “cuota de referencia”:
  // - Interés Fijo: cuota constante = capital/n + monto*i
  // - Cuota Fija  : cuota constante tipo francés
  // - Disminuir Cuota: usamos como referencia la CUOTA 1 (luego disminuye 2% por período)
  // - Capital al final: referencia = primera cuota (solo interés)

  double _cuotaReferencia({
    required double monto,
    required double tasaPct,
    required int n,
    required String tipo,
  }) {
    final i = tasaPct / 100.0;

    switch (tipo) {
      case 'Interés Fijo':
        return (monto / n) + (monto * i);

      case 'Cuota Fija': // sistema francés
        if (i == 0) return monto / n;
        final factor = i / (1 - math.pow(1 + i, -n));
        return monto * factor;

      case 'Disminuir Cuota':
        // Referencia = la primera cuota calculada con francés; luego bajará 2% cada período
        if (i == 0) return monto / n;
        final factor = i / (1 - math.pow(1 + i, -n));
        return monto * factor;

      case 'Capital al final':
        // primeras cuotas solo interés; referencia = interes del primer período
        return monto * i;

      default:
        return (monto / n) + (monto * i);
    }
  }

  /// Ajusta la tasa para que la CUOTA sea exactamente la deseada.
  /// Aplica solamente a: Interés Fijo y Cuota Fija.
  double _tasaAjustadaPorCuota({
    required double monto,
    required int n,
    required String tipo,
    required double cuotaDeseada,
  }) {
    if (monto <= 0 || n <= 0 || cuotaDeseada <= 0) return 0;

    if (tipo == 'Interés Fijo') {
      // cuota = monto/n + monto * i  →  i = (cuota - monto/n) / monto
      final capitalPorCuota = monto / n;
      final i = (cuotaDeseada - capitalPorCuota) / monto;
      return i <= 0 ? 0 : i * 100;
    }

    if (tipo == 'Cuota Fija') {
      // cuota = M * r / (1 - (1+r)^-n) → resolver r por bisección
      double lo = 0.0, hi = 1.0; // 0%..100% por periodo
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
      return r < 0 ? 0 : r * 100;
    }

    // Para los demás, no procede.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El ajuste de "Cuota (ajustada)" aplica a Interés Fijo y Cuota Fija.'),
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
    required String tipo,
  }) {
    final i = tasaPct / 100.0;
    final rows = <_AmRow>[];
    var saldo = monto;
    var f = _sumarPeriodo(DateTime.now());

    // Parámetro de reducción para "Disminuir Cuota"
    const reduccionPct = 0.02; // 2% menos cada período

    final cuotaRef = _cuotaReferencia(monto: monto, tasaPct: tasaPct, n: n, tipo: tipo);

    for (var k = 1; k <= n; k++) {
      double interes;
      double amort;
      double cuota;

      switch (tipo) {
        case 'Interés Fijo':
          interes = monto * i;     // fijo
          amort   = monto / n;     // fijo
          cuota   = amort + interes;
          if (k == n) amort = saldo; // remate
          break;

        case 'Cuota Fija': // francés
          interes = saldo * i;
          amort   = cuotaRef - interes;
          if (k == n) {     // última ajusta para cerrar saldo
            amort = saldo;
            cuota = amort + interes;
          } else {
            cuota = cuotaRef;
          }
          break;

        case 'Disminuir Cuota':
          // Cuota decreciente: partimos de cuota tipo francés y bajamos 2% cada período
          final cuotaK = cuotaRef * math.pow(1 - reduccionPct, (k - 1));
          interes = saldo * i;
          amort   = cuotaK - interes;
          if (amort < 0) amort = 0; // por si la tasa es alta
          if (amort > saldo || k == n) amort = saldo; // cierre
          cuota   = amort + interes;
          break;

        case 'Capital al final':
          if (k < n) {
            interes = saldo * i;  // saldo = monto hasta el final
            amort   = 0;
            cuota   = interes;
          } else {
            interes = saldo * i;
            amort   = saldo;      // todo el capital al final
            cuota   = amort + interes;
          }
          break;

        default:
          // fallback: interés fijo
          interes = monto * i;
          amort   = monto / n;
          cuota   = amort + interes;
      }

      saldo = (saldo - amort);
      if (saldo.abs() < 0.01) saldo = 0;

      // Redondeos visuales
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

    final double cuotaDeseada = _cuotaAjustadaCtrl.text.trim().isEmpty
        ? 0.0
        : _parseDouble(_cuotaAjustadaCtrl.text);

    double tasaPct = _parseDouble(_tasaCtrl.text); // % por período

    if (cuotaDeseada > 0.0) {
      tasaPct = _tasaAjustadaPorCuota(
        monto: monto,
        n: cuotas,
        tipo: _tipoAmort,
        cuotaDeseada: cuotaDeseada,
      );
      _tasaCtrl.text = tasaPct.toStringAsFixed(4);
    }

    // cuota de referencia (ver nota arriba)
    final cuotaRef  = _cuotaReferencia(
        monto: monto, tasaPct: tasaPct, n: cuotas, tipo: _tipoAmort);

    final tabla  = _armarTabla(
        monto: monto, tasaPct: tasaPct, n: cuotas, tipo: _tipoAmort);

    final total  = tabla.fold<double>(0, (s, r) => s + r.cuota);
    final totInt = tabla.fold<double>(0, (s, r) => s + r.interes);

    final first = tabla.isNotEmpty ? tabla.first : null;
    _capPorCuota = first?.abonoCapital ?? (monto / cuotas);
    _intPorCuota = first?.interes ?? (monto * (tasaPct / 100.0));

    setState(() {
      _cuota = double.parse(cuotaRef.toStringAsFixed(2));
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
      final c = _cuotaReferencia(
          monto: monto, tasaPct: tasa, n: n, tipo: tipo);
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
      interes: tasa,
      cuotas: cuotas,
      modalidad: _modalidad,
      tipoAmortizacion: _tipoAmort,
      tasaPorPeriodo: tasa,
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

                      // Cuota (ajustada) opcional
                      TextFormField(
                        controller: _cuotaAjustadaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _dec(
                          'Cuota (ajustada opcional)',
                          icon: Icons.tune,
                          helper:
                              'Si la escribes, se recalcula la tasa para que la cuota sea EXACTA.\n'
                              'Aplica a Interés Fijo y Cuota Fija.',
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

                      // Nuevo set de amortizaciones
                      DropdownButtonFormField<String>(
                        value: _tipoAmort,
                        decoration: _dec('Tipo de amortización', icon: Icons.rule),
                        items: const [
                          DropdownMenuItem(value: 'Interés Fijo', child: Text('Interés Fijo')),
                          DropdownMenuItem(value: 'Cuota Fija', child: Text('Cuota Fija')),
                          DropdownMenuItem(value: 'Disminuir Cuota', child: Text('Disminuir Cuota')),
                          DropdownMenuItem(value: 'Capital al final', child: Text('Capital al final')),
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

// lib/screens/agregar_pago_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repository.dart'; // 👈 backend only
import '../models/prestamo.dart';
import '../widgets/app_drawer.dart';

class AgregarPagoScreen extends StatefulWidget {
  final int prestamoId;

  const AgregarPagoScreen({
    super.key,
    required this.prestamoId,
  });

  @override
  State<AgregarPagoScreen> createState() => _AgregarPagoScreenState();
}

class _AgregarPagoScreenState extends State<AgregarPagoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Carga del préstamo
  bool _loading = true;
  String? _error;
  Prestamo? _p;

  // Modo de pago (arriba)
  static const _modos = ['CUOTA COMPLETA', 'SOLO INTERÉS', 'SOLO CAPITAL'];
  String _modo = _modos.first;

  // Nº de cuotas a pagar (1..restantes)
  int _nCuotas = 1;
  List<int> _opcionesCuotas = const [1];

  // PRIMERA CUOTA PENDIENTE (ABSOLUTA) => p.cuotasPagadas + 1
  int _primeraPendienteAbs = 1;

  // Fecha de pago (visual)
  DateTime _fechaPago = DateTime.now();

  // Campos
  final _descuentoCtrl = TextEditingController(text: '0');
  final _otrosCtrl = TextEditingController(text: '0');
  final _comentarioCtrl = TextEditingController();

  // Cálculos base
  double _capitalPorCuota = 0;
  double _interesPorCuota = 0;
  double _cuotaTotal = 0;

  // Resumen (placeholders)
  double _mora = 0;
  double _pendiente = 0;

  // Totales de la operación
  double _capitalAPagar = 0;
  double _interesAPagar = 0;
  double _otros = 0;
  double _descuento = 0;
  double _totalAPagar = 0;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descuentoCtrl.dispose();
    _otrosCtrl.dispose();
    _comentarioCtrl.dispose();
    super.dispose();
  }

  // =================== CARGA ===================
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prestamoMap = await Repository.i.prestamoPorId(widget.prestamoId);
      if (prestamoMap == null) {
        throw Exception('No existe el préstamo #${widget.prestamoId}.');
      }
      final p = Prestamo.fromJson(prestamoMap);

      // Base simple: capital/periodo + interés/periodo
      _capitalPorCuota = p.monto / p.cuotasTotales;
      _interesPorCuota = p.monto * (p.interes / 100.0);
      _cuotaTotal = _capitalPorCuota + _interesPorCuota;

      // Cuotas restantes (usamos lo que haya localmente para orientación)
      final pagadas = p.cuotasPagadas ?? 0;
      final rest = p.cuotasTotales - pagadas;
      final restantesPos = rest <= 0 ? 1 : rest;
      _opcionesCuotas = List<int>.generate(restantesPos, (i) => i + 1);
      _nCuotas = 1;

      // Primera cuota ABS pendiente
      _primeraPendienteAbs = pagadas + 1;

      _p = p;
      _recalcular();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // =================== LÓGICA ===================
  double _asDouble(String? s) {
    if (s == null || s.trim().isEmpty) return 0;
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }

  // Paso de período según modalidad
  Duration _step(String modalidad) {
    final low = modalidad.toLowerCase();
    if (low.contains('seman')) return const Duration(days: 7);
    if (low.contains('mens')) return const Duration(days: 30);
    return const Duration(days: 15); // quincenal (ajústalo si trabajas con 14)
  }

  DateTime _sumarPeriodos(DateTime d, String modalidad, int n) {
    final s = _step(modalidad);
    return d.add(Duration(days: s.inDays * n));
  }

  // Solo fecha (00:00) para comparar días
  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  // Próxima fecha de vencimiento (#cuota = cuotasPagadas+1)
  DateTime _primeraFechaVencimiento(Prestamo p) {
    final DateTime base = p.proximoPago ?? p.fechaInicio;
    final pagadas = p.cuotasPagadas ?? 0;
    final k = pagadas + 1;
    return _sumarPeriodos(base, p.modalidad, math.max(k, 1));
  }

  // Fecha de vencimiento de la cuota relativa (1 = la próxima sin pagar)
  DateTime _fechaVencCuotaRel(int n) {
    final p = _p!;
    final first = _primeraFechaVencimiento(p);
    if (n <= 1) return first;
    return _sumarPeriodos(first, p.modalidad, n - 1);
  }

  // ¿Está pendiente la cuota ABSOLUTA N?
  bool _estaPendienteAbs(int absIndex) {
    final rel = absIndex - _primeraPendienteAbs + 1;
    final due = _soloFecha(_fechaVencCuotaRel(rel));
    final hoy = _soloFecha(DateTime.now());
    return !due.isAfter(hoy); // due <= hoy
  }

  // Etiqueta: "Cuota N" (y "(Pendiente)" si corresponde a ESA cuota)
  String _labelCuota(int n) {
    final abs = _primeraPendienteAbs + n - 1;
    final base = 'Cuota $abs';
    return _estaPendienteAbs(abs) ? '$base (Pendiente)' : base;
  }

  void _recalcular() {
    _otros = _asDouble(_otrosCtrl.text);
    _descuento = _asDouble(_descuentoCtrl.text);

    switch (_modo) {
      case 'SOLO INTERÉS':
        _capitalAPagar = 0;
        _interesAPagar = _interesPorCuota * _nCuotas;
        break;
      case 'SOLO CAPITAL':
        _capitalAPagar = _capitalPorCuota * _nCuotas;
        _interesAPagar = 0;
        break;
      default: // CUOTA COMPLETA
        _capitalAPagar = _capitalPorCuota * _nCuotas;
        _interesAPagar = _interesPorCuota * _nCuotas;
    }

    // Descuento contra capital primero
    final double capitalConDesc = math.max(0.0, _capitalAPagar - _descuento);
    _totalAPagar = capitalConDesc + _interesAPagar + _otros;

    setState(() {}); // refrescar
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Fecha del pago',
    );
    if (picked != null) {
      setState(() => _fechaPago = picked);
    }
  }

  String _fmtMoney(num v) {
    final d = v.toDouble();
    final s = d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'RD\$$intPart${parts.length > 1 && parts[1] != '00' ? '.${parts[1]}' : ''}';
  }

  // =================== BACKEND HELPERS ===================
  Future<void> _crearPagoBackend({
    required int prestamoId,
    required double monto,
    required String tipo,           // 'capital' | 'interes' | 'mora' | 'seguro' | 'otros' | 'gastos'
    String? nota,
  }) async {
    if (monto <= 0) return;

    final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaPago);
    final t = tipo.toLowerCase(); // normalizado

    await Repository.i.crearPago(
      prestamoId: prestamoId,
      fecha: fechaStr,
      monto: monto,
      tipo: t,
      nota: (nota ?? '').trim().isEmpty ? null : nota!.trim(),
    );
  }

  // =================== GUARDAR ===================
  Future<void> _guardar() async {
    if (_p == null || _saving) return;

    setState(() => _saving = true);
    try {
      final p = _p!;
      _recalcular(); // por si cambió algo al final

      // 1) === Backend: crear pagos en API === (solo backend, sin SQLite)
      if (_interesAPagar > 0) {
        await _crearPagoBackend(
          prestamoId: p.id!,
          monto: _interesAPagar,
          tipo: 'interes',
          nota: 'Pago interés x$_nCuotas cuotas. ${_comentarioCtrl.text.trim()}'.trim(),
        );
      }

      final double capitalConDesc = math.max(0.0, _capitalAPagar - _descuento);
      if (capitalConDesc > 0) {
        await _crearPagoBackend(
          prestamoId: p.id!,
          monto: capitalConDesc,
          tipo: 'capital',
          nota: 'Pago capital x$_nCuotas cuotas. ${_comentarioCtrl.text.trim()}'.trim(),
        );
      }

      if (_otros > 0) {
        await _crearPagoBackend(
          prestamoId: p.id!,
          monto: _otros,
          tipo: 'otros',
          nota: _comentarioCtrl.text.trim().isEmpty ? 'Otros' : _comentarioCtrl.text.trim(),
        );
      }

      // 2) === NO escribimos en local ===
      //    Toda la actualización de balances vive en el backend.

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado en el backend')),
      );

      // Recargar datos desde el backend para reflejar los cambios más recientes
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: AppSection.inicio),
      appBar: AppBar(
        title: const Text('Agregar Pago'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Cerrar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _buildContent(),

      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: Divider.createBorderSide(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total a Pagar:  ${_fmtMoney(_totalAPagar)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : () => Navigator.maybePop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('CANCELAR'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _guardar,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('AGREGAR PAGO'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== selector de modo (tipo de cuota) =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: Divider.createBorderSide(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _modo,
                  items: _modos
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _modo = v);
                    _recalcular();
                  },
                  underline: const SizedBox.shrink(),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ===== fila: cuotas + fecha =====
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _nCuotas,
                      isExpanded: true,
                      items: _opcionesCuotas
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(_labelCuota(n)), // ← "Cuota N"
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _nCuotas = v);
                        _recalcular();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickFecha,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_fechaPago.year}-${_fechaPago.month.toString().padLeft(2, '0')}-${_fechaPago.day.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== resumen (mora/pendiente) =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!,
              child: Row(
                children: [
                  Expanded(child: _kv('Mora:', _fmtMoney(_mora))),
                  Expanded(child: _kv('Pendiente:', _fmtMoney(_pendiente))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ===== resumen (cuota/interés) =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(child: _kv('Cuota:', _fmtMoney(_cuotaTotal))),
                Expanded(child: _kv('Interés:', _fmtMoney(_interesPorCuota))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== importe grande =====
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _fmtMoney(
                  math.max(
                    0.0,
                    (_modo == 'SOLO INTERÉS')
                        ? _interesPorCuota * _nCuotas
                        : (_modo == 'SOLO CAPITAL')
                            ? _capitalPorCuota * _nCuotas
                            : _cuotaTotal * _nCuotas,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ===== Descuento / Otros =====
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _descuentoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Descuento',
                    prefixText: 'RD\$',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _recalcular(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _otrosCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Otros',
                    prefixText: 'RD\$',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _recalcular(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== Forma de pago =====
          DropdownButtonFormField<String>(
            value: 'Efectivo',
            items: const [
              DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
              DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
              DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
            ],
            onChanged: (_) {},
            decoration: const InputDecoration(
              labelText: 'Forma de pago *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // ===== Caja =====
          DropdownButtonFormField<String>(
            value: 'Ninguna',
            items: const [
              DropdownMenuItem(value: 'Ninguna', child: Text('Ninguna')),
            ],
            onChanged: (_) {},
            decoration: const InputDecoration(
              labelText: 'Caja',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // ===== Comentario =====
          TextFormField(
            controller: _comentarioCtrl,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 120), // margen para la barra inferior
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

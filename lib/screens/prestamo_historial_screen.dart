// lib/screens/prestamo_historial_screen.dart
import 'package:flutter/material.dart';
import '../data/db_service.dart';
import '../data/repository.dart';
import '../models/prestamo.dart';
import '../models/prestamo_api_adapter.dart';

class PrestamoHistorialScreen extends StatefulWidget {
  final int prestamoId;
  const PrestamoHistorialScreen({super.key, required this.prestamoId});

  @override
  State<PrestamoHistorialScreen> createState() => _PrestamoHistorialScreenState();
}

class _PrestamoHistorialScreenState extends State<PrestamoHistorialScreen> {
  final _repo = Repository.i;

  bool _loading = true;
  String? _error;

  Prestamo? _prestamo;
  late Duration _paso;               // paso por modalidad
  DateTime? _inicio;                 // fechaInicio del préstamo
  List<_CuotaPago> _cuotas = [];     // pagos de capital con atraso calculado
  List<_PagoRow> _pagosTodos = [];   // todos los pagos (para cálculo interno)

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    _HistorialData? data;

    try {
      data = await _cargarDesdeBackend();
    } catch (e) {
      if (!_esNotFoundError(e)) {
        _setError(e);
        return;
      }
    }

    if (data == null) {
      try {
        data = await _cargarDesdeLocal();
      } catch (e) {
        _setError(e);
        return;
      }
    }

    if (data == null) {
      _setError('El préstamo ${widget.prestamoId} no está disponible en el backend ni en la base local.');
      return;
    }

    if (!mounted) return;
    final resolvedData = data;
    if (resolvedData == null) return;
    setState(() {
      _prestamo = resolvedData.prestamo;
      _paso = resolvedData.paso;
      _inicio = resolvedData.inicio;
      _cuotas = resolvedData.cuotas;
      _pagosTodos = resolvedData.pagosTodos;
      _loading = false;
      _error = null;
    });
  }

  Future<_HistorialData?> _cargarDesdeBackend() async {
    final rawPrestamo = await _repo.prestamoPorId(widget.prestamoId);
    if (rawPrestamo == null) {
      return null;
    }
    final prestamo = prestamoFromApiMap(rawPrestamo);
    final rows = await _repo.pagosDePrestamo(widget.prestamoId);
    return _procesar(prestamo, rows);
  }

  Future<_HistorialData?> _cargarDesdeLocal() async {
    final local = await DbService.instance.getPrestamoById(widget.prestamoId);
    if (local == null) {
      return null;
    }
    final rows = await DbService.instance.listarPagosDePrestamo(widget.prestamoId);
    final normalizados = rows.map((m) => Map<String, dynamic>.from(m)).toList();
    return _procesar(local, normalizados);
  }

  _HistorialData _procesar(Prestamo prestamo, List<Map<String, dynamic>> rows) {
    final paso = _pasoPorModalidad(prestamo.modalidad);
    final inicio = _asDate(prestamo.fechaInicio);

    final pagosTodos = rows.map((r) {
      final fechaRaw = r['fecha'] ?? r['fecha_pago'] ?? r['fechaPago'] ?? r['created_at'];
      final fecha = _asDate(fechaRaw);
      final monto = _asDouble(r['monto'] ?? r['cantidad'] ?? r['monto_pagado']);
      final nota = _pickNota(r);
      final tipo = _pickTipo(r);
      return _PagoRow(fecha: fecha, monto: monto, nota: nota, tipo: tipo);
    }).toList()
      ..sort((a, b) {
        final ad = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });

    final capitales = pagosTodos.where((x) => _tag(x) == 'capital').toList();
    final cuotas = <_CuotaPago>[];
    for (var i = 0; i < capitales.length; i++) {
      final k = i + 1;
      final pago = capitales[i];
      final fechaPago = pago.fecha;

      DateTime? vencimiento;
      if (inicio != null) {
        vencimiento = inicio.add(Duration(days: paso.inDays * k));
      }

      var atraso = 0;
      if (fechaPago != null && vencimiento != null) {
        atraso = fechaPago.difference(vencimiento).inDays;
        if (atraso < 0) atraso = 0;
      }

      cuotas.add(_CuotaPago(
        numero: k,
        fechaPago: fechaPago,
        montoCapital: pago.monto,
        vencimiento: vencimiento,
        diasAtraso: atraso,
      ));
    }

    return _HistorialData(
      prestamo: prestamo,
      paso: paso,
      inicio: inicio,
      cuotas: cuotas,
      pagosTodos: pagosTodos,
    );
  }

  bool _esNotFoundError(Object error) {
    final msg = error.toString();
    return msg.contains('HTTP 404');
  }

  void _setError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = error.toString();
      _loading = false;
    });
  }

  // ===== Helpers =====

  /// Acepta DateTime directo o String ISO/fecha 'YYYY-MM-DD'
  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is num) {
      final millis = v > 2000000000 ? v.toInt() : (v * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      try {
        // admite ISO completo o solo fecha
        return s.length >= 10 ? DateTime.parse(s.substring(0, 10)) : DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return 0.0;
      final normalized = s.replaceAll(RegExp(r'[^0-9,.-]'), '').replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  String _pickNota(Map<String, dynamic> row) {
    for (final key in ['nota', 'descripcion', 'detalle', 'comentario', 'observacion']) {
      final v = row[key];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    final tipo = _pickTipo(row);
    return tipo.isNotEmpty ? tipo : '';
  }

  String _pickTipo(Map<String, dynamic> row) {
    for (final key in ['tipo', 'tipo_pago', 'tipoPago', 'categoria', 'tag']) {
      final v = row[key];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  Duration _pasoPorModalidad(String? modalidad) {
    final m = (modalidad ?? '').toLowerCase();
    if (m.contains('seman')) return const Duration(days: 7);
    if (m.contains('mens')) return const Duration(days: 30);
    return const Duration(days: 14); // quincenal por defecto
  }

  String _tag(_PagoRow pago) {
    final nota = pago.nota;
    final m = RegExp(r'^\s*\[([^\]]+)\]').firstMatch(nota);
    final noteTag = (m?.group(1) ?? '').toLowerCase();
    if (noteTag.isNotEmpty) return noteTag;
    final tipo = (pago.tipo ?? '').toLowerCase();
    if (tipo.isNotEmpty) return tipo;
    return 'otros';
  }

  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _money(num n) => 'RD\$${n.toStringAsFixed(2)}';

  String _descripcionPaso(Duration paso) {
    final dias = paso.inDays;
    if (dias == 7) return 'semanal (cada 7 días)';
    if (dias == 14) return 'quincenal (cada 14 días)';
    if (dias >= 28 && dias <= 31) return 'mensual (cada $dias días)';
    if (dias == 1) return 'diaria (cada 1 día)';
    return 'cada $dias días';
  }

  // “Píldoras” visuales para claridad
  Widget _pill(String text, Color color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.prestamoId;
    final titulo = 'Pagos del préstamo #$id';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildOk(),
    );
  }

  Widget _buildOk() {
    if (_prestamo == null) {
      return const Center(child: Text('Préstamo no encontrado.'));
    }

    // mostrar % correctamente (interes es fracción, p.ej. 0.1 -> 10.00%)
    final interesPct = (_prestamo!.interes * 100).toStringAsFixed(2);
    final frecuencia = _descripcionPaso(_paso);

    String ultimoMovimiento = '—';
    for (final pago in _pagosTodos.reversed) {
      final fecha = pago.fecha;
      if (fecha != null) {
        ultimoMovimiento = _d(fecha);
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ===== Resumen del préstamo =====
        Card(
          child: ListTile(
            leading: const Icon(Icons.request_page),
            title: Text(_money(_prestamo!.monto)),
            subtitle: Text(
              'Interés: $interesPct% • ${_prestamo!.modalidad}\n'
              'Inicio: ${_inicio != null ? _d(_inicio!) : '—'} • Cuotas: ${_prestamo!.cuotasTotales}\n'
              'Frecuencia: $frecuencia',
            ),
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text('Pagos registrados: ${_pagosTodos.length}'),
            subtitle: Text('Último movimiento: $ultimoMovimiento'),
          ),
        ),
        const SizedBox(height: 8),

        // ===== Cuotas (capital): VENCE vs. PAGADO =====
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6.0),
          child: Text('Cuotas (capital): vence vs. pagado', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (_cuotas.isEmpty)
          const Card(child: ListTile(title: Text('No hay pagos de capital registrados.')))
        else
          ..._cuotas.map((c) {
            final fp = c.fechaPago != null ? _d(c.fechaPago!) : '—';
            final fv = c.vencimiento != null ? _d(c.vencimiento!) : '—';
            final atrasado = c.diasAtraso > 0;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado: Cuota y monto
                    Row(
                      children: [
                        Icon(atrasado ? Icons.warning_amber : Icons.check_circle,
                            color: atrasado ? Colors.orange : Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cuota ${c.numero} • ${_money(c.montoCapital)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        atrasado
                            ? _pill('ATRASO: ${c.diasAtraso} día(s)', Colors.red)
                            : _pill('AL DÍA', Colors.green),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Píldoras: VENCE y PAGADO
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill('VENCE: $fv', Colors.deepOrange),
                        _pill('PAGADO: $fp', atrasado ? Colors.red : Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 12),

        // ⛔ Sección “Todos los movimientos” ocultada a propósito
      ],
    );
  }
}

// ===== Tipos internos =====
class _HistorialData {
  final Prestamo prestamo;
  final Duration paso;
  final DateTime? inicio;
  final List<_CuotaPago> cuotas;
  final List<_PagoRow> pagosTodos;
  const _HistorialData({
    required this.prestamo,
    required this.paso,
    required this.inicio,
    required this.cuotas,
    required this.pagosTodos,
  });
}

class _PagoRow {
  final DateTime? fecha;
  final double monto;
  final String nota;
  final String? tipo;
  _PagoRow({required this.fecha, required this.monto, required this.nota, this.tipo});
}

class _CuotaPago {
  final int numero;
  final DateTime? fechaPago;
  final double montoCapital;
  final DateTime? vencimiento;
  final int diasAtraso;
  _CuotaPago({
    required this.numero,
    required this.fechaPago,
    required this.montoCapital,
    required this.vencimiento,
    required this.diasAtraso,
  });
}

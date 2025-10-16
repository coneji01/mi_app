// lib/screens/prestamo_detalle_screen.dart
import 'package:flutter/material.dart';

import '../models/prestamo.dart';
import '../widgets/app_drawer.dart';
import 'agregar_pago_screen.dart';

// 👇 usa el repositorio (backend) para eliminar
import '../data/repository.dart';

class PrestamoDetalleScreen extends StatefulWidget {
  final int? prestamoId;
  final String? clienteNombre;

  const PrestamoDetalleScreen({
    super.key,
    required this.prestamoId,
    this.clienteNombre,
  });

  @override
  State<PrestamoDetalleScreen> createState() => _PrestamoDetalleScreenState();
}

class _PrestamoDetalleScreenState extends State<PrestamoDetalleScreen> {
  Prestamo? _prestamo;
  List<Map<String, dynamic>> _pagos = [];
  bool _loading = true;
  String? _error;

  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      int? id = widget.prestamoId;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) id ??= args;

      if (id == null || id <= 0) {
        throw Exception('ID de préstamo inválido.');
      }

      final prestamoMap = await Repository.i.prestamoPorId(id);
      if (prestamoMap == null) throw Exception('No existe el préstamo #$id.');
      final prestamo = Prestamo.fromJson(prestamoMap);
      final pagos = await Repository.i.pagosDePrestamo(id);

      if (!mounted) return;
      setState(() {
        _prestamo = prestamo;
        _pagos = pagos
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ===== Helpers =====
  double _asDouble(dynamic v, [double fb = 0]) {
    if (v == null) return fb;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  String _asString(dynamic v, [String fb = '']) => v?.toString() ?? fb;

  String _fmtFechaDyn(dynamic v) {
    if (v == null) return '—';
    DateTime? d;
    if (v is DateTime) {
      d = v;
    } else if (v is String) {
      d = DateTime.tryParse(v);
    } else {
      d = DateTime.tryParse(v.toString());
    }
    if (d == null) return '—';
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$dd $hh:$mm';
  }

  String _fmtMoney(num? v) {
    final d = (v ?? 0).toDouble();
    final s = d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'RD\$$intPart${parts.length > 1 && parts[1] != '00' ? '.${parts[1]}' : ''}';
  }

  // Muestra porcentaje correcto tanto si viene 0.06 como 6
  String _pctText(num? raw) {
    if (raw == null) return '—';
    final d = raw.toDouble();
    final pct = d <= 1 ? d * 100 : d;
    final s = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 2);
    return '$s %';
  }

  // ===== Acciones =====
  Future<void> _goAgregarPago() async {
    final p = _prestamo;
    if (p == null || p.id == null) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AgregarPagoScreen(prestamoId: p.id!),
      ),
    );
    if (ok == true) _load();
  }

  // 🔴 Eliminar préstamo (backend)
  Future<void> _eliminarPrestamo() async {
    final id = _prestamo?.id;
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar préstamo'),
        content: const Text(
          'Esta acción eliminará el préstamo y sus pagos asociados. '
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await Repository.i.deletePrestamo(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Préstamo #$id eliminado')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  void _onMenu(String action) {
    switch (action) {
      case 'eliminar':
        _eliminarPrestamo();
        break;
      case 'editar':
      case 'anular':
      case 'ajustar_capital':
      case 'recalcular_mora':
      case 'reenganche':
      case 'incobrable':
      case 'imprimir_contrato':
      case 'imprimir_estado':
      case 'contactar':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Acción "$action" pendiente de implementación')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: AppSection.inicio),
      appBar: AppBar(
        title: const Text('Detalle de préstamo'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            onSelected: _onMenu,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar',            child: Text('Editar')),
              const PopupMenuItem(value: 'anular',            child: Text('Anular Préstamo')),
              const PopupMenuItem(value: 'ajustar_capital',   child: Text('Ajustar Capital')),
              const PopupMenuItem(value: 'recalcular_mora',   child: Text('Recalcular Mora')),
              const PopupMenuItem(value: 'reenganche',        child: Text('Reenganche')),
              const PopupMenuItem(value: 'incobrable',        child: Text('Incobrable')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'imprimir_contrato', child: Text('Imprimir Contrato')),
              const PopupMenuItem(value: 'imprimir_estado',   child: Text('Imprimir Estado')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'contactar',         child: Text('Contactar')),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'eliminar',
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goAgregarPago,
        icon: const Icon(Icons.attach_money),
        label: const Text('AGREGAR PAGO'),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : _buildDetalle(),
    );
  }

  Widget _buildDetalle() {
    final p = _prestamo!;
    final id = p.id ?? 0;
    final nombreCliente = widget.clienteNombre ?? '—';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Préstamo #$id',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Cliente: $nombreCliente'),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fila('Monto', _fmtMoney(p.monto)),
                _fila('Total a pagar', _fmtMoney(p.totalAPagar)),
                _fila('Saldo', _fmtMoney(p.balancePendiente)),
                _fila('Cuotas', '${p.cuotasPagadas} de ${p.cuotasTotales}'),
                _fila('Interés', _pctText(p.interes)),           // ← porcentaje correcto
                _fila('Modalidad', p.modalidad),
                _fila('Amortización', p.tipoAmortizacion),
                _fila('Inicio', _fmtFechaDyn(p.fechaInicio)),
                _fila('Próximo pago', _fmtFechaDyn(p.proximoPago)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Text('Pagos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        if (_pagos.isEmpty)
          const Text('Aún no hay pagos registrados.')
        else
          ..._pagos.map(
            (pg) => Card(
              child: ListTile(
                dense: true,
                title: Text(_fmtMoney(_asDouble(pg['monto']))),
                subtitle: Text(
                  'Fecha: ${_fmtFechaDyn(pg['fecha'])}'
                  '${_asString(pg['nota']).isNotEmpty ? '\nNota: ${_asString(pg['nota'])}' : ''}',
                ),
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(etiqueta,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}

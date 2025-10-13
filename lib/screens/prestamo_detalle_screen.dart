// lib/screens/prestamo_detalle_screen.dart
import 'package:flutter/material.dart';

import '../data/db_service.dart';
import '../models/prestamo.dart';
import '../widgets/app_drawer.dart';
import 'agregar_pago_screen.dart';

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
  final _db = DbService.instance;

  Prestamo? _prestamo;
  List<Map<String, dynamic>> _pagos = [];
  bool _loading = true;
  String? _error;

  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
  }

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

      final prestamo = await _db.getPrestamoById(id);
      if (prestamo == null) throw Exception('No existe el préstamo #$id.');
      final pagos = await _db.listarPagosDePrestamo(id);

      if (!mounted) return;
      setState(() {
        _prestamo = prestamo;
        _pagos = pagos;
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

  /// Acepta DateTime? o String? (ISO). Devuelve texto amigable.
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

  void _onMenu(String action) {
    switch (action) {
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
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'editar',            child: Text('Editar')),
              PopupMenuItem(value: 'anular',            child: Text('Anular Préstamo')),
              PopupMenuItem(value: 'ajustar_capital',   child: Text('Ajustar Capital')),
              PopupMenuItem(value: 'recalcular_mora',   child: Text('Recalcular Mora')),
              PopupMenuItem(value: 'reenganche',        child: Text('Reenganche')),
              PopupMenuItem(value: 'incobrable',        child: Text('Incobrable')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'imprimir_contrato', child: Text('Imprimir Contrato')),
              PopupMenuItem(value: 'imprimir_estado',   child: Text('Imprimir Estado')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'contactar',         child: Text('Contactar')),
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
    final interesPct = (p.interes * 100).toStringAsFixed(2);

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
                _fila('Interés', '$interesPct %'),
                _fila('Modalidad', p.modalidad),
                _fila('Amortización', p.tipoAmortizacion), // asegúrate que el modelo tenga este nombre
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

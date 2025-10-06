// lib/screens/prestamo_detalle_screen.dart
import 'package:flutter/material.dart';

import '../data/db_service.dart';        // ✅ Servicio correcto (singleton)
import '../models/prestamo.dart';        // Modelo Prestamo (id, clienteId, etc.)

class PrestamoDetalleScreen extends StatefulWidget {
  final int prestamoId;
  final String? clienteNombre;

  const PrestamoDetalleScreen({
    super.key,
    required this.prestamoId,
    this.clienteNombre,
  });

  @override
  State<PrestamoDetalleScreen> createState() => _PrestamoDetalleScreenState();
}

class _PrestamoDetalleScreenState extends State<PrestamoDetalleScreen>
    with SingleTickerProviderStateMixin {
  // ✅ Instancia válida del servicio
  final _db = DbService.instance;

  Prestamo? _prestamo;
  List<Map<String, dynamic>> _pagos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _db.getPrestamoById(widget.prestamoId);
      final rows = await _db.listarPagosDePrestamo(widget.prestamoId);

      if (!mounted) return;
      setState(() {
        _prestamo = p;
        _pagos = (rows as List).cast<Map<String, dynamic>>();
        _error = null;
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

  String _money(num? v) {
    final n = (v ?? 0).toDouble();
    final s = n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'RD\$$intPart${parts.length > 1 && parts[1] != '00' ? '.${parts[1]}' : ''}';
  }

  String _fmtFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    const dias = ['lu', 'ma', 'mi', 'ju', 'vi', 'sá', 'do'];
    const mes = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final dow = dias[(d.weekday - 1).clamp(0, 6)];
    final m = mes[(d.month - 1).clamp(0, 11)];
    final dd = d.day.toString().padLeft(2, '0');
    return '$dow, $dd $m. ${d.year}';
  }

  Widget _header() {
    final p = _prestamo;
    if (p == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clienteNombre?.isNotEmpty == true
                  ? widget.clienteNombre!
                  : 'Cliente #${p.clienteId}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 6,
              spacing: 16,
              children: [
                Text('Monto: ${_money(p.monto)}'),
                Text('Balance: ${_money(p.balancePendiente)}'),
                
                Text('Cuotas: ${p.cuotasPagadas}/${p.cuotasTotales}'),
                Text('Próximo pago: ${_fmtFecha(p.proximoPago)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagoTile(Map<String, dynamic> r) {
    final fecha = _fmtFecha(r['fecha'] as String?);
    final monto = _money((r['monto'] as num?) ?? 0);
    final nota  = (r['nota'] as String?)?.trim();

    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: Text(monto),
      subtitle: Text(nota?.isNotEmpty == true ? '$fecha · $nota' : fecha),
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_error != null
            ? Center(child: Text('Error: $_error'))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _header(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Pagos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_pagos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('Sin pagos registrados'),
                      )
                    else
                      ..._pagos.map(_pagoTile),
                    const SizedBox(height: 24),
                  ],
                ),
              ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de préstamo'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }
}

import 'package:flutter/material.dart';
import '../data/db_service.dart';
import '../routes/nav.dart'; // pushPrestamoDetalle, etc.
import '../widgets/app_drawer.dart';

class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});
  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  // ✅ DbService suele estar como singleton: usamos instance
  final _db = DbService.instance;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _db.listarPrestamosConCliente(); // <-- viene de la extensión
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
        _error = null;
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

  T? _get<T>(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k] as T;
    }
    return null;
  }

  Widget _tile(Map<String, dynamic> r) {
    final prestamoId = _get<int>(r, ['p_id', 'id']) ?? 0;
    final nombre = '${_get<String>(r, ['c_nombre', 'nombre']) ?? ''} ${_get<String>(r, ['c_apellido', 'apellido']) ?? ''}'.trim();
    final modalidad = _get<String>(r, ['modalidad']) ?? '—';
    final cuotasTot = _get<int>(r, ['cuotas_totales']) ?? 0;
    final cuotasPag = _get<int>(r, ['cuotas_pagadas']) ?? 0;
    final balance   = _get<num>(r, ['balance_pendiente']) ?? 0;
    final proximo   = _fmtFecha(_get<String>(r, ['proximo_pago']));

    final estadoTexto = (balance > 0) ? 'Pendiente' : 'Al día';
    final estadoColor = (balance > 0)
        ? Theme.of(context).colorScheme.primary
        : Colors.green;

    return InkWell(
      onTap: () async {
        await pushPrestamoDetalle(
          context,
          prestamoId: prestamoId,
          clienteNombre: nombre.isEmpty ? null : nombre,
        );
        if (!mounted) return;
        _load(); // refresca al volver
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IZQUIERDA
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.isEmpty ? 'Cliente #${_get<int>(r, ['cliente_id']) ?? '-'}' : nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            'Próximo Pago: $proximo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            'Balance Pendiente: ${_money(balance)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            'Modalidad: $modalidad',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // DERECHA (panel compacto)
            Container(
              width: 170,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cuotas $cuotasPag/$cuotasTot',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _money(balance),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          side: BorderSide(color: estadoColor),
                          foregroundColor: estadoColor,
                        ),
                        onPressed: () {},
                        child: Text(estadoTexto),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_error != null
            ? Center(child: Text('Error: $_error'))
            : (_items.isEmpty
                ? const Center(child: Text('Sin préstamos'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _tile(_items[i]),
                    ),
                  )));

    return Scaffold(
      // Muestra tu Drawer en esta pantalla
      drawer: const AppDrawer(current: AppSection.prestamos),
      appBar: AppBar(
        title: const Text('Préstamos'),
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

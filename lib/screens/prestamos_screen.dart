// lib/screens/prestamos_screen.dart
import 'package:flutter/material.dart';
import '../data/db_service.dart';
import '../routes/nav.dart';
import '../widgets/app_drawer.dart';

class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});
  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  final _db = DbService.instance;

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;

  // Paginación local
  final List<int> _pageSizes = const [10, 15, 25, 50];
  int _pageSize = 15;
  int _page = 0; // 0-based

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _db.listarPrestamosConCliente();
      if (!mounted) return;
      setState(() {
        _all = rows;
        _loading = false;
        _error = null;
        _page = 0;
      });

      // Debug opcional
      if (_all.isNotEmpty) {
        debugPrint('🔑 Llaves: ${_all.first.keys.toList()}');
        debugPrint('🧪 Row0: ${_all.first}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ===== Helpers =====
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
      if (m.containsKey(k) && m[k] != null) {
        final v = m[k];
        if (v is T) return v;
        // Conversión flexible para num/int/double/String
        if (T == String) return v.toString() as T;
        if (T == num && v is num) return v as T;
        if (T == int && v is num) return v.toInt() as T;
        if (T == double && v is num) return v.toDouble() as T;
      }
    }
    return null;
  }

  // Balance con respaldo: balancePendiente -> balance_pendiente -> balanceCalculado
  double _balance(Map<String, dynamic> r) {
    return (_get<num>(r, ['balancePendiente', 'balance_pendiente'])
              ?? _get<num>(r, ['balanceCalculado'])
              ?? 0)
        .toDouble();
  }

  ({String label, Color color, String? extra}) _estadoPrestamo(Map<String, dynamic> r) {
    final balance = _balance(r);
    final modalidad = (_get<String>(r, ['modalidad']) ?? '').toLowerCase();
    final cuotasTot = _get<int>(r, ['cuotasTotales', 'cuotas_totales']) ?? 0;
    final cuotasPag = _get<int>(r, ['cuotasPagadas', 'cuotas_pagadas']) ?? 0;

    if (balance <= 0 || (cuotasTot > 0 && cuotasPag >= cuotasTot)) {
      return (label: 'Al día', color: Colors.green, extra: null);
    }

    final iso = _get<String>(r, ['proximoPago', 'proximo_pago']);
    final hoy = DateTime.now();
    DateTime? prox = (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso);

    int? vencidas;
    if (prox != null && prox.isBefore(DateTime(hoy.year, hoy.month, hoy.day))) {
      Duration paso;
      if (modalidad.contains('seman')) {
        paso = const Duration(days: 7);
      } else if (modalidad.contains('mens')) {
        paso = const Duration(days: 30);
      } else {
        paso = const Duration(days: 14); // quincenal por defecto
      }
      int c = 0;
      var cursor = prox;
      while (cursor.isBefore(DateTime(hoy.year, hoy.month, hoy.day))) {
        c++;
        cursor = cursor.add(paso);
        if (c > 99) break;
      }
      vencidas = c > 0 ? c : null;
    }

    if (vencidas != null) {
      return (label: 'Vencida', color: Colors.red, extra: 'Cuotas vencidas: $vencidas');
    }
    return (label: 'Pendiente', color: Theme.of(context).colorScheme.primary, extra: null);
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _estadoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  // ====== ITEM (tarjeta) ======
  Widget _tile(Map<String, dynamic> r) {
    // IDs y nombres robustos a aliases de tu SQL
    final prestamoId = _get<int>(r, ['prestamoId', 'p_id', 'id']) ?? 0;
    final nombre = '${_get<String>(r, ['clienteNombre', 'c_nombre', 'nombre']) ?? ''} '
                   '${_get<String>(r, ['clienteApellido', 'c_apellido', 'apellido']) ?? ''}'.trim();

    final modalidad  = _get<String>(r, ['modalidad']) ?? '—';
    final cuotasTot  = _get<int>(r, ['cuotasTotales', 'cuotas_totales']) ?? 0;
    final cuotasPag  = _get<int>(r, ['cuotasPagadas', 'cuotas_pagadas']) ?? 0;
    final balance    = _balance(r);
    final proximo    = _fmtFecha(_get<String>(r, ['proximoPago', 'proximo_pago']));

    final est = _estadoPrestamo(r);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: 0.5,
      child: InkWell(
        onTap: () async {
          await pushPrestamoDetalle(
            context,
            prestamoId: prestamoId,
            clienteNombre: nombre.isEmpty ? null : nombre,
          );
          if (!mounted) return;
          _load();
        },
        child: SizedBox(
          height: 128, // altura fija del ítem
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IZQUIERDA
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nombre.isEmpty ? 'Cliente #${_get<int>(r, ['clienteId', 'cliente_id']) ?? '-'}' : nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv('Próximo Pago:', proximo),
                          _kv('Balance Pendiente:', _money(balance)),
                          _kv('Modalidad:', modalidad),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Separador
              Container(width: 1, color: Theme.of(context).dividerColor.withOpacity(0.4)),
              // DERECHA
              SizedBox(
                width: 170,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Cuotas $cuotasPag/$cuotasTot',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _money(balance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _estadoChip(est.label, est.color),
                            if (est.extra != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.05),
                                  border: Border.all(color: Colors.red),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  est.extra!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paginator(int start, int end, int total) {
    final totalPages = (total == 0) ? 1 : ((total - 1) ~/ _pageSize) + 1;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          DropdownButton<int>(
            value: _pageSize,
            items: _pageSizes.map((s) => DropdownMenuItem(value: s, child: Text('$s'))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _pageSize = v;
                _page = 0;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(
            total == 0 ? '0–0 de 0' : '${start + 1}–$end de $total',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: (_page + 1) < totalPages ? () => setState(() => _page++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = _page * _pageSize;
    final end = (_all.isEmpty) ? 0 : (start + _pageSize > _all.length ? _all.length : start + _pageSize);
    final slice = (start < _all.length) ? _all.sublist(start, end) : <Map<String, dynamic>>[];
    final total = _all.length;

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_error != null
            ? Center(child: Text('Error: $_error'))
            : (_all.isEmpty
                ? const Center(child: Text('Sin préstamos'))
                : Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: slice.length,
                            itemExtent: 140, // altura aprox. del ítem (128 + márgenes)
                            itemBuilder: (_, i) => _tile(slice[i]),
                          ),
                        ),
                      ),
                      _paginator(start, end, total),
                    ],
                  )));

    return Scaffold(
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

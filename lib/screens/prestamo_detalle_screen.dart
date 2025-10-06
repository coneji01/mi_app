// lib/screens/prestamo_detalle_screen.dart
import 'package:flutter/material.dart';
import '../data/db.dart';
import '../models/prestamo.dart';

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
  final _db = DbService();

  Prestamo? _prestamo;
  bool _loading = true;
  String? _error;

  final List<_PagoLinea> _pagos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _db.getPrestamoById(widget.prestamoId);
      if (!mounted) return;
      setState(() {
        _prestamo = p;
        _loading = false;
      });
      if (p != null) {
        await _loadPagos();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadPagos() async {
    if (_prestamo?.id == null) return;
    final rows = await _db.listarPagosDePrestamo(_prestamo!.id!);
    if (!mounted) return;
    setState(() {
      _pagos
        ..clear()
        ..addAll(rows.map((r) => _PagoLinea(
              concepto: (r['tipo'] ?? r['nota'] ?? '').toString(),
              fecha: _fmtFechaUI(r['fecha']?.toString()),
              vence: _fmtFechaUI(r['vence']?.toString()),
              total: (r['monto'] as num?)?.toDouble() ?? 0,
            )));
    });
  }

  String _money(num? v) => v == null ? '-' : 'RD\$ ${v.toStringAsFixed(2)}';

  DateTime _parseFecha(String? s) {
    if (s == null || s.isEmpty) return DateTime.now();
    final t = DateTime.tryParse(s);
    return t ?? DateTime.now();
  }

  String _fmtFechaISO(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtFechaUI(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return '-';
    return _fmtFechaISO(d);
  }

  DateTime _addPeriodos(DateTime base, String modalidad, int count) {
    var d = base;
    for (int i = 0; i < count; i++) {
      switch (modalidad.toLowerCase()) {
        case 'diario':
          d = d.add(const Duration(days: 1));
          break;
        case 'interdiario':
          d = d.add(const Duration(days: 2));
          break;
        case 'semanal':
          d = d.add(const Duration(days: 7));
          break;
        case 'bisemanal':
          d = d.add(const Duration(days: 14));
          break;
        case 'quincenal':
        case '15 y fin de mes':
          d = d.add(const Duration(days: 15));
          break;
        case 'mensual':
          d = DateTime(d.year, d.month + 1, d.day);
          break;
        case 'anual':
          d = DateTime(d.year + 1, d.month, d.day);
          break;
        default:
          d = d.add(const Duration(days: 30));
      }
    }
    return d;
  }

  Future<void> _onAgregarPago() async {
    if (_prestamo == null) return;
    final p = _prestamo!;

    final pendientes =
        (p.cuotasTotales - p.cuotasPagadas).clamp(0, p.cuotasTotales);
    if (pendientes == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este préstamo ya está saldado.')),
      );
      return;
    }

    int cuotasAPagar = 1;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pagar cuotas',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cantidad:'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: cuotasAPagar, // ✅ reemplaza `value:`
                          items: List.generate(pendientes, (i) => i + 1)
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text('$e')))
                              .toList(),
                          onChanged: (v) => setSt(() => cuotasAPagar = v ?? 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('de $pendientes'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Continuar'),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return; // 👈 usamos `context` más abajo

    final tipo = p.tipoAmortizacion
        .toLowerCase()
        .replaceAll('í', 'i')
        .replaceAll('é', 'e');
    final esInteresFijo = tipo.contains('interes fijo') ||
        tipo.contains('interesfijo') ||
        tipo.contains('interes_fijo');

    if (!esInteresFijo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solo “Interés Fijo”. Actual: ${p.tipoAmortizacion}')),
      );
      return;
    }

    final r = p.interes / 100.0;
    final capitalPorCuota = p.monto / p.cuotasTotales;
    final interesPorCuota = p.monto * r;

    final capitalTotal = capitalPorCuota * cuotasAPagar;
    final interesTotal = interesPorCuota * cuotasAPagar;
    final totalPago = capitalTotal + interesTotal;

    final nuevasCuotasPagadas =
        (p.cuotasPagadas + cuotasAPagar).clamp(0, p.cuotasTotales);
    final nuevoBalance = (p.balancePendiente - capitalTotal);
    final nuevoBalanceClamped = nuevoBalance < 0 ? 0.0 : nuevoBalance;

    final fechaBase = _parseFecha(p.proximoPago);
    final nuevaFecha = _addPeriodos(fechaBase, p.modalidad, cuotasAPagar);

    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cuotas a pagar: $cuotasAPagar'),
            Text('Capital: ${_money(capitalTotal)}'),
            Text('Interés: ${_money(interesTotal)}'),
            const Divider(),
            Text('Total a cobrar: ${_money(totalPago)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Quedarán pagadas: $nuevasCuotasPagadas/${p.cuotasTotales}'),
            Text('Nuevo balance: ${_money(nuevoBalanceClamped)}'),
            Text('Próximo pago: ${_fmtFechaISO(nuevaFecha)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (conf != true) return;

    try {
      final updated = await _db.registrarPagoCuotas(
        prestamoId: p.id!,
        cuotas: cuotasAPagar,
        capital: capitalTotal,
        interes: interesTotal,
        total: totalPago,
        fecha: DateTime.now(),
        vence: fechaBase,
        proximoPago: nuevaFecha,
      );

      if (!mounted) return;
      setState(() => _prestamo = updated);
      await _loadPagos();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pago aplicado: ${_money(totalPago)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar el pago: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalles'),
          actions: [
            IconButton(
              tooltip: 'Notificaciones',
              icon: const Icon(Icons.notifications_none),
              onPressed: () {},
            ),
            IconButton(
              tooltip: 'WhatsApp',
              icon: const Icon(Icons.chat),
              onPressed: () {},
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : _prestamo == null
                    ? const Center(child: Text('Préstamo no encontrado'))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 28,
                                  child: Icon(Icons.person),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.clienteNombre ??
                                            'Cliente #${_prestamo!.clienteId}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cuotas vencidas: 0',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                                child: _MetricsGrid(
                                  items: [
                                    _M('RD\$${_prestamo!.monto.toStringAsFixed(0)}',
                                        'Capital actual'),
                                    _M(
                                        '${_prestamo!.cuotasPagadas}/${_prestamo!.cuotasTotales}',
                                        'Cuotas'),
                                    _M(_prestamo!.tipoAmortizacion,
                                        'Amortización'),
                                    _M(_fmtFechaUI(_prestamo!.proximoPago),
                                        'Próximo Pago'),
                                    _M('${_prestamo!.interes} %', 'Interés'),
                                    _M(_money(_prestamo!.balancePendiente),
                                        'Total por Saldar'),
                                    _M(_money(_prestamo!.balancePendiente),
                                        'Balance pendiente',
                                        color: Colors.red),
                                    _M(_prestamo!.modalidad, 'Modalidad'),
                                    const _M('% 0', 'Mora'),
                                    const _M('% 0', 'Comisión'),
                                    const _M('0', 'Gastos legales'),
                                    const _M('—', 'Atraso'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _onAgregarPago,
                                    child: const Text('AGREGAR PAGO'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  tooltip: 'Opciones del préstamo',
                                  icon: const Icon(Icons.arrow_drop_down),
                                  onSelected: (v) {},
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                        value: 'editar', child: Text('Editar')),
                                    PopupMenuItem(
                                        value: 'anular',
                                        child: Text('Anular Préstamo',
                                            style: TextStyle(color: Colors.red))),
                                    PopupMenuItem(
                                        value: 'ajustar',
                                        child: Text('Ajustar Capital')),
                                    PopupMenuItem(
                                        value: 'recalcular_mora',
                                        child: Text('Recalcular Mora')),
                                    PopupMenuItem(
                                        value: 'reenganche',
                                        child: Text('Reenganche')),
                                    PopupMenuItem(
                                        value: 'incobrable',
                                        child: Text('Incobrable')),
                                    PopupMenuItem(
                                        value: 'imprimir_contrato',
                                        child: Text('Imprimir Contrato')),
                                    PopupMenuItem(
                                        value: 'imprimir_estado',
                                        child: Text('Imprimir Estado')),
                                    PopupMenuItem(
                                        value: 'contactar',
                                        child: Text('Contactar')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: TabBar(
                                      isScrollable: true,
                                      tabs: [
                                        Tab(text: 'Pagos'),
                                        Tab(text: 'Amortización'),
                                        Tab(text: 'Notas (0)'),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: const [
                                      Text('Anulado'),
                                      Switch(value: false, onChanged: null),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _PagosTab(pagos: _pagos),
                                _AmortizacionTab(prestamo: _prestamo!),
                                _NotasTab(prestamo: _prestamo!),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _PagoLinea {
  final String concepto;
  final String fecha;
  final String vence;
  final num total;
  _PagoLinea({
    required this.concepto,
    required this.fecha,
    required this.vence,
    required this.total,
  });
}

class _M {
  final String value;
  final String label;
  final Color? color;
  const _M(this.value, this.label, {this.color});
}

/// Versión sin `BoxConstraints`: usa `MediaQuery` para decidir columnas
class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.items});
  final List<_M> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final double w = MediaQuery.sizeOf(context).width;
    final int cols = w > 900 ? 4 : (w > 600 ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 2.7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: it.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                it.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PagosTab extends StatelessWidget {
  const _PagosTab({required this.pagos});
  final List<_PagoLinea> pagos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: const [
              Expanded(
                child: Text('Concepto',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: Text('Fecha',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Text('Fecha Vencimiento',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: pagos.isEmpty
              ? const Center(child: Text('Sin pagos aún'))
              : ListView.separated(
                  itemCount: pagos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = pagos[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(r.concepto)),
                          const SizedBox(width: 8),
                          SizedBox(width: 110, child: Text(r.fecha)),
                          const SizedBox(width: 8),
                          SizedBox(width: 150, child: Text(r.vence)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AmortizacionTab extends StatelessWidget {
  const _AmortizacionTab({required this.prestamo});
  final Prestamo prestamo;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Tabla de amortización (pendiente)'));
  }
}

class _NotasTab extends StatelessWidget {
  const _NotasTab({required this.prestamo});
  final Prestamo prestamo;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Sin notas'));
  }
}

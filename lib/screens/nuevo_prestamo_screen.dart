// lib/screens/nuevo_prestamo_screen.dart
import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';
import '../models/cliente.dart';
import '../models/prestamo_propuesta.dart';
import '../models/prestamo.dart';
import '../data/db.dart';

class NuevoPrestamoScreen extends StatelessWidget {
  final Cliente cliente;
  final PrestamoPropuesta propuesta;

  const NuevoPrestamoScreen({
    super.key,
    required this.cliente,
    required this.propuesta,
  });

  // Calcula el próximo pago según la modalidad
  DateTime _calcProximoPago(DateTime base, String modalidad) {
    final m = modalidad.toLowerCase();
    if (m.contains('diario')) return base.add(const Duration(days: 1));
    if (m.contains('interdiario')) return base.add(const Duration(days: 2));
    if (m.contains('biseman')) return base.add(const Duration(days: 14));
    if (m.contains('seman')) return base.add(const Duration(days: 7));
    if (m.contains('quinc')) return base.add(const Duration(days: 15));
    if (m.contains('mens')) return DateTime(base.year, base.month + 1, base.day);
    if (m.contains('anual')) return DateTime(base.year + 1, base.month, base.day);
    // default: 30 días
    return base.add(const Duration(days: 30));
  }

  String _money(num v) => 'RD\$ ${v.toStringAsFixed(2)}';

  Future<void> _guardar(BuildContext context) async {
    final now = DateTime.now();

    // Capital a saldar inicia igual al monto (el interés no reduce capital).
    final balanceInicial = propuesta.monto;

    // totalAPagar requerido por el modelo/BD.
    final double totalAPagar = propuesta.cuota * propuesta.cuotas;

    final proximoPago =
        _calcProximoPago(now, propuesta.modalidad).toIso8601String();

    try {
      await DbService().crearPrestamo(
        Prestamo(
          clienteId: cliente.id!,
          monto: propuesta.monto,
          balancePendiente: balanceInicial,
          totalAPagar: totalAPagar,              // ✅ requerido
          cuotasTotales: propuesta.cuotas,
          cuotasPagadas: 0,
          interes: propuesta.tasaPorPeriodo / 100, // tasa por periodo en %
          modalidad: propuesta.modalidad,
          tipoAmortizacion: propuesta.tipoAmortizacion,
          fechaInicio: now.toIso8601String(),
          proximoPago: proximoPago,                // String (ISO)
        ),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préstamo creado')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear el préstamo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAPagarAproximado = propuesta.cuota * propuesta.cuotas;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo préstamo')),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cliente.nombre} ${cliente.apellido}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: Text('Modalidad: ${propuesta.modalidad}')),
                      Expanded(
                          child: Text(
                              'Amortización: ${propuesta.tipoAmortizacion}')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text('Cuotas: ${propuesta.cuotas}')),
                      Expanded(
                          child: Text(
                              'Tasa/Periodo: ${propuesta.tasaPorPeriodo.toStringAsFixed(2)}%')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _KV('Monto', _money(propuesta.monto)),
                  const SizedBox(height: 6),
                  _KV('Cuota aproximada', _money(propuesta.cuota)),
                  const SizedBox(height: 6),
                  _KV('Total aproximado a pagar', _money(totalAPagarAproximado)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _guardar(context),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(k, style: t.bodyMedium)),
        Text(v, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

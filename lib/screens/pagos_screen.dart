import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/app_drawer.dart';
import '../data/db_service.dart';
import '../models/pago_vista.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  final _db = DbService.instance;

  List<PagoVista> _pagos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Siempre agrupado (capital + interés sumados por cliente/préstamo/día)
      final data = await _db.listarPagosConCliente();
      if (!mounted) return;
      setState(() {
        _pagos = data;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar pagos: $e';
        _cargando = false;
      });
    }
  }

  String _fmtMonto(double monto) =>
      NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$').format(monto);

  String _fmtFecha(DateTime fecha) =>
      DateFormat('dd/MM/yyyy').format(fecha);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: AppSection.pagos),
      appBar: AppBar(
        title: const Text('Pagos'),
        centerTitle: false,
      ),
      body: SafeArea(child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_pagos.isEmpty) {
      return const Center(child: Text('No hay pagos registrados'));
    }

    return RefreshIndicator(
      onRefresh: _cargarPagos,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _pagos.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, i) {
          final p = _pagos[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            title: Text(
              p.clienteNombre,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              _fmtFecha(p.fecha),
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              _fmtMonto(p.monto),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            onTap: () {
              // futuro: navegar a detalle del préstamo con p.prestamoId (si lo necesitas)
            },
          );
        },
      ),
    );
  }
}

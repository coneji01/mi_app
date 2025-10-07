// lib/screens/cliente_detalle_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../models/prestamo_propuesta.dart';
import '../data/db_service.dart';

import 'calculadora_screen.dart';
import 'nuevo_prestamo_screen.dart';
import 'editar_cliente_screen.dart';

enum _MenuAccion { nuevoPrestamo, editarCliente }

class ClienteDetalleScreen extends StatefulWidget {
  final Cliente cliente;

  const ClienteDetalleScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  final _db = DbService.instance;

  late Cliente _cliente;   // estado local
  bool _touched = false;   // hubo cambios

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;
    _refreshFromDb(); // por si venimos de una lista cacheada
  }

  Future<void> _refreshFromDb() async {
    final id = _cliente.id;
    if (id == null) return;
    try {
      final fresh = await _db.getClienteById(id);
      if (!mounted) return;
      if (fresh != null) setState(() => _cliente = fresh);
    } catch (_) {
      // refresco silencioso
    }
  }

  String _sexoLegible(Sexo? sexo) {
    switch (sexo) {
      case Sexo.masculino:
        return 'Masculino';
      case Sexo.femenino:
        return 'Femenino';
      case Sexo.otro:
      default:
        return 'Otro';
    }
  }

  Widget _tile({
    required IconData icon,
    required String titulo,
    String? valor,
  }) {
    final v = (valor ?? '').trim();
    return ListTile(
      leading: Icon(icon),
      title: Text(titulo),
      subtitle: Text(v.isEmpty ? '—' : v),
    );
  }

  Future<void> _onAccionSeleccionada(BuildContext context, _MenuAccion a) async {
    switch (a) {
      case _MenuAccion.nuevoPrestamo:
        if (_cliente.id == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este cliente aún no tiene ID')),
          );
          return;
        }

        // 1) Obtenemos propuesta desde calculadora (en modo retorno)
        final propuesta = await Navigator.of(context).push<PrestamoPropuesta>(
          MaterialPageRoute(
            builder: (_) => const CalculadoraScreen(returnMode: true),
          ),
        );
        if (!context.mounted || propuesta == null) return;

        // 2) Abrimos la pantalla de nuevo préstamo con cliente + propuesta
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => NuevoPrestamoScreen(
              cliente: _cliente,
              propuesta: propuesta,
            ),
          ),
        );
        break;

      case _MenuAccion.editarCliente:
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditarClienteScreen(cliente: _cliente),
          ),
        );
        if (!mounted) return;

        if (result is Cliente) {
          setState(() {
            _cliente = result;
            _touched = true;
          });
        } else if (result == true) {
          await _refreshFromDb();
          _touched = true;
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneFoto =
        _cliente.fotoPath != null &&
        _cliente.fotoPath!.isNotEmpty &&
        File(_cliente.fotoPath!).existsSync();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_touched) {
          Navigator.of(context).pop(_cliente);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Cliente'),
          actions: [
            IconButton(
              tooltip: 'Refrescar',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshFromDb,
            ),
            PopupMenuButton<_MenuAccion>(
              onSelected: (a) => _onAccionSeleccionada(context, a),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MenuAccion.nuevoPrestamo,
                  child: Row(
                    children: [
                      Icon(Icons.request_page_outlined),
                      SizedBox(width: 8),
                      Text('Crear préstamo'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _MenuAccion.editarCliente,
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Editar cliente'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_cliente_detalle',
          onPressed: () => _onAccionSeleccionada(context, _MenuAccion.nuevoPrestamo),
          icon: const Icon(Icons.add),
          label: const Text('Crear préstamo'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage:
                      tieneFoto ? FileImage(File(_cliente.fotoPath!)) : null,
                  child: !tieneFoto ? const Icon(Icons.person, size: 36) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_cliente.nombre} ${_cliente.apellido}'.trim(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _tile(icon: Icons.perm_identity, titulo: 'Cédula', valor: _cliente.cedula),
            _tile(icon: Icons.male, titulo: 'Sexo', valor: _sexoLegible(_cliente.sexo)),
            _tile(icon: Icons.home_outlined, titulo: 'Dirección', valor: _cliente.direccion),
            _tile(icon: Icons.phone, titulo: 'Teléfono', valor: _cliente.telefono),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(_cliente.creadoEn),
              subtitle: const Text('Creado en (ISO-8601)'),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/screens/clientes_screen.dart
import 'package:flutter/material.dart';

import '../data/db_service.dart';
import '../models/cliente.dart';
import 'nuevo_cliente_screen.dart';
import 'cliente_detalle_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _db = DbService.instance;

  List<Cliente> _clientes = [];
  bool _cargando = true;
  String? _error;

  // normaliza: recorta y convierte null -> ''
  String _nn(String? s) => s?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await _db.getClientes(); // tipado a List<Cliente>
      if (!mounted) return;
      setState(() {
        _clientes = data;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$e';
      });
    }
  }

  Future<void> _irNuevoCliente() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NuevoClienteScreen()),
    );
    if (creado == true) {
      setState(() => _cargando = true);
      await _cargar();
    }
  }

  void _irDetalle(Cliente c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClienteDetalleScreen(cliente: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error: $_error'),
                )
              : _clientes.isEmpty
                  ? const Center(child: Text('Sin clientes'))
                  : ListView.separated(
                      itemCount: _clientes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _clientes[i];

                        // título: nombre + apellido (evitando null/espacios)
                        final titulo = [_nn(c.nombre), _nn(c.apellido)]
                            .where((s) => s.isNotEmpty)
                            .join(' ');

                        // subtítulo: teléfono si hay, si no dirección
                        final subtituloSrc =
                            _nn(c.telefono).isNotEmpty ? _nn(c.telefono) : _nn(c.direccion);

                        return ListTile(
                          title: Text(titulo.isEmpty ? 'Sin nombre' : titulo),
                          subtitle:
                              subtituloSrc.isEmpty ? null : Text(subtituloSrc),
                          onTap: () => _irDetalle(c),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irNuevoCliente,
        label: const Text('Nuevo'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

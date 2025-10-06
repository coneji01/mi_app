import 'package:flutter/material.dart';
import '../data/db.dart';
import '../models/cliente.dart';
import 'nuevo_cliente_screen.dart';
import 'cliente_detalle_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _db = DbService();
  List<Cliente> _clientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await _db.getClientes(); // ordenado por creado_en DESC
      if (!mounted) return;
      setState(() {
        _clientes = data;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  Future<void> _agregarCliente() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NuevoClienteScreen()),
    );
    if (created == true) await _cargar();
  }

  Future<void> _borrar(Cliente c) async {
    await _db.deleteCliente(c.id!);
    await _cargar();
  }

  Future<void> _irADetalle(Cliente c) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClienteDetalleScreen(cliente: c)),
    );

    if (!mounted) return;

    if (result is Cliente) {
      setState(() {
        final idx = _clientes.indexWhere((x) => x.id == result.id);
        if (idx != -1) _clientes[idx] = result; // refresco inmediato
      });
    } else if (result == true) {
      await _cargar(); // fallback legacy si algún flujo aún devuelve bool
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarCliente,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _clientes.isEmpty
                  ? const Center(child: Text('Sin clientes'))
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _clientes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = _clientes[i];
                          return ListTile(
                            leading:
                                const CircleAvatar(child: Icon(Icons.person)),
                            title: Text('${c.nombre} ${c.apellido}'),
                            subtitle: Text(c.cedula ?? '—'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _borrar(c),
                              tooltip: 'Eliminar',
                            ),
                            onTap: () => _irADetalle(c),
                          );
                        },
                      ),
                    ),
    );
  }
}

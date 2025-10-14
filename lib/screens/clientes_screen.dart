import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../models/cliente.dart';
import 'nuevo_cliente_screen.dart';
import 'cliente_detalle_screen.dart';
import '../data/repository.dart';
import '../../main.dart' show routeObserver; // <-- importa el observer

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> with RouteAware {
  List<Cliente> _clientes = [];
  bool _cargando = true;
  String? _error;

  String _nn(String? s) => s?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // Suscribirse al RouteObserver
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  // Desuscribir
  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Llamado cuando otra pantalla se cierra y esta vuelve a ser visible
  @override
  void didPopNext() {
    // por si volvemos sin resultado (por botón back, etc.)
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await _fetchClientesDesdeRepositorio();
      if (!mounted) return;
      setState(() {
        _clientes = data;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$e';
      });
    }
  }

  Future<List<Cliente>> _fetchClientesDesdeRepositorio() async {
    final dynamic any = await Repository.i.clientes();
    if (any is List<Cliente>) return any;
    if (any is List) {
      return any.map<Cliente>((e) {
        if (e is Cliente) return e;
        final m = Map<String, dynamic>.from(e as Map);
        return Cliente.fromMap(m);
      }).toList();
    }
    return <Cliente>[];
  }

  Future<void> _irNuevoCliente() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NuevoClienteScreen()),
    );
    if (creado == true) {
      // si la pantalla hija avisó “true”, recargamos
      await _cargar();
    }
  }

  void _irDetalle(Cliente c) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteDetalleScreen(cliente: c)),
    );
    if (changed == true) {
      // si editar/eliminar devolvió true, recargamos
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: AppSection.clientes),
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
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
                        final titulo = [_nn(c.nombre), _nn(c.apellido)]
                            .where((s) => s.isNotEmpty)
                            .join(' ');
                        final subtituloSrc = _nn(c.telefono).isNotEmpty
                            ? _nn(c.telefono)
                            : _nn(c.direccion);
                        return ListTile(
                          title: Text(titulo.isEmpty ? 'Sin nombre' : titulo),
                          subtitle: subtituloSrc.isEmpty ? null : Text(subtituloSrc),
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

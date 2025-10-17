import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/cliente_avatar.dart';
import '../models/cliente.dart';
import 'nuevo_cliente_screen.dart';
import 'cliente_detalle_screen.dart';
import '../data/repository.dart';
import '../../main.dart' show routeObserver; // observer para didPopNext

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> with RouteAware {
  final TextEditingController _searchController = TextEditingController();
  List<Cliente> _clientes = [];
  List<Cliente> _clientesFiltrados = [];
  bool _cargando = true;
  String? _error;
  int _pageSize = 20;
  final List<int> _pageSizeOptions = const [10, 15, 20, 50];

  String _nn(String? s) => s?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_aplicarFiltros);
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.removeListener(_aplicarFiltros);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
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
        _clientesFiltrados = _filtrarClientes(data, _searchController.text);
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

  void _aplicarFiltros() {
    if (!mounted) return;
    final term = _searchController.text;
    setState(() {
      _clientesFiltrados = _filtrarClientes(_clientes, term);
    });
  }

  List<Cliente> _filtrarClientes(List<Cliente> source, String term) {
    final q = term.trim().toLowerCase();
    if (q.isEmpty) return List<Cliente>.from(source);
    return source.where((cliente) {
      final valores = [
        cliente.nombre,
        cliente.apellido,
        cliente.cedula,
        cliente.telefono,
        cliente.direccion,
      ].whereType<String>().map((e) => e.toLowerCase());
      return valores.any((valor) => valor.contains(q));
    }).toList();
  }

  Widget _buildFiltros(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar cliente',
              hintText: 'Nombre, apellido, cédula o teléfono',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _aplicarFiltros();
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Mostrar:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _pageSize,
                items: _pageSizeOptions
                    .map((cantidad) => DropdownMenuItem<int>(
                          value: cantidad,
                          child: Text('$cantidad'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null || value == _pageSize) return;
                  setState(() {
                    _pageSize = value;
                  });
                },
              ),
              const SizedBox(width: 4),
              const Text('clientes'),
              const Spacer(),
              Text(
                _clientesFiltrados.isEmpty
                    ? 'Sin coincidencias'
                    : 'Mostrando ${math.min(_clientesFiltrados.length, _pageSize)} de ${_clientesFiltrados.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _irNuevoCliente() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NuevoClienteScreen()),
    );
    if (creado == true) {
      await _cargar();
    }
  }

  void _irDetalle(Cliente c) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteDetalleScreen(cliente: c)),
    );
    if (changed == true) {
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: AppSection.clientes),
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh))],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error: $_error'),
                )
              : Column(
                  children: [
                    _buildFiltros(context),
                    const Divider(height: 1),
                    Expanded(
                      child: _clientes.isEmpty
                          ? const Center(child: Text('Sin clientes'))
                          : _clientesFiltrados.isEmpty
                              ? const Center(child: Text('Sin coincidencias'))
                              : _buildListaClientes(),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irNuevoCliente,
        label: const Text('Nuevo'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
    );
  }

  Widget _buildListaClientes() {
    final limite = math.min(_clientesFiltrados.length, _pageSize);
    final visibles = _clientesFiltrados.take(limite).toList();
    return ListView.separated(
      itemCount: visibles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = visibles[i];
        final titulo = [_nn(c.nombre), _nn(c.apellido)]
            .where((s) => s.isNotEmpty)
            .join(' ');
        final subtituloSrc =
            _nn(c.telefono).isNotEmpty ? _nn(c.telefono) : _nn(c.direccion);

        return ListTile(
          leading: ClienteAvatar(cliente: c, radius: 24),
          title: Text(titulo.isEmpty ? 'Sin nombre' : titulo),
          subtitle: subtituloSrc.isEmpty ? null : Text(subtituloSrc),
          onTap: () => _irDetalle(c),
        );
      },
    );
  }
}

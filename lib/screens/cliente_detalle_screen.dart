// lib/screens/cliente_detalle_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../models/prestamo_propuesta.dart';

// Backend
import '../data/repository.dart';

import 'calculadora_screen.dart';
import 'nuevo_prestamo_screen.dart';
import 'editar_cliente_screen.dart';
import 'cliente_historial_screen.dart';

enum _MenuAccion { nuevoPrestamo, verHistorial, editarCliente, eliminarCliente }

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
  late Cliente _cliente;   // estado local
  bool _touched = false;   // hubo cambios

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;
    // Si más adelante expones un endpoint GET /clientes/{id}, aquí podrías refrescar.
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

  Future<void> _eliminarCliente() async {
    if (_cliente.id == null) return;

    final nombre = '${_cliente.nombre ?? ''} ${_cliente.apellido ?? ''}'.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
          '¿Seguro que deseas eliminar a${nombre.isEmpty ? '' : ' "$nombre"'}?\n'
          'Se borrarán también sus préstamos y pagos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await Repository.i.eliminarCliente(_cliente.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente eliminado')),
      );
      // Volvemos a la lista pidiendo que recargue
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
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

        final propuesta = await Navigator.of(context).push<PrestamoPropuesta>(
          MaterialPageRoute(
            builder: (_) => const CalculadoraScreen(returnMode: true),
          ),
        );
        if (!context.mounted || propuesta == null) return;

        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => NuevoPrestamoScreen(
              cliente: _cliente,
              propuesta: propuesta,
            ),
          ),
        );
        break;

      case _MenuAccion.verHistorial:
        if (_cliente.id == null) return;
        final nombreCompleto =
            '${_cliente.nombre ?? ''} ${_cliente.apellido ?? ''}'.trim();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClienteHistorialScreen(
              clienteId: _cliente.id!,
              clienteNombre: nombreCompleto.isEmpty ? null : nombreCompleto,
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
          _touched = true; // editado; que la lista recargue al volver
        }
        break;

      case _MenuAccion.eliminarCliente:
        await _eliminarCliente();
        break;
    }
  }

  /// Menú desplegable del botón con flecha (split-button)
  Future<void> _showSplitMenu(BuildContext context) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject() as RenderBox?;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box?.localToGlobal(Offset.zero, ancestor: overlay) ?? Offset.zero,
        box?.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay) ??
            const Offset(0, 0),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_MenuAccion>(
      context: context,
      position: position,
      items: const [
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
          value: _MenuAccion.verHistorial,
          child: Row(
            children: [
              Icon(Icons.history),
              SizedBox(width: 8),
              Text('Ver historial de préstamos'),
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
        PopupMenuItem(
          value: _MenuAccion.eliminarCliente,
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar cliente'),
            ],
          ),
        ),
      ],
    );

    if (selected != null) {
      await _onAccionSeleccionada(context, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneFoto = (_cliente.fotoPath != null &&
        _cliente.fotoPath!.isNotEmpty &&
        File(_cliente.fotoPath!).existsSync());

    final nombreCompleto =
        '${_cliente.nombre ?? ''} ${_cliente.apellido ?? ''}'.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_touched) {
          Navigator.of(context).pop(true); // indica recarga
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Cliente'),
          actions: [
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
                  value: _MenuAccion.verHistorial,
                  child: Row(
                    children: [
                      Icon(Icons.history),
                      SizedBox(width: 8),
                      Text('Ver historial de préstamos'),
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
                PopupMenuItem(
                  value: _MenuAccion.eliminarCliente,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar cliente'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // === BARRA INFERIOR con botón ancho + flecha (split-button) ===
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('AGREGAR PRÉSTAMO'),
                    onPressed: () =>
                        _onAccionSeleccionada(context, _MenuAccion.nuevoPrestamo),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _showSplitMenu(context),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ],
            ),
          ),
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
                    nombreCompleto.isEmpty ? 'Cliente sin nombre' : nombreCompleto,
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
              title: Text(_cliente.creadoEn ?? '—'),
              subtitle: const Text('Creado en (ISO-8601)'),
            ),
          ],
        ),
      ),
    );
  }
}

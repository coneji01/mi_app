// lib/screens/editar_cliente_screen.dart
import 'package:flutter/material.dart';

import '../data/db_service.dart';   // ✅ servicio correcto (singleton)
import '../models/cliente.dart';

class EditarClienteScreen extends StatefulWidget {
  final Cliente cliente;

  const EditarClienteScreen({super.key, required this.cliente});

  @override
  State<EditarClienteScreen> createState() => _EditarClienteScreenState();
}

class _EditarClienteScreenState extends State<EditarClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _telefonoCtrl;

  Sexo? _sexo;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombreCtrl    = TextEditingController(text: c.nombre);
    _apellidoCtrl  = TextEditingController(text: c.apellido);
    _cedulaCtrl    = TextEditingController(text: c.cedula ?? '');
    _direccionCtrl = TextEditingController(text: c.direccion);
    _telefonoCtrl  = TextEditingController(text: c.telefono ?? '');
    _sexo          = c.sexo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _cedulaCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      );

  Future<void> _guardar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final cedulaNorm = DbService.normalizeCedula(_cedulaCtrl.text);

      final updated = Cliente(
        id: widget.cliente.id,
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        cedula: cedulaNorm,
        sexo: _sexo,
        direccion: _direccionCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        creadoEn: widget.cliente.creadoEn,
        fotoPath: widget.cliente.fotoPath,
      );

      // ✅ usar singleton
      await DbService.instance.updateCliente(updated);

      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreCtrl,
              decoration: _dec('Nombre', icon: Icons.person_outline),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apellidoCtrl,
              decoration: _dec('Apellido', icon: Icons.person),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cedulaCtrl,
              decoration: _dec('Cédula', icon: Icons.badge_outlined),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoCtrl,
              decoration: _dec('Teléfono', icon: Icons.call_outlined),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<Sexo>(
              initialValue: _sexo,
              decoration: _dec('Sexo', icon: Icons.wc_outlined),
              items: const [
                DropdownMenuItem(value: Sexo.masculino, child: Text('Masculino')),
                DropdownMenuItem(value: Sexo.femenino, child: Text('Femenino')),
                DropdownMenuItem(value: Sexo.otro, child: Text('Otro')),
              ],
              onChanged: (v) => setState(() => _sexo = v),
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionCtrl,
              decoration: _dec('Dirección', icon: Icons.home_outlined),
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _guardar,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

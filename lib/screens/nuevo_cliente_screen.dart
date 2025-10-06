// lib/screens/nuevo_cliente_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/db_service.dart';          // ✅ Servicio correcto (singleton)
import '../models/cliente.dart';

class NuevoClienteScreen extends StatefulWidget {
  const NuevoClienteScreen({super.key});

  @override
  State<NuevoClienteScreen> createState() => _NuevoClienteScreenState();
}

class _NuevoClienteScreenState extends State<NuevoClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _cedula = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();

  final _picker = ImagePicker();
  String? _fotoPath;

  // Valor por defecto
  Sexo _sexo = Sexo.masculino;

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _cedula.dispose();
    _direccion.dispose();
    _telefono.dispose();
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  // Normaliza cédula a solo dígitos (devuelve null si queda vacía)
  String? _cedulaNormalizada(String? raw) {
    if (raw == null) return null;
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : d;
  }

  Future<void> _pickFoto() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x != null) setState(() => _fotoPath = x.path);
  }

  Future<void> _guardar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final cli = Cliente(
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        direccion: _direccion.text.trim(),
        telefono:
            _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        cedula: _cedulaNormalizada(_cedula.text),
        sexo: _sexo,
        creadoEn: DateTime.now().toIso8601String(),
        fotoPath: _fotoPath,
      );

      // ✅ Usar el singleton
      await DbService.instance.insertCliente(cli);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickFoto,
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage:
                      _fotoPath != null ? FileImage(File(_fotoPath!)) : null,
                  child: _fotoPath == null
                      ? const Icon(Icons.camera_alt, size: 30)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nombre,
              decoration: _dec('Nombre', icon: Icons.person_outline),
              textInputAction: TextInputAction.next,
              validator: _req,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _apellido,
              decoration: _dec('Apellido', icon: Icons.person),
              textInputAction: TextInputAction.next,
              validator: _req,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _cedula,
              decoration: _dec('Cédula', icon: Icons.badge_outlined),
              textInputAction: TextInputAction.next,
              validator: (v) {
                final n = _cedulaNormalizada(v);
                if (n == null) return null; // opcional
                if (n.length != 11) return 'Cédula inválida (11 dígitos)';
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _telefono,
              decoration: _dec('Teléfono', icon: Icons.call_outlined),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<Sexo>(
              initialValue: _sexo,
              decoration: _dec('Sexo', icon: Icons.wc_outlined),
              items: Sexo.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(SexoCodec.legible(s)),
                      ))
                  .toList(),
              onChanged: (s) => setState(() => _sexo = s ?? Sexo.masculino),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _direccion,
              decoration: _dec('Dirección', icon: Icons.home_outlined),
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: 2,
              validator: _req,
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _saving ? null : _guardar,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

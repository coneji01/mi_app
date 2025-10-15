// lib/screens/editar_cliente_screen.dart
import 'package:flutter/material.dart';

import '../data/repository.dart';
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

  // --------- Datos personales ---------
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _telefonoCtrl;
  late Sexo _sexo;

  // --------- Datos laborales ---------
  late final TextEditingController _empresaCtrl;
  late final TextEditingController _ingresosCtrl;
  late final TextEditingController _dependientesCtrl;
  late final TextEditingController _dirTrabajoCtrl;
  late final TextEditingController _puestoCtrl;
  late final TextEditingController _mesesTrabCtrl;
  late EstadoCivil _estadoCivil;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;

    // Personales
    _nombreCtrl    = TextEditingController(text: c.nombre);
    _apellidoCtrl  = TextEditingController(text: c.apellido);
    _cedulaCtrl    = TextEditingController(text: c.cedula ?? '');
    _direccionCtrl = TextEditingController(text: c.direccion);
    _telefonoCtrl  = TextEditingController(text: c.telefono ?? '');
    _sexo          = c.sexo ?? Sexo.otro;

    // Laborales
    _empresaCtrl      = TextEditingController(text: c.empresa ?? '');
    _ingresosCtrl     = TextEditingController(text: c.ingresos?.toString() ?? '');
    _dependientesCtrl = TextEditingController(text: c.dependientes?.toString() ?? '');
    _dirTrabajoCtrl   = TextEditingController(text: c.direccionTrabajo ?? '');
    _puestoCtrl       = TextEditingController(text: c.puestoTrabajo ?? '');
    _mesesTrabCtrl    = TextEditingController(text: c.mesesTrabajando?.toString() ?? '');
    _estadoCivil      = c.estadoCivil ?? EstadoCivil.soltero;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _cedulaCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _empresaCtrl.dispose();
    _ingresosCtrl.dispose();
    _dependientesCtrl.dispose();
    _dirTrabajoCtrl.dispose();
    _puestoCtrl.dispose();
    _mesesTrabCtrl.dispose();
    super.dispose();
  }

  // ----------------- Validaciones -----------------
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  String _normCedula(String v) => v.replaceAll(RegExp(r'\D'), '');

  String? _cedulaOk(String? v) {
    if (v == null || v.trim().isEmpty) return null; // opcional
    final d = _normCedula(v);
    if (d.length != 11) return 'Cédula inválida (11 dígitos)';
    return null;
  }

  String? _optNumEntero(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Número entero inválido';
    return null;
  }

  FormFieldValidator<String> _optNum(double? min) {
    return (String? v) {
      if (v == null || v.trim().isEmpty) return null;
      final n = double.tryParse(v.replaceAll(',', '.').trim());
      if (n == null) return 'Número inválido';
      if (min != null && n < min) return 'Debe ser ≥ ${min.toStringAsFixed(0)}';
      return null;
    };
  }

  InputDecoration _dec(String label, {IconData? icon, String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  // ----------------- Guardar (usa BACKEND) -----------------
  Future<void> _guardar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final updated = Cliente(
        id: widget.cliente.id,
        // Personales
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        cedula: _normCedula(_cedulaCtrl.text),
        sexo: _sexo,
        direccion: _direccionCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        creadoEn: widget.cliente.creadoEn,
        fotoPath: widget.cliente.fotoPath,
        // Laborales
        empresa: _empresaCtrl.text.trim().isEmpty ? null : _empresaCtrl.text.trim(),
        ingresos: _ingresosCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_ingresosCtrl.text.replaceAll(',', '.').trim()),
        estadoCivil: _estadoCivil,
        dependientes: _dependientesCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_dependientesCtrl.text.trim()),
        direccionTrabajo: _dirTrabajoCtrl.text.trim().isEmpty
            ? null
            : _dirTrabajoCtrl.text.trim(),
        puestoTrabajo: _puestoCtrl.text.trim().isEmpty
            ? null
            : _puestoCtrl.text.trim(),
        mesesTrabajando: _mesesTrabCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_mesesTrabCtrl.text.trim()),
      );

      // 👇 GUARDA EN BACKEND (no en SQLite local)
      final saved = await Repository.i.updateCliente(updated);

      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar en backend: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Datos personales'),
            TextFormField(
              controller: _nombreCtrl,
              decoration: _dec('Nombre', icon: Icons.person_outline),
              textInputAction: TextInputAction.next,
              validator: _req,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apellidoCtrl,
              decoration: _dec('Apellido', icon: Icons.person),
              textInputAction: TextInputAction.next,
              validator: _req,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cedulaCtrl,
              decoration: _dec('Cédula', icon: Icons.badge_outlined, hint: '11 dígitos'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: _cedulaOk,
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
              value: _sexo,
              decoration: _dec('Sexo', icon: Icons.wc_outlined),
              items: Sexo.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(SexoCodec.legible(s)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _sexo = v ?? _sexo),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionCtrl,
              decoration: _dec('Dirección', icon: Icons.home_outlined),
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: 2,
              validator: _req,
            ),

            _sectionTitle('Datos laborales'),
            TextFormField(
              controller: _empresaCtrl,
              decoration: _dec('Empresa donde trabaja', icon: Icons.apartment),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EstadoCivil>(
              value: _estadoCivil,
              decoration: _dec('Estado civil', icon: Icons.family_restroom),
              items: EstadoCivil.values
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(EstadoCivilCodec.legible(e)),
                      ))
                  .toList(),
              onChanged: (e) => setState(() => _estadoCivil = e ?? _estadoCivil),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ingresosCtrl,
              decoration: _dec('Ingresos mensuales (RD\$)', icon: Icons.payments),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _optNum(0),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dependientesCtrl,
              decoration: _dec('Dependientes', icon: Icons.group_outlined),
              keyboardType: TextInputType.number,
              validator: _optNumEntero,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dirTrabajoCtrl,
              decoration: _dec('Dirección del trabajo', icon: Icons.location_city),
              textInputAction: TextInputAction.next,
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _puestoCtrl,
              decoration: _dec('Puesto de trabajo', icon: Icons.badge),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mesesTrabCtrl,
              decoration: _dec('Tiempo trabajando (meses)', icon: Icons.timelapse),
              keyboardType: TextInputType.number,
              validator: _optNumEntero,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _guardar,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

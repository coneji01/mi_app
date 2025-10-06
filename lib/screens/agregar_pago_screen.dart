// lib/screens/agregar_pago_screen.dart
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../data/db.dart';

class AgregarPagoScreen extends StatefulWidget {
  final int prestamoId;
  const AgregarPagoScreen({super.key, required this.prestamoId});

  @override
  State<AgregarPagoScreen> createState() => _AgregarPagoScreenState();
}

class _AgregarPagoScreenState extends State<AgregarPagoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  String _tipo = 'capital';
  bool _saving = false;

  static const _tipos = <String>[
    'capital',
    'interes',
    'mora',
    'seguro',
    'otros',
    'gastos',
  ];

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final monto = double.parse(_montoCtrl.text.replaceAll(',', '.'));
      await DbService().agregarPagoRapido(
        prestamoId: widget.prestamoId,
        monto: monto,
        nota: _notaCtrl.text,
        tipo: _tipo,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando pago: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Asegúrate de que AppDrawer tenga constructor const
      // (en app_drawer.dart: `const AppDrawer({super.key, this.current});`)
      drawer: const AppDrawer(current: null),
      appBar: AppBar(title: const Text('Agregar pago')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _montoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final x = double.tryParse(v.replaceAll(',', '.'));
                  if (x == null || x <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ✅ evita el warning: usa initialValue en lugar de value
                initialValue: _tipo,
                items: _tipos
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t[0].toUpperCase() + t.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v ?? 'capital'),
                decoration:
                    const InputDecoration(labelText: 'Tipo de pago'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notaCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nota (opcional)'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/screens/calculadora_screen.dart
import 'package:flutter/material.dart';
import '../models/prestamo_propuesta.dart';

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key, this.returnMode = false});
  final bool returnMode;

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores / estado
  final _montoCtrl = TextEditingController();
  final _tasaCtrl = TextEditingController(); // % por período
  final _cuotasCtrl = TextEditingController();
  String _modalidad = 'Mensual';
  String _tipoAmort = 'Interés Fijo';

  @override
  void dispose() {
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _cuotasCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      );

  void _calcularYDevolver() {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.parse(_montoCtrl.text);
    final tasa = double.parse(_tasaCtrl.text); // % por período
    final cuotas = int.parse(_cuotasCtrl.text);

    // Cuota aprox. interés fijo = capital/cuotas + (monto * tasa%)
    final cuota = (monto / cuotas) + (monto * (tasa / 100.0));

    final propuesta = PrestamoPropuesta(
      monto: monto,
      interes: tasa,                 // si tu clase lo requiere
      cuotas: cuotas,
      modalidad: _modalidad,
      tipoAmortizacion: _tipoAmort,
      tasaPorPeriodo: tasa,          // si tu clase lo requiere
      tipo: _tipoAmort,              // si tu clase lo requiere
      cuota: cuota,                  // opcional si existe en tu modelo
    );

    if (widget.returnMode) {
      Navigator.pop(context, propuesta);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Propuesta calculada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ const para el valor realmente constante
    const double maxCardWidth = 760.0;
    final screenW = MediaQuery.of(context).size.width;
    final cardW = screenW > maxCardWidth ? maxCardWidth : screenW;

    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora')),
      body: Center(
        child: SizedBox(
          width: cardW,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Monto del préstamo', icon: Icons.attach_money),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tasaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Tasa por período (%)', icon: Icons.percent),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cuotasCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Cuotas', icon: Icons.onetwothree),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),

                  // ✅ value -> initialValue (API nueva)
                  DropdownButtonFormField<String>(
                    initialValue: _modalidad,
                    decoration: _dec('Modalidad', icon: Icons.calendar_month),
                    items: const [
                      DropdownMenuItem(value: 'Diario', child: Text('Diario')),
                      DropdownMenuItem(value: 'Interdiario', child: Text('Interdiario')),
                      DropdownMenuItem(value: 'Semanal', child: Text('Semanal')),
                      DropdownMenuItem(value: 'Bisemanal', child: Text('Bisemanal')),
                      DropdownMenuItem(value: 'Quincenal', child: Text('Quincenal')),
                      DropdownMenuItem(value: 'Mensual', child: Text('Mensual')),
                    ],
                    onChanged: (v) => setState(() => _modalidad = v ?? _modalidad),
                  ),
                  const SizedBox(height: 12),

                  // ✅ value -> initialValue (API nueva)
                  DropdownButtonFormField<String>(
                    initialValue: _tipoAmort,
                    decoration: _dec('Tipo de amortización', icon: Icons.rule),
                    items: const [
                      DropdownMenuItem(value: 'Interés Fijo', child: Text('Interés Fijo')),
                      DropdownMenuItem(value: 'Francés', child: Text('Francés')),
                      DropdownMenuItem(value: 'Alemán', child: Text('Alemán')),
                    ],
                    onChanged: (v) => setState(() => _tipoAmort = v ?? _tipoAmort),
                  ),
                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: _calcularYDevolver,
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(widget.returnMode ? 'Usar esta propuesta' : 'Calcular'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

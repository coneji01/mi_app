import 'package:flutter/material.dart';
import '../services/settings.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;

    return FutureBuilder(
      future: s.ensureInitialized(),
      builder: (context, snap) {
        // Mientras carga preferencias, mostramos un loader corto.
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold( // ← sin const
            appBar: AppBar(title: const Text('Configuración')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Configuración')), // ← sin const en AppBar no es obligatorio, pero seguro
          body: AnimatedBuilder(
            animation: s, // escuchamos cambios del Settings (ChangeNotifier)
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Campos visibles en "Nuevo Cliente"',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    context,
                    title: 'Datos personales',
                    children: [
                      _sw('Teléfono', s.showTelefono, s.setShowTelefono),
                      _sw('Cédula', s.showCedula, s.setShowCedula),
                      _sw('Dirección', s.showDireccion, s.setShowDireccion),
                      _sw('Estado civil', s.showEstadoCivil, s.setShowEstadoCivil),
                      _sw('Dependientes', s.showDependientes, s.setShowDependientes),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _card(
                    context,
                    title: 'Actividad económica',
                    children: [
                      _sw('Empresa/Negocio', s.showEmpresa, s.setShowEmpresa),
                      _sw('Ingresos mensuales', s.showIngresos, s.setShowIngresos),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _card(
                    context,
                    title: 'Trabajo',
                    children: [
                      _sw('Dirección del trabajo', s.showDireccionTrabajo, s.setShowDireccionTrabajo),
                      _sw('Puesto de trabajo', s.showPuestoTrabajo, s.setShowPuestoTrabajo),
                      _sw('Meses trabajando', s.showMesesTrabajando, s.setShowMesesTrabajando),
                      _sw('Teléfono del trabajo', s.showTelefonoTrabajo, s.setShowTelefonoTrabajo),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Los cambios se guardan automáticamente.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.tune),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Crea un SwitchListTile estilizado y conecta con el setter async.
  Widget _sw(String label, bool value, Future<void> Function(bool) setter) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: (v) => setter(v),
    );
  }
}

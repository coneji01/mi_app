import 'package:flutter/material.dart';
import '../services/settings.dart';
import '../widgets/app_drawer.dart'; // ✅ Drawer

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;

    return FutureBuilder(
      future: s.ensureInitialized(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Configuración')),
            drawer: const AppDrawer(current: AppSection.configuracion),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Configuración')),
          drawer: const AppDrawer(current: AppSection.configuracion),
          body: AnimatedBuilder(
            animation: s,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Campos visibles en "Nuevo Cliente"',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // ===== Datos personales
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

                  // ===== Actividad económica
                  _card(
                    context,
                    title: 'Actividad económica',
                    children: [
                      _sw('Empresa/Negocio', s.showEmpresa, s.setShowEmpresa),
                      _sw('Ingresos mensuales', s.showIngresos, s.setShowIngresos),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Trabajo
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
                  const Divider(height: 32),

                  // Información del backend fijo (solo lectura)
                  Card(
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_done),
                      title: const Text('Servidor de backend'),
                      subtitle: Text(
                        // Sólo informativo, ya no editable
                        s.backendUrl.isEmpty
                            ? 'URL fija embebida en la app'
                            : s.backendUrl,
                      ),
                      trailing: const Icon(Icons.lock, size: 18),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // === Widgets auxiliares ===
  Widget _card(BuildContext context, {required String title, required List<Widget> children}) {
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

  Widget _sw(String label, bool value, Future<void> Function(bool) setter) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: (v) => setter(v),
    );
  }
}

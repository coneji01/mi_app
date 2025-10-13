// lib/screens/configuracion_screen.dart
import 'package:flutter/material.dart';
import '../services/settings.dart';
import '../data/repository.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    final urlCtrl = TextEditingController(text: s.backendUrl);

    return FutureBuilder(
      future: s.ensureInitialized(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Configuración'),
              leading: _backButton(context),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Sincroniza Repository con lo guardado actualmente
        if (s.backendUrl.isNotEmpty) {
          Repository.i.setBaseUrl(s.backendUrl);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Configuración'),
            leading: _backButton(context),
          ),
          body: AnimatedBuilder(
            animation: s,
            builder: (context, _) {
              urlCtrl.text = s.backendUrl; // mantener actualizado el campo

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
                  const Divider(height: 32),
                  const Text(
                    'Conexión con el servidor (Backend)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: urlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'URL del backend',
                              hintText: 'Ej: http://190.93.188.250:8081',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                            ),
                            keyboardType: TextInputType.url,
                            onChanged: (v) {
                              // No guardamos aún; guardamos cuando pase el ping.
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final raw = urlCtrl.text.trim();
                                    if (raw.isEmpty) {
                                      _snack(context, 'Coloca la URL del backend');
                                      return;
                                    }
                                    // Ajuste para no dejar barra final
                                    final url = raw.replaceAll(RegExp(r'/+$'), '');
                                    Repository.i.setBaseUrl(url);
                                    try {
                                      final ok = await Repository.i.probarConexion();
                                      if (ok) {
                                        await s.setBackendUrl(url); // guardamos SOLO si responde
                                        _snack(context, '✔ Conectado al backend y guardado', ok: true);
                                      } else {
                                        _snack(context, '✖ El servidor no respondió (200..299 esperado)');
                                      }
                                    } catch (e) {
                                      _snack(context, '✖ Error de conexión: $e');
                                    }
                                  },
                                  icon: const Icon(Icons.wifi_tethering),
                                  label: const Text('Probar conexión'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Los cambios se guardan automáticamente (la URL se guarda al pasar la prueba).',
                    style: TextStyle(color: Colors.grey),
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

  Widget _backButton(BuildContext context) {
    // Si puede volver, muestra back; si no, muestra un botón Home que te lleve a '/'
    if (Navigator.canPop(context)) {
      return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop());
    }
    return IconButton(
      icon: const Icon(Icons.home),
      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
      tooltip: 'Ir al inicio',
    );
  }

  void _snack(BuildContext context, String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// lib/screens/nuevo_cliente_screen.dart
import 'package:flutter/material.dart';
import '../services/settings.dart';
import '../data/repository.dart';
import 'configuracion_screen.dart';

class NuevoClienteScreen extends StatefulWidget {
  const NuevoClienteScreen({super.key});

  @override
  State<NuevoClienteScreen> createState() => _NuevoClienteScreenState();
}

class _NuevoClienteScreenState extends State<NuevoClienteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();

  final _telefonoCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  final _empresaCtrl = TextEditingController();
  final _ingresosCtrl = TextEditingController();

  final _estadoCivilCtrl = TextEditingController();
  final _dependientesCtrl = TextEditingController();

  final _direccionTrabajoCtrl = TextEditingController();
  final _puestoTrabajoCtrl = TextEditingController();
  final _mesesTrabajandoCtrl = TextEditingController();
  final _telefonoTrabajoCtrl = TextEditingController(); // (solo UI)

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    _cedulaCtrl.dispose();
    _direccionCtrl.dispose();
    _empresaCtrl.dispose();
    _ingresosCtrl.dispose();
    _estadoCivilCtrl.dispose();
    _dependientesCtrl.dispose();
    _direccionTrabajoCtrl.dispose();
    _puestoTrabajoCtrl.dispose();
    _mesesTrabajandoCtrl.dispose();
    _telefonoTrabajoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;

    return FutureBuilder(
      future: s.ensureInitialized(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nuevo Cliente')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Nuevo Cliente')),
          body: AnimatedBuilder(
            animation: s,
            builder: (context, _) {
              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ===== Datos básicos =====
                    TextFormField(
                      controller: _nombresCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombres',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _apellidosCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),

                    const SizedBox(height: 16),
                    if (s.showTelefono)
                      TextFormField(
                        controller: _telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    if (s.showCedula) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cedulaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cédula',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                    ],
                    if (s.showDireccion) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _direccionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ===== Actividad económica =====
                    if (s.showEmpresa)
                      TextFormField(
                        controller: _empresaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Empresa / Negocio',
                          prefixIcon: Icon(Icons.store_outlined),
                        ),
                      ),
                    if (s.showIngresos) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ingresosCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ingresos mensuales (RD\$)',
                          prefixIcon: Icon(Icons.attach_money_outlined),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ===== Datos familiares =====
                    if (s.showEstadoCivil)
                      TextFormField(
                        controller: _estadoCivilCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Estado civil',
                          prefixIcon: Icon(Icons.favorite_outline),
                        ),
                      ),
                    if (s.showDependientes) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dependientesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dependientes',
                          prefixIcon: Icon(Icons.family_restroom_outlined),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ===== Trabajo =====
                    if (s.showDireccionTrabajo)
                      TextFormField(
                        controller: _direccionTrabajoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dirección del trabajo',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                      ),
                    if (s.showPuestoTrabajo) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _puestoTrabajoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Puesto de trabajo',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                      ),
                    ],
                    if (s.showMesesTrabajando) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mesesTrabajandoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Meses trabajando',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                      ),
                    ],
                    if (s.showTelefonoTrabajo) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _telefonoTrabajoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono del trabajo',
                          prefixIcon: Icon(Icons.call_outlined),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                      onPressed: _guardar,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Asegúrate de que haya URL de backend configurada
    if (!Repository.i.isReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura primero la URL del servidor')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
      );
      return;
    }

    // ====== Guardar en BACKEND (único modo) ======
    try {
      final body = <String, dynamic>{
        'nombre': _nombresCtrl.text.trim(),
        'apellido': _apellidosCtrl.text.trim().isEmpty ? null : _apellidosCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        'cedula': _cedulaCtrl.text.trim().isEmpty ? null : _cedulaCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'empresa': _empresaCtrl.text.trim().isEmpty ? null : _empresaCtrl.text.trim(),
        'ingresos': _ingresosCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_ingresosCtrl.text.trim()),
        'estado_civil': _estadoCivilCtrl.text.trim().isEmpty ? null : _estadoCivilCtrl.text.trim(),
        'dependientes': _dependientesCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_dependientesCtrl.text.trim()),
        'direccion_trabajo': _direccionTrabajoCtrl.text.trim().isEmpty
            ? null
            : _direccionTrabajoCtrl.text.trim(),
        'puesto_trabajo': _puestoTrabajoCtrl.text.trim().isEmpty
            ? null
            : _puestoTrabajoCtrl.text.trim(),
        'meses_trabajando': _mesesTrabajandoCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_mesesTrabajandoCtrl.text.trim()),
        // 'telefono_trabajo' no existe en la API; no lo enviamos
      };

      await Repository.i.crearCliente(body); // <-- usa el endpoint /clientes

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente guardado en servidor ✅')),
      );
      Navigator.pop(context, true); // avisa a la lista para recargar
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar (backend): $e')),
      );
    }
  }
}

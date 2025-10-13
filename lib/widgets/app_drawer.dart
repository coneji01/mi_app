// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';

// --- Importaciones de Pantallas ---
import '../screens/inicio_screen.dart';
import '../screens/solicitudes_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/prestamos_screen.dart';
import '../screens/pagos_screen.dart';
import '../screens/calculadora_screen.dart';
import '../screens/configuracion_screen.dart' as cfg;
// ⬇️ Fallback si no usas rutas nombradas:
import '../screens/login_screen.dart';

enum AppSection {
  inicio,
  solicitudes,
  clientes,
  prestamos,
  pagos,
  calculadora,
  configuracion,
}

class AppDrawer extends StatelessWidget {
  final AppSection? current;
  final Function(int)? onNavigateToHomeShellIndex;

  const AppDrawer({
    super.key,
    this.current,
    this.onNavigateToHomeShellIndex,
  });

  void _navToSecondary(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _goInicio(BuildContext context) {
    Navigator.pop(context);

    if (onNavigateToHomeShellIndex != null) {
      Future.microtask(() => onNavigateToHomeShellIndex!(0));
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const InicioScreen()),
      (route) => false,
    );
  }

  void _logout(BuildContext context) {
    // Cierra el drawer primero
    Navigator.pop(context);

    // (Opcional) aquí puedes limpiar tokens en SharedPreferences si usas auth.
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove('token');

    // Preferimos la ruta nombrada /login; si no existe, usamos fallback.
    try {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } catch (_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    TextStyle _itemStyle(bool selected) => TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primary : null,
        );

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            // Header
            Container(
              height: 120,
              color: Theme.of(context).primaryColor,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16, top: 24),
              child: const Text(
                'Joel Wifi Dominicana',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

            // --- Navegación ---
            ListTile(
              leading: Icon(Icons.home_outlined,
                  color: current == AppSection.inicio ? primary : null),
              title: Text('Inicio', style: _itemStyle(current == AppSection.inicio)),
              selected: current == AppSection.inicio,
              onTap: () => _goInicio(context),
            ),

            const Divider(),

            ListTile(
              leading: Icon(Icons.assignment_outlined,
                  color: current == AppSection.solicitudes ? primary : null),
              title: Text('Solicitudes', style: _itemStyle(current == AppSection.solicitudes)),
              selected: current == AppSection.solicitudes,
              onTap: () => _navToSecondary(context, const SolicitudesScreen()),
            ),

            ListTile(
              leading: Icon(Icons.group_outlined,
                  color: current == AppSection.clientes ? primary : null),
              title: Text('Clientes', style: _itemStyle(current == AppSection.clientes)),
              selected: current == AppSection.clientes,
              onTap: () => _navToSecondary(context, const ClientesScreen()),
            ),

            ListTile(
              leading: Icon(Icons.request_page_outlined,
                  color: current == AppSection.prestamos ? primary : null),
              title: Text('Préstamos', style: _itemStyle(current == AppSection.prestamos)),
              selected: current == AppSection.prestamos,
              onTap: () => _navToSecondary(context, const PrestamosScreen()),
            ),

            ListTile(
              leading: Icon(Icons.payments_outlined,
                  color: current == AppSection.pagos ? primary : null),
              title: Text('Pagos', style: _itemStyle(current == AppSection.pagos)),
              selected: current == AppSection.pagos,
              onTap: () => _navToSecondary(context, const PagosScreen()),
            ),

            ListTile(
              leading: Icon(Icons.calculate_outlined,
                  color: current == AppSection.calculadora ? primary : null),
              title: Text('Calculadora', style: _itemStyle(current == AppSection.calculadora)),
              selected: current == AppSection.calculadora,
              onTap: () => _navToSecondary(context, const CalculadoraScreen()),
            ),

            // ===== Configuración =====
            ListTile(
              leading: Icon(Icons.settings_outlined,
                  color: current == AppSection.configuracion ? primary : null),
              title: Text('Configuración', style: _itemStyle(current == AppSection.configuracion)),
              selected: current == AppSection.configuracion,
              onTap: () => _navToSecondary(context, const cfg.ConfiguracionScreen()),
            ),

            const Divider(),

            // ===== Cerrar sesión =====
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}

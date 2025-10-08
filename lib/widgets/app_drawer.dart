// Archivo: lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';

// --- Importaciones de Pantallas ---
import '../screens/inicio_screen.dart';           // ⬅️ Import explícito a Inicio
import '../screens/solicitudes_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/prestamos_screen.dart';
import '../screens/pagos_screen.dart';
import '../screens/calculadora_screen.dart';

enum AppSection { inicio, solicitudes, clientes, prestamos, pagos, calculadora }

class AppDrawer extends StatelessWidget {
  /// Sección actual (para resaltar el item)
  final AppSection? current;

  /// Callback opcional para HomeShell con tabs (0 = Inicio).
  final Function(int)? onNavigateToHomeShellIndex;

  const AppDrawer({
    super.key,
    this.current,
    this.onNavigateToHomeShellIndex,
  });

  // Navegación a pantallas “secundarias” (push normal)
  void _navToSecondary(BuildContext context, Widget screen) {
    Navigator.pop(context); // cierra el drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // Ir a Inicio:
  // 1) Si hay HomeShell con tabs, usa el callback
  // 2) Si no, navega explícitamente a InicioScreen limpiando el stack
  void _goInicio(BuildContext context) {
    Navigator.pop(context); // cierra el drawer primero

    if (onNavigateToHomeShellIndex != null) {
      Future.microtask(() => onNavigateToHomeShellIndex!(0));
      return;
    }

    // Fallback directo a InicioScreen (NO usa rutas nombradas para evitar caer en '/login')
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const InicioScreen()),
      (route) => false,
    );
  }

  void _logout(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
              title: Text(
                'Inicio',
                style: TextStyle(
                  fontWeight:
                      current == AppSection.inicio ? FontWeight.w700 : FontWeight.w500,
                  color: current == AppSection.inicio ? primary : null,
                ),
              ),
              selected: current == AppSection.inicio,
              onTap: () => _goInicio(context),
            ),

            const Divider(),

            ListTile(
              leading: Icon(Icons.assignment_outlined,
                  color: current == AppSection.solicitudes ? primary : null),
              title: Text(
                'Solicitudes',
                style: TextStyle(
                  fontWeight: current == AppSection.solicitudes
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: current == AppSection.solicitudes ? primary : null,
                ),
              ),
              selected: current == AppSection.solicitudes,
              onTap: () => _navToSecondary(context, const SolicitudesScreen()),
            ),

            ListTile(
              leading: Icon(Icons.group_outlined,
                  color: current == AppSection.clientes ? primary : null),
              title: Text(
                'Clientes',
                style: TextStyle(
                  fontWeight:
                      current == AppSection.clientes ? FontWeight.w700 : FontWeight.w500,
                  color: current == AppSection.clientes ? primary : null,
                ),
              ),
              selected: current == AppSection.clientes,
              onTap: () => _navToSecondary(context, const ClientesScreen()),
            ),

            ListTile(
              leading: Icon(Icons.request_page_outlined,
                  color: current == AppSection.prestamos ? primary : null),
              title: Text(
                'Préstamos',
                style: TextStyle(
                  fontWeight: current == AppSection.prestamos
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: current == AppSection.prestamos ? primary : null,
                ),
              ),
              selected: current == AppSection.prestamos,
              onTap: () => _navToSecondary(context, const PrestamosScreen()),
            ),

            ListTile(
              leading: Icon(Icons.payments_outlined,
                  color: current == AppSection.pagos ? primary : null),
              title: Text(
                'Pagos',
                style: TextStyle(
                  fontWeight:
                      current == AppSection.pagos ? FontWeight.w700 : FontWeight.w500,
                  color: current == AppSection.pagos ? primary : null,
                ),
              ),
              selected: current == AppSection.pagos,
              onTap: () => _navToSecondary(context, const PagosScreen()),
            ),

            ListTile(
              leading: Icon(Icons.calculate_outlined,
                  color: current == AppSection.calculadora ? primary : null),
              title: Text(
                'Calculadora',
                style: TextStyle(
                  fontWeight: current == AppSection.calculadora
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: current == AppSection.calculadora ? primary : null,
                ),
              ),
              selected: current == AppSection.calculadora,
              onTap: () => _navToSecondary(context, const CalculadoraScreen()),
            ),

            const Divider(),

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

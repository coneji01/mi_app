// Archivo: lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';

// ----------------------------------------------------
// --- Importaciones de Pantallas (Asegúrate de las rutas) ---
// ----------------------------------------------------
import '../screens/solicitudes_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/prestamos_screen.dart';
import '../screens/pagos_screen.dart';
import 'package:mi_app/screens/calculadora_screen.dart';

//import '../screens/calculadora_screen.dart';
//import '../screens/inicio_screen.dart'; 
//import '../screens/login_screen.dart'; 


enum AppSection { inicio, solicitudes, clientes, prestamos, pagos, calculadora }

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

  void _logout(BuildContext context) {
    Navigator.pop(context);
    // Usamos pushNamedAndRemoveUntil asumiendo que tu ruta de login es '/login'
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false); 
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            // Encabezado
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
                )
              ),
            ),
            
            // --- ENLACES DE NAVEGACIÓN ---
            
            // 1. INICIO (Estadísticas)
            ListTile(
              leading: const Icon(Icons.home), 
              title: const Text('Inicio'), 
              selected: current == AppSection.inicio, 
              onTap: () {
                Navigator.pop(context);
                onNavigateToHomeShellIndex?.call(0);
              }
            ),

            const Divider(), 
            
            // 2. SOLICITUDES
            ListTile(
              leading: const Icon(Icons.assignment_outlined), 
              title: const Text('Solicitudes'), 
              selected: current == AppSection.solicitudes, 
              onTap: () => _navToSecondary(context, const SolicitudesScreen()),
            ),
            
            // 3. CLIENTES
            ListTile(
              leading: const Icon(Icons.group_outlined), 
              title: const Text('Clientes'), 
              selected: current == AppSection.clientes, 
              onTap: () => _navToSecondary(context, const ClientesScreen()),
            ),
            
            // 4. PRÉSTAMOS
            ListTile(
              leading: const Icon(Icons.request_page_outlined), 
              title: const Text('Préstamos'), 
              selected: current == AppSection.prestamos, 
              onTap: () => _navToSecondary(context, const PrestamosScreen()),
            ),
            
            // 5. PAGOS (CxC)
            ListTile(
              leading: const Icon(Icons.payments_outlined), 
              title: const Text('Pagos'), 
              selected: current == AppSection.pagos, 
              onTap: () => _navToSecondary(context, const PagosScreen()),
            ),
            
            // 6. CALCULADORA
            ListTile(
              leading: const Icon(Icons.calculate_outlined), 
              title: const Text('Calculadora'), 
              selected: current == AppSection.calculadora, 
              onTap: () => _navToSecondary(context, const CalculadoraScreen()),
            ),
            
            const Divider(),
            
            // CERRAR SESIÓN
            ListTile(
              leading: const Icon(Icons.logout), 
              title: const Text('Cerrar sesión'), 
              onTap: () => _logout(context)
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

/// Pantalla de inicio limpia + Drawer visible.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Muestra tu Drawer en esta pantalla
      drawer: const AppDrawer(current: AppSection.inicio),

      appBar: AppBar(
        title: const Text('Inicio'),
        centerTitle: false,
      ),
      body: const Center(
        child: Text(
          'Pantalla vacía (inicio). Aquí armamos tu nuevo dashboard.',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

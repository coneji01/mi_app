// lib/main.dart
import 'package:flutter/material.dart';
import 'data/db.dart'; // importa AppDatabase

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prepara la base de datos en cualquier plataforma
  await AppDatabase.instance.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi App',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      // Mantén aquí tus rutas/initialRoute/home actuales
      home: const Placeholder(), // <-- reemplaza con tu pantalla inicial real
    );
  }
}

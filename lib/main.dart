// lib/main.dart
import 'package:flutter/material.dart';
import 'data/repository.dart';
import 'services/settings.dart';
import 'screens/login_screen.dart';
import 'screens/configuracion_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Evita que crashee en silencio
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  await Settings.instance.ensureInitialized();
  await Repository.i.init(); // lee URL de Settings.instance.backendUrl

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final ready = Repository.i.isReady;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi App',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      // Si no hay URL válida aún, envío a Configuración para que pruebe/guarde la URL
      home: ready ? const LoginScreen() : const ConfiguracionScreen(),
    );
  }
}

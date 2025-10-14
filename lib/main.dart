import 'package:flutter/material.dart';
import 'data/repository.dart';
import 'services/settings.dart';
import 'screens/login_screen.dart';

/// RouteObserver global para detectar cuando una ruta vuelve a ser visible.
/// Importa `routeObserver` desde otras pantallas con:
///   import '../../main.dart' show routeObserver;
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa settings y el repositorio (lee URL/token si existen).
  await Settings.instance.ensureInitialized();
  await Repository.i.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi App',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),

      // ✅ Siempre empezamos en Login; desde ahí puedes ir a Configuración.
      home: const LoginScreen(),

      // ✅ Registramos el observer para poder hacer refresh automático al volver.
      navigatorObservers: [routeObserver],
    );
  }
}

// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'inicio_screen.dart';
import '../data/repository.dart';
import 'configuracion_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String m, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: ok ? Colors.green : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      );

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Verifica que el repo tenga una URL base configurada
    if (!Repository.i.isReady) {
      _snack('Configura primero la URL del servidor');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = _userCtrl.text.trim();
      final pass = _passCtrl.text;

      // Llama al backend y usa la respuesta
      final res = await Repository.i.login(
        usernameOrEmail: user,
        password: pass,
      );

      // Extrae un posible token (ajusta las keys si tu API usa otras)
      final token = (res['access_token'] ?? res['token']) as String?;
      if (token != null && token.isNotEmpty) {
        Repository.i.setAuthToken(token); // guardamos para siguientes requests
      }

      _snack('Autenticado', ok: true);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const InicioScreen()),
      );
    } catch (e) {
      _snack('Error de inicio de sesión: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final onCard = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Card(
                  elevation: 10,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.06),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  (isDark ? Colors.white : Colors.black87)
                                      .withValues(alpha: 0.08),
                              child: Icon(Icons.wifi, color: onCard),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Joel Wifi Dominicana',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: onCard,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _userCtrl,
                            decoration:
                                _dec('Usuario', icon: Icons.person_outline),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passCtrl,
                            decoration:
                                _dec('Contraseña', icon: Icons.lock_outline),
                            obscureText: true,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                            onFieldSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _loading ? null : _login,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('Ingresar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// lib/screens/login_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/repository.dart';
import 'inicio_screen.dart'; // ✅ Navega directo al Inicio

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  late final AnimationController _anim; // para fondos y brillo

  @override
  void initState() {
    super.initState();
    Repository.i.init(); // Inicializa tu repo de login

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Repository.i.login(
        usernameOrEmail: _userCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      // ✅ Ahora va directo al InicioScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InicioScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ───────────────── Fondo animado ─────────────────
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final t = _anim.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.9 + 0.8 * t, -1.0),
                    end: Alignment(1.0, 1.0 - 0.8 * t),
                    colors: const [
                      Color(0xFF0A0F1C),
                      Color(0xFF0B1329),
                      Color(0xFF0F1738),
                    ],
                  ),
                ),
              );
            },
          ),
          const _Blob(top: -120, left: -60, color: Color(0xFF6B8CFF)),
          const _Blob(bottom: -140, right: -80, color: Color(0xFF7B3FFF)),

          // ───────────────── Tarjeta principal ─────────────────
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B8CFF).withOpacity(0.18),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                        child: Form(
                          key: _form,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LogoBadge(animation: _anim),
                              const SizedBox(height: 10),
                              Text(
                                'Bienvenido',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _FrostInput(
                                controller: _userCtrl,
                                hint: 'Usuario',
                                icon: Icons.person_outline,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Requerido'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              _PasswordField(controller: _passCtrl),
                              const SizedBox(height: 10),

                              if (_error != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                ),

                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: _GlowButton(
                                  animation: _anim,
                                  enabled: !_loading,
                                  onPressed: _loading ? null : _doLogin,
                                  label: _loading ? 'Ingresando…' : 'Ingresar',
                                  icon: Icons.login_rounded,
                                ),
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
        ],
      ),
    );
  }
}

// ───────────────────────── Widgets de estilo ─────────────────────────

class _FrostInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;

  const _FrostInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF6B8CFF), width: 1.6),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordField({required this.controller});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Contraseña',
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF7B3FFF), width: 1.6),
        ),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.white70,
          ),
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
    );
  }
}

class _GlowButton extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback? onPressed;
  final bool enabled;
  final String label;
  final IconData icon;

  const _GlowButton({
    required this.animation,
    required this.onPressed,
    required this.enabled,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final blur = 14.0 + 10.0 * (t);
        final spread = 1.0 + 1.0 * (t);

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF6B8CFF).withOpacity(0.55),
                      blurRadius: blur,
                      spreadRadius: spread,
                    ),
                    BoxShadow(
                      color: const Color(0xFF7B3FFF).withOpacity(0.35),
                      blurRadius: blur * .7,
                      spreadRadius: spread * .6,
                    ),
                  ]
                : [],
          ),
          child: _ShimmerSurface(
            animation: animation,
            borderRadius: 14,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerSurface extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final double borderRadius;

  const _ShimmerSurface({
    required this.child,
    required this.animation,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        return Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: const Alignment(1, 0),
              colors: const [
                Color(0xFF4C64FF),
                Color(0xFF6B8CFF),
                Color(0xFF7B3FFF),
              ],
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class _LogoBadge extends StatelessWidget {
  final Animation<double> animation;
  const _LogoBadge({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF6B8CFF).withOpacity(.25 + .15 * t),
                const Color(0xFF7B3FFF).withOpacity(.12 + .12 * (1 - t)),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B8CFF).withOpacity(.35 + .25 * t),
                blurRadius: 20 + 10 * t,
                spreadRadius: 1 + t,
              ),
            ],
          ),
          child: const Icon(Icons.lock_outline, color: Colors.white, size: 30),
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final double? top, left, right, bottom;
  final Color color;
  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(.35), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

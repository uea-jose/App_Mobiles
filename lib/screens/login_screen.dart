import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  Future<void> _doLogin() async {
    setState(() => _loading = true);
    try {
      await AuthService.login(
        email: _email.text.trim(),
        password: _pass.text,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeTabs()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar minimal (o puedes quitarla si quieres full screen)
      appBar: AppBar(
        title: const Text('Login'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _LoginCard(
                    emailController: _email,
                    passController: _pass,
                    loading: _loading,
                    onLogin: _doLogin,
                    onGoRegister: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      );
                    },
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

/// Fondo moderno azulado con degradado y “blur feel” (sin paquetes).
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6F8FF),
            Color(0xFFEAF1FF),
            Color(0xFFF8FAFF),
          ],
        ),
      ),
      child: Stack(
        children: const [
          // “blobs” suaves para dar profundidad
          _Blob(
              alignment: Alignment(-1.2, -1.0),
              size: 260,
              color: Color(0x332563EB)),
          _Blob(
              alignment: Alignment(1.2, -0.8),
              size: 220,
              color: Color(0x222563EB)),
          _Blob(
              alignment: Alignment(0.9, 1.2),
              size: 280,
              color: Color(0x1A2563EB)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _Blob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      ),
    );
  }
}

/// Card “bootstrap-like” con sombra suave.
class _LoginCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passController;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onGoRegister;

  const _LoginCard({
    required this.emailController,
    required this.passController,
    required this.loading,
    required this.onLogin,
    required this.onGoRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          const Text(
            "Bienvenido",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            "Inicia sesión para continuar",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black.withOpacity(0.55)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          GlowLiftButton(
            text: loading ? "Cargando..." : "Entrar",
            loading: loading,
            onPressed: loading ? null : onLogin,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onGoRegister,
            child: const Text('¿No tienes cuenta? Regístrate'),
          ),
        ],
      ),
    );
  }
}

/// Botón con “salto” + brillo al presionar (y hover si hay mouse).
class GlowLiftButton extends StatefulWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const GlowLiftButton({
    super.key,
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<GlowLiftButton> createState() => _GlowLiftButtonState();
}

class _GlowLiftButtonState extends State<GlowLiftButton> {
  bool _hover = false; // para web/desktop
  bool _down = false; // para press en móvil

  void _setHover(bool v) => setState(() => _hover = v);
  void _setDown(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    // Estado visual
    final lift = (!enabled)
        ? 0.0
        : _down
            ? -1.0
            : (_hover ? -3.0 : 0.0);

    final shadowStrength = (!enabled)
        ? 0.06
        : _down
            ? 0.10
            : (_hover ? 0.14 : 0.10);

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, lift, 0),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF2563EB), // azul principal
                Color(0xFF1D4ED8), // azul más profundo
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(37, 99, 235, shadowStrength),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onPressed,
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
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

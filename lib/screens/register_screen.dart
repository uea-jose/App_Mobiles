import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController(); // ✅ confirmar contraseña

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _pass2Focus = FocusNode();

  String _role = 'PLAYER';
  bool _loading = false;

  // ✅ VALIDADORES (sin carpeta extra, estilo simple)
  String? _required(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  String? _emailValidator(String? v) {
    final base = _required(v, 'Email');
    if (base != null) return base;

    final value = v!.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Email inválido (ej: usuario@dominio.com)';
    return null;
  }

  String? _passwordValidator(String? v) {
    final base = _required(v, 'Contraseña');
    if (base != null) return base;

    final value = v!;
    if (value.length < 8) return 'Debe tener al menos 8 caracteres';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasNumber) return 'Debe contener letras y números';
    return null;
  }

  String? _confirmPasswordValidator(String? v) {
    final base = _required(v, 'Confirmación');
    if (base != null) return base;

    if (v != _pass.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _doRegister() async {
    // ✅ valida antes de registrar
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await AuthService.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _pass.text,
        role: _role,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso. Ahora inicia sesión.')),
      );
      Navigator.pop(context);
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
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _pass2Focus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => _required(v, 'Nombre'),
                onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _emailValidator,
                onFieldSubmitted: (_) => _passFocus.requestFocus(),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _pass,
                focusNode: _passFocus,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: _passwordValidator,
                onChanged: (_) {
                  // ✅ si ya escribió confirmación, revalida
                  if (_pass2.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
                onFieldSubmitted: (_) => _pass2Focus.requestFocus(),
              ),
              const SizedBox(height: 12),

              // ✅ CONFIRMAR CONTRASEÑA
              TextFormField(
                controller: _pass2,
                focusNode: _pass2Focus,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: _confirmPasswordValidator,
                onFieldSubmitted: (_) => _doRegister(),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Text('Rol:  ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _role,
                    items: const [
                      DropdownMenuItem(value: 'PLAYER', child: Text('Jugador')),
                      DropdownMenuItem(value: 'OWNER', child: Text('Dueño')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'PLAYER'),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _doRegister,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Crear cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

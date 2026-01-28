import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService.getUser();
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return 'Administrador';
      case 'OWNER':
        return 'Dueño';
      default:
        return 'Jugador';
    }
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return const Color(0xFF2563EB);
      case 'OWNER':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF334155);
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return Icons.admin_panel_settings_outlined;
      case 'OWNER':
        return Icons.storefront_outlined;
      default:
        return Icons.sports_esports_outlined;
    }
  }

  String _initials(String nameOrEmail) {
    final cleaned = nameOrEmail.trim();
    if (cleaned.isEmpty) return '?';
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return cleaned[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil'), elevation: 0),
      body: Stack(
        children: [
          const _ProfileBackground(),
          SafeArea(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final user = snap.data ?? {};
                final name = (user['name'] ?? 'Usuario').toString();
                final email = (user['email'] ?? '-').toString();
                final role = (user['role'] ?? 'PLAYER').toString();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _HeaderCard(
                        name: name,
                        email: email,
                        roleLabel: _roleLabel(role),
                        roleColor: _roleColor(role),
                        roleIcon: _roleIcon(role),
                        initials: _initials(name.isNotEmpty ? name : email),
                      ),
                      const SizedBox(height: 14),
                      SoftCard(
                        title: 'Información de la Cuenta',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(label: 'Nombre', value: name),
                            const SizedBox(height: 10),
                            _InfoRow(label: 'Email', value: email),
                            const SizedBox(height: 10),
                            _InfoRow(label: 'Rol', value: _roleLabel(role)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      DangerLiftButton(
                        text: 'Cerrar sesión',
                        onPressed: () async {
                          await AuthService.logout();
                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo azulado suave con blobs
class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

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
          _Blob(
              alignment: Alignment(-1.1, -1.0),
              size: 260,
              color: Color(0x332563EB)),
          _Blob(
              alignment: Alignment(1.2, -0.7),
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

  const _Blob(
      {required this.alignment, required this.size, required this.color});

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

/// Header con avatar + badge de rol
class _HeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final Color roleColor;
  final IconData roleIcon;
  final String initials;

  const _HeaderCard({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.roleColor,
    required this.roleIcon,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(color: Colors.black.withOpacity(0.55)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _RoleBadge(
                  label: roleLabel,
                  color: roleColor,
                  icon: roleIcon,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _RoleBadge(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

/// Card reutilizable
class SoftCard extends StatelessWidget {
  final String title;
  final Widget child;

  const SoftCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Botón rojo con animación (logout)
class DangerLiftButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const DangerLiftButton(
      {super.key, required this.text, required this.onPressed});

  @override
  State<DangerLiftButton> createState() => _DangerLiftButtonState();
}

class _DangerLiftButtonState extends State<DangerLiftButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final lift = _down ? -1.0 : (_hover ? -3.0 : 0.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
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
              colors: [Color(0xFFE0555F), Color(0xFFD63C47)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33E0555F),
                blurRadius: 18,
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
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        return const Color(0xFF2563EB); // azul
      case 'OWNER':
        return const Color(0xFF0EA5E9); // celeste
      default:
        return const Color(0xFF334155); // gris azulado
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AuthService.currentUser(),
      builder: (context, snap) {
        // ⏳ Cargando
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Stack(
              children: [
                _DashboardBackground(),
                SafeArea(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        }

        // ❌ Error
        if (snap.hasError) {
          return Scaffold(
            body: Stack(
              children: [
                const _DashboardBackground(),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Error cargando usuario.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final user = snap.data ?? {};
        final name = (user['name'] ?? 'Usuario').toString();
        final email = (user['email'] ?? '-').toString();
        final role = (user['role'] ?? 'PLAYER').toString();

        final roleLabel = _roleLabel(role);
        final roleColor = _roleColor(role);

        return Scaffold(
          // AppBar “limpia”
          appBar: AppBar(
            title: const Text('Inicio'),
            elevation: 0,
          ),
          body: Stack(
            children: [
              const _DashboardBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _HeaderCard(
                        name: name,
                        email: email,
                        roleLabel: roleLabel,
                        roleColor: roleColor,
                        roleIcon: _roleIcon(role),
                      ),
                      const SizedBox(height: 14),

                      // Card: Información
                      SoftCard(
                        title: 'Información Personal',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(label: 'Nombre', value: name),
                            const SizedBox(height: 10),
                            _InfoRow(label: 'Email', value: email),
                            const SizedBox(height: 10),
                            _InfoRow(label: 'Rol', value: roleLabel),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Card: Acciones rápidas (solo UI; tú luego decides qué hace)
                      SoftCard(
                        title: 'Acciones rápidas',
                        child: Column(
                          children: [
                            _ActionTile(
                              icon: Icons.person_outline,
                              title: 'Ver mi perfil',
                              subtitle: 'Revisa tu información y tu rol',
                              onTap: () {
                                // UI: opcional
                                // si quieres navegar al tab Perfil, lo dejamos para después
                              },
                            ),
                            const SizedBox(height: 10),
                            _ActionTile(
                              icon: _roleIcon(role),
                              title: 'Mi rol: $roleLabel',
                              subtitle: 'La app adapta pantallas según tu rol',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fondo azulado suave con blobs (similar a login/register)
class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

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

/// Header “bootstrap-like”: avatar + nombre + badge rol
class _HeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final Color roleColor;
  final IconData roleIcon;

  const _HeaderCard({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.roleColor,
    required this.roleIcon,
  });

  String _initials(String s) {
    final parts =
        s.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    final a = parts.first[0].toUpperCase();
    final b = parts.length > 1 ? parts[1][0].toUpperCase() : '';
    return (a + b).trim();
  }

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
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F2563EB),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              _initials(name),
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
                  "Hola, $name",
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

/// Card reutilizable tipo “bootstrap”
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

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final lift = _down ? -1.0 : (_hover ? -2.0 : 0.0);

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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x14000000),
                blurRadius: _hover ? 16 : 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x1A2563EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                          color: Colors.black.withOpacity(0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
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
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

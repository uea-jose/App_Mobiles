import 'package:flutter/material.dart';

import 'package:flutter_application_3/ui/app_theme.dart';
import 'package:flutter_application_3/ui/app_widgets.dart';
import 'package:flutter_application_3/services/auth_service.dart';

import 'package:flutter_application_3/screens/inventory_screen.dart';
import 'package:flutter_application_3/screens/products_screen.dart';
import 'package:flutter_application_3/screens/profile_screen.dart';
import 'package:flutter_application_3/screens/users_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = AuthService();

  Map<String, dynamic>? me;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final data = await _auth.me();
      if (!mounted) return;
      setState(() {
        me = data;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final username = (me?['username'] ?? 'Usuario').toString();
    final role = (me?['role'] ?? 'USER').toString().toUpperCase();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadMe,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopGlassHeader(
                    title: 'Essenza Store',
                    username: username,
                    role: role,
                    loading: me == null && error == null,
                    onLogout: _logout,
                  ),
                  const SizedBox(height: 16),
                  if (error != null) ...[
                    _ErrorBanner(text: error!),
                    const SizedBox(height: 16),
                  ],
                  const _SectionTitle(
                    title: 'Módulos',
                    subtitle: 'Gestiona tu tienda con estilo',
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, c) {
                      final isWide = c.maxWidth >= 520;
                      final crossAxisCount = isWide ? 3 : 2;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.12,
                        children: [
                          _ModuleTile(
                            title: 'Inventario',
                            subtitle: 'Stock & entradas',
                            icon: Icons.inventory_2_outlined,
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.brandPink,
                                AppTheme.brandOrange,
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const InventoryScreen(),
                                ),
                              );
                            },
                          ),
                          _ModuleTile(
                            title: 'Productos',
                            subtitle: 'Catálogo',
                            icon: Icons.local_mall_outlined,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProductsScreen(),
                                ),
                              );
                            },
                          ),
                          _ModuleTile(
                            title: 'Ventas',
                            subtitle: 'Órdenes',
                            icon: Icons.receipt_long_outlined,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF10B981)],
                            ),
                            onTap: () {
                              _snack(context, 'Ventas (próximo módulo)');
                            },
                          ),
                          _ModuleTile(
                            title: 'Clientes',
                            subtitle: 'CRM básico',
                            icon: Icons.people_outline,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB703), Color(0xFFFB7185)],
                            ),
                            onTap: () {
                              _snack(context, 'Clientes (próximo módulo)');
                            },
                          ),
                          _ModuleTile(
                            title: 'Reportes',
                            subtitle: 'Analítica',
                            icon: Icons.auto_graph_outlined,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF111827), Color(0xFF374151)],
                            ),
                            onTap: () {
                              _snack(context, 'Reportes (próximo módulo)');
                            },
                          ),
                          _ModuleTile(
                            title: 'Usuarios',
                            subtitle: 'Roles & accesos',
                            icon: Icons.admin_panel_settings_outlined,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                            ),
                            badge: role == 'ADMIN' ? 'ADMIN' : null,
                            onTap: () {
                              if (role != 'ADMIN') {
                                _snack(
                                    context, 'Solo ADMIN puede ver Usuarios');
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const UsersScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    title: 'Acciones rápidas',
                    subtitle: 'Atajos para tu día a día',
                  ),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    icon: Icons.person_outline,
                    title: 'Mi perfil',
                    subtitle: 'Ver y editar datos de usuario',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _QuickActionCard(
                    icon: Icons.add_circle_outline,
                    title: 'Nuevo producto',
                    subtitle: 'Crear un perfume en 10 segundos',
                    onTap: () =>
                        _snack(context, 'Nuevo producto (próximo módulo)'),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionCard(
                    icon: Icons.logout,
                    title: 'Cerrar sesión',
                    subtitle: 'Salir de la cuenta actual',
                    onTap: _logout,
                    danger: true,
                  ),
                  const SizedBox(height: 18),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          color: AppTheme.brandPink,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tip: Mantén tu inventario actualizado. Un stock limpio vende más.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _TopGlassHeader extends StatelessWidget {
  final String title;
  final String username;
  final String role;
  final bool loading;
  final VoidCallback onLogout;

  const _TopGlassHeader({
    required this.title,
    required this.username,
    required this.role,
    required this.loading,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppTheme.brandGradient,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33FF4D8D),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_florist_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                if (loading)
                  const Text(
                    'Cargando perfil...',
                    style: TextStyle(color: AppTheme.textMuted),
                  )
                else
                  Row(
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(role: role),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final normalizedRole = role.toUpperCase();
    final isAdmin = normalizedRole == 'ADMIN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isAdmin ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
        border: Border.all(
          color: isAdmin ? const Color(0xFFFFCDD5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        normalizedRole,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: isAdmin ? const Color(0xFF9F1239) : const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String? badge;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x10FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.20),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _NeonIcon(icon: icon, gradient: gradient),
                      const Spacer(),
                      if (badge != null) _TinyBadge(text: badge!),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.8,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonIcon extends StatelessWidget {
  final IconData icon;
  final LinearGradient gradient;

  const _NeonIcon({required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  const _TinyBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [AppTheme.brandPink, AppTheme.brandOrange],
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = danger ? const Color(0xFFEF4444) : AppTheme.brandPink;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E8F0)),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFF9F1239)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF9F1239),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

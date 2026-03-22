import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String _roleFilter = 'TODOS';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleUsers {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _users.where((user) {
      final role = (user['role'] ?? '').toString().toUpperCase();
      if (_roleFilter != 'TODOS' && role != _roleFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final username = (user['username'] ?? '').toString().toLowerCase();
      final fullName =
          (user['fullName'] ?? user['name'] ?? '').toString().toLowerCase();

      return username.contains(query) || fullName.contains(query);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _auth.getToken();
      if (token == null || token.isEmpty) throw Exception('No token');

      final data = await _api.get('/api/users', token: token);
      final raw = (data['users'] as List?) ?? [];
      final list =
          raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

      if (!mounted) return;
      setState(() => _users = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildUserAvatar(Map<String, dynamic> user) {
    final avatar = user['avatar'];
    ImageProvider? image;
    if (avatar is String && avatar.isNotEmpty) {
      if (avatar.startsWith('http') || avatar.startsWith('https')) {
        image = NetworkImage(avatar);
      } else {
        try {
          final bytes = base64Decode(avatar);
          image = MemoryImage(bytes);
        } catch (_) {
          image = null;
        }
      }
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: AppTheme.brandPink,
      backgroundImage: image,
      child: image == null
          ? Text(
              (user['username']?.toString().trim().isNotEmpty ?? false)
                  ? user['username']![0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            )
          : null,
    );
  }

  Future<void> _pickUserAvatar(String userId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final encoded = base64Encode(bytes);

    await _updateUser(userId, {'avatarBase64': encoded});
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: const Text(
            '¿Estás seguro de eliminar este usuario? Esta acción es irreversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.brandPink),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _auth.getToken();
      if (token == null || token.isEmpty) throw Exception('No token');

      await _api.delete('/api/users/$userId', token: token);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${e.toString()}')));
    }
  }

  Future<void> _showUserActions(Map<String, dynamic> user) async {
    final id = (user['id'] ?? user['_id'])?.toString();
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró ID del usuario')));
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar usuario'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Actualizar foto'),
              onTap: () => Navigator.of(context).pop('photo'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar usuario'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (selected == 'edit') {
      await _openEditUserPage(user);
    } else if (selected == 'photo') {
      await _pickUserAvatar(id);
    } else if (selected == 'delete') {
      await _deleteUser(id);
    }
  }

  Future<void> _openEditUserPage(Map<String, dynamic> user) async {
    final id = (user['id'] ?? user['_id'])?.toString();
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró ID del usuario')));
      return;
    }

    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => UserEditScreen(user: user),
      ),
    );

    if (updated != null) {
      await _updateUser(id, updated);
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> body) async {
    if (body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios para actualizar')),
      );
      return;
    }

    final updateLabel = body.containsKey('avatarBase64')
        ? 'la foto del usuario'
        : 'los datos del usuario';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar actualización'),
        content: Text('¿Estás seguro de actualizar $updateLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, actualizar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _auth.getToken();
      if (token == null || token.isEmpty) throw Exception('No token');

      await _api.patch('/api/users/$userId', token: token, body: body);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _visibleUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                const AppPageHeader(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Gestión de usuarios',
                  subtitle: 'Administra accesos y roles',
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else if (_error != null)
                  Column(
                    children: [
                      ErrorMessage(text: _error!),
                      const SizedBox(height: 10),
                      SecondaryButton(
                        text: 'Reintentar',
                        icon: Icons.refresh,
                        onPressed: _load,
                      ),
                    ],
                  )
                else if (_users.isEmpty)
                  AppEmptyState(
                    icon: Icons.group_outlined,
                    title: 'No hay usuarios para mostrar',
                    subtitle:
                        'Aún no existen usuarios registrados en este entorno.',
                    actionText: 'Refrescar',
                    onAction: _load,
                  )
                else ...[
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Buscar por usuario o nombre',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _roleFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por rol',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'TODOS',
                              child: Text('Todos los roles'),
                            ),
                            DropdownMenuItem(
                              value: 'ADMIN',
                              child: Text('ADMIN'),
                            ),
                            DropdownMenuItem(
                              value: 'USER',
                              child: Text('USER'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _roleFilter = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    const AppEmptyState(
                      icon: Icons.filter_list_off,
                      title: 'No hay coincidencias',
                      subtitle: 'Prueba otro texto o cambia el filtro de rol.',
                    )
                  else
                    ...users.map((u) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            padding: const EdgeInsets.all(0),
                            child: InkWell(
                              onTap: () => _openEditUserPage(u),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    _buildUserAvatar(u),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              u['username']?.toString() ??
                                                  '- -',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 4),
                                          Text('Rol: ${u['role'] ?? '-'}',
                                              style: const TextStyle(
                                                  color: AppTheme.textMuted)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _showUserActions(u),
                                      icon: const Icon(Icons.more_vert,
                                          color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserEditScreen({required this.user, super.key});

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _roleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.user['fullName']?.toString() ??
            widget.user['name']?.toString() ??
            '');
    _usernameController =
        TextEditingController(text: widget.user['username']?.toString() ?? '');
    _roleController =
        TextEditingController(text: widget.user['role']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _save() {
    final updates = <String, dynamic>{
      if (_nameController.text.trim().isNotEmpty)
        'fullName': _nameController.text.trim(),
      if (_usernameController.text.trim().isNotEmpty)
        'username': _usernameController.text.trim(),
      if (_roleController.text.trim().isNotEmpty)
        'role': _roleController.text.trim(),
    };

    if (updates.isEmpty) {
      Navigator.of(context).pop(null);
      return;
    }

    Navigator.of(context).pop(updates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuario'),
        backgroundColor: AppTheme.brandPink,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Usuario'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _roleController,
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPink),
                onPressed: _save,
                child: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

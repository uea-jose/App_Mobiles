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

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final id = user['id'] ?? user['_id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encuentra ID del usuario')));
      return;
    }

    final nameController = TextEditingController(
        text: user['fullName']?.toString() ?? user['name']?.toString() ?? '');
    final usernameController =
        TextEditingController(text: user['username']?.toString() ?? '');
    final roleController =
        TextEditingController(text: user['role']?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar usuario'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Usuario'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.brandPink),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final updated = {
      if (nameController.text.trim().isNotEmpty)
        'fullName': nameController.text.trim(),
      if (usernameController.text.trim().isNotEmpty)
        'username': usernameController.text.trim(),
      if (roleController.text.trim().isNotEmpty)
        'role': roleController.text.trim(),
    };

    if (updated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se modificaron campos')));
      return;
    }

    await _updateUser(id.toString(), updated);
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> body) async {
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
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
                        ),
                        child: const Icon(Icons.admin_panel_settings_outlined,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Usuarios',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textDark)),
                      ),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else if (_error != null)
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFF9F1239),
                            fontWeight: FontWeight.w700)),
                  )
                else ...[
                  ..._users.map((u) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          padding: const EdgeInsets.all(0),
                          child: InkWell(
                            onTap: () => _showEditUserDialog(u),
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
                                        Text(u['username']?.toString() ?? '- -',
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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_3/services/auth_service.dart';
import 'package:flutter_application_3/services/profile_service.dart';
import 'package:flutter_application_3/ui/app_theme.dart';
import 'package:flutter_application_3/ui/app_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _profileService = ProfileService();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _user;
  String? _avatarData;
  File? _avatarFile;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _auth.getUser();
      if (user == null) {
        throw Exception('Usuario no encontrado');
      }

      if (!mounted) return;

      setState(() {
        _user = Map<String, dynamic>.from(user);
        _nameController.text =
            (user['fullName'] ?? user['name'] ?? '').toString();
        _usernameController.text = (user['username'] ?? '').toString();

        // Recupera avatar local si existe
        final avatar = user['avatar']?.toString();
        _avatarData =
            (avatar != null && avatar.isNotEmpty && !avatar.startsWith('http'))
                ? avatar
                : null;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final result = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (result == null) return;

    final file = File(result.path);
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);

    if (!mounted) return;

    setState(() {
      _avatarFile = file;
      _avatarData = base64String;
    });
  }

  ImageProvider? _buildAvatarProvider() {
    if (_avatarFile != null) {
      return FileImage(_avatarFile!);
    }

    final avatar = _user?['avatar']?.toString();
    if (avatar == null || avatar.isEmpty) return null;

    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return NetworkImage(avatar);
    }

    if (avatar.startsWith('data:image')) {
      try {
        final base64String = avatar.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (_) {
        return null;
      }
    }

    try {
      return MemoryImage(base64Decode(avatar));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final token = await _auth.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token expirado. Vuelve a iniciar sesión.');
      }

      final updated = await _profileService.updateProfile(
        token: token,
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        avatarBase64: _avatarData,
        userId: _user?['id']?.toString() ?? _user?['_id']?.toString(),
      );

      final currentUser = await _auth.getUser();

      final mergedUser = <String, dynamic>{
        ...?currentUser,
        ...updated,
        'fullName': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        if (_avatarData != null && _avatarData!.isNotEmpty)
          'avatar': _avatarData,
      };

      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.setString('auth_user', jsonEncode(mergedUser));

      if (!mounted) return;

      setState(() {
        _user = mergedUser;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _showPhotoOptions() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir desde galería'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context, null),
              ),
            ],
          ),
        );
      },
    );

    if (selected == 'camera') {
      await _pickImage(ImageSource.camera);
    } else if (selected == 'gallery') {
      await _pickImage(ImageSource.gallery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _user?['fullName'] ?? _user?['name'] ?? 'Perfil';
    final username = _user?['username'] ?? 'usuario';
    final avatarProvider = _buildAvatarProvider();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: AppTheme.brandPink,
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: AppTheme.brandPink,
                              backgroundImage: avatarProvider,
                              child: avatarProvider == null
                                  ? const Icon(Icons.person, size: 48)
                                  : null,
                            ),
                            FloatingActionButton.small(
                              heroTag: 'avatarBtn',
                              onPressed: _showPhotoOptions,
                              child: const Icon(Icons.camera_alt_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fullName.toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Editar información',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        const SizedBox(height: 4),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _saveProfile,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _saving ? 'Guardando...' : 'Guardar perfil',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPink,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

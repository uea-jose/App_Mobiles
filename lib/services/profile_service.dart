import 'package:flutter_application_3/services/api_client.dart';

class ProfileService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getProfile({
    required String token,
  }) async {
    final data = await _api.get(
      '/api/me',
      token: token,
    );

    final user = (data['user'] as Map?)?.cast<String, dynamic>() ??
        (data['me'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    if (user.isEmpty) {
      throw Exception('No se pudo obtener el perfil');
    }

    return user;
  }

  // Si quieres actualizar el perfil, puedes usar este método. Solo envía los campos que quieras cambiar.

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? fullName,
    String? username,
    String? avatarBase64,
    String? userId,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'fullName': fullName,
      if (username != null) 'username': username,
      if (avatarBase64 != null) 'avatarBase64': avatarBase64,
    };

    if (body.isEmpty) {
      return {};
    }

    final data = await _api.put(
      '/api/profile',
      token: token,
      body: body,
    );

    final user =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    if (user.isEmpty) {
      throw Exception('No se pudo actualizar el perfil');
    }

    return user;
  }
}

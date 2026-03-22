import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';

  final ApiClient _api = ApiClient();

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.post('/api/auth/login', body: {
      'username': username.trim(),
      'password': password,
    });

    final token = (data['token'] ?? '').toString();
    if (token.isEmpty) {
      throw Exception('Token missing');
    }

    final user =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    if (user.isEmpty) {
      throw Exception('User missing in login response');
    }

    final normalizedUser = <String, dynamic>{
      ...user,
      'role': (user['role'] ?? 'USER').toString().toUpperCase(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(normalizedUser));

    return normalizedUser;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? fullName,
    String? city,
    String? phone,
    String role = 'USER',
    String? adminKey,
  }) async {
    final normalizedRole =
        role.trim().toUpperCase() == 'ADMIN' ? 'ADMIN' : 'USER';

    final body = <String, dynamic>{
      'username': username.trim(),
      'password': password,
      'role': normalizedRole,
      if (fullName != null && fullName.trim().isNotEmpty)
        'fullName': fullName.trim(),
      if (adminKey != null && adminKey.trim().isNotEmpty)
        'adminKey': adminKey.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };

    final data = await _api.post('/api/auth/register', body: body);

    final token = (data['token'] ?? '').toString();
    if (token.isEmpty) {
      throw Exception('Register succeeded but token missing');
    }

    final user =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    if (user.isEmpty) {
      throw Exception('User missing in register response');
    }

    final normalizedUser = <String, dynamic>{
      ...user,
      'role': (user['role'] ?? 'USER').toString().toUpperCase(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(normalizedUser));

    return normalizedUser;
  }

  Future<Map<String, dynamic>> me() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token');
    }

    final data = await _api.get('/api/me', token: token);

    final user = (data['user'] as Map?)?.cast<String, dynamic>() ??
        (data['me'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    if (user.isEmpty) {
      throw Exception('No se pudo cargar el perfil');
    }

    final normalizedUser = <String, dynamic>{
      ...user,
      'role': (user['role'] ?? 'USER').toString().toUpperCase(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(normalizedUser));

    return normalizedUser;
  }
}

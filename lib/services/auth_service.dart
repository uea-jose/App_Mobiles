import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  static const _kToken = 'token';
  static const _kUser = 'user_json';

  static Future<void> saveToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUser, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  static Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kUser);
  }

  /// ✅ Usuario actual: primero de caché, si no, lo trae del backend (/api/me)
  static Future<Map<String, dynamic>> currentUser() async {
    final cached = await getUser();
    if (cached != null) return cached;

    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hay token guardado');
    }

    final res = await ApiClient.get('/api/me', token: token);
    final me = (res['me'] is Map) ? Map<String, dynamic>.from(res['me']) : null;
    if (me == null) throw Exception('No se recibió /api/me');

    // Tu backend /api/me devuelve el payload del JWT:
    // { sub, email, role, name }
    final user = <String, dynamic>{
      'id': me['sub'],
      'name': me['name'],
      'email': me['email'],
      'role': me['role'],
    };

    await saveUser(user);
    return user;
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await ApiClient.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );

    final token = (res['token'] ?? res['accessToken'])?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('No se recibió token del servidor');
    }

    await saveToken(token);

    // backend: { token, user: {id,name,email,role} }
    if (res['user'] is Map) {
      await saveUser(Map<String, dynamic>.from(res['user'] as Map));
    } else {
      // si por alguna razón no viene user, lo pedimos con /api/me
      await currentUser();
    }
  }

  static Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await ApiClient.post(
      '/api/auth/register',
      body: {'name': name, 'email': email, 'password': password, 'role': role},
    );
  }
}

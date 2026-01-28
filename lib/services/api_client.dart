import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // ✅ Emulador Android:
  static const String baseUrl = 'http://10.0.2.2:3000';

  // ✅ Android físico (Samsung) (tu PC en la red):
  // static const String baseUrl = 'http://192.168.100.229:3000';

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> _headers({String? token}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    String? token,
  }) async {
    final res = await http.get(
      _uri(path),
      headers: _headers(token: token),
    );

    final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    final msg = (decoded is Map && decoded['message'] != null)
        ? decoded['message'].toString()
        : 'Error HTTP ${res.statusCode}';
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final res = await http.post(
      _uri(path),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );

    final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    final msg = (decoded is Map && decoded['message'] != null)
        ? decoded['message'].toString()
        : 'Error HTTP ${res.statusCode}';
    throw Exception(msg);
  }
}

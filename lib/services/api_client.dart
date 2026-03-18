import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // static const String baseUrl = 'http://10.0.2.2:3000';
  static String baseUrl = 'http://192.168.100.229:3000';

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final resp = await http.get(uri, headers: _headers(token));
    return _handle(resp);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body ?? {}),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.put(
      uri,
      headers: _headers(token),
      body: jsonEncode(body ?? {}),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.patch(
      uri,
      headers: _headers(token),
      body: jsonEncode(body ?? {}),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.delete(uri, headers: _headers(token));
    return _handle(resp);
  }

  Map<String, String> _headers(String? token) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Map<String, dynamic> _handle(http.Response resp) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}

    if (resp.statusCode >= 200 && resp.statusCode < 300) return data;

    final msg = (data['message'] ?? 'HTTP ${resp.statusCode}').toString();
    throw Exception(msg);
  }
}

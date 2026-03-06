import '../models/brand.dart';
import 'api_client.dart';
import 'auth_service.dart';

class BrandService {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  /// Obtener lista de casas fabricantes (brands)
  Future<List<Brand>> list() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token');
    }

    final data = await _api.get('/api/brands', token: token);

    final raw = (data['brands'] as List?) ?? [];

    return raw
        .whereType<Map>()
        .map((e) => Brand.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Crear nueva casa fabricante
  Future<Brand> create({
    required String name,
    String? country,
  }) async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token');
    }

    final data = await _api.post(
      '/api/brands',
      token: token,
      body: {
        'name': name.trim(),
        if (country != null && country.trim().isNotEmpty) 'country': country,
      },
    );

    final brand =
        (data['brand'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    return Brand.fromJson(brand);
  }

  /// Eliminar casa fabricante
  Future<void> delete(String id) async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token');
    }

    await _api.delete('/api/brands/$id', token: token);
  }
}

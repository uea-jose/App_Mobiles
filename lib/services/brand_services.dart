import '../models/brand.dart';
import 'api_client.dart';
import 'auth_service.dart';

class BrandResolveResult {
  final Brand brand;
  final bool created;

  const BrandResolveResult({
    required this.brand,
    required this.created,
  });
}

class BrandService {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  String _normalizeName(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

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

  Future<BrandResolveResult> findOrCreateByName({
    required String name,
    String? country,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Nombre de casa fabricante requerido');
    }

    final normalized = _normalizeName(cleanName);
    final current = await list();

    for (final item in current) {
      if (_normalizeName(item.name) == normalized) {
        return BrandResolveResult(brand: item, created: false);
      }
    }

    try {
      final createdBrand = await create(name: cleanName, country: country);
      return BrandResolveResult(brand: createdBrand, created: true);
    } catch (_) {
      final reloaded = await list();
      for (final item in reloaded) {
        if (_normalizeName(item.name) == normalized) {
          return BrandResolveResult(brand: item, created: false);
        }
      }
      rethrow;
    }
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

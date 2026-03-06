import '../models/product_dto.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ProductsService {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  Future<String> _token() async {
    final t = await _auth.getToken();
    if (t == null || t.isEmpty) throw Exception('No token');
    return t;
  }

  Future<List<ProductDTO>> list() async {
    final token = await _token();
    final data = await _api.get('/api/products', token: token);
    final raw = (data['products'] as List?) ?? [];

    return raw
        .whereType<Map>()
        .map((e) => ProductDTO.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<String> create({
    String? sku,
    required String name,
    required String brandId,
    String? gender,
    String? description,
    required double price,
    String? imageUrl,
    int stock = 0,
    int minStock = 0,
  }) async {
    final token = await _token();

    final body = <String, dynamic>{
      'name': name.trim(),
      'brandId': brandId,
      'price': price,
      'stock': stock,
      'minStock': minStock,
    };

    if (sku != null && sku.trim().isNotEmpty) body['sku'] = sku.trim();
    if (gender != null && gender.trim().isNotEmpty) {
      body['gender'] = gender.trim().toUpperCase();
    }
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      body['imageUrl'] = imageUrl.trim();
    }

    final data = await _api.post('/api/products', token: token, body: body);

    final id = (data['id'] ?? '').toString();
    if (id.isEmpty) throw Exception('No retornó id del producto');
    return id;
  }

  Future<void> update({
    required String id,
    String? sku,
    required String name,
    required String brandId,
    String? gender,
    String? description,
    required double price,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final token = await _token();

    final body = <String, dynamic>{
      'name': name.trim(),
      'brandId': brandId,
      'price': price,
      'isActive': isActive,
    };

    if (sku != null && sku.trim().isNotEmpty) body['sku'] = sku.trim();
    if (gender != null && gender.trim().isNotEmpty) {
      body['gender'] = gender.trim().toUpperCase();
    }
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      body['imageUrl'] = imageUrl.trim();
    }

    await _api.put('/api/products/$id', token: token, body: body);
  }

  Future<void> delete(String id) async {
    final token = await _token();
    await _api.delete('/api/products/$id', token: token);
  }

  Future<void> setInventory({
    required String productId,
    required int stock,
    required int minStock,
  }) async {
    final token = await _token();
    await _api.put(
      '/api/inventory/$productId',
      token: token,
      body: {'stock': stock, 'minStock': minStock},
    );
  }
}

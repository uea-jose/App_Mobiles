import '../models/product_dto.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ProductsService {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token');
    }
    return token;
  }

  Future<List<ProductDTO>> list() async {
    final token = await _token();

    final data = await _api.get('/api/products', token: token);
    final raw = _extractRawList(data);

    return raw
        .whereType<Map>()
        .map((e) => ProductDTO.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ProductDTO> create({
    String? sku,
    required String name,
    required String brandId,
    String? gender,
    String? description,
    required double price,
    String? imageUrl,
    required int stock,
    required int minStock,
  }) async {
    final token = await _token();

    final data = await _api.post(
      '/api/products',
      token: token,
      body: {
        if (sku != null && sku.trim().isNotEmpty) 'sku': sku.trim(),
        'name': name.trim(),
        'brand_id': brandId,
        'brandId': brandId,
        if (gender != null && gender.trim().isNotEmpty) 'gender': gender.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'price': price,
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'image_url': imageUrl.trim(),
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'imageUrl': imageUrl.trim(),
        'stock': stock,
        'min_stock': minStock,
        'minStock': minStock,
      },
    );

    final product = _extractSingleProduct(data) ?? <String, dynamic>{};
    return ProductDTO.fromJson(product);
  }

  Future<ProductDTO> update({
    required String id,
    String? sku,
    required String name,
    required String brandId,
    String? gender,
    String? description,
    required double price,
    String? imageUrl,
    int? stock,
    int? minStock,
    bool? isActive,
  }) async {
    final token = await _token();

    final payload = {
      if (sku != null && sku.trim().isNotEmpty) 'sku': sku.trim(),
      'name': name.trim(),
      'brand_id': brandId,
      'brandId': brandId,
      if (gender != null && gender.trim().isNotEmpty) 'gender': gender.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'price': price,
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'image_url': imageUrl.trim(),
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'imageUrl': imageUrl.trim(),
      if (stock != null) 'stock': stock,
      if (minStock != null) 'min_stock': minStock,
      if (minStock != null) 'minStock': minStock,
      if (isActive != null) 'is_active': isActive,
      if (isActive != null) 'isActive': isActive,
    };

    Map<String, dynamic> data;
    try {
      data = await _api.put(
        '/api/products/$id',
        token: token,
        body: payload,
      );
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('404')) rethrow;

      data = await _api.patch(
        '/api/products/$id',
        token: token,
        body: payload,
      );
    }

    final product = _extractSingleProduct(data) ?? <String, dynamic>{};
    return ProductDTO.fromJson(product);
  }

  Future<void> setInventory({
    required String productId,
    required int stock,
    required int minStock,
  }) async {
    final token = await _token();

    try {
      await _api.patch(
        '/api/products/$productId/inventory',
        token: token,
        body: {
          'stock': stock,
          'min_stock': minStock,
          'minStock': minStock,
        },
      );
    } catch (_) {
      try {
        await _api.put(
          '/api/inventory/$productId',
          token: token,
          body: {
            'stock': stock,
            'min_stock': minStock,
            'minStock': minStock,
          },
        );
      } catch (_) {
        await _api.patch(
          '/api/inventory/$productId',
          token: token,
          body: {
            'stock': stock,
            'min_stock': minStock,
            'minStock': minStock,
          },
        );
      }
    }
  }

  Future<void> delete(String id) async {
    final token = await _token();

    await _api.delete('/api/products/$id', token: token);
  }

  Map<String, dynamic>? _extractSingleProduct(Map<String, dynamic> data) {
    final candidates = [
      data['product'],
      data['item'],
      data['data'],
      data,
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic> && candidate.isNotEmpty) {
        return candidate;
      }

      if (candidate is Map) {
        return candidate.cast<String, dynamic>();
      }
    }

    return null;
  }

  List<dynamic> _extractRawList(Map<String, dynamic> data) {
    final candidates = [
      data['products'],
      data['items'],
      data['data'],
      data['results'],
    ];

    for (final candidate in candidates) {
      if (candidate is List && candidate.isNotEmpty) {
        return candidate;
      }
    }

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate;
      }
    }

    return const [];
  }
}

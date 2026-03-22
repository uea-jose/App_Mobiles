class ProductDTO {
  final String id;
  final String name;
  final String? sku;
  final double price;
  final int stock;
  final int minStock;
  final String? description;
  final String? imageUrl;
  final String? gender;
  final String brandId;
  final String brandName;

  const ProductDTO({
    required this.id,
    required this.name,
    this.sku,
    required this.price,
    required this.stock,
    required this.minStock,
    this.description,
    this.imageUrl,
    this.gender,
    required this.brandId,
    required this.brandName,
  });

  factory ProductDTO.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? json['uuid'] ?? '').toString();
    final name = (json['name'] ?? json['nombre'] ?? '').toString().trim();
    final rawSku = json['sku']?.toString();
    final sku = (rawSku == null || rawSku.trim().isEmpty) ? null : rawSku;
    final price = _asDouble(json['price'] ?? json['precio']);
    final stock = _asInt(json['stock']);
    final minStock = _asInt(json['min_stock'] ?? json['minStock']);
    final description = json['description']?.toString();
    final imageUrl = (json['imageUrl'] ?? json['image_url'])?.toString();
    final gender = json['gender']?.toString();

    String brandId = '';
    String brandName = '';
    final brandRaw = json['brand'];
    if (brandRaw is Map<String, dynamic>) {
      brandId = (brandRaw['id'] ?? brandRaw['_id'] ?? '').toString();
      brandName = (brandRaw['name'] ?? '').toString();
    }
    if (brandId.isEmpty) {
      brandId = (json['brand_id'] ?? json['brandId'] ?? '').toString();
    }
    if (brandName.isEmpty) {
      brandName = (json['brand_name'] ?? json['brandName'] ?? '').toString();
    }

    return ProductDTO(
      id: id,
      name: name,
      sku: sku,
      price: price,
      stock: stock,
      minStock: minStock,
      description: description,
      imageUrl: imageUrl,
      gender: gender,
      brandId: brandId,
      brandName: brandName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (sku != null) 'sku': sku,
        'price': price,
        'stock': stock,
        'min_stock': minStock,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (gender != null) 'gender': gender,
        'brandId': brandId,
        'brandName': brandName,
      };

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final normalized = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final normalized = value.toString().trim().replaceAll(',', '.');
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(normalized);
    return asDouble?.toInt() ?? 0;
  }
}

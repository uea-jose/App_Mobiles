class ProductDTO {
  final String id;
  final String? sku;
  final String name;

  final String brandId;
  final String brandName;

  final String? gender; // FEMENINO | MASCULINO | UNISEX
  final String? description;
  final double price;
  final String? imageUrl;

  final int stock;
  final int minStock;

  const ProductDTO({
    required this.id,
    required this.sku,
    required this.name,
    required this.brandId,
    required this.brandName,
    required this.gender,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.stock,
    required this.minStock,
  });

  static double _parsePrice(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory ProductDTO.fromJson(Map<String, dynamic> json) {
    return ProductDTO(
      id: (json['id'] ?? '').toString(),
      sku: json['sku']?.toString(),
      name: (json['name'] ?? '').toString(),

      // soporta snake_case y camelCase por si acaso
      brandId: (json['brand_id'] ?? json['brandId'] ?? '').toString(),
      brandName: (json['brand_name'] ?? json['brandName'] ?? '').toString(),

      gender: json['gender']?.toString(),
      description: json['description']?.toString(),
      price: _parsePrice(json['price']),
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),

      stock: _parseInt(json['stock']),
      minStock: _parseInt(json['min_stock'] ?? json['minStock']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'brandId': brandId, // para requests normalmente se usa brandId
      'brandName': brandName,
      'gender': gender,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'stock': stock,
      'minStock': minStock,
    };
  }

  ProductDTO copyWith({
    String? id,
    String? sku,
    String? name,
    String? brandId,
    String? brandName,
    String? gender,
    String? description,
    double? price,
    String? imageUrl,
    int? stock,
    int? minStock,
  }) {
    return ProductDTO(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      gender: gender ?? this.gender,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
    );
  }
}

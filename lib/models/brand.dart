class Brand {
  final String id;
  final String name;
  final String? country;

  const Brand({
    required this.id,
    required this.name,
    this.country,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      country: json['country']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (country != null) 'country': country,
      };
}

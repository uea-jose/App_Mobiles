import 'auth_service.dart';
import 'api_client.dart';

class PerfumeOption {
  final String id;
  final String name;
  final String? imageUrl;
  final String? sku;
  final String? description;
  final String? brand;
  final String? gender;

  const PerfumeOption({
    required this.id,
    required this.name,
    this.imageUrl,
    this.sku,
    this.description,
    this.brand,
    this.gender,
  });

  factory PerfumeOption.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? json['uuid'] ?? '').toString();
    final name = (json['name'] ?? json['nombre'] ?? json['title'] ?? '')
        .toString()
        .trim();
    final imageUrl = (json['imageUrl'] ??
            json['image_url'] ??
            json['image'] ??
            json['url'] ??
            json['thumbnail'] ??
            json['image_path'] ??
            json['imagePath'] ??
            json['img'] ??
            json['photo'] ??
            json['picture'] ??
            json['picture_url'] ??
            json['foto'] ??
            json['foto_url'])
        ?.toString()
        .trim();
    final sku =
        (json['sku'] ?? json['code'] ?? json['codigo'])?.toString().trim();
    final description =
        (json['description'] ?? json['descripcion'] ?? json['notes'])
            ?.toString()
            .trim();
    final brand = (json['brand'] ?? json['brandName'] ?? json['marca'])
        ?.toString()
        .trim();
    final gender = (json['gender'] ??
        json['genero'] ??
        json['sexo'] ??
        json['target'] ??
        json['category'])
      ?.toString()
      .trim();

    final normalized = _normalizeImageUrl(imageUrl);
    if (name.isNotEmpty && normalized == null) {
      debugLog(
        'PerfumeOption.fromJson: $name has no imageUrl after normalization. raw=$imageUrl',
      );
    }

    return PerfumeOption(
      id: id.isEmpty ? name : id,
      name: name,
      imageUrl: normalized,
      sku: (sku == null || sku.isEmpty) ? null : sku,
      description:
          (description == null || description.isEmpty) ? null : description,
      brand: (brand == null || brand.isEmpty) ? null : brand,
      gender: (gender == null || gender.isEmpty) ? null : gender,
    );
  }

  static void debugLog(String msg) {
    print('[PerfumeOption] $msg');
  }

  static String? _normalizeImageUrl(String? raw) {
    if (raw == null) return null;

    final trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('data:image/')) return trimmed;

    final apiUri = Uri.tryParse(ApiClient.baseUrl);
    final appHost = apiUri?.host.isNotEmpty == true ? apiUri!.host : '10.0.2.2';
    final apiOrigin = apiUri?.origin ?? 'http://$appHost:3000';

    if (trimmed.startsWith('//')) {
      return Uri.encodeFull('http:$trimmed');
    }

    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        !trimmed.startsWith('/')) {
      final normalizedPath =
          trimmed.startsWith('./') ? trimmed.substring(2) : trimmed;
      final path = normalizedPath.startsWith('/')
          ? normalizedPath.substring(1)
          : normalizedPath;
      return Uri.encodeFull('$apiOrigin/$path');
    }

    if (trimmed.startsWith('/')) {
      return Uri.encodeFull('$apiOrigin$trimmed');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return Uri.encodeFull(trimmed);

    final host = uri.host.toLowerCase();
    if (host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '10.0.2.2' ||
        host == '10.0.3.2') {
      return Uri.encodeFull(
        uri
            .replace(
              host: appHost,
              port: uri.hasPort ? uri.port : null,
            )
            .toString(),
      );
    }

    return Uri.encodeFull(trimmed);
  }
}

class PerfumeOptionsService {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  Future<List<PerfumeOption>> listOptions() async {
    final token = await _auth.getToken();

    final data = await _api.get(
      '/api/integrations/perfumes/options',
      token: token,
    );

    final rawList = _extractRawList(data);

    return rawList
        .whereType<Map>()
        .map((e) => PerfumeOption.fromJson(e.cast<String, dynamic>()))
        .where((e) => e.name.isNotEmpty)
        .toList();
  }

  List<dynamic> _extractRawList(Map<String, dynamic> data) {
    final candidates = [
      data['options'],
      data['perfumes'],
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

import 'api_client.dart';
import 'auth_service.dart';

class ClientsService {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token');
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> list() async {
    try {
      final token = await _token();
      final data = await _api.get('/api/clients', token: token);
      final raw = _extractList(data, ['clients', 'data', 'items']);

      final list = raw
          .whereType<Map>()
          .map((e) => _normalize(e.cast<String, dynamic>()))
          .toList();

      if (list.isNotEmpty) return list;
      return _mockClients();
    } catch (_) {
      return _mockClients();
    }
  }

  List<dynamic> _extractList(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) return value;
    }

    for (final value in data.values) {
      if (value is List) return value;
    }

    return const [];
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return {
      ...raw,
      'id': (raw['id'] ?? raw['_id'] ?? '').toString(),
      'fullName':
          (raw['full_name'] ?? raw['fullName'] ?? raw['name'] ?? '').toString(),
      'cedula': (raw['cedula'] ?? '').toString(),
      'email': (raw['email'] ?? '').toString(),
      'address': (raw['address'] ?? raw['city'] ?? '').toString(),
      'phone': (raw['phone'] ?? '').toString(),
      'isActive': raw['is_active'] ?? raw['isActive'] ?? true,
      'createdAt': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
    };
  }

  List<Map<String, dynamic>> _mockClients() {
    return [
      _normalize({
        'id': '1',
        'full_name': 'Juan Pérez',
        'cedula': '1102456701',
        'email': 'juan.perez@gmail.com',
        'address': 'Quito',
        'phone': '0991111101',
      }),
      _normalize({
        'id': '2',
        'full_name': 'María López',
        'cedula': '1102456702',
        'email': 'maria.lopez@gmail.com',
        'address': 'Quito',
        'phone': '0991111102',
      }),
      _normalize({
        'id': '3',
        'full_name': 'Carlos Mendoza',
        'cedula': '1102456703',
        'email': 'carlos.mendoza@gmail.com',
        'address': 'Quito',
        'phone': '0991111103',
      }),
      _normalize({
        'id': '4',
        'full_name': 'Andrea Torres',
        'cedula': '1102456704',
        'email': 'andrea.torres@gmail.com',
        'address': 'Quito',
        'phone': '0991111104',
      }),
      _normalize({
        'id': '5',
        'full_name': 'Pedro Ramírez',
        'cedula': '1102456707',
        'email': 'pedro.ramirez@gmail.com',
        'address': 'Guayaquil',
        'phone': '0991111107',
      }),
      _normalize({
        'id': '6',
        'full_name': 'Valeria Mena',
        'cedula': '1102456708',
        'email': 'valeria.mena@gmail.com',
        'address': 'Guayaquil',
        'phone': '0991111108',
      }),
      _normalize({
        'id': '7',
        'full_name': 'Daniel Reinoso',
        'cedula': '1102456711',
        'email': 'daniel.reinoso@gmail.com',
        'address': 'Cuenca',
        'phone': '0991111111',
      }),
      _normalize({
        'id': '8',
        'full_name': 'Fernanda Bravo',
        'cedula': '1102456714',
        'email': 'fernanda.bravo@gmail.com',
        'address': 'Manta',
        'phone': '0991111114',
      }),
    ];
  }
}

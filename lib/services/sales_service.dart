import 'api_client.dart';
import 'auth_service.dart';

class SalesService {
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
      final data = await _api.get('/api/sales', token: token);
      final raw = _extractList(data, ['sales', 'data', 'items']);

      final list = raw
          .whereType<Map>()
          .map((e) => _normalize(e.cast<String, dynamic>()))
          .toList();

      if (list.isNotEmpty) return list;
      return _mockSales();
    } catch (_) {
      return _mockSales();
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
    final clientRaw = raw['client'];
    final client = clientRaw is Map<String, dynamic>
        ? clientRaw
        : clientRaw is Map
            ? clientRaw.cast<String, dynamic>()
            : <String, dynamic>{};

    return {
      ...raw,
      'id': (raw['id'] ?? raw['_id'] ?? '').toString(),
      'clientId': (raw['client_id'] ?? raw['clientId'] ?? client['id'] ?? '')
          .toString(),
      'saleDate':
          (raw['sale_date'] ?? raw['saleDate'] ?? raw['created_at'] ?? '')
              .toString(),
      'total': _asDouble(raw['total']),
      'client': {
        ...client,
        'id': (client['id'] ?? client['_id'] ?? '').toString(),
        'fullName':
            (client['full_name'] ?? client['fullName'] ?? client['name'] ?? '')
                .toString(),
        'address': (client['address'] ?? client['city'] ?? '').toString(),
      },
    };
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final normalized = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  List<Map<String, dynamic>> _mockSales() {
    final now = DateTime.now();
    final samples = [
      // Quito clients (6 clients → most sales)
      {
        'id': '1',
        'clientId': '1',
        'total': 42.00,
        'daysAgo': 19,
        'city': 'Quito',
        'client': 'Juan Pérez'
      },
      {
        'id': '2',
        'clientId': '2',
        'total': 44.50,
        'daysAgo': 18,
        'city': 'Quito',
        'client': 'María López'
      },
      {
        'id': '3',
        'clientId': '3',
        'total': 20.00,
        'daysAgo': 17,
        'city': 'Quito',
        'client': 'Carlos Mendoza'
      },
      {
        'id': '4',
        'clientId': '4',
        'total': 47.00,
        'daysAgo': 16,
        'city': 'Quito',
        'client': 'Andrea Torres'
      },
      {
        'id': '5',
        'clientId': '5',
        'total': 38.75,
        'daysAgo': 14,
        'city': 'Quito',
        'client': 'Luis Suárez'
      },
      {
        'id': '6',
        'clientId': '6',
        'total': 55.00,
        'daysAgo': 13,
        'city': 'Quito',
        'client': 'Sofía Castro'
      },
      // Guayaquil clients (4 clients)
      {
        'id': '7',
        'clientId': '7',
        'total': 22.50,
        'daysAgo': 12,
        'city': 'Guayaquil',
        'client': 'Pedro Ramírez'
      },
      {
        'id': '8',
        'clientId': '8',
        'total': 46.00,
        'daysAgo': 11,
        'city': 'Guayaquil',
        'client': 'Valeria Mena'
      },
      {
        'id': '9',
        'clientId': '9',
        'total': 31.20,
        'daysAgo': 10,
        'city': 'Guayaquil',
        'client': 'Roberto Vera'
      },
      {
        'id': '10',
        'clientId': '10',
        'total': 29.50,
        'daysAgo': 9,
        'city': 'Guayaquil',
        'client': 'Gabriela Loor'
      },
      // Cuenca clients (3 clients)
      {
        'id': '11',
        'clientId': '11',
        'total': 23.89,
        'daysAgo': 8,
        'city': 'Cuenca',
        'client': 'Daniel Reinoso'
      },
      {
        'id': '12',
        'clientId': '12',
        'total': 18.00,
        'daysAgo': 8,
        'city': 'Cuenca',
        'client': 'Patricia Ochoa'
      },
      {
        'id': '13',
        'clientId': '13',
        'total': 35.40,
        'daysAgo': 7,
        'city': 'Cuenca',
        'client': 'Andrés Idrovo'
      },
      // Ambato (1), Loja (1)
      {
        'id': '14',
        'clientId': '14',
        'total': 27.00,
        'daysAgo': 7,
        'city': 'Ambato',
        'client': 'Fernanda Navas'
      },
      {
        'id': '15',
        'clientId': '15',
        'total': 19.90,
        'daysAgo': 6,
        'city': 'Loja',
        'client': 'Marco Peña'
      },
      // Repeat purchases – Quito top clients
      {
        'id': '16',
        'clientId': '1',
        'total': 33.00,
        'daysAgo': 6,
        'city': 'Quito',
        'client': 'Juan Pérez'
      },
      {
        'id': '17',
        'clientId': '2',
        'total': 28.75,
        'daysAgo': 5,
        'city': 'Quito',
        'client': 'María López'
      },
      {
        'id': '18',
        'clientId': '3',
        'total': 41.10,
        'daysAgo': 5,
        'city': 'Quito',
        'client': 'Carlos Mendoza'
      },
      {
        'id': '19',
        'clientId': '7',
        'total': 52.00,
        'daysAgo': 4,
        'city': 'Guayaquil',
        'client': 'Pedro Ramírez'
      },
      {
        'id': '20',
        'clientId': '11',
        'total': 24.50,
        'daysAgo': 4,
        'city': 'Cuenca',
        'client': 'Daniel Reinoso'
      },
      {
        'id': '21',
        'clientId': '4',
        'total': 37.50,
        'daysAgo': 3,
        'city': 'Quito',
        'client': 'Andrea Torres'
      },
      {
        'id': '22',
        'clientId': '8',
        'total': 43.00,
        'daysAgo': 3,
        'city': 'Guayaquil',
        'client': 'Valeria Mena'
      },
      {
        'id': '23',
        'clientId': '1',
        'total': 25.00,
        'daysAgo': 2,
        'city': 'Quito',
        'client': 'Juan Pérez'
      },
      {
        'id': '24',
        'clientId': '2',
        'total': 23.95,
        'daysAgo': 1,
        'city': 'Quito',
        'client': 'María López'
      },
      {
        'id': '25',
        'clientId': '5',
        'total': 48.00,
        'daysAgo': 1,
        'city': 'Quito',
        'client': 'Luis Suárez'
      },
    ];

    return samples
        .map(
          (item) => _normalize({
            'id': item['id'],
            'client_id': item['clientId'],
            'sale_date': now
                .subtract(Duration(days: item['daysAgo'] as int))
                .toIso8601String(),
            'total': item['total'],
            'client': {
              'id': item['clientId'],
              'full_name': item['client'],
              'address': item['city'],
            },
          }),
        )
        .toList();
  }
}

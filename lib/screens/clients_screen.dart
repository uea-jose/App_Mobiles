import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/clients_service.dart';
import '../services/sales_service.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ClientsService _service = ClientsService();
  final SalesService _salesService = SalesService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _sales = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.list(),
        _salesService.list(),
      ]);
      final clients = results[0].cast<Map<String, dynamic>>();
      final sales = results[1].cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _sales = sales;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _error = e.toString().replaceAll('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleClients {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _clients;

    return _clients.where((client) {
      final fullName = (client['fullName'] ?? '').toString().toLowerCase();
      final cedula = (client['cedula'] ?? '').toString().toLowerCase();
      final city = (client['address'] ?? '').toString().toLowerCase();
      final email = (client['email'] ?? '').toString().toLowerCase();
      return fullName.contains(query) ||
          cedula.contains(query) ||
          city.contains(query) ||
          email.contains(query);
    }).toList();
  }

  double get _totalRevenue => _sales.fold<double>(
        0,
        (sum, item) => sum + ((item['total'] as num?)?.toDouble() ?? 0),
      );

  int get _totalPurchases => _sales.length;

    List<_ClientPurchaseMetric> get _topClients {
    final totals = <String, _ClientPurchaseMetric>{};

    for (final sale in _sales) {
      // Use sale clientId if available, otherwise use embedded client id/name,
      // fallback to sale id to ensure no sale is skipped
      final clientId = (sale['clientId'] ?? '').toString().trim();
      final embeddedClient = sale['client'] ?? {};
      final embeddedId =
          (embeddedClient is Map ? (embeddedClient['id'] ?? '') : '')
              .toString()
              .trim();
      final embeddedName = (embeddedClient is Map
              ? (embeddedClient['fullName'] ??
                  embeddedClient['full_name'] ??
                  embeddedClient['name'] ??
                  '')
              : '')
          .toString()
          .trim();
      final saleId = (sale['id'] ?? '').toString().trim();

      // Determine the key (unique identifier for this buyer)
      final key = clientId.isNotEmpty
          ? clientId
          : (embeddedId.isNotEmpty
              ? embeddedId
              : (embeddedName.isNotEmpty ? 'n:$embeddedName' : saleId));

      if (key.isEmpty) continue;

      // Resolve name from embedded or lookup or use embeded name or default
      final matchedClient = _clients.cast<Map<String, dynamic>?>().firstWhere(
            (c) =>
                (c?['id'] ?? '').toString() ==
                (clientId.isNotEmpty ? clientId : embeddedId),
            orElse: () => null,
          );
      final name = matchedClient?['fullName'] as String? ??
          (embeddedName.isNotEmpty ? embeddedName : 'Cliente');
      final total = ((sale['total'] ?? 0) as num).toDouble();

      if (totals.containsKey(key)) {
        final existing = totals[key]!;
        totals[key] = existing.copyWith(
          totalSpent: existing.totalSpent + total,
          purchases: existing.purchases + 1,
        );
      } else {
        totals[key] = _ClientPurchaseMetric(
          id: key,
          name: name,
          totalSpent: total,
          purchases: 1,
        );
      }
    }

    return totals.values.toList()
      ..sort((a, b) => b.purchases != a.purchases
          ? b.purchases.compareTo(a.purchases)
          : b.totalSpent.compareTo(a.totalSpent));
  }

  String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final visibleClients = _visibleClients;
    final topClients = _topClients;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                AppPageHeader(
                  icon: Icons.people_outline,
                  title: 'Clientes',
                  subtitle: 'Consulta clientes y ciudades registradas',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB703), Color(0xFFFB7185)],
                  ),
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Volver',
                  ),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatPill(
                            label: 'Clientes',
                            value: _clients.length.toString(),
                          ),
                          const SizedBox(width: 8),
                          _StatPill(
                            label: 'Compras',
                            value: _totalPurchases.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatPill(
                              label: 'Recaudado',
                              value: _formatMoney(_totalRevenue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, cédula, ciudad o email',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () => _searchCtrl.clear(),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null) ...[
                  ErrorMessage(text: _error!),
                  const SizedBox(height: 14),
                ],
                if (_loading) ...[
                  const AppCard(
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Cargando clientes...',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_clients.isEmpty) ...[
                  const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No hay clientes registrados',
                    subtitle:
                        'Cuando existan clientes en la API, aparecerán aquí.',
                  ),
                ] else ...[
                  if (topClients.isNotEmpty) ...[
                    _TopClientsBarChart(items: topClients.take(5).toList()),
                    const SizedBox(height: 14),
                  ],
                  ...visibleClients.map((client) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ClientTile(client: client),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Map<String, dynamic> client;

  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    final fullName = (client['fullName'] ?? 'Sin nombre').toString();
    final email = (client['email'] ?? 'Sin email').toString();
    final phone = (client['phone'] ?? 'Sin teléfono').toString();
    final city = (client['address'] ?? 'Sin ciudad').toString();
    final cedula = (client['cedula'] ?? 'Sin cédula').toString();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFFFEDD5),
            child: Text(
              fullName.isEmpty ? '?' : fullName[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cedula,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniChip(icon: Icons.location_on_outlined, label: city),
                    _MiniChip(icon: Icons.phone_outlined, label: phone),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopClientsBarChart extends StatelessWidget {
  final List<_ClientPurchaseMetric> items;

  const _TopClientsBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxPurchases = math.max(
      1,
      items.fold<int>(0, (maxValue, item) => math.max(maxValue, item.purchases)),
    );

    const barColors = [
      Color(0xFF315DDB),
      Color(0xFFD3D7E2),
      Color(0xFF2B7A6C),
      Color(0xFFC33DA7),
      Color(0xFF7A8397),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070B1F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1A2443)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top de clientes que más compran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Top 5 por número de compras',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final ratio = (item.purchases / maxPurchases).clamp(0.0, 1.0);
            final barColor = barColors[index % barColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available = constraints.maxWidth;
                  final nameWidth = (available * 0.34).clamp(120.0, 170.0);
                  final valueWidth = 28.0;
                    final barWidth =
                      math.max(available - nameWidth - valueWidth - 12, 80)
                        .toDouble();

                  return Row(
                    children: [
                      SizedBox(
                        width: nameWidth,
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFA8B3D0),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: barWidth,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Positioned.fill(
                              child: Row(
                                children: List.generate(
                                  4,
                                  (i) => Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 1,
                                        color: const Color(0xFF27335A),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF141B38),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: ratio,
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: valueWidth,
                        child: Text(
                          '${item.purchases}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFFCFD8ED),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ClientPurchaseMetric {
  final String id;
  final String name;
  final double totalSpent;
  final int purchases;

  const _ClientPurchaseMetric({
    required this.id,
    required this.name,
    required this.totalSpent,
    required this.purchases,
  });

  _ClientPurchaseMetric copyWith({
    String? id,
    String? name,
    double? totalSpent,
    int? purchases,
  }) {
    return _ClientPurchaseMetric(
      id: id ?? this.id,
      name: name ?? this.name,
      totalSpent: totalSpent ?? this.totalSpent,
      purchases: purchases ?? this.purchases,
    );
  }
}

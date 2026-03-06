import 'package:flutter/material.dart';

import '../models/product_dto.dart';
import '../services/products_service.dart';
import '../ui/app_widgets.dart';
import 'product_form_screen.dart';

const Color kInk = Color(0xFF1F2937);
const Color kSubtleText = Color(0xFF6B7280);
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFFFF4D8D), Color(0xFFFF7A45)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductsService _service = ProductsService();

  List<ProductDTO> _items = [];
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  _CatalogFilter _filter = _CatalogFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.list();
      if (!mounted) return;

      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );

    if (created == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto creado correctamente')),
      );
    }
  }

  Future<void> _openEdit(ProductDTO item) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: item),
      ),
    );

    if (updated == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto actualizado correctamente')),
      );
    }
  }

  Future<void> _deleteProduct(ProductDTO item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Deseas eliminar "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deleting = true);

    try {
      await _service.delete(item.id);
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Producto "${item.name}" eliminado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _showProductDetail(ProductDTO item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductHeroImage(
                    imageUrl: item.imageUrl,
                    height: 220,
                    gradient: kPrimaryGradient,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.business_outlined,
                        label: item.brandName.isEmpty
                            ? 'Sin marca'
                            : item.brandName,
                      ),
                      _MetaChip(
                        icon: Icons.sell_outlined,
                        label: item.sku == null || item.sku!.trim().isEmpty
                            ? 'SKU no definido'
                            : 'SKU: ${item.sku}',
                      ),
                      _MetaChip(
                        icon: Icons.category_outlined,
                        label: _genderLabel(item.gender),
                      ),
                      _MetaChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stock: ${item.stock}',
                      ),
                      _MetaChip(
                        icon: Icons.warning_amber_rounded,
                        label: 'Mínimo: ${item.minStock}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description == null || item.description!.trim().isEmpty
                        ? 'Sin descripción registrada.'
                        : item.description!,
                    style: const TextStyle(
                      height: 1.45,
                      color: kSubtleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _openEdit(item);
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _deleting
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  await _deleteProduct(item);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFBE123C),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<ProductDTO> get _filteredItems {
    switch (_filter) {
      case _CatalogFilter.all:
        return _items;
      case _CatalogFilter.male:
        return _items.where((e) => _isMale(e.gender)).toList();
      case _CatalogFilter.female:
        return _items.where((e) => _isFemale(e.gender)).toList();
      case _CatalogFilter.unisex:
        return _items.where((e) => _isUnisex(e.gender)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catálogos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Administra tus perfumes por tipo de catálogo.',
                        style: TextStyle(
                          color: kSubtleText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChipButton(
                            label: 'Todos',
                            selected: _filter == _CatalogFilter.all,
                            onTap: () => setState(
                              () => _filter = _CatalogFilter.all,
                            ),
                          ),
                          _FilterChipButton(
                            label: 'Masculino',
                            selected: _filter == _CatalogFilter.male,
                            onTap: () => setState(
                              () => _filter = _CatalogFilter.male,
                            ),
                          ),
                          _FilterChipButton(
                            label: 'Femenino',
                            selected: _filter == _CatalogFilter.female,
                            onTap: () => setState(
                              () => _filter = _CatalogFilter.female,
                            ),
                          ),
                          _FilterChipButton(
                            label: 'Unisex',
                            selected: _filter == _CatalogFilter.unisex,
                            onTap: () => setState(
                              () => _filter = _CatalogFilter.unisex,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_error != null)
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              children: [
                                AppCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Color(0xFF9F1239),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Color(0xFF9F1239),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            )
                          : visibleItems.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    AppCard(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 42,
                                            color: kSubtleText,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _emptyTitle(_filter),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: kInk,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Agrega un producto nuevo o cambia el filtro del catálogo.',
                                            style: TextStyle(
                                              color: kSubtleText,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 14),
                                          ElevatedButton.icon(
                                            onPressed: _openCreate,
                                            icon: const Icon(Icons.add),
                                            label: const Text('Nuevo producto'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    110,
                                  ),
                                  itemCount: visibleItems.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, i) {
                                    final item = visibleItems[i];
                                    return _ProductCard(
                                      item: item,
                                      deleting: _deleting,
                                      onTap: () => _showProductDetail(item),
                                      onDelete: () => _deleteProduct(item),
                                      onEdit: () => _openEdit(item),
                                      gradient: kPrimaryGradient,
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CatalogFilter { all, male, female, unisex }

class _ProductCard extends StatelessWidget {
  final ProductDTO item;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Gradient gradient;

  const _ProductCard({
    required this.item,
    required this.deleting,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.gradient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final skuText = (item.sku == null || item.sku!.trim().isEmpty)
        ? 'SKU no definido'
        : 'SKU: ${item.sku}';

    final descText =
        (item.description == null || item.description!.trim().isEmpty)
            ? 'Sin descripción'
            : item.description!.trim();

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductThumb(imageUrl: item.imageUrl, gradient: gradient),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: kInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: kInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.brandName.isEmpty ? "Sin marca" : item.brandName} • ${_genderLabel(item.gender)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kSubtleText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skuText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kSubtleText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    descText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kSubtleText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SmallInfoPill(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stock ${item.stock}',
                      ),
                      const SizedBox(width: 8),
                      _SmallInfoPill(
                        icon: Icons.warning_amber_rounded,
                        label: 'Min ${item.minStock}',
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: deleting ? null : onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final Gradient gradient;

  const _ProductThumb({
    required this.imageUrl,
    required this.gradient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: gradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _ImageFallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            )
          : const _ImageFallback(),
    );
  }
}

class _ProductHeroImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final Gradient gradient;

  const _ProductHeroImage({
    required this.imageUrl,
    required this.height,
    required this.gradient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: gradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _ImageFallback(big: true),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            )
          : const _ImageFallback(big: true),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final bool big;

  const _ImageFallback({this.big = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.local_mall_outlined,
        size: big ? 56 : 28,
        color: Colors.white,
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFFFE4EC),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFBE123C) : kInk,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFFFF4D8D) : const Color(0xFFE5E7EB),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SmallInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallInfoPill({
    required this.icon,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kSubtleText),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kSubtleText,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kSubtleText),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
        ],
      ),
    );
  }
}

String _genderLabel(String? gender) {
  final g = (gender ?? '').trim().toUpperCase();

  if (g.isEmpty) return 'Sin género';
  if (g == 'M' || g == 'MEN' || g == 'MASCULINO' || g == 'MALE') {
    return 'Masculino';
  }
  if (g == 'F' || g == 'WOMEN' || g == 'FEMENINO' || g == 'FEMALE') {
    return 'Femenino';
  }
  if (g == 'U' || g == 'UNISEX') {
    return 'Unisex';
  }

  return gender!;
}

bool _isMale(String? gender) {
  final g = (gender ?? '').trim().toUpperCase();
  return g == 'M' || g == 'MEN' || g == 'MASCULINO' || g == 'MALE';
}

bool _isFemale(String? gender) {
  final g = (gender ?? '').trim().toUpperCase();
  return g == 'F' || g == 'WOMEN' || g == 'FEMENINO' || g == 'FEMALE';
}

bool _isUnisex(String? gender) {
  final g = (gender ?? '').trim().toUpperCase();
  return g == 'U' || g == 'UNISEX';
}

String _emptyTitle(_CatalogFilter filter) {
  switch (filter) {
    case _CatalogFilter.all:
      return 'Aún no hay productos registrados';
    case _CatalogFilter.male:
      return 'No hay productos en catálogo masculino';
    case _CatalogFilter.female:
      return 'No hay productos en catálogo femenino';
    case _CatalogFilter.unisex:
      return 'No hay productos en catálogo unisex';
  }
}

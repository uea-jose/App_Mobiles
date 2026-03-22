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
  final ScrollController _filterScrollController = ScrollController();

  List<ProductDTO> _items = [];
  bool _loading = true;
  bool _deleting = false;
  bool _showLeftFilterCue = false;
  bool _showRightFilterCue = false;
  String? _error;

  _CatalogFilter _filter = _CatalogFilter.all;

  @override
  void initState() {
    super.initState();
    _filterScrollController.addListener(_updateFilterScrollCues);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFilterScrollCues();
    });
    _load();
  }

  @override
  void dispose() {
    _filterScrollController
      ..removeListener(_updateFilterScrollCues)
      ..dispose();
    super.dispose();
  }

  void _updateFilterScrollCues() {
    if (!mounted || !_filterScrollController.hasClients) return;

    final pos = _filterScrollController.position;
    final left = pos.pixels > 2;
    final right = pos.pixels < (pos.maxScrollExtent - 2);

    if (left != _showLeftFilterCue || right != _showRightFilterCue) {
      setState(() {
        _showLeftFilterCue = left;
        _showRightFilterCue = right;
      });
    }
  }

  void _setFilter(_CatalogFilter value) {
    if (_filter == value) return;
    setState(() {
      _filter = value;
    });
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
    final createdMessage = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );

    if (createdMessage != null && createdMessage.trim().isNotEmpty) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(createdMessage)),
      );
    }
  }

  Future<void> _openEdit(ProductDTO item) async {
    final updatedMessage = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: item),
      ),
    );

    if (updatedMessage != null && updatedMessage.trim().isNotEmpty) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updatedMessage)),
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
                        backgroundColor: _stockBackgroundColor(item.stock),
                        borderColor: _stockBorderColor(item.stock),
                        iconColor: _stockTextColor(item.stock),
                        textColor: _stockTextColor(item.stock),
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

  int get _activeFilterIndex {
    switch (_filter) {
      case _CatalogFilter.all:
        return 0;
      case _CatalogFilter.male:
        return 1;
      case _CatalogFilter.female:
        return 2;
      case _CatalogFilter.unisex:
        return 3;
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
                child: Column(
                  children: [
                    AppPageHeader(
                      icon: Icons.local_mall_outlined,
                      title: 'Productos',
                      subtitle: 'Gestiona tu catálogo por tipo de fragancia',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          '${visibleItems.length}/${_items.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro activo: ${_catalogFilterLabel(_filter)}',
                            style: const TextStyle(
                              color: kSubtleText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Desliza para explorar categorías',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              SizedBox(
                                height: 44,
                                child: ListView(
                                  controller: _filterScrollController,
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  children: [
                                    _FilterChipButton(
                                      label: 'Todos',
                                      selected: _filter == _CatalogFilter.all,
                                      onTap: () =>
                                          _setFilter(_CatalogFilter.all),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChipButton(
                                      label: 'Masculino',
                                      selected: _filter == _CatalogFilter.male,
                                      onTap: () =>
                                          _setFilter(_CatalogFilter.male),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChipButton(
                                      label: 'Femenino',
                                      selected:
                                          _filter == _CatalogFilter.female,
                                      onTap: () =>
                                          _setFilter(_CatalogFilter.female),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChipButton(
                                      label: 'Unisex',
                                      selected:
                                          _filter == _CatalogFilter.unisex,
                                      onTap: () =>
                                          _setFilter(_CatalogFilter.unisex),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                ),
                              ),
                              if (_showLeftFilterCue)
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 22,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xFFFFFFFF),
                                            Color(0x00FFFFFF)
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_showRightFilterCue)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 22,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0x00FFFFFF),
                                            Color(0xFFFFFFFF)
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final active = index == _activeFilterIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                height: 6,
                                width: active ? 18 : 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFFFF4D8D)
                                      : const Color(0xFFD1D5DB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                                    AppEmptyState(
                                      icon: Icons.inventory_2_outlined,
                                      title: _emptyTitle(_filter),
                                      subtitle:
                                          'Agrega un producto nuevo o cambia el filtro del catálogo.',
                                      actionText: 'Nuevo producto',
                                      onAction: _openCreate,
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
                        backgroundColor: _stockBackgroundColor(item.stock),
                        borderColor: _stockBorderColor(item.stock),
                        iconColor: _stockTextColor(item.stock),
                        textColor: _stockTextColor(item.stock),
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

  const _ImageFallback({this.big = false});

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
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  const _SmallInfoPill({
    required this.icon,
    required this.label,
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.borderColor = const Color(0xFFE5E7EB),
    this.iconColor = kSubtleText,
    this.textColor = kSubtleText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
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
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.borderColor = const Color(0xFFE5E7EB),
    this.iconColor = kSubtleText,
    this.textColor = kInk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

Color _stockBackgroundColor(int stock) {
  if (stock >= 7) return const Color(0xFFECFDF5);
  if (stock >= 4) return const Color(0xFFFFFBEB);
  return const Color(0xFFFEF2F2);
}

Color _stockBorderColor(int stock) {
  if (stock >= 7) return const Color(0xFF86EFAC);
  if (stock >= 4) return const Color(0xFFFCD34D);
  return const Color(0xFFFCA5A5);
}

Color _stockTextColor(int stock) {
  if (stock >= 7) return const Color(0xFF166534);
  if (stock >= 4) return const Color(0xFFB45309);
  return const Color(0xFFB91C1C);
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

String _catalogFilterLabel(_CatalogFilter filter) {
  switch (filter) {
    case _CatalogFilter.all:
      return 'Todos';
    case _CatalogFilter.male:
      return 'Masculino';
    case _CatalogFilter.female:
      return 'Femenino';
    case _CatalogFilter.unisex:
      return 'Unisex';
  }
}

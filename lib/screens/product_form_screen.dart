import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import '../models/brand.dart';
import '../models/product_dto.dart';
import '../services/api_client.dart';
import '../services/brand_services.dart';
import '../services/perfume_options_service.dart';
import '../services/products_service.dart';
import '../ui/app_widgets.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductDTO? product;

  const ProductFormScreen({super.key, this.product});

  bool get isEdit => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _service = ProductsService();
  final _brandService = BrandService();
  final _perfumeOptionsService = PerfumeOptionsService();
  final _formKey = GlobalKey<FormState>();
  late final FixedExtentScrollController _galleryController;

  final _sku = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '0');
  final _description = TextEditingController();
  final _imageUrl = TextEditingController();

  String? _gender;
  bool _saving = false;
  String? _error;
  int _galleryPageIndex = 0;

  bool _loadingBrands = true;
  String? _brandsError;
  List<Brand> _brands = [];
  Brand? _selectedBrand;

  bool _loadingPerfumeOptions = false;
  String? _perfumeOptionsError;
  List<PerfumeOption> _perfumeOptions = [];
  PerfumeOption? _selectedPerfumeOption;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _galleryController = FixedExtentScrollController(initialItem: 0);
    _fillInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBrands();
      _loadPerfumeOptions();
    });
  }

  void _fillInitialData() {
    final p = widget.product;
    if (p == null) return;

    _sku.text = p.sku ?? '';
    _name.text = p.name;
    _price.text = p.price.toStringAsFixed(2);
    _stock.text = p.stock.toString();
    _minStock.text = p.minStock.toString();
    _description.text = p.description ?? '';
    _imageUrl.text = p.imageUrl ?? '';
    _gender = p.gender;
  }

  Future<void> _loadBrands({
    String? preferredBrandId,
    String? preferredBrandName,
  }) async {
    try {
      final data = await _brandService.list();

      if (!mounted) return;

      Brand? selected;
      final normalizedPreferred = _normalizeBrandName(preferredBrandName);

      if (preferredBrandId != null && preferredBrandId.trim().isNotEmpty) {
        for (final b in data) {
          if (b.id == preferredBrandId.trim()) {
            selected = b;
            break;
          }
        }
      }

      if (selected == null && normalizedPreferred != null) {
        for (final b in data) {
          if (_normalizeBrandName(b.name) == normalizedPreferred) {
            selected = b;
            break;
          }
        }
      }

      if (selected == null && _selectedBrand != null) {
        for (final b in data) {
          if (b.id == _selectedBrand!.id) {
            selected = b;
            break;
          }
        }
      }

      if (selected == null && _isEdit) {
        final productBrandId = widget.product!.brandId;
        for (final b in data) {
          if (b.id == productBrandId) {
            selected = b;
            break;
          }
        }
      }

      setState(() {
        _brands = data;
        _selectedBrand = selected;
        _loadingBrands = false;
        _brandsError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _brandsError = e.toString().replaceAll('Exception: ', '');
        _loadingBrands = false;
      });
    }
  }

  String? _normalizeBrandName(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _loadPerfumeOptions() async {
    if (_isEdit) return;

    setState(() {
      _loadingPerfumeOptions = true;
      _perfumeOptionsError = null;
    });

    try {
      final data = await _perfumeOptionsService.listOptions();

      if (!mounted) return;

      setState(() {
        _perfumeOptions = data;
        _galleryPageIndex = 0;
        _selectedPerfumeOption = null;
        _loadingPerfumeOptions = false;
        _perfumeOptionsError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _perfumeOptionsError =
            e.toString().replaceAll('Exception: ', '').trim();
        _loadingPerfumeOptions = false;
      });
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _sku.dispose();
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _minStock.dispose();
    _description.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  double _toDouble(String v) {
    final normalized = v.replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }

  int _toInt(String v) {
    return int.tryParse(v.trim()) ?? 0;
  }

  String? _normalizeGenderOption(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return null;

    if (v == 'F' ||
        v == 'WOMAN' ||
        v == 'WOMEN' ||
        v == 'FEMENINO' ||
        v == 'FEMALE') {
      return 'FEMENINO';
    }

    if (v == 'M' ||
        v == 'MAN' ||
        v == 'MEN' ||
        v == 'MASCULINO' ||
        v == 'MALE') {
      return 'MASCULINO';
    }

    if (v == 'U' || v == 'UNISEX') {
      return 'UNISEX';
    }

    return null;
  }

  void _syncGalleryPosition(int index) {
    if (!_galleryController.hasClients) return;
    if (_galleryController.selectedItem == index) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_galleryController.hasClients) return;
      _galleryController.jumpToItem(index);
    });
  }

  List<PerfumeOption> get _filteredPerfumeOptions {
    if (_isEdit) return _perfumeOptions;
    if (_selectedBrand == null) return const [];

    final selectedBrandName = _selectedBrand!.name.trim().toLowerCase();
    if (selectedBrandName.isEmpty) return const [];

    final filtered = _perfumeOptions.where((option) {
      final optionBrand = (option.brand ?? '').trim().toLowerCase();
      return optionBrand.isNotEmpty && optionBrand == selectedBrandName;
    }).toList();

    return filtered;
  }

  void _applyPerfumeOption(PerfumeOption option) {
    setState(() {
      _selectedPerfumeOption = option;
      _name.text = option.name;

      if ((option.imageUrl ?? '').trim().isNotEmpty) {
        _imageUrl.text = option.imageUrl!.trim();
      }

      if (_sku.text.trim().isEmpty && (option.sku ?? '').trim().isNotEmpty) {
        _sku.text = option.sku!.trim();
      }

      if (_description.text.trim().isEmpty &&
          (option.description ?? '').trim().isNotEmpty) {
        _description.text = option.description!.trim();
      }

      final normalizedGender = _normalizeGenderOption(option.gender);
      if (normalizedGender != null) {
        _gender = normalizedGender;
      }
    });
  }

  Future<void> _openCreateBrandModal() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final countryController = TextEditingController();
    bool saving = false;

    final created = await showModalBottomSheet<Brand>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Agregar casa fabricante',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return 'Ingresa el nombre de la casa fabricante';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: countryController,
                      decoration: const InputDecoration(
                        labelText: 'País (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(modalContext),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    if (!(formKey.currentState?.validate() ??
                                        false)) {
                                      return;
                                    }

                                    setModalState(() {
                                      saving = true;
                                    });

                                    try {
                                      final result = await _brandService
                                          .findOrCreateByName(
                                        name: nameController.text,
                                        country: countryController.text,
                                      );

                                      if (!mounted || !modalContext.mounted) {
                                        return;
                                      }

                                      Navigator.pop(modalContext, result.brand);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result.created
                                                ? 'Casa fabricante creada'
                                                : 'Casa fabricante ya existente seleccionada',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted || !modalContext.mounted) {
                                        return;
                                      }

                                      setModalState(() {
                                        saving = false;
                                      });

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            e
                                                .toString()
                                                .replaceAll('Exception: ', '')
                                                .trim(),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              saving ? 'Guardando...' : 'Guardar',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    countryController.dispose();

    if (created == null || !mounted) return;

    await _loadBrands(preferredBrandId: created.id);
  }

  String _apiHost() {
    final apiUri = Uri.tryParse(ApiClient.baseUrl);
    if (apiUri != null && apiUri.host.isNotEmpty) {
      return apiUri.host;
    }
    return '10.0.2.2';
  }

  String _apiOrigin() {
    final apiUri = Uri.tryParse(ApiClient.baseUrl);
    if (apiUri != null && apiUri.hasScheme && apiUri.host.isNotEmpty) {
      return apiUri.origin;
    }
    return 'http://${_apiHost()}:3000';
  }

  bool _isLocalOnlyHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == '127.0.0.1' ||
        normalized == 'localhost' ||
        normalized == '10.0.2.2' ||
        normalized == '10.0.3.2';
  }

  String? _normalizeSingleImageUrl(String raw) {
    final trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('data:image/')) return trimmed;

    final apiOrigin = _apiOrigin();
    final apiHost = _apiHost();

    if (trimmed.startsWith('/')) {
      return Uri.encodeFull('$apiOrigin$trimmed');
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final path = trimmed.startsWith('./') ? trimmed.substring(2) : trimmed;
      return Uri.encodeFull(
          '$apiOrigin/${path.startsWith('/') ? path.substring(1) : path}');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return Uri.encodeFull(trimmed);

    if (_isLocalOnlyHost(uri.host)) {
      return Uri.encodeFull(
        uri
            .replace(
              host: apiHost,
              port: uri.hasPort ? uri.port : null,
            )
            .toString(),
      );
    }

    return Uri.encodeFull(trimmed);
  }

  List<String> _imageUrlCandidates(String raw) {
    final normalized = _normalizeSingleImageUrl(raw);
    if (normalized == null || normalized.isEmpty) return const [];

    final candidates = <String>[normalized];

    final uri = Uri.tryParse(normalized);
    final apiOrigin = _apiOrigin();

    if (uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        uri.path == '/api/external-image') {
      return candidates;
    }

    if (uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        !_isLocalOnlyHost(uri.host)) {
      return candidates;
    }

    if (normalized.startsWith('/static/')) {
      final extra = Uri.encodeFull('$apiOrigin$normalized');
      if (!candidates.contains(extra)) {
        candidates.add(extra);
      }
    }

    return candidates;
  }

  String _previewImageUrl(String raw) {
    final candidates = _imageUrlCandidates(raw);
    return candidates.isEmpty ? '' : candidates.first;
  }

  Widget _buildWheelItem(PerfumeOption option, {required bool isSelected}) {
    final imageUrls = _imageUrlCandidates(option.imageUrl ?? '');

    return Center(
      child: AnimatedContainer(
        key: ValueKey('wheel-item-${option.id}-$isSelected'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: isSelected ? 92 : 68,
        height: isSelected ? 92 : 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSelected ? 18 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.10 : 0.04),
              blurRadius: isSelected ? 18 : 8,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color:
                isSelected ? const Color(0xFFFF4D8D) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 16 : 11),
          child: imageUrls.isNotEmpty
              ? _ResilientNetworkImage(
                  key: ValueKey('wheel-image-${option.id}'),
                  imageUrls: imageUrls,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  loading: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  fallback: Container(
                    color: const Color(0xFFF9FAFB),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported_outlined,
                          size: 24,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            option.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFFF9FAFB),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      option.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPerfumeThumbnail(
    PerfumeOption option, {
    double size = 40,
    double radius = 10,
  }) {
    final imageUrls = _imageUrlCandidates(option.imageUrl ?? '');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: imageUrls.isNotEmpty
            ? _ResilientNetworkImage(
                key: ValueKey('thumb-image-${option.id}-$size-$radius'),
                imageUrls: imageUrls,
                fit: BoxFit.cover,
                loading: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                fallback: const Icon(
                  Icons.local_mall_outlined,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              )
            : const Icon(
                Icons.local_mall_outlined,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedBrand == null) {
      setState(() => _error = 'Selecciona una casa fabricante');
      return;
    }

    setState(() => _saving = true);

    try {
      final sku = _sku.text.trim().isEmpty ? null : _sku.text.trim();
      final description =
          _description.text.trim().isEmpty ? null : _description.text.trim();
      final imageUrl =
          _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim();
      final name = _name.text.trim();
      final price = _toDouble(_price.text);
      final stock = _toInt(_stock.text);
      final minStock = _toInt(_minStock.text);

      if (_isEdit) {
        final product = widget.product!;

        await _service.update(
          id: product.id,
          sku: sku,
          name: name,
          brandId: _selectedBrand!.id,
          gender: _gender,
          description: description,
          price: price,
          imageUrl: imageUrl,
          isActive: true,
        );

        await _service.setInventory(
          productId: product.id,
          stock: stock,
          minStock: minStock,
        );
      } else {
        await _service.create(
          sku: sku,
          name: name,
          brandId: _selectedBrand!.id,
          gender: _gender,
          description: description,
          price: price,
          imageUrl: imageUrl,
          stock: stock,
          minStock: minStock,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePreviewUrl =
        _imageUrl.text.trim().isEmpty ? '' : _previewImageUrl(_imageUrl.text);
    final visiblePerfumeOptions = _filteredPerfumeOptions;
    final selectedImageRaw =
        (_selectedPerfumeOption?.imageUrl ?? '').trim().isNotEmpty
            ? _selectedPerfumeOption!.imageUrl!
            : _imageUrl.text;
    final selectedPreviewUrls = _imageUrlCandidates(selectedImageRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar producto' : 'Ingresar producto'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (_error != null) ...[
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFF9F1239),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (!_isEdit) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Casa fabricante',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingBrands)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          )
                        else if (_brandsError != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _brandsError!,
                                style: const TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _loadingBrands = true;
                                    _brandsError = null;
                                  });
                                  _loadBrands();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar cargar casas'),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownSearch<Brand>(
                                items: _brands,
                                selectedItem: _selectedBrand,
                                compareFn: (item, selected) =>
                                    item.id == selected.id,
                                itemAsString: (Brand b) {
                                  final country = (b.country ?? '').trim();
                                  return country.isEmpty
                                      ? b.name
                                      : '${b.name} • $country';
                                },
                                popupProps: const PopupProps.menu(
                                  showSearchBox: true,
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: 'Buscar casa fabricante',
                                    ),
                                  ),
                                ),
                                dropdownDecoratorProps:
                                    const DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    labelText: 'Casa fabricante *',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                onChanged: (Brand? b) {
                                  final changed = _selectedBrand?.id != b?.id;

                                  setState(() {
                                    _selectedBrand = b;
                                  });

                                  if (changed) {
                                    setState(() {
                                      _selectedPerfumeOption = null;
                                      _galleryPageIndex = 0;
                                      _imageUrl.clear();
                                    });
                                    _syncGalleryPosition(0);
                                  }
                                },
                                validator: (Brand? b) {
                                  if (b == null) {
                                    return 'Selecciona una casa fabricante';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed:
                                      _saving ? null : _openCreateBrandModal,
                                    icon:
                                        const Icon(Icons.add_business_outlined),
                                    label: const Text(
                                      'Agregar casa fabricante',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Perfume (opcional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_selectedBrand == null)
                          DropdownSearch<PerfumeOption>(
                            items: const [],
                            selectedItem: null,
                            enabled: false,
                            itemAsString: (PerfumeOption p) => p.name,
                            popupProps: const PopupProps.menu(
                              showSearchBox: true,
                            ),
                            dropdownDecoratorProps:
                                const DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: 'Perfume sugerido (opcional)',
                                hintText:
                                    'Primero elige una casa fabricante',
                              ),
                            ),
                          )
                        else if (_loadingPerfumeOptions)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          )
                        else if (_perfumeOptionsError != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'No se pudieron cargar sugerencias de perfumes.',
                                style: TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _perfumeOptionsError!,
                                style: const TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _loadPerfumeOptions,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar sugerencias'),
                              ),
                            ],
                          )
                        else if (visiblePerfumeOptions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: const Text(
                              'No hay perfumes sugeridos para esta casa. Puedes ingresar los datos manualmente.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          DropdownSearch<PerfumeOption>(
                            items: visiblePerfumeOptions,
                            selectedItem: _selectedPerfumeOption,
                            compareFn: (item, selected) =>
                                (item.id) == (selected.id),
                            itemAsString: (PerfumeOption p) => p.name,
                            dropdownBuilder: (context, selectedItem) {
                              if (selectedItem == null) {
                                return const Text('Selecciona un perfume');
                              }

                              final selectedOption = selectedItem;

                              return Row(
                                children: [
                                  _buildPerfumeThumbnail(selectedOption),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedOption.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              itemBuilder: (context, item, isSelected) {
                                final option = item;
                                return ListTile(
                                  dense: true,
                                  leading: _buildPerfumeThumbnail(
                                    option,
                                    size: 36,
                                    radius: 8,
                                  ),
                                  title: Text(
                                    option.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                            dropdownDecoratorProps:
                                const DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: 'Perfume sugerido (opcional)',
                                hintText:
                                    'Busca por nombre (autocompleta datos)',
                              ),
                            ),
                            onChanged: (PerfumeOption? option) {
                              if (option == null) return;

                              final idx = visiblePerfumeOptions.indexWhere(
                                (item) => item.id == option.id,
                              );
                              if (idx >= 0) {
                                setState(() {
                                  _galleryPageIndex = idx;
                                });
                                _syncGalleryPosition(idx);
                              }

                              _applyPerfumeOption(option);
                            },
                          ),
                        if (_selectedBrand != null &&
                          visiblePerfumeOptions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.95, end: 1.0)
                                      .animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: ClipRRect(
                              key: ValueKey(
                                _selectedPerfumeOption?.id ?? 'placeholder',
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                height: 220,
                                color: Colors.white,
                                child: selectedPreviewUrls.isNotEmpty
                                    ? _ResilientNetworkImage(
                                        key: ValueKey(
                                          'hero-${_selectedPerfumeOption?.id ?? imagePreviewUrl}',
                                        ),
                                        imageUrls: selectedPreviewUrls,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        loading: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        fallback: const Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 64,
                                            color: Color(0xFFD1D5DB),
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.local_mall_outlined,
                                          size: 64,
                                          color: Color(0xFFD1D5DB),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 132,
                            child: ListWheelScrollView(
                              controller: _galleryController,
                              itemExtent: 88,
                              diameterRatio: 1.45,
                              useMagnifier: true,
                              magnification: 1.14,
                              overAndUnderCenterOpacity: 0.45,
                              squeeze: 0.92,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (newIndex) {
                                setState(() {
                                  _galleryPageIndex = newIndex;
                                });

                                if (newIndex < visiblePerfumeOptions.length) {
                                  _applyPerfumeOption(
                                    visiblePerfumeOptions[newIndex],
                                  );
                                }
                              },
                              children: List.generate(
                                visiblePerfumeOptions.length,
                                (index) {
                                  final option = visiblePerfumeOptions[index];
                                  return _buildWheelItem(
                                    option,
                                    isSelected: index == _galleryPageIndex,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              '${_selectedPerfumeOption?.name ?? 'Seleccionar'} • ${_galleryPageIndex + 1} de ${visiblePerfumeOptions.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                      ],
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del producto *',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      if (_isEdit && _loadingBrands)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        )
                      else if (_isEdit && _brandsError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _brandsError!,
                              style: const TextStyle(
                                color: Color(0xFF9F1239),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _loadingBrands = true;
                                  _brandsError = null;
                                });
                                _loadBrands();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar cargar casas'),
                            ),
                          ],
                        )
                      else if (_isEdit)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownSearch<Brand>(
                              items: _brands,
                              selectedItem: _selectedBrand,
                              compareFn: (item, selected) =>
                                  item.id == selected.id,
                              itemAsString: (Brand b) {
                                final country = (b.country ?? '').trim();
                                return country.isEmpty
                                    ? b.name
                                    : '${b.name} • $country';
                              },
                              popupProps: const PopupProps.menu(
                                showSearchBox: true,
                              ),
                              dropdownDecoratorProps:
                                  const DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: 'Casa fabricante *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              onChanged: (Brand? b) {
                                  setState(() {
                                    _selectedBrand = b;
                                  });
                              },
                              validator: (Brand? b) {
                                if (b == null) {
                                  return 'Selecciona una casa fabricante';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Spacer(),
                                TextButton.icon(
                                  onPressed:
                                      _saving ? null : _openCreateBrandModal,
                                  icon: const Icon(Icons.add_business_outlined),
                                  label: const Text('Agregar casa fabricante'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio *',
                        ),
                        validator: (v) {
                          final p = _toDouble(v ?? '');
                          if (p <= 0) return 'Precio inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _sku,
                        decoration: const InputDecoration(
                          labelText: 'SKU (opcional)',
                          hintText: 'Ej: DIOR-SAU-100',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Género (opcional)',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FEMENINO',
                            child: Text('Femenino'),
                          ),
                          DropdownMenuItem(
                            value: 'MASCULINO',
                            child: Text('Masculino'),
                          ),
                          DropdownMenuItem(
                            value: 'UNISEX',
                            child: Text('Unisex'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (imagePreviewUrl.isNotEmpty)
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _ResilientNetworkImage(
                            key: ValueKey('form-preview-$imagePreviewUrl'),
                            imageUrls: _imageUrlCandidates(_imageUrl.text),
                            fit: BoxFit.cover,
                            loading: const Center(
                              child: CircularProgressIndicator(),
                            ),
                            fallback: const Center(
                              child: Text(
                                'No se pudo cargar la imagen',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (imagePreviewUrl.isNotEmpty)
                        const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stock,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Stock',
                              ),
                              validator: (v) {
                                final n = _toInt(v ?? '0');
                                if (n < 0) return 'Inválido';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _minStock,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Stock mínimo',
                              ),
                              validator: (v) {
                                final n = _toInt(v ?? '0');
                                if (n < 0) return 'Inválido';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        text: _saving
                            ? (_isEdit
                                ? 'Guardando cambios...'
                                : 'Guardando...')
                            : (_isEdit ? 'Actualizar' : 'Guardar'),
                        onPressed: _saving ? null : _save,
                      ),
                    ],
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

class _ResilientNetworkImage extends StatefulWidget {
  final List<String> imageUrls;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget fallback;
  final Widget? loading;

  const _ResilientNetworkImage({
    super.key,
    required this.imageUrls,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.low,
    this.loading,
  });

  @override
  State<_ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<_ResilientNetworkImage> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant _ResilientNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.join('|') != widget.imageUrls.join('|')) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty || _index >= widget.imageUrls.length) {
      return widget.fallback;
    }

    final currentUrl = widget.imageUrls[_index];

    return Image.network(
      currentUrl,
      key: ValueKey(currentUrl),
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return widget.loading ?? widget.fallback;
      },
      errorBuilder: (context, error, stackTrace) {
        if (_index < widget.imageUrls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _index += 1;
            });
          });
          return widget.loading ?? widget.fallback;
        }
        return widget.fallback;
      },
    );
  }
}

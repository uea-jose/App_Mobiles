import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/brand.dart';
import '../models/product_dto.dart';
import '../services/api_client.dart';
import '../services/brand_services.dart';
import '../services/perfume_options_service.dart';
import '../services/products_service.dart';
import '../ui/app_widgets.dart';

enum _PerfumeInputMode { suggestions, manual }

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
  final _perfumeSearchController = TextEditingController();
  final _imageUrlInputController = TextEditingController();
  final _imagePicker = ImagePicker();

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
  String _perfumeSearch = '';
  String? _selectionMessage;
  bool _usingMockPerfumes = false;

  bool _loadingBrands = true;
  String? _brandsError;
  List<Brand> _brands = [];
  Brand? _selectedBrand;

  bool _loadingPerfumeOptions = false;
  String? _perfumeOptionsError;
  List<PerfumeOption> _perfumeOptions = [];
  PerfumeOption? _selectedPerfumeOption;
  _PerfumeInputMode _perfumeInputMode = _PerfumeInputMode.suggestions;

  bool get _isEdit => widget.product != null;

  void _showSnack(
    String message, {
    Color? backgroundColor,
  }) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
    });
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

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

    _sku.text = p.sku?.trim() ?? '';
    _name.text = p.name;
    _price.text = p.price.toStringAsFixed(2);
    _stock.text = p.stock.toString();
    _minStock.text = p.minStock.toString();
    _description.text = p.description ?? '';
    _imageUrl.text = p.imageUrl ?? '';
    _imageUrlInputController.text =
        _isDataImageSource(p.imageUrl ?? '') ? '' : (p.imageUrl ?? '');
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
    setState(() {
      _loadingPerfumeOptions = true;
      _perfumeOptionsError = null;
    });

    List<PerfumeOption> externalOptions = const [];
    List<PerfumeOption> localOptions = const [];
    String? externalError;
    String? localError;

    try {
      externalOptions = await _perfumeOptionsService.listOptions();
    } catch (e) {
      externalError = e.toString().replaceAll('Exception: ', '').trim();
    }

    try {
      final localProducts = await _service.list();
      localOptions = localProducts
          .where((product) => product.name.trim().isNotEmpty)
          .map(
            (product) => PerfumeOption(
              id: 'local-${product.id}',
              name: product.name.trim(),
              imageUrl: (product.imageUrl ?? '').trim().isEmpty
                  ? null
                  : product.imageUrl!.trim(),
              sku: (product.sku ?? '').trim().isEmpty
                  ? null
                  : product.sku!.trim(),
              description: (product.description ?? '').trim().isEmpty
                  ? null
                  : product.description!.trim(),
              brand: product.brandName.trim(),
              gender: product.gender,
            ),
          )
          .toList();
    } catch (e) {
      localError = e.toString().replaceAll('Exception: ', '').trim();
    }

    if (!mounted) return;

    final merged = _mergePerfumeOptions(externalOptions, localOptions);
    final resolvedError = merged.isEmpty
        ? (externalError ?? localError)
        : (externalError != null && localError != null
            ? '$externalError · $localError'
            : null);

    setState(() {
      _perfumeOptions = merged;
      _galleryPageIndex = 0;
      _selectedPerfumeOption = null;
      _loadingPerfumeOptions = false;
      _perfumeOptionsError = resolvedError;
      _usingMockPerfumes = false;
    });
  }

  String _normalizePerfumeKeyPart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _perfumeOptionKey(PerfumeOption option) {
    final brand = _normalizePerfumeKeyPart(option.brand ?? '');
    final name = _normalizePerfumeKeyPart(option.name);
    return '$brand|$name';
  }

  String _productDuplicateKey({
    required String brandId,
    required String brandName,
    required String name,
  }) {
    final normalizedBrandId = brandId.trim().toLowerCase();
    final normalizedBrandName = _normalizePerfumeKeyPart(brandName);
    final normalizedName = _normalizePerfumeKeyPart(name);
    return '$normalizedBrandId|$normalizedBrandName|$normalizedName';
  }

  Future<ProductDTO?> _findDuplicateProduct({
    required String brandId,
    required String brandName,
    required String name,
  }) async {
    final targetKey = _productDuplicateKey(
      brandId: brandId,
      brandName: brandName,
      name: name,
    );

    final products = await _service.list();

    for (final product in products) {
      final productKey = _productDuplicateKey(
        brandId: product.brandId,
        brandName: product.brandName,
        name: product.name,
      );

      if (productKey == targetKey) {
        return product;
      }
    }

    return null;
  }

  PerfumeOption _preferRicherPerfumeOption(
    PerfumeOption current,
    PerfumeOption candidate,
  ) {
    final currentScore = ((current.imageUrl ?? '').trim().isNotEmpty ? 1 : 0) +
        ((current.description ?? '').trim().isNotEmpty ? 1 : 0) +
        ((current.sku ?? '').trim().isNotEmpty ? 1 : 0) +
        ((current.gender ?? '').trim().isNotEmpty ? 1 : 0);
    final candidateScore =
        ((candidate.imageUrl ?? '').trim().isNotEmpty ? 1 : 0) +
            ((candidate.description ?? '').trim().isNotEmpty ? 1 : 0) +
            ((candidate.sku ?? '').trim().isNotEmpty ? 1 : 0) +
            ((candidate.gender ?? '').trim().isNotEmpty ? 1 : 0);

    if (candidateScore > currentScore) return candidate;
    return current;
  }

  List<PerfumeOption> _mergePerfumeOptions(
    List<PerfumeOption> external,
    List<PerfumeOption> local,
  ) {
    final merged = <String, PerfumeOption>{};

    for (final option in [...external, ...local]) {
      final key = _perfumeOptionKey(option);
      if (key.trim() == '|') continue;

      final existing = merged[key];
      if (existing == null) {
        merged[key] = option;
      } else {
        merged[key] = _preferRicherPerfumeOption(existing, option);
      }
    }

    return merged.values.toList()
      ..sort((a, b) {
        final brandCompare = (a.brand ?? '').compareTo(b.brand ?? '');
        if (brandCompare != 0) return brandCompare;
        return a.name.compareTo(b.name);
      });
  }

  void _loadMockPerfumeOptions() {
    setState(() {
      _perfumeOptions = const [
        PerfumeOption(
          id: 'mock-1',
          name: 'Sauvage Elixir',
          brand: 'Dior',
          gender: 'MASCULINO',
          description: 'Amaderado especiado intenso.',
          sku: 'DIOR-SAU-ELX',
          imageUrl:
              'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=600',
        ),
        PerfumeOption(
          id: 'mock-2',
          name: 'J\'adore Eau de Parfum',
          brand: 'Dior',
          gender: 'FEMENINO',
          description: 'Floral elegante y brillante.',
          sku: 'DIOR-JAD-EDP',
          imageUrl:
              'https://images.unsplash.com/photo-1541643600914-78b084683601?w=600',
        ),
        PerfumeOption(
          id: 'mock-3',
          name: 'La Vie Est Belle',
          brand: 'Lancôme',
          gender: 'FEMENINO',
          description: 'Dulce gourmand con iris.',
          sku: 'LAN-LVEB-EDP',
          imageUrl:
              'https://images.unsplash.com/photo-1615634262417-58f34b6f9c76?w=600',
        ),
        PerfumeOption(
          id: 'mock-4',
          name: 'Acqua di Giò Profondo',
          brand: 'Armani',
          gender: 'MASCULINO',
          description: 'Aromático marino moderno.',
          sku: 'ARM-ADGP-EDP',
          imageUrl:
              'https://images.unsplash.com/photo-1585386959984-a4155224a1ad?w=600',
        ),
      ];
      _perfumeOptionsError = null;
      _loadingPerfumeOptions = false;
      _usingMockPerfumes = true;
      _galleryPageIndex = 0;
      _selectedPerfumeOption = null;
    });
    _syncGalleryPosition(0);
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _perfumeSearchController.dispose();
    _imageUrlInputController.dispose();
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
    if (_selectedBrand == null) return const [];

    final selectedBrandName = _selectedBrand!.name.trim().toLowerCase();
    if (selectedBrandName.isEmpty) return const [];

    final filtered = _perfumeOptions.where((option) {
      final optionBrand = (option.brand ?? '').trim().toLowerCase();
      return optionBrand.isNotEmpty && optionBrand == selectedBrandName;
    }).toList();

    final query = _perfumeSearch.trim().toLowerCase();
    if (query.isEmpty) return filtered;

    return filtered
        .where((option) => option.name.toLowerCase().contains(query))
        .toList();
  }

  void _applyPerfumeOption(PerfumeOption option) {
    setState(() {
      _selectedPerfumeOption = option;
      _name.text = option.name;

      if ((option.imageUrl ?? '').trim().isNotEmpty) {
        final selectedImage = option.imageUrl!.trim();
        _imageUrl.text = selectedImage;
        _imageUrlInputController.text =
            _isDataImageSource(selectedImage) ? '' : selectedImage;
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

      _selectionMessage = 'Seleccionado: ${option.name}';
    });

    HapticFeedback.selectionClick();
  }

  bool _isDataImageSource(String value) {
    return value.trim().startsWith('data:image/');
  }

  String _guessMimeTypeFromPath(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 92,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      final mimeType = (picked.mimeType ?? '').trim().isNotEmpty
          ? picked.mimeType!.trim()
          : _guessMimeTypeFromPath(picked.path);
      final encoded = base64Encode(bytes);
      final dataUrl = 'data:$mimeType;base64,$encoded';

      if (!mounted) return;
      setState(() {
        _imageUrl.text = dataUrl;
        _imageUrlInputController.clear();
        _selectedPerfumeOption = null;
        _selectionMessage = 'Imagen local seleccionada';
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'No se pudo seleccionar la imagen: ${e.toString().replaceAll('Exception: ', '').trim()}',
      );
    }
  }

  void _setImageFromUrlInput(String value) {
    final normalized = value.trim();

    setState(() {
      _imageUrl.text = normalized;
      _selectedPerfumeOption = null;
      _selectionMessage =
          normalized.isEmpty ? 'Imagen limpiada' : 'Imagen configurada por URL';
    });
  }

  void _clearSelectedImage() {
    setState(() {
      _imageUrl.clear();
      _imageUrlInputController.clear();
      _selectedPerfumeOption = null;
      _selectionMessage = 'Imagen eliminada';
    });
  }

  String? _sanitizeImageUrlForSave(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:image/')) return value;

    final uri = Uri.tryParse(value);
    if (uri == null) return value;

    final isExternalProxy = uri.path == '/api/external-image';
    if (!isExternalProxy) return value;

    final source = uri.queryParameters['url']?.trim() ?? '';
    if (source.isEmpty) {
      return null;
    }

    return Uri.decodeFull(source);
  }

  bool get _isManualPerfumeEntry =>
      !_isEdit && _perfumeInputMode == _PerfumeInputMode.manual;

  void _setPerfumeInputMode(_PerfumeInputMode mode) {
    setState(() {
      _perfumeInputMode = mode;
      _selectedPerfumeOption =
          mode == _PerfumeInputMode.manual ? null : _selectedPerfumeOption;
      _galleryPageIndex = 0;
      _selectionMessage = mode == _PerfumeInputMode.manual
          ? 'Modo manual activado. Completa nombre y datos del producto.'
          : null;
    });

    if (mode == _PerfumeInputMode.suggestions) {
      _syncGalleryPosition(0);
    }
  }

  int get _currentStep {
    if (_selectedBrand == null) return 1;
    if (_isManualPerfumeEntry) return 4;
    if (_selectedPerfumeOption == null) return 2;
    return 4;
  }

  bool get _isCarouselEnabled => _selectedBrand != null;

  Future<void> _openCreateBrandModal() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final countryController = TextEditingController();
    String searchQuery = '';
    bool saving = false;

    final created = await showModalBottomSheet<Brand>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalBodyContext, setModalState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(modalBodyContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Casas existentes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Buscar casa fabricante',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final normalizedQuery =
                              searchQuery.trim().toLowerCase();
                          final visibleBrands = _brands.where((b) {
                            if (normalizedQuery.isEmpty) return true;
                            final name = b.name.toLowerCase();
                            final country = (b.country ?? '').toLowerCase();
                            return name.contains(normalizedQuery) ||
                                country.contains(normalizedQuery);
                          }).toList()
                            ..sort((a, b) => a.name
                                .toLowerCase()
                                .compareTo(b.name.toLowerCase()));

                          if (visibleBrands.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                _brands.isEmpty
                                    ? 'No hay casas cargadas todavía.'
                                    : 'No se encontraron resultados.',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }

                          return Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: visibleBrands.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final brand = visibleBrands[index];
                                final subtitle =
                                    (brand.country ?? '').trim().isEmpty
                                        ? 'Seleccionar esta casa'
                                        : brand.country!.trim();

                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    brand.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(subtitle),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                  ),
                                  onTap: saving
                                      ? null
                                      : () =>
                                          Navigator.pop(modalContext, brand),
                                );
                              },
                            ),
                          );
                        },
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

                                        if (!result.created) {
                                          await showDialog<void>(
                                            context: modalContext,
                                            builder: (_) => AlertDialog(
                                              title: const Text(
                                                'Casa fabricante ya existe',
                                              ),
                                              content: Text(
                                                'La casa fabricante "${result.brand.name}" ya existe y será utilizada.',
                                              ),
                                              actions: [
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(_, null),
                                                  child: const Text('Aceptar'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (!mounted ||
                                              !modalContext.mounted) {
                                            return;
                                          }
                                        }

                                        Navigator.pop(
                                            modalContext, result.brand);
                                      } catch (e) {
                                        if (!mounted || !modalContext.mounted) {
                                          return;
                                        }

                                        setModalState(() {
                                          saving = false;
                                        });

                                        _showSnack(
                                          e
                                              .toString()
                                              .replaceAll('Exception: ', '')
                                              .trim(),
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
              ),
            );
          },
        );
      },
    );

    if (created == null || !mounted) return;

    await _loadBrands(preferredBrandId: created.id);

    if (!mounted) return;
    _showSnack(
      'Casa fabricante "${created.name}" lista para usar',
    );
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
    var trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('data:image/')) return trimmed;

    try {
      final decoded = Uri.decodeFull(trimmed);
      if (decoded != trimmed) {
        trimmed = decoded;
      }
    } catch (_) {}

    final apiOrigin = _apiOrigin();
    final apiHost = _apiHost();

    if (trimmed.startsWith('/')) {
      return '$apiOrigin$trimmed';
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final path = trimmed.startsWith('./') ? trimmed.substring(2) : trimmed;
      return '$apiOrigin/${path.startsWith('/') ? path.substring(1) : path}';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    if (_isLocalOnlyHost(uri.host)) {
      return uri
          .replace(
            host: apiHost,
            port: uri.hasPort ? uri.port : null,
          )
          .toString();
    }

    return trimmed;
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
      final extra = '$apiOrigin$normalized';
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
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isSelected ? 1 : 0.55,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          scale: isSelected ? 1 : 0.94,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                key: ValueKey('wheel-item-${option.id}-$isSelected'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: isSelected ? 86 : 72,
                height: isSelected ? 86 : 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isSelected ? 18 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isSelected ? 0.10 : 0.04),
                      blurRadius: isSelected ? 18 : 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF4D8D)
                        : const Color(0xFFE5E7EB),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          fallback: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 24,
                            color: Color(0xFF9CA3AF),
                          ),
                        )
                      : const Icon(
                          Icons.local_mall_outlined,
                          size: 24,
                          color: Color(0xFF9CA3AF),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSelected ? 12 : 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF111827)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      if (mounted) {
        _showSnack(
          'Revisa los campos obligatorios antes de guardar',
          backgroundColor: const Color(0xFFB91C1C),
        );
      }
      return;
    }

    if (_selectedBrand == null) {
      setState(() => _error = 'Selecciona una casa fabricante');
      if (mounted) {
        _showSnack(
          'Selecciona una casa fabricante',
          backgroundColor: const Color(0xFFB91C1C),
        );
      }
      return;
    }

    if (_isEdit) {
      final confirmUpdate = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirmar actualización'),
          content: const Text('¿Estás seguro de actualizar este producto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, actualizar'),
            ),
          ],
        ),
      );

      if (confirmUpdate != true) {
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final sku = _sku.text.trim().isEmpty ? null : _sku.text.trim();
      final description =
          _description.text.trim().isEmpty ? null : _description.text.trim();
      final imageUrl = _sanitizeImageUrlForSave(_imageUrl.text);
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
          stock: stock,
          minStock: minStock,
          isActive: true,
        );

        try {
          await _service.setInventory(
            productId: product.id,
            stock: stock,
            minStock: minStock,
          );
        } catch (_) {
          // En algunos backends no existe endpoint dedicado de inventario.
          // Ya enviamos stock/minStock en update, así que no bloqueamos el guardado.
        }
      } else {
        final duplicate = await _findDuplicateProduct(
          brandId: _selectedBrand!.id,
          brandName: _selectedBrand!.name,
          name: name,
        );

        if (duplicate != null) {
          if (!mounted) return;

          await _showInfoDialog(
            title: 'Perfume ya existe',
            message:
                'El perfume "${duplicate.name}" ya existe en la casa fabricante "${duplicate.brandName}".',
          );
          return;
        }

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
      final message = _isEdit
          ? 'Producto actualizado exitosamente'
          : 'Producto guardado exitosamente';
      Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;

      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();

      setState(() {
        _error = errorMsg;
      });

      _showSnack(
        errorMsg.isEmpty ? 'No se pudo guardar el producto' : errorMsg,
        backgroundColor: const Color(0xFFB91C1C),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required int step,
    required bool enabled,
    required Widget child,
  }) {
    final active = _currentStep >= step;
    final current = _currentStep == step;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current
              ? const Color(0xFFFF4D8D)
              : active
                  ? const Color(0xFFFACFE0)
                  : const Color(0xFFE5E7EB),
          width: current ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor:
                    active ? const Color(0xFFFF4D8D) : const Color(0xFFE5E7EB),
                child: Text(
                  '$step',
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                current
                    ? Icons.play_circle_outline_rounded
                    : active
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                color: current
                    ? const Color(0xFFFF4D8D)
                    : active
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF9CA3AF),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: !enabled,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: enabled ? 1 : 0.55,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepIndicator() {
    const totalSteps = 4;
    final progress = (_currentStep / totalSteps).clamp(0.0, 1.0);
    const labels = ['Marca', 'Perfume', 'Vista previa', 'Datos'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso actual: $_currentStep de $totalSteps',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4D8D)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(labels.length, (index) {
              final step = index + 1;
              final isCurrent = step == _currentStep;
              final isDone = step < _currentStep;

              return Chip(
                avatar: Icon(
                  isDone
                      ? Icons.check_rounded
                      : isCurrent
                          ? Icons.play_arrow_rounded
                          : Icons.circle_outlined,
                  size: 16,
                  color: isCurrent
                      ? const Color(0xFFFF4D8D)
                      : isDone
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF9CA3AF),
                ),
                label: Text(
                  '$step. ${labels[index]}',
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent
                        ? const Color(0xFF111827)
                        : const Color(0xFF6B7280),
                  ),
                ),
                side: BorderSide(
                  color: isCurrent
                      ? const Color(0xFFFACFE0)
                      : const Color(0xFFE5E7EB),
                ),
                backgroundColor: isCurrent
                    ? const Color(0xFFFFF1F6)
                    : const Color(0xFFFFFFFF),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfumeStepContent(List<PerfumeOption> visiblePerfumeOptions) {
    if (!_isCarouselEnabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: const Text(
          'Selecciona una casa fabricante para habilitar el carrusel.',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Widget body;
    if (_loadingPerfumeOptions) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    } else if (_perfumeOptionsError != null) {
      body = Column(
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadPerfumeOptions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loadMockPerfumeOptions,
                  icon: const Icon(Icons.data_object),
                  label: const Text('Usar mock'),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (visiblePerfumeOptions.isEmpty) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          _perfumeSearch.trim().isEmpty
              ? 'No hay perfumes disponibles para esta marca.'
              : 'No hay resultados para "${_perfumeSearch.trim()}".',
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          SizedBox(
            height: 186,
            child: ListWheelScrollView.useDelegate(
              controller: _galleryController,
              itemExtent: 112,
              diameterRatio: 1.6,
              useMagnifier: true,
              magnification: 1.09,
              overAndUnderCenterOpacity: 0.35,
              squeeze: 0.95,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (newIndex) {
                setState(() {
                  _galleryPageIndex = newIndex;
                });

                if (newIndex < visiblePerfumeOptions.length) {
                  _applyPerfumeOption(visiblePerfumeOptions[newIndex]);
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: visiblePerfumeOptions.length,
                builder: (context, index) {
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
              '${_galleryPageIndex + 1} de ${visiblePerfumeOptions.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _perfumeSearchController,
          onChanged: (value) {
            setState(() {
              _perfumeSearch = value;
              _galleryPageIndex = 0;
              _selectedPerfumeOption = null;
            });
            _syncGalleryPosition(0);
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Buscar perfume en la marca',
          ),
        ),
        if (_usingMockPerfumes) ...[
          const SizedBox(height: 8),
          const Text(
            'Mostrando datos mock de ejemplo',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        body,
      ],
    );
  }

  Widget _buildImagePreviewBox({
    required String raw,
    required List<String> previewUrls,
  }) {
    final trimmedRaw = raw.trim();

    if (_isDataImageSource(trimmedRaw)) {
      final separator = trimmedRaw.indexOf(',');
      if (separator > -1 && separator < trimmedRaw.length - 1) {
        try {
          final bytes = base64Decode(trimmedRaw.substring(separator + 1));
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              width: double.infinity,
              height: 220,
            ),
          );
        } catch (_) {}
      }
    }

    if (previewUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _ResilientNetworkImage(
          key: ValueKey('edit-image-preview-${previewUrls.first}'),
          imageUrls: previewUrls,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          loading: const Center(child: CircularProgressIndicator()),
          fallback: const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: Color(0xFFD1D5DB),
            ),
          ),
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.local_mall_outlined,
        size: 64,
        color: Color(0xFFD1D5DB),
      ),
    );
  }

  Widget _buildEditImageSection({
    required List<PerfumeOption> visiblePerfumeOptions,
    required String selectedImageRaw,
    required List<String> selectedPreviewUrls,
    bool showSuggestions = true,
    bool showMainPreview = true,
    String helperText = 'Puedes elegir por sugerencia, URL o galería local',
  }) {
    final suggestions = visiblePerfumeOptions.take(10).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFACFE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: Color(0xFFFF4D8D)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Imagen del producto',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (showMainPreview) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: _buildImagePreviewBox(
                raw: selectedImageRaw,
                previewUrls: selectedPreviewUrls,
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _imageUrl.text.trim().isEmpty
                      ? Icons.image_not_supported_outlined
                      : Icons.check_circle_outline,
                  size: 16,
                  color: _imageUrl.text.trim().isEmpty
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 6),
                Text(
                  _imageUrl.text.trim().isEmpty
                      ? 'Sin imagen seleccionada'
                      : 'Imagen lista para vista previa',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _clearSelectedImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Limpiar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _imageUrlInputController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(
              hintText: 'https://... o /static/images/...',
            ),
            keyboardType: TextInputType.url,
            onChanged: _setImageFromUrlInput,
          ),
          if (_isDataImageSource(_imageUrl.text)) ...[
            const SizedBox(height: 6),
            const Text(
              'Imagen local seleccionada y lista para guardar.',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (showSuggestions && suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Sugerencias de la marca',
              style: TextStyle(
                color: Color(0xFF374151),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final option = suggestions[index];
                  final optionUrls = _imageUrlCandidates(option.imageUrl ?? '');
                  final isSelected = _selectedPerfumeOption?.id == option.id;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _saving ? null : () => _applyPerfumeOption(option),
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF4D8D)
                              : const Color(0xFFE5E7EB),
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: optionUrls.isNotEmpty
                                  ? _ResilientNetworkImage(
                                      imageUrls: optionUrls,
                                      fit: BoxFit.cover,
                                      loading: const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      fallback: const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 20,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 20,
                                      color: Color(0xFF9CA3AF),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreatePerfumeStepContent(
      List<PerfumeOption> visiblePerfumeOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: _perfumeInputMode == _PerfumeInputMode.suggestions,
              label: const Text('Sugerencias'),
              onSelected: _saving
                  ? null
                  : (_) => _setPerfumeInputMode(_PerfumeInputMode.suggestions),
            ),
            ChoiceChip(
              selected: _perfumeInputMode == _PerfumeInputMode.manual,
              label: const Text('Manual'),
              onSelected: _saving
                  ? null
                  : (_) => _setPerfumeInputMode(_PerfumeInputMode.manual),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_perfumeInputMode == _PerfumeInputMode.suggestions)
          _buildPerfumeStepContent(visiblePerfumeOptions)
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'Vas a ingresar el perfume manualmente. En este modo puedes cargar imagen local o por URL.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildEditImageSection(
            visiblePerfumeOptions: visiblePerfumeOptions,
            selectedImageRaw: _imageUrl.text,
            selectedPreviewUrls: _imageUrlCandidates(_imageUrl.text),
            showSuggestions: false,
            showMainPreview: false,
            helperText:
                'Sube una imagen local o pega una URL para el perfume manual',
          ),
        ],
      ],
    );
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
              AppPageHeader(
                icon: _isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                title: _isEdit ? 'Editar producto' : 'Ingresar producto',
                subtitle: _isEdit
                    ? 'Actualiza datos, imagen y stock del perfume'
                    : 'Completa el flujo para crear un nuevo perfume',
                trailing: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const SizedBox(height: 12),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isEdit) ...[
                        _buildCurrentStepIndicator(),
                        const SizedBox(height: 12),
                        _buildStepContainer(
                          step: 1,
                          enabled: true,
                          title: 'Casa fabricante',
                          subtitle: 'Elige la marca para filtrar perfumes',
                          child: _loadingBrands
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: LinearProgressIndicator(),
                                )
                              : _brandsError != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                          label: const Text(
                                            'Reintentar cargar casas',
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        DropdownSearch<Brand>(
                                          items: _brands,
                                          selectedItem: _selectedBrand,
                                          compareFn: (item, selected) =>
                                              item.id == selected.id,
                                          itemAsString: (Brand b) {
                                            final country =
                                                (b.country ?? '').trim();
                                            return country.isEmpty
                                                ? b.name
                                                : '${b.name} • $country';
                                          },
                                          popupProps: const PopupProps.menu(
                                            showSearchBox: true,
                                            searchFieldProps: TextFieldProps(
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Buscar casa fabricante',
                                              ),
                                            ),
                                          ),
                                          dropdownDecoratorProps:
                                              const DropDownDecoratorProps(
                                            dropdownSearchDecoration:
                                                InputDecoration(
                                              labelText: 'Casa fabricante *',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          onChanged: (Brand? b) {
                                            final changed =
                                                _selectedBrand?.id != b?.id;

                                            setState(() {
                                              _selectedBrand = b;
                                              _perfumeSearch = '';
                                              _perfumeSearchController.clear();
                                            });

                                            if (changed) {
                                              setState(() {
                                                _selectedPerfumeOption = null;
                                                _galleryPageIndex = 0;
                                                _imageUrl.clear();
                                                _selectionMessage = b == null
                                                    ? null
                                                    : 'Marca ${b.name} seleccionada. Elige un perfume.';
                                              });
                                              _syncGalleryPosition(0);
                                              if (b != null) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Mostrando perfumes de ${b.name}',
                                                    ),
                                                  ),
                                                );
                                              }
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
                                              onPressed: _saving
                                                  ? null
                                                  : _openCreateBrandModal,
                                              icon: const Icon(
                                                Icons.add_business_outlined,
                                              ),
                                              label: const Text(
                                                'Agregar casa fabricante',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                        ),
                        const SizedBox(height: 12),
                        _buildStepContainer(
                          step: 2,
                          enabled: _selectedBrand != null,
                          title: 'Seleccionar perfume',
                          subtitle:
                              'Carrusel vertical filtrado por marca seleccionada',
                          child: _buildCreatePerfumeStepContent(
                            visiblePerfumeOptions,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStepContainer(
                          step: 3,
                          enabled: true,
                          title: 'Vista previa',
                          subtitle: _isManualPerfumeEntry
                              ? 'Imagen y nombre según entrada manual'
                              : 'Imagen y nombre se actualizan automáticamente',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOut,
                                child: ClipRRect(
                                  key: ValueKey(
                                    _selectedPerfumeOption?.id ??
                                        'preview-empty',
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
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                            fallback: const Center(
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
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
                              const SizedBox(height: 10),
                              Text(
                                _selectedPerfumeOption?.name ??
                                    (_name.text.trim().isEmpty
                                        ? 'Sin perfume seleccionado'
                                        : _name.text.trim()),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if (_selectionMessage != null) ...[
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    _selectionMessage!,
                                    key: ValueKey(_selectionMessage),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildStepContainer(
                        step: _isEdit ? 1 : 4,
                        enabled: true,
                        title: 'Datos del producto',
                        subtitle: 'Completa y valida antes de guardar',
                        child: Column(
                          children: [
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
                                    label:
                                        const Text('Reintentar cargar casas'),
                                  ),
                                ],
                              )
                            else if (_isEdit) ...[
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
                                    _perfumeSearch = '';
                                    _perfumeSearchController.clear();
                                    _selectedPerfumeOption = null;
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
                                    icon:
                                        const Icon(Icons.add_business_outlined),
                                    label:
                                        const Text('Agregar casa fabricante'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _perfumeSearchController,
                                onChanged: (value) {
                                  setState(() {
                                    _perfumeSearch = value;
                                  });
                                },
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  labelText: 'Buscar sugerencia por nombre',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildEditImageSection(
                                visiblePerfumeOptions: visiblePerfumeOptions,
                                selectedImageRaw: selectedImageRaw,
                                selectedPreviewUrls: selectedPreviewUrls,
                              ),
                              const SizedBox(height: 10),
                            ],
                            const AppFieldLabel('Nombre del producto *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _name,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              decoration: const InputDecoration(
                                hintText: 'Ej: Sauvage Elixir',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Ingresa el nombre';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            const AppFieldLabel('Precio *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              decoration: const InputDecoration(
                                hintText: 'Ej: 85.50',
                              ),
                              validator: (v) {
                                final p = _toDouble(v ?? '');
                                if (p <= 0) return 'Precio inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            const AppFieldLabel('SKU (opcional)'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _sku,
                              decoration: const InputDecoration(
                                hintText: 'Ej: DIOR-SAU-100',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const AppFieldLabel('Género (opcional)'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: const InputDecoration(),
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
                            const AppFieldLabel('Descripción (opcional)'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _description,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Notas del perfume y detalles útiles',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const AppFieldLabel('Inventario'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _stock,
                                    keyboardType: TextInputType.number,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
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
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
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

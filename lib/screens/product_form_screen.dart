import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import '../models/brand.dart';
import '../models/product_dto.dart';
import '../services/brand_services.dart';
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
  final _formKey = GlobalKey<FormState>();

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

  bool _loadingBrands = true;
  String? _brandsError;
  List<Brand> _brands = [];
  Brand? _selectedBrand;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _fillInitialData();
    _loadBrands();
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

  Future<void> _loadBrands() async {
    try {
      final data = await _brandService.list();

      if (!mounted) return;

      Brand? selected;
      if (_isEdit) {
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

  @override
  void dispose() {
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

  String? _validateImageUrl(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Ingresa una URL válida';
    }
    return null;
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
    final imagePreviewUrl = _imageUrl.text.trim();

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
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
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
                        DropdownSearch<Brand>(
                          items: _brands,
                          selectedItem: _selectedBrand,
                          compareFn: (item, selected) => item.id == selected.id,
                          itemAsString: (Brand b) {
                            final country = (b.country ?? '').trim();
                            return country.isEmpty
                                ? b.name
                                : '${b.name} • $country';
                          },
                          popupProps: const PopupProps.menu(
                            showSearchBox: true,
                          ),
                          dropdownDecoratorProps: const DropDownDecoratorProps(
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
                            if (b == null)
                              return 'Selecciona una casa fabricante';
                            return null;
                          },
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
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _imageUrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Image URL (opcional)',
                          hintText: 'https://...',
                        ),
                        validator: _validateImageUrl,
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
                          child: Image.network(
                            imagePreviewUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const Center(
                                child: Text(
                                  'No se pudo cargar la imagen',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
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

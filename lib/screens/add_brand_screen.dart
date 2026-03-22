import 'package:flutter/material.dart';

import 'package:flutter_application_3/services/brand_services.dart';
import 'package:flutter_application_3/services/perfume_options_service.dart';
import 'package:flutter_application_3/ui/app_theme.dart';
import 'package:flutter_application_3/ui/app_widgets.dart';

class AddBrandScreen extends StatefulWidget {
  const AddBrandScreen({super.key});

  @override
  State<AddBrandScreen> createState() => _AddBrandScreenState();
}

class _AddBrandScreenState extends State<AddBrandScreen> {
  final _service = BrandService();
  final _perfumeOptionsService = PerfumeOptionsService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _country = TextEditingController();

  bool _loadingSuggestions = true;
  bool _saving = false;
  String? _error;

  List<String> _nameSuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isValidSuggestion(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return false;
    if (normalized == 'string') return false;
    if (normalized == 'null') return false;
    if (normalized == 'undefined') return false;
    return true;
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _error = null;
    });

    try {
      final perfumes = await _perfumeOptionsService.listOptions();

      final counts = <String, int>{};
      final display = <String, String>{};

      for (final item in perfumes) {
        final name = (item.brand ?? '').trim();
        if (!_isValidSuggestion(name)) continue;
        final key = _normalize(name);
        counts[key] = (counts[key] ?? 0) + 1;
        display.putIfAbsent(key, () => name);
      }

      final sorted = display.keys.toList()
        ..sort((a, b) {
          final cmp = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
          if (cmp != 0) return cmp;
          return a.compareTo(b);
        });

      if (!mounted) return;
      setState(() {
        _nameSuggestions = sorted.map((k) => display[k]!).toList();
        _loadingSuggestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
        _error = e.toString().replaceAll('Exception: ', '').trim();
      });
    }
  }

  List<String> get _filteredSuggestions {
    final query = _normalize(_name.text);
    final base = _nameSuggestions;

    if (query.isEmpty) {
      return base.take(8).toList();
    }

    return base.where((e) => _normalize(e).contains(query)).take(8).toList();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar guardado'),
        content: const Text('¿Estás seguro de guardar esta casa fabricante?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, guardar'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await _service.findOrCreateByName(
        name: _name.text,
        country: _country.text,
      );

      if (!mounted) return;

      if (!result.created) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Casa fabricante ya existe'),
            content: Text(
              'La casa fabricante "${result.brand.name}" ya existe y será utilizada.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );

        if (!mounted) return;
      }

      Navigator.pop(context, result.brand);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _filteredSuggestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar casa fabricante'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              AppPageHeader(
                icon: Icons.storefront_outlined,
                title: 'Agregar casa fabricante',
                subtitle: 'Crea una marca nueva o usa sugerencias de la API',
                trailing: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nueva casa fabricante',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Escribe el nombre y te sugerimos casas desde la API externa.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const AppFieldLabel('Nombre *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Ej: Dior',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Ingresa un nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      const AppFieldLabel('País (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _country,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Ej: Francia',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingSuggestions)
                        const LinearProgressIndicator()
                      else if (suggestions.isNotEmpty) ...[
                        const Text(
                          'Sugerencias de nombre',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: suggestions
                              .map(
                                (item) => ActionChip(
                                  label: Text(item),
                                  onPressed: () {
                                    setState(() {
                                      _name.text = item;
                                      _name.selection = TextSelection.collapsed(
                                        offset: _name.text.length,
                                      );
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        ErrorMessage(text: _error!),
                      ],
                      const SizedBox(height: 16),
                      GradientButton(
                        text: _saving ? 'Guardando...' : 'Guardar casa',
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

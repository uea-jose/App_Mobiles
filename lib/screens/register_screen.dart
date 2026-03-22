import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import '../utils/validators.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const LatLng _defaultQuito = LatLng(-0.1807, -78.4678);

  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _loadingLocation = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_onFormChanged);
    _cityCtrl.addListener(_onFormChanged);
    _phoneCtrl.addListener(_onFormChanged);
    _passwordCtrl.addListener(_onPasswordChanged);
    _confirmCtrl.addListener(_onFormChanged);
  }

  void _onPasswordChanged() {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _hasUppercase(String text) => RegExp(r'[A-Z]').hasMatch(text);
  bool _hasNumber(String text) => RegExp(r'\d').hasMatch(text);
  bool _hasSpecial(String text) => RegExp(r'[^A-Za-z0-9]').hasMatch(text);

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Contraseña es obligatoria';
    }
    if (password.length < 8) {
      return 'La contraseña debe tener mínimo 8 caracteres';
    }
    if (!_hasUppercase(password)) {
      return 'Incluye al menos 1 letra mayúscula';
    }
    if (!_hasNumber(password)) {
      return 'Incluye al menos 1 número';
    }
    if (!_hasSpecial(password)) {
      return 'Incluye al menos 1 carácter especial';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirmar contraseña es obligatoria';
    }
    if (value != _passwordCtrl.text) {
      return 'La confirmación no coincide con la contraseña';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      return 'Teléfono es obligatorio';
    }
    if (!RegExp(r'^\d{9}$').hasMatch(phone)) {
      return 'Ingresa 9 dígitos válidos (sin +593)';
    }
    if (!phone.startsWith('9')) {
      return 'El número debe iniciar con 9';
    }
    return null;
  }

  String _normalizedPhone() =>
      '+593${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';

  bool get _isPasswordMinLength => _passwordCtrl.text.length >= 8;
  bool get _isPasswordHasUppercase => _hasUppercase(_passwordCtrl.text);
  bool get _isPasswordHasNumber => _hasNumber(_passwordCtrl.text);
  bool get _isPasswordHasSpecial => _hasSpecial(_passwordCtrl.text);

  bool get _canSubmit {
    if (_loading) return false;
    if (Validators.username(_usernameCtrl.text) != null) return false;
    if (Validators.requiredField(_cityCtrl.text, field: 'Ciudad') != null) {
      return false;
    }
    if (_validatePhone(_phoneCtrl.text) != null) return false;
    if (_validatePassword(_passwordCtrl.text) != null) return false;
    if (_validateConfirmPassword(_confirmCtrl.text) != null) return false;
    return true;
  }

  Future<void> _detectCity() async {
    if (_loadingLocation) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          _error =
              'El GPS está desactivado. Puedes escribir tu ciudad manualmente.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _error =
              'Permiso de ubicación denegado. Puedes escribir tu ciudad manualmente.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error =
              'Permiso denegado permanentemente. Actívalo en configuración o escribe tu ciudad manualmente.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      await setLocaleIdentifier('es_EC');
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        setState(() {
          _error = 'No se pudo detectar tu ciudad automáticamente.';
        });
        return;
      }

      final place = placemarks.first;

      final city = [
        place.locality,
        place.subLocality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ]
          .where((e) => e != null && e.trim().isNotEmpty)
          .map((e) => e!.trim())
          .fold<String>('', (prev, element) => prev.isEmpty ? element : prev);

      if (city.isEmpty) {
        setState(() {
          _error = 'No se pudo detectar tu ciudad automáticamente.';
        });
        return;
      }

      final cityLower = city.toLowerCase();
      final isDefaultEmulatorCity = cityLower.contains('mountain view') ||
          cityLower.contains('california');

      if (position.isMocked && isDefaultEmulatorCity) {
        setState(() {
          _cityCtrl.clear();
          _error =
              'El emulador está usando ubicación por defecto (Mountain View). Configura una ubicación en Quito para autocompletar.';
        });
        return;
      }

      setState(() {
        _cityCtrl.text = city;
        if (position.isMocked) {
          _error =
              'Ubicación simulada detectada (emulador). Configura una ubicación en Ecuador para autocompletar correctamente.';
        } else {
          _error = null;
        }
      });
    } catch (e) {
      setState(() {
        _error =
            'No se pudo obtener la ubicación. Escribe tu ciudad manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  String _extractCityFromPlacemark(Placemark place) {
    return [
      place.locality,
      place.subLocality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .fold<String>('', (prev, element) => prev.isEmpty ? element : prev);
  }

  Future<LatLng> _initialMapCenter() async {
    return _defaultQuito;
  }

  Future<void> _pickCityOnMap() async {
    if (_loadingLocation) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      final center = await _initialMapCenter();

      if (!mounted) return;

      final selectedPoint = await showModalBottomSheet<LatLng>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (_) => _CityMapPickerSheet(initialCenter: center),
      );

      if (selectedPoint == null || !mounted) return;

      await setLocaleIdentifier('es_EC');
      final placemarks = await placemarkFromCoordinates(
        selectedPoint.latitude,
        selectedPoint.longitude,
      );

      if (placemarks.isEmpty) {
        setState(() {
          _error =
              'No se pudo resolver la ciudad desde el mapa. Puedes escribirla manualmente.';
        });
        return;
      }

      final city = _extractCityFromPlacemark(placemarks.first);

      if (city.isEmpty) {
        setState(() {
          _error =
              'No se pudo detectar una ciudad válida. Intenta tocar otra zona del mapa.';
        });
        return;
      }

      setState(() {
        _cityCtrl.text = city;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo abrir el mapa. Escribe tu ciudad manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.register(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _fullNameCtrl.text.trim().isEmpty
            ? null
            : _fullNameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        phone: _normalizedPhone(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Crear cuenta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Regístrate para gestionar tu tienda de perfumes',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 18),
                        const AppFieldLabel('Nombre (opcional)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fullNameCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        const AppFieldLabel('Usuario'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          validator: Validators.username,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 14),
                        const AppFieldLabel('Ciudad'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _cityCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: _loadingLocation
                                ? 'Detectando ciudad...'
                                : 'Ingresa tu ciudad',
                            suffixIcon: _loadingLocation
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    width: 96,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Usar mi ubicación actual',
                                          icon: const Icon(Icons.my_location),
                                          onPressed:
                                              _loading ? null : _detectCity,
                                        ),
                                        IconButton(
                                          tooltip: 'Elegir en mapa',
                                          icon: const Icon(Icons.map_outlined),
                                          onPressed:
                                              _loading ? null : _pickCityOnMap,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          validator: (value) =>
                              Validators.requiredField(value, field: 'Ciudad'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 14),
                        const AppFieldLabel('Teléfono'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            const _EcuadorPhoneMaskFormatter(),
                          ],
                          decoration: InputDecoration(
                            hintText: '9XX XXX XXX',
                            prefixText: _cityCtrl.text.trim().isNotEmpty
                                ? '🇪🇨 +593 '
                                : null,
                            helperText: _cityCtrl.text.trim().isNotEmpty
                                ? 'Ingresa el número sin el prefijo'
                                : 'Selecciona una ciudad para usar +593',
                          ),
                          validator: _validatePhone,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 14),
                        const AppFieldLabel('Contraseña'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: _loading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: _validatePassword,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 8),
                        _PasswordRulesHint(
                          minLengthOk: _isPasswordMinLength,
                          uppercaseOk: _isPasswordHasUppercase,
                          numberOk: _isPasswordHasNumber,
                          specialOk: _isPasswordHasSpecial,
                        ),
                        const SizedBox(height: 14),
                        const AppFieldLabel('Confirmar contraseña'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirm
                                  ? 'Mostrar confirmación'
                                  : 'Ocultar confirmación',
                              onPressed: _loading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureConfirm = !_obscureConfirm;
                                      });
                                    },
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: _validateConfirmPassword,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          ErrorMessage(
                            text: _error!,
                            onDismiss: () => setState(() => _error = null),
                          ),
                          const SizedBox(height: 12),
                        ],
                        GradientButton(
                          text: 'Registrar',
                          loading: _loading,
                          onPressed: _canSubmit ? _submit : null,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed:
                              _loading ? null : () => Navigator.pop(context),
                          child: const Text('Ya tengo cuenta, iniciar sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRulesHint extends StatelessWidget {
  final bool minLengthOk;
  final bool uppercaseOk;
  final bool numberOk;
  final bool specialOk;

  const _PasswordRulesHint({
    required this.minLengthOk,
    required this.uppercaseOk,
    required this.numberOk,
    required this.specialOk,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PasswordRuleItem(
          text: 'Mínimo 8 caracteres',
          ok: minLengthOk,
        ),
        _PasswordRuleItem(
          text: 'Al menos 1 letra mayúscula',
          ok: uppercaseOk,
        ),
        _PasswordRuleItem(
          text: 'Al menos 1 número',
          ok: numberOk,
        ),
        _PasswordRuleItem(
          text: 'Al menos 1 carácter especial',
          ok: specialOk,
        ),
      ],
    );
  }
}

class _PasswordRuleItem extends StatelessWidget {
  final String text;
  final bool ok;

  const _PasswordRuleItem({required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF047857) : AppTheme.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityMapPickerSheet extends StatefulWidget {
  final LatLng initialCenter;

  const _CityMapPickerSheet({required this.initialCenter});

  @override
  State<_CityMapPickerSheet> createState() => _CityMapPickerSheetState();
}

class _CityMapPickerSheetState extends State<_CityMapPickerSheet> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seleccionar ciudad en mapa',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca el mapa para elegir la ubicación de tu ciudad.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: 12,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _selected = latLng;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.flutter_application_3',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selected,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_pin,
                            size: 40,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Lat: ${_selected.latitude.toStringAsFixed(5)}  •  Lng: ${_selected.longitude.toStringAsFixed(5)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _selected),
                    icon: const Icon(Icons.check),
                    label: const Text('Usar ubicación'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EcuadorPhoneMaskFormatter extends TextInputFormatter {
  const _EcuadorPhoneMaskFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 9 ? digits.substring(0, 9) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

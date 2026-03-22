import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _adminKeyCtrl = TextEditingController();

  bool _loading = false;
  bool _loadingLocation = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  String? _role;
  String? _roleError;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_onFormChanged);
    _cityCtrl.addListener(_onFormChanged);
    _phoneCtrl.addListener(_onFormChanged);
    _passwordCtrl.addListener(_onPasswordChanged);
    _confirmCtrl.addListener(_onFormChanged);
    _adminKeyCtrl.addListener(_onFormChanged);
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
      if (_role != null) {
        _roleError = null;
      }
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
    _adminKeyCtrl.dispose();
    super.dispose();
  }

  bool _hasUppercase(String text) => RegExp(r'[A-Z]').hasMatch(text);
  bool _hasNumber(String text) => RegExp(r'\d').hasMatch(text);
  bool _hasSpecial(String text) => RegExp(r'[^A-Za-z0-9]').hasMatch(text);

  String? _validateRole(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Selecciona un rol para continuar';
    }
    return null;
  }

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
    if (_validateRole(_role) != null) return false;
    if (_validatePhone(_phoneCtrl.text) != null) return false;
    if (_validatePassword(_passwordCtrl.text) != null) return false;
    if (_validateConfirmPassword(_confirmCtrl.text) != null) return false;
    if (_role == 'ADMIN' &&
        Validators.requiredField(_adminKeyCtrl.text, field: 'Código admin') !=
            null) {
      return false;
    }
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

      setState(() {
        _cityCtrl.text = city;
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final roleError = _validateRole(_role);
    setState(() {
      _roleError = roleError;
    });

    if (!_formKey.currentState!.validate() || roleError != null) return;

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
        role: _role!,
        adminKey: _role == 'ADMIN' ? _adminKeyCtrl.text.trim() : null,
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
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Nombre (opcional)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fullNameCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Usuario',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          validator: Validators.username,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ciudad',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
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
                                : IconButton(
                                    tooltip: 'Usar mi ubicación actual',
                                    icon: const Icon(Icons.my_location),
                                    onPressed: _loading ? null : _detectCity,
                                  ),
                          ),
                          validator: (value) =>
                              Validators.requiredField(value, field: 'Ciudad'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Rol',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RoleSelector(
                          value: _role,
                          onChanged: _loading
                              ? null
                              : (v) {
                                  setState(() {
                                    _role = v;
                                    _roleError = null;
                                    _error = null;
                                  });
                                },
                        ),
                        if (_roleError != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _roleError!,
                              style: const TextStyle(
                                color: Color(0xFF9F1239),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Teléfono',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
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
                        if (_role == 'ADMIN') ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Código de administrador',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _adminKeyCtrl,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (_role != 'ADMIN') return null;
                              return Validators.requiredField(
                                v,
                                field: 'Código admin',
                              );
                            },
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          ),
                          const SizedBox(height: 14),
                        ],
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Contraseña',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
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
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Confirmar contraseña',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFCDD5),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF9F1239),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

class _RoleSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String>? onChanged;

  const _RoleSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleChip(
            label: 'Usuario',
            selected: value == 'USER',
            onTap: onChanged == null ? null : () => onChanged!.call('USER'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleChip(
            label: 'Admin',
            selected: value == 'ADMIN',
            onTap: onChanged == null ? null : () => onChanged!.call('ADMIN'),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.brandPink : const Color(0xFFE6E8F0),
              width: selected ? 2 : 1,
            ),
            color: selected ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFF),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected ? AppTheme.brandPink : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? AppTheme.textDark : const Color(0xFF475569),
                ),
              ),
            ],
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

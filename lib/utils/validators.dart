class Validators {
  static String? requiredText(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  static String? email(String? v) {
    final base = requiredText(v, field: 'Email');
    if (base != null) return base;

    final value = v!.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Email inválido (ej: usuario@dominio.com)';
    return null;
  }

  static String? password(String? v) {
    final base = requiredText(v, field: 'Contraseña');
    if (base != null) return base;

    final value = v!;
    if (value.length < 8) return 'Debe tener al menos 8 caracteres';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasNumber) return 'Debe tener letras y números';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    final base = requiredText(v, field: 'Confirmación');
    if (base != null) return base;

    if (v != original) return 'Las contraseñas no coinciden';
    return null;
  }
}

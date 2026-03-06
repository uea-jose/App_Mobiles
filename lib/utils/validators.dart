class Validators {
  static String? requiredField(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  static String? username(String? v) {
    final err = requiredField(v, field: 'Usuario');
    if (err != null) return err;
    if (v!.trim().length < 3) return 'Usuario debe tener al menos 3 caracteres';
    return null;
  }

  static String? password(String? v) {
    final err = requiredField(v, field: 'Contraseña');
    if (err != null) return err;
    if (v!.length < 4) return 'Contraseña debe tener al menos 4 caracteres';
    return null;
  }

  // ✅ ESTE ES EL QUE TE FALTA
  static String? confirmPassword(String? value, String originalPassword) {
    final err = requiredField(value, field: 'Confirmación');
    if (err != null) return err;
    if (value != originalPassword) return 'Las contraseñas no coinciden';
    return null;
  }
}

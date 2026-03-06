import 'package:flutter/material.dart';

class AppTheme {
  static const brandPink = Color(0xFFFF4D8D);
  static const brandOrange = Color(0xFFFF7A3D);

  static const bgTop = Color(0xFFF7E9EE);
  static const bgBottom = Color(0xFFF7F7FB);

  static const textDark = Color(0xFF1F2430);
  static const textMuted = Color(0xFF6B7280);

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgBottom,
      colorScheme: ColorScheme.fromSeed(seedColor: brandPink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E6EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E6EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandPink, width: 2),
        ),
      ),
    );
  }

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandPink, brandOrange],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );
}

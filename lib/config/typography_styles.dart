import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'theme_colors.dart';

class TypographyStyles {
  static TextStyle get header => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: ThemeColors.textPrimary,
  );

  static TextStyle get subHeader => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: ThemeColors.textPrimary,
  );

  static TextStyle get body =>
      const TextStyle(fontSize: 16, color: ThemeColors.textSecondary);

  static TextStyle get button => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

import 'package:flutter/material.dart';
import 'palette.dart';

class TextTokens {
  static TextStyle get headline => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppPalette.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get title => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppPalette.textPrimary,
  );

  static TextStyle get body => const TextStyle(
    fontSize: 15,
    color: AppPalette.textSecondary,
    height: 1.5,
  );

  static TextStyle get label => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppPalette.textSecondary,
    letterSpacing: 0.3,
  );

  static TextStyle get cta => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.4,
  );
}

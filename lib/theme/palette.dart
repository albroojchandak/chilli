import 'package:flutter/material.dart';

class AppPalette {
  static const Color primary = Color(0xFF7C3AED);
  static const Color secondary = Color(0xFFF59E0B);
  static const Color accent = Color(0xFF10B981);
  static const Color background = Color(0xFF0F0A1E);
  static const Color surface = Color(0xFF1A1030);
  static const Color surfaceLight = Color(0xFF231842);
  static const Color textPrimary = Color(0xFFF1F0F7);
  static const Color textSecondary = Color(0xFF9B93B8);
  static const Color error = Color(0xFFEF4444);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6), Color(0xFF3B0764)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color voiceBadgeBg = Color(0xFF064E3B);
  static const Color voiceBadgeText = Color(0xFF6EE7B7);
  static const Color videoBadgeBg = Color(0xFF1E3A5F);
  static const Color videoBadgeText = Color(0xFF93C5FD);
  static const Color msgBadgeBg = Color(0xFF3B1F5E);
  static const Color msgBadgeText = Color(0xFFC4B5FD);
  static const Color verifiedColor = Color(0xFF10B981);
  static const Color activeGreen = Color(0xFF34D399);
  static const Color tagSurface = Color(0xFF2D1B5E);
  static const Color tagLabel = Color(0xFFA78BFA);
}

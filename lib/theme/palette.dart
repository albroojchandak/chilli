import 'package:flutter/material.dart';

class Palette {
  // 7:3:1 Theme (70% White, 30% Indigo, 10% Chilli Red)
  static const Color primary = Color(0xFF4F46E5); // Deep Indigo
  static const Color secondary = Color(0xFF3730A3); // Darker Indigo
  static const Color accent = Color(0xFFE11D48); // Vibrant Chilli Red
  static const Color background = Color(0xFFFFFFFF); // Pure White (70%)
  static const Color surface = Color(0xFFFFFFFF); // Pure White (70%)
  static const Color textPrimary = Color(0xFF0F172A); // Slate Dark
  static const Color textSecondary = Color(0xFF64748B); // Slate Gray
  static const Color error = Color(0xFFEF4444);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // New Design Colors
  static const Color audioCallBg = Color(0xFFDCFCE7);
  static const Color audioCallText = Color(0xFF166534);
  static const Color videoCallBg = Color(0xFFDDD6FE);
  static const Color videoCallText = Color(0xFF6B21A8);
  static const Color chatBg = Color(0xFFFED7AA);
  static const Color chatText = Color(0xFF9A3412);
  static const Color verified = Color(0xFF10B981);
  static const Color onlineGreen = Color(0xFF34D399);
  static const Color tagBg = Color(0xFFE0E7FF);
  static const Color tagText = Color(0xFF4F46E5);
}


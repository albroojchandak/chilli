import 'package:flutter/material.dart';

class Palette {
  // Fresh Teal & Coral Theme
  static const Color primary = Color(0xFF06B6D4); // Vibrant Cyan
  static const Color secondary = Color(0xFFFF6B6B); // Coral Red
  static const Color accent = Color(0xFFFBBF24); // Golden Yellow
  static const Color background = Color(0xFFF8FAFC); // Soft White
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate Dark
  static const Color textSecondary = Color(0xFF64748B); // Slate Gray
  static const Color error = Color(0xFFEF4444);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF0E7490)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
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


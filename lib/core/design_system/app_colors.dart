import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1E3A8A); // Blue 900
  static const Color secondary = Color(0xFF3B82F6); // Blue 500
  static const Color accent = Color(0xFF60A5FA); // Blue 400

  // Semantic
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color danger = Color(0xFFEF4444); // Red 500
  static const Color dangerLight = Color(0xFFFEE2E2); // Red 100
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100

  // Neutrals (Light Theme)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // Neutrals (Dark Theme)
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color borderDark = Color(0xFF334155); // Slate 700
}

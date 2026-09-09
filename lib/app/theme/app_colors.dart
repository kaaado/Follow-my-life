/// Design system color palette for Follow My Life.
/// Uses a sophisticated dark-first palette with accent colors.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5A57FE);      // Electric violet
  static const Color primaryLight = Color(0xFF817BFF);
  static const Color primaryDark = Color(0xFF4542D4);
  static const Color primarySurface = Color(0x1A5A57FE);

  static const Color secondary = Color(0xFF00D9A6);     // Mint/teal
  static const Color secondaryLight = Color(0xFF5CFFD1);
  static const Color secondaryDark = Color(0xFF00A67E);

  static const Color tertiary = Color(0xFFFF6B8A);      // Soft coral
  static const Color tertiaryLight = Color(0xFFFF9BB0);
  static const Color tertiaryDark = Color(0xFFCC4463);

  // ─── Semantic Colors ──────────────────────────────────────────
  static const Color income = Color(0xFF00D9A6);        // Mint green
  static const Color expense = Color(0xFFEF4444);       // Red
  static const Color transfer = Color(0xFF64B5F6);      // Sky blue
  static const Color savings = Color(0xFFFFB74D);       // Amber
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFEF5350);
  static const Color success = Color(0xFF66BB6A);
  static const Color info = Color(0xFF42A5F5);

  // ─── Dark Theme ───────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0A0A14);
  static const Color darkSurface = Color(0xFF12121E);
  static const Color darkSurfaceVariant = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16162A);
  static const Color darkCardHover = Color(0xFF1E1E36);
  static const Color darkBorder = Color(0xFF2A2A42);
  static const Color darkDivider = Color(0xFF1F1F35);

  static const Color darkTextPrimary = Color(0xFFF0F0F8);
  static const Color darkTextSecondary = Color(0xFFB0B0CC);
  static const Color darkTextTertiary = Color(0xFF7070A0);
  static const Color darkTextDisabled = Color(0xFF50507A);

  // ─── Light Theme ──────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF5F5FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F0F6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardHover = Color(0xFFF8F8FC);
  static const Color lightBorder = Color(0xFFE0E0EC);
  static const Color lightDivider = Color(0xFFE8E8F0);

  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6060A0);
  static const Color lightTextTertiary = Color(0xFF9090B8);
  static const Color lightTextDisabled = Color(0xFFB0B0C8);

  // ─── Gradient Presets ─────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9D97FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF00D9A6), Color(0xFF00F5C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF16162A), Color(0xFF1E1E36)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Category Colors ──────────────────────────────────────────
  static const List<Color> categoryColors = [
    Color(0xFF6C63FF), // Primary violet
    Color(0xFF00D9A6), // Mint
    Color(0xFFFF6B8A), // Coral
    Color(0xFFFFB74D), // Amber
    Color(0xFF64B5F6), // Sky blue
    Color(0xFFBA68C8), // Purple
    Color(0xFF4DB6AC), // Teal
    Color(0xFFFF8A65), // Deep orange
    Color(0xFF81C784), // Green
    Color(0xFFE57373), // Red
    Color(0xFF9575CD), // Deep purple
    Color(0xFF4FC3F7), // Light blue
  ];

  static Color getCategoryColor(int index) {
    return categoryColors[index % categoryColors.length];
  }
}

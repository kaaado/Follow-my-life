/// App theme preset definition and color palette presets.
library;

import 'package:flutter/material.dart';

class AppThemePreset {
  final String id;
  final String name;
  final Color primaryColor;
  final LinearGradient gradient;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.gradient,
  });
}

class AppThemePresets {
  AppThemePresets._();

  static const defaultPreset = AppThemePreset(
    id: 'default_purple',
    name: 'Electric Violet',
    primaryColor: Color(0xFF5A57FE),
    gradient: LinearGradient(
      colors: [Color(0xFF5A57FE), Color(0xFF3835B9), Color(0xFF00D9A6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const presets = <AppThemePreset>[
    defaultPreset,
    AppThemePreset(
      id: 'emerald_mint',
      name: 'Emerald Mint',
      primaryColor: Color(0xFF00B894),
      gradient: LinearGradient(
        colors: [Color(0xFF00B894), Color(0xFF00B09B), Color(0xFF96C93D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AppThemePreset(
      id: 'sunset_crimson',
      name: 'Sunset Crimson',
      primaryColor: Color(0xFFFF7675),
      gradient: LinearGradient(
        colors: [Color(0xFFFF7675), Color(0xFFE84393), Color(0xFFFF9F43)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AppThemePreset(
      id: 'cyber_cyan',
      name: 'Cyber Cyan',
      primaryColor: Color(0xFF0984E3),
      gradient: LinearGradient(
        colors: [Color(0xFF0984E3), Color(0xFF6C5CE7), Color(0xFF00CEC9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AppThemePreset(
      id: 'golden_amber',
      name: 'Golden Amber',
      primaryColor: Color(0xFFF39C12),
      gradient: LinearGradient(
        colors: [Color(0xFFF1C40F), Color(0xFFE67E22), Color(0xFFE74C3C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AppThemePreset(
      id: 'deep_indigo',
      name: 'Deep Indigo',
      primaryColor: Color(0xFF4B7BEC),
      gradient: LinearGradient(
        colors: [Color(0xFF3867D6), Color(0xFF4B7BEC), Color(0xFF2D98DA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AppThemePreset(
      id: 'rose_gold',
      name: 'Rose Gold',
      primaryColor: Color(0xFFE84393),
      gradient: LinearGradient(
        colors: [Color(0xFFFD79A8), Color(0xFFE84393), Color(0xFFFFB74D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AppThemePreset(
      id: 'royal_amethyst',
      name: 'Royal Amethyst',
      primaryColor: Color(0xFF8E44AD),
      gradient: LinearGradient(
        colors: [Color(0xFF9B59B6), Color(0xFF8E44AD), Color(0xFF3498DB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  static AppThemePreset getById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => defaultPreset,
    );
  }

  static AppThemePreset getPreset(String id) => getById(id);
}

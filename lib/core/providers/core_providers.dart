/// Core providers for dependency injection.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_my_life/app/theme/app_theme_presets.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/security/security_service.dart';

/// Single database instance for the entire app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Security service provider.
final securityServiceProvider = ChangeNotifierProvider<SecurityService>((ref) {
  return SecurityService();
});

/// Initial value providers (can be overridden before runApp)
final initialColorPresetProvider = Provider<String>((ref) => AppThemePresets.defaultPreset.id);
final initialThemeModeProvider = Provider<String>((ref) => 'dark');
final initialLocaleProvider = Provider<Locale>((ref) => const Locale('ar'));
final initialCurrencyProvider = Provider<String>((ref) => 'DZD');

/// Persistent Theme Color Preset Notifier
class AppColorPresetNotifier extends StateNotifier<String> {
  final FlutterSecureStorage _storage;
  static const _key = 'app_color_preset';

  AppColorPresetNotifier(this._storage, [String? initialValue])
      : super(initialValue ?? AppThemePresets.defaultPreset.id) {
    if (initialValue == null) {
      _loadPreset();
    }
  }

  Future<void> _loadPreset() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && saved.isNotEmpty) {
        super.state = saved;
      }
    } catch (_) {}
  }

  @override
  set state(String value) {
    super.state = value;
    _storage.write(key: _key, value: value);
  }
}

/// App color theme preset provider with persistent storage.
final appColorPresetProvider = StateNotifierProvider<AppColorPresetNotifier, String>((ref) {
  final initial = ref.watch(initialColorPresetProvider);
  return AppColorPresetNotifier(const FlutterSecureStorage(), initial);
});

/// Persistent Theme Mode Notifier ('light', 'dark', 'system')
class ThemeModeNotifier extends StateNotifier<String> {
  final FlutterSecureStorage _storage;
  static const _key = 'theme_mode';

  ThemeModeNotifier(this._storage, [String? initialValue])
      : super(initialValue ?? 'dark') {
    if (initialValue == null) {
      _loadThemeMode();
    }
  }

  Future<void> _loadThemeMode() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && saved.isNotEmpty) {
        super.state = saved;
      }
    } catch (_) {}
  }

  @override
  set state(String value) {
    super.state = value;
    _storage.write(key: _key, value: value);
  }
}

/// Theme mode provider ('light', 'dark', 'system') with persistent storage.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, String>((ref) {
  final initial = ref.watch(initialThemeModeProvider);
  return ThemeModeNotifier(const FlutterSecureStorage(), initial);
});

/// Persistent App Locale Notifier
class AppLocaleNotifier extends StateNotifier<Locale> {
  final FlutterSecureStorage _storage;
  static const _key = 'app_locale';

  AppLocaleNotifier(this._storage, [Locale? initialValue])
      : super(initialValue ?? const Locale('ar')) {
    if (initialValue == null) {
      _loadLocale();
    }
  }

  Future<void> _loadLocale() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && saved.isNotEmpty) {
        super.state = Locale(saved);
      }
    } catch (_) {}
  }

  @override
  set state(Locale value) {
    super.state = value;
    _storage.write(key: _key, value: value.languageCode);
  }
}

/// App locale provider with persistent storage.
final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale>((ref) {
  final initial = ref.watch(initialLocaleProvider);
  return AppLocaleNotifier(const FlutterSecureStorage(), initial);
});

/// Persistent Currency Notifier
class CurrencyNotifier extends StateNotifier<String> {
  final FlutterSecureStorage _storage;
  static const _key = 'current_currency';

  CurrencyNotifier(this._storage, [String? initialValue])
      : super(initialValue ?? 'DZD') {
    if (initialValue == null) {
      _loadCurrency();
    }
  }

  Future<void> _loadCurrency() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && saved.isNotEmpty) {
        super.state = saved;
      }
    } catch (_) {}
  }

  @override
  set state(String value) {
    super.state = value;
    _storage.write(key: _key, value: value);
  }
}

/// Current currency provider with persistent storage.
final currentCurrencyProvider = StateNotifierProvider<CurrencyNotifier, String>((ref) {
  final initial = ref.watch(initialCurrencyProvider);
  return CurrencyNotifier(const FlutterSecureStorage(), initial);
});

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_my_life/app/router/app_router.dart';
import 'package:follow_my_life/app/theme/app_theme.dart';
import 'package:follow_my_life/app/theme/app_theme_presets.dart';
import 'package:follow_my_life/core/constants/app_constants.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Pre-load saved user settings to guarantee instant initial frame rendering without theme flicker
  const storage = FlutterSecureStorage();
  final savedPreset = await storage.read(key: 'app_color_preset');
  final savedThemeMode = await storage.read(key: 'theme_mode');
  final savedLocale = await storage.read(key: 'app_locale');
  final savedCurrency = await storage.read(key: 'current_currency');

  runApp(
    ProviderScope(
      overrides: [
        if (savedPreset != null && savedPreset.isNotEmpty)
          initialColorPresetProvider.overrideWithValue(savedPreset),
        if (savedThemeMode != null && savedThemeMode.isNotEmpty)
          initialThemeModeProvider.overrideWithValue(savedThemeMode),
        if (savedLocale != null && savedLocale.isNotEmpty)
          initialLocaleProvider.overrideWithValue(Locale(savedLocale)),
        if (savedCurrency != null && savedCurrency.isNotEmpty)
          initialCurrencyProvider.overrideWithValue(savedCurrency),
      ],
      child: const FollowMyLifeApp(),
    ),
  );
}

class FollowMyLifeApp extends ConsumerWidget {
  const FollowMyLifeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);
    final themeStr = ref.watch(themeModeProvider);
    final presetId = ref.watch(appColorPresetProvider);
    final preset = AppThemePresets.getById(presetId);

    ThemeMode themeMode;
    if (themeStr == 'light') {
      themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      themeMode = ThemeMode.dark;
    } else {
      themeMode = ThemeMode.system;
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightWithPreset(preset),
      darkTheme: AppTheme.darkWithPreset(preset),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
      ],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

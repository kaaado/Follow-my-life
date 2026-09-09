import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppFast();
    });
  }

  Future<void> _initializeAppFast() async {
    if (!mounted) return;

    try {
      final security = ref.read(securityServiceProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      
      // Fast fetch with 1.5s timeout fallback, run concurrently with security init
      final profileFuture = profileRepo.getProfile().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => Failure(DatabaseFailure('Timeout', 'Initialization timeout')),
      );

      await security.initFuture;

      if (!mounted) return;

      if (security.isLocked) {
        context.go('/lock');
        return;
      }

      final profileResult = await profileFuture;

      if (!mounted) return;

      profileResult.when(
        success: (profile) {
          if (!mounted) return;
          if (profile != null) {
            final currentLocale = ref.read(appLocaleProvider);
            final currentTheme = ref.read(themeModeProvider);

            // Instant sync locale and theme mode
            if (profile.locale.isNotEmpty && currentLocale.languageCode != profile.locale) {
              ref.read(appLocaleProvider.notifier).state = Locale(profile.locale);
            }
            if (profile.themeMode.isNotEmpty && currentTheme != profile.themeMode) {
              ref.read(themeModeProvider.notifier).state = profile.themeMode;
            }
            ref.read(currentCurrencyProvider.notifier).state = profile.currency;
            
            context.go('/');
          } else {
            context.go('/onboarding');
          }
        },
        failure: (_) {
          if (mounted) context.go('/onboarding');
        },
      );
    } catch (_) {
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(appLocaleProvider);
    final isRtl = locale.languageCode == 'ar';

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Brand Icon Ring
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryColor, AppColors.tertiary, AppColors.income],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.trendingUp,
                  color: Colors.white,
                  size: 46,
                ),
              )
                  .animate()
                  .scaleXY(begin: 0.85, end: 1.0, duration: 400.ms, curve: Curves.easeOutCubic)
                  .fadeIn(duration: 300.ms),

              const SizedBox(height: AppSpacing.xl),

              // App Name
              Text(
                context.tr('app_title'),
                style: AppTypography.displayMedium(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.2, end: 0, duration: 250.ms),

              const SizedBox(height: AppSpacing.xs),

              // Tagline
              Text(
                context.tr('app_tagline'),
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: AppSpacing.xxxl),

              // Loading Indicator
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ).animate().fadeIn(duration: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}

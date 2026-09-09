import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentPage = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    final finalName = name.isNotEmpty ? name : context.tr('default_user');

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(profileRepositoryProvider);
      final result = await repo.createProfile(name: finalName);

      result.when(
        success: (_) {
          ref.invalidate(profileProvider);
          if (mounted) context.go('/');
        },
        failure: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.message)),
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _createProfile();
    }
  }

  void _skipToLast() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(3);
    }
    setState(() => _currentPage = 3);
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
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar: Skip Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.trendingUp, size: 18, color: primaryColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('app_title'),
                          style: AppTypography.headlineSmall(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_currentPage < 3)
                      TextButton(
                        onPressed: _skipToLast,
                        child: Text(
                          context.tr('skip'),
                          style: AppTypography.labelLarge(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 40),
                  ],
                ),
              ),

              // Multi-Slide View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _buildSlide1(isDark),
                    _buildSlide2(isDark),
                    _buildSlide3(isDark),
                    _buildSlide4(isDark),
                  ],
                ),
              ),

              // Bottom Control Bar
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page Indicator Dots
                    Row(
                      children: List.generate(4, (index) {
                        final isSelected = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          height: 8,
                          width: isSelected ? 24 : 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    // Navigation Action Button
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentPage == 3) {
                                _createProfile();
                              } else {
                                _nextPage();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == 3 ? context.tr('get_started') : context.tr('next'),
                                  style: AppTypography.labelLarge(color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _currentPage == 3 ? LucideIcons.check : LucideIcons.arrowRight,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 1: Welcome & Total Financial Control
  Widget _buildSlide1(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              child: Image.asset(
                'assets/images/folowmylifebanner.webp',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          AppColors.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.trendingUp,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            context.tr('onboarding_slide1_title'),
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            context.tr('onboarding_slide1_desc'),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureBadge(LucideIcons.shieldCheck, 'Local-First Encryption', isDark),
              _buildFeatureBadge(LucideIcons.zap, 'Zero Latency Ledger', isDark),
              _buildFeatureBadge(LucideIcons.lock, 'Biometric Protected', isDark),
            ],
          ),
        ],
      ),
    );
  }

  // Slide 2: Smart Virtual Envelope Splits
  Widget _buildSlide2(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('create_split'),
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Icon(LucideIcons.pieChart, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
                const Divider(height: 24),
                _buildSplitPreviewRow(context.tr('savings'), '35%', AppColors.income, isDark),
                const SizedBox(height: 8),
                _buildSplitPreviewRow(context.tr('bills'), '45%', AppColors.tertiary, isDark),
                const SizedBox(height: 8),
                _buildSplitPreviewRow(context.tr('emergency_reserve_target'), '20%', Theme.of(context).colorScheme.primary, isDark),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            context.tr('onboarding_slide2_title'),
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            context.tr('onboarding_slide2_desc'),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: Forecast & Purchasing Power Simulator
  Widget _buildSlide3(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.lineChart, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('cash_flow_forecast'),
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBar(40, isDark),
                      _buildBar(55, isDark),
                      _buildBar(70, isDark),
                      _buildBar(85, isDark, active: true),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            context.tr('onboarding_slide3_title'),
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            context.tr('onboarding_slide3_desc'),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Slide 4: Set Up Your Profile & Ledger
  Widget _buildSlide4(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.userCheck, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            context.tr('onboarding_slide4_title'),
            style: AppTypography.headlineMedium(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          Text(
            context.tr('onboarding_slide4_desc'),
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.tr('onboarding_name_label'),
              prefixIcon: const Icon(LucideIcons.user),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createProfile(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTypography.labelSmall(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPreviewRow(String label, String percent, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        Text(
          percent,
          style: AppTypography.labelSmall(color: color).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBar(double height, bool isDark, {bool active = false}) {
    return Container(
      width: 24,
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: active ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

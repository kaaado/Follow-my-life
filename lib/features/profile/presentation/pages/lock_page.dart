import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  final List<String> _pinDigits = [];
  bool _isError = false;
  bool _bioError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
  }

  Future<void> _checkBiometrics() async {
    final security = ref.read(securityServiceProvider);
    if (security.isBiometricsEnabled) {
      final success = await security.authenticateWithBiometrics(
        context.tr('biometric_auth_reason'),
      );
      if (success && mounted) {
        AppFeedback.showSuccess(context, context.tr('unlocked'));
        context.go('/');
      } else if (!success && mounted) {
        setState(() {
          _isError = true;
          _bioError = true;
        });
        AppFeedback.showError(context, context.tr('biometrics_failed'));
      }
    }
  }

  void _onKeyPress(String digit) async {
    if (_pinDigits.length < 4) {
      setState(() {
        _isError = false;
        _bioError = false;
        _pinDigits.add(digit);
      });

      if (_pinDigits.length == 4) {
        final pin = _pinDigits.join();
        final security = ref.read(securityServiceProvider);
        final isValid = await security.verifyPin(pin);

        if (isValid && mounted) {
          AppFeedback.showSuccess(context, context.tr('unlocked'));
          context.go('/');
        } else if (!isValid && mounted) {
          setState(() {
            _isError = true;
            _pinDigits.clear();
          });
          AppFeedback.showError(context, context.tr('pin_incorrect'));
        }
      }
    }
  }

  void _onDelete() {
    if (_pinDigits.isNotEmpty) {
      setState(() {
        _pinDigits.removeLast();
        _isError = false;
        _bioError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final security = ref.watch(securityServiceProvider);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final hasError = _isError || _bioError;
    final activeIconColor = hasError ? AppColors.expense : primaryColor;

    Widget iconWidget = GestureDetector(
      onTap: () {
        setState(() {
          _isError = false;
          _bioError = false;
        });
        _checkBiometrics();
      },
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: activeIconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: activeIconColor.withValues(alpha: hasError ? 0.6 : 0.2),
            width: 2,
          ),
        ),
        child: Icon(
          security.isPinConfigured ? LucideIcons.lock : LucideIcons.fingerprint,
          color: activeIconColor,
          size: 38,
        ),
      ),
    );

    if (hasError) {
      iconWidget = iconWidget.animate().shake(duration: 400.ms, hz: 4);
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                iconWidget,
                const SizedBox(height: AppSpacing.lg),
                Text(
                  security.isPinConfigured
                      ? context.tr('enter_pin_title')
                      : context.tr('biometrics'),
                  style: AppTypography.headlineMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  security.isPinConfigured
                      ? context.tr('app_title')
                      : context.tr('biometric_auth_reason'),
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),

                if (hasError) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.alertCircle, color: AppColors.expense, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _bioError ? context.tr('biometrics_failed') : context.tr('pin_incorrect'),
                          style: AppTypography.bodySmall(color: AppColors.expense),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),

                if (security.isPinConfigured) ...[
                  // PIN Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _pinDigits.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isError
                              ? AppColors.expense
                              : isFilled
                                  ? primaryColor
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          border: Border.all(
                            color: _isError ? AppColors.expense : primaryColor,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),

                  const Spacer(),

                  // Numeric Keypad
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.4,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index == 9) {
                        return security.isBiometricsEnabled
                            ? IconButton(
                                icon: Icon(LucideIcons.fingerprint, size: 28, color: primaryColor),
                                onPressed: () {
                                  setState(() {
                                    _isError = false;
                                    _bioError = false;
                                  });
                                  _checkBiometrics();
                                },
                              )
                            : const SizedBox.shrink();
                      }
                      if (index == 10) {
                        return _buildKeypadButton('0');
                      }
                      if (index == 11) {
                        return IconButton(
                          icon: Icon(
                            LucideIcons.delete,
                            size: 24,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          onPressed: _onDelete,
                        );
                      }
                      return _buildKeypadButton('${index + 1}');
                    },
                  ),
                ] else ...[
                  // Biometrics-only Unlock Button
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isError = false;
                        _bioError = false;
                      });
                      _checkBiometrics();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                    ),
                    icon: const Icon(LucideIcons.fingerprint, size: 24),
                    label: Text(
                      context.tr('unlock'),
                      style: AppTypography.labelLarge(color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                ],

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: AppTypography.headlineSmall(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Elevated glassmorphic bottom navigation shell widget.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/plan')) return 2;
    if (location.startsWith('/sources')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final activeIndex = _currentIndex(context);

    final navItems = [
      (path: '/', icon: LucideIcons.home, labelKey: 'home'),
      (path: '/transactions', icon: LucideIcons.arrowLeftRight, labelKey: 'activity'),
      (path: '/plan', icon: LucideIcons.clipboardList, labelKey: 'plan'),
      (path: '/sources', icon: LucideIcons.wallet, labelKey: 'sources'),
      (path: '/profile', icon: LucideIcons.user, labelKey: 'profile'),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Main screen content with padding for floating bar
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: child,
            ),
          ),

          // Floating Glassmorphic Navigation Bar
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.sm,
            child: SafeArea(
              top: false,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface.withValues(alpha: 0.82)
                            : AppColors.lightSurface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.6)
                              : AppColors.lightBorder.withValues(alpha: 0.8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(navItems.length, (index) {
                          final item = navItems[index];
                          final isSelected = activeIndex == index;

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (activeIndex != index) {
                                  context.go(item.path);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primary.withValues(alpha: isDark ? 0.18 : 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 20,
                                      color: isSelected
                                          ? primary
                                          : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.tr(item.labelKey),
                                      style: AppTypography.labelSmall(
                                        color: isSelected
                                            ? primary
                                            : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                      ).copyWith(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

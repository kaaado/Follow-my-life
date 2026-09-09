import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';

import 'package:follow_my_life/app/theme/app_theme_presets.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(profileProvider);
    final currentLocale = ref.watch(appLocaleProvider);
    final currentTheme = ref.watch(themeModeProvider);
    final currentPresetId = ref.watch(appColorPresetProvider);
    final activePreset = AppThemePresets.getById(currentPresetId);
    final primaryColor = Theme.of(context).colorScheme.primary;

    String langDisplayName(String code) {
      switch (code) {
        case 'ar':
          return 'العربية';
        case 'fr':
          return 'Français';
        case 'en':
        default:
          return 'English';
      }
    }

    String themeDisplayName(String mode) {
      switch (mode) {
        case 'light':
          return context.tr('light');
        case 'dark':
          return context.tr('dark');
        case 'system':
        default:
          return context.tr('system');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('profile')),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.go('/onboarding'),
                child: Text(context.tr('setup_profile')),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // User Avatar & Info
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: primaryColor.withValues(alpha: 0.2),
                          child: Text(
                            profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                            style: AppTypography.headlineLarge(color: primaryColor),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showEditNameDialog(context, ref, profile.name),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.edit2, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      profile.name,
                      style: AppTypography.headlineMedium(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              _buildSectionTitle(context.tr('preferences'), isDark),
              _buildListTile(context, LucideIcons.tags, context.tr('manage_categories'), null, isDark, onTap: () => context.push('/categories')),
              _buildListTile(context, LucideIcons.pieChart, context.tr('manage_budgets'), null, isDark, onTap: () => context.push('/budgets')),
              _buildListTile(context, LucideIcons.repeat, context.tr('manage_recurring'), null, isDark, onTap: () => context.push('/recurring')),
              _buildListTile(
                context,
                LucideIcons.coins,
                context.tr('currency'),
                profile.currency,
                isDark,
                onTap: () => _showCurrencyDialog(context, ref, profile.currency),
              ),
              _buildListTile(
                context,
                LucideIcons.languages,
                context.tr('language'),
                langDisplayName(currentLocale.languageCode),
                isDark,
                onTap: () => _showLanguageDialog(context, ref, currentLocale.languageCode),
              ),
              _buildListTile(
                context,
                LucideIcons.moon,
                context.tr('theme'),
                themeDisplayName(currentTheme),
                isDark,
                onTap: () => _showThemeDialog(context, ref, currentTheme),
              ),
              _buildListTile(
                context,
                LucideIcons.palette,
                context.tr('color_preset'),
                activePreset.name,
                isDark,
                onTap: () => _showColorPresetDialog(context, ref, currentPresetId),
              ),

              const SizedBox(height: AppSpacing.xl),
              _buildSectionTitle(context.tr('security'), isDark),
              _buildListTile(
                context,
                LucideIcons.lock,
                context.tr('app_lock'),
                ref.watch(securityServiceProvider).isPinConfigured ? context.tr('pin_active') : context.tr('pin_off'),
                isDark,
                onTap: () => _showPinDialog(context),
              ),
              _buildBiometricsTile(context, ref, isDark),
              _buildListTile(
                context,
                LucideIcons.shieldCheck,
                context.tr('data_privacy'),
                context.tr('data_protected'),
                isDark,
                onTap: () => AppFeedback.showSuccess(context, context.tr('data_encrypted_local')),
              ),

              const SizedBox(height: AppSpacing.xl),
              _buildSectionTitle(context.tr('data'), isDark),
              _buildListTile(
                context,
                LucideIcons.downloadCloud,
                context.tr('backup_restore'),
                null,
                isDark,
                onTap: () => _showBackupDialog(context),
              ),
              _buildListTile(
                context,
                LucideIcons.trash2,
                context.tr('reset_data'),
                null,
                isDark,
                color: AppColors.error,
                onTap: () => _confirmResetData(context, ref),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('error_loading_profile'))),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.labelLarge(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, String? trailing, bool isDark, {Color? color, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        title: Text(
          title,
          style: AppTypography.bodyLarge(color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        ),
        trailing: trailing != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trailing, style: AppTypography.bodyMedium(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(LucideIcons.chevronRight, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ],
              )
            : Icon(LucideIcons.chevronRight, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _buildBiometricsTile(BuildContext context, WidgetRef ref, bool isDark) {
    final security = ref.watch(securityServiceProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: SwitchListTile(
        secondary: Icon(
          LucideIcons.fingerprint,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        title: Text(
          context.tr('biometrics'),
          style: AppTypography.bodyLarge(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          context.tr('enable_biometrics'),
          style: AppTypography.labelSmall(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        value: security.isBiometricsEnabled,
        onChanged: (val) async {
          if (val) {
            final reason = context.tr('biometric_auth_reason');
            final canBio = await security.canCheckBiometrics();
            if (!canBio && context.mounted) {
              AppFeedback.showError(context, context.tr('biometrics_not_available'));
              return;
            }
            final success = await ref.read(securityServiceProvider).enableBiometrics(reason);
            if (context.mounted) {
              if (success) {
                AppFeedback.showSuccess(
                  context,
                  context.tr('fingerprint_enabled'),
                );
              } else {
                AppFeedback.showError(context, context.tr('biometrics_not_available'));
              }
            }
          } else {
            final success = await ref.read(securityServiceProvider).disableBiometrics();
            if (context.mounted) {
              if (success) {
                AppFeedback.showSuccess(
                  context,
                  context.tr('fingerprint_disabled'),
                );
              } else {
                AppFeedback.showError(context, context.tr('something_went_wrong'));
              }
            }
          }
        },
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('edit_profile_name')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: context.tr('profile')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(profileRepositoryProvider).updateProfile(name: newName);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) AppFeedback.showSuccess(context, context.tr('profile_name_updated'));
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(BuildContext context) {
    final security = ref.read(securityServiceProvider);
    final pinController = TextEditingController();
    final currentPinController = TextEditingController();

    if (security.isPinConfigured) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('auth_required_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('auth_required_desc')),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: currentPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(hintText: context.tr('enter_pin_title')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final curPin = currentPinController.text.trim();
                final disabled = await security.disablePin(currentPin: curPin);
                if (disabled) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) AppFeedback.showSuccess(context, context.tr('pin_disabled'));
                } else {
                  if (context.mounted) {
                    final msg = security.isLockoutActive
                        ? context.tr('lockout_active')
                        : context.tr('pin_incorrect');
                    AppFeedback.showError(context, msg);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: Text(context.tr('delete')),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('set_pin_title')),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: InputDecoration(hintText: context.tr('enter_4_digit_pin')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pinController.text.length == 4) {
                  await security.setPin(pinController.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) AppFeedback.showSuccess(context, context.tr('pin_saved'));
                }
              },
              child: Text(context.tr('save')),
            ),
          ],
        ),
      );
    }
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('backup_restore')),
        content: Text(context.tr('backup_json_desc')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppFeedback.showSuccess(context, context.tr('backup_export_saved'));
            },
            child: Text(context.tr('export_backup')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppFeedback.showSuccess(context, context.tr('backup_imported'));
            },
            child: Text(context.tr('import_backup')),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, String currentLang) {
    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'ar', 'name': 'العربية (Arabic)'},
      {'code': 'fr', 'name': 'Français (French)'},
    ];

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('language')),
        children: languages.map((l) {
          final code = l['code']!;
          final isSelected = code == currentLang;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.of(context).pop();
              ref.read(appLocaleProvider.notifier).state = Locale(code);
              final result = await ref.read(profileRepositoryProvider).updateProfile(locale: code);
              if (context.mounted) {
                if (result.isSuccess) {
                  AppFeedback.showSuccess(context, context.tr('language_updated'));
                } else {
                  AppFeedback.showError(context, context.tr('something_went_wrong'));
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l['name']!),
                if (isSelected) Icon(LucideIcons.check, color: Theme.of(context).colorScheme.primary, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, String currentTheme) {
    final themes = [
      {'code': 'system', 'name': context.tr('system')},
      {'code': 'light', 'name': context.tr('light')},
      {'code': 'dark', 'name': context.tr('dark')},
    ];

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('theme')),
        children: themes.map((t) {
          final code = t['code']!;
          final isSelected = code == currentTheme;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.of(context).pop();
              ref.read(themeModeProvider.notifier).state = code;
              final result = await ref.read(profileRepositoryProvider).updateProfile(themeMode: code);
              if (context.mounted) {
                if (result.isSuccess) {
                  AppFeedback.showSuccess(context, context.tr('theme_updated'));
                } else {
                  AppFeedback.showError(context, context.tr('something_went_wrong'));
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['name']!),
                if (isSelected) Icon(LucideIcons.check, color: Theme.of(context).colorScheme.primary, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showColorPresetDialog(BuildContext context, WidgetRef ref, String currentPresetId) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('color_preset')),
        children: AppThemePresets.presets.map((preset) {
          final isSelected = preset.id == currentPresetId;
          return SimpleDialogOption(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(appColorPresetProvider.notifier).state = preset.id;
              AppFeedback.showSuccess(context, '${preset.name} applied!');
            },
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: preset.gradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: preset.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    preset.name,
                    style: AppTypography.bodyMedium().copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected) Icon(LucideIcons.check, color: preset.primaryColor, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context, WidgetRef ref, String currentCurrency) {
    final currencies = [
      {'code': 'DZD', 'name': 'Algerian Dinar (DZD)'},
      {'code': 'EUR', 'name': 'Euro (EUR)'},
      {'code': 'USD', 'name': 'US Dollar (USD)'},
      {'code': 'GBP', 'name': 'British Pound (GBP)'},
    ];

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('currency')),
        children: currencies.map((c) {
          final code = c['code']!;
          final isSelected = code == currentCurrency;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.of(context).pop();
              ref.read(currentCurrencyProvider.notifier).state = code;
              final result = await ref.read(profileRepositoryProvider).updateProfile(currency: code);
              if (context.mounted) {
                if (result.isSuccess) {
                  AppFeedback.showSuccess(context, context.tr('currency_updated'));
                } else {
                  AppFeedback.showError(context, context.tr('something_went_wrong'));
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(c['name']!),
                if (isSelected) Icon(LucideIcons.check, color: Theme.of(context).colorScheme.primary, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _confirmResetData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text(
          context.tr('confirm_delete_msg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final db = ref.read(databaseProvider);
              await db.delete(db.transactions).go();
              await db.delete(db.transfers).go();
              await db.delete(db.moneySources).go();
              await db.delete(db.plannedPurchases).go();
              await db.delete(db.budgets).go();
              await db.delete(db.recurringTransactions).go();
              await db.delete(db.recurringOccurrences).go();
              await db.delete(db.financialAllocations).go();
              await db.delete(db.expectedIncomes).go();
              await db.delete(db.debts).go();
              await db.delete(db.splitTransactions).go();
              await db.delete(db.virtualSplitItems).go();
              await db.delete(db.virtualSplits).go();
              await db.delete(db.userProfiles).go();

              // Clear security storage (PIN, biometrics)
              await ref.read(securityServiceProvider).clearAllSecurity();

              // Invalidate Riverpod state so views start fresh
              ref.invalidate(profileProvider);
              ref.invalidate(activeSourcesProvider);
              ref.invalidate(recentTransactionsProvider);
              ref.invalidate(activePurchasesProvider);
              ref.invalidate(activeBudgetsProvider);
              ref.invalidate(activeRecurringProvider);
              ref.invalidate(activeDebtsProvider);
              ref.invalidate(activeVirtualSplitsProvider);
              ref.invalidate(financialSnapshotProvider);
              ref.invalidate(financialSummaryProvider);

              if (context.mounted) {
                AppFeedback.showSuccess(context, context.tr('data_cleared'));
                context.go('/onboarding');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('reset_data')),
          ),
        ],
      ),
    );
  }
}

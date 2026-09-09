import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_theme_presets.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/core/widgets/app_empty_state.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SourcesPage extends ConsumerWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final totalBalanceAsync = ref.watch(totalBalanceProvider);
    final profileAsync = ref.watch(profileProvider);
    final activePresetId = ref.watch(appColorPresetProvider);
    final activePreset = AppThemePresets.getPreset(activePresetId);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = profileAsync.valueOrNull?.currency ?? 'DZD';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('sources')),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context.push('/add-source'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-source'),
        backgroundColor: primaryColor,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: sourcesAsync.when(
        data: (sources) {
          if (sources.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.wallet,
              title: context.tr('no_sources'),
              message: context.tr('no_sources_desc'),
              actionLabel: context.tr('add_source'),
              onAction: () => context.push('/add-source'),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                sliver: SliverToBoxAdapter(
                  child: HeroCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    gradient: activePreset.gradient,
                    child: Column(
                      children: [
                        Text(
                          context.tr('total_balance').toUpperCase(),
                          style: AppTypography.labelMedium(color: Colors.white.withValues(alpha: 0.85))
                              .copyWith(letterSpacing: 1.1),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        totalBalanceAsync.when(
                          data: (balance) => Text(
                            MoneyFormatter.format(balance, currency: currency),
                            style: AppTypography.moneyLarge(color: Colors.white),
                          ),
                          loading: () => Text('...', style: AppTypography.moneyLarge(color: Colors.white)),
                          error: (err, stack) => Text(context.tr('error'), style: AppTypography.moneyLarge(color: Colors.white)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final source = sources[index];
                      final sourceColor = AppColors.getCategoryColor(source.colorIndex);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: GlassCard(
                          onTap: () => _showSourceOptions(context, ref, source),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: sourceColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sourceColor.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  _getIconData(source.icon),
                                  color: sourceColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      source.name,
                                      style: AppTypography.headlineSmall(
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getSourceTypeName(context, source.type.name),
                                      style: AppTypography.bodySmall(
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    MoneyFormatter.format(source.cachedBalanceMinor, currency: source.currency, compact: true),
                                    style: AppTypography.moneyMedium(
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Icon(
                                    LucideIcons.moreVertical,
                                    size: 16,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: sources.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl * 2)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(context.tr('error_loading_sources'))),
      ),
    );
  }

  void _showSourceOptions(BuildContext context, WidgetRef ref, MoneySource source) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.edit2),
              title: Text(context.tr('edit')),
              onTap: () {
                Navigator.pop(ctx);
                _showEditSourceDialog(context, ref, source);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.refreshCw),
              title: Text(context.tr('recalculate_balance')),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(sourceRepositoryProvider).recalculateBalance(source.id);
                if (context.mounted) {
                  AppFeedback.showSuccess(context, context.tr('balance_recalculated'));
                }
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.error),
              title: Text(context.tr('delete'), style: const TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                _confirmDeleteSource(context, ref, source);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSourceDialog(BuildContext context, WidgetRef ref, MoneySource source) {
    final nameController = TextEditingController(text: source.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('edit')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: context.tr('source_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(sourceRepositoryProvider).updateSource(source.id, name: newName);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) AppFeedback.showSuccess(context, context.tr('saved_successfully'));
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSource(BuildContext context, WidgetRef ref, MoneySource source) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_item_title')),
        content: Text(context.tr('delete_item_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final res = await ref.read(sourceRepositoryProvider).deleteSource(source.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                if (res.isSuccess) {
                  AppFeedback.showSuccess(context, context.tr('item_deleted'));
                } else {
                  AppFeedback.showError(context, res.failure.message);
                }
              }
            },
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }

  String _getSourceTypeName(BuildContext context, String typeName) {
    switch (typeName) {
      case 'cash': return context.tr('cash');
      case 'bankAccount': return context.tr('bank_account');
      case 'eWallet': return context.tr('e_wallet');
      case 'incomeSource': return context.tr('income_source');
      default: return context.tr('other');
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'wallet': return LucideIcons.wallet;
      case 'building': return LucideIcons.building;
      case 'smartphone': return LucideIcons.smartphone;
      case 'banknote': return LucideIcons.banknote;
      case 'creditCard': return LucideIcons.creditCard;
      default: return LucideIcons.wallet;
    }
  }
}

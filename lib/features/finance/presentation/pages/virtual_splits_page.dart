import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VirtualSplitsPage extends ConsumerWidget {
  const VirtualSplitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAsync = ref.watch(activeVirtualSplitsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('virtual_splits')),
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context.push('/create-virtual-split'),
          ),
        ],
      ),
      body: splitsAsync.when(
        data: (splits) {
          if (splits.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.gitFork,
                      size: 64,
                      color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('virtual_splits'),
                      style: AppTypography.headlineMedium(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.tr('split_description'),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/create-virtual-split'),
                      icon: const Icon(LucideIcons.plus),
                      label: Text(context.tr('create_split')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: splits.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = splits[index];
              final split = item.split;
              final source = item.source;
              final categoriesAsync = ref.watch(activeCategoriesProvider);
              final categoriesMap = {
                for (var cat in categoriesAsync.valueOrNull ?? []) cat.id: cat.name
              };

              return GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.gitFork, color: AppColors.tertiary, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  split.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.headlineSmall(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (source != null)
                                  Text(
                                    source.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall(
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                MoneyFormatter.format(split.totalAmountMinor, currency: split.currency),
                                style: AppTypography.headlineSmall(
                                  color: AppColors.tertiary,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, height: 1),
                      const SizedBox(height: AppSpacing.md),

                      // Category Item Breakdowns
                      ...item.items.map((line) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    categoriesMap[line.categoryId] ?? context.tr('category'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  MoneyFormatter.format(line.amountMinor, currency: split.currency),
                                  style: AppTypography.bodyMedium(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )),

                      const SizedBox(height: AppSpacing.lg),

                      // Action Buttons (Apply / Cancel)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final repo = ref.read(virtualSplitRepositoryProvider);
                                await repo.cancelVirtualSplit(split.id);
                                if (context.mounted) {
                                  AppFeedback.showSuccess(context, context.tr('split_cancelled'));
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.expense,
                                side: const BorderSide(color: AppColors.expense),
                              ),
                              child: Text(context.tr('cancel')),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(context.tr('apply_split')),
                                    content: Text(context.tr('confirm_apply_split')),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text(context.tr('cancel')),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                        child: Text(context.tr('submit')),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final repo = ref.read(virtualSplitRepositoryProvider);
                                  final success = await repo.applyVirtualSplit(split.id);
                                  if (context.mounted) {
                                    if (success) {
                                      AppFeedback.showSuccess(context, context.tr('split_applied_success'));
                                    } else {
                                      AppFeedback.showError(context, context.tr('insufficient_funds_split'));
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(context.tr('apply_split')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('error_loading_splits'))),
      ),
    );
  }
}

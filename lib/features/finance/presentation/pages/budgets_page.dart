import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(activeBudgetsProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoriesMap = categoriesAsync.valueOrNull != null
        ? {for (var c in categoriesAsync.valueOrNull!) c.id: c.name}
        : <String, String>{};

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('budgets')),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context.push('/add-budget'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-budget'),
        backgroundColor: primaryColor,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.pieChart, size: 64, color: primaryColor.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.tr('no_active_budgets'),
                    style: AppTypography.headlineMedium(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('budget_desc'),
                    style: AppTypography.bodyMedium(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  IconButton(
                    onPressed: () => context.push('/add-budget'),
                    icon: Icon(LucideIcons.plus, size: 32, color: primaryColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final b = budgets[index];
              final categoryName = categoriesMap[b.categoryId] ?? context.tr('category');

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.pieChart, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryName,
                              style: AppTypography.headlineSmall(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            ),
                            Text(
                              context.tr('monthly_limit'),
                              style: AppTypography.bodySmall(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          MoneyFormatter.format(b.amountMinor, currency: b.currency),
                          style: AppTypography.headlineSmall(color: primaryColor),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            LucideIcons.moreVertical,
                            size: 18,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          padding: EdgeInsets.zero,
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(context.tr('delete_budget')),
                                  content: Text(context.tr('delete_budget_confirm')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: Text(context.tr('cancel')),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                      child: Text(context.tr('delete')),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true && context.mounted) {
                                final res = await ref.read(budgetRepositoryProvider).deleteBudget(b.id);
                                if (context.mounted) {
                                  if (res.isSuccess) {
                                    ref.invalidate(activeBudgetsProvider);
                                    AppFeedback.showSuccess(context, context.tr('item_deleted'));
                                  } else {
                                    AppFeedback.showError(context, res.failure.message);
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    context.tr('delete_budget'),
                                    style: AppTypography.bodyMedium(color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('error_loading_budgets'))),
      ),
    );
  }
}

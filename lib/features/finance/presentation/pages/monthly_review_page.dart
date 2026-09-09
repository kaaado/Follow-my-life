import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/features/finance/domain/services/financial_health_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MonthlyReviewPage extends ConsumerWidget {
  const MonthlyReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(financialSummaryProvider);
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final debtsAsync = ref.watch(activeDebtsProvider);
    final profileAsync = ref.watch(profileProvider);
    final currency = profileAsync.valueOrNull?.currency ?? 'DZD';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('monthly_financial_review')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header
            Text(
              context.tr('monthly_review_summary'),
              style: AppTypography.headlineMedium(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('monthly_review_desc'),
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            summaryAsync.when(
              data: (summary) {
                final totalIncome = summary.totalIncome;
                final totalExpenses = summary.totalExpenses;
                final netSavings = totalIncome - totalExpenses;
                final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100).toStringAsFixed(1) : '0';

                return Column(
                  children: [
                    // Financial Health Metric Card
                    sourcesAsync.when(
                      data: (sources) {
                        final totalAssets = sources.fold<int>(0, (sum, s) => sum + s.cachedBalanceMinor);
                        final totalDebts = debtsAsync.valueOrNull?.fold<int>(0, (sum, d) => sum + (d.amountMinor - d.paidAmountMinor)) ?? 0;

                        final health = FinancialHealthService.calculateHealth(
                          totalAssetsMinor: totalAssets,
                          totalMonthlyIncomeMinor: totalIncome,
                          totalMonthlyExpensesMinor: totalExpenses,
                          totalDebtsMinor: totalDebts,
                        );

                        return GlassCard(
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: health.score >= 70
                                      ? AppColors.income.withValues(alpha: 0.2)
                                      : AppColors.warning.withValues(alpha: 0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${health.score}',
                                    style: AppTypography.headlineMedium(
                                      color: health.score >= 70 ? AppColors.income : AppColors.warning,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${context.tr('health_score_label')}: ${health.rating}',
                                      style: AppTypography.labelLarge(
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      health.recommendations.first,
                                      style: AppTypography.bodySmall(
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Metrics Breakdown
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            title: context.tr('total_income'),
                            amount: totalIncome,
                            currency: currency,
                            icon: LucideIcons.arrowDownToLine,
                            color: AppColors.income,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            title: context.tr('total_expenses'),
                            amount: totalExpenses,
                            currency: currency,
                            icon: LucideIcons.arrowUpFromLine,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('net_savings'),
                            style: AppTypography.labelSmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            MoneyFormatter.format(netSavings, currency: currency),
                            style: AppTypography.headlineLarge(
                              color: netSavings >= 0 ? AppColors.income : AppColors.expense,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${context.tr('savings_rate')}: $savingsRate%',
                            style: AppTypography.bodyMedium(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text(context.tr('error_loading_summary')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required int amount,
    required String currency,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelSmall(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            MoneyFormatter.format(amount, currency: currency),
            style: AppTypography.headlineSmall(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

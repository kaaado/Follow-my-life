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
import 'package:follow_my_life/features/finance/domain/services/forecast_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ForecastPage extends ConsumerStatefulWidget {
  const ForecastPage({super.key});

  @override
  ConsumerState<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends ConsumerState<ForecastPage> {
  int _horizonDays = 30; // Options: 7, 30, 90, 180, 365

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final debtsAsync = ref.watch(activeDebtsProvider);
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('cash_flow_forecast')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Horizon Selection Toggle
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7D')),
                ButtonSegment(value: 30, label: Text('30D')),
                ButtonSegment(value: 90, label: Text('3M')),
                ButtonSegment(value: 180, label: Text('6M')),
                ButtonSegment(value: 365, label: Text('1Y')),
              ],
              selected: {_horizonDays},
              onSelectionChanged: (set) {
                setState(() {
                  _horizonDays = set.first;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Combine Async States to build forecast
            sourcesAsync.when(
              data: (sources) {
                final startingBalance = sources.fold<int>(0, (sum, s) => sum + s.cachedBalanceMinor);

                return recurringAsync.when(
                  data: (recurring) {
                    return debtsAsync.when(
                      data: (debts) {
                        return purchasesAsync.when(
                          data: (purchases) {
                            final result = ForecastService.generateForecast(
                              startingBalanceMinor: startingBalance,
                              recurringTxns: recurring,
                              activeDebts: debts,
                              plannedPurchases: purchases,
                              horizonDays: _horizonDays,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Projection Summary Card
                                GlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${context.tr('projected_balance')} ($_horizonDays ${context.tr('days')})',
                                        style: AppTypography.labelMedium(
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        MoneyFormatter.format(result.projectedEndingBalanceMinor),
                                        style: AppTypography.headlineLarge(
                                          color: result.netChangeMinor >= 0 ? AppColors.income : AppColors.expense,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Row(
                                        children: [
                                          Icon(
                                            result.netChangeMinor >= 0
                                                ? LucideIcons.trendingUp
                                                : LucideIcons.trendingDown,
                                            size: 16,
                                            color: result.netChangeMinor >= 0 ? AppColors.income : AppColors.expense,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${context.tr('net_change')}: ${MoneyFormatter.format(result.netChangeMinor)}',
                                            style: AppTypography.bodySmall(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                Text(
                                  context.tr('forecast_timeline'),
                                  style: AppTypography.headlineSmall(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Timeline list
                                ...result.points.map((pt) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                    child: ListTile(
                                      title: Text(
                                        '${pt.date.day}/${pt.date.month}/${pt.date.year}',
                                        style: AppTypography.bodyMedium(
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: (pt.expectedIncomeMinor > 0 || pt.expectedExpenseMinor > 0)
                                          ? Text(
                                              '${context.tr('forecast_in')}: +${MoneyFormatter.format(pt.expectedIncomeMinor)} | ${context.tr('forecast_out')}: -${MoneyFormatter.format(pt.expectedExpenseMinor)}',
                                              style: AppTypography.bodySmall(
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              ),
                                            )
                                          : Text(
                                              context.tr('no_movements'),
                                              style: AppTypography.bodySmall(
                                                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                              ),
                                            ),
                                      trailing: Text(
                                        MoneyFormatter.format(pt.projectedBalanceMinor),
                                        style: AppTypography.labelLarge(
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (err, stack) => Text(context.tr('error_loading_plans')),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (err, stack) => Text(context.tr('error_loading_debts')),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text(context.tr('error_loading_recurring')),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text(context.tr('error_loading_sources')),
            ),
          ],
        ),
      ),
    );
  }
}

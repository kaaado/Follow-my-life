import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum ReportPeriod {
  thisMonth('this_month'),
  lastMonth('last_month'),
  thisYear('this_year');

  final String labelKey;
  const ReportPeriod(this.labelKey);
}

final reportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.thisMonth);

final reportSummaryProvider = FutureProvider.family<({int totalIncome, int totalExpenses, int netCashFlow}), ReportPeriod>((ref, period) async {
  ref.watch(recentTransactionsProvider);
  final now = DateTime.now();
  DateTime from;
  DateTime to;

  switch (period) {
    case ReportPeriod.thisMonth:
      from = DateHelper.startOfMonth(now);
      to = DateHelper.endOfMonth(now);
      break;
    case ReportPeriod.lastMonth:
      final prev = DateTime(now.year, now.month - 1, 15);
      from = DateHelper.startOfMonth(prev);
      to = DateHelper.endOfMonth(prev);
      break;
    case ReportPeriod.thisYear:
      from = DateTime(now.year, 1, 1);
      to = DateTime(now.year, 12, 31, 23, 59, 59);
      break;
  }

  final repo = ref.watch(transactionRepositoryProvider);
  final res = await repo.getPeriodSummary(from: from, to: to);
  return res.when(
    success: (data) => (
      totalIncome: data.totalIncome,
      totalExpenses: data.totalExpenses,
      netCashFlow: data.totalIncome - data.totalExpenses,
    ),
    failure: (_) => (totalIncome: 0, totalExpenses: 0, netCashFlow: 0),
  );
});

final reportCategorySpendingProvider = FutureProvider.family<Map<String, int>, ReportPeriod>((ref, period) async {
  ref.watch(recentTransactionsProvider);
  final now = DateTime.now();
  DateTime from;
  DateTime to;

  switch (period) {
    case ReportPeriod.thisMonth:
      from = DateHelper.startOfMonth(now);
      to = DateHelper.endOfMonth(now);
      break;
    case ReportPeriod.lastMonth:
      final prev = DateTime(now.year, now.month - 1, 15);
      from = DateHelper.startOfMonth(prev);
      to = DateHelper.endOfMonth(prev);
      break;
    case ReportPeriod.thisYear:
      from = DateTime(now.year, 1, 1);
      to = DateTime(now.year, 12, 31, 23, 59, 59);
      break;
  }

  final repo = ref.watch(transactionRepositoryProvider);
  final res = await repo.getCategorySpending(from: from, to: to);
  return res.when(
    success: (data) => data,
    failure: (_) => {},
  );
});

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final summaryAsync = ref.watch(reportSummaryProvider(period));
    final categorySpendingAsync = ref.watch(reportCategorySpendingProvider(period));
    final categoriesAsync = ref.watch(categoriesProvider);
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final profileAsync = ref.watch(profileProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final currency = profileAsync.valueOrNull?.currency ?? 'DZD';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final themeChartColors = [
      primaryColor,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.income,
      AppColors.expense,
      AppColors.transfer,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('reports')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),

            // Period Selector Chips
            Row(
              children: ReportPeriod.values.map((p) {
                final isSelected = period == p;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(context.tr(p.labelKey)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(reportPeriodProvider.notifier).state = p;
                      }
                    },
                    labelStyle: AppTypography.labelMedium(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    selectedColor: primaryColor,
                    backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Key Financial Summary Metrics
            summaryAsync.when(
              data: (summary) {
                final income = summary.totalIncome;
                final expenses = summary.totalExpenses;
                final net = summary.netCashFlow;
                final savingsRate = income > 0 ? ((net / income) * 100).clamp(0, 100).toDouble() : 0.0;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: context.tr('income'),
                            amountMinor: income,
                            currency: currency,
                            color: AppColors.income,
                            icon: LucideIcons.trendingUp,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: context.tr('expenses'),
                            amountMinor: expenses,
                            currency: currency,
                            color: AppColors.expense,
                            icon: LucideIcons.trendingDown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: context.tr('net_cash_flow'),
                            amountMinor: net,
                            currency: currency,
                            color: net >= 0 ? AppColors.income : AppColors.expense,
                            icon: LucideIcons.scale,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('savings_rate'),
                                  style: AppTypography.labelSmall(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${savingsRate.toStringAsFixed(1)}%',
                                  style: AppTypography.moneyMedium(color: primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text(context.tr('error_loading_summary')),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Cash Flow Bar Chart (Income vs Expenses)
            Text(
              context.tr('income_vs_expenses'),
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            summaryAsync.when(
              data: (summary) {
                final incomeMajor = (summary.totalIncome / 100).toDouble();
                final expenseMajor = (summary.totalExpenses / 100).toDouble();
                final maxVal = incomeMajor > expenseMajor ? incomeMajor : expenseMajor;
                final maxY = maxVal > 0 ? maxVal * 1.25 : 100.0;

                return GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            minY: 0,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final title = groupIndex == 0 ? context.tr('income') : context.tr('expenses');
                                  final amountMinor = groupIndex == 0 ? summary.totalIncome : summary.totalExpenses;
                                  return BarTooltipItem(
                                    '$title\n${MoneyFormatter.format(amountMinor, currency: currency)}',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    switch (val.toInt()) {
                                      case 0:
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            context.tr('income'),
                                            style: TextStyle(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      case 1:
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            context.tr('expenses'),
                                            style: TextStyle(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      default:
                                        return const Text('');
                                    }
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              BarChartGroupData(
                                x: 0,
                                barRods: [
                                  BarChartRodData(
                                    toY: incomeMajor,
                                    color: AppColors.income,
                                    width: 36,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  ),
                                ],
                              ),
                              BarChartGroupData(
                                x: 1,
                                barRods: [
                                  BarChartRodData(
                                    toY: expenseMajor,
                                    color: AppColors.expense,
                                    width: 36,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: AppColors.income, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${context.tr('income')}: ${MoneyFormatter.format(summary.totalIncome, currency: currency)}',
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${context.tr('expenses')}: ${MoneyFormatter.format(summary.totalExpenses, currency: currency)}',
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const GlassCard(
                child: SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (err, stack) => GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: Text(context.tr('error_loading_summary'))),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Money Sources vs Expenses Allocation Chart
            Text(
              context.tr('sources'),
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            sourcesAsync.when(
              data: (sources) {
                if (sources.isEmpty) {
                  return GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: Text(context.tr('no_sources'))),
                    ),
                  );
                }

                final totalSourcesBalance = sources.fold<int>(0, (sum, s) => sum + s.cachedBalanceMinor);
                int colorIndex = 0;
                final sourceBarGroups = <BarChartGroupData>[];
                final sourceLegend = <Widget>[];

                for (int i = 0; i < sources.length; i++) {
                  final source = sources[i];
                  final color = themeChartColors[colorIndex % themeChartColors.length];
                  colorIndex++;

                  sourceBarGroups.add(
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (source.cachedBalanceMinor / 100).toDouble(),
                          color: color,
                          width: 24,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ],
                    ),
                  );

                  final pct = totalSourcesBalance > 0
                      ? (source.cachedBalanceMinor / totalSourcesBalance) * 100
                      : 0.0;

                  sourceLegend.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              source.name,
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(0)}% • ${MoneyFormatter.format(source.cachedBalanceMinor, currency: currency)}',
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final maxSourceY = sources.isEmpty
                    ? 1000.0
                    : (sources.map((s) => s.cachedBalanceMinor).reduce((a, b) => a > b ? a : b) / 100) * 1.25 + 10;

                return GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxSourceY,
                            minY: 0,
                            barTouchData: BarTouchData(enabled: true),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx >= 0 && idx < sources.length) {
                                      return Text(
                                        sources[idx].name.length > 8
                                            ? '${sources[idx].name.substring(0, 7)}…'
                                            : sources[idx].name,
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: sourceBarGroups,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.md),
                      ...sourceLegend,
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text(context.tr('error_loading_sources')),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Category Spending Breakdown Pie Chart
            Text(
              context.tr('spending_by_category'),
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            categorySpendingAsync.when(
              data: (spendingMap) {
                if (spendingMap.isEmpty) {
                  return GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: Text(context.tr('no_category_data'))),
                    ),
                  );
                }

                final categories = categoriesAsync.valueOrNull ?? [];
                final totalSpent = spendingMap.values.fold(0, (sum, val) => sum + val);

                int colorIdx = 0;
                final pieSections = <PieChartSectionData>[];
                final legendItems = <Widget>[];

                spendingMap.forEach((catId, amount) {
                  final cat = categories.firstWhere(
                    (c) => c.id == catId,
                    orElse: () => Category(
                      id: catId,
                      name: context.tr('general'),
                      icon: 'tag',
                      colorIndex: 0,
                      isDefault: true,
                      isActive: true,
                      sortOrder: 0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  final color = themeChartColors[colorIdx % themeChartColors.length];
                  colorIdx++;

                  final pct = totalSpent > 0 ? (amount / totalSpent) * 100 : 0.0;

                  pieSections.add(
                    PieChartSectionData(
                      color: color,
                      value: amount.toDouble(),
                      title: '${pct.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );

                  legendItems.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          Text(
                            MoneyFormatter.format(amount, currency: currency),
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                });

                return GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: pieSections,
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.md),
                      ...legendItems,
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text(context.tr('error_loading_categories')),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required int amountMinor,
    required String currency,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            MoneyFormatter.format(amountMinor, currency: currency),
            style: AppTypography.moneyMedium(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

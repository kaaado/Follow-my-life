import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/core/widgets/app_empty_state.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/features/finance/domain/services/plan_intelligence_service.dart';
import 'package:follow_my_life/features/finance/domain/services/plan_scenario_service.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  String _selectedPriorityFilter = 'all';

  void _showScenarioOptimizerDialog(BuildContext context, List<PlannedPurchase> purchases, int defaultCapacity, String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capacityCtrl = TextEditingController(text: (defaultCapacity > 0 ? defaultCapacity / 100.0 : 30000).toStringAsFixed(0));
    final simFormKey = GlobalKey<FormState>();

    final titleText = context.tr('plan_capacity_simulator');
    final descText = context.tr('simulator_desc');
    final capacityLabel = context.tr('monthly_savings_capacity');
    final errRequired = context.tr('amount_required');
    final errPositive = context.tr('amount_positive');
    final simulateLabel = context.tr('simulate_capacity');
    final optimalAllocLabel = context.tr('optimal_allocation');
    final estCompletionLabel = context.tr('est_completion');
    final closeLabel = context.tr('close');
    final simCalculatedMsg = context.tr('simulation_calculated');
    final capacitySummaryLabel = context.tr('capacity_summary');
    final totalTargetLabel = context.tr('total_target_amount');
    final monthsNeededLabel = context.tr('months_needed');
    final fullyFeasibleLabel = context.tr('fully_feasible');
    final capacityDeficitLabel = context.tr('capacity_deficit');

    final effectivePurchases = purchases.isNotEmpty
        ? purchases
        : [
            PlannedPurchase(
              id: 'sample_plan_1',
              name: context.tr('sample_plan_title'),
              estimatedAmountMinor: 10000000, // 100,000 DZD
              reservedAmountMinor: 2000000, // 20,000 DZD
              priority: 'high',
              currency: 'DZD',
              status: 'active',
              targetDate: DateTime.now().add(const Duration(days: 120)),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setDialogState) {
            final capacityMinor = MoneyFormatter.parseToMinor(capacityCtrl.text) ?? 0;
            final opt = PlanScenarioService.optimizeAllocations(
              activePlans: effectivePurchases,
              availableMonthlyCapacityMinor: capacityMinor,
            );

            int totalTargetMinor = 0;
            int maxMonthsNeeded = 0;
            for (final p in effectivePurchases) {
              final rem = p.estimatedAmountMinor - p.reservedAmountMinor;
              if (rem > 0) totalTargetMinor += rem;
              final alloc = opt.suggestedMonthlyAllocationsMinor[p.id] ?? 0;
              final sim = PlanScenarioService.simulatePlan(plan: p, simulatedMonthlyContributionMinor: alloc);
              if (sim.monthsToComplete > maxMonthsNeeded) {
                maxMonthsNeeded = sim.monthsToComplete;
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                top: AppSpacing.xl,
                bottom: MediaQuery.of(builderCtx).viewInsets.bottom + AppSpacing.xl,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: simFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.sliders, color: Theme.of(context).colorScheme.primary, size: 24),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              titleText,
                              style: AppTypography.headlineMedium(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        descText,
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      TextFormField(
                        controller: capacityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          labelText: capacityLabel,
                          prefixIcon: const Icon(LucideIcons.wallet),
                          suffixText: currency,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return errRequired;
                          final parsed = MoneyFormatter.parseToMinor(val);
                          if (parsed == null || parsed <= 0) return errPositive;
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            FocusScope.of(builderCtx).unfocus();
                            if (simFormKey.currentState?.validate() ?? false) {
                              setDialogState(() {});
                              AppFeedback.showSuccess(builderCtx, simCalculatedMsg);
                            }
                          },
                          icon: const Icon(LucideIcons.calculator, size: 18),
                          label: Text(simulateLabel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Simulation Overview Summary Card
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    capacitySummaryLabel,
                                    style: AppTypography.labelMedium(color: Theme.of(context).colorScheme.primary).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: opt.hasCapacityDeficit
                                          ? AppColors.warning.withValues(alpha: 0.15)
                                          : AppColors.income.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          opt.hasCapacityDeficit ? LucideIcons.alertTriangle : LucideIcons.checkCircle2,
                                          size: 14,
                                          color: opt.hasCapacityDeficit ? AppColors.warning : AppColors.income,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          opt.hasCapacityDeficit ? capacityDeficitLabel : fullyFeasibleLabel,
                                          style: AppTypography.labelSmall(
                                            color: opt.hasCapacityDeficit ? AppColors.warning : AppColors.income,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          totalTargetLabel,
                                          style: AppTypography.labelSmall(
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          MoneyFormatter.format(totalTargetMinor, currency: currency),
                                          style: AppTypography.bodyMedium(
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          monthsNeededLabel,
                                          style: AppTypography.labelSmall(
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$maxMonthsNeeded ${context.tr('calendar') != '' ? 'M' : 'Mo'}',
                                          style: AppTypography.bodyMedium(
                                            color: Theme.of(context).colorScheme.primary,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      Text(
                        optimalAllocLabel,
                        style: AppTypography.labelSmall(color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      ...opt.suggestedMonthlyAllocationsMinor.entries.map((entry) {
                        final planMatches = effectivePurchases.where((p) => p.id == entry.key).toList();
                        if (planMatches.isEmpty) return const SizedBox.shrink();
                        final plan = planMatches.first;
                        final allocMinor = entry.value;
                        final sim = PlanScenarioService.simulatePlan(
                          plan: plan,
                          simulatedMonthlyContributionMinor: allocMinor,
                        );

                        final rem = (plan.estimatedAmountMinor - plan.reservedAmountMinor).clamp(1, 9999999999);
                        final allocRatio = (allocMinor / rem).clamp(0.0, 1.0);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          plan.name,
                                          style: AppTypography.bodyMedium(
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        '+${MoneyFormatter.format(allocMinor, currency: currency)} /mo',
                                        style: AppTypography.bodyMedium(color: AppColors.income).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: allocRatio == 0 && allocMinor > 0 ? 0.05 : allocRatio,
                                      backgroundColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                                      color: AppColors.income,
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        estCompletionLabel,
                                        style: AppTypography.labelSmall(
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      Text(
                                        DateHelper.formatShortDate(sim.projectedCompletionDate),
                                        style: AppTypography.bodySmall(
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.lg),

                      ...opt.optimizationNotes.map((note) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $note',
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          )),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: Text(closeLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(activePurchasesProvider);
    final summaryAsync = ref.watch(financialSummaryProvider);
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final profileAsync = ref.watch(profileProvider);
    final currency = profileAsync.valueOrNull?.currency ?? 'DZD';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final summary = summaryAsync.valueOrNull;
    final netCashFlow = summary?.netCashFlow ?? 0;
    final availableBalance = summary?.availableBalance ?? 0;
    final purchases = purchasesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('plans')),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.sliders),
            tooltip: context.tr('simulate_capacity'),
            onPressed: () => _showScenarioOptimizerDialog(context, purchases, netCashFlow, currency),
          ),
          IconButton(
            icon: const Icon(LucideIcons.gitFork),
            tooltip: context.tr('virtual_splits'),
            onPressed: () => context.push('/virtual-splits'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context.push('/add-purchase'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-purchase'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: purchasesAsync.when(
        data: (purchases) {
          if (purchases.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.clipboardList,
              title: context.tr('no_plans'),
              message: context.tr('no_plans_desc'),
              actionLabel: context.tr('add_purchase'),
              onAction: () => context.push('/add-purchase'),
            );
          }

          final multiPlanSummary = PlanIntelligenceService.analyzePlans(
            plans: purchases,
            monthlyNetCashFlowMinor: netCashFlow,
            totalAvailableBalanceMinor: availableBalance,
          );

          final filteredPurchases = purchases.where((p) {
            if (_selectedPriorityFilter == 'all') return true;
            if (_selectedPriorityFilter == 'ready') return p.status == 'ready';
            return p.priority.toLowerCase() == _selectedPriorityFilter;
          }).toList();

          final filterOptions = {
            'all': context.tr('filter_all'),
            'high': context.tr('priority_high'),
            'medium': context.tr('priority_medium'),
            'low': context.tr('priority_low'),
            'ready': context.tr('filter_ready'),
          };

          return CustomScrollView(
            slivers: [
              // Conflict Alert Banner
              if (multiPlanSummary.hasConflict)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertTriangle, color: AppColors.warning),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              multiPlanSummary.conflictMessage,
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Summary Header Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('total_planned_targets'),
                              style: AppTypography.labelSmall(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              ),
                              child: Text(
                                '${purchases.length} ${context.tr('items')}',
                                style: AppTypography.labelSmall(color: AppColors.tertiary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          MoneyFormatter.format(multiPlanSummary.totalTargetMinor, currency: currency),
                          style: AppTypography.moneyLarge(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('reserved'),
                                    style: AppTypography.labelSmall(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  Text(
                                    MoneyFormatter.format(multiPlanSummary.totalReservedMinor, currency: currency),
                                    style: AppTypography.bodyMedium(color: AppColors.income)
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 24, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('required_monthly'),
                                      style: AppTypography.labelSmall(
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    Text(
                                      MoneyFormatter.format(multiPlanSummary.totalRequiredMonthlyMinor, currency: currency),
                                      style: AppTypography.bodyMedium(
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

              // Emergency Safety Reserve Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.shieldCheck, color: AppColors.info, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('emergency_reserve_target'),
                              style: AppTypography.headlineSmall(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          context.tr('emergency_reserve_desc'),
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

              // Filter Chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                  child: Row(
                    children: filterOptions.entries.map((entry) {
                      final isSelected = _selectedPriorityFilter == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedPriorityFilter = entry.key);
                          },
                          labelStyle: AppTypography.labelMedium(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

              // Purchase Items List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final purchase = filteredPurchases[index];
                      final analysis = multiPlanSummary.analyses.firstWhere(
                        (a) => a.plan.id == purchase.id,
                        orElse: () => PlanAnalysis(
                          plan: purchase,
                          remainingAmountMinor: purchase.estimatedAmountMinor,
                          progressPercent: 0,
                          requiredMonthlyContributionMinor: 0,
                          requiredWeeklyContributionMinor: 0,
                          feasibilityStatus: 'high',
                          recommendation: '',
                        ),
                      );

                      final canAffordNow = availableBalance >= purchase.estimatedAmountMinor;
                      final neededAmount = purchase.estimatedAmountMinor - availableBalance;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: GlassCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(context, purchase.priority).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(LucideIcons.target, color: _getPriorityColor(context, purchase.priority), size: 20),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          purchase.name,
                                          style: AppTypography.headlineSmall(
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        if (purchase.targetDate != null)
                                          Text(
                                            '${context.tr('target_date_label')}: ${DateHelper.formatShortDate(purchase.targetDate!)}',
                                            style: AppTypography.bodySmall(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            MoneyFormatter.format(purchase.estimatedAmountMinor, currency: purchase.currency),
                                            style: AppTypography.moneyMedium(
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getPriorityColor(context, purchase.priority),
                                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                            ),
                                            child: Text(
                                              purchase.priority.toUpperCase(),
                                              style: AppTypography.labelSmall(color: Colors.white).copyWith(fontSize: 9),
                                            ),
                                          ),
                                        ],
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(LucideIcons.moreVertical, size: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _showEditPlanDialog(context, purchase);
                                          } else if (val == 'delete') {
                                            _confirmDeletePlan(context, purchase);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                const Icon(LucideIcons.edit2, size: 16),
                                                const SizedBox(width: 8),
                                                Text(context.tr('edit')),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                                                const SizedBox(width: 8),
                                                Text(context.tr('delete'), style: const TextStyle(color: AppColors.error)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppSpacing.md),

                              // Progress Indicator
                              LinearProgressIndicator(
                                value: (analysis.progressPercent / 100).clamp(0.0, 1.0),
                                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                valueColor: AlwaysStoppedAnimation<Color>(_getPriorityColor(context, purchase.priority)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${analysis.progressPercent.toStringAsFixed(0)}% ${context.tr('reserved')}',
                                    style: AppTypography.labelSmall(
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                    ),
                                  ),
                                  if (analysis.requiredMonthlyContributionMinor > 0)
                                    Text(
                                      '${MoneyFormatter.format(analysis.requiredMonthlyContributionMinor, currency: currency)}/mo',
                                      style: AppTypography.labelSmall(color: Theme.of(context).colorScheme.primary).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),

                              const SizedBox(height: AppSpacing.md),

                              // Affordability & Recommendation Badge
                              if (canAffordNow)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.income.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.checkCircle2, size: 14, color: AppColors.income),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          context.tr('can_buy_now'),
                                          style: AppTypography.labelSmall(color: AppColors.income)
                                              .copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.tertiary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.info, size: 14, color: AppColors.tertiary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${context.tr('needs_more')} (${MoneyFormatter.format(neededAmount, currency: currency)})',
                                          style: AppTypography.labelSmall(color: AppColors.tertiary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: AppSpacing.md),

                              // Action Buttons: Reserve / Buy
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showReserveDialog(context, purchase, currency),
                                    icon: const Icon(LucideIcons.bookmark, size: 16),
                                    label: Text('${context.tr('reserve_funds')} (${MoneyFormatter.formatNumber(purchase.reservedAmountMinor, currency: currency)})'),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  ElevatedButton.icon(
                                    onPressed: () => _showBuyDialog(context, purchase, sourcesAsync.valueOrNull ?? [], currency),
                                    icon: const Icon(LucideIcons.shoppingBag, size: 16),
                                    label: Text(context.tr('buy_now')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: filteredPurchases.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('error_loading_plans'))),
      ),
    );
  }

  Color _getPriorityColor(BuildContext context, String priority) {
    switch (priority.toLowerCase()) {
      case 'essential':
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.tertiary;
      case 'optional':
      case 'low':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  void _showReserveDialog(BuildContext context, PlannedPurchase purchase, String currency) {
    final titleText = '${context.tr('reserve_funds')}: ${purchase.name}';
    final noteText = context.tr('note');
    final labelReserved = context.tr('reserved_amount');
    final errRequired = context.tr('amount_required');
    final errPositive = context.tr('amount_positive');
    final cancelText = context.tr('cancel');
    final saveText = context.tr('save');
    final successText = context.tr('reserved_amount_updated');

    final controller = TextEditingController(
      text: (purchase.reservedAmountMinor / 100).toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(titleText),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(noteText),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: labelReserved,
                  suffixText: currency,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return errRequired;
                  final parsed = MoneyFormatter.parseToMinor(val);
                  if (parsed == null || parsed < 0) return errPositive;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final val = MoneyFormatter.parseToMinor(controller.text.trim());
              if (val != null) {
                await ref.read(purchaseRepositoryProvider).updateReservedAmount(purchase.id, val);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) AppFeedback.showSuccess(context, successText);
              }
            },
            child: Text(saveText),
          ),
        ],
      ),
    );
  }

  void _showBuyDialog(BuildContext context, PlannedPurchase purchase, List<MoneySource> sources, String currency) {
    if (sources.isEmpty) {
      AppFeedback.showError(context, context.tr('no_sources_desc'));
      return;
    }

    final titleText = '${context.tr('buy_now')}: ${purchase.name}';
    final sourceLabel = context.tr('source');
    final amountLabel = context.tr('amount');
    final errRequired = context.tr('amount_required');
    final errPositive = context.tr('amount_positive');
    final cancelText = context.tr('cancel');
    final submitText = context.tr('submit');
    final successText = context.tr('purchase_completed');

    String selectedSourceId = sources.first.id;
    final amountController = TextEditingController(
      text: (purchase.estimatedAmountMinor / 100).toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setDialogState) => AlertDialog(
          title: Text(titleText),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sourceLabel),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: selectedSourceId,
                  items: sources
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (${MoneyFormatter.format(s.cachedBalanceMinor, currency: s.currency)})'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSourceId = val);
                  },
                  decoration: InputDecoration(labelText: sourceLabel),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: amountLabel,
                    suffixText: currency,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return errRequired;
                    final parsed = MoneyFormatter.parseToMinor(val);
                    if (parsed == null || parsed <= 0) return errPositive;
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final actualMinor = MoneyFormatter.parseToMinor(amountController.text.trim());
                if (actualMinor != null) {
                  final result = await ref
                      .read(purchaseRepositoryProvider)
                      .markAsPurchased(purchase.id, actualMinor, selectedSourceId);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                  if (context.mounted) {
                    if (result.isSuccess) {
                      AppFeedback.showSuccess(context, successText);
                    } else {
                      AppFeedback.showError(context, result.failure.message);
                    }
                  }
                }
              },
              child: Text(submitText),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlanDialog(BuildContext context, PlannedPurchase purchase) {
    final titleText = context.tr('edit');
    final nameLabel = context.tr('plan_name');
    final costLabel = context.tr('estimated_cost');
    final errRequired = context.tr('amount_required');
    final errPositive = context.tr('amount_positive');
    final priorityLabel = context.tr('priority');
    final priorityLow = context.tr('priority_low');
    final priorityMed = context.tr('priority_medium');
    final priorityHigh = context.tr('priority_high');
    final cancelText = context.tr('cancel');
    final saveText = context.tr('save');
    final successText = context.tr('plan_updated');

    final nameCtrl = TextEditingController(text: purchase.name);
    final amountCtrl = TextEditingController(text: (purchase.estimatedAmountMinor / 100).toStringAsFixed(0));
    String priority = purchase.priority;
    DateTime? targetDate = purchase.targetDate;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setDialogState) => AlertDialog(
          title: Text(titleText),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
                    ],
                    decoration: InputDecoration(labelText: nameLabel),
                    validator: (val) => val == null || val.trim().isEmpty ? errRequired : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(labelText: costLabel),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return errRequired;
                      final parsed = MoneyFormatter.parseToMinor(val);
                      if (parsed == null || parsed <= 0) return errPositive;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    items: [
                      DropdownMenuItem(value: 'low', child: Text(priorityLow)),
                      DropdownMenuItem(value: 'medium', child: Text(priorityMed)),
                      DropdownMenuItem(value: 'high', child: Text(priorityHigh)),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => priority = val);
                    },
                    decoration: InputDecoration(labelText: priorityLabel),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(cancelText)),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final amount = MoneyFormatter.parseToMinor(amountCtrl.text.trim());
                if (nameCtrl.text.trim().isNotEmpty && amount != null) {
                  await ref.read(purchaseRepositoryProvider).updatePurchase(
                    id: purchase.id,
                    name: nameCtrl.text.trim(),
                    estimatedAmountMinor: amount,
                    priority: priority,
                    targetDate: targetDate,
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) AppFeedback.showSuccess(context, successText);
                }
              },
              child: Text(saveText),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlan(BuildContext context, PlannedPurchase purchase) {
    final titleText = context.tr('delete_item_title');
    final confirmText = context.tr('delete_item_confirm');
    final cancelText = context.tr('cancel');
    final deleteText = context.tr('delete');
    final successText = context.tr('item_deleted');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titleText),
        content: Text(confirmText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancelText)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              await ref.read(purchaseRepositoryProvider).deletePurchase(purchase.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) AppFeedback.showSuccess(context, successText);
            },
            child: Text(deleteText),
          ),
        ],
      ),
    );
  }
}

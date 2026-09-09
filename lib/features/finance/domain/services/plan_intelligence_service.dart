import 'package:follow_my_life/core/database/app_database.dart';

class PlanAnalysis {
  final PlannedPurchase plan;
  final int remainingAmountMinor;
  final double progressPercent;
  final int requiredMonthlyContributionMinor;
  final int requiredWeeklyContributionMinor;
  final DateTime? estimatedCompletionDate;
  final String feasibilityStatus; // 'high', 'medium', 'low'
  final String recommendation;

  PlanAnalysis({
    required this.plan,
    required this.remainingAmountMinor,
    required this.progressPercent,
    required this.requiredMonthlyContributionMinor,
    required this.requiredWeeklyContributionMinor,
    this.estimatedCompletionDate,
    required this.feasibilityStatus,
    required this.recommendation,
  });
}

class MultiPlanSummary {
  final List<PlanAnalysis> analyses;
  final int totalTargetMinor;
  final int totalReservedMinor;
  final int totalRequiredMonthlyMinor;
  final bool hasConflict;
  final String conflictMessage;

  MultiPlanSummary({
    required this.analyses,
    required this.totalTargetMinor,
    required this.totalReservedMinor,
    required this.totalRequiredMonthlyMinor,
    required this.hasConflict,
    required this.conflictMessage,
  });
}

class PlanIntelligenceService {
  PlanIntelligenceService._();

  static MultiPlanSummary analyzePlans({
    required List<PlannedPurchase> plans,
    required int monthlyNetCashFlowMinor,
    required int totalAvailableBalanceMinor,
  }) {
    if (plans.isEmpty) {
      return MultiPlanSummary(
        analyses: [],
        totalTargetMinor: 0,
        totalReservedMinor: 0,
        totalRequiredMonthlyMinor: 0,
        hasConflict: false,
        conflictMessage: '',
      );
    }

    final now = DateTime.now();
    int totalTarget = 0;
    int totalReserved = 0;
    int totalRequiredMonthly = 0;
    final analyses = <PlanAnalysis>[];

    for (final plan in plans) {
      totalTarget += plan.estimatedAmountMinor;
      totalReserved += plan.reservedAmountMinor;

      final remaining = (plan.estimatedAmountMinor - plan.reservedAmountMinor).clamp(0, plan.estimatedAmountMinor);
      final progress = plan.estimatedAmountMinor > 0
          ? ((plan.reservedAmountMinor / plan.estimatedAmountMinor) * 100).clamp(0.0, 100.0)
          : 0.0;

      int monthlyReq = 0;
      int weeklyReq = 0;
      DateTime? estDate;

      if (plan.targetDate != null && plan.targetDate!.isAfter(now)) {
        final daysRemaining = plan.targetDate!.difference(now).inDays;
        final monthsRemaining = (daysRemaining / 30.0).clamp(0.1, 120.0);
        final weeksRemaining = (daysRemaining / 7.0).clamp(0.1, 520.0);

        monthlyReq = (remaining / monthsRemaining).round();
        weeklyReq = (remaining / weeksRemaining).round();
      } else if (remaining > 0 && monthlyNetCashFlowMinor > 0) {
        final monthsNeeded = (remaining / monthlyNetCashFlowMinor).ceil();
        estDate = DateTime(now.year, now.month + monthsNeeded, now.day);
      }

      totalRequiredMonthly += monthlyReq;

      // Feasibility Assessment
      String feasibility = 'high';
      String recommendation = 'On track to meet target.';

      if (remaining == 0) {
        feasibility = 'high';
        recommendation = 'Goal fully funded! Safe to purchase now.';
      } else if (totalAvailableBalanceMinor >= remaining) {
        feasibility = 'high';
        recommendation = 'You have sufficient available funds to purchase this immediately.';
      } else if (monthlyReq > 0) {
        if (monthlyReq > monthlyNetCashFlowMinor) {
          feasibility = 'low';
          recommendation = 'Required monthly savings exceeds net income. Consider extending target date.';
        } else if (monthlyReq > (monthlyNetCashFlowMinor * 0.5)) {
          feasibility = 'medium';
          recommendation = 'Tight budget. Requires setting aside over 50% of net cash flow.';
        }
      }

      analyses.add(PlanAnalysis(
        plan: plan,
        remainingAmountMinor: remaining,
        progressPercent: progress,
        requiredMonthlyContributionMinor: monthlyReq,
        requiredWeeklyContributionMinor: weeklyReq,
        estimatedCompletionDate: estDate,
        feasibilityStatus: feasibility,
        recommendation: recommendation,
      ));
    }

    final hasConflict = totalRequiredMonthly > monthlyNetCashFlowMinor && monthlyNetCashFlowMinor > 0;
    final conflictMessage = hasConflict
        ? 'Total monthly requirements across all plans exceed your net cash flow. High priority plans will be prioritized.'
        : '';

    return MultiPlanSummary(
      analyses: analyses,
      totalTargetMinor: totalTarget,
      totalReservedMinor: totalReserved,
      totalRequiredMonthlyMinor: totalRequiredMonthly,
      hasConflict: hasConflict,
      conflictMessage: conflictMessage,
    );
  }
}

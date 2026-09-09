import 'package:follow_my_life/core/database/app_database.dart';

class PlanSimulationResult {
  final String planId;
  final String planName;
  final int simulatedMonthlyContributionMinor;
  final DateTime projectedCompletionDate;
  final int monthsToComplete;
  final bool isFeasible;

  const PlanSimulationResult({
    required this.planId,
    required this.planName,
    required this.simulatedMonthlyContributionMinor,
    required this.projectedCompletionDate,
    required this.monthsToComplete,
    required this.isFeasible,
  });
}

class MultiPlanOptimizationResult {
  final int totalAvailableMonthlyCapacityMinor;
  final int totalRequiredMonthlyMinor;
  final bool hasCapacityDeficit;
  final Map<String, int> suggestedMonthlyAllocationsMinor;
  final List<String> optimizationNotes;

  const MultiPlanOptimizationResult({
    required this.totalAvailableMonthlyCapacityMinor,
    required this.totalRequiredMonthlyMinor,
    required this.hasCapacityDeficit,
    required this.suggestedMonthlyAllocationsMinor,
    required this.optimizationNotes,
  });
}

class PlanScenarioService {
  /// Simulate single plan timeline given a custom monthly contribution.
  static PlanSimulationResult simulatePlan({
    required PlannedPurchase plan,
    required int simulatedMonthlyContributionMinor,
  }) {
    final remainingMinor = plan.estimatedAmountMinor - plan.reservedAmountMinor;
    if (remainingMinor <= 0) {
      return PlanSimulationResult(
        planId: plan.id,
        planName: plan.name,
        simulatedMonthlyContributionMinor: simulatedMonthlyContributionMinor,
        projectedCompletionDate: DateTime.now(),
        monthsToComplete: 0,
        isFeasible: true,
      );
    }

    if (simulatedMonthlyContributionMinor <= 0) {
      return PlanSimulationResult(
        planId: plan.id,
        planName: plan.name,
        simulatedMonthlyContributionMinor: 0,
        projectedCompletionDate: DateTime.now().add(const Duration(days: 3650)),
        monthsToComplete: 120,
        isFeasible: false,
      );
    }

    final monthsNeeded = (remainingMinor / simulatedMonthlyContributionMinor).ceil();
    final completionDate = DateTime.now().add(Duration(days: monthsNeeded * 30));

    bool isFeasible = true;
    if (plan.targetDate != null && completionDate.isAfter(plan.targetDate!)) {
      isFeasible = false;
    }

    return PlanSimulationResult(
      planId: plan.id,
      planName: plan.name,
      simulatedMonthlyContributionMinor: simulatedMonthlyContributionMinor,
      projectedCompletionDate: completionDate,
      monthsToComplete: monthsNeeded,
      isFeasible: isFeasible,
    );
  }

  /// Optimizes monthly allocation capacity across multiple active plans based on priority and deadlines.
  static MultiPlanOptimizationResult optimizeAllocations({
    required List<PlannedPurchase> activePlans,
    required int availableMonthlyCapacityMinor,
  }) {
    final allocations = <String, int>{};
    final notes = <String>[];

    int totalRequired = 0;
    final planRequirements = <({PlannedPurchase plan, int requiredMonthly})>[];

    final now = DateTime.now();

    for (final plan in activePlans) {
      if (plan.status == 'completed' || plan.status == 'cancelled' || plan.status == 'purchased') continue;

      final remaining = plan.estimatedAmountMinor - plan.reservedAmountMinor;
      if (remaining <= 0) continue;

      int monthsLeft = 12;
      if (plan.targetDate != null) {
        monthsLeft = (plan.targetDate!.difference(now).inDays / 30).ceil().clamp(1, 120);
      }

      final reqMonthly = (remaining / monthsLeft).ceil();
      totalRequired += reqMonthly;
      planRequirements.add((plan: plan, requiredMonthly: reqMonthly));
    }

    // Sort by priority (essential/high first) then deadline
    planRequirements.sort((a, b) {
      final pA = _priorityScore(a.plan.priority);
      final pB = _priorityScore(b.plan.priority);
      if (pA != pB) return pB.compareTo(pA); // higher score first
      final dateA = a.plan.targetDate ?? DateTime(2099);
      final dateB = b.plan.targetDate ?? DateTime(2099);
      return dateA.compareTo(dateB);
    });

    int remainingCapacity = availableMonthlyCapacityMinor;
    bool hasDeficit = totalRequired > availableMonthlyCapacityMinor;

    for (final req in planRequirements) {
      if (remainingCapacity <= 0) {
        allocations[req.plan.id] = 0;
        notes.add('${req.plan.name} receives 0 DZD due to capacity limit.');
      } else if (remainingCapacity >= req.requiredMonthly) {
        allocations[req.plan.id] = req.requiredMonthly;
        remainingCapacity -= req.requiredMonthly;
      } else {
        allocations[req.plan.id] = remainingCapacity;
        notes.add('${req.plan.name} receives partial allocation of ${remainingCapacity ~/ 100} DZD.');
        remainingCapacity = 0;
      }
    }

    if (hasDeficit) {
      notes.insert(0, 'Total plan requirements (${totalRequired ~/ 100} DZD) exceed your available capacity.');
    } else {
      notes.insert(0, 'Your monthly capacity fully satisfies all active plans.');
    }

    return MultiPlanOptimizationResult(
      totalAvailableMonthlyCapacityMinor: availableMonthlyCapacityMinor,
      totalRequiredMonthlyMinor: totalRequired,
      hasCapacityDeficit: hasDeficit,
      suggestedMonthlyAllocationsMinor: allocations,
      optimizationNotes: notes,
    );
  }

  static int _priorityScore(String priority) {
    switch (priority.toLowerCase()) {
      case 'essential':
      case 'high':
        return 3;
      case 'important':
      case 'medium':
        return 2;
      case 'optional':
      case 'low':
        return 1;
      default:
        return 2;
    }
  }
}

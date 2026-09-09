import 'package:flutter_test/flutter_test.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/features/finance/domain/services/financial_snapshot_service.dart';
import 'package:follow_my_life/features/finance/domain/services/safe_to_spend_service.dart';
import 'package:follow_my_life/features/finance/domain/services/subscription_intelligence_service.dart';
import 'package:follow_my_life/features/finance/domain/services/plan_scenario_service.dart';
import 'package:follow_my_life/features/finance/domain/services/smart_action_service.dart';
import 'package:follow_my_life/features/finance/domain/services/virtual_split_template_service.dart';

void main() {
  group('Stage 19 Financial Intelligence Unit Tests', () {
    test('SafeToSpendService calculates correct safe-to-spend balance with breakdown', () {
      final sources = <MoneySource>[
        MoneySource(
          id: 'src-1',
          name: 'Main Bank',
          type: SourceType.bankAccount,
          currency: 'DZD',
          icon: 'bank',
          colorIndex: 0,
          initialBalanceMinor: 10000000,
          cachedBalanceMinor: 10000000, // 100,000 DZD
          isActive: true,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final plans = <PlannedPurchase>[
        PlannedPurchase(
          id: 'plan-1',
          name: 'New Laptop',
          estimatedAmountMinor: 15000000,
          reservedAmountMinor: 3000000, // 30,000 DZD
          currency: 'DZD',
          targetDate: DateTime.now().add(const Duration(days: 90)),
          priority: 'high',
          status: 'saving',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final recurring = <RecurringTransaction>[
        RecurringTransaction(
          id: 'rec-1',
          sourceId: 'src-1',
          categoryId: 'cat-1',
          type: 'expense',
          amountMinor: 2000000, // 20,000 DZD
          currency: 'DZD',
          description: 'Rent',
          frequency: 'monthly',
          nextOccurrence: DateTime.now().add(const Duration(days: 5)),
          isActive: true,
          autoExecute: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final breakdown = SafeToSpendService.calculate(
        sources: sources,
        plans: plans,
        virtualSplits: [],
        recurringItems: recurring,
        debts: [],
      );

      expect(breakdown.totalBalanceMinor, equals(10000000));
      expect(breakdown.reservedMinor, equals(3000000));
      expect(breakdown.availableBalanceMinor, equals(7000000));
      expect(breakdown.upcomingBillsMinor, equals(2000000));
      expect(breakdown.safeToSpendMinor, equals(7000000 - 2000000 - breakdown.planContributionsMinor - 300000));
      expect(breakdown.lineItems.isNotEmpty, isTrue);
    });

    test('SubscriptionIntelligenceService detects monthly burden and percentage', () {
      final recurring = <RecurringTransaction>[
        RecurringTransaction(
          id: 'rec-1',
          sourceId: 'src-1',
          categoryId: 'cat-sub',
          type: 'expense',
          amountMinor: 100000, // 1,000 DZD
          currency: 'DZD',
          description: 'Netflix',
          frequency: 'monthly',
          nextOccurrence: DateTime.now().add(const Duration(days: 10)),
          isActive: true,
          autoExecute: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final summary = SubscriptionIntelligenceService.analyze(
        recurringTxns: recurring,
        monthlyIncomeMinor: 10000000, // 100,000 DZD
      );

      expect(summary.activeSubscriptionCount, equals(1));
      expect(summary.totalMonthlyBurdenMinor, equals(100000));
      expect(summary.totalAnnualizedBurdenMinor, equals(1200000));
      expect(summary.burdenPercentOfIncome, equals(1.0));
    });

    test('PlanScenarioService simulates single plan completion date', () {
      final plan = PlannedPurchase(
        id: 'plan-1',
        name: 'Smartphone',
        estimatedAmountMinor: 6000000, // 60,000 DZD
        reservedAmountMinor: 1000000,  // 10,000 DZD (50,000 left)
        currency: 'DZD',
        targetDate: DateTime.now().add(const Duration(days: 180)),
        priority: 'high',
        status: 'saving',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = PlanScenarioService.simulatePlan(
        plan: plan,
        simulatedMonthlyContributionMinor: 1000000, // 10,000 DZD / mo -> 5 months needed
      );

      expect(result.monthsToComplete, equals(5));
      expect(result.isFeasible, isTrue);
    });

    test('PlanScenarioService optimizes multi-plan capacity allocation', () {
      final plans = <PlannedPurchase>[
        PlannedPurchase(
          id: 'p1',
          name: 'Emergency Fund',
          estimatedAmountMinor: 12000000,
          reservedAmountMinor: 0,
          currency: 'DZD',
          targetDate: DateTime.now().add(const Duration(days: 365)),
          priority: 'essential',
          status: 'saving',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PlannedPurchase(
          id: 'p2',
          name: 'Vacation',
          estimatedAmountMinor: 5000000,
          reservedAmountMinor: 0,
          currency: 'DZD',
          targetDate: DateTime.now().add(const Duration(days: 180)),
          priority: 'optional',
          status: 'saving',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final opt = PlanScenarioService.optimizeAllocations(
        activePlans: plans,
        availableMonthlyCapacityMinor: 2000000, // 20,000 DZD
      );

      expect(opt.suggestedMonthlyAllocationsMinor.containsKey('p1'), isTrue);
      expect(opt.optimizationNotes.isNotEmpty, isTrue);
    });

    test('VirtualSplitTemplateService computes percentage allocations correctly', () {
      final template = VirtualSplitTemplateService.templates.first;
      final allocations = VirtualSplitTemplateService.calculatePercentageAllocations(
        totalBalanceMinor: 10000000, // 100,000 DZD
        percentageItems: template.items.map((i) => (label: i.categoryNameKey, percentage: i.percentage)).toList(),
      );

      final totalAllocated = allocations.fold(0, (sum, a) => sum + a.amountMinor);
      expect(totalAllocated, equals(10000000));
    });

    test('SmartActionService generates appropriate recommendations', () {
      final snapshot = FinancialSnapshotService.computeSnapshot(
        sources: [],
        plans: [],
        virtualSplits: [],
        recurringItems: [],
        debts: [],
        currentMonthTransactions: [],
        previousMonthTransactions: [],
        budgets: [],
      );

      final recurring = <RecurringTransaction>[];
      final subSummary = SubscriptionIntelligenceService.analyze(
        recurringTxns: recurring,
        monthlyIncomeMinor: snapshot.currentMonthIncomeMinor,
      );

      final actions = SmartActionService.generateActions(
        snapshot: snapshot,
        anomalies: [],
        subscriptionSummary: subSummary,
      );

      expect(actions, isA<List>());
    });
  });
}

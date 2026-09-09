import 'package:follow_my_life/core/database/app_database.dart';

class SafeToSpendBreakdown {
  final int totalBalanceMinor;
  final int reservedMinor;
  final int availableBalanceMinor;
  final int upcomingIncomeMinor;
  final int upcomingBillsMinor;
  final int planContributionsMinor;
  final int recommendedReserveMinor;
  final int safeToSpendMinor;
  final List<({String label, int amountMinor, bool isAddition, String category})> lineItems;

  const SafeToSpendBreakdown({
    required this.totalBalanceMinor,
    required this.reservedMinor,
    required this.availableBalanceMinor,
    required this.upcomingIncomeMinor,
    required this.upcomingBillsMinor,
    required this.planContributionsMinor,
    required this.recommendedReserveMinor,
    required this.safeToSpendMinor,
    required this.lineItems,
  });
}

class SafeToSpendService {
  static SafeToSpendBreakdown calculate({
    required List<MoneySource> sources,
    required List<PlannedPurchase> plans,
    required List<VirtualSplit> virtualSplits,
    required List<RecurringTransaction> recurringItems,
    required List<Debt> debts,
  }) {
    final totalBalance = sources.fold<int>(0, (sum, s) => sum + (s.isActive ? s.cachedBalanceMinor : 0));

    int reservedInPlans = 0;
    int monthlyPlanContributionsNeeded = 0;
    for (final plan in plans) {
      if (plan.status != 'completed' && plan.status != 'cancelled' && plan.status != 'purchased') {
        reservedInPlans += plan.reservedAmountMinor;
        if (plan.targetDate != null) {
          final monthsLeft = (plan.targetDate!.difference(DateTime.now()).inDays / 30).clamp(1.0, 36.0);
          final remaining = plan.estimatedAmountMinor - plan.reservedAmountMinor;
          if (remaining > 0) {
            monthlyPlanContributionsNeeded += (remaining / monthsLeft).round();
          }
        }
      }
    }

    int activeVirtualSplitsTotal = 0;
    for (final vs in virtualSplits) {
      if (vs.status == 'active' || vs.status == 'draft') {
        activeVirtualSplitsTotal += vs.totalAmountMinor;
      }
    }

    final totalReserved = reservedInPlans + activeVirtualSplitsTotal;
    final availableBalance = (totalBalance - totalReserved).clamp(0, 999999999999);

    int upcomingIncome = 0;
    int upcomingBills = 0;
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    for (final rec in recurringItems) {
      if (rec.isActive && rec.nextOccurrence.isBefore(thirtyDaysLater)) {
        if (rec.type == 'income') {
          upcomingIncome += rec.amountMinor;
        } else if (rec.type == 'expense') {
          upcomingBills += rec.amountMinor;
        }
      }
    }

    for (final debt in debts) {
      if (debt.status == 'active' || debt.status == 'partially_paid') {
        if (debt.dueDate != null && debt.dueDate!.isBefore(thirtyDaysLater)) {
          final rem = debt.amountMinor - debt.paidAmountMinor;
          if (rem > 0) {
            if (debt.type == 'i_owe') {
              upcomingBills += rem;
            } else if (debt.type == 'owed_to_me') {
              upcomingIncome += rem;
            }
          }
        }
      }
    }

    // Recommended emergency safety buffer (e.g. 15% of upcoming bills or fixed minimum)
    final recommendedReserve = (upcomingBills * 0.15).round();

    final rawSafeToSpend = availableBalance + upcomingIncome - upcomingBills - monthlyPlanContributionsNeeded - recommendedReserve;
    final safeToSpend = rawSafeToSpend.clamp(0, 999999999999);

    final lineItems = <({String label, int amountMinor, bool isAddition, String category})>[
      (label: 'Total Balance', amountMinor: totalBalance, isAddition: true, category: 'balance'),
      if (totalReserved > 0)
        (label: 'Active Reserves & Virtual Splits', amountMinor: totalReserved, isAddition: false, category: 'reserved'),
      if (upcomingIncome > 0)
        (label: 'Expected Income (Next 30 Days)', amountMinor: upcomingIncome, isAddition: true, category: 'income'),
      if (upcomingBills > 0)
        (label: 'Upcoming Bills & Debts', amountMinor: upcomingBills, isAddition: false, category: 'bills'),
      if (monthlyPlanContributionsNeeded > 0)
        (label: 'Plan Monthly Targets', amountMinor: monthlyPlanContributionsNeeded, isAddition: false, category: 'plans'),
      if (recommendedReserve > 0)
        (label: 'Safety Buffer Reserve', amountMinor: recommendedReserve, isAddition: false, category: 'buffer'),
    ];

    return SafeToSpendBreakdown(
      totalBalanceMinor: totalBalance,
      reservedMinor: totalReserved,
      availableBalanceMinor: availableBalance,
      upcomingIncomeMinor: upcomingIncome,
      upcomingBillsMinor: upcomingBills,
      planContributionsMinor: monthlyPlanContributionsNeeded,
      recommendedReserveMinor: recommendedReserve,
      safeToSpendMinor: safeToSpend,
      lineItems: lineItems,
    );
  }
}

import 'package:follow_my_life/core/database/app_database.dart';

class SubscriptionSummary {
  final int activeSubscriptionCount;
  final int totalMonthlyBurdenMinor;
  final int totalAnnualizedBurdenMinor;
  final double burdenPercentOfIncome;
  final List<({RecurringTransaction item, int nextDaysLeft})> upcomingSubscriptions;

  const SubscriptionSummary({
    required this.activeSubscriptionCount,
    required this.totalMonthlyBurdenMinor,
    required this.totalAnnualizedBurdenMinor,
    required this.burdenPercentOfIncome,
    required this.upcomingSubscriptions,
  });
}

class SubscriptionIntelligenceService {
  static SubscriptionSummary analyze({
    required List<RecurringTransaction> recurringTxns,
    required int monthlyIncomeMinor,
  }) {
    int activeCount = 0;
    int monthlyTotal = 0;
    final now = DateTime.now();

    final upcoming = <({RecurringTransaction item, int nextDaysLeft})>[];

    for (final rec in recurringTxns) {
      if (rec.isActive && rec.type == 'expense') {
        activeCount++;

        // Normalize frequency to monthly minor units
        int monthlyEquiv = rec.amountMinor;
        switch (rec.frequency.toLowerCase()) {
          case 'daily':
            monthlyEquiv = rec.amountMinor * 30;
            break;
          case 'weekly':
            monthlyEquiv = (rec.amountMinor * 4.33).round();
            break;
          case 'monthly':
            monthlyEquiv = rec.amountMinor;
            break;
          case 'yearly':
            monthlyEquiv = (rec.amountMinor / 12).round();
            break;
        }

        monthlyTotal += monthlyEquiv;

        final daysLeft = rec.nextOccurrence.difference(now).inDays;
        if (daysLeft >= 0 && daysLeft <= 30) {
          upcoming.add((item: rec, nextDaysLeft: daysLeft));
        }
      }
    }

    upcoming.sort((a, b) => a.nextDaysLeft.compareTo(b.nextDaysLeft));

    double burdenPct = 0.0;
    if (monthlyIncomeMinor > 0) {
      burdenPct = (monthlyTotal / monthlyIncomeMinor) * 100.0;
    }

    return SubscriptionSummary(
      activeSubscriptionCount: activeCount,
      totalMonthlyBurdenMinor: monthlyTotal,
      totalAnnualizedBurdenMinor: monthlyTotal * 12,
      burdenPercentOfIncome: burdenPct,
      upcomingSubscriptions: upcoming,
    );
  }
}

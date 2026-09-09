import 'package:follow_my_life/core/database/app_database.dart';

class ForecastPoint {
  final DateTime date;
  final int projectedBalanceMinor;
  final int expectedIncomeMinor;
  final int expectedExpenseMinor;

  const ForecastPoint({
    required this.date,
    required this.projectedBalanceMinor,
    required this.expectedIncomeMinor,
    required this.expectedExpenseMinor,
  });
}

class ForecastResult {
  final int currentBalanceMinor;
  final int projectedEndingBalanceMinor;
  final int netChangeMinor;
  final List<ForecastPoint> points;

  const ForecastResult({
    required this.currentBalanceMinor,
    required this.projectedEndingBalanceMinor,
    required this.netChangeMinor,
    required this.points,
  });
}

class ForecastService {
  static ForecastResult generateForecast({
    required int startingBalanceMinor,
    required List<RecurringTransaction> recurringTxns,
    required List<Debt> activeDebts,
    required List<PlannedPurchase> plannedPurchases,
    required int horizonDays,
  }) {
    final now = DateTime.now();
    final points = <ForecastPoint>[];

    int runningBalance = startingBalanceMinor;
    
    // Step by step daily projection
    for (int day = 0; day <= horizonDays; day++) {
      final currentDate = DateTime(now.year, now.month, now.day).add(Duration(days: day));
      int dayIncome = 0;
      int dayExpense = 0;

      // 1. Process recurring items due today
      for (final rec in recurringTxns) {
        if (_isDueDate(currentDate, rec)) {
          if (rec.type == 'income') {
            dayIncome += rec.amountMinor;
          } else {
            dayExpense += rec.amountMinor;
          }
        }
      }

      // 2. Process debts due today
      for (final debt in activeDebts) {
        if (debt.dueDate != null && _isSameDay(debt.dueDate!, currentDate)) {
          final remaining = debt.amountMinor - debt.paidAmountMinor;
          if (remaining > 0) {
            if (debt.type == 'i_owe') {
              dayExpense += remaining;
            } else {
              dayIncome += remaining;
            }
          }
        }
      }

      // 3. Process planned purchases target date
      for (final purchase in plannedPurchases) {
        if (purchase.targetDate != null && _isSameDay(purchase.targetDate!, currentDate)) {
          dayExpense += purchase.estimatedAmountMinor;
        }
      }

      runningBalance = runningBalance + dayIncome - dayExpense;

      // Sample weekly or key milestones depending on horizon
      if (horizonDays <= 30 || day % 7 == 0 || day == horizonDays) {
        points.add(ForecastPoint(
          date: currentDate,
          projectedBalanceMinor: runningBalance,
          expectedIncomeMinor: dayIncome,
          expectedExpenseMinor: dayExpense,
        ));
      }
    }

    return ForecastResult(
      currentBalanceMinor: startingBalanceMinor,
      projectedEndingBalanceMinor: runningBalance,
      netChangeMinor: runningBalance - startingBalanceMinor,
      points: points,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isDueDate(DateTime target, RecurringTransaction rec) {
    final start = rec.nextOccurrence;
    if (target.isBefore(DateTime(start.year, start.month, start.day))) return false;

    switch (rec.frequency.toLowerCase()) {
      case 'daily':
        return true;
      case 'weekly':
        return target.weekday == start.weekday;
      case 'monthly':
        return target.day == start.day;
      case 'yearly':
        return target.month == start.month && target.day == start.day;
      default:
        return target.day == start.day;
    }
  }
}

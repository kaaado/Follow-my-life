import 'package:follow_my_life/core/database/app_database.dart';

class FinancialSummaryData {
  final int totalBalance;
  final int availableBalance;
  final int reservedBalance;
  final int safeToSpend;
  final int totalIncome;
  final int totalExpenses;
  final int netCashFlow;
  final int upcomingIncome;
  final int upcomingExpenses;
  final int plannedAmount;
  final int essentialPlannedAmount;
  final int optionalPlannedAmount;
  final int savings;

  const FinancialSummaryData({
    required this.totalBalance,
    required this.availableBalance,
    required this.reservedBalance,
    required this.safeToSpend,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashFlow,
    required this.upcomingIncome,
    required this.upcomingExpenses,
    required this.plannedAmount,
    required this.essentialPlannedAmount,
    required this.optionalPlannedAmount,
    required this.savings,
  });
}

class FinancialSummaryService {
  static FinancialSummaryData calculate({
    required List<MoneySource> sources,
    required List<Transaction> periodTransactions,
    required List<PlannedPurchase> plans,
    required List<RecurringTransaction> recurringEvents,
  }) {
    // 1. Total Balance from active sources
    final totalBalance = sources.fold<int>(
      0,
      (sum, s) => sum + (s.isActive ? s.cachedBalanceMinor : 0),
    );

    // 2. Reserved Balance from active planned purchases
    int reservedBalance = 0;
    int plannedTotal = 0;
    int essentialPlanned = 0;
    int optionalPlanned = 0;

    for (final plan in plans) {
      if (plan.status != 'completed' && plan.status != 'cancelled' && plan.status != 'purchased') {
        reservedBalance += plan.reservedAmountMinor;
        plannedTotal += plan.estimatedAmountMinor;

        if (plan.priority == 'essential' || plan.priority == 'high') {
          essentialPlanned += plan.estimatedAmountMinor;
        } else if (plan.priority == 'optional' || plan.priority == 'low') {
          optionalPlanned += plan.estimatedAmountMinor;
        }
      }
    }

    // 3. Available Balance
    final availableBalance = (totalBalance - reservedBalance).clamp(0, double.maxFinite.toInt());

    // 4. Period Income & Expenses
    int income = 0;
    int expenses = 0;
    int savingsCategorySum = 0;

    for (final t in periodTransactions) {
      if (t.status == 'completed') {
        if (t.type == 'income') {
          income += t.amountMinor;
        } else if (t.type == 'expense') {
          expenses += t.amountMinor;
          if (t.categoryId == 'cat_savings') {
            savingsCategorySum += t.amountMinor;
          }
        }
      }
    }

    final netCashFlow = income - expenses;

    // 5. Upcoming Income & Expenses (Next 30 days)
    int upcomingIn = 0;
    int upcomingOut = 0;
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    for (final rec in recurringEvents) {
      if (rec.isActive &&
          rec.nextOccurrence.isAfter(now.subtract(const Duration(days: 1))) &&
          rec.nextOccurrence.isBefore(thirtyDaysLater)) {
        if (rec.type == 'income') {
          upcomingIn += rec.amountMinor;
        } else if (rec.type == 'expense') {
          upcomingOut += rec.amountMinor;
        }
      }
    }

    // 6. Safe to Spend calculation
    final safeToSpend = (availableBalance - upcomingOut).clamp(0, double.maxFinite.toInt());

    return FinancialSummaryData(
      totalBalance: totalBalance,
      availableBalance: availableBalance,
      reservedBalance: reservedBalance,
      safeToSpend: safeToSpend,
      totalIncome: income,
      totalExpenses: expenses,
      netCashFlow: netCashFlow,
      upcomingIncome: upcomingIn,
      upcomingExpenses: upcomingOut,
      plannedAmount: plannedTotal,
      essentialPlannedAmount: essentialPlanned,
      optionalPlannedAmount: optionalPlanned,
      savings: savingsCategorySum + reservedBalance,
    );
  }
}

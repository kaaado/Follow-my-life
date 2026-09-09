import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/features/finance/domain/entities/financial_snapshot.dart';

class FinancialSnapshotService {
  static FinancialSnapshot computeSnapshot({
    required List<MoneySource> sources,
    required List<Transaction> currentMonthTransactions,
    required List<Transaction> previousMonthTransactions,
    required List<PlannedPurchase> plans,
    required List<VirtualSplit> virtualSplits,
    required List<RecurringTransaction> recurringItems,
    required List<Budget> budgets,
    required List<Debt> debts,
  }) {
    // 1. Total balance from active accounts
    final totalBalance = sources.fold<int>(
      0,
      (sum, s) => sum + (s.isActive ? s.cachedBalanceMinor : 0),
    );

    // 2. Virtual allocations total
    int activeVirtualTotal = 0;
    for (final vs in virtualSplits) {
      if (vs.status == 'active' || vs.status == 'draft') {
        activeVirtualTotal += vs.totalAmountMinor;
      }
    }

    // 3. Plan reserved amounts
    int planReserved = 0;
    int activePlansCount = 0;
    for (final plan in plans) {
      if (plan.status != 'completed' && plan.status != 'cancelled' && plan.status != 'purchased') {
        planReserved += plan.reservedAmountMinor;
        activePlansCount++;
      }
    }

    final totalReserved = planReserved + activeVirtualTotal;
    final availableBalance = (totalBalance - totalReserved).clamp(0, 999999999999);

    // 4. Current Month Cash Flow
    int currentIncome = 0;
    int currentExpenses = 0;
    int savingsCategorySum = 0;

    for (final t in currentMonthTransactions) {
      if (t.status == 'completed') {
        if (t.type == 'income') {
          currentIncome += t.amountMinor;
        } else if (t.type == 'expense') {
          currentExpenses += t.amountMinor;
          if (t.categoryId == 'cat_savings') {
            savingsCategorySum += t.amountMinor;
          }
        }
      }
    }

    final netCashFlow = currentIncome - currentExpenses;

    // 5. Previous Month Expenses & Trend
    int prevExpenses = 0;
    for (final t in previousMonthTransactions) {
      if (t.status == 'completed' && t.type == 'expense') {
        prevExpenses += t.amountMinor;
      }
    }

    double trendPercent = 0.0;
    if (prevExpenses > 0) {
      trendPercent = ((currentExpenses - prevExpenses) / prevExpenses) * 100.0;
    }

    // 6. Savings Rate
    double savingsRate = 0.0;
    if (currentIncome > 0) {
      final monthlySaved = currentIncome - currentExpenses;
      if (monthlySaved > 0) {
        savingsRate = monthlySaved / currentIncome;
      }
    }

    // 7. Upcoming Commitments & Expected Income (30 days)
    int upcomingCommitments = 0;
    int expectedIncome = 0;
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    for (final rec in recurringItems) {
      if (rec.isActive &&
          rec.nextOccurrence.isAfter(now.subtract(const Duration(days: 1))) &&
          rec.nextOccurrence.isBefore(thirtyDaysLater)) {
        if (rec.type == 'income') {
          expectedIncome += rec.amountMinor;
        } else if (rec.type == 'expense') {
          upcomingCommitments += rec.amountMinor;
        }
      }
    }

    // Include debts due in next 30 days
    for (final debt in debts) {
      if (debt.status == 'active' || debt.status == 'partially_paid') {
        if (debt.dueDate != null && debt.dueDate!.isBefore(thirtyDaysLater)) {
          final remaining = debt.amountMinor - debt.paidAmountMinor;
          if (remaining > 0) {
            if (debt.type == 'i_owe') {
              upcomingCommitments += remaining;
            } else if (debt.type == 'owed_to_me') {
              expectedIncome += remaining;
            }
          }
        }
      }
    }

    // 8. Safe-to-Spend Calculation
    // Safe-to-spend = Available Balance + Expected Income - Upcoming Mandatory Commitments
    final safeToSpend = (availableBalance + expectedIncome - upcomingCommitments).clamp(0, 999999999999);

    // 9. Budget Health Analysis
    String budgetHealth = 'good';
    final categoryExpenses = <String, int>{};
    for (final t in currentMonthTransactions) {
      if (t.status == 'completed' && t.type == 'expense' && t.categoryId != null) {
        categoryExpenses[t.categoryId!] = (categoryExpenses[t.categoryId!] ?? 0) + t.amountMinor;
      }
    }

    bool hasExceeded = false;
    bool hasWarning = false;
    for (final b in budgets) {
      if (b.isActive) {
        final spent = categoryExpenses[b.categoryId] ?? 0;
        final ratio = spent / b.amountMinor;
        if (ratio >= 1.0) {
          hasExceeded = true;
        } else if (ratio >= 0.85) {
          hasWarning = true;
        }
      }
    }

    if (hasExceeded) {
      budgetHealth = 'exceeded';
    } else if (hasWarning) {
      budgetHealth = 'warning';
    } else if (budgets.isNotEmpty) {
      budgetHealth = 'excellent';
    }

    // 10. Risk Warnings & Opportunities Generation
    final warnings = <String>[];
    final opportunities = <String>[];

    if (upcomingCommitments > availableBalance) {
      warnings.add('Upcoming commitments exceed your currently available balance.');
    }
    if (netCashFlow < 0 && currentIncome > 0) {
      warnings.add('Your expenses exceed your income this month.');
    }
    if (budgetHealth == 'exceeded') {
      warnings.add('One or more of your category budgets have been exceeded.');
    }

    if (netCashFlow > 1000000 && activePlansCount > 0) {
      opportunities.add('You have surplus cash flow. Consider boosting your active plan allocations.');
    }
    if (availableBalance > 5000000 && totalReserved < 1000000) {
      opportunities.add('You have unallocated funds available to reserve for future goals.');
    }

    // 11. Daily Budget & Spending Pace Intelligence
    final now2 = DateTime.now();
    final daysInMonth = DateTime(now2.year, now2.month + 1, 0).day;
    final daysPassed = now2.day;
    final daysLeft = (daysInMonth - daysPassed).clamp(1, 31);

    // Daily budget = safe-to-spend ÷ remaining days
    final dailyBudget = daysLeft > 0 ? (safeToSpend / daysLeft).round() : 0;

    // Spending pace: what % of income is spent vs what % of month has passed
    double spendingPace = 0.0;
    if (currentIncome > 0 && daysPassed > 0) {
      final expectedSpendingRatio = daysPassed / daysInMonth; // e.g. 0.5 at mid-month
      final actualSpendingRatio = currentExpenses / currentIncome; // e.g. 0.7
      spendingPace = ((actualSpendingRatio / expectedSpendingRatio) - 1.0) * 100; // +40% means overspending
    }

    return FinancialSnapshot(
      totalBalanceMinor: totalBalance,
      availableBalanceMinor: availableBalance,
      reservedBalanceMinor: totalReserved,
      virtualAllocationsMinor: activeVirtualTotal,
      savingsMinor: savingsCategorySum + planReserved,
      safeToSpendMinor: safeToSpend,
      expectedIncomeMinor: expectedIncome,
      expectedExpensesMinor: upcomingCommitments,
      upcomingCommitmentsMinor: upcomingCommitments,
      currentMonthIncomeMinor: currentIncome,
      currentMonthExpensesMinor: currentExpenses,
      netCashFlowMinor: netCashFlow,
      spendingTrendPercent: trendPercent,
      savingsRate: savingsRate,
      activePlansCount: activePlansCount,
      budgetHealth: budgetHealth,
      warnings: warnings,
      opportunities: opportunities,
      dailyBudgetMinor: dailyBudget,
      daysLeftInMonth: daysLeft,
      spendingPacePercent: spendingPace,
    );
  }
}

import 'package:equatable/equatable.dart';

class FinancialSnapshot extends Equatable {
  final int totalBalanceMinor;
  final int availableBalanceMinor;
  final int reservedBalanceMinor;
  final int virtualAllocationsMinor;
  final int savingsMinor;
  final int safeToSpendMinor;
  final int expectedIncomeMinor;
  final int expectedExpensesMinor;
  final int upcomingCommitmentsMinor;
  final int currentMonthIncomeMinor;
  final int currentMonthExpensesMinor;
  final int netCashFlowMinor;
  final double spendingTrendPercent; // e.g. +14.5% or -5.2%
  final double savingsRate; // 0.0 to 1.0
  final int activePlansCount;
  final String budgetHealth; // 'excellent', 'good', 'warning', 'exceeded'
  final List<String> warnings;
  final List<String> opportunities;

  // New intelligence fields
  final int dailyBudgetMinor;    // safe-to-spend ÷ days remaining in month
  final int daysLeftInMonth;
  final double spendingPacePercent; // % of month gone vs % of budget spent

  const FinancialSnapshot({
    required this.totalBalanceMinor,
    required this.availableBalanceMinor,
    required this.reservedBalanceMinor,
    required this.virtualAllocationsMinor,
    required this.savingsMinor,
    required this.safeToSpendMinor,
    required this.expectedIncomeMinor,
    required this.expectedExpensesMinor,
    required this.upcomingCommitmentsMinor,
    required this.currentMonthIncomeMinor,
    required this.currentMonthExpensesMinor,
    required this.netCashFlowMinor,
    required this.spendingTrendPercent,
    required this.savingsRate,
    required this.activePlansCount,
    required this.budgetHealth,
    required this.warnings,
    required this.opportunities,
    this.dailyBudgetMinor = 0,
    this.daysLeftInMonth = 30,
    this.spendingPacePercent = 0.0,
  });

  @override
  List<Object?> get props => [
        totalBalanceMinor,
        availableBalanceMinor,
        reservedBalanceMinor,
        virtualAllocationsMinor,
        savingsMinor,
        safeToSpendMinor,
        expectedIncomeMinor,
        expectedExpensesMinor,
        upcomingCommitmentsMinor,
        currentMonthIncomeMinor,
        currentMonthExpensesMinor,
        netCashFlowMinor,
        spendingTrendPercent,
        savingsRate,
        activePlansCount,
        budgetHealth,
        warnings,
        opportunities,
        dailyBudgetMinor,
        daysLeftInMonth,
        spendingPacePercent,
      ];
}

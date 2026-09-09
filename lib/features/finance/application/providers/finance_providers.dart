/// Finance-specific Riverpod providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/features/finance/data/repositories/source_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/transaction_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/category_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/purchase_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/budget_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/recurring_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/debt_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/split_transaction_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/virtual_split_repository.dart';
import 'package:follow_my_life/features/profile/data/profile_repository.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/features/finance/domain/entities/financial_snapshot.dart';
import 'package:follow_my_life/features/finance/domain/services/financial_snapshot_service.dart';
import 'package:follow_my_life/features/finance/domain/services/financial_summary_service.dart';

// ─── Repository Providers ─────────────────────────────────────
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(databaseProvider));
});

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SourceRepository(ref.watch(databaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(databaseProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(databaseProvider));
});

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref.watch(databaseProvider));
});

final splitTransactionRepositoryProvider = Provider<SplitTransactionRepository>((ref) {
  return SplitTransactionRepository(ref.watch(databaseProvider));
});

final virtualSplitRepositoryProvider = Provider<VirtualSplitRepository>((ref) {
  return VirtualSplitRepository(ref.watch(databaseProvider));
});

final activeVirtualSplitsProvider = StreamProvider<List<VirtualSplitWithItems>>((ref) {
  return ref.watch(virtualSplitRepositoryProvider).watchActiveSplits();
});

final splitsForTransactionProvider =
    StreamProvider.family<List<SplitTransaction>, String>((ref, transactionId) {
  final repo = ref.watch(splitTransactionRepositoryProvider);
  return repo.watchSplitsForTransaction(transactionId);
});

/// Active debts stream.
final activeDebtsProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(debtRepositoryProvider).watchActiveDebts();
});

// ─── Data Providers ───────────────────────────────────────────

/// Profile stream.
final profileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});

/// Active money sources stream.
final activeSourcesProvider = StreamProvider<List<MoneySource>>((ref) {
  return ref.watch(sourceRepositoryProvider).watchActiveSources();
});

/// Active categories stream.
final activeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchActiveCategories();
});
final categoriesProvider = activeCategoriesProvider;

/// Active planned purchases stream.
final activePurchasesProvider = StreamProvider<List<PlannedPurchase>>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchActivePurchases();
});
final purchasesProvider = activePurchasesProvider;

/// Active budgets stream.
final activeBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchActiveBudgets();
});

/// Active recurring transactions stream.
final activeRecurringProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  return ref.watch(recurringRepositoryProvider).watchActiveRecurring();
});
final recurringTransactionsProvider = activeRecurringProvider;

/// Recent transactions stream.
final recentTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider)
      .watchRecentTransactions(limit: 15);
});

/// Total balance across all sources.
final totalBalanceProvider = FutureProvider<int>((ref) async {
  // Watch sources to auto-refresh when sources change
  ref.watch(activeSourcesProvider);
  final result = await ref.watch(sourceRepositoryProvider).getTotalBalance();
  return result.when(success: (data) => data, failure: (_) => 0);
});

/// This month's summary (income + expenses).
final monthSummaryProvider =
    FutureProvider<({int totalIncome, int totalExpenses})>((ref) async {
  ref.watch(recentTransactionsProvider); // Auto-refresh
  final now = DateTime.now();
  final from = DateHelper.startOfMonth(now);
  final to = DateHelper.endOfMonth(now);
  final result = await ref.watch(transactionRepositoryProvider)
      .getPeriodSummary(from: from, to: to);
  return result.when(
    success: (data) => data,
    failure: (_) => (totalIncome: 0, totalExpenses: 0),
  );
});

/// Category spending for current month.
final categorySpendingProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(recentTransactionsProvider);
  final now = DateTime.now();
  final from = DateHelper.startOfMonth(now);
  final to = DateHelper.endOfMonth(now);
  final result = await ref.watch(transactionRepositoryProvider)
      .getCategorySpending(from: from, to: to);
  return result.when(success: (data) => data, failure: (_) => {});
});

/// Comprehensive reactive financial snapshot.
final financialSnapshotProvider = FutureProvider<FinancialSnapshot>((ref) async {
  final sources = ref.watch(activeSourcesProvider).valueOrNull ?? [];
  final plans = ref.watch(activePurchasesProvider).valueOrNull ?? [];
  final recurring = ref.watch(activeRecurringProvider).valueOrNull ?? [];
  final budgets = ref.watch(activeBudgetsProvider).valueOrNull ?? [];
  final debts = ref.watch(activeDebtsProvider).valueOrNull ?? [];
  final splitsWithItems = ref.watch(activeVirtualSplitsProvider).valueOrNull ?? [];
  final splits = splitsWithItems.map((s) => s.split).toList();

  final now = DateTime.now();
  final currentFrom = DateHelper.startOfMonth(now);
  final currentTo = DateHelper.endOfMonth(now);

  final prevMonthDate = DateTime(now.year, now.month - 1, 15);
  final prevFrom = DateHelper.startOfMonth(prevMonthDate);
  final prevTo = DateHelper.endOfMonth(prevMonthDate);

  final repo = ref.watch(transactionRepositoryProvider);
  final currentTxnRes = await repo.getTransactions(from: currentFrom, to: currentTo, limit: 300);
  final prevTxnRes = await repo.getTransactions(from: prevFrom, to: prevTo, limit: 300);

  final currentTxns = currentTxnRes.when(success: (l) => l, failure: (_) => <Transaction>[]);
  final prevTxns = prevTxnRes.when(success: (l) => l, failure: (_) => <Transaction>[]);

  return FinancialSnapshotService.computeSnapshot(
    sources: sources,
    currentMonthTransactions: currentTxns,
    previousMonthTransactions: prevTxns,
    plans: plans,
    virtualSplits: splits,
    recurringItems: recurring,
    budgets: budgets,
    debts: debts,
  );
});

/// Reconciled financial summary containing balances, safe-to-spend, plans, and period totals.
final financialSummaryProvider = FutureProvider<FinancialSummaryData>((ref) async {
  final sources = ref.watch(activeSourcesProvider).value ?? [];
  final purchases = ref.watch(activePurchasesProvider).value ?? [];
  final recurring = ref.watch(activeRecurringProvider).value ?? [];

  final now = DateTime.now();
  final from = DateHelper.startOfMonth(now);
  final to = DateHelper.endOfMonth(now);

  final txnResult = await ref.watch(transactionRepositoryProvider).getTransactions(
        from: from,
        to: to,
        limit: 300,
      );

  final txns = txnResult.when(
    success: (list) => list,
    failure: (_) => <Transaction>[],
  );

  return FinancialSummaryService.calculate(
    sources: sources,
    periodTransactions: txns,
    plans: purchases,
    recurringEvents: recurring,
  );
});

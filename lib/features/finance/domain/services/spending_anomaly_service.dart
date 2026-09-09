import 'package:follow_my_life/core/database/app_database.dart';

enum AnomalySeverity { low, medium, high }

class SpendingAnomaly {
  final String id;
  final String title;
  final String description;
  final AnomalySeverity severity;
  final String? categoryId;
  final String? transactionId;
  final DateTime detectedAt;

  const SpendingAnomaly({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    this.categoryId,
    this.transactionId,
    required this.detectedAt,
  });
}

class SpendingAnomalyService {
  static List<SpendingAnomaly> detectAnomalies({
    required List<Transaction> recentTransactions,
    required List<Transaction> historicalTransactions,
    required List<Category> categories,
  }) {
    final anomalies = <SpendingAnomaly>[];
    final categoryMap = {for (var c in categories) c.id: c.name};

    if (recentTransactions.isEmpty) return anomalies;

    // 1. Category Spending Spikes (Recent 30 days vs previous 60 days)
    final recentCategorySums = <String, int>{};
    final historicalCategorySums = <String, int>{};

    for (final t in recentTransactions) {
      if (t.type == 'expense' && t.status == 'completed' && t.categoryId != null) {
        recentCategorySums[t.categoryId!] = (recentCategorySums[t.categoryId!] ?? 0) + t.amountMinor;
      }
    }

    for (final t in historicalTransactions) {
      if (t.type == 'expense' && t.status == 'completed' && t.categoryId != null) {
        historicalCategorySums[t.categoryId!] = (historicalCategorySums[t.categoryId!] ?? 0) + t.amountMinor;
      }
    }

    recentCategorySums.forEach((catId, recentSum) {
      final historicalAvg = ((historicalCategorySums[catId] ?? 0) / 2.0).round();
      if (historicalAvg > 500000 && recentSum > (historicalAvg * 1.4)) {
        final categoryName = categoryMap[catId] ?? 'Category';
        final pctIncrease = (((recentSum - historicalAvg) / historicalAvg) * 100).round();
        anomalies.add(SpendingAnomaly(
          id: 'spike_$catId',
          title: '$categoryName Spending Spike',
          description: 'You spent $pctIncrease% more on $categoryName compared to your recent average.',
          severity: pctIncrease > 50 ? AnomalySeverity.high : AnomalySeverity.medium,
          categoryId: catId,
          detectedAt: DateTime.now(),
        ));
      }
    });

    // 2. Unusually Large Expense (Single Txn > 3x average transaction amount)
    final allExpenses = recentTransactions.where((t) => t.type == 'expense' && t.status == 'completed').toList();
    if (allExpenses.length > 3) {
      final totalAmount = allExpenses.fold<int>(0, (sum, t) => sum + t.amountMinor);
      final avgAmount = (totalAmount / allExpenses.length).round();

      for (final txn in allExpenses) {
        if (txn.amountMinor > (avgAmount * 3.5) && txn.amountMinor > 1000000) {
          final catName = categoryMap[txn.categoryId] ?? 'General';
          anomalies.add(SpendingAnomaly(
            id: 'large_txn_${txn.id}',
            title: 'Unusually Large Expense',
            description: 'Single expense of ${txn.amountMinor ~/ 100} in $catName is significantly above your average.',
            severity: AnomalySeverity.medium,
            transactionId: txn.id,
            categoryId: txn.categoryId,
            detectedAt: txn.date,
          ));
        }
      }
    }

    return anomalies;
  }
}

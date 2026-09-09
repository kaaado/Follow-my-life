
class FinancialHealthResult {
  final int score; // 0 to 100
  final String rating; // 'Excellent', 'Good', 'Fair', 'Needs Attention'
  final double savingsRate;
  final double debtToIncomeRatio;
  final double emergencyBufferMonths;
  final List<String> recommendations;

  const FinancialHealthResult({
    required this.score,
    required this.rating,
    required this.savingsRate,
    required this.debtToIncomeRatio,
    required this.emergencyBufferMonths,
    required this.recommendations,
  });
}

class FinancialHealthService {
  static FinancialHealthResult calculateHealth({
    required int totalAssetsMinor,
    required int totalMonthlyIncomeMinor,
    required int totalMonthlyExpensesMinor,
    required int totalDebtsMinor,
  }) {
    // 1. Savings Rate Score (Max 35 pts)
    double savingsRate = 0.0;
    if (totalMonthlyIncomeMinor > 0) {
      final savings = totalMonthlyIncomeMinor - totalMonthlyExpensesMinor;
      savingsRate = (savings / totalMonthlyIncomeMinor).clamp(0.0, 1.0);
    }
    final savingsScore = (savingsRate * 35).round();

    // 2. Debt-to-Income Score (Max 30 pts)
    double dti = 0.0;
    if (totalMonthlyIncomeMinor > 0) {
      dti = totalDebtsMinor / (totalMonthlyIncomeMinor * 12);
    } else if (totalDebtsMinor > 0) {
      dti = 1.0;
    }
    final dtiScore = ((1.0 - dti.clamp(0.0, 1.0)) * 30).round();

    // 3. Emergency Buffer Score (Max 35 pts)
    double bufferMonths = 0.0;
    if (totalMonthlyExpensesMinor > 0) {
      bufferMonths = totalAssetsMinor / totalMonthlyExpensesMinor;
    } else if (totalAssetsMinor > 0) {
      bufferMonths = 6.0;
    }
    final bufferScore = ((bufferMonths / 6.0).clamp(0.0, 1.0) * 35).round();

    final totalScore = (savingsScore + dtiScore + bufferScore).clamp(0, 100);

    String rating = 'Needs Attention';
    if (totalScore >= 80) {
      rating = 'Excellent';
    } else if (totalScore >= 65) {
      rating = 'Good';
    } else if (totalScore >= 45) {
      rating = 'Fair';
    }

    final recs = <String>[];
    if (savingsRate < 0.20) {
      recs.add('Aim to save at least 20% of monthly income.');
    }
    if (bufferMonths < 3.0) {
      recs.add('Build emergency reserve to cover 3 to 6 months of expenses.');
    }
    if (totalDebtsMinor > 0) {
      recs.add('Prioritize paying down high-interest outstanding debts.');
    }
    if (recs.isEmpty) {
      recs.add('Great financial posture! Maintain your current allocation strategy.');
    }

    return FinancialHealthResult(
      score: totalScore,
      rating: rating,
      savingsRate: savingsRate,
      debtToIncomeRatio: dti,
      emergencyBufferMonths: bufferMonths,
      recommendations: recs,
    );
  }
}

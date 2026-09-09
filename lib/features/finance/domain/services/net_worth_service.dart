import 'package:follow_my_life/core/database/app_database.dart';

class NetWorthResult {
  final int liquidAssetsMinor;
  final int receivablesMinor;
  final int totalAssetsMinor;
  final int liabilitiesMinor;
  final int netWorthMinor;

  const NetWorthResult({
    required this.liquidAssetsMinor,
    required this.receivablesMinor,
    required this.totalAssetsMinor,
    required this.liabilitiesMinor,
    required this.netWorthMinor,
  });
}

class NetWorthService {
  static NetWorthResult calculateNetWorth({
    required List<MoneySource> sources,
    required List<Debt> debts,
  }) {
    final liquidAssets = sources.fold<int>(0, (sum, s) => sum + s.cachedBalanceMinor);
    
    int receivables = 0;
    int liabilities = 0;

    for (final debt in debts) {
      final remaining = debt.amountMinor - debt.paidAmountMinor;
      if (remaining > 0) {
        if (debt.type == 'owed_to_me') {
          receivables += remaining;
        } else if (debt.type == 'i_owe') {
          liabilities += remaining;
        }
      }
    }

    final totalAssets = liquidAssets + receivables;
    final netWorth = totalAssets - liabilities;

    return NetWorthResult(
      liquidAssetsMinor: liquidAssets,
      receivablesMinor: receivables,
      totalAssetsMinor: totalAssets,
      liabilitiesMinor: liabilities,
      netWorthMinor: netWorth,
    );
  }
}

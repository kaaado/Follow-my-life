import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class SplitItemInput {
  final String? categoryId;
  final String? sourceId;
  final int amountMinor;
  final String currency;
  final double exchangeRate;
  final int? normalizedAmountMinor;
  final String? note;

  const SplitItemInput({
    this.categoryId,
    this.sourceId,
    required this.amountMinor,
    this.currency = 'DZD',
    this.exchangeRate = 1.0,
    this.normalizedAmountMinor,
    this.note,
  });
}

class SplitTransactionRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  SplitTransactionRepository(this._db);

  Stream<List<SplitTransaction>> watchSplitsForTransaction(String transactionId) {
    return (_db.select(_db.splitTransactions)..where((t) => t.transactionId.equals(transactionId)))
        .watch();
  }

  Future<List<SplitTransaction>> getSplitsForTransaction(String transactionId) async {
    return (_db.select(_db.splitTransactions)..where((t) => t.transactionId.equals(transactionId)))
        .get();
  }

  Future<Result<void>> saveSplitsForTransaction({
    required String transactionId,
    required List<SplitItemInput> splits,
  }) async {
    try {
      return await _db.transaction(() async {
        // Remove existing splits for this transaction
        await (_db.delete(_db.splitTransactions)
              ..where((t) => t.transactionId.equals(transactionId)))
            .go();

        // Insert new splits
        for (final item in splits) {
          await _db.into(_db.splitTransactions).insert(
                SplitTransactionsCompanion.insert(
                  id: _uuid.v4(),
                  transactionId: transactionId,
                  categoryId: Value(item.categoryId),
                  sourceId: Value(item.sourceId),
                  amountMinor: item.amountMinor,
                  currency: Value(item.currency),
                  exchangeRate: Value(item.exchangeRate),
                  normalizedAmountMinor: Value(item.normalizedAmountMinor),
                  note: Value(item.note),
                ),
              );
        }
        return const Success(null);
      });
    } catch (e) {
      return Failure(DatabaseFailure('Failed to save split transactions: $e'));
    }
  }
}

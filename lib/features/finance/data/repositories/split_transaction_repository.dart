import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class SplitItemInput {
  final String categoryId;
  final int amountMinor;
  final String? note;

  const SplitItemInput({
    required this.categoryId,
    required this.amountMinor,
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
                  categoryId: item.categoryId,
                  amountMinor: item.amountMinor,
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

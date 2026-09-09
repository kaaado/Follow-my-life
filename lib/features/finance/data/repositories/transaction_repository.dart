/// Transaction repository — the core financial engine.
/// Every money movement passes through this layer.
/// All mutations are atomic using database transactions.
library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class TransactionRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  TransactionRepository(this._db);

  Future<Result<Transaction?>> getTransactionById(String id) async {
    try {
      final txn = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
      return Success(txn);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to get transaction', e.toString()));
    }
  }

  // ─── Record Income ──────────────────────────────────────────
  Future<Result<Transaction>> recordIncome({
    required int amountMinor,
    required String sourceId,
    String? categoryId,
    String? incomeOrigin,
    required String description,
    required DateTime date,
    String currency = 'DZD',
    String? note,
    String? referenceId,
    String? referenceType,
  }) async {
    try {
      return await _db.transaction(() async {
        final id = 'txn_${_uuid.v4().substring(0, 12)}';

        await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
              id: id,
              type: 'income',
              amountMinor: amountMinor,
              currency: Value(currency),
              sourceId: sourceId,
              categoryId: Value(categoryId),
              incomeOrigin: Value(incomeOrigin),
              description: Value(description),
              note: Value(note),
              date: date,
              status: const Value('completed'),
              referenceId: Value(referenceId),
              referenceType: Value(referenceType),
            ));

        // Update source cached balance
        await _updateSourceBalance(sourceId, amountMinor);

        final txn = await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        return Success(txn);
      });
    } catch (e) {
      return Failure(TransactionFailure(
          "We couldn't save this income. Your money was not changed."));
    }
  }

  // ─── Record Expense ─────────────────────────────────────────
  Future<Result<Transaction>> recordExpense({
    required int amountMinor,
    required String sourceId,
    String? categoryId,
    String? payee,
    required String description,
    required DateTime date,
    String currency = 'DZD',
    String? note,
    String? referenceId,
    String? referenceType,
  }) async {
    try {
      return await _db.transaction(() async {
        // Check sufficient funds
        final source = await (_db.select(_db.moneySources)
              ..where((t) => t.id.equals(sourceId)))
            .getSingle();

        if (source.cachedBalanceMinor < amountMinor) {
          return Failure(InsufficientFundsFailure(
            available: source.cachedBalanceMinor,
            required_: amountMinor,
          ));
        }

        final id = 'txn_${_uuid.v4().substring(0, 12)}';

        await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
              id: id,
              type: 'expense',
              amountMinor: amountMinor,
              currency: Value(currency),
              sourceId: sourceId,
              categoryId: Value(categoryId),
              payee: Value(payee),
              description: Value(description),
              note: Value(note),
              date: date,
              status: const Value('completed'),
              referenceId: Value(referenceId),
              referenceType: Value(referenceType),
            ));

        // Update source cached balance
        await _updateSourceBalance(sourceId, -amountMinor);

        final txn = await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        return Success(txn);
      });
    } catch (e) {
      if (e is Result) return e as Result<Transaction>;
      return Failure(TransactionFailure(
          "We couldn't save this expense. Your money was not changed."));
    }
  }

  // ─── Record Transfer ────────────────────────────────────────
  Future<Result<Transfer>> recordTransfer({
    required String fromSourceId,
    required String toSourceId,
    required int amountMinor,
    required DateTime date,
    String currency = 'DZD',
    String? note,
  }) async {
    if (fromSourceId == toSourceId) {
      return const Failure(
          ValidationFailure('Cannot transfer to the same source.'));
    }
    try {
      return await _db.transaction(() async {
        final fromSource = await (_db.select(_db.moneySources)
              ..where((t) => t.id.equals(fromSourceId)))
            .getSingle();

        if (fromSource.cachedBalanceMinor < amountMinor) {
          return Failure(InsufficientFundsFailure(
            available: fromSource.cachedBalanceMinor,
            required_: amountMinor,
          ));
        }

        final transferId = 'trf_${_uuid.v4().substring(0, 12)}';

        await _db.into(_db.transfers).insert(TransfersCompanion.insert(
              id: transferId,
              fromSourceId: fromSourceId,
              toSourceId: toSourceId,
              amountMinor: amountMinor,
              currency: Value(currency),
              note: Value(note),
              date: date,
            ));

        // Deduct from source, add to destination
        await _updateSourceBalance(fromSourceId, -amountMinor);
        await _updateSourceBalance(toSourceId, amountMinor);

        final transfer = await (_db.select(_db.transfers)
              ..where((t) => t.id.equals(transferId)))
            .getSingle();
        return Success(transfer);
      });
    } catch (e) {
      return Failure(TransactionFailure(
          "We couldn't complete this transfer. No money was moved."));
    }
  }

  // ─── Queries ────────────────────────────────────────────────
  Future<Result<List<Transaction>>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? type,
    String? sourceId,
    String? categoryId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final query = _db.select(_db.transactions)
        ..orderBy([(t) => OrderingTerm.desc(t.date)])
        ..limit(limit, offset: offset);

      if (from != null) {
        query.where((t) => t.date.isBiggerOrEqualValue(from));
      }
      if (to != null) {
        query.where((t) => t.date.isSmallerOrEqualValue(to));
      }
      if (type != null) {
        query.where((t) => t.type.equals(type));
      }
      if (sourceId != null) {
        query.where((t) => t.sourceId.equals(sourceId));
      }
      if (categoryId != null) {
        query.where((t) => t.categoryId.equals(categoryId));
      }
      if (status != null) {
        query.where((t) => t.status.equals(status));
      }

      final results = await query.get();
      return Success(results);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to load transactions', e.toString()));
    }
  }

  Stream<List<Transaction>> watchRecentTransactions({int limit = 10}) {
    return (_db.select(_db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .watch();
  }

  /// Get income/expense summary for a period.
  Future<Result<({int totalIncome, int totalExpenses})>> getPeriodSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final transactions = await (_db.select(_db.transactions)
            ..where((t) =>
                t.date.isBiggerOrEqualValue(from) &
                t.date.isSmallerOrEqualValue(to) &
                t.status.equals('completed')))
          .get();

      int income = 0;
      int expenses = 0;

      for (final t in transactions) {
        if (t.type == 'income') income += t.amountMinor;
        if (t.type == 'expense') expenses += t.amountMinor;
      }

      return Success((totalIncome: income, totalExpenses: expenses));
    } catch (e) {
      return Failure(DatabaseFailure('Failed to get summary', e.toString()));
    }
  }

  /// Get spending by category for a period.
  Future<Result<Map<String, int>>> getCategorySpending({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final expenses = await (_db.select(_db.transactions)
            ..where((t) =>
                t.type.equals('expense') &
                t.status.equals('completed') &
                t.date.isBiggerOrEqualValue(from) &
                t.date.isSmallerOrEqualValue(to)))
          .get();

      final Map<String, int> spending = {};
      for (final t in expenses) {
        final catId = t.categoryId ?? 'other';
        spending[catId] = (spending[catId] ?? 0) + t.amountMinor;
      }

      return Success(spending);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to calculate category spending', e.toString()));
    }
  }
  Future<Result<bool>> deleteTransaction(String transactionId) async {
    try {
      return await _db.transaction(() async {
        final txn = await (_db.select(_db.transactions)
              ..where((t) => t.id.equals(transactionId)))
            .getSingleOrNull();

        if (txn == null) {
          return const Failure(NotFoundFailure('Transaction not found'));
        }

        // Reverse balance effect if completed
        if (txn.status == 'completed') {
          if (txn.type == 'income') {
            await _updateSourceBalance(txn.sourceId, -txn.amountMinor);
          } else if (txn.type == 'expense') {
            await _updateSourceBalance(txn.sourceId, txn.amountMinor);
          }
        }

        await (_db.delete(_db.transactions)..where((t) => t.id.equals(transactionId))).go();
        return const Success(true);
      });
    } catch (e) {
      return Failure(DatabaseFailure('Failed to delete transaction', e.toString()));
    }
  }

  Future<Result<Transaction>> recordRefund({
    required String originalExpenseId,
    required int refundAmountMinor,
    required DateTime date,
    String? note,
  }) async {
    try {
      return await _db.transaction(() async {
        final original = await (_db.select(_db.transactions)..where((t) => t.id.equals(originalExpenseId))).getSingleOrNull();
        if (original == null) {
          return const Failure(NotFoundFailure('Original transaction not found'));
        }

        final refundTxn = await recordIncome(
          amountMinor: refundAmountMinor,
          sourceId: original.sourceId,
          categoryId: original.categoryId,
          incomeOrigin: 'Refund: ${original.payee ?? original.description}',
          description: 'Refund for ${original.description}',
          date: date,
          currency: original.currency,
          note: note ?? 'Refund linked to ${original.id}',
          referenceId: original.id,
          referenceType: 'refund',
        );

        return refundTxn;
      });
    } catch (e) {
      return Failure(DatabaseFailure('Failed to record refund', e.toString()));
    }
  }

  // ─── Internal helpers ───────────────────────────────────────
  Future<void> _updateSourceBalance(String sourceId, int delta) async {
    final source = await (_db.select(_db.moneySources)
          ..where((t) => t.id.equals(sourceId)))
        .getSingle();

    await (_db.update(_db.moneySources)
          ..where((t) => t.id.equals(sourceId)))
        .write(MoneySourcesCompanion(
      cachedBalanceMinor: Value(source.cachedBalanceMinor + delta),
      updatedAt: Value(DateTime.now()),
    ));
  }
}

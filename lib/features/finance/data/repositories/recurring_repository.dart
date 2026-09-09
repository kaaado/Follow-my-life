library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class RecurringRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  RecurringRepository(this._db);

  Stream<List<RecurringTransaction>> watchActiveRecurring() {
    return (_db.select(_db.recurringTransactions)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.nextOccurrence)]))
        .watch();
  }

  Future<Result<RecurringTransaction>> createRecurring({
    required String description,
    required String type, // 'income', 'expense'
    required int amountMinor,
    required String frequency, // 'daily', 'weekly', 'monthly', 'yearly'
    required DateTime startDate,
    required String sourceId,
    String? categoryId,
    String currency = 'DZD',
  }) async {
    try {
      final id = 'rec_${_uuid.v4().substring(0, 12)}';
      
      await _db.into(_db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
            id: id,
            type: type,
            amountMinor: amountMinor,
            currency: Value(currency),
            sourceId: sourceId,
            categoryId: Value(categoryId),
            description: description,
            frequency: Value(frequency),
            nextOccurrence: startDate,
          ));

      final rec = await (_db.select(_db.recurringTransactions)..where((t) => t.id.equals(id))).getSingle();
      return Success(rec);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create recurring transaction', e.toString()));
    }
  }

  Future<Result<void>> executeOccurrence(String recurringId) async {
    try {
      return await _db.transaction(() async {
        final rec = await (_db.select(_db.recurringTransactions)..where((t) => t.id.equals(recurringId))).getSingle();
        final scheduled = rec.nextOccurrence;

        // 1. Idempotency Check
        final existingOccurrence = await (_db.select(_db.recurringOccurrences)
              ..where((t) => t.recurringId.equals(recurringId) & t.scheduledDate.equals(scheduled)))
            .getSingleOrNull();

        if (existingOccurrence != null && existingOccurrence.status == 'processed') {
          return const Success(null);
        }

        // 2. Find source balance
        final source = await (_db.select(_db.moneySources)..where((t) => t.id.equals(rec.sourceId))).getSingle();

        if (rec.type == 'expense' && source.cachedBalanceMinor < rec.amountMinor) {
          return Failure(InsufficientFundsFailure(
            available: source.cachedBalanceMinor,
            required_: rec.amountMinor,
          ));
        }

        // 3. Create Transaction
        final txnId = 'txn_${_uuid.v4().substring(0, 12)}';
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: txnId,
                type: rec.type,
                amountMinor: rec.amountMinor,
                currency: Value(rec.currency),
                sourceId: rec.sourceId,
                categoryId: Value(rec.categoryId),
                incomeOrigin: Value(rec.incomeOrigin),
                payee: Value(rec.payee),
                description: Value('Recurring: ${rec.description}'),
                date: DateTime.now(),
                status: const Value('completed'),
                referenceId: Value(rec.id),
                referenceType: const Value('recurring'),
              ),
            );

        // 4. Update Money Source balance
        final balanceDelta = rec.type == 'income' ? rec.amountMinor : -rec.amountMinor;
        await (_db.update(_db.moneySources)..where((t) => t.id.equals(rec.sourceId))).write(
          MoneySourcesCompanion(
            cachedBalanceMinor: Value(source.cachedBalanceMinor + balanceDelta),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // 5. Insert Occurrence Record
        final occId = 'occ_${_uuid.v4().substring(0, 12)}';
        await _db.into(_db.recurringOccurrences).insert(
              RecurringOccurrencesCompanion.insert(
                id: occId,
                recurringId: rec.id,
                scheduledDate: scheduled,
                processedAt: Value(DateTime.now()),
                status: const Value('processed'),
                transactionId: Value(txnId),
              ),
            );

        // 6. Calculate Next Date
        DateTime nextDate;
        switch (rec.frequency.toLowerCase()) {
          case 'daily':
            nextDate = rec.nextOccurrence.add(const Duration(days: 1));
            break;
          case 'weekly':
            nextDate = rec.nextOccurrence.add(const Duration(days: 7));
            break;
          case 'yearly':
            nextDate = DateTime(rec.nextOccurrence.year + 1, rec.nextOccurrence.month, rec.nextOccurrence.day);
            break;
          case 'monthly':
          default:
            nextDate = DateTime(rec.nextOccurrence.year, rec.nextOccurrence.month + 1, rec.nextOccurrence.day);
            break;
        }

        await (_db.update(_db.recurringTransactions)..where((t) => t.id.equals(rec.id))).write(
          RecurringTransactionsCompanion(
            lastProcessed: Value(DateTime.now()),
            nextOccurrence: Value(nextDate),
            updatedAt: Value(DateTime.now()),
          ),
        );

        return const Success(null);
      });
    } catch (e) {
      if (e is Result) return e as Result<void>;
      return Failure(DatabaseFailure('Failed to execute recurring occurrence', e.toString()));
    }
  }

  Future<Result<void>> checkAndAutoExecuteDue() async {
    try {
      final now = DateTime.now();
      final dueItems = await (_db.select(_db.recurringTransactions)
            ..where((t) => t.isActive.equals(true) & t.autoExecute.equals(true) & t.nextOccurrence.isSmallerOrEqualValue(now)))
          .get();

      for (final item in dueItems) {
        await executeOccurrence(item.id);
      }
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to auto-execute due items', e.toString()));
    }
  }

  Future<Result<void>> updateRecurring({
    required String id,
    required String description,
    required int amountMinor,
    required String frequency,
    required String sourceId,
    String? categoryId,
  }) async {
    try {
      await (_db.update(_db.recurringTransactions)..where((t) => t.id.equals(id))).write(
        RecurringTransactionsCompanion(
          description: Value(description),
          amountMinor: Value(amountMinor),
          frequency: Value(frequency),
          sourceId: Value(sourceId),
          categoryId: Value(categoryId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to update recurring transaction', e.toString()));
    }
  }

  Future<Result<void>> deleteRecurring(String id) async {
    try {
      await (_db.update(_db.recurringTransactions)..where((t) => t.id.equals(id))).write(
        RecurringTransactionsCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to delete recurring transaction', e.toString()));
    }
  }
}

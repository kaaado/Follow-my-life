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

  Stream<List<RecurringTransaction>> watchAllRecurring() {
    return (_db.select(_db.recurringTransactions)
          ..orderBy([(t) => OrderingTerm.desc(t.isActive), (t) => OrderingTerm.asc(t.nextOccurrence)]))
        .watch();
  }

  /// Calculates max days in a given month handling leap years.
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  /// Calculates next occurrence date with day clamping to prevent invalid calendar overflow.
  static DateTime calculateNextOccurrence(DateTime fromDate, String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return fromDate.add(const Duration(days: 1));
      case 'weekly':
        return fromDate.add(const Duration(days: 7));
      case 'yearly':
        final targetYear = fromDate.year + 1;
        final maxDays = daysInMonth(targetYear, fromDate.month);
        final day = fromDate.day > maxDays ? maxDays : fromDate.day;
        return DateTime(targetYear, fromDate.month, day, fromDate.hour, fromDate.minute);
      case 'monthly':
      default:
        var targetYear = fromDate.year;
        var targetMonth = fromDate.month + 1;
        if (targetMonth > 12) {
          targetMonth = 1;
          targetYear += 1;
        }
        final maxDays = daysInMonth(targetYear, targetMonth);
        final day = fromDate.day > maxDays ? maxDays : fromDate.day;
        return DateTime(targetYear, targetMonth, day, fromDate.hour, fromDate.minute);
    }
  }

  /// Checks if any active recurring items lack a valid active destination/funding source.
  Future<List<RecurringTransaction>> getItemsRequiringAttention() async {
    try {
      final activeItems = await (_db.select(_db.recurringTransactions)
            ..where((t) => t.isActive.equals(true)))
          .get();

      final sources = await (_db.select(_db.moneySources)
            ..where((t) => t.isActive.equals(true)))
          .get();
      final validSourceIds = sources.map((s) => s.id).toSet();

      return activeItems.where((item) => !validSourceIds.contains(item.sourceId)).toList();
    } catch (_) {
      return [];
    }
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
    bool isActive = true,
    bool autoExecute = true,
    String? payee,
    String? incomeOrigin,
  }) async {
    try {
      if (sourceId.trim().isEmpty) {
        return const Failure(ValidationFailure('A valid destination/source must be selected.'));
      }

      // Validate source exists and is active
      final source = await (_db.select(_db.moneySources)
            ..where((t) => t.id.equals(sourceId) & t.isActive.equals(true)))
          .getSingleOrNull();

      if (source == null) {
        return const Failure(ValidationFailure('Selected source does not exist or is inactive.'));
      }

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
            isActive: Value(isActive),
            autoExecute: Value(autoExecute),
            payee: Value(payee),
            incomeOrigin: Value(incomeOrigin),
          ));

      final rec = await (_db.select(_db.recurringTransactions)..where((t) => t.id.equals(id))).getSingle();
      return Success(rec);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create recurring transaction: $e'));
    }
  }

  Future<Result<void>> executeOccurrence(String recurringId, {DateTime? targetScheduledDate}) async {
    try {
      return await _db.transaction(() async {
        final rec = await (_db.select(_db.recurringTransactions)..where((t) => t.id.equals(recurringId))).getSingleOrNull();
        if (rec == null) {
          return const Failure(NotFoundFailure('Recurring transaction not found'));
        }

        final scheduled = targetScheduledDate ?? rec.nextOccurrence;
        final occId = 'occ_${rec.id}_${scheduled.year}${scheduled.month.toString().padLeft(2, '0')}${scheduled.day.toString().padLeft(2, '0')}';

        // 1. Deterministic Idempotency Check
        final existingOccurrence = await (_db.select(_db.recurringOccurrences)
              ..where((t) => t.recurringId.equals(recurringId) & t.scheduledDate.equals(scheduled)))
            .getSingleOrNull();

        if (existingOccurrence != null && existingOccurrence.status == 'processed') {
          // Already generated this scheduled occurrence!
          // Advance nextOccurrence if still stuck at or before this processed date
          if (rec.nextOccurrence.isAtSameMomentAs(scheduled) || rec.nextOccurrence.isBefore(scheduled)) {
            final nextDate = calculateNextOccurrence(scheduled, rec.frequency);
            await (_db.update(_db.recurringTransactions)..where((t) => t.id.equals(rec.id))).write(
              RecurringTransactionsCompanion(
                nextOccurrence: Value(nextDate),
                lastProcessed: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
          return const Success(null);
        }

        // 2. Validate Source Existence & Active State
        final source = await (_db.select(_db.moneySources)..where((t) => t.id.equals(rec.sourceId))).getSingleOrNull();
        if (source == null || !source.isActive) {
          // Do NOT create transaction or corrupt ledger; record failure status
          await _db.into(_db.recurringOccurrences).insertOnConflictUpdate(
                RecurringOccurrencesCompanion.insert(
                  id: occId,
                  recurringId: rec.id,
                  scheduledDate: scheduled,
                  processedAt: Value(DateTime.now()),
                  status: const Value('failed'),
                ),
              );
          return Failure(ValidationFailure(
            'Source for recurring "${rec.description}" is missing or inactive. Please assign a valid source.',
          ));
        }

        // 3. Balance Check for Expenses
        if (rec.type == 'expense' && source.cachedBalanceMinor < rec.amountMinor) {
          return Failure(InsufficientFundsFailure(
            available: source.cachedBalanceMinor,
            required_: rec.amountMinor,
          ));
        }

        // 4. Create Transaction Linked to Scheduled Date
        final txnId = 'txn_${_uuid.v4().substring(0, 12)}';
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: txnId,
                type: rec.type,
                amountMinor: rec.amountMinor,
                currency: Value(rec.currency),
                sourceId: rec.sourceId,
                categoryId: Value(rec.categoryId),
                incomeOrigin: Value(rec.incomeOrigin ?? (rec.type == 'income' ? rec.description : null)),
                payee: Value(rec.payee ?? (rec.type == 'expense' ? rec.description : null)),
                description: Value('Recurring: ${rec.description}'),
                date: scheduled,
                status: const Value('completed'),
                referenceId: Value(rec.id),
                referenceType: const Value('recurring'),
              ),
            );

        // 5. Update Money Source balance atomically
        final balanceDelta = rec.type == 'income' ? rec.amountMinor : -rec.amountMinor;
        await (_db.update(_db.moneySources)..where((t) => t.id.equals(rec.sourceId))).write(
          MoneySourcesCompanion(
            cachedBalanceMinor: Value(source.cachedBalanceMinor + balanceDelta),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // 6. Insert Unique Occurrence Record
        await _db.into(_db.recurringOccurrences).insertOnConflictUpdate(
              RecurringOccurrencesCompanion.insert(
                id: occId,
                recurringId: rec.id,
                scheduledDate: scheduled,
                processedAt: Value(DateTime.now()),
                status: const Value('processed'),
                transactionId: Value(txnId),
              ),
            );

        // 7. Calculate and advance Next Occurrence date safely
        final nextDate = calculateNextOccurrence(scheduled, rec.frequency);
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
      return Failure(DatabaseFailure('Failed to execute recurring occurrence: $e'));
    }
  }

  /// Scans for all due and missed occurrences up to now and executes them sequentially.
  /// Missed Recurrence Policy:
  /// Each due period is executed deterministically one by one until nextOccurrence > now.
  /// A safety limit of 24 periods prevents infinite loops.
  Future<Result<int>> checkAndAutoExecuteDue() async {
    try {
      final now = DateTime.now();
      final dueItems = await (_db.select(_db.recurringTransactions)
            ..where((t) => t.isActive.equals(true) & t.autoExecute.equals(true) & t.nextOccurrence.isSmallerOrEqualValue(now)))
          .get();

      int executedCount = 0;

      for (final item in dueItems) {
        var currentItem = item;
        int catchupIterations = 0;

        // Catch up all missed occurrences up to now (capped at 24 iterations)
        while (currentItem.nextOccurrence.isBefore(now) || currentItem.nextOccurrence.isAtSameMomentAs(now)) {
          if (catchupIterations >= 24) break;

          final result = await executeOccurrence(currentItem.id, targetScheduledDate: currentItem.nextOccurrence);
          if (result.isFailure) {
            // Stop catchup on error (e.g. insufficient funds or missing source)
            break;
          }

          executedCount++;
          catchupIterations++;

          // Re-fetch updated next occurrence
          final updated = await (_db.select(_db.recurringTransactions)
                ..where((t) => t.id.equals(currentItem.id)))
              .getSingleOrNull();

          if (updated == null || !updated.isActive || updated.nextOccurrence.isAtSameMomentAs(currentItem.nextOccurrence)) {
            break;
          }
          currentItem = updated;
        }
      }

      return Success(executedCount);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to auto-execute due items: $e'));
    }
  }

  Future<Result<void>> updateRecurring({
    required String id,
    required String description,
    required int amountMinor,
    required String frequency,
    required String sourceId,
    String? categoryId,
    bool? isActive,
    bool? autoExecute,
    DateTime? nextOccurrence,
  }) async {
    try {
      // Validate source
      if (sourceId.trim().isNotEmpty) {
        final source = await (_db.select(_db.moneySources)..where((t) => t.id.equals(sourceId))).getSingleOrNull();
        if (source == null || !source.isActive) {
          return const Failure(ValidationFailure('Selected source does not exist or is inactive.'));
        }
      }

      await (_db.update(_db.recurringTransactions)..where((t) => t.id.equals(id))).write(
        RecurringTransactionsCompanion(
          description: Value(description),
          amountMinor: Value(amountMinor),
          frequency: Value(frequency),
          sourceId: Value(sourceId),
          categoryId: Value(categoryId),
          isActive: isActive != null ? Value(isActive) : const Value.absent(),
          autoExecute: autoExecute != null ? Value(autoExecute) : const Value.absent(),
          nextOccurrence: nextOccurrence != null ? Value(nextOccurrence) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to update recurring transaction: $e'));
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
      return Failure(DatabaseFailure('Failed to delete recurring transaction: $e'));
    }
  }
}

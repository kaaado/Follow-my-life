import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:uuid/uuid.dart';

class DebtRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  DebtRepository(this._db);

  Stream<List<Debt>> watchDebts() {
    return (_db.select(_db.debts)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<Debt>> watchActiveDebts() {
    return (_db.select(_db.debts)
          ..where((t) => t.status.isIn(['active', 'partially_paid', 'overdue']))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<Result<Debt>> getDebtById(String id) async {
    try {
      final item = await (_db.select(_db.debts)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (item == null) {
        return const Failure(DatabaseFailure('Debt record not found'));
      }
      return Success(item);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to get debt: $e'));
    }
  }

  Future<Result<String>> createDebt({
    required String personName,
    required String type, // 'i_owe' or 'owed_to_me'
    required int amountMinor,
    String currency = 'DZD',
    DateTime? dueDate,
    String? notes,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: id,
              personName: personName,
              type: type,
              amountMinor: amountMinor,
              paidAmountMinor: const Value(0),
              currency: Value(currency),
              dueDate: Value(dueDate),
              status: const Value('active'),
              notes: Value(notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return Success(id);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create debt: $e'));
    }
  }

  Future<Result<void>> recordPayment({
    required String debtId,
    required String sourceId,
    required int amountMinor,
    required DateTime date,
    String? notes,
  }) async {
    try {
      return await _db.transaction(() async {
        final debt = await (_db.select(_db.debts)..where((t) => t.id.equals(debtId))).getSingleOrNull();
        if (debt == null) {
          return const Failure(DatabaseFailure('Debt not found'));
        }

        final source = await (_db.select(_db.moneySources)..where((t) => t.id.equals(sourceId))).getSingleOrNull();
        if (source == null) {
          return const Failure(DatabaseFailure('Account source not found'));
        }

        final isIOwe = debt.type == 'i_owe';
        final newPaid = debt.paidAmountMinor + amountMinor;
        String newStatus = debt.status;
        if (newPaid >= debt.amountMinor) {
          newStatus = 'paid';
        } else {
          newStatus = 'partially_paid';
        }

        // 1. Update debt
        await (_db.update(_db.debts)..where((t) => t.id.equals(debtId))).write(
          DebtsCompanion(
            paidAmountMinor: Value(newPaid),
            status: Value(newStatus),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // 2. Create transaction (expense if paying back what I owe; income if collecting owed to me)
        final txnId = _uuid.v4();
        final txnType = isIOwe ? 'expense' : 'income';
        final txnDesc = isIOwe
            ? 'Debt Repayment to ${debt.personName}'
            : 'Debt Collection from ${debt.personName}';

        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: txnId,
                type: txnType,
                amountMinor: amountMinor,
                currency: Value(debt.currency),
                sourceId: sourceId,
                payee: Value(isIOwe ? debt.personName : null),
                incomeOrigin: Value(isIOwe ? null : debt.personName),
                description: Value(txnDesc),
                note: Value(notes ?? 'Debt reference: ${debt.id}'),
                date: date,
                referenceId: Value(debt.id),
                referenceType: const Value('debt_payment'),
              ),
            );

        // 3. Update source balance
        final newBalance = isIOwe
            ? source.cachedBalanceMinor - amountMinor
            : source.cachedBalanceMinor + amountMinor;

        await (_db.update(_db.moneySources)..where((t) => t.id.equals(sourceId))).write(
          MoneySourcesCompanion(
            cachedBalanceMinor: Value(newBalance),
            updatedAt: Value(DateTime.now()),
          ),
        );

        return const Success(null);
      });
    } catch (e) {
      return Failure(DatabaseFailure('Failed to record debt payment: $e'));
    }
  }

  Future<Result<void>> deleteDebt(String id) async {
    try {
      await (_db.delete(_db.debts)..where((t) => t.id.equals(id))).go();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to delete debt: $e'));
    }
  }
}

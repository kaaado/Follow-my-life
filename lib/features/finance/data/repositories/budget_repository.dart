library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class BudgetRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  BudgetRepository(this._db);

  Stream<List<Budget>> watchActiveBudgets() {
    return (_db.select(_db.budgets)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Result<Budget>> createBudget({
    required int amountMinor,
    required String categoryId,
    required int year,
    required int month,
    String currency = 'DZD',
  }) async {
    try {
      final id = 'bdg_${_uuid.v4().substring(0, 12)}';
      
      await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
            id: id,
            categoryId: categoryId,
            amountMinor: amountMinor,
            currency: Value(currency),
            year: year,
            month: month,
          ));

      final budget = await (_db.select(_db.budgets)..where((t) => t.id.equals(id))).getSingle();
      return Success(budget);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create budget', e.toString()));
    }
  }
}

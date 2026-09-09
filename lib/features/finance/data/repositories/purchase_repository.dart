/// Planned Purchase repository.
library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class PurchaseRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  PurchaseRepository(this._db);

  Future<Result<List<PlannedPurchase>>> getActivePurchases() async {
    try {
      final purchases = await (_db.select(_db.plannedPurchases)
            ..where((t) => t.status.isIn(['planned', 'saving', 'ready']))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      return Success(purchases);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to load purchases', e.toString()));
    }
  }

  Stream<List<PlannedPurchase>> watchActivePurchases() {
    return (_db.select(_db.plannedPurchases)
          ..where((t) => t.status.isIn(['planned', 'saving', 'ready']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Result<void>> updateReservedAmount(String id, int reservedAmountMinor) async {
    try {
      final pur = await (_db.select(_db.plannedPurchases)..where((t) => t.id.equals(id))).getSingle();
      String newStatus = pur.status;
      if (reservedAmountMinor >= pur.estimatedAmountMinor) {
        newStatus = 'ready';
      } else if (reservedAmountMinor > 0) {
        newStatus = 'saving';
      } else {
        newStatus = 'planned';
      }

      await (_db.update(_db.plannedPurchases)..where((t) => t.id.equals(id))).write(
        PlannedPurchasesCompanion(
          reservedAmountMinor: Value(reservedAmountMinor),
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to update reserved amount', e.toString()));
    }
  }

  Future<Result<void>> deletePurchase(String id) async {
    try {
      await (_db.delete(_db.plannedPurchases)..where((t) => t.id.equals(id))).go();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to delete purchase', e.toString()));
    }
  }

  Future<Result<void>> updatePurchase({
    required String id,
    required String name,
    required int estimatedAmountMinor,
    String? categoryId,
    String priority = 'medium',
    DateTime? targetDate,
  }) async {
    try {
      await (_db.update(_db.plannedPurchases)..where((t) => t.id.equals(id))).write(
        PlannedPurchasesCompanion(
          name: Value(name),
          estimatedAmountMinor: Value(estimatedAmountMinor),
          categoryId: Value(categoryId),
          priority: Value(priority),
          targetDate: Value(targetDate),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to update purchase', e.toString()));
    }
  }

  Future<Result<PlannedPurchase>> createPurchase({
    required String name,
    required int estimatedAmountMinor,
    String? categoryId,
    String priority = 'medium',
    DateTime? targetDate,
    String currency = 'DZD',
  }) async {
    try {
      final id = 'pur_${_uuid.v4().substring(0, 12)}';
      await _db.into(_db.plannedPurchases).insert(PlannedPurchasesCompanion.insert(
            id: id,
            name: name,
            estimatedAmountMinor: estimatedAmountMinor,
            categoryId: Value(categoryId),
            priority: Value(priority),
            targetDate: Value(targetDate),
            currency: Value(currency),
          ));

      final pur = await (_db.select(_db.plannedPurchases)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      return Success(pur);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create purchase', e.toString()));
    }
  }

  Future<Result<void>> markAsPurchased(String id, int actualAmountMinor, String sourceId) async {
    try {
      return await _db.transaction(() async {
        // Find purchase
        final pur = await (_db.select(_db.plannedPurchases)..where((t) => t.id.equals(id))).getSingle();
        
        // Find source
        final source = await (_db.select(_db.moneySources)..where((t) => t.id.equals(sourceId))).getSingle();
        
        if (source.cachedBalanceMinor < actualAmountMinor) {
          return Failure(InsufficientFundsFailure(
            available: source.cachedBalanceMinor,
            required_: actualAmountMinor,
          ));
        }

        // Create expense transaction
        final txnId = 'txn_${_uuid.v4().substring(0, 12)}';
        await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
              id: txnId,
              type: 'expense',
              amountMinor: actualAmountMinor,
              currency: Value(pur.currency),
              sourceId: sourceId,
              categoryId: Value(pur.categoryId),
              description: Value('Purchased: ${pur.name}'),
              date: DateTime.now(),
              status: const Value('completed'),
              referenceId: Value(id),
              referenceType: const Value('purchase'),
            ));

        // Deduct source
        await (_db.update(_db.moneySources)..where((t) => t.id.equals(sourceId)))
            .write(MoneySourcesCompanion(
          cachedBalanceMinor: Value(source.cachedBalanceMinor - actualAmountMinor),
          updatedAt: Value(DateTime.now()),
        ));

        // Update purchase status
        await (_db.update(_db.plannedPurchases)..where((t) => t.id.equals(id)))
            .write(PlannedPurchasesCompanion(
          status: const Value('purchased'),
          actualAmountMinor: Value(actualAmountMinor),
          transactionId: Value(txnId),
          updatedAt: Value(DateTime.now()),
        ));

        return const Success(null);
      });
    } catch (e) {
      if (e is Result) return e as Result<void>;
      return Failure(DatabaseFailure('Failed to complete purchase', e.toString()));
    }
  }
}

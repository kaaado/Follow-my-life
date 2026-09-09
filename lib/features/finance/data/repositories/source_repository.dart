/// Money sources repository.
library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:uuid/uuid.dart';

class SourceRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  SourceRepository(this._db);

  // ─── Queries ────────────────────────────────────────────────
  Future<Result<List<MoneySource>>> getActiveSources() async {
    try {
      final sources = await (_db.select(_db.moneySources)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      return Success(sources);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to load sources', e.toString()));
    }
  }

  Future<Result<MoneySource>> getSource(String id) async {
    try {
      final source = await (_db.select(_db.moneySources)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (source == null) return const Failure(NotFoundFailure('Source not found'));
      return Success(source);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to load source', e.toString()));
    }
  }

  Stream<List<MoneySource>> watchActiveSources() {
    return (_db.select(_db.moneySources)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  // ─── Mutations ──────────────────────────────────────────────
  Future<Result<MoneySource>> createSource({
    required String name,
    required SourceType type,
    String currency = 'DZD',
    String icon = 'wallet',
    int colorIndex = 0,
    int initialBalanceMinor = 0,
  }) async {
    try {
      final id = 'src_${_uuid.v4().substring(0, 8)}';
      await _db.into(_db.moneySources).insert(MoneySourcesCompanion.insert(
            id: id,
            name: name,
            type: type,
            currency: Value(currency),
            icon: Value(icon),
            colorIndex: Value(colorIndex),
            initialBalanceMinor: Value(initialBalanceMinor),
            cachedBalanceMinor: Value(initialBalanceMinor),
          ));
      return getSource(id);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create source', e.toString()));
    }
  }

  Future<Result<MoneySource>> updateSource(
    String id, {
    String? name,
    String? icon,
    int? colorIndex,
  }) async {
    try {
      await (_db.update(_db.moneySources)..where((t) => t.id.equals(id)))
          .write(MoneySourcesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        colorIndex: colorIndex != null ? Value(colorIndex) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));
      return getSource(id);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to update source', e.toString()));
    }
  }

  Future<Result<void>> archiveSource(String id) async {
    try {
      await (_db.update(_db.moneySources)..where((t) => t.id.equals(id)))
          .write(const MoneySourcesCompanion(
        isActive: Value(false),
        updatedAt: Value.absent(),
      ));
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to archive source', e.toString()));
    }
  }

  Future<Result<void>> deleteSource(String id) async {
    try {
      await (_db.delete(_db.moneySources)..where((t) => t.id.equals(id))).go();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to delete source', e.toString()));
    }
  }

  /// Recalculate cached balance from transaction ledger.
  Future<Result<int>> recalculateBalance(String sourceId) async {
    try {
      // Get initial balance
      final source = await (_db.select(_db.moneySources)
            ..where((t) => t.id.equals(sourceId)))
          .getSingle();
      int balance = source.initialBalanceMinor;

      // Add completed income for this source
      final incomes = await (_db.select(_db.transactions)
            ..where((t) =>
                t.sourceId.equals(sourceId) &
                t.type.equals('income') &
                t.status.equals('completed')))
          .get();
      for (final t in incomes) {
        balance += t.amountMinor;
      }

      // Subtract completed expenses for this source
      final expenses = await (_db.select(_db.transactions)
            ..where((t) =>
                t.sourceId.equals(sourceId) &
                t.type.equals('expense') &
                t.status.equals('completed')))
          .get();
      for (final t in expenses) {
        balance -= t.amountMinor;
      }

      // Add incoming transfers (this source is toSourceId)
      final inTransfers = await (_db.select(_db.transfers)
            ..where((t) =>
                t.toSourceId.equals(sourceId) &
                t.status.equals('completed')))
          .get();
      for (final t in inTransfers) {
        balance += t.amountMinor;
      }

      // Subtract outgoing transfers (this source is fromSourceId)
      final outTransfers = await (_db.select(_db.transfers)
            ..where((t) =>
                t.fromSourceId.equals(sourceId) &
                t.status.equals('completed')))
          .get();
      for (final t in outTransfers) {
        balance -= t.amountMinor;
      }

      // Update cached balance
      await (_db.update(_db.moneySources)
            ..where((t) => t.id.equals(sourceId)))
          .write(MoneySourcesCompanion(
        cachedBalanceMinor: Value(balance),
        updatedAt: Value(DateTime.now()),
      ));

      return Success(balance);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to recalculate balance', e.toString()));
    }
  }

  /// Get total balance across all active sources.
  Future<Result<int>> getTotalBalance() async {
    try {
      final sources = await (_db.select(_db.moneySources)
            ..where((t) => t.isActive.equals(true)))
          .get();
      final total = sources.fold<int>(0, (sum, s) => sum + s.cachedBalanceMinor);
      return Success(total);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to get total balance', e.toString()));
    }
  }
}

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class VirtualSplitWithItems {
  final VirtualSplit split;
  final List<VirtualSplitItem> items;
  final MoneySource? source;

  VirtualSplitWithItems({
    required this.split,
    required this.items,
    this.source,
  });
}

class VirtualSplitRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  VirtualSplitRepository(this._db);

  Stream<List<VirtualSplitWithItems>> watchActiveSplits() {
    final query = _db.select(_db.virtualSplits)
      ..where((tbl) => tbl.status.equals('active'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

    return query.watch().asyncMap((splits) async {
      final list = <VirtualSplitWithItems>[];
      for (final split in splits) {
        final items = await (_db.select(_db.virtualSplitItems)
              ..where((tbl) => tbl.splitId.equals(split.id)))
            .get();

        final source = await (_db.select(_db.moneySources)
              ..where((tbl) => tbl.id.equals(split.sourceId)))
            .getSingleOrNull();

        list.add(VirtualSplitWithItems(
          split: split,
          items: items,
          source: source,
        ));
      }
      return list;
    });
  }

  Future<String> createVirtualSplit({
    required String name,
    required String sourceId,
    required List<({String categoryId, int amountMinor, String? note})> items,
    String currency = 'DZD',
  }) async {
    final splitId = _uuid.v4();
    final totalAmount = items.fold<int>(0, (sum, item) => sum + item.amountMinor);

    await _db.transaction(() async {
      await _db.into(_db.virtualSplits).insert(
            VirtualSplitsCompanion.insert(
              id: splitId,
              name: name,
              sourceId: sourceId,
              totalAmountMinor: totalAmount,
              currency: Value(currency),
              status: const Value('active'),
            ),
          );

      for (final item in items) {
        await _db.into(_db.virtualSplitItems).insert(
              VirtualSplitItemsCompanion.insert(
                id: _uuid.v4(),
                splitId: splitId,
                categoryId: item.categoryId,
                amountMinor: item.amountMinor,
                note: Value(item.note),
              ),
            );
      }
    });

    return splitId;
  }

  /// Atomic Transaction Engine to apply a virtual split to actual ledger
  Future<bool> applyVirtualSplit(String splitId) async {
    return await _db.transaction(() async {
      final split = await (_db.select(_db.virtualSplits)
            ..where((tbl) => tbl.id.equals(splitId)))
          .getSingleOrNull();

      if (split == null || split.status != 'active') {
        // Idempotency check: Already applied or cancelled
        return false;
      }

      final source = await (_db.select(_db.moneySources)
            ..where((tbl) => tbl.id.equals(split.sourceId)))
          .getSingleOrNull();

      if (source == null || source.cachedBalanceMinor < split.totalAmountMinor) {
        // Insufficient funds guard
        await (_db.update(_db.virtualSplits)..where((tbl) => tbl.id.equals(splitId)))
            .write(const VirtualSplitsCompanion(status: Value('failed')));
        return false;
      }

      // Mark status as applying
      await (_db.update(_db.virtualSplits)..where((tbl) => tbl.id.equals(splitId)))
          .write(const VirtualSplitsCompanion(status: Value('applying')));

      final items = await (_db.select(_db.virtualSplitItems)
            ..where((tbl) => tbl.splitId.equals(splitId)))
          .get();

      final now = DateTime.now();

      for (final item in items) {
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: _uuid.v4(),
                type: 'expense',
                amountMinor: item.amountMinor,
                currency: Value(split.currency),
                sourceId: split.sourceId,
                categoryId: Value(item.categoryId),
                description: Value('${split.name} (Virtual Split)'),
                note: Value(item.note),
                date: now,
                status: const Value('completed'),
                referenceId: Value(splitId),
                referenceType: const Value('virtual_split'),
              ),
            );
      }

      // Update Money Source cached balance
      final newBalance = source.cachedBalanceMinor - split.totalAmountMinor;
      await (_db.update(_db.moneySources)..where((tbl) => tbl.id.equals(split.sourceId)))
          .write(MoneySourcesCompanion(cachedBalanceMinor: Value(newBalance)));

      // Finalize split status to applied
      await (_db.update(_db.virtualSplits)..where((tbl) => tbl.id.equals(splitId))).write(
        VirtualSplitsCompanion(
          status: const Value('applied'),
          appliedAt: Value(now),
        ),
      );

      return true;
    });
  }

  Future<void> cancelVirtualSplit(String splitId) async {
    await (_db.update(_db.virtualSplits)..where((tbl) => tbl.id.equals(splitId)))
        .write(const VirtualSplitsCompanion(status: Value('cancelled')));
  }
}

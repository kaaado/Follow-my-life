/// Transaction repository — the core financial engine.
/// Every money movement passes through this layer.
/// All mutations are atomic using database transactions.
library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:follow_my_life/core/utils/currency_conversion_service.dart';
import 'package:follow_my_life/features/finance/data/repositories/split_transaction_repository.dart';
import 'package:uuid/uuid.dart';

class PagedTransactionsResult {
  final List<Transaction> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const PagedTransactionsResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });
}

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

  // ─── Record Split Expense ───────────────────────────────────
  Future<Result<Transaction>> recordSplitExpense({
    required int amountMinor,
    required String description,
    required DateTime date,
    String currency = 'DZD',
    String? categoryId,
    String? payee,
    String? note,
    required List<SplitItemInput> splits,
  }) async {
    if (splits.isEmpty) {
      return const Failure(ValidationFailure('At least one split allocation is required.'));
    }

    final validation = CurrencyConversionService.validateSplits(
      totalAmountMinor: amountMinor,
      baseCurrency: currency,
      splits: splits,
    );
    if (!validation.isValid) {
      return Failure(ValidationFailure(validation.errorMessage ?? 'Split allocations do not match total expense.'));
    }

    try {
      return await _db.transaction(() async {
        // Validate each source exists and has funds
        for (final split in splits) {
          final srcId = split.sourceId;
          if (srcId == null || srcId.isEmpty) {
            return const Failure(ValidationFailure('Each split must have a funding source selected.'));
          }
          final source = await (_db.select(_db.moneySources)..where((t) => t.id.equals(srcId))).getSingleOrNull();
          if (source == null) {
            return Failure(NotFoundFailure('Money source not found: $srcId'));
          }
          if (source.cachedBalanceMinor < split.amountMinor) {
            return Failure(InsufficientFundsFailure(
              available: source.cachedBalanceMinor,
              required_: split.amountMinor,
            ));
          }
        }

        final txnId = 'txn_${_uuid.v4().substring(0, 12)}';
        final primarySourceId = splits.first.sourceId!;

        await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
              id: txnId,
              type: 'expense',
              amountMinor: amountMinor,
              currency: Value(currency),
              sourceId: primarySourceId,
              categoryId: Value(categoryId),
              payee: Value(payee),
              description: Value(description),
              note: Value(note),
              date: date,
              status: const Value('completed'),
              referenceType: const Value('split'),
            ));

        // Deduct balances from respective sources and store splits
        for (final split in splits) {
          final sId = split.sourceId!;
          await _updateSourceBalance(sId, -split.amountMinor);

          final rate = CurrencyConversionService.getExchangeRate(split.currency, currency);
          final normalized = CurrencyConversionService.convert(
            amountMinor: split.amountMinor,
            fromCurrency: split.currency,
            toCurrency: currency,
          );

          await _db.into(_db.splitTransactions).insert(SplitTransactionsCompanion.insert(
                id: 'splt_${_uuid.v4().substring(0, 12)}',
                transactionId: txnId,
                categoryId: Value(split.categoryId ?? categoryId),
                sourceId: Value(sId),
                amountMinor: split.amountMinor,
                currency: Value(split.currency),
                exchangeRate: Value(rate),
                normalizedAmountMinor: Value(normalized),
                note: Value(split.note),
              ));
        }

        final txn = await (_db.select(_db.transactions)..where((t) => t.id.equals(txnId))).getSingle();
        return Success(txn);
      });
    } catch (e) {
      if (e is Result) return e as Result<Transaction>;
      return Failure(TransactionFailure("Failed to record split expense: ${e.toString()}"));
    }
  }

  // ─── Record Transfer ────────────────────────────────────────
  Future<Result<Transfer>> recordTransfer({
    required String fromSourceId,
    required String toSourceId,
    required int amountMinor,
    required DateTime date,
    String? currency,
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
        final toSource = await (_db.select(_db.moneySources)
              ..where((t) => t.id.equals(toSourceId)))
            .getSingle();

        if (fromSource.cachedBalanceMinor < amountMinor) {
          return Failure(InsufficientFundsFailure(
            available: fromSource.cachedBalanceMinor,
            required_: amountMinor,
          ));
        }

        final transferCurrency = currency ?? fromSource.currency;

        // Multi-currency calculation
        final convertedAmountMinor = CurrencyConversionService.convert(
          amountMinor: amountMinor,
          fromCurrency: transferCurrency,
          toCurrency: toSource.currency,
        );

        final transferId = 'trf_${_uuid.v4().substring(0, 12)}';

        await _db.into(_db.transfers).insert(TransfersCompanion.insert(
              id: transferId,
              fromSourceId: fromSourceId,
              toSourceId: toSourceId,
              amountMinor: amountMinor,
              currency: Value(transferCurrency),
              note: Value(note),
              date: date,
            ));

        // Deduct from source in its currency, add to destination in destination currency
        await _updateSourceBalance(fromSourceId, -amountMinor);
        await _updateSourceBalance(toSourceId, convertedAmountMinor);

        // Record in transactions so transfers appear in ledger and activity
        final txnId = 'txn_${_uuid.v4().substring(0, 12)}';
        await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
              id: txnId,
              type: 'transfer',
              amountMinor: amountMinor,
              currency: Value(transferCurrency),
              sourceId: fromSourceId,
              incomeOrigin: Value(fromSource.name),
              payee: Value(toSource.name),
              description: Value('Transfer: ${fromSource.name} -> ${toSource.name}'),
              note: Value(note),
              date: date,
              status: const Value('completed'),
              referenceId: Value(transferId),
              referenceType: const Value('transfer'),
            ));

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
          if (txn.type == 'transfer') {
            if (txn.referenceId != null) {
              final transfer = await (_db.select(_db.transfers)
                    ..where((t) => t.id.equals(txn.referenceId!)))
                  .getSingleOrNull();
              if (transfer != null) {
                final toSource = await (_db.select(_db.moneySources)
                      ..where((t) => t.id.equals(transfer.toSourceId)))
                    .getSingle();
                final convertedAdded = CurrencyConversionService.convert(
                  amountMinor: transfer.amountMinor,
                  fromCurrency: transfer.currency,
                  toCurrency: toSource.currency,
                );
                // Return amount to sender source, deduct from receiver source
                await _updateSourceBalance(transfer.fromSourceId, transfer.amountMinor);
                await _updateSourceBalance(transfer.toSourceId, -convertedAdded);
                await (_db.delete(_db.transfers)..where((t) => t.id.equals(transfer.id))).go();
              }
            }
          } else if (txn.referenceType == 'split') {
            // Reverse split allocations
            final splits = await (_db.select(_db.splitTransactions)
                  ..where((t) => t.transactionId.equals(transactionId)))
                .get();
            for (final split in splits) {
              if (split.sourceId != null) {
                await _updateSourceBalance(split.sourceId!, split.amountMinor);
              }
            }
            await (_db.delete(_db.splitTransactions)..where((t) => t.transactionId.equals(transactionId))).go();
          } else if (txn.type == 'income') {
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

  /// Paginated and filtered transaction query.
  Future<Result<PagedTransactionsResult>> getTransactionsPaged({
    DateTime? month,
    String? type,
    String? sourceId,
    String? categoryId,
    String? searchQuery,
    int page = 1,
    int pageSize = 15,
  }) async {
    try {
      final safePage = page < 1 ? 1 : page;
      final safePageSize = pageSize < 1 ? 15 : pageSize;
      final offset = (safePage - 1) * safePageSize;

      DateTime? startOfMonth;
      DateTime? endOfMonth;
      if (month != null) {
        startOfMonth = DateTime(month.year, month.month, 1);
        endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
      }

      final query = _db.select(_db.transactions)
        ..orderBy([(t) => OrderingTerm.desc(t.date)])
        ..limit(safePageSize, offset: offset);

      Expression<bool> whereClause = const Constant(true);

      if (startOfMonth != null && endOfMonth != null) {
        whereClause = whereClause &
            _db.transactions.date.isBiggerOrEqualValue(startOfMonth) &
            _db.transactions.date.isSmallerOrEqualValue(endOfMonth);
      }

      if (type != null && type.isNotEmpty && type != 'all') {
        whereClause = whereClause & _db.transactions.type.equals(type);
      }

      if (sourceId != null && sourceId.isNotEmpty) {
        whereClause = whereClause & _db.transactions.sourceId.equals(sourceId);
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        whereClause = whereClause & _db.transactions.categoryId.equals(categoryId);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim().toLowerCase()}%';
        whereClause = whereClause &
            (_db.transactions.description.lower().like(term) |
                _db.transactions.note.lower().like(term) |
                _db.transactions.payee.lower().like(term) |
                _db.transactions.incomeOrigin.lower().like(term));
      }

      query.where((_) => whereClause);
      final items = await query.get();

      // Total count query
      final countQuery = _db.selectOnly(_db.transactions)
        ..addColumns([_db.transactions.id.count()]);

      Expression<bool> countWhereClause = const Constant(true);
      if (startOfMonth != null && endOfMonth != null) {
        countWhereClause = countWhereClause &
            _db.transactions.date.isBiggerOrEqualValue(startOfMonth) &
            _db.transactions.date.isSmallerOrEqualValue(endOfMonth);
      }
      if (type != null && type.isNotEmpty && type != 'all') {
        countWhereClause = countWhereClause & _db.transactions.type.equals(type);
      }
      if (sourceId != null && sourceId.isNotEmpty) {
        countWhereClause = countWhereClause & _db.transactions.sourceId.equals(sourceId);
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        countWhereClause = countWhereClause & _db.transactions.categoryId.equals(categoryId);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim().toLowerCase()}%';
        countWhereClause = countWhereClause &
            (_db.transactions.description.lower().like(term) |
                _db.transactions.note.lower().like(term) |
                _db.transactions.payee.lower().like(term) |
                _db.transactions.incomeOrigin.lower().like(term));
      }
      countQuery.where(countWhereClause);
      final countRow = await countQuery.getSingle();
      final totalCount = countRow.read(_db.transactions.id.count()) ?? 0;

      final totalPages = (totalCount / safePageSize).ceil().clamp(1, 999999);

      return Success(PagedTransactionsResult(
        items: items,
        totalCount: totalCount,
        page: safePage,
        pageSize: safePageSize,
        totalPages: totalPages,
        hasNextPage: safePage < totalPages,
        hasPreviousPage: safePage > 1,
      ));
    } catch (e) {
      return Failure(DatabaseFailure('Failed to load transactions', e.toString()));
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

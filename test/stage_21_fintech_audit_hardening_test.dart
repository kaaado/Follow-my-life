import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_my_life/core/constants/app_constants.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/storage/backup_service.dart';
import 'package:follow_my_life/core/utils/currency_conversion_service.dart';
import 'package:follow_my_life/features/finance/data/repositories/recurring_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/split_transaction_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/budget_repository.dart';
import 'package:follow_my_life/features/finance/data/repositories/transaction_repository.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:crypto/crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 21 FinTech Audit Hardening Tests', () {
    late AppDatabase db;
    late BackupService backupService;
    late RecurringRepository recurringRepo;
    late BudgetRepository budgetRepo;
    late TransactionRepository txnRepo;

    setUpAll(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      backupService = BackupService(db);
      recurringRepo = RecurringRepository(db);
      budgetRepo = BudgetRepository(db);
      txnRepo = TransactionRepository(db);
    });

    tearDownAll(() async {
      await db.close();
    });

    // ─── 1. Recurring Date Engine Advancement & Day Clamping ───
    test('Recurring Date Engine advances 15th of each month correctly', () {
      final sep15 = DateTime(2026, 9, 15);
      final oct15 = RecurringRepository.calculateNextOccurrence(sep15, 'monthly');
      expect(oct15, DateTime(2026, 10, 15));

      final nov15 = RecurringRepository.calculateNextOccurrence(oct15, 'monthly');
      expect(nov15, DateTime(2026, 11, 15));

      final dec15 = RecurringRepository.calculateNextOccurrence(nov15, 'monthly');
      expect(dec15, DateTime(2026, 12, 15));

      final jan15 = RecurringRepository.calculateNextOccurrence(dec15, 'monthly');
      expect(jan15, DateTime(2027, 1, 15));
    });

    test('Recurring Date Engine correctly clamps end-of-month dates (e.g., Jan 31 -> Feb 28)', () {
      final jan31 = DateTime(2026, 1, 31);
      final febEnd = RecurringRepository.calculateNextOccurrence(jan31, 'monthly');
      // 2026 is non-leap year -> Feb 28
      expect(febEnd, DateTime(2026, 2, 28));

      final marEnd = RecurringRepository.calculateNextOccurrence(febEnd, 'monthly');
      expect(marEnd.month, 3);
    });

    test('Recurring Date Engine advances weekly and daily frequencies', () {
      final base = DateTime(2026, 9, 15);
      final nextDaily = RecurringRepository.calculateNextOccurrence(base, 'daily');
      expect(nextDaily, DateTime(2026, 9, 16));

      final nextWeekly = RecurringRepository.calculateNextOccurrence(base, 'weekly');
      expect(nextWeekly, DateTime(2026, 9, 22));

      final nextYearly = RecurringRepository.calculateNextOccurrence(base, 'yearly');
      expect(nextYearly, DateTime(2027, 9, 15));
    });

    // ─── 2. Currency Conversion & Scaled Arithmetic ──────────
    test('CurrencyConversionService uses integer scaled arithmetic avoiding floating drift', () {
      // 100 EUR = 14,500 DZD (at 145.0 rate)
      final dzdMinor = CurrencyConversionService.convert(
        amountMinor: 10000, // 100.00 EUR
        fromCurrency: 'EUR',
        toCurrency: 'DZD',
      );
      expect(dzdMinor, 1450000); // 14,500.00 DZD

      // 135 DZD to USD (at 135.0 rate)
      final usdMinor = CurrencyConversionService.convert(
        amountMinor: 13500, // 135.00 DZD
        fromCurrency: 'DZD',
        toCurrency: 'USD',
      );
      expect(usdMinor, 100); // 1.00 USD
    });

    test('CurrencyConversionService validates multi-source split transactions accurately', () {
      final validSplits = [
        const SplitItemInput(
          sourceId: 'src-cash',
          amountMinor: 1000000,
          currency: 'DZD',
        ),
        const SplitItemInput(
          sourceId: 'src-bank',
          amountMinor: 1000000,
          currency: 'DZD',
        ),
      ];

      final validRes = CurrencyConversionService.validateSplits(
        totalAmountMinor: 2000000,
        baseCurrency: 'DZD',
        splits: validSplits,
      );
      expect(validRes.isValid, isTrue);
      expect(validRes.remainingNormalizedMinor, 0);

      final invalidSplits = [
        const SplitItemInput(
          sourceId: 'src-cash',
          amountMinor: 1000000,
          currency: 'DZD',
        ),
        const SplitItemInput(
          sourceId: 'src-bank',
          amountMinor: 500000,
          currency: 'DZD',
        ),
      ];

      final invalidRes = CurrencyConversionService.validateSplits(
        totalAmountMinor: 2000000,
        baseCurrency: 'DZD',
        splits: invalidSplits,
      );
      expect(invalidRes.isValid, isFalse);
      expect(invalidRes.remainingNormalizedMinor, 500000);
      expect(invalidRes.errorMessage, isNotNull);
    });

    test('CurrencyConversionService validates multi-currency splits with exchange rates', () {
      final multiCurrencySplits = [
        const SplitItemInput(
          sourceId: 'src-dzd',
          amountMinor: 1000000,
          currency: 'DZD',
        ),
        const SplitItemInput(
          sourceId: 'src-eur',
          amountMinor: 10000,
          currency: 'EUR',
        ),
      ];

      final res = CurrencyConversionService.validateSplits(
        totalAmountMinor: 2450000,
        baseCurrency: 'DZD',
        splits: multiCurrencySplits,
      );
      expect(res.isValid, isTrue);
      expect(res.totalAllocatedNormalizedMinor, 2450000);
      expect(res.remainingNormalizedMinor, 0);
    });

    // ─── 3. 12-Point Backup & Restore Validation Pipeline ─────
    test('BackupService rejects corrupted JSON string', () {
      final res = backupService.validateBackupPayload('{invalid_json');
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('valid JSON'));
    });

    test('BackupService rejects payloads with wrong app signature', () {
      final payload = jsonEncode({
        'metadata': {
          'app': 'SomeOtherApp',
          'schema_version': 5,
        },
        'checksum': '0' * 64,
        'data': {},
      });

      final res = backupService.validateBackupPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Incompatible app backup signature'));
    });

    test('BackupService rejects unsupported future schema versions', () {
      final payload = jsonEncode({
        'metadata': {
          'app': 'Follow My Life',
          'schema_version': AppConstants.databaseVersion + 99,
        },
        'checksum': '0' * 64,
        'data': {},
      });

      final res = backupService.validateBackupPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Unsupported schema version'));
    });

    test('BackupService detects cryptographic checksum mismatch', () {
      final data = {'money_sources': []};
      final fakeChecksum = 'a' * 64;

      final payload = jsonEncode({
        'metadata': {
          'app': 'Follow My Life',
          'schema_version': AppConstants.databaseVersion,
        },
        'checksum': fakeChecksum,
        'data': data,
      });

      final res = backupService.validateBackupPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('checksum mismatch'));
    });

    test('BackupService detects foreign key inconsistencies in backup data', () {
      final data = {
        'money_sources': [
          {'id': 'src-1', 'currency': 'DZD'}
        ],
        'transactions': [
          {'id': 'txn-1', 'sourceId': 'non_existent_source'}
        ],
      };
      final dataJson = jsonEncode(data);
      final checksum = sha256.convert(utf8.encode(dataJson)).toString();

      final payload = jsonEncode({
        'metadata': {
          'app': 'Follow My Life',
          'schema_version': AppConstants.databaseVersion,
        },
        'checksum': checksum,
        'data': data,
      });

      final res = backupService.validateBackupPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Foreign key error'));
    });

    test('BackupService validates canonical valid backup successfully', () {
      final data = {
        'money_sources': [
          {'id': 'src-1', 'currency': 'DZD'}
        ],
        'transactions': [
          {'id': 'txn-1', 'sourceId': 'src-1', 'currency': 'DZD'}
        ],
        'transfers': [],
      };
      final dataJson = jsonEncode(data);
      final checksum = sha256.convert(utf8.encode(dataJson)).toString();

      final payload = jsonEncode({
        'metadata': {
          'app': 'Follow My Life',
          'schema_version': AppConstants.databaseVersion,
        },
        'checksum': checksum,
        'data': data,
      });

      final res = backupService.validateBackupPayload(payload);
      expect(res.isValid, isTrue);
      expect(res.schemaVersion, AppConstants.databaseVersion);
      expect(res.totalRecords, 2);
    });

    // ─── 4. Database Operations: Budget Soft-Delete, Attention, Pagination ─
    test('BudgetRepository soft-deletes budget without affecting transactions', () async {
      // Create a budget
      final createRes = await budgetRepo.createBudget(
        categoryId: 'cat_food',
        amountMinor: 2500000,
        year: 2026,
        month: 9,
        currency: 'DZD',
      );
      expect(createRes.isSuccess, isTrue);
      final budget = createRes.value;

      // Delete budget
      final deleteRes = await budgetRepo.deleteBudget(budget.id);
      expect(deleteRes.isSuccess, isTrue);

      // Verify active budgets no longer contains it
      final activeBudgets = await (db.select(db.budgets)..where((t) => t.isActive.equals(true))).get();
      expect(activeBudgets.any((b) => b.id == budget.id), isFalse);
    });

    test('RecurringRepository detects items requiring attention when source is missing', () async {
      // Insert recurring with non-existent source
      await db.into(db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
            id: 'rec_orphan',
            type: 'income',
            amountMinor: 10000000,
            description: 'Salary Orphan',
            frequency: const Value('monthly'),
            nextOccurrence: DateTime(2026, 9, 15),
            isActive: const Value(true),
            sourceId: 'non_existent_source_id',
          ));

      final attentionItems = await recurringRepo.getItemsRequiringAttention();
      expect(attentionItems.any((r) => r.id == 'rec_orphan'), isTrue);
    });

    test('TransactionRepository getTransactionsPaged limits by month and page size', () async {
      // Create source
      await db.into(db.moneySources).insert(
            MoneySourcesCompanion.insert(
              id: 'src_test_paged',
              name: 'Test Source',
              type: SourceType.cash,
              cachedBalanceMinor: const Value(5000000),
            ),
            mode: InsertMode.insertOrReplace,
          );

      // Record 3 September transactions and 1 October transaction
      final sepDate = DateTime(2026, 9, 10);
      final octDate = DateTime(2026, 10, 5);

      await txnRepo.recordIncome(
        amountMinor: 100000,
        sourceId: 'src_test_paged',
        description: 'Sep 1',
        date: sepDate,
      );
      await txnRepo.recordIncome(
        amountMinor: 200000,
        sourceId: 'src_test_paged',
        description: 'Sep 2',
        date: sepDate,
      );
      await txnRepo.recordIncome(
        amountMinor: 300000,
        sourceId: 'src_test_paged',
        description: 'Sep 3',
        date: sepDate,
      );
      await txnRepo.recordIncome(
        amountMinor: 400000,
        sourceId: 'src_test_paged',
        description: 'Oct 1',
        date: octDate,
      );

      // Query September page 1 with pageSize 2
      final sepPagedRes = await txnRepo.getTransactionsPaged(
        month: DateTime(2026, 9, 1),
        page: 1,
        pageSize: 2,
      );
      expect(sepPagedRes.isSuccess, isTrue);
      final paged = sepPagedRes.value;
      expect(paged.items.length, 2);
      expect(paged.totalCount, 3);
      expect(paged.totalPages, 2);
      expect(paged.hasNextPage, isTrue);
      expect(paged.hasPreviousPage, isFalse);

      // Query September page 2
      final sepPage2 = await txnRepo.getTransactionsPaged(
        month: DateTime(2026, 9, 1),
        page: 2,
        pageSize: 2,
      );
      expect(sepPage2.value.items.length, 1);
      expect(sepPage2.value.hasNextPage, isFalse);
      expect(sepPage2.value.hasPreviousPage, isTrue);
    });
  });
}

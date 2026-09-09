/// Drift database definition for Follow My Life.
/// All financial operations use atomic transactions.
/// Monetary amounts stored as integer minor units (centimes).
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:follow_my_life/core/constants/app_constants.dart';

part 'app_database.g.dart';

// ─── Enums ────────────────────────────────────────────────────────
class SourceTypeConverter extends TypeConverter<SourceType, String> {
  const SourceTypeConverter();

  @override
  SourceType fromSql(String fromDb) => SourceType.values.firstWhere(
        (e) => e.name == fromDb,
        orElse: () => SourceType.other,
      );

  @override
  String toSql(SourceType value) => value.name;
}

enum SourceType { cash, bankAccount, eWallet, incomeSource, other }

enum TransactionType { income, expense, transfer, adjustment }

enum TransactionStatus { pending, completed, cancelled, reversed }

enum IncomeStatus { expected, received, cancelled }

enum PurchasePriority { high, medium, low }

enum PurchaseStatus { planned, purchased, cancelled }

enum RecurrenceFrequency { daily, weekly, monthly, yearly, custom }

// ─── Tables ───────────────────────────────────────────────────────

/// User profile — single row table.
class UserProfiles extends Table {
  TextColumn get id => text().withDefault(const Constant('default'))();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get locale => text().withDefault(const Constant('en'))();
  TextColumn get themeMode =>
      text().withDefault(const Constant('system'))(); // light, dark, system
  IntColumn get firstDayOfWeek => integer().withDefault(const Constant(1))();
  TextColumn get profilePhotoPath => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Money sources (wallets, bank accounts, etc.)
class MoneySources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text().map(const SourceTypeConverter())();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get initialBalanceMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get cachedBalanceMinor =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Spending/income categories.
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get icon => text().withDefault(const Constant('tag'))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// The core financial ledger. Every money movement is a transaction.
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // income, expense, transfer, adjustment
  IntColumn get amountMinor => integer()(); // always positive
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get sourceId => text().references(MoneySources, #id)();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get incomeOrigin => text().nullable()(); // Income source/reason (e.g. Salary, Freelance, Gift)
  TextColumn get payee => text().nullable()(); // Expense destination/vendor (e.g. Restaurant, Supermarket)
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('completed'))();
  TextColumn get referenceId =>
      text().nullable()(); // links to transfer, purchase, etc.
  TextColumn get referenceType =>
      text().nullable()(); // 'transfer', 'purchase', 'recurring'
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_txn_date', 'CREATE INDEX idx_txn_date ON transactions (date)'),
        Index('idx_txn_source', 'CREATE INDEX idx_txn_source ON transactions (source_id)'),
        Index('idx_txn_category', 'CREATE INDEX idx_txn_category ON transactions (category_id)'),
      ];
}

/// Money transfers between sources.
class Transfers extends Table {
  TextColumn get id => text()();
  TextColumn get fromSourceId => text().references(MoneySources, #id)();
  TextColumn get toSourceId => text().references(MoneySources, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('completed'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Planned purchases.
class PlannedPurchases extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get estimatedAmountMinor => integer()();
  IntColumn get actualAmountMinor => integer().nullable()();
  IntColumn get reservedAmountMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get priority =>
      text().withDefault(const Constant('medium'))(); // essential, important, optional, high, medium, low
  TextColumn get status =>
      text().withDefault(const Constant('planned'))(); // planned, saving, ready, purchased, completed, cancelled
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Monthly/category budgets.
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_budget_cat_year_month', 'CREATE INDEX idx_budget_cat_year_month ON budgets (category_id, year, month)'),
      ];
}

/// Recurring transaction templates.
class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // income, expense
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get sourceId => text().references(MoneySources, #id)();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get description => text()();
  TextColumn get frequency =>
      text().withDefault(const Constant('monthly'))();
  DateTimeColumn get nextOccurrence => dateTime()();
  DateTimeColumn get lastProcessed => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get autoExecute => boolean().withDefault(const Constant(true))();
  TextColumn get payee => text().nullable()();
  TextColumn get incomeOrigin => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_rec_next', 'CREATE INDEX idx_rec_next ON recurring_transactions (next_occurrence)'),
        Index('idx_rec_source', 'CREATE INDEX idx_rec_source ON recurring_transactions (source_id)'),
      ];
}

/// Idempotent occurrence tracking for recurring events.
class RecurringOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get recurringId => text().references(RecurringTransactions, #id)();
  DateTimeColumn get scheduledDate => dateTime()();
  DateTimeColumn get processedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  TextColumn get status =>
      text().withDefault(const Constant('processed'))(); // processed, skipped, failed

  @override
  Set<Column> get primaryKey => {id};
}

/// Financial allocations (money reserved for a purpose).
class FinancialAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get sourceId =>
      text().nullable().references(MoneySources, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get note => text().nullable()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Expected/upcoming income entries.
class ExpectedIncomes extends Table {
  TextColumn get id => text()();
  TextColumn get description => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get sourceId => text().references(MoneySources, #id)();
  DateTimeColumn get expectedDate => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('expected'))();
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  TextColumn get recurringId =>
      text().nullable().references(RecurringTransactions, #id)();
  DateTimeColumn get receivedDate => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Debts and Loans tracking ("I Owe" vs "Owed to Me").
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get personName => text()();
  TextColumn get type => text()(); // 'i_owe', 'owed_to_me'
  IntColumn get amountMinor => integer()();
  IntColumn get paidAmountMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, partially_paid, paid, overdue, cancelled
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Split transaction items breakdown.
class SplitTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pre-spending virtual splits (planning & fund allocation layer).
class VirtualSplits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get sourceId => text().references(MoneySources, #id)();
  IntColumn get totalAmountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // draft, active, applying, applied, cancelled, failed
  DateTimeColumn get appliedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class VirtualSplitItems extends Table {
  TextColumn get id => text()();
  TextColumn get splitId => text().references(VirtualSplits, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database Definition ──────────────────────────────────────────
@DriftDatabase(tables: [
  UserProfiles,
  MoneySources,
  Categories,
  Transactions,
  Transfers,
  PlannedPurchases,
  Budgets,
  RecurringTransactions,
  RecurringOccurrences,
  FinancialAllocations,
  ExpectedIncomes,
  Debts,
  SplitTransactions,
  VirtualSplits,
  VirtualSplitItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // For testing
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => AppConstants.databaseVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Seed default categories
          await _seedDefaultCategories();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.incomeOrigin);
            await m.addColumn(transactions, transactions.payee);
            await m.addColumn(plannedPurchases, plannedPurchases.reservedAmountMinor);
            await m.addColumn(recurringTransactions, recurringTransactions.autoExecute);
            await m.addColumn(recurringTransactions, recurringTransactions.payee);
            await m.addColumn(recurringTransactions, recurringTransactions.incomeOrigin);
            await m.createTable(recurringOccurrences);
          }
          if (from < 3) {
            await m.createTable(debts);
            await m.createTable(splitTransactions);
          }
          if (from < 4) {
            await m.createTable(virtualSplits);
            await m.createTable(virtualSplitItems);
          }
        },
        beforeOpen: (details) async {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS debts (
              id TEXT NOT NULL PRIMARY KEY,
              person_name TEXT NOT NULL,
              type TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              paid_amount_minor INTEGER NOT NULL DEFAULT 0,
              currency TEXT NOT NULL DEFAULT 'DZD',
              due_date INTEGER,
              status TEXT NOT NULL DEFAULT 'active',
              notes TEXT,
              created_at INTEGER NOT NULL DEFAULT (UNIXEPOCH()),
              updated_at INTEGER NOT NULL DEFAULT (UNIXEPOCH())
            );
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS split_transactions (
              id TEXT NOT NULL PRIMARY KEY,
              transaction_id TEXT NOT NULL REFERENCES transactions(id),
              category_id TEXT NOT NULL REFERENCES categories(id),
              amount_minor INTEGER NOT NULL,
              note TEXT
            );
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS virtual_splits (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              source_id TEXT NOT NULL REFERENCES money_sources(id),
              total_amount_minor INTEGER NOT NULL,
              currency TEXT NOT NULL DEFAULT 'DZD',
              status TEXT NOT NULL DEFAULT 'active',
              applied_at INTEGER,
              created_at INTEGER NOT NULL DEFAULT (UNIXEPOCH()),
              updated_at INTEGER NOT NULL DEFAULT (UNIXEPOCH())
            );
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS virtual_split_items (
              id TEXT NOT NULL PRIMARY KEY,
              split_id TEXT NOT NULL REFERENCES virtual_splits(id) ON DELETE CASCADE,
              category_id TEXT NOT NULL REFERENCES categories(id),
              amount_minor INTEGER NOT NULL,
              note TEXT,
              created_at INTEGER NOT NULL DEFAULT (UNIXEPOCH())
            );
          ''');
        },
      );

  Future<void> _seedDefaultCategories() async {
    final defaults = [
      ('food', 'cat_food', 'utensils', 0),
      ('transport', 'cat_transport', 'car', 1),
      ('housing', 'cat_housing', 'home', 2),
      ('bills', 'cat_bills', 'receipt', 3),
      ('shopping', 'cat_shopping', 'shopping-bag', 4),
      ('health', 'cat_health', 'heart-pulse', 5),
      ('education', 'cat_education', 'graduation-cap', 6),
      ('entertainment', 'cat_entertainment', 'gamepad-2', 7),
      ('family', 'cat_family', 'users', 8),
      ('savings', 'cat_savings', 'piggy-bank', 9),
      ('emergency', 'cat_emergency', 'shield-alert', 10),
      ('other', 'cat_other', 'tag', 11),
    ];

    for (final (id, name, icon, colorIdx) in defaults) {
      await into(categories).insert(CategoriesCompanion.insert(
        id: 'cat_$id',
        name: name,
        icon: Value(icon),
        colorIndex: Value(colorIdx),
        isDefault: const Value(true),
        sortOrder: Value(colorIdx),
      ));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, AppConstants.databaseName));
    return NativeDatabase(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
      },
    );
  });
}

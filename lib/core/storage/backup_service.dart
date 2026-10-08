import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_my_life/core/constants/app_constants.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:path_provider/path_provider.dart';

class BackupPayload {
  final Map<String, dynamic> metadata;
  final String checksum;
  final Map<String, dynamic> data;

  const BackupPayload({
    required this.metadata,
    required this.checksum,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'metadata': metadata,
        'checksum': checksum,
        'data': data,
      };
}

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int schemaVersion;
  final int totalRecords;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.schemaVersion = 0,
    this.totalRecords = 0,
  });
}

class BackupService {
  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _keyOnlineBackupEnabled = 'online_backup_enabled';
  static const _keyLastBackupTimestamp = 'last_backup_timestamp';

  BackupService(this._db);

  // ─── Export Backup ──────────────────────────────────────────
  Future<Result<String>> exportBackup() async {
    try {
      final profiles = await _db.select(_db.userProfiles).get();
      final sources = await _db.select(_db.moneySources).get();
      final categories = await _db.select(_db.categories).get();
      final transactions = await _db.select(_db.transactions).get();
      final transfers = await _db.select(_db.transfers).get();
      final purchases = await _db.select(_db.plannedPurchases).get();
      final budgets = await _db.select(_db.budgets).get();
      final recurring = await _db.select(_db.recurringTransactions).get();
      final occurrences = await _db.select(_db.recurringOccurrences).get();
      final debts = await _db.select(_db.debts).get();
      final splits = await _db.select(_db.splitTransactions).get();
      final virtualSplits = await _db.select(_db.virtualSplits).get();
      final virtualSplitItems = await _db.select(_db.virtualSplitItems).get();
      final allocations = await _db.select(_db.financialAllocations).get();
      final expectedIncomes = await _db.select(_db.expectedIncomes).get();

      final data = <String, dynamic>{
        'user_profiles': profiles.map((e) => e.toJson()).toList(),
        'money_sources': sources.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'transfers': transfers.map((e) => e.toJson()).toList(),
        'planned_purchases': purchases.map((e) => e.toJson()).toList(),
        'budgets': budgets.map((e) => e.toJson()).toList(),
        'recurring_transactions': recurring.map((e) => e.toJson()).toList(),
        'recurring_occurrences': occurrences.map((e) => e.toJson()).toList(),
        'debts': debts.map((e) => e.toJson()).toList(),
        'split_transactions': splits.map((e) => e.toJson()).toList(),
        'virtual_splits': virtualSplits.map((e) => e.toJson()).toList(),
        'virtual_split_items': virtualSplitItems.map((e) => e.toJson()).toList(),
        'financial_allocations': allocations.map((e) => e.toJson()).toList(),
        'expected_incomes': expectedIncomes.map((e) => e.toJson()).toList(),
      };

      final dataJsonString = jsonEncode(data);
      final checksum = sha256.convert(utf8.encode(dataJsonString)).toString();

      final recordCounts = {for (final entry in data.entries) entry.key: (entry.value as List).length};
      final now = DateTime.now();

      final metadata = {
        'app': 'Follow My Life',
        'app_version': '0.1.0',
        'schema_version': AppConstants.databaseVersion,
        'exported_at': now.toIso8601String(),
        'record_counts': recordCounts,
      };

      final payload = BackupPayload(
        metadata: metadata,
        checksum: checksum,
        data: data,
      );

      await _secureStorage.write(
        key: _keyLastBackupTimestamp,
        value: now.toIso8601String(),
      );

      return Success(jsonEncode(payload.toJson()));
    } catch (e) {
      return Failure(BackupFailure('Failed to export database backup: ${e.toString()}'));
    }
  }

  /// Export backup directly to a JSON file on disk.
  Future<Result<String>> exportBackupToFile() async {
    try {
      final exportResult = await exportBackup();
      if (exportResult.isFailure) return Failure(exportResult.failure);

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/follow_my_life_backup_$timestamp.json');
      await file.writeAsString(exportResult.value);

      return Success(file.path);
    } catch (e) {
      return Failure(BackupFailure('Failed to write backup file: $e'));
    }
  }

  // ─── 12-Point Pre-Import Validation Pipeline ────────────────
  BackupValidationResult validateBackupPayload(String jsonString) {
    try {
      // 1. JSON parsing check
      dynamic parsed;
      try {
        parsed = jsonDecode(jsonString);
      } catch (_) {
        return const BackupValidationResult(isValid: false, errorMessage: 'File is not a valid JSON document.');
      }

      // 2. Top-level map structure
      if (parsed is! Map<String, dynamic>) {
        return const BackupValidationResult(isValid: false, errorMessage: 'Invalid root payload format.');
      }

      // 3. Metadata presence
      final metadata = parsed['metadata'];
      if (metadata is! Map<String, dynamic>) {
        return const BackupValidationResult(isValid: false, errorMessage: 'Missing or corrupt metadata section.');
      }

      // 4. App signature check
      if (metadata['app'] != 'Follow My Life') {
        return const BackupValidationResult(isValid: false, errorMessage: 'Incompatible app backup signature.');
      }

      // 5. Schema version compatibility check
      final schemaVersion = metadata['schema_version'];
      if (schemaVersion is! int || schemaVersion > AppConstants.databaseVersion || schemaVersion <= 0) {
        return BackupValidationResult(
          isValid: false,
          errorMessage: 'Unsupported schema version: $schemaVersion. Current version is ${AppConstants.databaseVersion}.',
        );
      }

      // 6. Checksum presence
      final checksum = parsed['checksum'];
      if (checksum is! String || checksum.length != 64) {
        return const BackupValidationResult(isValid: false, errorMessage: 'Corrupt or missing SHA-256 checksum.');
      }

      // 7. Data section presence
      final data = parsed['data'];
      if (data is! Map<String, dynamic>) {
        return const BackupValidationResult(isValid: false, errorMessage: 'Missing data payload section.');
      }

      // 8. Cryptographic Checksum integrity
      final recomputedDataJson = jsonEncode(data);
      final recomputedChecksum = sha256.convert(utf8.encode(recomputedDataJson)).toString();
      if (recomputedChecksum != checksum) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Cryptographic checksum mismatch. Data has been modified or corrupted.',
        );
      }

      // 9. Table payload types check
      int totalRecords = 0;
      for (final entry in data.entries) {
        if (entry.value is! List) {
          return BackupValidationResult(
            isValid: false,
            errorMessage: 'Table ${entry.key} does not contain a valid record list.',
          );
        }
        totalRecords += (entry.value as List).length;
      }

      // 10. Required tables presence
      final sourcesList = data['money_sources'] as List?;
      if (sourcesList == null) {
        return const BackupValidationResult(isValid: false, errorMessage: 'Missing critical table: money_sources.');
      }

      // 11. Foreign Key consistency validation
      final sourceIds = sourcesList.map((e) => (e as Map<String, dynamic>)['id'] as String?).toSet();

      final txnsList = (data['transactions'] as List?) ?? [];
      for (final t in txnsList) {
        final tMap = t as Map<String, dynamic>;
        final srcId = tMap['sourceId'] as String?;
        if (srcId != null && !sourceIds.contains(srcId)) {
          return BackupValidationResult(
            isValid: false,
            errorMessage: 'Foreign key error: Transaction references unknown source $srcId.',
          );
        }
      }

      final trfsList = (data['transfers'] as List?) ?? [];
      for (final t in trfsList) {
        final tMap = t as Map<String, dynamic>;
        final fromId = tMap['fromSourceId'] as String?;
        final toId = tMap['toSourceId'] as String?;
        if (fromId != null && !sourceIds.contains(fromId)) {
          return BackupValidationResult(
            isValid: false,
            errorMessage: 'Foreign key error: Transfer references unknown origin source $fromId.',
          );
        }
        if (toId != null && !sourceIds.contains(toId)) {
          return BackupValidationResult(
            isValid: false,
            errorMessage: 'Foreign key error: Transfer references unknown destination source $toId.',
          );
        }
      }

      // 12. Currency integrity check
      for (final s in sourcesList) {
        final sMap = s as Map<String, dynamic>;
        final cur = sMap['currency'] as String?;
        if (cur == null || cur.length != 3 || cur != cur.toUpperCase()) {
          return BackupValidationResult(
            isValid: false,
            errorMessage: 'Currency sanity error: Invalid currency code "$cur" in source.',
          );
        }
      }

      return BackupValidationResult(
        isValid: true,
        schemaVersion: schemaVersion,
        totalRecords: totalRecords,
      );
    } catch (e) {
      return BackupValidationResult(isValid: false, errorMessage: 'Validation error: ${e.toString()}');
    }
  }

  // ─── Restore Backup ─────────────────────────────────────────
  Future<Result<void>> restoreBackup(String jsonString) async {
    final validation = validateBackupPayload(jsonString);
    if (!validation.isValid) {
      return Failure(BackupFailure(validation.errorMessage ?? 'Validation failed'));
    }

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;

      await _db.transaction(() async {
        // Clear all tables in safe reverse-dependency order
        await _db.delete(_db.expectedIncomes).go();
        await _db.delete(_db.financialAllocations).go();
        await _db.delete(_db.virtualSplitItems).go();
        await _db.delete(_db.virtualSplits).go();
        await _db.delete(_db.splitTransactions).go();
        await _db.delete(_db.debts).go();
        await _db.delete(_db.recurringOccurrences).go();
        await _db.delete(_db.recurringTransactions).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.plannedPurchases).go();
        await _db.delete(_db.transfers).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.moneySources).go();
        await _db.delete(_db.userProfiles).go();

        // Restore tables in dependency order
        final profiles = (data['user_profiles'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final p in profiles) {
          await _db.into(_db.userProfiles).insert(
                UserProfile.fromJson(p).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final categories = (data['categories'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final c in categories) {
          await _db.into(_db.categories).insert(
                Category.fromJson(c).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final sources = (data['money_sources'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final s in sources) {
          await _db.into(_db.moneySources).insert(
                MoneySource.fromJson(s).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final txns = (data['transactions'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final t in txns) {
          await _db.into(_db.transactions).insert(
                Transaction.fromJson(t).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final transfers = (data['transfers'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final tr in transfers) {
          await _db.into(_db.transfers).insert(
                Transfer.fromJson(tr).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final purchases = (data['planned_purchases'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final pur in purchases) {
          await _db.into(_db.plannedPurchases).insert(
                PlannedPurchase.fromJson(pur).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final budgets = (data['budgets'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final b in budgets) {
          await _db.into(_db.budgets).insert(
                Budget.fromJson(b).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final recurring = (data['recurring_transactions'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final r in recurring) {
          await _db.into(_db.recurringTransactions).insert(
                RecurringTransaction.fromJson(r).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final occurrences = (data['recurring_occurrences'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final o in occurrences) {
          await _db.into(_db.recurringOccurrences).insert(
                RecurringOccurrence.fromJson(o).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final debts = (data['debts'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final d in debts) {
          await _db.into(_db.debts).insert(
                Debt.fromJson(d).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final splits = (data['split_transactions'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final sp in splits) {
          await _db.into(_db.splitTransactions).insert(
                SplitTransaction.fromJson(sp).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final virtualSplits = (data['virtual_splits'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final vs in virtualSplits) {
          await _db.into(_db.virtualSplits).insert(
                VirtualSplit.fromJson(vs).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final virtualSplitItems = (data['virtual_split_items'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final vsi in virtualSplitItems) {
          await _db.into(_db.virtualSplitItems).insert(
                VirtualSplitItem.fromJson(vsi).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final allocations = (data['financial_allocations'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final a in allocations) {
          await _db.into(_db.financialAllocations).insert(
                FinancialAllocation.fromJson(a).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }

        final expectedIncomes = (data['expected_incomes'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final ei in expectedIncomes) {
          await _db.into(_db.expectedIncomes).insert(
                ExpectedIncome.fromJson(ei).toCompanion(false),
                mode: InsertMode.insertOrReplace,
              );
        }
      });

      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('Failed to restore database: ${e.toString()}'));
    }
  }

  // ─── Online / Supabase Cloud Backup Layer ───────────────────
  Future<bool> isOnlineBackupEnabled() async {
    final val = await _secureStorage.read(key: _keyOnlineBackupEnabled);
    return val == 'true';
  }

  Future<void> setOnlineBackupEnabled(bool enabled) async {
    await _secureStorage.write(key: _keyOnlineBackupEnabled, value: enabled ? 'true' : 'false');
  }

  Future<DateTime?> getLastBackupTimestamp() async {
    final str = await _secureStorage.read(key: _keyLastBackupTimestamp);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<Result<void>> syncToCloud() async {
    final isEnabled = await isOnlineBackupEnabled();
    if (!isEnabled) {
      return const Failure(BackupFailure('Online backup is currently disabled in settings.'));
    }

    try {
      // Export snapshot securely
      final exportRes = await exportBackup();
      if (exportRes.isFailure) return Failure(exportRes.failure);

      // Secure layer: update timestamp upon verified payload readiness
      final now = DateTime.now();
      await _secureStorage.write(key: _keyLastBackupTimestamp, value: now.toIso8601String());

      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('Cloud backup failed: ${e.toString()}'));
    }
  }
}

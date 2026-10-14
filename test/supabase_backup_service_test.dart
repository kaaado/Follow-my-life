import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_my_life/core/constants/app_constants.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/storage/app_value_serializer.dart';
import 'package:follow_my_life/core/storage/backup_service.dart';
import 'package:follow_my_life/core/storage/supabase_backup_service.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({required String key, iOptions, aOptions, eOptions, sOptions, mOptions, lOptions, webOptions, wOptions}) async => _data[key];

  @override
  Future<void> write({required String key, required String? value, iOptions, aOptions, eOptions, sOptions, mOptions, lOptions, webOptions, wOptions}) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, iOptions, aOptions, eOptions, sOptions, mOptions, lOptions, webOptions, wOptions}) async => _data.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Supabase Backup & Cloud Recovery Unit Tests', () {
    late AppDatabase db;
    late FakeSecureStorage fakeStorage;
    late BackupService backupService;
    late SupabaseBackupService supabaseService;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      fakeStorage = FakeSecureStorage();
      backupService = BackupService(db, secureStorage: fakeStorage);
      supabaseService = SupabaseBackupService(backupService, storage: fakeStorage);
    });

    tearDown(() async {
      await db.close();
    });

    test('SupabaseBackupService exposes configured constants and connection parameters', () {
      expect(SupabaseBackupService.defaultProjectRef, 'yyjhsexdlqpdbojpfngh');
      expect(SupabaseBackupService.defaultSupabaseUrl, 'https://yyjhsexdlqpdbojpfngh.supabase.co');
      expect(SupabaseBackupService.directHost, 'db.yyjhsexdlqpdbojpfngh.supabase.co');
      expect(SupabaseBackupService.directPort, 5432);
      expect(SupabaseBackupService.directUser, 'postgres');
      expect(SupabaseBackupService.directDatabase, 'postgres');
    });

    test('Phone identifier can be saved, retrieved and updated securely', () async {
      expect(await supabaseService.getCurrentIdentifier(), isNull);

      await supabaseService.setPhoneIdentifier('+213555123456');
      final savedId = await supabaseService.getCurrentIdentifier();
      expect(savedId, '+213555123456');

      await supabaseService.signOut();
      expect(await supabaseService.getCurrentIdentifier(), isNull);
    });

    test('Custom Supabase credentials can be saved in secure storage', () async {
      await supabaseService.saveCredentials(
        anonKey: 'test_anon_key_12345',
        url: 'https://test-project.supabase.co',
      );

      expect(await fakeStorage.read(key: 'supabase_anon_key'), 'test_anon_key_12345');
      expect(await fakeStorage.read(key: 'supabase_custom_url'), 'https://test-project.supabase.co');
    });

    test('CloudBackupSummary parses correctly from JSON map', () {
      final json = {
        'id': 'backup-uuid-1',
        'identifier': '+213555123456',
        'phone': '+213555123456',
        'email': 'user@example.com',
        'checksum': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'schema_version': 5,
        'record_counts': {
          'user_profiles': 1,
          'money_sources': 3,
          'transactions': 12,
        },
        'updated_at': '2026-10-14T10:00:00.000Z',
      };

      final summary = CloudBackupSummary.fromJson(json);
      expect(summary.id, 'backup-uuid-1');
      expect(summary.identifier, '+213555123456');
      expect(summary.phone, '+213555123456');
      expect(summary.email, 'user@example.com');
      expect(summary.checksum, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(summary.schemaVersion, 5);
      expect(summary.totalRecords, 16);
      expect(summary.updatedAt.isUtc, isTrue);
    });

    test('Export object problem is resolved: full database export with enums succeeds', () async {
      // 1. Seed user profile
      await db.into(db.userProfiles).insert(
            UserProfilesCompanion.insert(
              id: const Value('default'),
              name: 'John Doe',
              currency: const Value('DZD'),
            ),
          );

      // 2. Seed multiple money sources with distinct SourceType enums
      await db.into(db.moneySources).insert(
            MoneySourcesCompanion.insert(
              id: 'wallet_cash',
              name: 'Cash Pocket',
              type: SourceType.cash,
              currency: const Value('DZD'),
            ),
          );
      await db.into(db.moneySources).insert(
            MoneySourcesCompanion.insert(
              id: 'bank_acc',
              name: 'Main Bank Account',
              type: SourceType.bankAccount,
              currency: const Value('DZD'),
            ),
          );

      // 3. Seed category
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat_groceries',
              name: 'Groceries',
            ),
          );

      // 4. Seed transaction
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'txn_001',
              type: 'expense',
              amountMinor: 450000,
              currency: const Value('DZD'),
              sourceId: 'wallet_cash',
              categoryId: const Value('cat_groceries'),
              date: DateTime.now(),
            ),
          );

      // 5. Seed transfer
      await db.into(db.transfers).insert(
            TransfersCompanion.insert(
              id: 'trf_001',
              fromSourceId: 'bank_acc',
              toSourceId: 'wallet_cash',
              amountMinor: 1000000,
              currency: const Value('DZD'),
              date: DateTime.now(),
            ),
          );

      // 6. Execute exportBackup
      final exportResult = await backupService.exportBackup();
      expect(exportResult.isSuccess, isTrue);

      final jsonString = exportResult.value;
      expect(jsonString, isNotEmpty);

      // Verify that no 'Instance of SourceType' or unencoded object exists
      expect(jsonString.contains('Instance of'), isFalse);
      expect(jsonString.contains('cash'), isTrue);
      expect(jsonString.contains('bankAccount'), isTrue);

      // 7. Validate through 12-point pipeline
      final validation = backupService.validateBackupPayload(jsonString);
      expect(validation.isValid, isTrue);
      expect(validation.errorMessage, isNull);
      expect(validation.schemaVersion, AppConstants.databaseVersion);
      expect(validation.totalRecords, greaterThanOrEqualTo(5));

      // 8. Restore into database and verify clean round-trip
      final restoreResult = await backupService.restoreBackup(jsonString);
      expect(restoreResult.isSuccess, isTrue);

      final restoredSources = await db.select(db.moneySources).get();
      expect(restoredSources.length, 2);
      expect(restoredSources.any((s) => s.type == SourceType.cash), isTrue);
      expect(restoredSources.any((s) => s.type == SourceType.bankAccount), isTrue);

      final restoredTxns = await db.select(db.transactions).get();
      expect(restoredTxns.length, 1);
      expect(restoredTxns.first.id, 'txn_001');
    });

    test('File export writes verified JSON file to disk path', () async {
      final tempDir = Directory.systemTemp.createTempSync('fml_test_');
      final targetFile = '${tempDir.path}/test_backup.json';

      final exportFileResult = await backupService.exportBackupToFile(customPath: targetFile);
      expect(exportFileResult.isSuccess, isTrue);

      final filePath = exportFileResult.value;
      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      final validation = backupService.validateBackupPayload(content);
      expect(validation.isValid, isTrue);

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    test('Online backup enabled setting can be toggled and read', () async {
      expect(await backupService.isOnlineBackupEnabled(), isFalse);

      await backupService.setOnlineBackupEnabled(true);
      expect(await backupService.isOnlineBackupEnabled(), isTrue);

      await backupService.setOnlineBackupEnabled(false);
      expect(await backupService.isOnlineBackupEnabled(), isFalse);
    });
  });
}

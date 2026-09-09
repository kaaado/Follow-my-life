import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_my_life/core/security/security_service.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/database/app_database.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({required String key, iOptions, aOptions, eOptions, sOptions, mOptions, lOptions, webOptions, wOptions}) async {
    return _data[key];
  }

  @override
  Future<void> write({required String key, required String? value, iOptions, aOptions, eOptions, sOptions, mOptions, lOptions, webOptions, wOptions}) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, iOptions, aOptions, eOptions, sOptions, mOptions, lOptions, webOptions, wOptions}) async {
    _data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Stage 20 Production Hardening Unit Tests', () {
    late FakeSecureStorage fakeStorage;
    late SecurityService securityService;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      securityService = SecurityService(storage: fakeStorage);
    });

    test('SecurityService sets and verifies PIN correctly', () async {
      final setSuccess = await securityService.setPin('1234');
      expect(setSuccess, isTrue);
      expect(securityService.isPinConfigured, isTrue);

      final verifySuccess = await securityService.verifyPin('1234');
      expect(verifySuccess, isTrue);

      final verifyFail = await securityService.verifyPin('0000');
      expect(verifyFail, isFalse);
    });

    test('SecurityService enforces PIN rate limiting and lockout after 5 failed attempts', () async {
      await securityService.setPin('1234');

      // 4 wrong attempts
      for (int i = 0; i < 4; i++) {
        final result = await securityService.verifyPin('9999');
        expect(result, isFalse);
        expect(securityService.isLockoutActive, isFalse);
      }

      // 5th wrong attempt triggers lockout
      final result5 = await securityService.verifyPin('9999');
      expect(result5, isFalse);
      expect(securityService.isLockoutActive, isTrue);
      expect(securityService.lockoutRemainingSeconds, greaterThan(0));

      // Even correct PIN is blocked while lockout is active
      final blockedResult = await securityService.verifyPin('1234');
      expect(blockedResult, isFalse);
    });

    test('SecurityService requires valid current PIN to disable security', () async {
      await securityService.setPin('1234');

      // Attempt to disable with wrong PIN
      final disableWrong = await securityService.disablePin(currentPin: '0000');
      expect(disableWrong, isFalse);
      expect(securityService.isPinConfigured, isTrue);

      // Disable with correct PIN
      final disableCorrect = await securityService.disablePin(currentPin: '1234');
      expect(disableCorrect, isTrue);
      expect(securityService.isPinConfigured, isFalse);
    });

    test('AppLocalizations supports English, French, and Arabic seamlessly', () {
      final enLoc = AppLocalizations(const Locale('en'));
      final frLoc = AppLocalizations(const Locale('fr'));
      final arLoc = AppLocalizations(const Locale('ar'));

      expect(enLoc.translate('app_title'), 'Follow My Life');
      expect(frLoc.translate('app_title'), 'Follow My Life');
      expect(arLoc.translate('app_title'), 'Follow My Life');

      expect(enLoc.translate('safe_to_spend'), 'Safe to Spend');
      expect(frLoc.translate('safe_to_spend'), 'Dépense sécurisée');
      expect(arLoc.translate('safe_to_spend'), 'المبلغ الآمن للإنفاق');

      expect(arLoc.translate('income_source'), 'مصدر دخل');
      expect(arLoc.translate('theme'), 'نمط العرض');
    });

    test('AppDatabase table index configuration is defined', () {
      final transactionsTable = Transactions();
      expect(transactionsTable.indexes, isNotEmpty);

      final recurringTable = RecurringTransactions();
      expect(recurringTable.indexes, isNotEmpty);
    });
  });
}

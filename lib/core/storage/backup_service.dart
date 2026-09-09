import 'dart:convert';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';

class BackupPayload {
  final String version;
  final DateTime exportedAt;
  final Map<String, dynamic> data;
  final String checksum;

  const BackupPayload({
    required this.version,
    required this.exportedAt,
    required this.data,
    required this.checksum,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'data': data,
        'checksum': checksum,
      };
}

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  Future<Result<String>> exportBackup() async {
    try {
      final sources = await _db.select(_db.moneySources).get();
      final txns = await _db.select(_db.transactions).get();
      final debts = await _db.select(_db.debts).get();

      final rawData = {
        'sources_count': sources.length,
        'transactions_count': txns.length,
        'debts_count': debts.length,
      };

      final dataJson = jsonEncode(rawData);
      final checksum = dataJson.hashCode.toString();

      final payload = BackupPayload(
        version: '1.0.0',
        exportedAt: DateTime.now(),
        data: rawData,
        checksum: checksum,
      );

      return Success(jsonEncode(payload.toJson()));
    } catch (e) {
      return Failure(BackupFailure('Failed to export backup: $e'));
    }
  }

  Future<Result<void>> restoreBackup(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final checksum = decoded['checksum'] as String?;
      final rawData = decoded['data'] as Map<String, dynamic>?;

      if (checksum == null || rawData == null) {
        return Failure(const BackupFailure('Invalid backup payload structure'));
      }

      final computedChecksum = jsonEncode(rawData).hashCode.toString();
      if (checksum != computedChecksum) {
        return Failure(const BackupFailure('Backup integrity check failed (checksum mismatch)'));
      }

      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('Failed to restore backup: $e'));
    }
  }
}

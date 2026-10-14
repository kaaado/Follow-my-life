import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_my_life/core/constants/app_constants.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';
import 'package:follow_my_life/core/storage/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudBackupSummary {
  final String id;
  final String identifier;
  final String? phone;
  final String? email;
  final String checksum;
  final int schemaVersion;
  final int totalRecords;
  final DateTime updatedAt;
  final Map<String, dynamic>? recordCounts;

  const CloudBackupSummary({
    required this.id,
    required this.identifier,
    this.phone,
    this.email,
    required this.checksum,
    required this.schemaVersion,
    required this.totalRecords,
    required this.updatedAt,
    this.recordCounts,
  });

  factory CloudBackupSummary.fromJson(Map<String, dynamic> json) {
    int total = 0;
    final rc = json['record_counts'] as Map<String, dynamic>?;
    if (rc != null) {
      for (final v in rc.values) {
        if (v is int) total += v;
      }
    }

    return CloudBackupSummary(
      id: (json['id'] ?? '').toString(),
      identifier: (json['identifier'] ?? json['user_id'] ?? '').toString(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      checksum: (json['checksum'] ?? '').toString(),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? AppConstants.databaseVersion,
      totalRecords: total > 0 ? total : ((json['total_records'] as num?)?.toInt() ?? 0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      recordCounts: rc,
    );
  }
}

class SupabaseBackupService {
  final BackupService _backupService;
  final FlutterSecureStorage _storage;

  // Supabase Project Configuration Defaults
  static const String defaultProjectRef = 'yyjhsexdlqpdbojpfngh';
  static const String defaultSupabaseUrl = 'https://yyjhsexdlqpdbojpfngh.supabase.co';
  static const String directHost = 'db.yyjhsexdlqpdbojpfngh.supabase.co';
  static const int directPort = 5432;
  static const String directDatabase = 'postgres';
  static const String directUser = 'postgres';

  // Secure storage keys
  static const _keyAnonKey = 'supabase_anon_key';
  static const _keyCustomUrl = 'supabase_custom_url';
  static const _keyPhoneIdentifier = 'supabase_phone_identifier';

  // Fallback demo/public anon key placeholder for the project
  // Can be configured or updated via UI settings anytime
  static const String _defaultAnonPlaceholder =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5amhzZXhkbHFwZGJvanBmbmdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDk4Mjk5MDAsImV4cCI6MjAyNTQwNTkwMH0.placeholder';

  bool _isInitialized = false;

  SupabaseBackupService(
    this._backupService, {
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  bool get isInitialized => _isInitialized;

  /// Get current Supabase client instance if initialized.
  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize Supabase Flutter SDK
  Future<Result<void>> initSupabase({String? customUrl, String? customAnonKey}) async {
    try {
      if (client != null) {
        _isInitialized = true;
        return const Success(null);
      }

      final savedUrl = await _storage.read(key: _keyCustomUrl);
      final savedAnonKey = await _storage.read(key: _keyAnonKey);

      final url = customUrl ?? savedUrl ?? defaultSupabaseUrl;
      final anonKey = customAnonKey ?? savedAnonKey ?? _defaultAnonPlaceholder;

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: kDebugMode,
      );

      _isInitialized = true;
      return const Success(null);
    } catch (e) {
      // If already initialized, mark true
      if (e.toString().contains('already initialized') || client != null) {
        _isInitialized = true;
        return const Success(null);
      }
      return Failure(BackupFailure('Failed to initialize Supabase: ${e.toString()}'));
    }
  }

  /// Configure custom Anon Key or URL
  Future<void> saveCredentials({required String anonKey, String? url}) async {
    await _storage.write(key: _keyAnonKey, value: anonKey);
    if (url != null) {
      await _storage.write(key: _keyCustomUrl, value: url);
    }
  }

  // ─── Authentication & User Identification ───────────────────

  /// Current authenticated Supabase User
  User? get currentUser => client?.auth.currentUser;

  /// Current authentication or phone identifier
  Future<String?> getCurrentIdentifier() async {
    if (currentUser?.phone != null && currentUser!.phone!.isNotEmpty) {
      return currentUser!.phone;
    }
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      return currentUser!.email;
    }
    if (currentUser?.id != null) {
      return currentUser!.id;
    }
    return await _storage.read(key: _keyPhoneIdentifier);
  }

  bool get isAuthenticated => currentUser != null;

  /// Set custom phone identifier (for phone-based recovery without SMS OTP gateway setup)
  Future<void> setPhoneIdentifier(String phone) async {
    await _storage.write(key: _keyPhoneIdentifier, value: phone.trim());
  }

  /// Sign in or register with Phone OTP (SMS)
  Future<Result<void>> signInWithPhoneOtp(String phoneNumber) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return initRes;

    try {
      final cl = client;
      if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

      await cl.auth.signInWithOtp(
        phone: phoneNumber.trim(),
      );

      await setPhoneIdentifier(phoneNumber);
      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('Phone OTP request failed: ${e.toString()}'));
    }
  }

  /// Verify Phone OTP code
  Future<Result<AuthResponse>> verifyPhoneOtp({
    required String phoneNumber,
    required String token,
  }) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    try {
      final cl = client;
      if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

      final response = await cl.auth.verifyOTP(
        phone: phoneNumber.trim(),
        token: token.trim(),
        type: OtpType.sms,
      );

      await setPhoneIdentifier(phoneNumber);
      return Success(response);
    } catch (e) {
      return Failure(BackupFailure('OTP verification failed: ${e.toString()}'));
    }
  }

  /// Sign in with Email and Password
  Future<Result<AuthResponse>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    try {
      final cl = client;
      if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

      final res = await cl.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return Success(res);
    } catch (e) {
      return Failure(BackupFailure('Email sign-in failed: ${e.toString()}'));
    }
  }

  /// Sign up with Email and Password
  Future<Result<AuthResponse>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    try {
      final cl = client;
      if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

      final res = await cl.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return Success(res);
    } catch (e) {
      return Failure(BackupFailure('Sign-up failed: ${e.toString()}'));
    }
  }

  /// Sign in with SSO / OAuth (e.g. Google, Apple)
  Future<Result<void>> signInWithOAuth(OAuthProvider provider) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return initRes;

    try {
      final cl = client;
      if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

      await cl.auth.signInWithOAuth(
        provider,
        redirectTo: 'followmylife://login-callback',
      );
      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('SSO authentication failed: ${e.toString()}'));
    }
  }

  /// Sign out current Supabase session
  Future<Result<void>> signOut() async {
    try {
      await client?.auth.signOut();
      await _storage.delete(key: _keyPhoneIdentifier);
      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('Sign out failed: ${e.toString()}'));
    }
  }

  // ─── Cloud Backup & Recovery Operations ──────────────────────

  /// Upload current database snapshot to Supabase Cloud
  Future<Result<CloudBackupSummary>> uploadBackupToCloud() async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    final cl = client;
    if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

    final identifier = await getCurrentIdentifier();
    if (identifier == null || identifier.isEmpty) {
      return const Failure(BackupFailure(
        'Please sign in or provide your phone number/account to sync with Supabase cloud.',
      ));
    }

    try {
      // 1. Export local database snapshot
      final exportRes = await _backupService.exportBackup();
      if (exportRes.isFailure) return Failure(exportRes.failure);

      final payloadJsonStr = exportRes.value;
      final payloadMap = jsonDecode(payloadJsonStr) as Map<String, dynamic>;
      final metadata = payloadMap['metadata'] as Map<String, dynamic>;
      final checksum = payloadMap['checksum'] as String;
      final data = payloadMap['data'] as Map<String, dynamic>;
      final recordCounts = metadata['record_counts'] as Map<String, dynamic>?;

      final now = DateTime.now().toUtc();
      final backupRecord = {
        'user_id': currentUser?.id,
        'phone': currentUser?.phone ?? (identifier.contains('+') || RegExp(r'^[0-9]+$').hasMatch(identifier) ? identifier : null),
        'email': currentUser?.email ?? (identifier.contains('@') ? identifier : null),
        'identifier': identifier,
        'checksum': checksum,
        'schema_version': AppConstants.databaseVersion,
        'record_counts': recordCounts,
        'backup_data': data,
        'metadata': metadata,
        'updated_at': now.toIso8601String(),
      };

      // 2. Upsert into Supabase `user_backups` table
      final response = await cl
          .from('user_backups')
          .upsert(backupRecord, onConflict: 'identifier')
          .select()
          .maybeSingle();

      final summary = CloudBackupSummary(
        id: response?['id']?.toString() ?? 'cloud_${now.millisecondsSinceEpoch}',
        identifier: identifier,
        phone: backupRecord['phone'] as String?,
        email: backupRecord['email'] as String?,
        checksum: checksum,
        schemaVersion: AppConstants.databaseVersion,
        totalRecords: metadata['record_counts'] != null
            ? (metadata['record_counts'] as Map).values.fold<int>(0, (sum, v) => sum + (v as int? ?? 0))
            : 0,
        updatedAt: now.toLocal(),
        recordCounts: recordCounts,
      );

      // 3. Mark last backup in secure storage
      await _storage.write(
        key: 'last_backup_timestamp',
        value: DateTime.now().toIso8601String(),
      );

      return Success(summary);
    } catch (e) {
      return Failure(BackupFailure('Failed to upload backup to Supabase: ${e.toString()}'));
    }
  }

  /// Fetch list of cloud backups available for current user / phone
  Future<Result<List<CloudBackupSummary>>> fetchCloudBackups() async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    final cl = client;
    if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

    final identifier = await getCurrentIdentifier();
    if (identifier == null || identifier.isEmpty) {
      return const Success([]);
    }

    try {
      final query = cl.from('user_backups').select();

      final List<dynamic> records;
      if (currentUser?.id != null) {
        records = await query
            .or('user_id.eq.${currentUser!.id},identifier.eq.$identifier,phone.eq.$identifier')
            .order('updated_at', ascending: false);
      } else {
        records = await query
            .or('identifier.eq.$identifier,phone.eq.$identifier')
            .order('updated_at', ascending: false);
      }

      final summaries = records
          .map((r) => CloudBackupSummary.fromJson(r as Map<String, dynamic>))
          .toList();

      return Success(summaries);
    } catch (e) {
      return Failure(BackupFailure('Failed to fetch cloud backups from Supabase: ${e.toString()}'));
    }
  }

  /// Pull and restore the latest backup from Supabase Cloud
  Future<Result<void>> restoreLatestBackupFromCloud({String? backupId}) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    final cl = client;
    if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

    final identifier = await getCurrentIdentifier();
    if (identifier == null || identifier.isEmpty) {
      return const Failure(BackupFailure('No authenticated user or phone identifier found.'));
    }

    try {
      Map<String, dynamic>? record;

      if (backupId != null) {
        record = await cl.from('user_backups').select().eq('id', backupId).maybeSingle();
      } else {
        final query = cl.from('user_backups').select();
        final List<dynamic> list;
        if (currentUser?.id != null) {
          list = await query
              .or('user_id.eq.${currentUser!.id},identifier.eq.$identifier,phone.eq.$identifier')
              .order('updated_at', ascending: false)
              .limit(1);
        } else {
          list = await query
              .or('identifier.eq.$identifier,phone.eq.$identifier')
              .order('updated_at', ascending: false)
              .limit(1);
        }
        if (list.isNotEmpty) {
          record = list.first as Map<String, dynamic>;
        }
      }

      if (record == null) {
        return const Failure(BackupFailure('No cloud backup found for this account/phone number.'));
      }

      // Reconstruct full BackupPayload JSON
      final checksum = record['checksum'] as String? ?? '';
      final metadata = (record['metadata'] as Map<String, dynamic>?) ??
          {
            'app': 'Follow My Life',
            'schema_version': record['schema_version'] ?? AppConstants.databaseVersion,
            'exported_at': record['updated_at'] ?? DateTime.now().toIso8601String(),
          };
      final data = (record['backup_data'] as Map<String, dynamic>?) ?? {};

      final reconstructedPayload = {
        'metadata': metadata,
        'checksum': checksum,
        'data': data,
      };

      final jsonPayloadStr = jsonEncode(reconstructedPayload);

      // Validate through the 12-point pipeline
      final validation = _backupService.validateBackupPayload(jsonPayloadStr);
      if (!validation.isValid) {
        return Failure(BackupFailure(
          'Cloud backup failed integrity check: ${validation.errorMessage}',
        ));
      }

      // Restore into local SQLite database
      final restoreRes = await _backupService.restoreBackup(jsonPayloadStr);
      return restoreRes;
    } catch (e) {
      return Failure(BackupFailure('Failed to restore from Supabase: ${e.toString()}'));
    }
  }

  /// Delete a cloud backup from Supabase
  Future<Result<void>> deleteCloudBackup(String backupId) async {
    final cl = client;
    if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

    try {
      await cl.from('user_backups').delete().eq('id', backupId);
      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('Failed to delete cloud backup: ${e.toString()}'));
    }
  }
}

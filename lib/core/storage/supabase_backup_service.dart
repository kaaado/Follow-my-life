import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_my_life/core/config/env_config.dart';
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

  // Supabase Project Configuration (dynamically sourced from EnvConfig / environment)
  static String get defaultProjectRef => EnvConfig.supabaseProjectRef;
  static String get defaultSupabaseUrl => EnvConfig.supabaseUrl;
  static String get directHost => EnvConfig.directHost;
  static int get directPort => EnvConfig.directPort;
  static String get directDatabase => EnvConfig.directDatabase;
  static String get directUser => EnvConfig.directUser;

  // Secure storage keys
  static const _keyAnonKey = 'supabase_anon_key';
  static const _keyCustomUrl = 'supabase_custom_url';
  static const _keySyncIdentifier = 'supabase_sync_identifier';
  static const _keyPhoneIdentifier = 'supabase_phone_identifier';

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
      final anonKey = customAnonKey ?? savedAnonKey ?? EnvConfig.resolvedAnonKey;

      if (anonKey.isEmpty) {
        return const Failure(BackupFailure(
          'Supabase anon key is not configured. Please define SUPABASE_ANON_KEY in your .env or configure custom credentials.',
        ));
      }

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
    await _storage.write(key: _keyAnonKey, value: anonKey.trim());
    if (url != null && url.trim().isNotEmpty) {
      await _storage.write(key: _keyCustomUrl, value: url.trim());
    }
    _isInitialized = false;
  }

  /// Read currently configured Supabase credentials (saved in secure storage or fallback to EnvConfig)
  Future<Map<String, String>> getCredentials() async {
    final savedUrl = await _storage.read(key: _keyCustomUrl);
    final savedAnonKey = await _storage.read(key: _keyAnonKey);
    return {
      'url': savedUrl ?? EnvConfig.supabaseUrl,
      'anonKey': savedAnonKey ?? EnvConfig.supabaseAnonKey,
    };
  }

  // ─── Simple Cloud Sync Key Management ──────────────────────

  /// Get current Cloud Sync Key.
  /// If one already exists in storage, returns it.
  /// Otherwise, automatically creates a new 6-character random key and saves it.
  Future<String> getSyncKey() async {
    final saved = await _storage.read(key: _keySyncIdentifier) ??
                  await _storage.read(key: _keyPhoneIdentifier);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    final freshKey = generateRandomSyncKey();
    await _storage.write(key: _keySyncIdentifier, value: freshKey);
    return freshKey;
  }

  /// Set or change the Cloud Sync Key (e.g. entering key from another device or custom memorable phrase).
  Future<void> setSyncKey(String key) async {
    final clean = key.trim();
    if (clean.isNotEmpty) {
      await _storage.write(key: _keySyncIdentifier, value: clean);
      await _storage.write(key: _keyPhoneIdentifier, value: clean);
    }
  }

  /// Generate and store a fresh unique Sync Key.
  Future<String> generateNewSyncKey() async {
    final freshKey = generateRandomSyncKey();
    await _storage.write(key: _keySyncIdentifier, value: freshKey);
    await _storage.write(key: _keyPhoneIdentifier, value: freshKey);
    return freshKey;
  }

  /// Generate a clean, readable sync code (no confusing characters like 0/O, 1/l).
  static String generateRandomSyncKey() {
    const chars = '23456789abcdefghjkmnpqrstuvwxyz';
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'fml-$code';
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
    return await _storage.read(key: _keySyncIdentifier) ??
           await _storage.read(key: _keyPhoneIdentifier);
  }

  bool get isAuthenticated => currentUser != null;

  /// Set custom phone identifier (for phone-based recovery without SMS OTP gateway setup)
  Future<void> setPhoneIdentifier(String phone) async {
    await setSyncKey(phone);
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
      await _storage.delete(key: _keySyncIdentifier);
      await _storage.delete(key: _keyPhoneIdentifier);
      return const Success(null);
    } catch (e) {
      return Failure(BackupFailure('Sign out failed: ${e.toString()}'));
    }
  }

  // ─── Cloud Backup & Recovery Operations ──────────────────────

  /// Upload current database snapshot to Supabase Cloud
  Future<Result<CloudBackupSummary>> uploadBackupToCloud({
    String? syncKey,
    String? customSyncKey,
  }) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    final cl = client;
    if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

    final effectiveKey = (syncKey != null && syncKey.trim().isNotEmpty)
        ? syncKey.trim()
        : (customSyncKey != null && customSyncKey.trim().isNotEmpty)
            ? customSyncKey.trim()
            : null;
    final identifier = effectiveKey ?? await getSyncKey();

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
        'phone': currentUser?.phone,
        'email': currentUser?.email,
        'identifier': identifier,
        'checksum': checksum,
        'schema_version': AppConstants.databaseVersion,
        'record_counts': recordCounts,
        'backup_data': data,
        'metadata': metadata,
        'updated_at': now.toIso8601String(),
      };

      // 2. Resilient update or insert into Supabase `user_backups` table
      final existing = await cl
          .from('user_backups')
          .select('id')
          .eq('identifier', identifier)
          .maybeSingle();

      final Map<String, dynamic>? response;
      if (existing != null && existing['id'] != null) {
        response = await cl
            .from('user_backups')
            .update(backupRecord)
            .eq('id', existing['id'])
            .select()
            .maybeSingle();
      } else {
        response = await cl
            .from('user_backups')
            .insert(backupRecord)
            .select()
            .maybeSingle();
      }

      final summary = CloudBackupSummary(
        id: response?['id']?.toString() ?? existing?['id']?.toString() ?? 'cloud_${now.millisecondsSinceEpoch}',
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
      final msg = e.toString();
      if (msg.contains('Invalid API key') || msg.contains('401')) {
        return const Failure(BackupFailure(
          'Invalid Supabase API key. Please verify your Supabase configuration.',
        ));
      }
      if (msg.contains('relation "public.user_backups" does not exist') ||
          msg.contains('42P01') ||
          msg.contains('PGRST205') ||
          msg.contains('schema cache')) {
        return const Failure(BackupFailure(
          'Table user_backups not found on Supabase. Please run schema_user_backups.sql in your Supabase SQL Editor.',
        ));
      }
      return Failure(BackupFailure('Failed to upload backup: $msg'));
    }
  }

  /// Fetch list of cloud backups available for current sync key
  Future<Result<List<CloudBackupSummary>>> fetchCloudBackups({
    String? syncKey,
    String? customSyncKey,
  }) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    final cl = client;
    if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

    final effectiveKey = (syncKey != null && syncKey.trim().isNotEmpty)
        ? syncKey.trim()
        : (customSyncKey != null && customSyncKey.trim().isNotEmpty)
            ? customSyncKey.trim()
            : null;
    final identifier = effectiveKey ?? await getSyncKey();

    try {
      final query = cl.from('user_backups').select();

      final List<dynamic> records;
      if (currentUser?.id != null) {
        records = await query
            .or('user_id.eq.${currentUser!.id},identifier.eq.$identifier')
            .order('updated_at', ascending: false);
      } else {
        records = await query
            .eq('identifier', identifier)
            .order('updated_at', ascending: false);
      }

      final summaries = records
          .map((r) => CloudBackupSummary.fromJson(r as Map<String, dynamic>))
          .toList();

      return Success(summaries);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('relation "public.user_backups" does not exist') ||
          msg.contains('42P01') ||
          msg.contains('PGRST205') ||
          msg.contains('schema cache')) {
        return const Failure(BackupFailure(
          'Table user_backups not found on Supabase. Please run schema_user_backups.sql in your Supabase SQL Editor.',
        ));
      }
      if (msg.contains('Invalid API key') || msg.contains('401')) {
        return const Failure(BackupFailure(
          'Invalid Supabase API key. Please check your Supabase configuration.',
        ));
      }
      return Failure(BackupFailure('Failed to fetch cloud backups: $msg'));
    }
  }

  /// Pull and restore the latest backup from Supabase Cloud
  Future<Result<void>> restoreLatestBackupFromCloud({
    String? syncKey,
    String? targetSyncKey,
    String? backupId,
  }) async {
    final initRes = await initSupabase();
    if (initRes.isFailure) return Failure(initRes.failure);

    final cl = client;
    if (cl == null) return const Failure(BackupFailure('Supabase client is not available.'));

    final effectiveKey = (syncKey != null && syncKey.trim().isNotEmpty)
        ? syncKey.trim()
        : (targetSyncKey != null && targetSyncKey.trim().isNotEmpty)
            ? targetSyncKey.trim()
            : null;
    final identifier = effectiveKey ?? await getSyncKey();

    try {
      Map<String, dynamic>? record;

      if (backupId != null) {
        record = await cl.from('user_backups').select().eq('id', backupId).maybeSingle();
      } else {
        final query = cl.from('user_backups').select();
        final List<dynamic> list;
        if (currentUser?.id != null) {
          list = await query
              .or('user_id.eq.${currentUser!.id},identifier.eq.$identifier')
              .order('updated_at', ascending: false)
              .limit(1);
        } else {
          list = await query
              .eq('identifier', identifier)
              .order('updated_at', ascending: false)
              .limit(1);
        }
        if (list.isNotEmpty) {
          record = list.first as Map<String, dynamic>;
        }
      }

      if (record == null) {
        return Failure(BackupFailure(
          'No cloud backup found for Sync Key: "$identifier". Make sure you have uploaded a backup with this key first.',
        ));
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

      // Restore into database
      return await _backupService.restoreBackup(jsonPayloadStr);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('relation "public.user_backups" does not exist') ||
          msg.contains('42P01') ||
          msg.contains('PGRST205') ||
          msg.contains('schema cache')) {
        return const Failure(BackupFailure(
          'Table user_backups not found on Supabase. Please run schema_user_backups.sql in your Supabase SQL Editor.',
        ));
      }
      if (msg.contains('Invalid API key') || msg.contains('401')) {
        return const Failure(BackupFailure(
          'Invalid Supabase API key. Please check your Supabase configuration.',
        ));
      }
      return Failure(BackupFailure('Failed to restore from cloud: $msg'));
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

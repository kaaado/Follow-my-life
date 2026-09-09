/// Profile repository — local persistence for user profile.
library;

import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/errors/failures.dart';
import 'package:follow_my_life/core/errors/result.dart';

class ProfileRepository {
  final AppDatabase _db;

  ProfileRepository(this._db);

  Future<Result<UserProfile?>> getProfile() async {
    try {
      final profile = await (_db.select(_db.userProfiles)
            ..limit(1))
          .getSingleOrNull();
      return Success(profile);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to load profile', e.toString()));
    }
  }

  Future<Result<UserProfile>> createProfile({
    required String name,
    String currency = 'DZD',
    String locale = 'ar',
    String themeMode = 'dark',
    int firstDayOfWeek = 1,
  }) async {
    try {
      await _db.into(_db.userProfiles).insert(UserProfilesCompanion.insert(
            name: name,
            currency: Value(currency),
            locale: Value(locale),
            themeMode: Value(themeMode),
            firstDayOfWeek: Value(firstDayOfWeek),
          ));
      final profile = await (_db.select(_db.userProfiles)..limit(1)).getSingle();
      return Success(profile);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to create profile', e.toString()));
    }
  }

  Future<Result<UserProfile>> updateProfile({
    String? name,
    String? currency,
    String? locale,
    String? themeMode,
    int? firstDayOfWeek,
    String? profilePhotoPath,
  }) async {
    try {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals('default')))
          .write(UserProfilesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        currency: currency != null ? Value(currency) : const Value.absent(),
        locale: locale != null ? Value(locale) : const Value.absent(),
        themeMode: themeMode != null ? Value(themeMode) : const Value.absent(),
        firstDayOfWeek:
            firstDayOfWeek != null ? Value(firstDayOfWeek) : const Value.absent(),
        profilePhotoPath: profilePhotoPath != null
            ? Value(profilePhotoPath)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));
      final profile = await (_db.select(_db.userProfiles)..limit(1)).getSingle();
      return Success(profile);
    } catch (e) {
      return Failure(DatabaseFailure('Failed to update profile', e.toString()));
    }
  }

  /// Stream for real-time profile updates.
  Stream<UserProfile?> watchProfile() {
    return (_db.select(_db.userProfiles)..limit(1))
        .watchSingleOrNull();
  }
}

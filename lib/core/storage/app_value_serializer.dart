import 'package:drift/drift.dart';
import 'package:follow_my_life/core/database/app_database.dart';

/// Custom Drift [ValueSerializer] to properly serialize and deserialize
/// Enums (like [SourceType]) and date/time fields to/from JSON.
///
/// Prevents the "Converting object to an encodable object failed: Instance of '...'"
/// error during database export.
class AppValueSerializer extends ValueSerializer {
  final ValueSerializer _fallback;

  AppValueSerializer([ValueSerializer? fallback])
      : _fallback = fallback ?? driftRuntimeOptions.defaultSerializer;

  @override
  T fromJson<T>(dynamic json) {
    if (json == null) {
      return null as T;
    }

    if (T == SourceType) {
      if (json is String) {
        return SourceType.values.firstWhere(
          (e) => e.name == json,
          orElse: () => SourceType.other,
        ) as T;
      }
    }

    return _fallback.fromJson<T>(json);
  }

  @override
  dynamic toJson<T>(T value) {
    if (value == null) {
      return null;
    }

    if (value is Enum) {
      return value.name;
    }

    return _fallback.toJson<T>(value);
  }
}

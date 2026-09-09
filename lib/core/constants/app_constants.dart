/// Application-wide constants.
/// Never hard-code values across the application; reference this file.
library;

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Follow My Life';
  static const String appVersion = '0.1.0';
  static const int appBuildNumber = 1;

  // Database
  static const String databaseName = 'follow_my_life.db';
  static const int databaseVersion = 4;

  // Backup
  static const String backupFileExtension = '.fml';
  static const int backupSchemaVersion = 1;

  // Defaults
  static const String defaultCurrency = 'DZD';
  static const String defaultLocale = 'en';
  static const int defaultFirstDayOfWeek = 1; // Monday

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Validation
  static const int maxSourceNameLength = 50;
  static const int maxCategoryNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxNoteLength = 1000;

  // Animation durations (ms)
  static const int animDurationFast = 150;
  static const int animDurationMedium = 300;
  static const int animDurationSlow = 500;
  static const int animDurationPage = 400;

  // Security
  static const String secureStorageKeyPrefix = 'fml_';
  static const int pinLength = 4;
}

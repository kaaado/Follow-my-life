/// Currency definitions and utilities.
/// All monetary amounts are stored as integer minor units to avoid
/// floating-point precision issues.
library;

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;
  final String locale;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
    required this.locale,
  });

  /// Convert a major unit double to minor unit integer.
  /// e.g., 85000.50 DZD (2 decimals) → 8500050
  int toMinorUnits(double majorUnits) {
    final multiplier = _pow10(decimalDigits);
    return (majorUnits * multiplier).round();
  }

  /// Convert minor unit integer to major unit double.
  /// e.g., 8500050 → 85000.50 DZD
  double toMajorUnits(int minorUnits) {
    final multiplier = _pow10(decimalDigits);
    return minorUnits / multiplier;
  }

  int _pow10(int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }
}

class CurrencyConstants {
  CurrencyConstants._();

  static const Map<String, CurrencyInfo> currencies = {
    'DZD': CurrencyInfo(
      code: 'DZD',
      symbol: 'د.ج',
      name: 'Algerian Dinar',
      decimalDigits: 2,
      locale: 'ar_DZ',
    ),
    'EUR': CurrencyInfo(
      code: 'EUR',
      symbol: '€',
      name: 'Euro',
      decimalDigits: 2,
      locale: 'fr_FR',
    ),
    'USD': CurrencyInfo(
      code: 'USD',
      symbol: '\$',
      name: 'US Dollar',
      decimalDigits: 2,
      locale: 'en_US',
    ),
    'GBP': CurrencyInfo(
      code: 'GBP',
      symbol: '£',
      name: 'British Pound',
      decimalDigits: 2,
      locale: 'en_GB',
    ),
  };

  static CurrencyInfo getCurrency(String code) {
    return currencies[code] ?? currencies['DZD']!;
  }

  static List<String> get supportedCurrencies => currencies.keys.toList();
}

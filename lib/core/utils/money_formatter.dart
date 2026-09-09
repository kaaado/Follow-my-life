/// Centralized money formatting utility.
/// Never manually format currency in individual screens.
library;

import 'package:intl/intl.dart';
import 'package:follow_my_life/core/constants/currency_constants.dart';

class MoneyFormatter {
  MoneyFormatter._();

  /// Format minor units to display string.
  /// e.g., 8500000 DZD → "85,000.00 DZD"
  static String format(int minorUnits, {String currency = 'DZD', bool showCurrency = true, bool compact = false}) {
    final info = CurrencyConstants.getCurrency(currency);
    final majorValue = info.toMajorUnits(minorUnits);

    NumberFormat formatter;
    try {
      formatter = compact
          ? NumberFormat.compact()
          : NumberFormat('#,##0${info.decimalDigits > 0 ? '.${'0' * info.decimalDigits}' : ''}');
    } catch (_) {
      formatter = NumberFormat('#,##0${info.decimalDigits > 0 ? '.${'0' * info.decimalDigits}' : ''}', 'en_US');
    }

    String formatted;
    try {
      formatted = formatter.format(majorValue);
    } catch (_) {
      formatted = majorValue.toStringAsFixed(info.decimalDigits);
    }

    if (!showCurrency) return formatted;

    // DZD uses suffix, others use prefix symbol
    if (currency == 'DZD') {
      return '$formatted ${info.symbol}';
    }
    return '${info.symbol}$formatted';
  }

  /// Format with sign prefix for income/expense display.
  static String formatSigned(int minorUnits, {String currency = 'DZD', bool isPositive = true}) {
    final sign = isPositive ? '+' : '-';
    return '$sign${format(minorUnits.abs(), currency: currency)}';
  }

  /// Format just the number without currency symbol.
  static String formatNumber(int minorUnits, {String currency = 'DZD'}) {
    return format(minorUnits, currency: currency, showCurrency: false);
  }

  /// Parse user input string to minor units.
  /// Handles both "85000" and "85,000" formats.
  static int? parseToMinor(String input, {String currency = 'DZD'}) {
    if (input.trim().isEmpty) return null;
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    final info = CurrencyConstants.getCurrency(currency);
    return info.toMinorUnits(value);
  }
}

/// Currency conversion and exchange rate normalization service.
/// Uses scaled integer arithmetic to protect financial data integrity and avoid
/// floating point drift.
library;

import 'package:follow_my_life/core/constants/currency_constants.dart';
import 'package:follow_my_life/features/finance/data/repositories/split_transaction_repository.dart';

class CurrencyConversionService {
  CurrencyConversionService._();

  /// Default reference exchange rates relative to DZD (Algerian Dinar).
  /// Rate represents: 1 [Currency] = X [DZD].
  static const Map<String, double> ratesToDzd = {
    'DZD': 1.0,
    'EUR': 145.0,
    'USD': 135.0,
    'GBP': 175.0,
  };

  /// Scale factor for integer math to prevent floating point inaccuracy.
  static const int _scaleFactor = 100000;

  /// Returns the exchange rate from [fromCurrency] to [toCurrency].
  /// Rate means: 1 unit of [fromCurrency] = result units of [toCurrency].
  static double getRate(String fromCurrency, String toCurrency) {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
      return 1.0;
    }

    final fromRateToDzd = ratesToDzd[fromCurrency.toUpperCase()] ?? 1.0;
    final toRateToDzd = ratesToDzd[toCurrency.toUpperCase()] ?? 1.0;

    if (toRateToDzd == 0) return 1.0;
    return fromRateToDzd / toRateToDzd;
  }

  /// Converts [amountMinor] from [fromCurrency] to [toCurrency] using scaled integer arithmetic.
  static int convertMinor({
    required int amountMinor,
    required String fromCurrency,
    required String toCurrency,
    double? customRate,
  }) {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();

    if (from == to || amountMinor == 0) {
      return amountMinor;
    }

    final rate = (customRate != null && customRate != 1.0) ? customRate : getRate(from, to);
    final scaledMultiplier = (rate * _scaleFactor).round();

    final fromInfo = CurrencyConstants.getCurrency(from);
    final toInfo = CurrencyConstants.getCurrency(to);

    int converted = (amountMinor * scaledMultiplier) ~/ _scaleFactor;

    // Handle decimal digit discrepancy if applicable
    if (toInfo.decimalDigits != fromInfo.decimalDigits) {
      final diff = toInfo.decimalDigits - fromInfo.decimalDigits;
      if (diff > 0) {
        for (int i = 0; i < diff; i++) {
          converted *= 10;
        }
      } else {
        for (int i = 0; i < -diff; i++) {
          converted ~/= 10;
        }
      }
    }

    return converted;
  }

  /// Alias for getRate.
  static double getExchangeRate(String fromCurrency, String toCurrency) =>
      getRate(fromCurrency, toCurrency);

  /// Alias for convertMinor.
  static int convert({
    required int amountMinor,
    required String fromCurrency,
    required String toCurrency,
    double? customRate,
  }) =>
      convertMinor(
        amountMinor: amountMinor,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        customRate: customRate,
      );

  /// Validates whether the sum of normalized split allocations equals the expected total.
  static ({bool isValid, int totalAllocatedNormalizedMinor, int remainingNormalizedMinor, String? errorMessage}) validateSplits({
    required int totalAmountMinor,
    required String baseCurrency,
    required List<dynamic> splits,
    int toleranceMinor = 2,
  }) {
    if (splits.isEmpty) {
      return (
        isValid: false,
        totalAllocatedNormalizedMinor: 0,
        remainingNormalizedMinor: totalAmountMinor,
        errorMessage: 'At least one split allocation is required.',
      );
    }

    int totalNormalizedMinor = 0;
    for (final split in splits) {
      int amount = 0;
      String currency = baseCurrency;
      double? customRate;

      if (split is SplitItemInput) {
        amount = split.amountMinor;
        currency = split.currency;
        customRate = split.exchangeRate;
      } else if (split is ({int amountMinor, String currency, double? customRate})) {
        amount = split.amountMinor;
        currency = split.currency;
        customRate = split.customRate;
      } else if (split is Map<String, dynamic>) {
        amount = (split['amountMinor'] as num?)?.toInt() ?? 0;
        currency = split['currency'] as String? ?? baseCurrency;
        customRate = (split['exchangeRate'] as num?)?.toDouble();
      }

      totalNormalizedMinor += convert(
        amountMinor: amount,
        fromCurrency: currency,
        toCurrency: baseCurrency,
        customRate: customRate,
      );
    }

    final diff = totalAmountMinor - totalNormalizedMinor;
    final isValid = diff.abs() <= toleranceMinor;

    return (
      isValid: isValid,
      totalAllocatedNormalizedMinor: totalNormalizedMinor,
      remainingNormalizedMinor: diff,
      errorMessage: isValid ? null : 'Sum of split allocations must equal the total expense.',
    );
  }
}

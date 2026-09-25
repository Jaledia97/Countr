import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported base currencies for Countr portfolio valuations and market analysis.
enum AppCurrency {
  usd('USD', '\$', 'US Dollar'),
  eur('EUR', '€', 'Euro'),
  gbp('GBP', '£', 'British Pound'),
  cad('CAD', 'CA\$', 'Canadian Dollar');

  /// Standard 3-letter ISO-4217 currency code.
  final String code;

  /// Display symbol for prices (e.g. '$', '€', '£', 'CA$').
  final String symbol;

  /// English human-readable currency name.
  final String displayName;

  const AppCurrency(this.code, this.symbol, this.displayName);

  /// Safe parser converting case-insensitive ISO strings or enum names into [AppCurrency].
  ///
  /// Defaults to [AppCurrency.usd] for null, unrecognized, or empty strings.
  static AppCurrency fromCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      return AppCurrency.usd;
    }
    final normalized = code.trim().toLowerCase();
    for (final c in AppCurrency.values) {
      if (c.code.toLowerCase() == normalized || c.name.toLowerCase() == normalized) {
        return c;
      }
    }
    return AppCurrency.usd;
  }
}

/// Global Riverpod StateProvider holding the user's selected base currency.
///
/// Defaults to [AppCurrency.usd].
final baseCurrencyProvider = StateProvider<AppCurrency>((ref) {
  return AppCurrency.usd;
});

/// Global Riverpod StateProvider tracking whether Privacy Mode is active.
///
/// When active (`true`), all financial figures app-wide (Vault totals, card prices,
/// deck valuations, P&L deltas) are redacted to '****' or blurred placeholders.
/// Defaults to `false`.
final privacyModeProvider = StateProvider<bool>((ref) {
  return false;
});

/// Global Riverpod StateProvider for Streamer Security.
///
/// When enabled (`true`), entering background lifecycle state (`paused`, `inactive`, `hidden`)
/// or losing application focus automatically activates [privacyModeProvider].
/// Defaults to `false`.
final streamerSecurityEnabledProvider = StateProvider<bool>((ref) {
  return false;
});

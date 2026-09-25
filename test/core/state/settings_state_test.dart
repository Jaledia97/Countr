import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/state/settings_state.dart';

void main() {
  group('SettingsState Unit Tests', () {
    test('S1.1: AppCurrency enum contains USD, EUR, GBP, CAD with valid symbols and metadata', () {
      expect(AppCurrency.values, hasLength(4));
      expect(AppCurrency.usd.code, equals('USD'));
      expect(AppCurrency.usd.symbol, equals('\$'));
      expect(AppCurrency.usd.displayName, equals('US Dollar'));

      expect(AppCurrency.eur.code, equals('EUR'));
      expect(AppCurrency.eur.symbol, equals('€'));
      expect(AppCurrency.eur.displayName, equals('Euro'));

      expect(AppCurrency.gbp.code, equals('GBP'));
      expect(AppCurrency.gbp.symbol, equals('£'));
      expect(AppCurrency.gbp.displayName, equals('British Pound'));

      expect(AppCurrency.cad.code, equals('CAD'));
      expect(AppCurrency.cad.symbol, equals('CA\$'));
      expect(AppCurrency.cad.displayName, equals('Canadian Dollar'));
    });

    test('S1.2: AppCurrency.fromCode parses codes and names case-insensitively', () {
      expect(AppCurrency.fromCode('usd'), equals(AppCurrency.usd));
      expect(AppCurrency.fromCode('USD'), equals(AppCurrency.usd));
      expect(AppCurrency.fromCode('EUR'), equals(AppCurrency.eur));
      expect(AppCurrency.fromCode('eur'), equals(AppCurrency.eur));
      expect(AppCurrency.fromCode('gbp'), equals(AppCurrency.gbp));
      expect(AppCurrency.fromCode('GBP'), equals(AppCurrency.gbp));
      expect(AppCurrency.fromCode('Cad'), equals(AppCurrency.cad));
      expect(AppCurrency.fromCode('cad'), equals(AppCurrency.cad));
      expect(AppCurrency.fromCode(' CAD '), equals(AppCurrency.cad));
      expect(AppCurrency.fromCode('invalid'), equals(AppCurrency.usd));
      expect(AppCurrency.fromCode(''), equals(AppCurrency.usd));
      expect(AppCurrency.fromCode('   '), equals(AppCurrency.usd));
      expect(AppCurrency.fromCode(null), equals(AppCurrency.usd));
    });

    test('S1.3: settings_state Riverpod providers initialize with correct defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(baseCurrencyProvider), equals(AppCurrency.usd));
      expect(container.read(privacyModeProvider), isFalse);
      expect(container.read(streamerSecurityEnabledProvider), isFalse);
    });

    test('S1.4: settings_state Riverpod providers mutate state reactively', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(baseCurrencyProvider.notifier).state = AppCurrency.eur;
      expect(container.read(baseCurrencyProvider), equals(AppCurrency.eur));

      container.read(privacyModeProvider.notifier).state = true;
      expect(container.read(privacyModeProvider), isTrue);

      container.read(streamerSecurityEnabledProvider.notifier).state = true;
      expect(container.read(streamerSecurityEnabledProvider), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

void main() {
  group('VaultPricingHelper - M1 Currency & Privacy Extensions', () {
    group('formatAmount', () {
      test('redacts to privacyMask when isPrivacyMode is true', () {
        expect(
          VaultPricingHelper.formatAmount(
            150.75,
            currency: AppCurrency.usd,
            isPrivacyMode: true,
          ),
          '****',
        );

        expect(
          VaultPricingHelper.formatAmount(
            -50.0,
            currency: AppCurrency.eur,
            isPrivacyMode: true,
          ),
          '****',
        );

        expect(
          VaultPricingHelper.formatAmount(
            null,
            currency: AppCurrency.gbp,
            isPrivacyMode: true,
          ),
          '****',
        );
      });

      test('formats positive amounts with correct currency symbols', () {
        expect(
          VaultPricingHelper.formatAmount(12.50, currency: AppCurrency.usd, isPrivacyMode: false),
          r'$12.50',
        );
        expect(
          VaultPricingHelper.formatAmount(12.50, currency: AppCurrency.eur, isPrivacyMode: false),
          '€12.50',
        );
        expect(
          VaultPricingHelper.formatAmount(12.50, currency: AppCurrency.gbp, isPrivacyMode: false),
          '£12.50',
        );
        expect(
          VaultPricingHelper.formatAmount(12.50, currency: AppCurrency.cad, isPrivacyMode: false),
          r'CA$12.50',
        );
      });

      test('formats negative amounts with minus sign before currency symbol', () {
        expect(
          VaultPricingHelper.formatAmount(-12.50, currency: AppCurrency.usd, isPrivacyMode: false),
          r'-$12.50',
        );
        expect(
          VaultPricingHelper.formatAmount(-12.50, currency: AppCurrency.eur, isPrivacyMode: false),
          '-€12.50',
        );
      });

      test('handles zero amounts according to allowZero flag', () {
        expect(
          VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.usd, isPrivacyMode: false, allowZero: false),
          'Unlisted',
        );
        expect(
          VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.usd, isPrivacyMode: false, allowZero: true),
          r'$0.00',
        );
      });

      test('handles null, NaN, and infinity with fallback', () {
        expect(
          VaultPricingHelper.formatAmount(null, currency: AppCurrency.usd, isPrivacyMode: false),
          'Unlisted',
        );
        expect(
          VaultPricingHelper.formatAmount(double.nan, currency: AppCurrency.usd, isPrivacyMode: false),
          'Unlisted',
        );
        expect(
          VaultPricingHelper.formatAmount(double.infinity, currency: AppCurrency.usd, isPrivacyMode: false, fallback: 'N/A'),
          'N/A',
        );
      });
    });

    group('formatReturn', () {
      test('redacts return to privacyMask when isPrivacyMode is true', () {
        expect(
          VaultPricingHelper.formatReturn(
            15.0,
            25.0,
            currency: AppCurrency.usd,
            isPrivacyMode: true,
          ),
          '****',
        );
      });

      test('formats positive delta and percentage with amountFirst = true', () {
        final formatted = VaultPricingHelper.formatReturn(
          12.50,
          25.0,
          currency: AppCurrency.usd,
          isPrivacyMode: false,
          amountFirst: true,
        );
        expect(formatted, r'+$12.50 (+25.0%)');
      });

      test('formats negative delta and percentage with amountFirst = false', () {
        final formatted = VaultPricingHelper.formatReturn(
          -5.00,
          -10.0,
          currency: AppCurrency.eur,
          isPrivacyMode: false,
          amountFirst: false,
        );
        expect(formatted, '-10.0% (-€5.00)');
      });

      test('formats zero delta and percentage correctly', () {
        final formatted = VaultPricingHelper.formatReturn(
          0.0,
          0.0,
          currency: AppCurrency.usd,
          isPrivacyMode: false,
        );
        expect(formatted, r'+$0.00 (+0.0%)');
      });

      test('formats percentage-only and delta-only returns', () {
        expect(
          VaultPricingHelper.formatReturn(
            null,
            18.5,
            currency: AppCurrency.usd,
            isPrivacyMode: false,
          ),
          '+18.5%',
        );

        expect(
          VaultPricingHelper.formatReturn(
            -7.25,
            null,
            currency: AppCurrency.gbp,
            isPrivacyMode: false,
          ),
          '-£7.25',
        );
      });

      test('returns fallback if both delta and percentage are null or invalid', () {
        expect(
          VaultPricingHelper.formatReturn(
            null,
            null,
            currency: AppCurrency.usd,
            isPrivacyMode: false,
          ),
          '—',
        );

        expect(
          VaultPricingHelper.formatReturn(
            double.nan,
            double.infinity,
            currency: AppCurrency.usd,
            isPrivacyMode: false,
            fallback: 'Unknown',
          ),
          'Unknown',
        );
      });
    });

    group('Upgraded Formatters & Backward Compatibility', () {
      test('formatMarketPriceLabel works with legacy call pattern', () {
        expect(VaultPricingHelper.formatMarketPriceLabel(24.99), r'$24.99');
        expect(VaultPricingHelper.formatMarketPriceLabel(0.0), 'Unlisted');
      });

      test('formatMarketPriceLabel respects currency and isPrivacyMode', () {
        expect(
          VaultPricingHelper.formatMarketPriceLabel(
            24.99,
            currency: AppCurrency.eur,
            isPrivacyMode: false,
          ),
          '€24.99',
        );

        expect(
          VaultPricingHelper.formatMarketPriceLabel(
            24.99,
            currency: AppCurrency.eur,
            isPrivacyMode: true,
          ),
          '****',
        );
      });

      test('formatMarketHeaderLabel respects currency and isPrivacyMode', () {
        expect(
          VaultPricingHelper.formatMarketHeaderLabel(15.00),
          r'Market: $15.00',
        );

        expect(
          VaultPricingHelper.formatMarketHeaderLabel(
            15.00,
            currency: AppCurrency.cad,
            isPrivacyMode: false,
          ),
          r'Market: CA$15.00',
        );

        expect(
          VaultPricingHelper.formatMarketHeaderLabel(
            15.00,
            currency: AppCurrency.cad,
            isPrivacyMode: true,
          ),
          'Market: ****',
        );
      });
    });

    group('VaultItemPricing Extension', () {
      test('extension methods support currency and privacy mode', () {
        final item = VaultItem(
          id: 'vault-1',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          imageUrl: 'https://example.com/lotus.jpg',
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false, isDeleted: false,
          acquiredPrice: 40000.0,
          acquiredDate: DateTime.now(),
          currentMarketPrice: 50000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        );

        expect(
          item.formatMarketPrice(currency: AppCurrency.usd, isPrivacyMode: false),
          r'$50000.00',
        );
        expect(
          item.formatMarketPrice(currency: AppCurrency.usd, isPrivacyMode: true),
          '****',
        );
        expect(
          item.formatMarketHeader(currency: AppCurrency.eur, isPrivacyMode: false),
          'Market: €50000.00',
        );
        expect(
          item.formatMarketHeader(currency: AppCurrency.eur, isPrivacyMode: true),
          'Market: ****',
        );
        expect(
          item.formatAmount(currency: AppCurrency.gbp, isPrivacyMode: true),
          '****',
        );
      });
    });
  });
}

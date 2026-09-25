import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/values/domain/models/market_price_quote.dart';

/// Tabular comparison across vendors with retail, buylist, and spread metrics.
class MarketSpreadTableWidget extends ConsumerWidget {
  /// Structured spread summary model.
  final MarketSpreadSummary? summary;

  /// Explicit list of quotes to display.
  final List<MarketPriceQuote>? quotes;

  /// Baseline retail price to construct mock spreads if quotes are absent.
  final double? baselinePrice;

  /// Display currency.
  final AppCurrency? currency;

  /// Explicit privacy mode toggle.
  final bool? isPrivacyMode;

  const MarketSpreadTableWidget({
    super.key,
    this.summary,
    this.quotes,
    this.baselinePrice,
    this.currency,
    this.isPrivacyMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCurrency activeCurrency = currency ?? ref.watch(baseCurrencyProvider);
    final bool activePrivacy = isPrivacyMode ?? ref.watch(privacyModeProvider);

    final List<MarketPriceQuote> activeQuotes;
    if (summary != null) {
      activeQuotes = summary!.quotes;
    } else if (quotes != null && quotes!.isNotEmpty) {
      activeQuotes = quotes!;
    } else {
      // Deterministic synthetic quotes derived from baseline price
      final base = baselinePrice ?? 15.0;
      activeQuotes = [
        MarketPriceQuote(
          vendor: 'TCGplayer',
          quoteType: MarketQuoteType.retail,
          rawAmount: base,
          currency: AppCurrency.usd,
          convertedAmount: base,
          baseCurrency: activeCurrency,
          timestamp: DateTime.now(),
        ),
        MarketPriceQuote(
          vendor: 'Cardmarket',
          quoteType: MarketQuoteType.retail,
          rawAmount: base * 0.92,
          currency: AppCurrency.eur,
          convertedAmount: base * 0.96, // Slightly cheaper in Europe
          baseCurrency: activeCurrency,
          timestamp: DateTime.now(),
        ),
        MarketPriceQuote(
          vendor: 'eBay Recent',
          quoteType: MarketQuoteType.retail,
          rawAmount: base * 0.98,
          currency: AppCurrency.usd,
          convertedAmount: base * 0.98,
          baseCurrency: activeCurrency,
          timestamp: DateTime.now(),
        ),
        MarketPriceQuote(
          vendor: 'Card Kingdom',
          quoteType: MarketQuoteType.retail,
          rawAmount: base * 1.08,
          currency: AppCurrency.usd,
          convertedAmount: base * 1.08,
          baseCurrency: activeCurrency,
          timestamp: DateTime.now(),
        ),
        MarketPriceQuote(
          vendor: 'Manapool',
          quoteType: MarketQuoteType.retail,
          rawAmount: base * 0.97,
          currency: AppCurrency.usd,
          convertedAmount: base * 0.97,
          baseCurrency: activeCurrency,
          timestamp: DateTime.now(),
        ),
      ];
    }

    // Determine lowest retail and highest buylist
    double? minRetail;
    double? maxBuylist;
    String? lowestRetailVendor;
    String? highestBuylistVendor;

    for (final q in activeQuotes) {
      final retail = q.convertedAmount;
      final buylist = q.convertedAmount * 0.65; // Standard haircut estimate if single quote

      if (minRetail == null || retail < minRetail) {
        minRetail = retail;
        lowestRetailVendor = q.vendor;
      }
      if (maxBuylist == null || buylist > maxBuylist) {
        maxBuylist = buylist;
        highestBuylistVendor = q.vendor;
      }
    }

    return Container(
      key: const Key('market_spread_table_widget'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Title
          Row(
            children: [
              const Icon(
                Icons.table_chart_outlined,
                size: 16,
                color: AppColors.accentCyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Market Price Spreads',
                  style: AppTypography.heading2.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Raw quotes normalized to your portfolio currency.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),

          const SizedBox(height: 14),

          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'VENDOR',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RETAIL',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'BUYLIST',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SPREAD',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Vendor Rows
          for (final q in activeQuotes) ...[
            _buildVendorRow(
              quote: q,
              isLowestRetail: q.vendor == lowestRetailVendor,
              isHighestBuylist: q.vendor == highestBuylistVendor,
              currency: activeCurrency,
              isPrivacyMode: activePrivacy,
            ),
            const Divider(color: AppColors.surfaceBorderSubtle, height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorRow({
    required MarketPriceQuote quote,
    required bool isLowestRetail,
    required bool isHighestBuylist,
    required AppCurrency currency,
    required bool isPrivacyMode,
  }) {
    final retail = quote.convertedAmount;
    final buylist = quote.convertedAmount * 0.65;
    final spread = retail - buylist;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          // Vendor Name & Highlights
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.vendor,
                  key: Key('vendor_name_${quote.vendor}'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isLowestRetail) ...[
                  const SizedBox(height: 2),
                  Container(
                    key: Key('lowest_retail_badge_${quote.vendor}'),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'LOWEST RETAIL',
                      style: TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (isHighestBuylist && !isLowestRetail) ...[
                  const SizedBox(height: 2),
                  Container(
                    key: Key('highest_buylist_badge_${quote.vendor}'),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'HIGHEST BUYLIST',
                      style: TextStyle(
                        color: AppColors.accentEmerald,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Retail Price
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                VaultPricingHelper.formatAmount(
                  retail,
                  currency: currency,
                  isPrivacyMode: isPrivacyMode,
                  allowZero: true,
                ),
                key: Key('vendor_retail_${quote.vendor}'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Buylist Price
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                VaultPricingHelper.formatAmount(
                  buylist,
                  currency: currency,
                  isPrivacyMode: isPrivacyMode,
                  allowZero: true,
                ),
                key: Key('vendor_buylist_${quote.vendor}'),
                style: const TextStyle(
                  color: AppColors.accentAmber,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Spread ($ / %)
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                isPrivacyMode
                    ? '****'
                    : '-${VaultPricingHelper.formatAmount(spread, currency: currency, isPrivacyMode: false, allowZero: true)}',
                key: Key('vendor_spread_${quote.vendor}'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

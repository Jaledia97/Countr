import 'package:flutter/foundation.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Represents a single heavy hitter card within a deck's Pareto value concentration.
@immutable
class DeckHeavyHitter {
  final int rank; // 1..5
  final String vaultItemId;
  final String cardName;
  final String setCode;
  final String? imageUrl;
  final String? artCropUrl;
  final int quantity;
  final double unitPrice;
  final double lineValue;
  final double shareOfTotal; // e.g. 28.5%

  const DeckHeavyHitter({
    required this.rank,
    required this.vaultItemId,
    required this.cardName,
    required this.setCode,
    this.imageUrl,
    this.artCropUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineValue,
    required this.shareOfTotal,
  });

  String get effectiveImageUrl {
    if (artCropUrl != null && artCropUrl!.trim().isNotEmpty) {
      return artCropUrl!.trim();
    }
    return imageUrl?.trim() ?? '';
  }

  String formatLineValue({
    required AppCurrency currency,
    required bool isPrivacyMode,
  }) {
    return VaultPricingHelper.formatAmount(
      lineValue,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      allowZero: true,
    );
  }

  String formatUnitPrice({
    required AppCurrency currency,
    required bool isPrivacyMode,
  }) {
    return VaultPricingHelper.formatAmount(
      unitPrice,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      allowZero: true,
    );
  }

  String formatShare({required bool isPrivacyMode}) {
    if (isPrivacyMode) return '****';
    return '${shareOfTotal.toStringAsFixed(1)}%';
  }
}

/// Comprehensive financial summary of a deck, including market value, cost basis,
/// P&L returns, and Pareto value concentration.
@immutable
class DeckFinancialSummary {
  final String deckId;
  final double totalMarketValue;
  final double totalCostBasis;
  final double dollarReturn;
  final double percentageReturn;
  final int totalCardCount;
  final int uniqueCardCount;
  final AppCurrency currency;
  final bool isProfit;
  final bool isLoss;
  final bool isNeutral;
  final double paretoConcentration;
  final String paretoHeadline;
  final List<DeckHeavyHitter> heavyHitters;

  const DeckFinancialSummary({
    required this.deckId,
    required this.totalMarketValue,
    required this.totalCostBasis,
    required this.dollarReturn,
    required this.percentageReturn,
    required this.totalCardCount,
    required this.uniqueCardCount,
    required this.currency,
    required this.isProfit,
    required this.isLoss,
    required this.isNeutral,
    required this.paretoConcentration,
    required this.paretoHeadline,
    required this.heavyHitters,
  });

  factory DeckFinancialSummary.zero({
    required String deckId,
    required AppCurrency currency,
  }) {
    return DeckFinancialSummary(
      deckId: deckId,
      totalMarketValue: 0.0,
      totalCostBasis: 0.0,
      dollarReturn: 0.0,
      percentageReturn: 0.0,
      totalCardCount: 0,
      uniqueCardCount: 0,
      currency: currency,
      isProfit: false,
      isLoss: false,
      isNeutral: true,
      paretoConcentration: 0.0,
      paretoHeadline: "No cards in deck to calculate concentration.",
      heavyHitters: const [],
    );
  }

  String formatMarketValue({required bool isPrivacyMode}) {
    return VaultPricingHelper.formatAmount(
      totalMarketValue,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      allowZero: true,
    );
  }

  String formatCostBasis({required bool isPrivacyMode}) {
    return VaultPricingHelper.formatAmount(
      totalCostBasis,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      allowZero: true,
    );
  }

  String formatReturn({
    required bool isPrivacyMode,
    bool amountFirst = true,
  }) {
    return VaultPricingHelper.formatReturn(
      dollarReturn,
      percentageReturn,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      amountFirst: amountFirst,
    );
  }

  String getHeadline({bool isPrivacyMode = false}) {
    if (uniqueCardCount == 0) {
      return 'No cards in deck to calculate concentration.';
    }
    final pctStr = isPrivacyMode
        ? '****'
        : '${paretoConcentration.toStringAsFixed(1)}%';

    final k = heavyHitters.length;
    if (k == 1) {
      return "The top card represents $pctStr of this deck's total value.";
    }
    return "The top $k cards represent $pctStr of this deck's total value.";
  }
}

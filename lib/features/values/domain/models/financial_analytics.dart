import 'package:flutter/foundation.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Classification tag for market liquidity.
enum LiquidityTag {
  high('HIGH'),
  moderate('MODERATE'),
  low('LOW');

  final String label;
  const LiquidityTag(this.label);
}

/// Comprehensive Profit and Loss (P&L) calculation result model.
@immutable
class PnLResult {
  /// Total cost basis ($P_{acq} \times \text{quantity}$).
  final double costBasis;

  /// Total current market valuation ($\bar{P}_{trimmed} \times \text{quantity}$).
  final double marketValue;

  /// Absolute net dollar return in base currency ($V_{market} - C_{basis}$).
  final double dollarReturn;

  /// Relative percentage return $( (V_{market} - C_{basis}) / C_{basis} ) \times 100$.
  /// Set strictly to 0.0 when costBasis is 0.0 or negative to prevent division by zero.
  final double percentageReturn;

  /// Acquisition cost per single unit.
  final double unitCostBasis;

  /// Current market price per single unit.
  final double unitMarketPrice;

  /// Physical card quantity owned.
  final int quantity;

  /// Active base currency for formatted display.
  final AppCurrency currency;

  /// True if net return is strictly positive (> 0.0).
  final bool isProfit;

  /// True if net return is strictly negative (< 0.0).
  final bool isLoss;

  /// True if net return is break-even (== 0.0).
  final bool isNeutral;

  const PnLResult({
    required this.costBasis,
    required this.marketValue,
    required this.dollarReturn,
    required this.percentageReturn,
    required this.unitCostBasis,
    required this.unitMarketPrice,
    required this.quantity,
    required this.currency,
    required this.isProfit,
    required this.isLoss,
    required this.isNeutral,
  });

  /// Factory computing P&L with strict division-by-zero defense and quantity scaling.
  factory PnLResult.calculate({
    required double costBasisPerUnit,
    required double marketPricePerUnit,
    int quantity = 1,
    required AppCurrency currency,
  }) {
    final validQty = quantity > 0 ? quantity : 1;
    final cleanCost = (costBasisPerUnit.isNaN || costBasisPerUnit.isInfinite || costBasisPerUnit < 0.0)
        ? 0.0
        : costBasisPerUnit;
    final cleanMarket = (marketPricePerUnit.isNaN || marketPricePerUnit.isInfinite || marketPricePerUnit < 0.0)
        ? 0.0
        : marketPricePerUnit;

    final totalCost = cleanCost * validQty;
    final totalMarket = cleanMarket * validQty;
    final delta = totalMarket - totalCost;

    final double pct;
    if (totalCost > 0.0) {
      pct = (delta / totalCost) * 100.0;
    } else {
      pct = 0.0;
    }

    return PnLResult(
      costBasis: totalCost,
      marketValue: totalMarket,
      dollarReturn: delta,
      percentageReturn: pct,
      unitCostBasis: cleanCost,
      unitMarketPrice: cleanMarket,
      quantity: validQty,
      currency: currency,
      isProfit: delta > 0.0,
      isLoss: delta < 0.0,
      isNeutral: delta == 0.0,
    );
  }

  /// Formatted return string with dynamic currency symbol and privacy mask support.
  String formatReturn({required bool isPrivacyMode, bool amountFirst = true}) {
    return VaultPricingHelper.formatReturn(
      dollarReturn,
      percentageReturn,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      amountFirst: amountFirst,
    );
  }

  /// JSON serialization.
  Map<String, dynamic> toJson() => {
        'cost_basis': costBasis,
        'market_value': marketValue,
        'dollar_return': dollarReturn,
        'percentage_return': percentageReturn,
        'unit_cost_basis': unitCostBasis,
        'unit_market_price': unitMarketPrice,
        'quantity': quantity,
        'currency': currency.code,
        'is_profit': isProfit,
        'is_loss': isLoss,
        'is_neutral': isNeutral,
      };

  /// JSON deserialization.
  factory PnLResult.fromJson(Map<String, dynamic> json) {
    return PnLResult(
      costBasis: (json['cost_basis'] as num?)?.toDouble() ?? 0.0,
      marketValue: (json['market_value'] as num?)?.toDouble() ?? 0.0,
      dollarReturn: (json['dollar_return'] as num?)?.toDouble() ?? 0.0,
      percentageReturn: (json['percentage_return'] as num?)?.toDouble() ?? 0.0,
      unitCostBasis: (json['unit_cost_basis'] as num?)?.toDouble() ?? 0.0,
      unitMarketPrice: (json['unit_market_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      currency: AppCurrency.fromCode(json['currency']?.toString()),
      isProfit: json['is_profit'] as bool? ?? false,
      isLoss: json['is_loss'] as bool? ?? false,
      isNeutral: json['is_neutral'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PnLResult &&
          runtimeType == other.runtimeType &&
          costBasis == other.costBasis &&
          marketValue == other.marketValue &&
          dollarReturn == other.dollarReturn &&
          percentageReturn == other.percentageReturn &&
          unitCostBasis == other.unitCostBasis &&
          unitMarketPrice == other.unitMarketPrice &&
          quantity == other.quantity &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(
        costBasis,
        marketValue,
        dollarReturn,
        percentageReturn,
        unitCostBasis,
        unitMarketPrice,
        quantity,
        currency,
      );
}

/// 52-week price range horizontal gauge model.
@immutable
class FiftyTwoWeekRange {
  /// The lowest price recorded over the past 52 weeks.
  final double low52;

  /// The highest price recorded over the past 52 weeks.
  final double high52;

  /// The current market price.
  final double currentPrice;

  /// Normalized position of currentPrice between [low52] and [high52], clamped to [0.0..1.0].
  final double rangePosition;

  /// Active base currency for formatted display.
  final AppCurrency currency;

  const FiftyTwoWeekRange({
    required this.low52,
    required this.high52,
    required this.currentPrice,
    required this.rangePosition,
    required this.currency,
  });

  /// Factory computing normalized position with boundary checks.
  factory FiftyTwoWeekRange.calculate({
    required double low52,
    required double high52,
    required double currentPrice,
    required AppCurrency currency,
  }) {
    final cleanLow = (low52.isNaN || low52.isInfinite || low52 < 0.0) ? 0.0 : low52;
    final cleanHigh = (high52.isNaN || high52.isInfinite || high52 < cleanLow) ? cleanLow : high52;
    final cleanCurrent = (currentPrice.isNaN || currentPrice.isInfinite || currentPrice < 0.0) ? cleanLow : currentPrice;

    final rangeSpan = cleanHigh - cleanLow;
    final double position;
    if (rangeSpan <= 0.0) {
      position = 0.5; // Neutral midpoint when high equals low
    } else {
      position = ((cleanCurrent - cleanLow) / rangeSpan).clamp(0.0, 1.0);
    }

    return FiftyTwoWeekRange(
      low52: cleanLow,
      high52: cleanHigh,
      currentPrice: cleanCurrent,
      rangePosition: position,
      currency: currency,
    );
  }

  /// String formatted percentile label (e.g. "75%").
  String get percentileLabel => '${(rangePosition * 100.0).toStringAsFixed(0)}%';

  /// JSON serialization.
  Map<String, dynamic> toJson() => {
        'low_52': low52,
        'high_52': high52,
        'current_price': currentPrice,
        'range_position': rangePosition,
        'currency': currency.code,
      };

  /// JSON deserialization.
  factory FiftyTwoWeekRange.fromJson(Map<String, dynamic> json) {
    return FiftyTwoWeekRange(
      low52: (json['low_52'] as num?)?.toDouble() ?? 0.0,
      high52: (json['high_52'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      rangePosition: (json['range_position'] as num?)?.toDouble() ?? 0.5,
      currency: AppCurrency.fromCode(json['currency']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiftyTwoWeekRange &&
          runtimeType == other.runtimeType &&
          low52 == other.low52 &&
          high52 == other.high52 &&
          currentPrice == other.currentPrice &&
          rangePosition == other.rangePosition &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(low52, high52, currentPrice, rangePosition, currency);
}

/// Liquidity and Reality Check analytics model.
@immutable
class LiquidityAnalysis {
  /// Total cost to replace the card from retail stores ($V_{replacement}$).
  final double replacementValue;

  /// Estimated instant cash out buylist liquidation value ($V_{cash\_out}$).
  final double cashOutValue;

  /// Cash realization rate percentage ($V_{cash\_out} / V_{replacement} \times 100$).
  final double realizationRate;

  /// Qualitative liquidity tag (High, Moderate, Low).
  final LiquidityTag liquidityTag;

  /// Whether the card is on WotC's official Reserved List reprint policy.
  final bool isReservedList;

  /// Active base currency for formatted display.
  final AppCurrency currency;

  const LiquidityAnalysis({
    required this.replacementValue,
    required this.cashOutValue,
    required this.realizationRate,
    required this.liquidityTag,
    required this.isReservedList,
    required this.currency,
  });

  /// Factory computing liquidity haircuts using institutional pricing tiers.
  ///
  /// Tier Ratios:
  /// - Market >= $50.00: 70% buylist cash-out ratio (high-value staple)
  /// - $10.00 <= Market < $50.00: 60% buylist cash-out ratio
  /// - $2.00 <= Market < $10.00: 45% buylist cash-out ratio
  /// - Market < $2.00: 25% buylist cash-out ratio (bulk tier)
  factory LiquidityAnalysis.calculate({
    required double marketPrice,
    int quantity = 1,
    required AppCurrency currency,
    bool isReservedList = false,
    double? explicitBuylistPrice,
  }) {
    final validQty = quantity > 0 ? quantity : 1;
    final cleanPrice = (marketPrice.isNaN || marketPrice.isInfinite || marketPrice < 0.0) ? 0.0 : marketPrice;
    final replacement = cleanPrice * validQty;

    final double cashOut;
    if (explicitBuylistPrice != null && explicitBuylistPrice > 0.0) {
      cashOut = explicitBuylistPrice * validQty;
    } else {
      final double ratio;
      if (cleanPrice >= 50.0) {
        ratio = 0.70;
      } else if (cleanPrice >= 10.0) {
        ratio = 0.60;
      } else if (cleanPrice >= 2.0) {
        ratio = 0.45;
      } else {
        ratio = 0.25;
      }
      cashOut = cleanPrice * ratio * validQty;
    }

    final double rate = (replacement > 0.0) ? (cashOut / replacement) * 100.0 : 0.0;

    // Evaluates Liquidity Tag: High if market >= 5.0, Moderate if market >= 2.0, else Low
    final LiquidityTag tag;
    if (cleanPrice >= 5.0) {
      tag = LiquidityTag.high;
    } else if (cleanPrice >= 2.0) {
      tag = LiquidityTag.moderate;
    } else {
      tag = LiquidityTag.low;
    }

    return LiquidityAnalysis(
      replacementValue: replacement,
      cashOutValue: cashOut,
      realizationRate: rate,
      liquidityTag: tag,
      isReservedList: isReservedList,
      currency: currency,
    );
  }

  /// JSON serialization.
  Map<String, dynamic> toJson() => {
        'replacement_value': replacementValue,
        'cash_out_value': cashOutValue,
        'realization_rate': realizationRate,
        'liquidity_tag': liquidityTag.name,
        'is_reserved_list': isReservedList,
        'currency': currency.code,
      };

  /// JSON deserialization.
  factory LiquidityAnalysis.fromJson(Map<String, dynamic> json) {
    return LiquidityAnalysis(
      replacementValue: (json['replacement_value'] as num?)?.toDouble() ?? 0.0,
      cashOutValue: (json['cash_out_value'] as num?)?.toDouble() ?? 0.0,
      realizationRate: (json['realization_rate'] as num?)?.toDouble() ?? 0.0,
      liquidityTag: LiquidityTag.values.firstWhere(
        (t) => t.name == json['liquidity_tag'],
        orElse: () => LiquidityTag.moderate,
      ),
      isReservedList: json['is_reserved_list'] as bool? ?? false,
      currency: AppCurrency.fromCode(json['currency']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidityAnalysis &&
          runtimeType == other.runtimeType &&
          replacementValue == other.replacementValue &&
          cashOutValue == other.cashOutValue &&
          realizationRate == other.realizationRate &&
          liquidityTag == other.liquidityTag &&
          isReservedList == other.isReservedList &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(
        replacementValue,
        cashOutValue,
        realizationRate,
        liquidityTag,
        isReservedList,
        currency,
      );
}

/// Condition and treatment pricing grid model (3x3 Matrix).
@immutable
class ConditionTreatmentMatrix {
  final Map<String, Map<String, double>> matrix; // condition -> {finish: price}
  final AppCurrency currency;

  const ConditionTreatmentMatrix({
    required this.matrix,
    required this.currency,
  });

  /// Factory computing condition degradation haircuts against baseline NM prices.
  factory ConditionTreatmentMatrix.compute({
    required double baseNonFoil,
    required double baseFoil,
    required double baseEtched,
    required AppCurrency currency,
  }) {
    final cleanNonFoil = baseNonFoil > 0 ? baseNonFoil : 0.0;
    final cleanFoil = baseFoil > 0 ? baseFoil : (cleanNonFoil * 1.4);
    final cleanEtched = baseEtched > 0 ? baseEtched : (cleanFoil * 1.1);

    return ConditionTreatmentMatrix(
      matrix: {
        'NM': {
          'non_foil': cleanNonFoil,
          'foil': cleanFoil,
          'etched': cleanEtched,
        },
        'LP': {
          'non_foil': cleanNonFoil * 0.88,
          'foil': cleanFoil * 0.85,
          'etched': cleanEtched * 0.85,
        },
        'MP': {
          'non_foil': cleanNonFoil * 0.72,
          'foil': cleanFoil * 0.70,
          'etched': cleanEtched * 0.70,
        },
      },
      currency: currency,
    );
  }

  double getPrice(String condition, String finish) {
    final condKey = condition.toUpperCase().trim();
    final finishKey = finish.toLowerCase().trim();
    return matrix[condKey]?[finishKey] ?? 0.0;
  }

  /// JSON serialization.
  Map<String, dynamic> toJson() => {
        'matrix': matrix,
        'currency': currency.code,
      };

  /// JSON deserialization.
  factory ConditionTreatmentMatrix.fromJson(Map<String, dynamic> json) {
    final rawMatrix = json['matrix'] as Map<String, dynamic>? ?? {};
    final parsedMatrix = <String, Map<String, double>>{};
    rawMatrix.forEach((k, v) {
      if (v is Map) {
        final innerMap = <String, double>{};
        v.forEach((ik, iv) {
          innerMap[ik.toString()] = (iv as num?)?.toDouble() ?? 0.0;
        });
        parsedMatrix[k] = innerMap;
      }
    });

    return ConditionTreatmentMatrix(
      matrix: parsedMatrix,
      currency: AppCurrency.fromCode(json['currency']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConditionTreatmentMatrix &&
          runtimeType == other.runtimeType &&
          mapEquals(matrix['NM'], other.matrix['NM']) &&
          mapEquals(matrix['LP'], other.matrix['LP']) &&
          mapEquals(matrix['MP'], other.matrix['MP']) &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(matrix, currency);
}

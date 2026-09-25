import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Represents a single ranked card in the deck's Pareto value distribution.
@immutable
class ParetoItem {
  /// Rank position in the deck (#1, #2, #3, etc.).
  final int rank;

  /// Vault item unique ID or card identifier.
  final String id;

  /// Card name (e.g. "Edgar Markov").
  final String name;

  /// Set or expansion code (e.g. "CMM", "MH2").
  final String setCode;

  /// Quantity allocated in the deck (q_i >= 1).
  final int quantity;

  /// Single-unit market valuation in active base currency (p_i).
  final double unitPrice;

  /// Total line valuation in base currency (w_i = p_i * quantity).
  final double lineValue;

  /// Percentage of total deck valuation contributed by this card (share_i).
  final double percentageShare;

  /// Normalized deck weight ratio in [0.0..1.0] driving the visual horizontal bar.
  final double weightRatio;

  /// Direct card image URL.
  final String imageUrl;

  /// Dedicated art crop image URL (derived from Scryfall dynamicData).
  final String? artCropUrl;

  const ParetoItem({
    required this.rank,
    required this.id,
    required this.name,
    required this.setCode,
    required this.quantity,
    required this.unitPrice,
    required this.lineValue,
    required this.percentageShare,
    required this.weightRatio,
    required this.imageUrl,
    this.artCropUrl,
  });

  /// Formatted metadata subtitle (e.g. "CMM · 1x").
  String get subtitle {
    final cleanSet = setCode.toUpperCase().trim();
    if (cleanSet.isEmpty) {
      return '${quantity}x';
    }
    return '$cleanSet · ${quantity}x';
  }

  /// Resolved effective art crop or image url.
  String get effectiveImageUrl =>
      (artCropUrl != null && artCropUrl!.trim().isNotEmpty)
          ? artCropUrl!.trim()
          : imageUrl.trim();

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'id': id,
        'name': name,
        'set_code': setCode,
        'quantity': quantity,
        'unit_price': unitPrice,
        'line_value': lineValue,
        'percentage_share': percentageShare,
        'weight_ratio': weightRatio,
        'image_url': imageUrl,
        'art_crop_url': artCropUrl,
      };

  factory ParetoItem.fromJson(Map<String, dynamic> json) => ParetoItem(
        rank: (json['rank'] as num?)?.toInt() ?? 1,
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        setCode: json['set_code']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
        lineValue: (json['line_value'] as num?)?.toDouble() ?? 0.0,
        percentageShare: (json['percentage_share'] as num?)?.toDouble() ?? 0.0,
        weightRatio: (json['weight_ratio'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['image_url']?.toString() ?? '',
        artCropUrl: json['art_crop_url']?.toString(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParetoItem &&
          runtimeType == other.runtimeType &&
          rank == other.rank &&
          id == other.id &&
          name == other.name &&
          setCode == other.setCode &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          lineValue == other.lineValue &&
          percentageShare == other.percentageShare &&
          weightRatio == other.weightRatio &&
          imageUrl == other.imageUrl &&
          artCropUrl == other.artCropUrl;

  @override
  int get hashCode => Object.hash(
        rank,
        id,
        name,
        setCode,
        quantity,
        unitPrice,
        lineValue,
        percentageShare,
        weightRatio,
        imageUrl,
        artCropUrl,
      );
}

/// Complete Pareto value concentration aggregate result.
@immutable
class ParetoDistributionResult {
  /// Total valuation of the entire deck (V_deck = sum(w_i)).
  final double totalDeckValue;

  /// Aggregate valuation of top K cards (W_topK = sum_{i=1}^K w_(i)).
  final double topCardsValue;

  /// Pareto concentration percentage (P_pareto = (W_topK / V_deck) * 100).
  final double concentrationPercentage;

  /// Total count of unique cards evaluated (M).
  final int totalUniqueCards;

  /// Total physical cards count (sum of all deck card quantities).
  final int totalCardCount;

  /// Top K count evaluated (min(targetK, M)).
  final int topK;

  /// Ranked micro-list of top cards sorted strictly descending by line value.
  final List<ParetoItem> topCards;

  /// Active base currency for formatted display.
  final AppCurrency currency;

  const ParetoDistributionResult({
    required this.totalDeckValue,
    required this.topCardsValue,
    required this.concentrationPercentage,
    required this.totalUniqueCards,
    required this.totalCardCount,
    required this.topK,
    required this.topCards,
    required this.currency,
  });

  /// True if deck has zero items or zero market value.
  bool get isEmpty => totalUniqueCards == 0 || totalDeckValue <= 0.0;

  /// Generates the authoritative headline banner text with grammatical pluralization
  /// and privacy masking support.
  ///
  /// Examples:
  /// - 0 cards: "No cards in deck to calculate concentration."
  /// - 1 card: "The top card represents 100.0% of this deck's total value."
  /// - 2 cards: "The top 2 cards represent 100.0% of this deck's total value."
  /// - 5 cards: "The top 5 cards represent 64.2% of this deck's total value."
  /// - Privacy active: "The top 5 cards represent **** of this deck's total value."
  String getHeadline({bool isPrivacyMode = false}) {
    if (totalUniqueCards == 0) {
      return 'No cards in deck to calculate concentration.';
    }
    final String pctStr = isPrivacyMode
        ? '****'
        : '${concentrationPercentage.toStringAsFixed(1)}%';

    if (topK == 1) {
      return "The top card represents $pctStr of this deck's total value.";
    }
    return "The top $topK cards represent $pctStr of this deck's total value.";
  }

  /// Empty fallback instance.
  factory ParetoDistributionResult.empty({AppCurrency currency = AppCurrency.usd}) {
    return ParetoDistributionResult(
      totalDeckValue: 0.0,
      topCardsValue: 0.0,
      concentrationPercentage: 0.0,
      totalUniqueCards: 0,
      totalCardCount: 0,
      topK: 0,
      topCards: const [],
      currency: currency,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_deck_value': totalDeckValue,
        'top_cards_value': topCardsValue,
        'concentration_percentage': concentrationPercentage,
        'total_unique_cards': totalUniqueCards,
        'total_card_count': totalCardCount,
        'top_k': topK,
        'top_cards': topCards.map((c) => c.toJson()).toList(),
        'currency': currency.code,
      };

  factory ParetoDistributionResult.fromJson(Map<String, dynamic> json) =>
      ParetoDistributionResult(
        totalDeckValue: (json['total_deck_value'] as num?)?.toDouble() ?? 0.0,
        topCardsValue: (json['top_cards_value'] as num?)?.toDouble() ?? 0.0,
        concentrationPercentage:
            (json['concentration_percentage'] as num?)?.toDouble() ?? 0.0,
        totalUniqueCards: (json['total_unique_cards'] as num?)?.toInt() ?? 0,
        totalCardCount: (json['total_card_count'] as num?)?.toInt() ?? 0,
        topK: (json['top_k'] as num?)?.toInt() ?? 0,
        topCards: (json['top_cards'] as List?)
                ?.map((e) => ParetoItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        currency: AppCurrency.fromCode(json['currency']?.toString()),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParetoDistributionResult &&
          runtimeType == other.runtimeType &&
          totalDeckValue == other.totalDeckValue &&
          topCardsValue == other.topCardsValue &&
          concentrationPercentage == other.concentrationPercentage &&
          totalUniqueCards == other.totalUniqueCards &&
          totalCardCount == other.totalCardCount &&
          topK == other.topK &&
          listEquals(topCards, other.topCards) &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(
        totalDeckValue,
        topCardsValue,
        concentrationPercentage,
        totalUniqueCards,
        totalCardCount,
        topK,
        Object.hashAll(topCards),
        currency,
      );
}

/// Normalized input item for Pareto distribution calculation.
class ParetoCardInput {
  final String id;
  final String name;
  final String setCode;
  final int quantity;
  final double unitPrice;
  final String imageUrl;
  final String? artCropUrl;

  const ParetoCardInput({
    required this.id,
    required this.name,
    this.setCode = '',
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.imageUrl = '',
    this.artCropUrl,
  });

  /// Factory adapting raw Drift query maps from `watchDeckItems(deckId)`.
  factory ParetoCardInput.fromDeckItemMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'Unknown Card';
    final id = map['vault_item_id']?.toString() ?? map['id']?.toString() ?? '';
    final qty = (map['deck_quantity'] as num?)?.toInt() ?? (map['quantity'] as num?)?.toInt() ?? 1;
    final directPrice = (map['current_market_price'] as num?)?.toDouble();
    final rawDyn = map['dynamic_data'];

    String setCode = map['set_or_series']?.toString() ?? '';
    String? artCrop;
    double? dynPrice;

    if (rawDyn != null) {
      try {
        final d = rawDyn is Map
            ? rawDyn
            : jsonDecode(rawDyn.toString()) as Map<String, dynamic>;

        if (setCode.isEmpty) {
          setCode = d['set_code']?.toString() ?? d['set']?.toString() ?? '';
        }

        // Extract art crop from image_uris or first face
        if (d['image_uris'] is Map) {
          artCrop = d['image_uris']['art_crop']?.toString();
        } else if (d['card_faces'] is List && (d['card_faces'] as List).isNotEmpty) {
          final f0 = (d['card_faces'] as List)[0];
          if (f0 is Map && f0['image_uris'] is Map) {
            artCrop = f0['image_uris']['art_crop']?.toString();
          }
        }

        // Fallback price extraction if direct price is null or non-positive
        if (directPrice == null || directPrice <= 0.0) {
          dynPrice = VaultPricingHelper.extractFromDynamicData(d);
        }
      } catch (_) {}
    }

    final effectivePrice = (directPrice != null && directPrice > 0.0)
        ? directPrice
        : (dynPrice ?? 0.0);

    return ParetoCardInput(
      id: id,
      name: name,
      setCode: setCode,
      quantity: qty,
      unitPrice: effectivePrice,
      imageUrl: map['image_url']?.toString() ?? '',
      artCropUrl: artCrop,
    );
  }

  /// Factory adapting [DeckItemWithCard].
  factory ParetoCardInput.fromDeckItemWithCard(
    DeckItemWithCard item,
    AppCurrency targetCurrency,
  ) {
    String? artCrop;
    if (item.dynamicData != null) {
      try {
        final d = jsonDecode(item.dynamicData!);
        if (d is Map) {
          if (d['image_uris'] is Map) {
            artCrop = d['image_uris']['art_crop']?.toString();
          } else if (d['card_faces'] is List && (d['card_faces'] as List).isNotEmpty) {
            final f0 = (d['card_faces'] as List)[0];
            if (f0 is Map && f0['image_uris'] is Map) {
              artCrop = f0['image_uris']['art_crop']?.toString();
            }
          }
        }
      } catch (_) {}
    }

    return ParetoCardInput(
      id: item.vaultItemId.isNotEmpty ? item.vaultItemId : item.id,
      name: item.name,
      setCode: item.setOrSeries,
      quantity: item.deckQuantity,
      unitPrice: item.resolveMarketPrice(targetCurrency),
      imageUrl: item.imageUrl ?? '',
      artCropUrl: artCrop,
    );
  }
}

/// Pure Dart service computing deck value concentration and ranked heavy hitters.
class ParetoDistributionCalculator {
  ParetoDistributionCalculator._();

  /// Calculates the complete [ParetoDistributionResult] for a list of [cards].
  static ParetoDistributionResult calculate({
    required List<ParetoCardInput> cards,
    int targetK = 5,
    AppCurrency currency = AppCurrency.usd,
  }) {
    if (cards.isEmpty) {
      return ParetoDistributionResult.empty(currency: currency);
    }

    // 1. Calculate sanitized line valuations and totals
    final evaluatedList = <_CleanedItem>[];
    double totalDeckVal = 0.0;
    int totalPhysicalCards = 0;

    for (final card in cards) {
      final cleanQty = card.quantity > 0 ? card.quantity : 1;
      final cleanPrice = (card.unitPrice.isNaN || card.unitPrice.isInfinite || card.unitPrice <= 0.0)
          ? 0.0
          : card.unitPrice;

      final lineVal = cleanPrice * cleanQty;
      totalDeckVal += lineVal;
      totalPhysicalCards += cleanQty;

      evaluatedList.add(
        _CleanedItem(
          input: card,
          cleanQuantity: cleanQty,
          cleanPrice: cleanPrice,
          lineValue: lineVal,
        ),
      );
    }

    // 2. Descending sort with deterministic tie-breaking
    // Primary: Line valuation descending
    // Secondary: Name ascending (case-insensitive)
    // Tertiary: Unit price descending
    evaluatedList.sort((a, b) {
      final compVal = b.lineValue.compareTo(a.lineValue);
      if (compVal != 0) return compVal;
      final compName = a.input.name.toLowerCase().compareTo(b.input.name.toLowerCase());
      if (compName != 0) return compName;
      return b.cleanPrice.compareTo(a.cleanPrice);
    });

    final totalUnique = evaluatedList.length;
    final int k = (totalUnique < targetK) ? totalUnique : targetK;

    // 3. Slice top K and compute concentration
    final topSlice = evaluatedList.take(k).toList();
    double topCardsSum = 0.0;
    for (final item in topSlice) {
      topCardsSum += item.lineValue;
    }

    final double concentration;
    if (totalDeckVal > 0.0 && !totalDeckVal.isNaN && !totalDeckVal.isInfinite) {
      concentration = ((topCardsSum / totalDeckVal) * 100.0).clamp(0.0, 100.0);
    } else {
      concentration = 0.0;
    }

    // 4. Build ParetoItem micro-list
    final rankedItems = <ParetoItem>[];
    for (int i = 0; i < topSlice.length; i++) {
      final item = topSlice[i];
      final double share;
      final double weightRatio;

      if (totalDeckVal > 0.0 && !totalDeckVal.isNaN && !totalDeckVal.isInfinite) {
        share = ((item.lineValue / totalDeckVal) * 100.0).clamp(0.0, 100.0);
        weightRatio = (item.lineValue / totalDeckVal).clamp(0.0, 1.0);
      } else {
        share = 0.0;
        weightRatio = 0.0;
      }

      rankedItems.add(
        ParetoItem(
          rank: i + 1,
          id: item.input.id,
          name: item.input.name,
          setCode: item.input.setCode,
          quantity: item.cleanQuantity,
          unitPrice: item.cleanPrice,
          lineValue: item.lineValue,
          percentageShare: share,
          weightRatio: weightRatio,
          imageUrl: item.input.imageUrl,
          artCropUrl: item.input.artCropUrl,
        ),
      );
    }

    return ParetoDistributionResult(
      totalDeckValue: totalDeckVal,
      topCardsValue: topCardsSum,
      concentrationPercentage: concentration,
      totalUniqueCards: totalUnique,
      totalCardCount: totalPhysicalCards,
      topK: k,
      topCards: rankedItems,
      currency: currency,
    );
  }
}

class _CleanedItem {
  final ParetoCardInput input;
  final int cleanQuantity;
  final double cleanPrice;
  final double lineValue;

  const _CleanedItem({
    required this.input,
    required this.cleanQuantity,
    required this.cleanPrice,
    required this.lineValue,
  });
}

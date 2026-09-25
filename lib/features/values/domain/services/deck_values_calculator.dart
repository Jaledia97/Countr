import 'dart:convert';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/values/domain/models/deck_financial_summary.dart';

/// Pure Dart service computing aggregate financial performance and Pareto concentration for decks.
class DeckValuesCalculator {
  DeckValuesCalculator._();

  /// Calculates the complete [DeckFinancialSummary] for a deck.
  ///
  /// Defends against:
  /// - Empty card lists (returns [DeckFinancialSummary.zero])
  /// - Division-by-zero when total cost basis is 0.0 (percentage return = 0.0%)
  /// - Negative or NaN price and cost values (sanitized to 0.0)
  /// - Deterministic tie-breaking across identically valued cards
  static DeckFinancialSummary calculate({
    required String deckId,
    required List<dynamic> items,
    required AppCurrency currency,
    Map<AppCurrency, double>? rates,
  }) {
    if (items.isEmpty) {
      return DeckFinancialSummary.zero(deckId: deckId, currency: currency);
    }

    final evaluatedCards = <_EvaluatedDeckCard>[];
    double totalMarket = 0.0;
    double totalCost = 0.0;
    int totalCards = 0;

    for (final raw in items) {
      final item = raw is DeckItemWithCard
          ? raw
          : (raw is Map<String, dynamic>
              ? DeckItemWithCard.fromRow(raw)
              : null);

      if (item == null) continue;

      final qty = item.deckQuantity > 0 ? item.deckQuantity : 1;
      final costBasisPerUnit = item.effectiveCostBasis;
      final marketPricePerUnit = item.resolveMarketPrice(currency);

      final lineMarket = (marketPricePerUnit.isNaN || marketPricePerUnit.isInfinite || marketPricePerUnit < 0.0)
          ? 0.0
          : (marketPricePerUnit * qty);
      final lineCost = (costBasisPerUnit.isNaN || costBasisPerUnit.isInfinite || costBasisPerUnit < 0.0)
          ? 0.0
          : (costBasisPerUnit * qty);

      totalMarket += lineMarket;
      totalCost += lineCost;
      totalCards += qty;

      final artCrop = _extractArtCrop(item.dynamicData);

      evaluatedCards.add(
        _EvaluatedDeckCard(
          id: item.vaultItemId.isNotEmpty ? item.vaultItemId : item.id,
          name: item.name,
          setCode: item.setOrSeries,
          imageUrl: item.imageUrl,
          artCropUrl: artCrop,
          quantity: qty,
          unitPrice: marketPricePerUnit,
          lineValue: lineMarket,
        ),
      );
    }

    final uniqueCount = evaluatedCards.length;
    if (uniqueCount == 0) {
      return DeckFinancialSummary.zero(deckId: deckId, currency: currency);
    }

    final dollarReturn = totalMarket - totalCost;
    final double percentageReturn;
    if (totalCost > 0.0 && !totalCost.isNaN && !totalCost.isInfinite) {
      percentageReturn = (dollarReturn / totalCost) * 100.0;
    } else {
      percentageReturn = 0.0;
    }

    final isProfit = dollarReturn > 0.0001;
    final isLoss = dollarReturn < -0.0001;
    final isNeutral = !isProfit && !isLoss;

    // Deterministic sorting for Pareto Heavy Hitters:
    // 1. Line valuation descending
    // 2. Card name ascending (case-insensitive)
    // 3. Unit price descending
    evaluatedCards.sort((a, b) {
      final compVal = b.lineValue.compareTo(a.lineValue);
      if (compVal != 0) return compVal;
      final compName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (compName != 0) return compName;
      return b.unitPrice.compareTo(a.unitPrice);
    });

    final targetK = 5;
    final k = uniqueCount < targetK ? uniqueCount : targetK;
    final topCardsSlice = evaluatedCards.take(k).toList();

    double topCardsSum = 0.0;
    for (final c in topCardsSlice) {
      topCardsSum += c.lineValue;
    }

    final double paretoPct;
    if (totalMarket > 0.0 && !totalMarket.isNaN && !totalMarket.isInfinite) {
      paretoPct = ((topCardsSum / totalMarket) * 100.0).clamp(0.0, 100.0);
    } else {
      paretoPct = 0.0;
    }

    final headline = _generateHeadline(k: k, paretoPct: paretoPct, uniqueCount: uniqueCount);

    final heavyHitters = <DeckHeavyHitter>[];
    for (int i = 0; i < topCardsSlice.length; i++) {
      final c = topCardsSlice[i];
      final share = (totalMarket > 0.0 && !totalMarket.isNaN && !totalMarket.isInfinite)
          ? ((c.lineValue / totalMarket) * 100.0).clamp(0.0, 100.0)
          : 0.0;

      heavyHitters.add(
        DeckHeavyHitter(
          rank: i + 1,
          vaultItemId: c.id,
          cardName: c.name,
          setCode: c.setCode,
          imageUrl: c.imageUrl,
          artCropUrl: c.artCropUrl,
          quantity: c.quantity,
          unitPrice: c.unitPrice,
          lineValue: c.lineValue,
          shareOfTotal: share,
        ),
      );
    }

    return DeckFinancialSummary(
      deckId: deckId,
      totalMarketValue: totalMarket,
      totalCostBasis: totalCost,
      dollarReturn: dollarReturn,
      percentageReturn: percentageReturn,
      totalCardCount: totalCards,
      uniqueCardCount: uniqueCount,
      currency: currency,
      isProfit: isProfit,
      isLoss: isLoss,
      isNeutral: isNeutral,
      paretoConcentration: paretoPct,
      paretoHeadline: headline,
      heavyHitters: heavyHitters,
    );
  }

  static String _generateHeadline({
    required int k,
    required double paretoPct,
    required int uniqueCount,
  }) {
    if (uniqueCount == 0) {
      return 'No cards in deck to calculate concentration.';
    }
    final pctStr = '${paretoPct.toStringAsFixed(1)}%';
    if (k == 1) {
      return "The top card represents $pctStr of this deck's total value.";
    }
    return "The top $k cards represent $pctStr of this deck's total value.";
  }

  static String? _extractArtCrop(dynamic rawDyn) {
    if (rawDyn == null) return null;
    try {
      final d = rawDyn is Map ? rawDyn : jsonDecode(rawDyn.toString());
      if (d is Map) {
        if (d['image_uris'] is Map) {
          final uri = d['image_uris']['art_crop']?.toString();
          if (uri != null && uri.trim().isNotEmpty) return uri.trim();
        }
        if (d['card_faces'] is List && (d['card_faces'] as List).isNotEmpty) {
          final f0 = (d['card_faces'] as List)[0];
          if (f0 is Map && f0['image_uris'] is Map) {
            final uri = f0['image_uris']['art_crop']?.toString();
            if (uri != null && uri.trim().isNotEmpty) return uri.trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

class _EvaluatedDeckCard {
  final String id;
  final String name;
  final String setCode;
  final String? imageUrl;
  final String? artCropUrl;
  final int quantity;
  final double unitPrice;
  final double lineValue;

  const _EvaluatedDeckCard({
    required this.id,
    required this.name,
    required this.setCode,
    this.imageUrl,
    this.artCropUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineValue,
  });
}

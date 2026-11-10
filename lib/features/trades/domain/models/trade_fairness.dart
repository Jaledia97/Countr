import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';

/// 3 visual tiers for trade balance
enum TradeFairnessTier {
  fair, // Green: gap <= 10%
  moderate, // Amber: gap 10-25%
  lopsided; // Red: gap > 25%

  String get displayName {
    switch (this) {
      case TradeFairnessTier.fair:
        return 'Fair';
      case TradeFairnessTier.moderate:
        return 'Moderate';
      case TradeFairnessTier.lopsided:
        return 'Lopsided';
    }
  }

  Color get color {
    switch (this) {
      case TradeFairnessTier.fair:
        return AppColors.accentEmerald;
      case TradeFairnessTier.moderate:
        return AppColors.accentAmber;
      case TradeFairnessTier.lopsided:
        return AppColors.accentRose;
    }
  }
}

/// Result of trade fairness evaluation.
class TradeFairnessResult {
  final TradeFairnessTier tier;
  final double maxGapPercent;
  final double maxDollarGap;
  final bool isLargeGap;
  final Map<String, double> participantPercentGaps;
  final Map<String, double> participantDollarGaps;

  const TradeFairnessResult({
    required this.tier,
    required this.maxGapPercent,
    required this.maxDollarGap,
    required this.isLargeGap,
    this.participantPercentGaps = const {},
    this.participantDollarGaps = const {},
  });

  /// Evaluates trade fairness across 2 or 3 participants.
  factory TradeFairnessResult.evaluate(List<TradeParticipant> participants) {
    if (participants.isEmpty) {
      return const TradeFairnessResult(
        tier: TradeFairnessTier.fair,
        maxGapPercent: 0.0,
        maxDollarGap: 0.0,
        isLargeGap: false,
      );
    }

    double maxPercent = 0.0;
    double maxDollar = 0.0;
    final percentGaps = <String, double>{};
    final dollarGaps = <String, double>{};

    for (final p in participants) {
      final pGap = p.percentageDelta;
      final dGap = p.absoluteDollarGap;
      percentGaps[p.id] = pGap;
      dollarGaps[p.id] = dGap;

      if (pGap > maxPercent) maxPercent = pGap;
      if (dGap > maxDollar) maxDollar = dGap;
    }

    final TradeFairnessTier tier;
    if (maxPercent <= 10.0) {
      tier = TradeFairnessTier.fair;
    } else if (maxPercent <= 25.0) {
      tier = TradeFairnessTier.moderate;
    } else {
      tier = TradeFairnessTier.lopsided;
    }

    // Large difference trigger condition: >= 15% OR >= $10.00
    final hasActiveTrade = participants.any((p) => p.sendingTotalValue > 0 || p.receivingTotalValue > 0);
    final isLarge = hasActiveTrade && (maxPercent >= 15.0 || maxDollar >= 10.0);

    return TradeFairnessResult(
      tier: tier,
      maxGapPercent: maxPercent,
      maxDollarGap: maxDollar,
      isLargeGap: isLarge,
      participantPercentGaps: percentGaps,
      participantDollarGaps: dollarGaps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'maxGapPercent': maxGapPercent,
      'maxDollarGap': maxDollarGap,
      'isLargeGap': isLargeGap,
      'participantPercentGaps': participantPercentGaps,
      'participantDollarGaps': participantDollarGaps,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory TradeFairnessResult.fromJson(Map<String, dynamic> json) {
    final tierName = json['tier'] as String? ?? 'fair';
    final tier = TradeFairnessTier.values.firstWhere(
      (e) => e.name == tierName,
      orElse: () => TradeFairnessTier.fair,
    );

    return TradeFairnessResult(
      tier: tier,
      maxGapPercent: (json['maxGapPercent'] as num?)?.toDouble() ?? 0.0,
      maxDollarGap: (json['maxDollarGap'] as num?)?.toDouble() ?? 0.0,
      isLargeGap: json['isLargeGap'] as bool? ?? false,
      participantPercentGaps: json['participantPercentGaps'] is Map
          ? (json['participantPercentGaps'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            )
          : {},
      participantDollarGaps: json['participantDollarGaps'] is Map
          ? (json['participantDollarGaps'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            )
          : {},
    );
  }

  static TradeFairnessResult? tryParse(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return TradeFairnessResult.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}

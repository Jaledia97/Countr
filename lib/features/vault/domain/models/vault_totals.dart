import 'package:flutter/foundation.dart';

/// Immutable model representing aggregate vault macro statistics computed directly
/// by Drift SQLite queries.
@immutable
class VaultTotals {
  final int totalCount;
  final double totalMarketValue;
  final double totalCostBasis;
  final double totalProfitLoss;
  final double profitLossPercentage;

  const VaultTotals({
    required this.totalCount,
    required this.totalMarketValue,
    this.totalCostBasis = 0.0,
    this.totalProfitLoss = 0.0,
    this.profitLossPercentage = 0.0,
  });

  /// True if net profit/loss is non-negative.
  bool get isProfitable => totalProfitLoss >= 0;

  /// Default zero totals instance.
  static const zero = VaultTotals(
    totalCount: 0,
    totalMarketValue: 0.0,
    totalCostBasis: 0.0,
    totalProfitLoss: 0.0,
    profitLossPercentage: 0.0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultTotals &&
          runtimeType == other.runtimeType &&
          totalCount == other.totalCount &&
          totalMarketValue == other.totalMarketValue &&
          totalCostBasis == other.totalCostBasis &&
          totalProfitLoss == other.totalProfitLoss &&
          profitLossPercentage == other.profitLossPercentage;

  @override
  int get hashCode => Object.hash(
        totalCount,
        totalMarketValue,
        totalCostBasis,
        totalProfitLoss,
        profitLossPercentage,
      );

  @override
  String toString() =>
      'VaultTotals(totalCount: $totalCount, totalMarketValue: $totalMarketValue, totalCostBasis: $totalCostBasis, totalProfitLoss: $totalProfitLoss, profitLossPercentage: $profitLossPercentage)';
}

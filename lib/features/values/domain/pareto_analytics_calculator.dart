export 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';

/// Legacy/PROJECT.md contract class for Pareto concentration calculations.
class ParetoAnalyticsCalculator {
  ParetoAnalyticsCalculator._();

  /// Computes the Pareto concentration percentage of the top [topK] items.
  static double computeConcentration({
    required List<double> itemLineValues,
    int topK = 5,
  }) {
    final valid = itemLineValues.where((v) => !v.isNaN && !v.isInfinite && v > 0.0).toList();
    if (valid.isEmpty) return 0.0;

    valid.sort((a, b) => b.compareTo(a)); // descending
    final total = valid.reduce((a, b) => a + b);
    if (total <= 0.0) return 0.0;

    final k = (topK > valid.length) ? valid.length : topK;
    final topSum = valid.sublist(0, k).reduce((a, b) => a + b);
    return ((topSum / total) * 100.0).clamp(0.0, 100.0);
  }

  /// Generates the standard headline string for Pareto deck concentration.
  static String generateHeadline(
    double concentrationPercentage, {
    int topK = 5,
  }) {
    if (topK == 1) {
      return "The top card represents ${concentrationPercentage.toStringAsFixed(1)}% of this deck's total value.";
    }
    return "The top $topK cards represent ${concentrationPercentage.toStringAsFixed(1)}% of this deck's total value.";
  }
}

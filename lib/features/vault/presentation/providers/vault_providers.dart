import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

/// Database singleton provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Vault DAO provider
final vaultDaoProvider = Provider<VaultDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.vaultDao;
});

/// Reactive StreamProvider that queries VaultItems based on activeGameContextProvider.
/// Automatically re-emits when the user switches collection context or database mutates.
final vaultItemsStreamProvider = StreamProvider<List<VaultItem>>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchItemsByCollection(activeGame);
});

/// Model holding calculated portfolio ledger financial summaries
class VaultPortfolioSummary {
  final double totalMarketValue;
  final double totalCostBasis;
  final double totalProfitLoss;
  final double profitLossPercentage;
  final int totalItemCount;

  const VaultPortfolioSummary({
    required this.totalMarketValue,
    required this.totalCostBasis,
    required this.totalProfitLoss,
    required this.profitLossPercentage,
    required this.totalItemCount,
  });

  bool get isProfitable => totalProfitLoss >= 0;
}

/// Reactive provider calculating overall portfolio performance from live Vault items
final vaultPortfolioSummaryProvider = Provider<VaultPortfolioSummary>((ref) {
  final asyncItems = ref.watch(vaultItemsStreamProvider);

  return asyncItems.maybeWhen(
    data: (items) {
      if (items.isEmpty) {
        return const VaultPortfolioSummary(
          totalMarketValue: 0.0,
          totalCostBasis: 0.0,
          totalProfitLoss: 0.0,
          profitLossPercentage: 0.0,
          totalItemCount: 0,
        );
      }

      double marketVal = 0.0;
      double costBasis = 0.0;
      int count = 0;

      for (final item in items) {
        marketVal += (item.currentMarketPrice * item.quantity);
        costBasis += (item.acquiredPrice * item.quantity);
        count += item.quantity;
      }

      final delta = marketVal - costBasis;
      final pct = costBasis > 0 ? (delta / costBasis) * 100 : 0.0;

      return VaultPortfolioSummary(
        totalMarketValue: marketVal,
        totalCostBasis: costBasis,
        totalProfitLoss: delta,
        profitLossPercentage: pct,
        totalItemCount: count,
      );
    },
    orElse: () => const VaultPortfolioSummary(
      totalMarketValue: 0.0,
      totalCostBasis: 0.0,
      totalProfitLoss: 0.0,
      profitLossPercentage: 0.0,
      totalItemCount: 0,
    ),
  );
});

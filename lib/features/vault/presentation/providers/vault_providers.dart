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

/// Controls whether the Vault tab displays:
/// - false (default): 'My Vault' (owned cards only, quantity > 0)
/// - true: 'Catalog Reference' (unowned reference cards from bulk hydration, capped at 100)
final vaultShowCatalogProvider = StateProvider<bool>((ref) => false);

/// Reactive StreamProvider that queries VaultItems based on activeGameContextProvider.
/// Automatically re-emits when the user switches collection context or database mutates.
final vaultItemsStreamProvider = StreamProvider<List<VaultItem>>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final dao = ref.watch(vaultDaoProvider);
  final showCatalog = ref.watch(vaultShowCatalogProvider);

  if (showCatalog) {
    // When viewing catalog reference, limit to 100 items to guarantee smooth 60fps rendering
    return dao.watchItemsByCollection(
      activeGame,
      onlyOwned: false,
      limit: 100,
    );
  }

  // Default: Stream owned inventory only (quantity > 0)
  return dao.watchItemsByCollection(
    activeGame,
    onlyOwned: true,
  );
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
        // Filter strictly for owned inventory (quantity > 0); catalog dictionary items have quantity 0
        if (item.quantity <= 0) continue;
        // Defensive check: staged Inbox cards must never inflate portfolio valuation or cost basis
        if (item.primaryBinderId == 'INBOX') continue;
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

/// View mode for Vault screen (All Vault vs Binders View)
enum VaultViewMode {
  allVault,
  binders,
}

final vaultViewModeProvider =
    StateProvider<VaultViewMode>((ref) => VaultViewMode.allVault);

/// Reactive StreamProvider for items staged in the Inbox
final inboxItemsStreamProvider = StreamProvider<List<VaultItem>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchInboxItems();
});

/// Reactive count of items in the Inbox
final inboxItemCountProvider = Provider<int>((ref) {
  final asyncInbox = ref.watch(inboxItemsStreamProvider);
  return asyncInbox.maybeWhen(
    data: (items) => items.fold<int>(0, (sum, i) => sum + i.quantity),
    orElse: () => 0,
  );
});

/// Reactive StreamProvider for binders filtered by activeGameContextProvider
final bindersStreamProvider = StreamProvider<List<VaultBinder>>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchBindersByCollection(activeGame);
});

/// Reactive StreamProvider for item counts per binder
final binderItemCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchBinderItemCounts();
});

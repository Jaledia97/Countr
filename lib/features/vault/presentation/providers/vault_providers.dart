import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_totals.dart';

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

/// Card display layout for the Vault cards view (List vs. ManaBox-style Grid/Tile)
enum CardDisplayLayout { list, grid }

/// Controls whether cards are displayed in list or grid/tile layout
final cardDisplayLayoutProvider = StateProvider<CardDisplayLayout>((ref) => CardDisplayLayout.grid);

/// Global search query entered in the Vault screen
final vaultSearchQueryProvider = StateProvider<String>((ref) => '');

/// Pagination item limit for infinite scrolling in the Vault screen
final vaultPaginationLimitProvider = StateProvider<int>((ref) => 50);

/// Tracks whether infinite scrolling is currently fetching more items in the background
final vaultIsFetchingMoreProvider = StateProvider<bool>((ref) => false);

/// Controls whether the Vault tab displays:
/// - false (default): 'My Vault' (owned cards only, quantity > 0)
/// - true: 'Catalog Reference' (unowned reference cards from bulk hydration, capped at 100)
final vaultShowCatalogProvider = StateProvider<bool>((ref) => false);

/// Reactive StreamProvider that queries VaultItems based on activeGameContextProvider,
/// active search query, catalog mode, and infinite-scroll pagination limit.
/// Automatically re-emits when the user switches collection context or database mutates.
final vaultItemsStreamProvider = StreamProvider<List<VaultItem>>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final dao = ref.watch(vaultDaoProvider);
  final showCatalog = ref.watch(vaultShowCatalogProvider);
  final searchQuery = ref.watch(vaultSearchQueryProvider).trim();
  final paginationLimit = ref.watch(vaultPaginationLimitProvider);

  if (showCatalog) {
    return dao.watchItemsByCollection(
      activeGame,
      onlyOwned: false,
      searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      limit: paginationLimit,
    );
  }

  return dao.watchItemsByCollection(
    activeGame,
    onlyOwned: true,
    searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
    limit: paginationLimit,
  );
});

/// Model holding calculated portfolio ledger financial summaries
class VaultPortfolioSummary {
  final double totalMarketValue;
  final double totalCostBasis;
  final double totalProfitLoss;
  final double profitLossPercentage;
  final int totalItemCount;
  final int uniqueCardCount;

  const VaultPortfolioSummary({
    required this.totalMarketValue,
    required this.totalCostBasis,
    required this.totalProfitLoss,
    required this.profitLossPercentage,
    required this.totalItemCount,
    this.uniqueCardCount = 0,
  });

  bool get isProfitable => totalProfitLoss >= 0;
}

/// Holds currently selected binder ID for scoped Vault totals (null = macro view)
final selectedVaultBinderIdProvider = StateProvider<String?>((ref) => null);

/// Reactive StreamProvider delivering full database macro statistics
final vaultTotalsProvider = StreamProvider<VaultTotals>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final binderId = ref.watch(selectedVaultBinderIdProvider);
  final dao = ref.watch(vaultDaoProvider);

  return dao.watchVaultTotals(
    collectionType: activeGame,
    binderId: binderId,
  );
});

/// Reactive provider calculating overall portfolio performance directly from vaultTotalsProvider
final vaultPortfolioSummaryProvider = Provider<VaultPortfolioSummary>((ref) {
  final asyncTotals = ref.watch(vaultTotalsProvider);

  if (asyncTotals.hasValue) {
    final totals = asyncTotals.value!;
    return VaultPortfolioSummary(
      totalMarketValue: totals.totalMarketValue,
      totalCostBasis: totals.totalCostBasis,
      totalProfitLoss: totals.totalProfitLoss,
      profitLossPercentage: totals.profitLossPercentage,
      totalItemCount: totals.totalCount,
      uniqueCardCount:
          totals.uniqueCount > 0 ? totals.uniqueCount : totals.totalCount,
    );
  }

  // Graceful fallback while vaultTotalsProvider stream initializes if vaultItemsStreamProvider has loaded
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
          uniqueCardCount: 0,
        );
      }

      double marketVal = 0.0;
      double costBasis = 0.0;
      int count = 0;
      int unique = 0;

      for (final item in items) {
        if (item.quantity <= 0) continue;
        if (item.primaryBinderId == 'INBOX') continue;
        marketVal += (item.currentMarketPrice * item.quantity);
        costBasis += (item.acquiredPrice * item.quantity);
        count += item.quantity;
        unique += 1;
      }

      final delta = marketVal - costBasis;
      final pct = costBasis > 0 ? (delta / costBasis) * 100 : 0.0;

      return VaultPortfolioSummary(
        totalMarketValue: marketVal,
        totalCostBasis: costBasis,
        totalProfitLoss: delta,
        profitLossPercentage: pct,
        totalItemCount: count,
        uniqueCardCount: unique,
      );
    },
    orElse: () => const VaultPortfolioSummary(
      totalMarketValue: 0.0,
      totalCostBasis: 0.0,
      totalProfitLoss: 0.0,
      profitLossPercentage: 0.0,
      totalItemCount: 0,
      uniqueCardCount: 0,
    ),
  );
});

/// View mode for Vault screen (All Vault vs Binders View)
enum VaultViewMode {
  allVault,
  binders,
}

final vaultViewModeProvider =
    StateProvider<VaultViewMode>((ref) => VaultViewMode.binders);

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

/// Reactive StreamProvider for aggregate items grouped by collection type
final collectionItemCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchCollectionItemCounts();
});


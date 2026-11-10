import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/domain/models/vault_totals.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/features/vault/data/daos/card_reputation_dao.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

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

/// Card Reputation DAO provider
final cardReputationDaoProvider = Provider<CardReputationDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.cardReputationDao;
});

/// Reactive reputation summary provider for an individual card.
final cardReputationProvider = StreamProvider.family<CardReputationSummary, String>((ref, cardId) {
  final dao = ref.watch(cardReputationDaoProvider);
  return dao.watchReputationScore(cardId);
});

/// Card display layout for the Vault cards view (List vs. ManaBox-style Grid/Tile)
enum CardDisplayLayout { list, grid }

/// Controls whether cards are displayed in list or grid/tile layout
final cardDisplayLayoutProvider = StateProvider<CardDisplayLayout>((ref) => CardDisplayLayout.grid);

/// Global search query entered in the Vault screen
final vaultSearchQueryProvider = StateProvider<String>((ref) => '');

/// Pagination item limit for infinite scrolling in the Vault screen
final vaultPaginationLimitProvider = StateProvider<int>((ref) {
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
    return 50;
  }
  return 60;
});

/// Tracks whether infinite scrolling is currently fetching more items in the background
final vaultIsFetchingMoreProvider = StateProvider<bool>((ref) => false);

/// Controls whether the Vault tab displays:
/// - false (default): 'My Vault' (owned cards only, quantity > 0)
/// - true: 'Catalog Reference' (unowned reference cards from bulk hydration, capped at 100)
final vaultShowCatalogProvider = StateProvider<bool>((ref) => false);

/// Active polymorphic category filter for non-MTG card collections (e.g. 'Owned', 'All Cards', 'Graded Slabs', etc.)
final vaultPolymorphicFilterProvider = StateProvider<String>((ref) => 'Owned');

/// Controls visibility of the Estimated Vault Value header card.
/// Defaults to true (shown). When false, the header collapses to 0.0dp extent.
final vaultShowEstimatedValueProvider = StateProvider<bool>((ref) => true);

/// Controls whether only wishlisted cards (isWishlisted == true) are displayed.
/// Defaults to false.
final vaultWishlistFilterProvider = StateProvider<bool>((ref) => false);

/// Available sort options for Vault cards.
enum VaultSortOption {
  reputationHighest,
  reputationLowest,
  priceHighToLow,
  priceLowToHigh,
  nameAZ,
  manaValueCmc,
  releaseDate,
}

extension VaultSortOptionLabel on VaultSortOption {
  String get label {
    switch (this) {
      case VaultSortOption.reputationHighest:
        return 'Reputation (Highest Upvoted)';
      case VaultSortOption.reputationLowest:
        return 'Reputation (Lowest/Controversial)';
      case VaultSortOption.priceHighToLow:
        return 'Price: High-Low';
      case VaultSortOption.priceLowToHigh:
        return 'Price: Low-High';
      case VaultSortOption.nameAZ:
        return 'Name: A-Z';
      case VaultSortOption.manaValueCmc:
        return 'Mana Value (CMC)';
      case VaultSortOption.releaseDate:
        return 'Release Date';
    }
  }
}

/// Active sort option for Vault cards.
final vaultSortOptionProvider = StateProvider<VaultSortOption>((ref) => VaultSortOption.releaseDate);

int _extractReputationScore(VaultItem item) {
  try {
    final dyn = item as dynamic;
    if (dyn.reputationScore != null) return (dyn.reputationScore as num).toInt();
  } catch (_) {}
  if (item.dynamicData.isNotEmpty) {
    try {
      final map = ParsedJsonCache.parse(item.dynamicData);
      final score = map['reputation_score'] ?? map['score'];
      if (score != null) return (score as num).toInt();
    } catch (_) {}
  }
  return 0;
}

double _extractCmc(VaultItem item) {
  if (item.dynamicData.isNotEmpty) {
    try {
      final map = ParsedJsonCache.parse(item.dynamicData);
      final cmc = map['cmc'];
      if (cmc != null) return (cmc as num).toDouble();
    } catch (_) {}
  }
  return 0.0;
}

String _extractReleaseDate(VaultItem item) {
  if (item.dynamicData.isNotEmpty) {
    try {
      final map = ParsedJsonCache.parse(item.dynamicData);
      final rel = map['released_at'] ?? map['release_date'];
      if (rel != null) return rel.toString();
    } catch (_) {}
  }
  return '';
}

List<VaultItem> sortVaultItemsInMemory(
  List<VaultItem> items,
  VaultSortOption sortOption,
) {
  final list = List<VaultItem>.from(items);
  switch (sortOption) {
    case VaultSortOption.reputationHighest:
      list.sort((a, b) {
        final scoreA = _extractReputationScore(a);
        final scoreB = _extractReputationScore(b);
        final cmp = scoreB.compareTo(scoreA);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case VaultSortOption.reputationLowest:
      list.sort((a, b) {
        final scoreA = _extractReputationScore(a);
        final scoreB = _extractReputationScore(b);
        final cmp = scoreA.compareTo(scoreB);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case VaultSortOption.priceHighToLow:
      list.sort((a, b) {
        final cmp = b.currentMarketPrice.compareTo(a.currentMarketPrice);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case VaultSortOption.priceLowToHigh:
      list.sort((a, b) {
        final cmp = a.currentMarketPrice.compareTo(b.currentMarketPrice);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case VaultSortOption.nameAZ:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      break;
    case VaultSortOption.manaValueCmc:
      list.sort((a, b) {
        final cmcA = _extractCmc(a);
        final cmcB = _extractCmc(b);
        final cmp = cmcA.compareTo(cmcB);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case VaultSortOption.releaseDate:
      list.sort((a, b) {
        final dateA = _extractReleaseDate(a);
        final dateB = _extractReleaseDate(b);
        final cmp = dateB.compareTo(dateA);
        if (cmp != 0) return cmp;
        final acqCmp = b.acquiredDate.compareTo(a.acquiredDate);
        if (acqCmp != 0) return acqCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
  }
  return list;
}

/// Reactive StreamProvider that queries VaultItems based on activeGameContextProvider,
/// active search query, catalog mode, MTG filter state, infinite-scroll pagination limit,
/// and active VaultSortOption.
/// Automatically re-emits when the user switches collection context, updates filters, or database mutates.
final vaultItemsStreamProvider = StreamProvider<List<VaultItem>>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final dao = ref.watch(vaultDaoProvider);
  final showCatalog = ref.watch(vaultShowCatalogProvider);
  final isWishlistOnly = ref.watch(vaultWishlistFilterProvider);
  final searchQuery = ref.watch(vaultSearchQueryProvider).trim();
  final paginationLimit = ref.watch(vaultPaginationLimitProvider);
  final sortOption = ref.watch(vaultSortOptionProvider);

  // Only watch mtgFilterProvider when the active game context is Magic: The Gathering
  final isMtg = activeGame.toLowerCase().contains('magic') || activeGame.toLowerCase() == 'mtg';
  final mtgFilter = isMtg ? ref.watch(mtgFilterProvider) : null;

  final isUnfilteredCatalog = showCatalog &&
      (mtgFilter == null || !mtgFilter.isActive) &&
      searchQuery.isEmpty;
  final fetchMultiplier = isUnfilteredCatalog ? 1.25 : 2.0;
  final fetchLimit = (paginationLimit * fetchMultiplier).ceil();

  return dao.watchItemsByCollection(
    activeGame,
    onlyOwned: !showCatalog,
    onlyWishlisted: isWishlistOnly,
    searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
    mtgFilter: (mtgFilter != null && mtgFilter.isActive) ? mtgFilter : null,
    sortOption: sortOption,
    limit: fetchLimit,
  ).map((items) {
    final consolidated = VaultVariantHelper.groupVaultItemsByVariant(items).items;
    final sorted = sortVaultItemsInMemory(consolidated, sortOption);
    return sorted.take(paginationLimit).toList();
  });
});

/// Reactive StreamProvider delivering the true total database count (SELECT COUNT(*))
/// of vault items matching activeGameContextProvider, catalog toggle (showCatalog),
/// search query, and MTG filters.
/// Completely independent of pagination limits (120 / 50).
/// Automatically re-emits when items are inserted, deleted, modified, or filters change.
final vaultFilteredItemCountProvider = StreamProvider<int>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final dao = ref.watch(vaultDaoProvider);
  final showCatalog = ref.watch(vaultShowCatalogProvider);
  final isWishlistOnly = ref.watch(vaultWishlistFilterProvider);
  final searchQuery = ref.watch(vaultSearchQueryProvider).trim();

  // Only watch mtgFilterProvider when the active game context is Magic: The Gathering
  final isMtg = activeGame.toLowerCase().contains('magic') || activeGame.toLowerCase() == 'mtg';
  final mtgFilter = isMtg ? ref.watch(mtgFilterProvider) : null;

  return dao.watchFilteredItemCount(
    activeGame,
    onlyOwned: !showCatalog,
    onlyWishlisted: isWishlistOnly,
    searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
    mtgFilter: (mtgFilter != null && mtgFilter.isActive) ? mtgFilter : null,
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
  final currentUserId = ref.watch(currentUserIdProvider);
  final dao = ref.watch(vaultDaoProvider);

  return dao.watchVaultTotals(
    collectionType: activeGame,
    binderId: binderId,
    userId: currentUserId,
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
        if (item.primaryBinderId != null &&
            (item.primaryBinderId!.startsWith('system_looking_for') ||
                item.primaryBinderId == 'looking_for')) {
          continue;
        }
        if (item.isTraded == true) continue;
        final unitPrice = VaultPricingHelper.resolveEffectiveMarketPrice(item);
        marketVal += (unitPrice * item.quantity);
        costBasis +=
            ((item.purchasePrice ?? item.acquiredPrice) * item.quantity);
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

/// View mode for Vault screen (Singles vs Binders vs Collections View)
enum VaultViewMode {
  allVault,
  binders,
  collections,
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

/// Reactive StreamProvider for binders filtered by activeGameContextProvider,
/// strictly scoped to the active user and their business account status.
final bindersStreamProvider = StreamProvider<List<VaultBinder>>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final dao = ref.watch(vaultDaoProvider);
  final userId = ref.watch(currentUserIdProvider);
  final authUser = ref.watch(currentUserProvider);
  final profile = ref.watch(currentUserProfileProvider);
  final isBusiness = authUser.isBusiness ||
      profile?.accountType == 'business' ||
      (profile?.isVerifiedBusiness ?? false);

  return dao.watchBindersByCollection(
    activeGame,
    userId: userId,
    isBusiness: isBusiness,
  );
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

/// Reactive StreamProvider for set collections grouped by setOrSeries
final vaultSetCollectionsStreamProvider =
    StreamProvider<List<VaultSetCollection>>((ref) {
  final activeGame = ref.watch(activeGameContextProvider);
  final searchQuery = ref.watch(vaultSearchQueryProvider).trim();
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchSetCollections(
    collectionType: activeGame,
    searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
  );
});

/// Alias for vaultSetCollectionsStreamProvider
final vaultSetCollectionsProvider = vaultSetCollectionsStreamProvider;

/// Selected or expanded collection set name
final selectedCollectionSetProvider = StateProvider<String?>((ref) => null);

/// Reactive StreamProvider fetching a single VaultItem by ID.
final vaultItemProvider = StreamProvider.family<VaultItem?, String>((ref, id) async* {
  try {
    final dao = ref.watch(vaultDaoProvider);
    yield* dao.watchItemById(id);
  } catch (error, stackTrace) {
    debugPrint('[vaultItemProvider] Error watching item $id: $error\n$stackTrace');
    rethrow;
  }
});

/// Reactive StreamProvider fetching all active card deck assignments.
final allCardActiveDecksProvider = StreamProvider<Map<String, List<String>>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchAllCardActiveDecks();
});

/// Reactive StreamProvider fetching the list of decks currently assigning a specific VaultItem.
final cardActiveDecksProvider = StreamProvider.family<List<String>, String>((ref, vaultItemId) async* {
  try {
    final dao = ref.watch(vaultDaoProvider);
    final item = await dao.getItemById(vaultItemId);
    if (item != null) {
      yield* dao.watchItemActiveDecks(vaultItemId);
    } else {
      yield const <String>[];
    }
  } catch (error, stackTrace) {
    debugPrint('[cardActiveDecksProvider] Error watching active decks for $vaultItemId: $error\n$stackTrace');
    yield const <String>[];
  }
});

/// Backward-compatible alias for cardActiveDecksProvider.
final vaultItemAssignedDecksProvider = cardActiveDecksProvider;

/// Reactive StreamProvider fetching card availability breakdown across all vault cards.
final allCardAvailabilityProvider =
    StreamProvider<Map<String, CardAvailability>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchAllCardAvailability();
});

/// Reactive StreamProvider fetching availability for a single card by its ID.
final cardAvailabilityProvider =
    StreamProvider.family<CardAvailability, String>((ref, id) {
  final asyncMap = ref.watch(allCardAvailabilityProvider);
  return asyncMap.when(
    data: (map) => Stream.value(
      map[id] ?? const CardAvailability(owned: 0, available: 0, inDeck: 0),
    ),
    loading: () => const Stream.empty(),
    error: (err, stack) => Stream.error(err, stack),
  );
});

/// Provider for checking if a given card has multiple variants in the Vault
final vaultVariantMetadataProvider = Provider<ConsolidatedVariantResult>((ref) {
  final asyncItems = ref.watch(vaultItemsStreamProvider);
  return VaultVariantHelper.groupVaultItemsByVariant(asyncItems.asData?.value ?? const []);
});

/// Reactive StreamProvider for custom user tags on a VaultItem, parsed from vaultItemProvider.
final cardCustomTagsProvider = StreamProvider.family<List<String>, String>((ref, vaultItemId) async* {
  try {
    final dao = ref.watch(vaultDaoProvider);
    final item = await dao.getItemById(vaultItemId);
    if (item != null) {
      yield* dao.watchItemById(vaultItemId).map((item) {
        if (item == null || item.dynamicData.isEmpty) return const <String>[];
        try {
          final data = jsonDecode(item.dynamicData) as Map<String, dynamic>;
          final raw = data['tags'];
          if (raw is List) return raw.map((e) => e.toString()).toList();
        } catch (error, stackTrace) {
          debugPrint('[cardCustomTagsProvider] Failed parsing tags: $error\n$stackTrace');
        }
        return const <String>[];
      });
    } else {
      yield const <String>[];
    }
  } catch (error, stackTrace) {
    debugPrint('[cardCustomTagsProvider] Error watching custom tags for $vaultItemId: $error\n$stackTrace');
    yield const <String>[];
  }
});

/// View mode for Binder Detail screen (3x3 Grid vs List)
enum BinderViewMode {
  grid3x3,
  list,
}

/// Persistent view mode state for BinderDetailScreen
final binderViewModeProvider = StateProvider<BinderViewMode>((ref) => BinderViewMode.grid3x3);

/// Metadata model for binder extra properties (description, coverArtUrl)
class BinderMetadata {
  final String? description;
  final String? coverArtUrl;

  const BinderMetadata({
    this.description,
    this.coverArtUrl,
  });

  BinderMetadata copyWith({
    String? description,
    String? coverArtUrl,
  }) {
    return BinderMetadata(
      description: description ?? this.description,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
    );
  }
}

/// Reactive StateProvider family storing binder extra metadata
final binderMetadataProvider = StateProvider.family<BinderMetadata, String>((ref, binderId) {
  final dao = ref.watch(vaultDaoProvider);
  return BinderMetadata(
    description: dao.getBinderDescription(binderId),
    coverArtUrl: dao.getBinderCoverArt(binderId),
  );
});

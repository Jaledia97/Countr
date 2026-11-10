import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/domain/services/explore_category_engine.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

final exploreDeckDaoProvider = Provider<ExploreDeckDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.exploreDeckDao;
});

final activeExploreCategoryProvider = StateProvider<ExploreCategory>((ref) {
  return ExploreCategory.all;
});

final activeExploreSortOptionProvider = StateProvider<ExploreSortOption>((ref) {
  return ExploreSortOption.popularity;
});

final exploreSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

final exploreFilterStateProvider = StateProvider<ExploreFilterState>((ref) {
  return const ExploreFilterState();
});

/// Reactive stream of explore decks matching active category, sort, filters, and query.
final exploreDecksStreamProvider = StreamProvider<List<ExploreDeckWithVote>>((ref) {
  final dao = ref.watch(exploreDeckDaoProvider);
  final category = ref.watch(activeExploreCategoryProvider);
  final sort = ref.watch(activeExploreSortOptionProvider);
  final filter = ref.watch(exploreFilterStateProvider);
  final searchQuery = ref.watch(exploreSearchQueryProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  return dao.watchExploreDecks(
    category: category,
    sort: sort,
    filter: filter,
    searchQuery: searchQuery,
    userId: currentUserId,
    balanceFeed: category == ExploreCategory.all && searchQuery.trim().isEmpty,
  );
});

/// Reactive StreamProvider delivering the true total database count (SELECT COUNT(*))
/// of explore decks matching active category, filters, and search query.
/// Completely independent of sort order and pagination.
final exploreFilteredDeckCountProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(exploreDeckDaoProvider);
  final category = ref.watch(activeExploreCategoryProvider);
  final filter = ref.watch(exploreFilterStateProvider);
  final searchQuery = ref.watch(exploreSearchQueryProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  return dao.watchFilteredExploreDeckCount(
    category: category,
    filter: filter,
    searchQuery: searchQuery,
    currentUserId: currentUserId,
  );
});

/// Reactive stream for featured carousels (e.g. 'Suggested Commanders', 'From Top Deck Builders')
final featuredExploreCategoryStreamProvider =
    StreamProvider.family<List<ExploreDeckWithVote>, String>((ref, category) {
  final dao = ref.watch(exploreDeckDaoProvider);
  return dao.watchFeaturedCategory(category);
});

/// Multi-tier grouped search suggestions provider
final exploreSearchResultsProvider =
    FutureProvider.family<ExploreSearchResults, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return const ExploreSearchResults(inDeckName: [], inDeckCards: [], byUsername: []);
  }
  final dao = ref.watch(exploreDeckDaoProvider);
  return dao.searchExploreDecks(query: query);
});

/// Detail stream provider for Read-Only Deck Screen
final exploreDeckDetailStreamProvider =
    StreamProvider.family<ExploreDeckDetail?, String>((ref, deckId) {
  final dao = ref.watch(exploreDeckDaoProvider);
  return dao.watchExploreDeckDetail(deckId);
});

/// Active category for dedicated category drill-down view (e.g. 'Suggested Commanders').
/// When null, ExploreDecksTabView displays the standard discovery feed.
final exploreDrillDownCategoryProvider = StateProvider<String?>((ref) => null);

/// Reactive stream of explore decks for a specific featured category without carousel cap.
final featuredCategoryDecksStreamProvider =
    StreamProvider.family<List<ExploreDeckWithVote>, String>((ref, category) {
  final dao = ref.watch(exploreDeckDaoProvider);
  final sort = ref.watch(activeExploreSortOptionProvider);
  final filter = ref.watch(exploreFilterStateProvider);
  final searchQuery = ref.watch(exploreSearchQueryProvider);

  return dao.watchExploreDecks(
    category: ExploreCategory.all,
    sort: sort,
    filter: filter,
    searchQuery: searchQuery,
    featuredCategory: category,
  );
});

/// Reactive stream delivering the true total database count (SELECT COUNT(*))
/// of explore decks matching a specific featured category.
final featuredCategoryDeckCountProvider =
    StreamProvider.family<int, String>((ref, category) {
  final dao = ref.watch(exploreDeckDaoProvider);
  final filter = ref.watch(exploreFilterStateProvider);
  final searchQuery = ref.watch(exploreSearchQueryProvider);

  return dao.watchFilteredExploreDeckCount(
    category: ExploreCategory.all,
    filter: filter,
    searchQuery: searchQuery,
    featuredCategory: category,
  );
});

final exploreCategoryEngineProvider = Provider<ExploreCategoryEngine>((ref) {
  final dao = ref.watch(exploreDeckDaoProvider);
  return ExploreCategoryEngine(dao);
});

final leadVelocityWindowProvider = StreamProvider<LeadVelocityWindow>((ref) {
  final engine = ref.watch(exploreCategoryEngineProvider);
  return engine.watchLeadVelocityWindow();
});

final leadTrendingDecksStreamProvider = StreamProvider<List<ExploreDeckWithVote>>((ref) {
  final engine = ref.watch(exploreCategoryEngineProvider);
  final windowAsync = ref.watch(leadVelocityWindowProvider);
  final window = windowAsync.valueOrNull ?? LeadVelocityWindow.todaysPicks;
  return engine.watchLeadTrendingDecks(window: window);
});

final dailyRotatingCategoryProvider = Provider<AlgorithmicCategoryDefinition>((ref) {
  final engine = ref.watch(exploreCategoryEngineProvider);
  return engine.resolveDailyRotatingCategory();
});

final weeklyRotatingCategoryProvider = Provider<AlgorithmicCategoryDefinition>((ref) {
  final engine = ref.watch(exploreCategoryEngineProvider);
  return engine.resolveWeeklyRotatingCategory();
});

final algorithmicCategoryDecksStreamProvider =
    StreamProvider.family<List<ExploreDeckWithVote>, String>((ref, category) {
  final engine = ref.watch(exploreCategoryEngineProvider);
  return engine.watchCategoryDecks(category);
});



import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

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

  return dao.watchExploreDecks(
    category: category,
    sort: sort,
    filter: filter,
    searchQuery: searchQuery,
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

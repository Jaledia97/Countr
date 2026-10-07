import 'dart:convert';
import 'package:countr/core/database/app_database.dart';

enum ExploreCategory { all, official, community }

enum ExploreSortOption {
  popularity,
  recentlyAdded,
  priceLowToHigh,
  priceHighToLow,
  alphabetical,
}

class ExploreFilterState {
  final String? format;
  final List<String> colors;
  final String colorMatchMode; // 'including', 'atMost', 'exactly', 'commander'
  final String priceRange; // 'all', 'budget_0_50', 'mid_50_200', 'high_200_plus'
  final String? commanderName;
  final String? cardInclusion;

  const ExploreFilterState({
    this.format,
    this.colors = const [],
    this.colorMatchMode = 'including',
    this.priceRange = 'all',
    this.commanderName,
    this.cardInclusion,
  });

  bool get isEmpty =>
      (format == null || format == 'all') &&
      colors.isEmpty &&
      priceRange == 'all' &&
      (commanderName == null || commanderName!.trim().isEmpty) &&
      (cardInclusion == null || cardInclusion!.trim().isEmpty);
}

/// Presentation DTO bundling an ExploreDeck with the active user's persistent vote state.
class ExploreDeckWithVote {
  final ExploreDeck deck;
  final int userVote; // 1 = upvoted, -1 = downvoted, 0 = neutral

  const ExploreDeckWithVote({
    required this.deck,
    required this.userVote,
  });

  String get id => deck.id;
  String get name => deck.name;
  String get format => deck.format;
  String get tcgDomain => deck.tcgDomain;
  String get sourceType => deck.sourceType;
  String get creatorName => deck.creatorName;
  String? get description => deck.description;
  String? get commanderName => deck.commanderName;
  String? get commanderImageUrl => deck.commanderImageUrl;
  String? get commanderArtCrop => deck.commanderArtCrop;
  int get cardCount => deck.cardCount;
  double get estimatedPrice => deck.estimatedPrice;
  int get upvotes => deck.upvotes;
  int get downvotes => deck.downvotes;
  int get score => deck.score;
  String? get featuredCategory => deck.featuredCategory;
  int? get releaseYear => deck.releaseYear;
  String? get releaseCode => deck.releaseCode;
  DateTime get createdAt => deck.createdAt;

  bool get isUpvoted => userVote == 1;
  bool get isDownvoted => userVote == -1;

  List<String> get colorIdentity {
    try {
      final decoded = jsonDecode(deck.colorIdentity);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return const [];
  }
}

/// Detailed Explore Deck presentation model bundling deck metadata, votes, and full card list.
class ExploreDeckDetail {
  final ExploreDeckWithVote deckWithVote;
  final List<ExploreDeckItem> cards;

  const ExploreDeckDetail({
    required this.deckWithVote,
    required this.cards,
  });

  ExploreDeck get deck => deckWithVote.deck;
  int get userVote => deckWithVote.userVote;

  List<ExploreDeckItem> get commanderCards =>
      cards.where((c) => c.isCommander || c.boardZone == 'Commander').toList();

  List<ExploreDeckItem> get mainboardCards =>
      cards.where((c) => !c.isCommander && c.boardZone != 'Commander' && c.boardZone != 'Sideboard').toList();

  List<ExploreDeckItem> get sideboardCards =>
      cards.where((c) => c.boardZone == 'Sideboard').toList();
}

/// Enriched card match for search results in Tier 2
class ExploreDeckCardMatch {
  final ExploreDeckWithVote deckWithVote;
  final String matchingCardName;
  final int cardQuantity;

  const ExploreDeckCardMatch({
    required this.deckWithVote,
    required this.matchingCardName,
    required this.cardQuantity,
  });
}

/// Structured multi-level search result for Explore feed queries.
class ExploreSearchResults {
  final List<ExploreDeckWithVote> inDeckName;
  final List<ExploreDeckCardMatch> inDeckCards;
  final List<ExploreDeckWithVote> byUsername;

  const ExploreSearchResults({
    required this.inDeckName,
    required this.inDeckCards,
    required this.byUsername,
  });

  int get totalCount =>
      inDeckName.length + inDeckCards.length + byUsername.length;
  bool get isEmpty => totalCount == 0;
}

/// Result of an atomic voting transaction
class VoteResult {
  final int newVote;
  final int newScore;
  final int upvotes;
  final int downvotes;

  const VoteResult({
    required this.newVote,
    required this.newScore,
    required this.upvotes,
    required this.downvotes,
  });
}

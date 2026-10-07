import 'package:countr/features/decks/domain/models/deck_summary.dart';

/// A match representing a card inside a personal deck that matched the search query.
class MyDeckCardMatch {
  final DeckSummary deck;
  final String matchingCardName;
  final int cardQuantity;

  const MyDeckCardMatch({
    required this.deck,
    required this.matchingCardName,
    required this.cardQuantity,
  });
}

/// Structured multi-level search result for personal decks in the "My Decks" tab.
class MyDecksSearchResults {
  final List<DeckSummary> inDeckName;
  final List<MyDeckCardMatch> inDeckCards;

  const MyDecksSearchResults({
    this.inDeckName = const [],
    this.inDeckCards = const [],
  });

  int get totalCount => inDeckName.length + inDeckCards.length;
  bool get isEmpty => totalCount == 0;
  bool get isNotEmpty => !isEmpty;
}

/// Type alias for singular/plural naming compatibility.
typedef MyDecksSearchResult = MyDecksSearchResults;

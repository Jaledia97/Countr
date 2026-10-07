import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/my_decks_search_result.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/values/domain/models/deck_financial_summary.dart';
import 'package:countr/features/values/domain/services/deck_values_calculator.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';

/// Active TCG domain filter for DecksScreen and new deck creation.
/// Values: 'all', 'mtg', 'pokemon', 'lorcana'. Defaults to 'all'.
final activeDeckTcgFilterProvider = StateProvider<String>((ref) {
  return 'all';
});

final deckListProvider = StreamProvider<List<Deck>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchAllDecks();
});

/// Reactive StreamProvider that queries active decks with Commander art crop, color identity,
/// card count, and completeness from SQLite.
final deckSummariesProvider = StreamProvider<List<DeckSummary>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchDeckSummaries();
});

final cardDeckAllocationsProvider =
    StreamProvider.family<Map<String, int>, String>((ref, vaultItemId) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchCardDeckAllocations(vaultItemId);
});

final deckProvider = StreamProvider.family<Deck, String>((ref, id) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchDeck(id);
});

final deckItemsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, deckId) async* {
  try {
    final dao = ref.watch(vaultDaoProvider);
    final deck = await dao.getDeck(deckId);
    if (deck != null) {
      // Real deck persisted in SQLite: emit real items unless only starter placeholder exists
      yield* dao.watchDeckItems(deckId).map((items) {
        if (deckId == MockDeckData.edgarMarkovDeckId && items.length <= 1 && MockDeckData.getDeckItems(deckId).isNotEmpty) {
          return MockDeckData.getDeckItems(deckId);
        }
        return items;
      });
    } else {
      // Non-persisted mock deck: emit mock items
      yield* dao.watchDeckItems(deckId).map((items) {
        if (items.isEmpty) {
          return MockDeckData.getDeckItems(deckId);
        }
        return items;
      }).handleError((error, stackTrace) {
        debugPrint('[deckItemsProvider] Error loading deck items stream for $deckId: $error\n$stackTrace');
        return MockDeckData.getDeckItems(deckId);
      });
    }
  } catch (error, stackTrace) {
    debugPrint('[deckItemsProvider] Error watching deck items for $deckId: $error\n$stackTrace');
    yield MockDeckData.getDeckItems(deckId);
  }
});

final deckVersionsProvider =
    StreamProvider.family<List<DeckVersion>, String>((ref, deckId) {
  try {
    final dao = ref.watch(vaultDaoProvider);
    return dao.watchDeckVersions(deckId).map((versions) {
      if (versions.isEmpty) {
        return MockDeckData.getMockVersions(deckId);
      }
      return versions;
    }).handleError((error, stackTrace) {
      debugPrint('[deckVersionsProvider] Error loading deck versions for $deckId: $error\n$stackTrace');
      return MockDeckData.getMockVersions(deckId);
    });
  } catch (error, stackTrace) {
    debugPrint('[deckVersionsProvider] Error watching deck versions for $deckId: $error\n$stackTrace');
    return Stream.value(MockDeckData.getMockVersions(deckId));
  }
});

final deckMatchupsProvider =
    StreamProvider.family<List<DeckMatchup>, String>((ref, deckId) {
  try {
    final dao = ref.watch(vaultDaoProvider);
    return dao.watchDeckMatchups(deckId).map((matchups) {
      if (matchups.isEmpty) {
        return MockDeckData.getMockMatchups(deckId);
      }
      return matchups;
    }).handleError((error, stackTrace) {
      debugPrint('[deckMatchupsProvider] Error loading deck matchups for $deckId: $error\n$stackTrace');
      return MockDeckData.getMockMatchups(deckId);
    });
  } catch (error, stackTrace) {
    debugPrint('[deckMatchupsProvider] Error watching deck matchups for $deckId: $error\n$stackTrace');
    return Stream.value(MockDeckData.getMockMatchups(deckId));
  }
});

final itemActiveDecksProvider =
    StreamProvider.family<List<String>, String>((ref, vaultItemId) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchItemActiveDecks(vaultItemId);
});

class DeckAnalytics {
  final Map<int, int> manaCurve;
  final Map<String, int> colorDevotion;
  final Map<String, int> colorProduction;
  final double blingPercentage;

  DeckAnalytics({
    required this.manaCurve,
    required this.colorDevotion,
    required this.colorProduction,
    required this.blingPercentage,
  });
}

final deckAnalyticsProvider =
    Provider.family<AsyncValue<DeckAnalytics>, String>((ref, deckId) {
  final itemsAsync = ref.watch(deckItemsProvider(deckId));

  return itemsAsync.whenData((items) {
    final manaCurve = <int, int>{};
    final colorDevotion = <String, int>{};
    final colorProduction = <String, int>{};
    int totalCards = 0;
    int blingCards = 0;

    for (final item in items) {
      final int qty = item['deck_quantity'] as int? ?? 1;
      totalCards += qty;

      // Bling check: graded, altered, signed, misprint, or finishes (foil, etched) / promo
      final isGraded = item['is_graded'] == 1 || item['is_graded'] == true;
      final isAltered = item['is_altered'] == 1 || item['is_altered'] == true;
      final isSigned = item['is_signed'] == 1 || item['is_signed'] == true;
      final isMisprint =
          item['is_misprint'] == 1 || item['is_misprint'] == true;

      bool cardHasBling = isGraded || isAltered || isSigned || isMisprint;

      final dynamicDataStr = item['dynamic_data'] as String?;
      if (dynamicDataStr != null && dynamicDataStr.isNotEmpty) {
        try {
          final data = jsonDecode(dynamicDataStr) as Map<String, dynamic>;

          if (!cardHasBling) {
            if (data['promo'] == true) {
              cardHasBling = true;
            } else if (data['finishes'] is List) {
              final finishes = (data['finishes'] as List).cast<String>();
              if (finishes.contains('foil') || finishes.contains('etched')) {
                cardHasBling = true;
              }
            } else if (data['frame_effects'] is List) {
              final effects = (data['frame_effects'] as List).cast<String>();
              if (effects.contains('showcase') ||
                  effects.contains('extendedart') ||
                  effects.contains('borderless')) {
                cardHasBling = true;
              }
            }
          }

          // Mana Curve (cmc):
          // Under MTG deckbuilding conventions, Lands do not cost mana and are
          // excluded from the spell mana curve. Non-land 0-cost cards (e.g. Lotus Petal,
          // Pact of Negation, Memnite, Mox Amber) are accurately counted in bucket 0.
          if (!ScryfallSymbolCatalog.isLandCard(data)) {
            final cardCmc = ScryfallSymbolCatalog.resolveCardCmc(data);
            final bucket = cardCmc.round();
            manaCurve[bucket] = (manaCurve[bucket] ?? 0) + qty;
          }

          // Helper to parse mana cost string into devotion
          void parseManaCost(String cost) {
            final matches = RegExp(r'\{([^}]+)\}').allMatches(cost);
            for (final match in matches) {
              final sym = match.group(1)!.toUpperCase();
              if (sym.contains('/')) {
                final parts = sym.split('/');
                for (final part in parts) {
                  if (part != 'P' &&
                      part != '2' &&
                      RegExp(r'^[WUBRGC]$').hasMatch(part)) {
                    colorDevotion[part] = (colorDevotion[part] ?? 0) + qty;
                  }
                }
              } else if (RegExp(r'^[WUBRGC]$').hasMatch(sym)) {
                colorDevotion[sym] = (colorDevotion[sym] ?? 0) + qty;
              }
            }
          }

          // Color Devotion (mana_cost parsing, DFCs/adventures via card_faces)
          final manaCost = data['mana_cost']?.toString();
          if (manaCost != null && manaCost.isNotEmpty) {
            parseManaCost(manaCost);
          } else if (data['card_faces'] is List) {
            for (final face in (data['card_faces'] as List)) {
              if (face is Map && face['mana_cost'] != null) {
                parseManaCost(face['mana_cost'].toString());
              }
            }
          }

          // Color Production (produced_mana)
          final produced = data['produced_mana'] as List<dynamic>?;
          if (produced != null) {
            for (final c in produced) {
              final color = c.toString();
              colorProduction[color] = (colorProduction[color] ?? 0) + qty;
            }
          }
        } catch (error, stackTrace) {
          debugPrint('[deckAnalyticsProvider] Failed parsing dynamicData: $error\n$stackTrace');
        }
      }

      if (cardHasBling) {
        blingCards += qty;
      }
    }

    return DeckAnalytics(
      manaCurve: manaCurve,
      colorDevotion: colorDevotion,
      colorProduction: colorProduction,
      blingPercentage: totalCards > 0 ? (blingCards / totalCards) : 0.0,
    );
  });
});

/// Exposes the aggregate financial metrics and P&L for a deck.
final deckFinancialSummaryProvider =
    Provider.family<DeckFinancialSummary, String>((ref, deckId) {
  final itemsAsync = ref.watch(deckItemsProvider(deckId));
  final currency = ref.watch(baseCurrencyProvider);
  final items = itemsAsync.value ?? const [];
  return DeckValuesCalculator.calculate(
    deckId: deckId,
    items: items,
    currency: currency,
  );
});

/// Exposes the Pareto value concentration calculation for a deck.
final deckParetoDistributionProvider =
    Provider.family<ParetoDistributionResult, String>((ref, deckId) {
  final itemsAsync = ref.watch(deckItemsProvider(deckId));
  final currency = ref.watch(baseCurrencyProvider);
  final items = itemsAsync.value ?? const [];
  final inputCards = <ParetoCardInput>[];
  for (final item in items) {
    if (item is DeckItemWithCard) {
      inputCards.add(ParetoCardInput.fromDeckItemWithCard(item, currency));
    } else {
      inputCards.add(ParetoCardInput.fromDeckItemMap(item));
    }
  }
  return ParetoDistributionCalculator.calculate(
    cards: inputCards,
    targetK: 5,
    currency: currency,
  );
});

// ===========================================================================
// Milestone 2: Dual-Tab Architecture & "My Decks" Providers
// ===========================================================================

/// Canonical mock deck definitions used for UI previews, empty database fallback,
/// and test suites.
final List<Map<String, dynamic>> rawMockDecks = [
  {
    'id': 'deck-edgar-markov',
    'title': 'Edgar Markov Aristocrats',
    'format': 'MTG Commander',
    'cardCount': '100/100',
    'colors': [Colors.white, Colors.black, Colors.red],
    'colorIdentity': ['W', 'B', 'R'],
    'winRate': '68%',
    'tcgDomain': 'mtg',
    'isRegistered': true,
    'isCompetitive': false,
    'commanderName': 'Edgar Markov',
    'commanderImageUrl':
        'https://api.scryfall.com/cards/named?exact=Edgar%20Markov&format=image&version=art_crop',
    'commanderArtCrop':
        'https://api.scryfall.com/cards/named?exact=Edgar%20Markov&format=image&version=art_crop',
  },
  {
    'id': 'deck-charizard-ex',
    'title': 'Charizard ex / Pidgeot ex',
    'format': 'Pokémon Standard',
    'cardCount': '60/60',
    'colors': [Colors.orange, Colors.red],
    'colorIdentity': <String>[],
    'winRate': '74%',
    'tcgDomain': 'pokemon',
    'isRegistered': true,
    'isCompetitive': true,
    'commanderName': 'Charizard ex',
    'commanderImageUrl':
        'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
    'commanderArtCrop':
        'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
  },
  {
    'id': 'deck-yuriko',
    'title': 'Yuriko, the Tiger\'s Shadow',
    'format': 'MTG Commander (cEDH)',
    'cardCount': '100/100',
    'colors': [Colors.blue, Colors.black],
    'colorIdentity': ['U', 'B'],
    'winRate': '82%',
    'tcgDomain': 'mtg',
    'isRegistered': false,
    'isCompetitive': true,
    'commanderName': 'Yuriko, the Tiger\'s Shadow',
    'commanderImageUrl':
        'https://api.scryfall.com/cards/named?exact=Yuriko%2C%20the%20Tiger%27s%20Shadow&format=image&version=art_crop',
    'commanderArtCrop':
        'https://api.scryfall.com/cards/named?exact=Yuriko%2C%20the%20Tiger%27s%20Shadow&format=image&version=art_crop',
  },
  {
    'id': 'deck-lorcana',
    'title': 'Ruby / Amethyst Bounce Control',
    'format': 'Disney Lorcana Core',
    'cardCount': '60/60',
    'colors': [Colors.red, Colors.purple],
    'colorIdentity': <String>[],
    'winRate': '70%',
    'tcgDomain': 'lorcana',
    'isRegistered': false,
    'isCompetitive': false,
    'commanderName': 'Ruby / Amethyst Bounce Control',
    'commanderImageUrl':
        'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
    'commanderArtCrop':
        'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
  },
  {
    'id': 'deck-lost-zone',
    'title': 'Lost Zone Giratina VSTAR',
    'format': 'Pokémon Standard',
    'cardCount': '60/60',
    'colors': [Colors.purple, Colors.teal],
    'colorIdentity': <String>[],
    'winRate': '65%',
    'tcgDomain': 'pokemon',
    'isRegistered': true,
    'isCompetitive': true,
    'commanderName': 'Giratina VSTAR',
    'commanderImageUrl':
        'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
    'commanderArtCrop':
        'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
  },
  {
    'id': 'deck-tron',
    'title': 'Modern Mono-Green Tron',
    'format': 'MTG Modern',
    'cardCount': '75/75',
    'colors': [Colors.green],
    'colorIdentity': ['G'],
    'winRate': '55%',
    'tcgDomain': 'mtg',
    'isRegistered': false,
    'isCompetitive': false,
    'commanderName': 'Karn Liberated',
    'commanderImageUrl':
        'https://cards.scryfall.io/art_crop/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
    'commanderArtCrop':
        'https://cards.scryfall.io/art_crop/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
  },
];

DeckSummary mapMockToDeckSummary(Map<String, dynamic> m) {
  final title = m['title'] as String? ?? 'Untitled Deck';
  final format = m['format'] as String? ?? 'MTG Commander';
  final domain = m['tcgDomain'] as String? ?? 'mtg';
  final isReg = m['isRegistered'] as bool? ?? false;
  final isComp = m['isCompetitive'] as bool? ?? false;
  final countStr = m['cardCount'] as String? ?? '0/100';
  final parts = countStr.split('/');
  final curCount = int.tryParse(parts.first) ?? 0;
  final targetCount =
      parts.length > 1 ? (int.tryParse(parts[1]) ?? 60) : 60;
  final colors = (m['colorIdentity'] as List?)?.cast<String>() ??
      (domain == 'mtg' ? ['W', 'B', 'R'] : <String>[]);

  return DeckSummary(
    id: m['id'] as String,
    name: title,
    format: format,
    tcgDomain: domain,
    isRegistered: isReg,
    isCompetitive: isComp,
    createdAt: DateTime.now(),
    cardCount: curCount,
    targetCardCount: targetCount,
    completeness: targetCount > 0 ? curCount / targetCount : 0.0,
    assemblyStatus: isReg
        ? 'Assembled'
        : (curCount >= targetCount && curCount > 0 ? 'Ready' : 'Draft'),
    colorIdentity: colors,
    commanderName: m['commanderName'] as String?,
    commanderImageUrl: m['commanderImageUrl'] as String?,
    commanderArtCrop: m['commanderArtCrop'] as String?,
    deck: Deck(
      id: m['id'] as String,
      name: title,
      format: format,
      tcgDomain: domain,
      isRegistered: isReg,
      isAssembled: isReg,
      isCompetitive: isComp,
      createdAt: DateTime.now(),
      wins: 0,
      losses: 0,
      draws: 0,
      isCloned: false,
      isDeleted: false,
    ),
  );
}

/// Active top-level tab (0: My Decks, 1: Explore Decks)
final decksTopTabProvider = StateProvider<int>((ref) => 0);

/// Active search query for "My Decks" tab
final myDecksSearchQueryProvider = StateProvider<String>((ref) => '');

/// Selected deck IDs for press-and-hold multi-selection in "My Decks"
final myDecksSelectedIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Active subheader tab in "My Decks" (0: All, 1: Competitive, 2: Draft)
final myDecksSubTabProvider = StateProvider<int>((ref) => 0);

/// Combined summaries for personal decks (SQLite + in-memory mocks)
final myDecksCombinedSummariesProvider = Provider<List<DeckSummary>>((ref) {
  final dbSummaries = ref.watch(deckSummariesProvider).value;
  if (dbSummaries != null && dbSummaries.isNotEmpty) {
    final newInMemSummaries = rawMockDecks
        .where((m) => !dbSummaries.any((s) => s.id == m['id']))
        .map(mapMockToDeckSummary)
        .toList();
    return [...newInMemSummaries, ...dbSummaries];
  }
  return rawMockDecks.map(mapMockToDeckSummary).toList();
});

/// Multi-tier personal deck search results provider
final myDecksSearchResultsProvider =
    FutureProvider<MyDecksSearchResults>((ref) async {
  final query = ref.watch(myDecksSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) {
    return const MyDecksSearchResults();
  }

  final allSummaries = ref.watch(myDecksCombinedSummariesProvider);
  final activeFilter = ref.watch(activeDeckTcgFilterProvider);
  final domainDecks = allSummaries.where((deck) {
    if (activeFilter == 'all') return true;
    return deck.tcgDomain == activeFilter;
  }).toList();

  // Tier 1: Matches in Deck Name
  final inDeckName = domainDecks
      .where((d) => d.name.toLowerCase().contains(query))
      .toList();
  final inDeckNameIds = inDeckName.map((d) => d.id).toSet();

  // Tier 2: Matches in Deck Cards (for decks not already in Tier 1)
  final vaultDao = ref.watch(vaultDaoProvider);
  final inDeckCards = <MyDeckCardMatch>[];

  for (final deck in domainDecks) {
    if (inDeckNameIds.contains(deck.id)) continue;

    String? matchedCardName;
    int matchedQty = 1;

    try {
      final dbItems = await vaultDao.getDeckItems(deck.id);
      if (dbItems.isNotEmpty) {
        for (final item in dbItems) {
          if (item.name.toLowerCase().contains(query)) {
            matchedCardName = item.name;
            matchedQty = item.deckQuantity;
            break;
          }
        }
      }
    } catch (_) {}

    if (matchedCardName == null) {
      final mockItems = MockDeckData.getDeckItems(deck.id);
      for (final item in mockItems) {
        final name = (item['name'] as String? ?? '').toLowerCase();
        if (name.contains(query)) {
          matchedCardName = item['name'] as String?;
          matchedQty = item['deck_quantity'] as int? ?? 1;
          break;
        }
      }
    }

    if (matchedCardName != null) {
      inDeckCards.add(MyDeckCardMatch(
        deck: deck,
        matchingCardName: matchedCardName,
        cardQuantity: matchedQty,
      ));
    }
  }

  return MyDecksSearchResults(
    inDeckName: inDeckName,
    inDeckCards: inDeckCards,
  );
});


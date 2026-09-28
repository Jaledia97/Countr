import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';

/// Comprehensive mock data repository for collectible decks, version histories,
/// matchups, and Scryfall dynamic data dictionaries.
class MockDeckData {
  /// Canonical 100-card MTG Commander Deck ID
  static const String edgarMarkovDeckId = 'deck-edgar-markov';

  /// Default mock Deck entities for UI previews and tests
  static final List<Deck> defaultDecks = [
    Deck(
      id: edgarMarkovDeckId,
      name: 'Edgar Markov Aristocrats',
      format: 'Commander',
      wins: 12,
      losses: 4,
      draws: 0,
      tcgDomain: 'mtg',
      isRegistered: true,
      isAssembled: true,
      isCompetitive: false,
      isDeleted: false,
      createdAt: DateTime.now(),
    ),
    Deck(
      id: 'deck-charizard-ex',
      name: 'Charizard ex / Pidgeot ex',
      format: 'Standard',
      wins: 8,
      losses: 2,
      draws: 1,
      tcgDomain: 'pokemon',
      isRegistered: true,
      isAssembled: true,
      isCompetitive: true,
      isDeleted: false,
      createdAt: DateTime.now(),
    ),
    Deck(
      id: 'deck-yuriko',
      name: "Yuriko, the Tiger's Shadow",
      format: 'Commander (cEDH)',
      wins: 15,
      losses: 7,
      draws: 2,
      tcgDomain: 'mtg',
      isRegistered: false,
      isAssembled: false,
      isCompetitive: true,
      isDeleted: false,
      createdAt: DateTime.now(),
    ),
    Deck(
      id: 'deck-lorcana',
      name: 'Ruby / Amethyst Bounce Control',
      format: 'Core',
      wins: 5,
      losses: 3,
      draws: 0,
      tcgDomain: 'lorcana',
      isRegistered: false,
      isAssembled: false,
      isCompetitive: false,
      isDeleted: false,
      createdAt: DateTime.now(),
    ),
  ];

  /// Retrieves a rich, fully populated list of card maps for the given deck ID.
  /// If the deck ID is unknown or represents the Edgar Markov Commander deck,
  /// returns the canonical 100-card Mardu Aristocrats list.
  static List<Map<String, dynamic>> getDeckItems(String deckId) {
    final lower = deckId.toLowerCase();
    if (lower.contains('charizard') || lower.contains('pokemon')) {
      return _pokemonCharizardItems;
    }
    if (lower.contains('tron')) {
      return _modernTronItems;
    }
    // Default to the full 100-card Edgar Markov Commander deck for all other IDs
    return _edgarMarkovItems;
  }

  /// Retrieves mock version history for a deck
  static List<DeckVersion> getMockVersions(String deckId) {
    final now = DateTime.now();
    return [
      DeckVersion(
        id: 'ver-$deckId-3',
        deckId: deckId,
        versionNumber: 3,
        versionNote:
            'Added Charismatic Conqueror and Bloodtithe Harvester; cut Bloodline Necromancer',
        isActive: true,
        isDeleted: false,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      DeckVersion(
        id: 'ver-$deckId-2',
        deckId: deckId,
        versionNumber: 2,
        versionNote:
            'Upgraded mana base with Savai Triome, Vault of Champions, and Luxury Suite',
        isActive: false,
        isDeleted: false,
        createdAt: now.subtract(const Duration(days: 14)),
      ),
      DeckVersion(
        id: 'ver-$deckId-1',
        deckId: deckId,
        versionNumber: 1,
        versionNote: 'Initial Commander 100-card Edgar Markov deck assembly',
        isActive: false,
        isDeleted: false,
        createdAt: now.subtract(const Duration(days: 45)),
      ),
    ];
  }

  /// Retrieves mock matchup records and sideboard recommendations
  static List<DeckMatchup> getMockMatchups(String deckId) {
    return [
      DeckMatchup(
        id: 'match-$deckId-1',
        deckId: deckId,
        opponentArchetype: 'Golgari Aristocrats / Midrange',
        notes:
            'Favorable matchup. Maintain sacrificial outlets up to prevent life drain locks.',
        swapInItemIds: 'edgar-card-toxic-deluge,edgar-card-swords',
        swapOutItemIds: 'edgar-card-champion-of-dusk',
        isDeleted: false,
      ),
      DeckMatchup(
        id: 'match-$deckId-2',
        deckId: deckId,
        opponentArchetype: 'Azorius Control',
        notes:
            'Hold Teferi\'s Protection or Boros Charm for Supreme Verdict. Apply early token pressure.',
        swapInItemIds: 'edgar-card-boros-charm,edgar-card-teferis-protection',
        swapOutItemIds: 'edgar-card-butcher-of-malakir',
        isDeleted: false,
      ),
      DeckMatchup(
        id: 'match-$deckId-3',
        deckId: deckId,
        opponentArchetype: 'Mono-Red Aggro / Burn',
        notes:
            'Stabilize life total with Vito and Cruel Celebrant. Mulligan aggressively for early drops.',
        swapInItemIds: 'edgar-card-vito,edgar-card-cruel-celebrant',
        swapOutItemIds: 'edgar-card-necropotence',
        isDeleted: false,
      ),
    ];
  }

  /// Calculates DeckAnalytics directly from mock items
  static DeckAnalytics getMockAnalytics(String deckId) {
    final items = getDeckItems(deckId);
    return computeAnalyticsFromItems(items);
  }

  /// Pure computation helper to derive analytics from deck items
  static DeckAnalytics computeAnalyticsFromItems(
      List<Map<String, dynamic>> items) {
    final manaCurve = <int, int>{};
    final colorDevotion = <String, int>{};
    final colorProduction = <String, int>{};
    int totalCards = 0;
    int blingCards = 0;

    for (final item in items) {
      final qty = item['deck_quantity'] as int? ?? 1;
      totalCards += qty;

      final isGraded = item['is_graded'] == 1 || item['is_graded'] == true;
      final isAltered = item['is_altered'] == 1 || item['is_altered'] == true;
      final isSigned = item['is_signed'] == 1 || item['is_signed'] == true;

      bool cardHasBling = isGraded || isAltered || isSigned;

      final dynamicDataStr = item['dynamic_data'] as String?;
      if (dynamicDataStr != null && dynamicDataStr.isNotEmpty) {
        try {
          final data = jsonDecode(dynamicDataStr) as Map<String, dynamic>;

          // Check finishes/promo for bling
          if (!cardHasBling) {
            if (data['promo'] == true) {
              cardHasBling = true;
            } else if (data['finishes'] is List) {
              final finishes = data['finishes'] as List;
              if (finishes.any((f) => f == 'foil' || f == 'etched')) {
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

          // Color Devotion (mana_cost & card_faces)
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
        } catch (e, stackTrace) {
          debugPrint('[MockDeckData] Error parsing card dynamicData: $e\n$stackTrace');
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
  }

  // ===========================================================================
  // 100-Card Canonical MTG Commander Deck: Edgar Markov Aristocrats
  // ===========================================================================

  static final Map<String, Map<String, String>> _cardArtLookup = {
    'blood-artist': {
      'normal': 'https://cards.scryfall.io/normal/front/6/9/693dd112-d04a-4404-8fce-74f7e5497312.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/6/9/693dd112-d04a-4404-8fce-74f7e5497312.jpg',
    },
    'cruel-celebrant': {
      'normal': 'https://cards.scryfall.io/normal/front/8/7/87fed6cb-2802-4228-868d-d27385e35f7e.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/8/7/87fed6cb-2802-4228-868d-d27385e35f7e.jpg',
    },
    'cordial-vampire': {
      'normal': 'https://cards.scryfall.io/normal/front/8/c/8c841474-761d-450e-a86d-0a37750976d1.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/8/c/8c841474-761d-450e-a86d-0a37750976d1.jpg',
    },
    'viscera-seer': {
      'normal': 'https://cards.scryfall.io/normal/front/4/8/486fb84c-2234-4b55-a222-3a36db5e1730.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/4/8/486fb84c-2234-4b55-a222-3a36db5e1730.jpg',
    },
    'twilight-prophet': {
      'normal': 'https://cards.scryfall.io/normal/front/7/2/72225695-1774-4b82-901c-69532822ca9d.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/7/2/72225695-1774-4b82-901c-69532822ca9d.jpg',
    },
    'elenda-the-dusk-rose': {
      'normal': 'https://cards.scryfall.io/normal/front/2/5/25e34147-588b-4fd5-8895-340b04123518.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/2/5/25e34147-588b-4fd5-8895-340b04123518.jpg',
    },
    'sol-ring': {
      'normal': 'https://cards.scryfall.io/normal/front/4/c/4c565076-5db2-47ea-8ee0-4a4fd7bb353d.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/4/c/4c565076-5db2-47ea-8ee0-4a4fd7bb353d.jpg',
    },
    'arcane-signet': {
      'normal': 'https://cards.scryfall.io/normal/front/0/4/04397b98-bc92-437e-b0e2-640df2323ffb.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/0/4/04397b98-bc92-437e-b0e2-640df2323ffb.jpg',
    },
    'swords-to-plowshares': {
      'normal': 'https://cards.scryfall.io/normal/front/7/c/7c85d415-460d-4074-b5a1-778ea2ca2c48.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/7/c/7c85d415-460d-4074-b5a1-778ea2ca2c48.jpg',
    },
    'demonic-tutor': {
      'normal': 'https://cards.scryfall.io/normal/front/3/b/3bdbc231-5316-4abd-9d8d-d87cff2c9847.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/3/b/3bdbc231-5316-4abd-9d8d-d87cff2c9847.jpg',
    },
    'skullclamp': {
      'normal': 'https://cards.scryfall.io/normal/front/a/3/a3652ec2-5907-41a4-a367-192a43507d34.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/a/3/a3652ec2-5907-41a4-a367-192a43507d34.jpg',
    },
    'teferis-protection': {
      'normal': 'https://cards.scryfall.io/normal/front/4/8/483fa1cb-1e35-44f2-a143-98c0f107f5ca.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/4/8/483fa1cb-1e35-44f2-a143-98c0f107f5ca.jpg',
    },
    'command-tower': {
      'normal': 'https://cards.scryfall.io/normal/front/0/5/05364120-218b-4338-b856-a1c8a0430c9a.jpg',
      'art_crop': 'https://cards.scryfall.io/art_crop/front/0/5/05364120-218b-4338-b856-a1c8a0430c9a.jpg',
    },
  };

  static Map<String, dynamic> _makeCard({
    required String id,
    required String name,
    required String zone,
    required int qty,
    required double price,
    required int cmc,
    required String manaCost,
    required String typeLine,
    required String rarity,
    required List<String> colors,
    List<String> producedMana = const [],
    List<String> finishes = const ['nonfoil'],
    bool isGraded = false,
    bool isAltered = false,
    bool isSigned = false,
    bool isPromo = false,
    String? imageUrl,
    String? artCropUrl,
    String? normalUrl,
    String? smallUrl,
    String setOrSeries = 'CMM',
    Map<String, dynamic>? extraDynamicData,
  }) {
    final String resolvedArtCropUrl;
    final String resolvedNormalUrl;
    final String resolvedSmallUrl;

    if (artCropUrl != null || normalUrl != null || smallUrl != null || imageUrl != null) {
      resolvedArtCropUrl = artCropUrl ?? imageUrl ?? normalUrl ?? smallUrl!;
      resolvedNormalUrl = normalUrl ?? imageUrl ?? artCropUrl ?? smallUrl!;
      resolvedSmallUrl = smallUrl ?? imageUrl ?? normalUrl ?? artCropUrl!;
    } else if (id == 'edgar-markov') {
      resolvedArtCropUrl =
          'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-45c8-a90d-10b6394c3904.jpg';
      resolvedNormalUrl =
          'https://cards.scryfall.io/normal/front/8/d/8d94b8ec-ecda-45c8-a90d-10b6394c3904.jpg';
      resolvedSmallUrl =
          'https://cards.scryfall.io/small/front/8/d/8d94b8ec-ecda-45c8-a90d-10b6394c3904.jpg';
    } else if (_cardArtLookup.containsKey(id)) {
      final lookup = _cardArtLookup[id]!;
      resolvedArtCropUrl = lookup['art_crop'] ?? lookup['normal']!;
      resolvedNormalUrl = lookup['normal']!;
      resolvedSmallUrl = lookup['small'] ?? lookup['normal']!;
    } else {
      resolvedArtCropUrl = 'https://cards.scryfall.io/art_crop/back.jpg';
      resolvedNormalUrl = 'https://cards.scryfall.io/normal/back.jpg';
      resolvedSmallUrl = 'https://cards.scryfall.io/small/back.jpg';
    }

    final dyn = <String, dynamic>{
      'cmc': cmc,
      'mana_cost': manaCost,
      'type_line': typeLine,
      'rarity': rarity,
      'colors': colors,
      'produced_mana': producedMana,
      'finishes': finishes,
      'promo': isPromo,
      'legalities': {
        'commander': 'legal',
        'mtg commander': 'legal',
        'modern': 'legal',
        'mtg modern': 'legal',
        'legacy': 'legal',
        'vintage': 'legal',
      },
      'prices': {
        'usd': price.toStringAsFixed(2),
        'usd_foil': (price * 2.2).toStringAsFixed(2),
      },
      'image_uris': {
        'small': resolvedSmallUrl,
        'normal': resolvedNormalUrl,
        'large': resolvedNormalUrl,
        'art_crop': resolvedArtCropUrl,
      },
      if (extraDynamicData != null) ...extraDynamicData,
    };

    return {
      'dvi_id': 'dvi-$id',
      'version_id': 'ver-edgar-3',
      'vault_item_id': id,
      'deck_quantity': qty,
      'board_zone': zone,
      'is_proxy': 0,
      'id': id,
      'name': name,
      'set_or_series': setOrSeries,
      'image_url': dyn['image_uris']['normal'],
      'dynamic_data': jsonEncode(dyn),
      'current_market_price': price,
      'vault_quantity': qty,
      'is_graded': isGraded ? 1 : 0,
      'condition': 'NM',
      'is_altered': isAltered ? 1 : 0,
      'is_misprint': 0,
      'is_signed': isSigned ? 1 : 0,
    };
  }

  static final List<Map<String, dynamic>> _edgarMarkovItems = [
    // -------------------------------------------------------------------------
    // Commander (1 card)
    // -------------------------------------------------------------------------
    _makeCard(
      id: 'edgar-markov',
      name: 'Edgar Markov',
      zone: 'Commander',
      qty: 1,
      price: 112.50,
      cmc: 6,
      manaCost: '{3}{R}{W}{B}',
      typeLine: 'Legendary Creature — Vampire Knight',
      rarity: 'mythic',
      colors: ['W', 'B', 'R'],
      finishes: ['foil', 'etched'],
      isGraded: true,
    ),

    // -------------------------------------------------------------------------
    // Creatures (32 cards)
    // -------------------------------------------------------------------------
    _makeCard(
      id: 'blood-artist',
      name: 'Blood Artist',
      zone: 'Creatures',
      qty: 1,
      price: 4.25,
      cmc: 2,
      manaCost: '{1}{B}',
      typeLine: 'Creature — Vampire',
      rarity: 'uncommon',
      colors: ['B'],
      finishes: ['foil'],
      isSigned: true,
    ),
    _makeCard(
      id: 'cruel-celebrant',
      name: 'Cruel Celebrant',
      zone: 'Creatures',
      qty: 1,
      price: 2.10,
      cmc: 2,
      manaCost: '{W}{B}',
      typeLine: 'Creature — Vampire',
      rarity: 'uncommon',
      colors: ['W', 'B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'cordial-vampire',
      name: 'Cordial Vampire',
      zone: 'Creatures',
      qty: 1,
      price: 3.50,
      cmc: 2,
      manaCost: '{B}{B}',
      typeLine: 'Creature — Vampire',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'viscera-seer',
      name: 'Viscera Seer',
      zone: 'Creatures',
      qty: 1,
      price: 0.75,
      cmc: 1,
      manaCost: '{B}',
      typeLine: 'Creature — Vampire Wizard',
      rarity: 'common',
      colors: ['B'],
    ),
    _makeCard(
      id: 'twilight-prophet',
      name: 'Twilight Prophet',
      zone: 'Creatures',
      qty: 1,
      price: 14.80,
      cmc: 4,
      manaCost: '{2}{B}{B}',
      typeLine: 'Creature — Vampire Cleric',
      rarity: 'mythic',
      colors: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'elenda-the-dusk-rose',
      name: 'Elenda, the Dusk Rose',
      zone: 'Creatures',
      qty: 1,
      price: 11.20,
      cmc: 4,
      manaCost: '{2}{W}{B}',
      typeLine: 'Legendary Creature — Vampire Knight',
      rarity: 'mythic',
      colors: ['W', 'B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'welcoming-vampire',
      name: 'Welcoming Vampire',
      zone: 'Creatures',
      qty: 1,
      price: 3.00,
      cmc: 3,
      manaCost: '{2}{W}',
      typeLine: 'Creature — Vampire Cleric',
      rarity: 'rare',
      colors: ['W'],
    ),
    _makeCard(
      id: 'charismatic-conqueror',
      name: 'Charismatic Conqueror',
      zone: 'Creatures',
      qty: 1,
      price: 18.50,
      cmc: 2,
      manaCost: '{1}{W}',
      typeLine: 'Creature — Vampire Soldier',
      rarity: 'rare',
      colors: ['W'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'captivating-vampire',
      name: 'Captivating Vampire',
      zone: 'Creatures',
      qty: 1,
      price: 8.90,
      cmc: 3,
      manaCost: '{1}{B}{B}',
      typeLine: 'Creature — Vampire',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'stromkirk-captain',
      name: 'Stromkirk Captain',
      zone: 'Creatures',
      qty: 1,
      price: 1.25,
      cmc: 3,
      manaCost: '{1}{B}{R}',
      typeLine: 'Creature — Vampire Soldier',
      rarity: 'uncommon',
      colors: ['B', 'R'],
    ),
    _makeCard(
      id: 'falkenrath-aristocrat',
      name: 'Falkenrath Aristocrat',
      zone: 'Creatures',
      qty: 1,
      price: 1.50,
      cmc: 4,
      manaCost: '{2}{B}{R}',
      typeLine: 'Creature — Vampire',
      rarity: 'mythic',
      colors: ['B', 'R'],
    ),
    _makeCard(
      id: 'vito-thorn-of-the-dusk-rose',
      name: 'Vito, Thorn of the Dusk Rose',
      zone: 'Creatures',
      qty: 1,
      price: 6.75,
      cmc: 3,
      manaCost: '{2}{B}',
      typeLine: 'Legendary Creature — Vampire Cleric',
      rarity: 'rare',
      colors: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'drana-liberator-of-malakir',
      name: 'Drana, Liberator of Malakir',
      zone: 'Creatures',
      qty: 1,
      price: 4.50,
      cmc: 3,
      manaCost: '{1}{B}{B}',
      typeLine: 'Legendary Creature — Vampire Ally',
      rarity: 'mythic',
      colors: ['B'],
    ),
    _makeCard(
      id: 'kalitas-traitor-of-ghet',
      name: 'Kalitas, Traitor of Ghet',
      zone: 'Creatures',
      qty: 1,
      price: 12.00,
      cmc: 4,
      manaCost: '{2}{B}{B}',
      typeLine: 'Legendary Creature — Vampire Warrior',
      rarity: 'mythic',
      colors: ['B'],
    ),
    _makeCard(
      id: 'florian-voldaren-scion',
      name: 'Florian, Voldaren Scion',
      zone: 'Creatures',
      qty: 1,
      price: 0.60,
      cmc: 3,
      manaCost: '{1}{B}{R}',
      typeLine: 'Legendary Creature — Vampire Noble',
      rarity: 'rare',
      colors: ['B', 'R'],
    ),
    _makeCard(
      id: 'bloodtithe-harvester',
      name: 'Bloodtithe Harvester',
      zone: 'Creatures',
      qty: 1,
      price: 1.10,
      cmc: 2,
      manaCost: '{B}{R}',
      typeLine: 'Creature — Vampire',
      rarity: 'uncommon',
      colors: ['B', 'R'],
    ),
    _makeCard(
      id: 'dusk-legion-zealot',
      name: 'Dusk Legion Zealot',
      zone: 'Creatures',
      qty: 1,
      price: 0.35,
      cmc: 2,
      manaCost: '{1}{B}',
      typeLine: 'Creature — Vampire Cleric',
      rarity: 'common',
      colors: ['B'],
    ),
    _makeCard(
      id: 'vampire-nighthawk',
      name: 'Vampire Nighthawk',
      zone: 'Creatures',
      qty: 1,
      price: 0.50,
      cmc: 3,
      manaCost: '{1}{B}{B}',
      typeLine: 'Creature — Vampire Shaman',
      rarity: 'uncommon',
      colors: ['B'],
    ),
    _makeCard(
      id: 'legion-lieutenant',
      name: 'Legion Lieutenant',
      zone: 'Creatures',
      qty: 1,
      price: 0.85,
      cmc: 2,
      manaCost: '{W}{B}',
      typeLine: 'Creature — Vampire Soldier',
      rarity: 'uncommon',
      colors: ['W', 'B'],
    ),
    _makeCard(
      id: 'mavren-fein-dusk-apostle',
      name: 'Mavren Fein, Dusk Apostle',
      zone: 'Creatures',
      qty: 1,
      price: 2.20,
      cmc: 3,
      manaCost: '{2}{W}',
      typeLine: 'Legendary Creature — Vampire Cleric',
      rarity: 'rare',
      colors: ['W'],
    ),
    _makeCard(
      id: 'olivia-voldaren',
      name: 'Olivia Voldaren',
      zone: 'Creatures',
      qty: 1,
      price: 4.80,
      cmc: 4,
      manaCost: '{2}{B}{R}',
      typeLine: 'Legendary Creature — Vampire',
      rarity: 'mythic',
      colors: ['B', 'R'],
    ),
    _makeCard(
      id: 'anowon-the-ruin-sage',
      name: 'Anowon, the Ruin Sage',
      zone: 'Creatures',
      qty: 1,
      price: 1.40,
      cmc: 5,
      manaCost: '{3}{B}{B}',
      typeLine: 'Legendary Creature — Vampire Shaman',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'butcher-of-malakir',
      name: 'Butcher of Malakir',
      zone: 'Creatures',
      qty: 1,
      price: 0.75,
      cmc: 7,
      manaCost: '{5}{B}{B}',
      typeLine: 'Creature — Vampire Warrior',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'patron-of-the-vein',
      name: 'Patron of the Vein',
      zone: 'Creatures',
      qty: 1,
      price: 5.50,
      cmc: 6,
      manaCost: '{4}{B}{B}',
      typeLine: 'Creature — Vampire Shaman',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'forerunner-of-the-legion',
      name: 'Forerunner of the Legion',
      zone: 'Creatures',
      qty: 1,
      price: 1.30,
      cmc: 3,
      manaCost: '{2}{W}',
      typeLine: 'Creature — Vampire Knight',
      rarity: 'uncommon',
      colors: ['W'],
    ),
    _makeCard(
      id: 'bloodghast',
      name: 'Bloodghast',
      zone: 'Creatures',
      qty: 1,
      price: 7.90,
      cmc: 2,
      manaCost: '{B}{B}',
      typeLine: 'Creature — Vampire Spirit',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'indulgent-aristocrat',
      name: 'Indulgent Aristocrat',
      zone: 'Creatures',
      qty: 1,
      price: 0.65,
      cmc: 1,
      manaCost: '{B}',
      typeLine: 'Creature — Vampire',
      rarity: 'uncommon',
      colors: ['B'],
    ),
    _makeCard(
      id: 'silversmote-ghoul',
      name: 'Silversmote Ghoul',
      zone: 'Creatures',
      qty: 1,
      price: 0.40,
      cmc: 3,
      manaCost: '{2}{B}',
      typeLine: 'Creature — Zombie Vampire',
      rarity: 'uncommon',
      colors: ['B'],
    ),
    _makeCard(
      id: 'yahenni-undying-partisan',
      name: 'Yahenni, Undying Partisan',
      zone: 'Creatures',
      qty: 1,
      price: 3.20,
      cmc: 3,
      manaCost: '{2}{B}',
      typeLine: 'Legendary Creature — Aetherborn Vampire',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'knight-of-the-ebon-legion',
      name: 'Knight of the Ebon Legion',
      zone: 'Creatures',
      qty: 1,
      price: 2.80,
      cmc: 1,
      manaCost: '{B}',
      typeLine: 'Creature — Vampire Knight',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'champion-of-dusk',
      name: 'Champion of Dusk',
      zone: 'Creatures',
      qty: 1,
      price: 1.80,
      cmc: 5,
      manaCost: '{3}{B}{B}',
      typeLine: 'Creature — Vampire Knight',
      rarity: 'rare',
      colors: ['B'],
    ),
    // Transforming DFC: Bloodline Keeper // Lord of Lineage
    _makeCard(
      id: 'bloodline-keeper',
      name: 'Bloodline Keeper // Lord of Lineage',
      zone: 'Creatures',
      qty: 1,
      price: 16.50,
      cmc: 4,
      manaCost: '{2}{B}{B}',
      typeLine: 'Creature — Vampire // Creature — Vampire',
      rarity: 'rare',
      colors: ['B'],
      extraDynamicData: {
        'card_faces': [
          {
            'name': 'Bloodline Keeper',
            'mana_cost': '{2}{B}{B}',
            'type_line': 'Creature — Vampire',
            'colors': ['B'],
          },
          {
            'name': 'Lord of Lineage',
            'mana_cost': '',
            'type_line': 'Creature — Vampire',
            'colors': ['B'],
          },
        ],
      },
    ),

    // -------------------------------------------------------------------------
    // Spells (Instants & Sorceries) (18 cards)
    // -------------------------------------------------------------------------
    _makeCard(
      id: 'vampiric-tutor',
      name: 'Vampiric Tutor',
      zone: 'Spells',
      qty: 1,
      price: 38.00,
      cmc: 1,
      manaCost: '{B}',
      typeLine: 'Instant',
      rarity: 'mythic',
      colors: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'demonic-tutor',
      name: 'Demonic Tutor',
      zone: 'Spells',
      qty: 1,
      price: 42.50,
      cmc: 2,
      manaCost: '{1}{B}',
      typeLine: 'Sorcery',
      rarity: 'rare',
      colors: ['B'],
      finishes: ['foil'],
      isPromo: true,
    ),
    _makeCard(
      id: 'swords-to-plowshares',
      name: 'Swords to Plowshares',
      zone: 'Spells',
      qty: 1,
      price: 2.50,
      cmc: 1,
      manaCost: '{W}',
      typeLine: 'Instant',
      rarity: 'uncommon',
      colors: ['W'],
      finishes: ['etched'],
    ),
    _makeCard(
      id: 'path-to-exile',
      name: 'Path to Exile',
      zone: 'Spells',
      qty: 1,
      price: 2.00,
      cmc: 1,
      manaCost: '{W}',
      typeLine: 'Instant',
      rarity: 'uncommon',
      colors: ['W'],
      finishes: ['foil'],
    ),
    // Hybrid Mana spell: Anguished Unmaking {1}{W/B}{B} or {1}{W}{B}
    _makeCard(
      id: 'anguished-unmaking',
      name: 'Anguished Unmaking',
      zone: 'Spells',
      qty: 1,
      price: 5.20,
      cmc: 3,
      manaCost: '{1}{W/B}{B}',
      typeLine: 'Instant',
      rarity: 'rare',
      colors: ['W', 'B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'boros-charm',
      name: 'Boros Charm',
      zone: 'Spells',
      qty: 1,
      price: 3.10,
      cmc: 2,
      manaCost: '{R}{W}',
      typeLine: 'Instant',
      rarity: 'uncommon',
      colors: ['R', 'W'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'teferis-protection',
      name: 'Teferi\'s Protection',
      zone: 'Spells',
      qty: 1,
      price: 26.00,
      cmc: 3,
      manaCost: '{2}{W}',
      typeLine: 'Instant',
      rarity: 'rare',
      colors: ['W'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'deadly-rollick',
      name: 'Deadly Rollick',
      zone: 'Spells',
      qty: 1,
      price: 24.50,
      cmc: 4,
      manaCost: '{3}{B}',
      typeLine: 'Instant',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'crackle-with-power',
      name: 'Crackle with Power',
      zone: 'Spells',
      qty: 1,
      price: 8.50,
      cmc: 5,
      manaCost: '{X}{R}{R}{R}',
      typeLine: 'Sorcery',
      rarity: 'mythic',
      colors: ['R'],
    ),
    _makeCard(
      id: 'toxic-deluge',
      name: 'Toxic Deluge',
      zone: 'Spells',
      qty: 1,
      price: 7.80,
      cmc: 3,
      manaCost: '{2}{B}',
      typeLine: 'Sorcery',
      rarity: 'rare',
      colors: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'blasphemous-act',
      name: 'Blasphemous Act',
      zone: 'Spells',
      qty: 1,
      price: 4.50,
      cmc: 9,
      manaCost: '{8}{R}',
      typeLine: 'Sorcery',
      rarity: 'rare',
      colors: ['R'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'return-to-dust',
      name: 'Return to Dust',
      zone: 'Spells',
      qty: 1,
      price: 0.40,
      cmc: 4,
      manaCost: '{2}{W}{W}',
      typeLine: 'Instant',
      rarity: 'uncommon',
      colors: ['W'],
    ),
    _makeCard(
      id: 'generous-gift',
      name: 'Generous Gift',
      zone: 'Spells',
      qty: 1,
      price: 1.20,
      cmc: 3,
      manaCost: '{2}{W}',
      typeLine: 'Instant',
      rarity: 'uncommon',
      colors: ['W'],
    ),
    _makeCard(
      id: 'chaos-warp',
      name: 'Chaos Warp',
      zone: 'Spells',
      qty: 1,
      price: 1.60,
      cmc: 3,
      manaCost: '{2}{R}',
      typeLine: 'Instant',
      rarity: 'rare',
      colors: ['R'],
    ),
    _makeCard(
      id: 'read-the-bones',
      name: 'Read the Bones',
      zone: 'Spells',
      qty: 1,
      price: 0.30,
      cmc: 3,
      manaCost: '{2}{B}',
      typeLine: 'Sorcery',
      rarity: 'common',
      colors: ['B'],
    ),
    _makeCard(
      id: 'nights-whisper',
      name: 'Night\'s Whisper',
      zone: 'Spells',
      qty: 1,
      price: 1.50,
      cmc: 2,
      manaCost: '{1}{B}',
      typeLine: 'Sorcery',
      rarity: 'common',
      colors: ['B'],
    ),
    // Phyrexian Mana spell: Dismember {1}{B/P}{B/P}
    _makeCard(
      id: 'dismember',
      name: 'Dismember',
      zone: 'Spells',
      qty: 1,
      price: 4.80,
      cmc: 3,
      manaCost: '{1}{B/P}{B/P}',
      typeLine: 'Instant',
      rarity: 'uncommon',
      colors: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'ruinous-ultimatum',
      name: 'Ruinous Ultimatum',
      zone: 'Spells',
      qty: 1,
      price: 6.20,
      cmc: 7,
      manaCost: '{R}{R}{W}{W}{B}{B}{B}',
      typeLine: 'Sorcery',
      rarity: 'rare',
      colors: ['R', 'W', 'B'],
    ),

    // -------------------------------------------------------------------------
    // Artifacts & Enchantments (14 cards)
    // -------------------------------------------------------------------------
    _makeCard(
      id: 'sol-ring',
      name: 'Sol Ring',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 2.10,
      cmc: 1,
      manaCost: '{1}',
      typeLine: 'Artifact',
      rarity: 'uncommon',
      colors: [],
      producedMana: ['C'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'arcane-signet',
      name: 'Arcane Signet',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 1.20,
      cmc: 2,
      manaCost: '{2}',
      typeLine: 'Artifact',
      rarity: 'common',
      colors: [],
      producedMana: ['W', 'B', 'R'],
    ),
    _makeCard(
      id: 'talisman-of-hierarchy',
      name: 'Talisman of Hierarchy',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 1.50,
      cmc: 2,
      manaCost: '{2}',
      typeLine: 'Artifact',
      rarity: 'uncommon',
      colors: [],
      producedMana: ['W', 'B'],
    ),
    _makeCard(
      id: 'talisman-of-indulgence',
      name: 'Talisman of Indulgence',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 2.20,
      cmc: 2,
      manaCost: '{2}',
      typeLine: 'Artifact',
      rarity: 'uncommon',
      colors: [],
      producedMana: ['B', 'R'],
    ),
    _makeCard(
      id: 'talisman-of-conviction',
      name: 'Talisman of Conviction',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 0.90,
      cmc: 2,
      manaCost: '{2}',
      typeLine: 'Artifact',
      rarity: 'uncommon',
      colors: [],
      producedMana: ['R', 'W'],
    ),
    _makeCard(
      id: 'skullclamp',
      name: 'Skullclamp',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 6.80,
      cmc: 1,
      manaCost: '{1}',
      typeLine: 'Artifact — Equipment',
      rarity: 'uncommon',
      colors: [],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'phyrexian-altar',
      name: 'Phyrexian Altar',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 28.50,
      cmc: 3,
      manaCost: '{3}',
      typeLine: 'Artifact',
      rarity: 'rare',
      colors: [],
      producedMana: ['W', 'U', 'B', 'R', 'G'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'ashnods-altar',
      name: 'Ashnod\'s Altar',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 9.40,
      cmc: 3,
      manaCost: '{3}',
      typeLine: 'Artifact',
      rarity: 'uncommon',
      colors: [],
      producedMana: ['C'],
    ),
    _makeCard(
      id: 'black-market-connections',
      name: 'Black Market Connections',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 19.50,
      cmc: 3,
      manaCost: '{2}{B}',
      typeLine: 'Enchantment',
      rarity: 'rare',
      colors: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'smothering-tithe',
      name: 'Smothering Tithe',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 22.00,
      cmc: 4,
      manaCost: '{3}{W}',
      typeLine: 'Enchantment',
      rarity: 'rare',
      colors: ['W'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'necropotence',
      name: 'Necropotence',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 15.00,
      cmc: 3,
      manaCost: '{B}{B}{B}',
      typeLine: 'Enchantment',
      rarity: 'mythic',
      colors: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'phyrexian-arena',
      name: 'Phyrexian Arena',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 3.50,
      cmc: 3,
      manaCost: '{1}{B}{B}',
      typeLine: 'Enchantment',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'dictate-of-erebos',
      name: 'Dictate of Erebos',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 13.80,
      cmc: 5,
      manaCost: '{3}{B}{B}',
      typeLine: 'Enchantment',
      rarity: 'rare',
      colors: ['B'],
    ),
    _makeCard(
      id: 'anointed-procession',
      name: 'Anointed Procession',
      zone: 'Artifacts & Enchantments',
      qty: 1,
      price: 45.00,
      cmc: 4,
      manaCost: '{3}{W}',
      typeLine: 'Enchantment',
      rarity: 'rare',
      colors: ['W'],
      finishes: ['foil'],
    ),

    // -------------------------------------------------------------------------
    // Lands (35 cards)
    // -------------------------------------------------------------------------
    _makeCard(
      id: 'command-tower',
      name: 'Command Tower',
      zone: 'Lands',
      qty: 1,
      price: 0.50,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'common',
      colors: [],
      producedMana: ['W', 'B', 'R'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'nomad-outpost',
      name: 'Nomad Outpost',
      zone: 'Lands',
      qty: 1,
      price: 0.35,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'uncommon',
      colors: [],
      producedMana: ['W', 'B', 'R'],
    ),
    _makeCard(
      id: 'savai-triome',
      name: 'Savai Triome',
      zone: 'Lands',
      qty: 1,
      price: 18.00,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land — Plains Swamp Mountain',
      rarity: 'rare',
      colors: [],
      producedMana: ['W', 'B', 'R'],
    ),
    _makeCard(
      id: 'blood-crypt',
      name: 'Blood Crypt',
      zone: 'Lands',
      qty: 1,
      price: 19.50,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land — Swamp Mountain',
      rarity: 'rare',
      colors: [],
      producedMana: ['B', 'R'],
      isAltered: true,
    ),
    _makeCard(
      id: 'godless-shrine',
      name: 'Godless Shrine',
      zone: 'Lands',
      qty: 1,
      price: 14.00,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land — Plains Swamp',
      rarity: 'rare',
      colors: [],
      producedMana: ['W', 'B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'sacred-foundry',
      name: 'Sacred Foundry',
      zone: 'Lands',
      qty: 1,
      price: 16.50,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land — Mountain Plains',
      rarity: 'rare',
      colors: [],
      producedMana: ['R', 'W'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'vault-of-champions',
      name: 'Vault of Champions',
      zone: 'Lands',
      qty: 1,
      price: 8.50,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['W', 'B'],
    ),
    _makeCard(
      id: 'luxury-suite',
      name: 'Luxury Suite',
      zone: 'Lands',
      qty: 1,
      price: 11.00,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['B', 'R'],
    ),
    _makeCard(
      id: 'spectator-seating',
      name: 'Spectator Seating',
      zone: 'Lands',
      qty: 1,
      price: 9.00,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['R', 'W'],
    ),
    _makeCard(
      id: 'isolated-chapel',
      name: 'Isolated Chapel',
      zone: 'Lands',
      qty: 1,
      price: 2.30,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['W', 'B'],
    ),
    _makeCard(
      id: 'dragonskull-summit',
      name: 'Dragonskull Summit',
      zone: 'Lands',
      qty: 1,
      price: 2.10,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['B', 'R'],
    ),
    _makeCard(
      id: 'clifftop-retreat',
      name: 'Clifftop Retreat',
      zone: 'Lands',
      qty: 1,
      price: 2.40,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['R', 'W'],
    ),
    _makeCard(
      id: 'cavern-of-souls',
      name: 'Cavern of Souls',
      zone: 'Lands',
      qty: 1,
      price: 44.00,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'mythic',
      colors: [],
      producedMana: ['W', 'U', 'B', 'R', 'G', 'C'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'path-of-ancestry',
      name: 'Path of Ancestry',
      zone: 'Lands',
      qty: 1,
      price: 0.30,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'common',
      colors: [],
      producedMana: ['W', 'B', 'R'],
    ),
    _makeCard(
      id: 'bojuka-bog',
      name: 'Bojuka Bog',
      zone: 'Lands',
      qty: 1,
      price: 1.80,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'common',
      colors: [],
      producedMana: ['B'],
    ),
    _makeCard(
      id: 'phyrexian-tower',
      name: 'Phyrexian Tower',
      zone: 'Lands',
      qty: 1,
      price: 22.50,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['B', 'C'],
    ),
    _makeCard(
      id: 'urborg-tomb-of-yawgmoth',
      name: 'Urborg, Tomb of Yawgmoth',
      zone: 'Lands',
      qty: 1,
      price: 36.00,
      cmc: 0,
      manaCost: '',
      typeLine: 'Legendary Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['B'],
      finishes: ['foil'],
    ),
    _makeCard(
      id: 'cabal-coffers',
      name: 'Cabal Coffers',
      zone: 'Lands',
      qty: 1,
      price: 21.00,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land',
      rarity: 'rare',
      colors: [],
      producedMana: ['B'],
      finishes: ['foil'],
    ),
    // 7x Swamps
    for (int i = 1; i <= 7; i++)
      _makeCard(
        id: 'swamp-$i',
        name: 'Swamp',
        zone: 'Lands',
        qty: 1,
        price: 0.15,
        cmc: 0,
        manaCost: '',
        typeLine: 'Basic Land — Swamp',
        rarity: 'common',
        colors: [],
        producedMana: ['B'],
      ),
    // 5x Plains
    for (int i = 1; i <= 5; i++)
      _makeCard(
        id: 'plains-$i',
        name: 'Plains',
        zone: 'Lands',
        qty: 1,
        price: 0.15,
        cmc: 0,
        manaCost: '',
        typeLine: 'Basic Land — Plains',
        rarity: 'common',
        colors: [],
        producedMana: ['W'],
      ),
    // 5x Mountains
    for (int i = 1; i <= 5; i++)
      _makeCard(
        id: 'mountain-$i',
        name: 'Mountain',
        zone: 'Lands',
        qty: 1,
        price: 0.15,
        cmc: 0,
        manaCost: '',
        typeLine: 'Basic Land — Mountain',
        rarity: 'common',
        colors: [],
        producedMana: ['R'],
      ),
  ];

  // ===========================================================================
  // Other Formats Mock Data (Pokémon, Tron)
  // ===========================================================================

  static final List<Map<String, dynamic>> _pokemonCharizardItems = [
    _makeCard(
      id: 'pkm-charizard-ex',
      name: 'Charizard ex',
      zone: 'Pokémon',
      qty: 3,
      price: 38.00,
      cmc: 3,
      manaCost: '{R}{R}{R}',
      typeLine: 'Stage 2 Pokémon ex',
      rarity: 'double rare',
      colors: ['R'],
      finishes: ['foil'],
      setOrSeries: 'OBF',
      imageUrl:
          'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
      artCropUrl:
          'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
    ),
    _makeCard(
      id: 'pkm-pidgeot-ex',
      name: 'Pidgeot ex',
      zone: 'Pokémon',
      qty: 2,
      price: 12.50,
      cmc: 2,
      manaCost: '{C}{C}',
      typeLine: 'Stage 2 Pokémon ex',
      rarity: 'double rare',
      colors: ['C'],
      finishes: ['foil'],
      setOrSeries: 'OBF',
      imageUrl:
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=400&q=80',
      artCropUrl:
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=400&q=80',
    ),
    _makeCard(
      id: 'pkm-rare-candy',
      name: 'Rare Candy',
      zone: 'Trainer',
      qty: 4,
      price: 1.20,
      cmc: 0,
      manaCost: '',
      typeLine: 'Item',
      rarity: 'uncommon',
      colors: [],
      setOrSeries: 'SVI',
      imageUrl:
          'https://images.unsplash.com/photo-1582562124811-c09040d0a901?auto=format&fit=crop&w=400&q=80',
      artCropUrl:
          'https://images.unsplash.com/photo-1582562124811-c09040d0a901?auto=format&fit=crop&w=400&q=80',
    ),
    _makeCard(
      id: 'pkm-fire-energy',
      name: 'Basic Fire Energy',
      zone: 'Energy',
      qty: 8,
      price: 0.25,
      cmc: 0,
      manaCost: '',
      typeLine: 'Basic Energy',
      rarity: 'common',
      colors: ['R'],
      producedMana: ['R'],
      setOrSeries: 'SVI',
      imageUrl:
          'https://images.unsplash.com/photo-1525498128493-380d1990a112?auto=format&fit=crop&w=400&q=80',
      artCropUrl:
          'https://images.unsplash.com/photo-1525498128493-380d1990a112?auto=format&fit=crop&w=400&q=80',
    ),
  ];

  static final List<Map<String, dynamic>> _modernTronItems = [
    _makeCard(
      id: 'tron-karn-liberated',
      name: 'Karn Liberated',
      zone: 'Planeswalkers',
      qty: 4,
      price: 24.00,
      cmc: 7,
      manaCost: '{7}',
      typeLine: 'Legendary Planeswalker — Karn',
      rarity: 'mythic',
      colors: [],
      finishes: ['foil'],
      setOrSeries: '2XM',
      imageUrl:
          'https://cards.scryfall.io/normal/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
      artCropUrl:
          'https://cards.scryfall.io/art_crop/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
    ),
    _makeCard(
      id: 'tron-wurmcoil-engine',
      name: 'Wurmcoil Engine',
      zone: 'Creatures',
      qty: 3,
      price: 18.00,
      cmc: 6,
      manaCost: '{6}',
      typeLine: 'Artifact Creature — Wurm',
      rarity: 'mythic',
      colors: [],
      finishes: ['foil'],
      setOrSeries: '2XM',
      imageUrl:
          'https://cards.scryfall.io/normal/front/d/0/d0a13423-11e1-4466-80d6-bc570f25ebd8.jpg',
      artCropUrl:
          'https://cards.scryfall.io/art_crop/front/d/0/d0a13423-11e1-4466-80d6-bc570f25ebd8.jpg',
    ),
    _makeCard(
      id: 'tron-urzas-tower',
      name: 'Urza\'s Tower',
      zone: 'Lands',
      qty: 4,
      price: 3.50,
      cmc: 0,
      manaCost: '',
      typeLine: 'Land — Urza\'s Tower',
      rarity: 'common',
      colors: [],
      producedMana: ['C'],
      setOrSeries: '2XM',
      imageUrl:
          'https://cards.scryfall.io/normal/front/9/e/9e369f3f-354b-42bf-9b2f-2c1914068393.jpg',
      artCropUrl:
          'https://cards.scryfall.io/art_crop/front/9/e/9e369f3f-354b-42bf-9b2f-2c1914068393.jpg',
    ),
  ];
}

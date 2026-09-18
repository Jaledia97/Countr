import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

/// Instantiates an isolated in-memory Drift [AppDatabase] for Phase 3.9 tests.
AppDatabase createPhase39TestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Helper method to construct a standard [VaultItem] for test fixtures.
VaultItem createPhase39Card({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'Core Set',
  String? flavorName,
  String imageUrl = 'https://cards.scryfall.io/large/front/test.jpg',
  double acquiredPrice = 0.0,
  double currentMarketPrice = 0.0,
  int quantity = 1,
  String condition = 'NM',
  bool isGraded = false,
  bool isAltered = false,
  bool isMisprint = false,
  bool isSigned = false,
  String? primaryBinderId,
  Map<String, dynamic>? dynamicDataMap,
}) {
  final now = DateTime(2026, 9, 18);
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    flavorName: flavorName,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: acquiredPrice,
    acquiredDate: now,
    quantity: quantity,
    condition: condition,
    isGraded: isGraded,
    isAltered: isAltered,
    isMisprint: isMisprint,
    isSigned: isSigned,
    personalNotes: null,
    primaryBinderId: primaryBinderId,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: now,
    dynamicData: jsonEncode(dynamicDataMap ?? {}),
  );
}

/// Constructs a raw Scryfall JSON map for an Adventure Card (e.g., Bonecrusher Giant // Stomp).
Map<String, dynamic> createScryfallAdventureJson({
  String id = 'adv-bonecrusher',
  String name = 'Bonecrusher Giant // Stomp',
  String manaCost = '{2}{R}',
  String set = 'eld',
  String setName = 'Throne of Eldraine',
  Map<String, dynamic>? prices,
}) {
  return {
    'id': id,
    'name': name,
    'layout': 'adventure',
    'mana_cost': manaCost,
    'type_line': 'Creature — Giant // Instant — Adventure',
    'oracle_text':
        'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage. // Damage cannot be prevented this turn. Stomp deals 2 damage.',
    'card_faces': [
      {
        'name': 'Bonecrusher Giant',
        'mana_cost': '{2}{R}',
        'type_line': 'Creature — Giant',
        'oracle_text':
            'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage.',
        'power': '4',
        'toughness': '3',
      },
      {
        'name': 'Stomp',
        'mana_cost': '{1}{R}',
        'type_line': 'Instant — Adventure',
        'oracle_text':
            'Damage cannot be prevented this turn. Stomp deals 2 damage.',
      }
    ],
    'image_uris': {
      'normal': 'https://cards.scryfall.io/normal/front/bonecrusher.jpg',
      'small': 'https://cards.scryfall.io/small/front/bonecrusher.jpg',
    },
    'set': set,
    'set_name': setName,
    'prices': prices ?? {'usd': '1.50', 'usd_foil': '4.00'},
  };
}

/// Constructs a raw Scryfall JSON map for a Double-Faced Card (DFC).
Map<String, dynamic> createScryfallDfcJson({
  String id = 'dfc-delver',
  String name = 'Delver of Secrets // Insectile Aberration',
  String layout = 'transform',
  String set = 'isd',
  String setName = 'Innistrad',
  Map<String, dynamic>? prices,
}) {
  return {
    'id': id,
    'name': name,
    'layout': layout,
    'card_faces': [
      {
        'name': 'Delver of Secrets',
        'mana_cost': '{U}',
        'type_line': 'Creature — Human Wizard',
        'oracle_text': 'At the beginning of your upkeep, look at the top card of your library...',
        'power': '1',
        'toughness': '1',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/front/delver_front.jpg',
          'small': 'https://cards.scryfall.io/small/front/delver_front.jpg',
        },
      },
      {
        'name': 'Insectile Aberration',
        'mana_cost': '',
        'type_line': 'Creature — Human Insect',
        'oracle_text': 'Flying',
        'power': '3',
        'toughness': '2',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/front/delver_back.jpg',
          'small': 'https://cards.scryfall.io/small/front/delver_back.jpg',
        },
      }
    ],
    'set': set,
    'set_name': setName,
    'prices': prices ?? {'usd': '2.00', 'usd_foil': '8.00'},
  };
}

/// Constructs a raw Scryfall JSON map for a Universes Beyond card.
Map<String, dynamic> createScryfallUniversesBeyondJson({
  String id = 'ub-one-ring',
  String name = 'The One Ring',
  List<String>? promoTypes,
  List<String>? frameEffects,
  String? securityStamp = 'triangle',
  String set = 'ltr',
  String setName = 'The Lord of the Rings: Tales of Middle-earth',
}) {
  return {
    'id': id,
    'name': name,
    'layout': 'normal',
    'mana_cost': '{4}',
    'type_line': 'Legendary Artifact',
    'oracle_text': 'Indestructible. When The One Ring enters the battlefield...',
    'promo_types': promoTypes ?? ['universes_beyond'],
    ...?frameEffects != null ? {'frame_effects': frameEffects} : null,
    ...?securityStamp != null ? {'security_stamp': securityStamp} : null,
    'image_uris': {
      'normal': 'https://cards.scryfall.io/normal/front/one_ring.jpg',
      'small': 'https://cards.scryfall.io/small/front/one_ring.jpg',
    },
    'set': set,
    'set_name': setName,
    'prices': {'usd': '95.00'},
  };
}

/// Constructs a raw Scryfall JSON map for a Secret Lair Drop card.
Map<String, dynamic> createScryfallSecretLairJson({
  String id = 'sld-ozolith',
  String name = 'The Ozolith',
  String flavorName = 'Adamantium Bonding Tank',
  String set = 'sld',
  String setName = 'Secret Lair Drop',
}) {
  return {
    'id': id,
    'name': name,
    'flavor_name': flavorName,
    'layout': 'normal',
    'mana_cost': '{1}',
    'type_line': 'Legendary Artifact',
    'oracle_text': 'Whenever a creature you control leaves the battlefield...',
    'image_uris': {
      'normal': 'https://cards.scryfall.io/normal/front/ozolith.jpg',
      'small': 'https://cards.scryfall.io/small/front/ozolith.jpg',
    },
    'set': set,
    'set_name': setName,
    'prices': {'usd': '35.00'},
  };
}

/// Helper method to resolve prices according to the strict fallback chain:
/// prices['usd'] -> prices['usd_foil'] -> prices['usd_etched'] -> prices['eur'] -> prices['eur_foil'] -> 0.0
double resolveHierarchicalPrice(Map<String, dynamic>? prices) {
  if (prices == null) return 0.0;
  final usd = double.tryParse(prices['usd']?.toString() ?? '');
  if (usd != null && usd > 0) return usd;

  final usdFoil = double.tryParse(prices['usd_foil']?.toString() ?? '');
  if (usdFoil != null && usdFoil > 0) return usdFoil;

  final usdEtched = double.tryParse(prices['usd_etched']?.toString() ?? '');
  if (usdEtched != null && usdEtched > 0) return usdEtched;

  final eur = double.tryParse(prices['eur']?.toString() ?? '');
  if (eur != null && eur > 0) return eur;

  final eurFoil = double.tryParse(prices['eur_foil']?.toString() ?? '');
  if (eurFoil != null && eurFoil > 0) return eurFoil;

  return 0.0;
}

/// Formats a market price label, ensuring "Check" is strictly eliminated and "Unlisted" or "$" is rendered.
String formatMarketPriceLabel(double price) {
  if (price.isNaN || price.isInfinite || price <= 0.0) return 'Unlisted';
  return '\$${price.toStringAsFixed(2)}';
}

/// Test harness wrapping [CardDetailSheet] in an interactive [PageView.builder]
/// that synchronizes swiping with an underlying [ScrollController].
class CardDetailSwipingTestHarness extends StatefulWidget {
  final List<VaultItem> items;
  final int initialIndex;
  final ScrollController? backgroundScrollController;
  final ValueChanged<int>? onPageChanged;

  const CardDetailSwipingTestHarness({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.backgroundScrollController,
    this.onPageChanged,
  });

  @override
  State<CardDetailSwipingTestHarness> createState() =>
      _CardDetailSwipingTestHarnessState();
}

class _CardDetailSwipingTestHarnessState
    extends State<CardDetailSwipingTestHarness> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    // Programmatically sync underlying background scroll position
    if (widget.backgroundScrollController != null &&
        widget.backgroundScrollController!.hasClients) {
      const itemHeight = 120.0; // standard simulated card row/grid height
      final targetOffset = index * itemHeight;
      widget.backgroundScrollController!.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }

    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('No items to display'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Detail Swiper'),
        leading: IconButton(
          key: const Key('swipe_prev_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_pageController.hasClients) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
        actions: [
          IconButton(
            key: const Key('swipe_next_button'),
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              if (_pageController.hasClients) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        key: const Key('card_detail_page_view'),
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: _handlePageChanged,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return CardDetailSheet(
            key: Key('card_detail_sheet_${item.id}'),
            item: item,
          );
        },
      ),
    );
  }
}

/// Test harness wrapping [FullScreenCardViewer] in an interactive [PageView.builder].
class FullScreenSwipingTestHarness extends StatefulWidget {
  final List<VaultItem> items;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  const FullScreenSwipingTestHarness({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  @override
  State<FullScreenSwipingTestHarness> createState() =>
      _FullScreenSwipingTestHarnessState();
}

class _FullScreenSwipingTestHarnessState
    extends State<FullScreenSwipingTestHarness> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FullScreen Swiper'),
        leading: IconButton(
          key: const Key('fs_swipe_prev_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_pageController.hasClients) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
        actions: [
          IconButton(
            key: const Key('fs_swipe_next_button'),
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              if (_pageController.hasClients) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        key: const Key('fullscreen_page_view'),
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (index) {
          widget.onPageChanged?.call(index);
        },
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return FullScreenCardViewer(
            key: Key('fullscreen_card_viewer_${item.id}'),
            item: item,
          );
        },
      ),
    );
  }
}

/// Seeds standard multi-feature Phase 3.9 cards into SQLite [VaultDao].
Future<void> seedPhase39Catalog(VaultDao dao) async {
  await dao.clearAllItems();

  final items = [
    // 1. Double-Faced Card
    createPhase39Card(
      id: 'dfc-card-1',
      name: 'Delver of Secrets // Insectile Aberration',
      quantity: 1,
      currentMarketPrice: 2.50,
      dynamicDataMap: {
        'layout': 'transform',
        'mana_cost': '{U}',
        'type_line': 'Creature — Human Wizard // Creature — Human Insect',
        'card_faces': [
          {
            'name': 'Delver of Secrets',
            'mana_cost': '{U}',
            'image_uris': {'normal': 'https://cards.scryfall.io/delver_front.jpg'},
          },
          {
            'name': 'Insectile Aberration',
            'mana_cost': '',
            'image_uris': {'normal': 'https://cards.scryfall.io/delver_back.jpg'},
          }
        ],
        'back_image_url': 'https://cards.scryfall.io/delver_back.jpg',
      },
    ),

    // 2. Adventure Card
    createPhase39Card(
      id: 'adv-card-1',
      name: 'Bonecrusher Giant // Stomp',
      quantity: 2, // duplicate for 3x grid badge
      currentMarketPrice: 1.75,
      dynamicDataMap: {
        'layout': 'adventure',
        'mana_cost': '{2}{R}',
        'type_line': 'Creature — Giant // Instant — Adventure',
        'oracle_text':
            'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage. // Damage cannot be prevented this turn. Stomp deals 2 damage.',
        'card_faces': [
          {
            'name': 'Bonecrusher Giant',
            'mana_cost': '{2}{R}',
            'type_line': 'Creature — Giant',
            'oracle_text':
                'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage.',
          },
          {
            'name': 'Stomp',
            'mana_cost': '{1}{R}',
            'type_line': 'Instant — Adventure',
            'oracle_text':
                'Damage cannot be prevented this turn. Stomp deals 2 damage.',
          }
        ],
      },
    ),

    // 3. Universes Beyond Card
    createPhase39Card(
      id: 'ub-card-1',
      name: 'The One Ring',
      setOrSeries: 'LTR',
      quantity: 1,
      currentMarketPrice: 90.0,
      dynamicDataMap: {
        'layout': 'normal',
        'mana_cost': '{4}',
        'type_line': 'Legendary Artifact',
        'is_universes_beyond': true,
        'promo_types': ['universes_beyond'],
        'security_stamp': 'triangle',
        'cmc': 4.0,
        'colors': ['C'],
      },
    ),

    // 4. Secret Lair Drop with Flavor Name
    createPhase39Card(
      id: 'sld-card-1',
      name: 'The Ozolith',
      flavorName: 'Adamantium Bonding Tank',
      setOrSeries: 'Secret Lair Drop',
      quantity: 3, // duplicate
      currentMarketPrice: 42.0,
      dynamicDataMap: {
        'layout': 'normal',
        'mana_cost': '{1}',
        'set': 'sld',
        'set_code': 'sld',
        'flavor_name': 'Adamantium Bonding Tank',
        'type_line': 'Legendary Artifact',
        'cmc': 1.0,
      },
    ),

    // 5. Unlisted Pricing Fallback Card (no prices)
    createPhase39Card(
      id: 'unlisted-card-1',
      name: 'Mysterious Unlisted Rare',
      quantity: 1,
      currentMarketPrice: 0.0,
      dynamicDataMap: {
        'layout': 'normal',
        'mana_cost': '{3}{U}{U}',
        'prices': {'usd': null, 'usd_foil': null, 'eur': null},
        'cmc': 5.0,
        'colors': ['U'],
      },
    ),
  ];

  for (final card in items) {
    await dao.into(dao.vaultItems).insertOnConflictUpdate(card);
  }
}

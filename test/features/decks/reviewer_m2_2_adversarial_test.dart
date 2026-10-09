import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  const testDeckId = 'adv_test_deck_m2_2';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    required Widget child,
    Size viewportSize = const Size(320, 640),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: SizedBox(
            width: viewportSize.width,
            height: viewportSize.height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Reviewer M2-2 Adversarial Challenge & Layout Robustness Suite', () {
    testWidgets('1. Narrow viewport (320px) with realistic MTG card renders without RenderFlex overflow', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: 'Narrow Viewport Test Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('The Ur-Dragon'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/ur_dragon.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Card with standard MTG name, quantity, 5 mana symbols, and market price
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_standard_card',
          exploreDeckId: testDeckId,
          cardName: 'The Ur-Dragon, Broodmother Scion',
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          typeLine: const Value('Legendary Creature — Dragon Avatar'),
          manaCost: const Value('{4}{W}{U}{B}{R}{G}'),
          price: const Value(15.00),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/ur_dragon.jpg'),
        ),
      );

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
          viewportSize: const Size(320, 640),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull,
          reason: 'Standard cards in ReadOnlyDeckScreen._buildCardRow must not cause RenderFlex overflow on 320px viewport');

      // Verify thumbnail is present and bounded
      final thumbnailFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.minWidth == 40 &&
            widget.constraints?.maxWidth == 40 &&
            widget.constraints?.minHeight == 56 &&
            widget.constraints?.maxHeight == 56 &&
            widget.clipBehavior == Clip.antiAlias,
      );
      expect(thumbnailFinder, findsOneWidget);

      // Verify card name text is rendered with ellipsis
      final nameFinder = find.text('The Ur-Dragon, Broodmother Scion');
      expect(nameFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(nameFinder);
      expect(textWidget.maxLines, equals(1));
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));

      // Verify quantity is rendered
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('2. Screen reader accessibility and semantics tree are preserved with thumbnails', (tester) async {
      final semantics = tester.ensureSemantics();
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_semantics_test',
          name: 'Semantics Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Atraxa, Praetors\' Voice'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/atraxa.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_semantics',
          exploreDeckId: 'deck_semantics_test',
          cardName: 'Sol Ring',
          quantity: const Value(1),
          boardZone: const Value('Artifacts & Enchantments'),
          typeLine: const Value('Artifact'),
          manaCost: const Value('{1}'),
          price: const Value(1.50),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/sol_ring.jpg'),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_semantics_test'),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byType(Semantics);
      expect(semanticsFinder, findsWidgets);
      expect(find.byType(ManaCostBar), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('3. Fallback cache keys (_fallback) strictly isolate disk cache entries', (tester) async {
      // 3.1 ReadOnlyDeckScreen card thumbnail cache keys
      final now = DateTime.now();
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_cache_iso',
          name: 'Cache Isolation Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('The Ur-Dragon'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/ur_dragon.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Art series item
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'iso_art_item',
          exploreDeckId: 'deck_cache_iso',
          cardName: 'Ledger Shredder (Art Card)',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          imageUrl: const Value('https://cards.scryfall.io/art_series/front/shredder.jpg'),
        ),
      );

      // Playable variant item
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'iso_variant_item',
          exploreDeckId: 'deck_cache_iso',
          cardName: 'Ledger Shredder',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/shredder_borderless.jpg'),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_cache_iso'),
        ),
      );
      await tester.pumpAndSettle();

      final images = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      final artItemImage = images.firstWhere((img) => img.cardName == 'Ledger Shredder (Art Card)');
      expect(artItemImage.cacheKey, equals('explore_item_iso_art_item_fallback'),
          reason: 'Art series card must append _fallback to cacheKey to isolate from disk cache');

      final variantItemImage = images.firstWhere((img) => img.cardName == 'Ledger Shredder' && img.imageUrl.contains('borderless'));
      expect(variantItemImage.cacheKey, equals('explore_item_iso_variant_item'),
          reason: 'Playable variant card must use standard cache key without _fallback');
      expect(variantItemImage.cacheKey?.endsWith('_fallback'), isFalse);
    });

    testWidgets('4. DeckBuilderScreen list and grid views isolate cache keys on art series detection', (tester) async {
      final activeDeck = createTestDeck(
        id: 'deck-builder-iso-test',
        name: 'Builder Cache Iso Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
      );

      final normalItem = {
        'id': 'normal-item-1',
        'vault_item_id': 'normal-item-1',
        'name': 'Esper Sentinel',
        'set_or_series': 'MH2',
        'image_url': 'https://cards.scryfall.io/normal/front/esper_sentinel.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Creatures',
        'current_market_price': 30.00,
        'dynamic_data': jsonEncode({'layout': 'normal'}),
      };

      final artItem = {
        'id': 'art-item-2',
        'vault_item_id': 'art-item-2',
        'name': 'Esper Sentinel (Art Card)',
        'set_or_series': 'AMH2',
        'image_url': 'https://cards.scryfall.io/art_series/front/esper_sentinel_art.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Creatures',
        'current_market_price': 1.00,
        'dynamic_data': jsonEncode({'layout': 'art_series'}),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(activeDeck.id).overrideWith(
              (ref) => Stream.value([normalItem, artItem]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: activeDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final images = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      final normalImg = images.firstWhere((img) => img.cardName == 'Esper Sentinel');
      expect(normalImg.cacheKey, equals('card_art_normal-item-1'),
          reason: 'Normal playable card in DeckBuilderScreen must use standard cacheKey');

      final artImg = images.firstWhere((img) => img.cardName == 'Esper Sentinel (Art Card)');
      expect(artImg.cacheKey, equals('card_art_art-item-2_fallback'),
          reason: 'Art card in DeckBuilderScreen must use _fallback cacheKey');
    });

    testWidgets('5. Top banner art in ReadOnlyDeckScreen and ExploreDeckCard safely handles hostile inputs (null/empty/whitespace/unknown)', (tester) async {
      final now = DateTime.now();

      // Case A: ReadOnlyDeckScreen with null commanderName and empty deck name
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_hostile_1',
          name: '',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_series/front/dummy.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_hostile_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Empty deck name and null commanderName must not throw');
      // Should cleanly render fallback banner
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      // Case B: ExploreDeckCard with commanderName = 'Unknown Card' and empty artCrop
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_hostile_2',
          name: 'Unknown Card Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Unknown Card'),
          commanderArtCrop: const Value(''),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final deckWithVote = await exploreDao.getExploreDeck('deck_hostile_2');
      expect(deckWithVote, isNotNull);

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: ExploreDeckCard(deckWithVote: deckWithVote!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Unknown Card and empty commanderArtCrop must not throw');
      expect(find.byType(CountrCachedImage), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('6. DFC and emoji string parsing does not crash and sanitizes correctly', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_dfc_edge',
          name: 'DFC Edge Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Edge 1: Card with trailing slash only
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'dfc_trailing_slash',
          exploreDeckId: 'deck_dfc_edge',
          cardName: 'Valki, God of Lies // ',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
        ),
      );

      // Edge 2: Card with Art Series suffix and emoji
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'emoji_art_card',
          exploreDeckId: 'deck_dfc_edge',
          cardName: 'Phoenix of the Wilds - Art Series',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_dfc_edge'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final images = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final valki = images.firstWhere((img) => img.cardName == 'Valki, God of Lies // ');
      expect(valki.imageUrl, contains('Valki%2C%20God%20of%20Lies'));

      final phoenix = images.firstWhere((img) => img.cardName == 'Phoenix of the Wilds - Art Series');
      expect(phoenix.imageUrl, contains('Phoenix%20of%20the%20Wilds'));
      expect(phoenix.imageUrl, isNot(contains('Art%20Series')));
      expect(phoenix.cacheKey, equals('explore_item_emoji_art_card_fallback'));
    });

    testWidgets('7. Mana cost boundary analysis on narrow 320px viewport', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_mana_stress',
          name: 'Mana Stress Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Jodah, Archmage Eternal'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/jodah.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Card with 6 mana symbols: {1}{W}{U}{B}{R}{G}
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_6_mana',
          exploreDeckId: 'deck_mana_stress',
          cardName: 'Jodah, Archmage Eternal',
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          typeLine: const Value('Legendary Creature — Human Wizard'),
          manaCost: const Value('{1}{W}{U}{B}{R}{G}'),
          price: const Value(3.50),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/jodah.jpg'),
        ),
      );

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_mana_stress'),
          viewportSize: const Size(320, 640),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull, reason: '6 mana symbols on 320px screen should render cleanly');
    });
  });
}

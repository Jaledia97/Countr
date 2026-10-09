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
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  const testDeckId = 'test_variant_precon_deck';
  const testDeckName = 'Draconic Domination Precon';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Milestone 2 Requirement R5: Strict Variant Resolution & Art Series Filter', () {
    testWidgets('1. ReadOnlyDeckScreen card rows render 40x56 CountrCachedImage thumbnails with surfaceRaised and Clip.antiAlias', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('The Ur-Dragon'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/ur_dragon.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_ur_dragon',
          exploreDeckId: testDeckId,
          cardName: 'The Ur-Dragon',
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isCommander: const Value(true),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/ur_dragon_variant.jpg'),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
        ),
      );
      await tester.pumpAndSettle();

      // Find the card row thumbnail container
      final thumbnailContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(Row),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.minWidth == 40 &&
                widget.constraints?.maxWidth == 40 &&
                widget.constraints?.minHeight == 56 &&
                widget.constraints?.maxHeight == 56 &&
                widget.clipBehavior == Clip.antiAlias,
          ),
        ),
      ).toList();

      expect(thumbnailContainers.isNotEmpty, isTrue,
          reason: 'Card row must contain a 40x56 thumbnail container with Clip.antiAlias');

      // Verify CountrCachedImage is rendered inside the thumbnail container
      final cachedImageFinder = find.descendant(
        of: find.byWidget(thumbnailContainers.first),
        matching: find.byType(CountrCachedImage),
      );
      expect(cachedImageFinder, findsOneWidget);

      final cachedImage = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(cachedImage.width, equals(40));
      expect(cachedImage.height, equals(56));
      expect(cachedImage.fit, equals(BoxFit.cover));
      expect(cachedImage.fallbackVersion, equals('normal'));
    });

    testWidgets('2. ReadOnlyDeckScreen preserves exact variant printings (showcase, borderless, retro frame)', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('The Ur-Dragon'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/ur_dragon.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Seed 3 distinct special variants: borderless, showcase, retro frame
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_borderless',
          exploreDeckId: testDeckId,
          cardName: 'Force of Negation',
          quantity: const Value(1),
          boardZone: const Value('Instants & Sorceries'),
          typeLine: const Value('Instant'),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/force_of_negation_borderless.jpg'),
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_showcase',
          exploreDeckId: testDeckId,
          cardName: 'Brazen Borrower',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          typeLine: const Value('Creature — Faerie Rogue'),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/brazen_borrower_showcase.jpg'),
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_retro',
          exploreDeckId: testDeckId,
          cardName: 'Lightning Bolt',
          quantity: const Value(1),
          boardZone: const Value('Instants & Sorceries'),
          typeLine: const Value('Instant'),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/lightning_bolt_retro_frame.jpg'),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      final forceImage = cachedImages.firstWhere((img) => img.cardName == 'Force of Negation');
      expect(forceImage.imageUrl, equals('https://cards.scryfall.io/normal/front/force_of_negation_borderless.jpg'),
          reason: 'Borderless variant printing must be strictly preserved');

      final brazenImage = cachedImages.firstWhere((img) => img.cardName == 'Brazen Borrower');
      expect(brazenImage.imageUrl, equals('https://cards.scryfall.io/normal/front/brazen_borrower_showcase.jpg'),
          reason: 'Showcase variant printing must be strictly preserved');

      final boltImage = cachedImages.firstWhere((img) => img.cardName == 'Lightning Bolt');
      expect(boltImage.imageUrl, equals('https://cards.scryfall.io/normal/front/lightning_bolt_retro_frame.jpg'),
          reason: 'Retro frame variant printing must be strictly preserved');
    });

    testWidgets('3. ReadOnlyDeckScreen strictly filters out non-playable art_series cards with Scryfall named normal fallback', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('The Ur-Dragon'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/ur_dragon.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Card 1: Detected via dynamic_data layout = art_series
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'art_series_dyn_layout',
          exploreDeckId: testDeckId,
          cardName: 'Esper Sentinel',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          typeLine: const Value('Artifact Creature — Human Soldier'),
          imageUrl: const Value('https://cards.scryfall.io/art_crop/front/esper_sentinel_art.jpg'),
          dynamicData: Value(jsonEncode({
            'layout': 'art_series',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/esper_sentinel_art.jpg',
            },
          })),
        ),
      );

      // Card 2: Detected via card name suffix "(Art Card)"
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'art_series_name_suffix',
          exploreDeckId: testDeckId,
          cardName: 'Dauthi Voidwalker (Art Card)',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          typeLine: const Value('Creature — Dauthi Rogue'),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/dauthi_art_crop.jpg'),
        ),
      );

      // Card 3: Detected via Scryfall art_series image URL
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'art_series_cdn_url',
          exploreDeckId: testDeckId,
          cardName: 'Sol Ring',
          quantity: const Value(1),
          boardZone: const Value('Artifacts & Enchantments'),
          typeLine: const Value('Artifact'),
          imageUrl: const Value('https://cards.scryfall.io/art_series/front/sol_ring_front.jpg'),
        ),
      );

      // Card 4: Detected via art series set code (e.g. AMH2)
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'art_series_set_code',
          exploreDeckId: testDeckId,
          cardName: 'Grief',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          typeLine: const Value('Creature — Elemental Incarnation'),
          imageUrl: const Value('https://cards.scryfall.io/front/grief_art.jpg'),
          dynamicData: Value(jsonEncode({
            'set': 'amh2',
          })),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      // Card 1: Esper Sentinel
      final esperImage = cachedImages.firstWhere((img) => img.cardName == 'Esper Sentinel');
      expect(esperImage.imageUrl, isNot(contains('esper_sentinel_art.jpg')));
      expect(esperImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(esperImage.imageUrl, contains('Esper%20Sentinel'));
      expect(esperImage.imageUrl, contains('version=normal'));
      expect(esperImage.cacheKey, equals('explore_item_art_series_dyn_layout_fallback'));

      // Card 2: Dauthi Voidwalker
      final dauthiImage = cachedImages.firstWhere((img) => img.cardName?.contains('Dauthi Voidwalker') == true);
      expect(dauthiImage.imageUrl, isNot(contains('dauthi_art_crop.jpg')));
      expect(dauthiImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(dauthiImage.imageUrl, contains('Dauthi%20Voidwalker'));
      expect(dauthiImage.imageUrl, isNot(contains('Art%20Card')));
      expect(dauthiImage.imageUrl, contains('version=normal'));
      expect(dauthiImage.cacheKey, equals('explore_item_art_series_name_suffix_fallback'));

      // Card 3: Sol Ring
      final solImage = cachedImages.firstWhere((img) => img.cardName == 'Sol Ring');
      expect(solImage.imageUrl, isNot(contains('art_series')));
      expect(solImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(solImage.imageUrl, contains('Sol%20Ring'));
      expect(solImage.imageUrl, contains('version=normal'));
      expect(solImage.cacheKey, equals('explore_item_art_series_cdn_url_fallback'));

      // Card 4: Grief
      final griefImage = cachedImages.firstWhere((img) => img.cardName == 'Grief');
      expect(griefImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(griefImage.imageUrl, contains('Grief'));
      expect(griefImage.imageUrl, contains('version=normal'));
      expect(griefImage.cacheKey, equals('explore_item_art_series_set_code_fallback'));
    });

    testWidgets('4. Top banner art in ReadOnlyDeckScreen sanitizes art_series and falls back to named art_crop', (tester) async {
      final now = DateTime.now();

      // Seed deck with an art_series commander art URL
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_art_series_banner',
          name: 'Ur-Dragon Art Showcase',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('The Ur-Dragon'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_series/front/ur_dragon_art_series.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_art_series_banner'),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final bannerImage = cachedImages.firstWhere((img) => img.cardName == 'The Ur-Dragon');

      // Sanitizes art_series and falls back to named art_crop
      expect(bannerImage.imageUrl, isNot(contains('ur_dragon_art_series.jpg')));
      expect(bannerImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(bannerImage.imageUrl, contains('The%20Ur-Dragon'));
      expect(bannerImage.imageUrl, contains('version=art_crop'));
      expect(bannerImage.cacheKey, equals('explore_cover_deck_art_series_banner_fallback'));
    });

    testWidgets('5. Top banner art in ExploreDeckCard sanitizes art_series and falls back to named art_crop', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'explore_card_art_series',
          name: 'Atraxa Art Showcase',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Atraxa, Praetors\' Voice'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_series/front/atraxa_art.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final deckWithVote = await exploreDao.getExploreDeck('explore_card_art_series');
      expect(deckWithVote, isNotNull);

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Center(
              child: ExploreDeckCard(deckWithVote: deckWithVote!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final bannerImage = cachedImages.firstWhere((img) => img.cardName == 'Atraxa, Praetors\' Voice');

      // Sanitizes art_series and falls back to named art_crop
      expect(bannerImage.imageUrl, isNot(contains('atraxa_art.jpg')));
      expect(bannerImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(bannerImage.imageUrl, contains('Atraxa%2C%20Praetors\'%20Voice'));
      expect(bannerImage.imageUrl, contains('version=art_crop'));
      expect(bannerImage.cacheKey, equals('explore_cover_explore_card_art_series_fallback'));
    });

    testWidgets('6. Top banner art in ExploreDeckCard preserves exact variant art crops', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'explore_card_variant',
          name: 'Edgar Markov Vampire Bloodlust',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Edgar Markov'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/edgar_markov_judge_promo.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final deckWithVote = await exploreDao.getExploreDeck('explore_card_variant');
      expect(deckWithVote, isNotNull);

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Center(
              child: ExploreDeckCard(deckWithVote: deckWithVote!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final bannerImage = cachedImages.firstWhere((img) => img.cardName == 'Edgar Markov');

      // Preserves exact variant art crop
      expect(bannerImage.imageUrl, equals('https://cards.scryfall.io/art_crop/front/edgar_markov_judge_promo.jpg'));
      expect(bannerImage.cacheKey, equals('explore_cover_explore_card_variant'));
    });

    testWidgets('7. DeckBuilderScreen card tile and grid cell bypass standard cache key on art_series detection', (tester) async {
      final activeDeck = createTestDeck(
        id: 'deck-builder-art-test',
        name: 'Art Test Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
      );

      final artSeriesItem = {
        'id': 'art-card-item-1',
        'vault_item_id': 'art-card-item-1',
        'name': 'Ragavan, Nimble Pilferer',
        'set_or_series': 'AMH2',
        'image_url': 'https://cards.scryfall.io/art_series/front/ragavan_art.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Creatures',
        'current_market_price': 50.00,
        'dynamic_data': jsonEncode({
          'layout': 'art_series',
        }),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(activeDeck.id).overrideWith(
              (ref) => Stream.value([artSeriesItem]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: activeDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final ragavanImage = cachedImages.firstWhere((img) => img.cardName == 'Ragavan, Nimble Pilferer');

      // Verify that cache key is bypassed to prevent disk collision with art series card image
      expect(ragavanImage.cacheKey, equals('card_art_art-card-item-1_fallback'));
      expect(ragavanImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(ragavanImage.imageUrl, contains('Ragavan%2C%20Nimble%20Pilferer'));
      expect(ragavanImage.imageUrl, contains('version=normal'));
    });

    testWidgets('8. Top banner in ReadOnlyDeckScreen with empty commanderArtCrop falls back to named art_crop', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_empty_banner',
          name: 'Empty Banner Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          commanderArtCrop: const Value(''),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_empty_banner'),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final bannerImage = cachedImages.firstWhere((img) => img.cardName == 'Morophon, the Boundless');

      expect(bannerImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(bannerImage.imageUrl, contains('Morophon%2C%20the%20Boundless'));
      expect(bannerImage.imageUrl, contains('version=art_crop'));
      expect(bannerImage.cacheKey, equals('explore_cover_deck_empty_banner_fallback'));
    });

    testWidgets('9. Top banner in ReadOnlyDeckScreen with null art crops renders fallback decorative banner cleanly', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_null_banner',
          name: 'Null Banner Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Niv-Mizzet, Parun'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_null_banner'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('10. Top banner in ExploreDeckCard with null art crops renders fallback decorative banner cleanly', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'explore_null_banner',
          name: 'Null Explore Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Krenko, Mob Boss'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final deckWithVote = await exploreDao.getExploreDeck('explore_null_banner');
      expect(deckWithVote, isNotNull);

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Center(
              child: ExploreDeckCard(deckWithVote: deckWithVote!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsNothing);
    });

    testWidgets('11. ReadOnlyDeckScreen card row handles double-faced card (DFC) name splitting gracefully', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_dfc_test',
          name: 'DFC Test Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Nicol Bolas, the Ravager'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/nicol_bolas.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Card with DFC double slash name and empty imageUrl to test Scryfall named normal resolution
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'dfc_card_row',
          exploreDeckId: 'deck_dfc_test',
          cardName: 'Delver of Secrets // Insectile Aberration',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          typeLine: const Value('Creature — Human Wizard'),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'deck_dfc_test'),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final delverImage = cachedImages.firstWhere((img) => img.cardName == 'Delver of Secrets // Insectile Aberration');

      // Resolved clean name should isolate front face 'Delver of Secrets'
      expect(delverImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(delverImage.imageUrl, contains('Delver%20of%20Secrets'));
      expect(delverImage.imageUrl, isNot(contains('Insectile%20Aberration')));
      expect(delverImage.imageUrl, contains('version=normal'));
    });
  });
}

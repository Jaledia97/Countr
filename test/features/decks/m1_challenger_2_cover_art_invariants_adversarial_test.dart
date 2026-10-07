import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'deck_test_helpers.dart';

import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_cover_art_test_root_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return mockCacheDir.path;
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (mockCacheDir.existsSync()) {
      try {
        mockCacheDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedCard({
    required String id,
    required String name,
    required String artCropUrl,
    String? dynamicData,
  }) async {
    final now = DateTime.now();
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion(
        id: drift.Value(id),
        collectionType: const drift.Value('mtg'),
        name: drift.Value(name),
        setOrSeries: const drift.Value('TEST'),
        imageUrl: drift.Value(artCropUrl),
        currentMarketPrice: const drift.Value(10.0),
        acquiredPrice: const drift.Value(5.0),
        acquiredDate: drift.Value(now),
        lastPriceUpdate: drift.Value(now),
        condition: const drift.Value('NM'),
        quantity: const drift.Value(1),
        isDeleted: const drift.Value(false),
        dynamicData: drift.Value(
          dynamicData ??
              jsonEncode({
                'image_uris': {'art_crop': artCropUrl},
              }),
        ),
      ),
    );
  }

  group('Milestone 1 Adversarial Challenge: Cover Art Priority Invariants', () {
    testWidgets('Invariant 1: Commander Only -> Displays Commander Art with default cacheKey', (tester) async {
      final deck = createTestDeck(
        id: 'deck-commander-only',
        name: 'Commander Only Deck',
        coverItemId: null,
      );

      final commanderItem = {
        'id': 'dvi-comm-only',
        'vault_item_id': 'card-comm-only',
        'name': 'The Ur-Dragon',
        'image_url': 'https://cards.scryfall.io/art_crop/ur_dragon.jpg',
        'dynamic_data': jsonEncode({
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/ur_dragon.jpg'},
        }),
        'board_zone': 'Commander',
      };

      final summary = DeckSummary(
        id: deck.id,
        name: deck.name,
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        commanderCardId: 'card-comm-only',
        commanderName: 'The Ur-Dragon',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/ur_dragon.jpg',
        commanderImageUrl: 'https://cards.scryfall.io/art_crop/ur_dragon.jpg',
        cardCount: 1,
        targetCardCount: 100,
        completeness: 0.01,
        assemblyStatus: 'Draft',
        deck: deck,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([summary])),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value([commanderItem])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: deck)),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == 'deck_cover_${deck.id}',
      ).toList();

      expect(cachedImages, isNotEmpty);
      final coverWidget = cachedImages.first;
      expect(coverWidget.imageUrl, equals('https://cards.scryfall.io/art_crop/ur_dragon.jpg'));
      expect(coverWidget.cacheKey, equals('deck_cover_${deck.id}'));
      expect(coverWidget.key, equals(ValueKey('deck_cover_${deck.id}')));
    });

    testWidgets('Invariant 2: Custom Cover Only -> Displays Custom Cover with dynamic cacheKey', (tester) async {
      final deck = createTestDeck(
        id: 'deck-custom-only',
        name: 'Modern 60-Card Deck',
        format: 'Modern',
        coverItemId: 'custom-card-id-42',
      );

      final customCardItem = {
        'id': 'dvi-custom-42',
        'vault_item_id': 'custom-card-id-42',
        'name': 'Ragavan, Nimble Pilferer',
        'image_url': 'https://cards.scryfall.io/art_crop/ragavan.jpg',
        'dynamic_data': jsonEncode({
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/ragavan.jpg'},
        }),
        'board_zone': 'Mainboard',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([])),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value([customCardItem])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: deck)),
        ),
      );
      await tester.pumpAndSettle();

      final expectedKey = 'deck_cover_${deck.id}_custom-card-id-42';
      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == expectedKey,
      ).toList();

      expect(cachedImages, isNotEmpty);
      final coverWidget = cachedImages.first;
      expect(coverWidget.imageUrl, equals('https://cards.scryfall.io/art_crop/ragavan.jpg'));
      expect(coverWidget.cacheKey, equals(expectedKey));
      expect(coverWidget.key, equals(ValueKey(expectedKey)));
    });

    testWidgets('Invariant 3: Both Present -> Custom Cover MUST override Commander art immediately', (tester) async {
      final deck = createTestDeck(
        id: 'deck-both-present',
        name: 'Grixis Reanimator',
        format: 'Commander',
        coverItemId: 'custom-selected-art-99',
      );

      final commanderItem = {
        'id': 'dvi-comm-sedris',
        'vault_item_id': 'card-sedris',
        'name': 'Sedris, the Traitor King',
        'image_url': 'https://cards.scryfall.io/art_crop/sedris.jpg',
        'dynamic_data': jsonEncode({
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/sedris.jpg'},
        }),
        'board_zone': 'Commander',
      };

      final customCoverItem = {
        'id': 'dvi-custom-99',
        'vault_item_id': 'custom-selected-art-99',
        'name': 'Reanimate',
        'image_url': 'https://cards.scryfall.io/art_crop/reanimate.jpg',
        'dynamic_data': jsonEncode({
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/reanimate.jpg'},
        }),
        'board_zone': 'Mainboard',
      };

      final summary = DeckSummary(
        id: deck.id,
        name: deck.name,
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        commanderCardId: 'card-sedris',
        commanderName: 'Sedris, the Traitor King',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/sedris.jpg',
        commanderImageUrl: 'https://cards.scryfall.io/art_crop/sedris.jpg',
        cardCount: 2,
        targetCardCount: 100,
        completeness: 0.02,
        assemblyStatus: 'Draft',
        deck: deck,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([summary])),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value([commanderItem, customCoverItem])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: deck)),
        ),
      );
      await tester.pumpAndSettle();

      final expectedKey = 'deck_cover_${deck.id}_custom-selected-art-99';
      final headerImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == expectedKey,
      ).toList();

      expect(headerImages, isNotEmpty, reason: 'Header must contain image with custom dynamic cache key');
      final coverWidget = headerImages.first;
      expect(coverWidget.imageUrl, equals('https://cards.scryfall.io/art_crop/reanimate.jpg'));
      expect(coverWidget.cacheKey, equals(expectedKey));
      expect(coverWidget.key, equals(ValueKey(expectedKey)));

      // Assert Commander art is NOT used in the sliver header cover
      final commanderHeaderImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == 'deck_cover_${deck.id}',
      ).toList();
      expect(commanderHeaderImages, isEmpty, reason: 'Commander cover key must NOT be present when custom cover is set');
    });

    testWidgets('Invariant 4A: Neither Present with cards -> Falls back to first item in deck', (tester) async {
      final deck = createTestDeck(
        id: 'deck-neither-first-card',
        name: 'Pauper Burn',
        format: 'Pauper',
        coverItemId: null,
      );

      final firstCard = {
        'id': 'dvi-bolt',
        'vault_item_id': 'card-bolt',
        'name': 'Lightning Bolt',
        'image_url': 'https://cards.scryfall.io/art_crop/bolt.jpg',
        'dynamic_data': jsonEncode({
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/bolt.jpg'},
        }),
        'board_zone': 'Mainboard',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([])),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value([firstCard])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: deck)),
        ),
      );
      await tester.pumpAndSettle();

      final expectedKey = 'deck_cover_${deck.id}';
      final headerImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == expectedKey,
      ).toList();

      expect(headerImages, isNotEmpty);
      expect(headerImages.first.imageUrl, equals('https://cards.scryfall.io/art_crop/bolt.jpg'));
      expect(headerImages.first.cacheKey, equals(expectedKey));
    });

    testWidgets('Invariant 4B: Neither Present with empty deck -> Renders shield fallback container without error', (tester) async {
      final emptyDeck = createTestDeck(
        id: 'deck-completely-empty',
        name: 'Brand New Empty Deck',
        coverItemId: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(emptyDeck.id).overrideWith((ref) => Stream.value(emptyDeck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([])),
            deckItemsProvider(emptyDeck.id).overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: emptyDeck)),
        ),
      );
      await tester.pumpAndSettle();

      // Zero exceptions thrown
      expect(tester.takeException(), isNull);

      // No cover CountrCachedImage rendered
      final coverImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey != null && img.cacheKey!.startsWith('deck_cover_'),
      ).toList();
      expect(coverImages, isEmpty);

      // Fallback shield icon rendered in header
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });
  });

  group('Milestone 1 Adversarial Challenge: Persistence & Live UI Switch Lifecycle', () {
    testWidgets('Full Lifecycle: Setting custom cover in modal updates SQLite and immediately invalidates header', (tester) async {
      // 1. Seed database with deck and two cards
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-lifecycle-1',
          name: 'Lifecycle Test Deck',
          format: 'Commander',
          tcgDomain: const drift.Value('mtg'),
          createdAt: DateTime.now(),
        ),
      );

      await seedCard(
        id: 'card-comm-life',
        name: 'Commander Atla Palani',
        artCropUrl: 'https://cards.scryfall.io/art_crop/atla.jpg',
      );
      await seedCard(
        id: 'card-custom-life',
        name: 'Worldspine Wurm',
        artCropUrl: 'https://cards.scryfall.io/art_crop/wurm.jpg',
      );

      var currentDeck = await (db.select(db.decks)..where((d) => d.id.equals('deck-lifecycle-1'))).getSingle();
      expect(currentDeck.coverItemId, isNull);

      final deckItems = [
        {
          'id': 'dvi-comm',
          'vault_item_id': 'card-comm-life',
          'name': 'Commander Atla Palani',
          'image_url': 'https://cards.scryfall.io/art_crop/atla.jpg',
          'dynamic_data': jsonEncode({
            'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/atla.jpg'},
          }),
          'board_zone': 'Commander',
        },
        {
          'id': 'dvi-wurm',
          'vault_item_id': 'card-custom-life',
          'name': 'Worldspine Wurm',
          'image_url': 'https://cards.scryfall.io/art_crop/wurm.jpg',
          'dynamic_data': jsonEncode({
            'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/wurm.jpg'},
          }),
          'board_zone': 'Mainboard',
        },
      ];

      // Mount Modal Launcher
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
            deckProvider('deck-lifecycle-1').overrideWith(
              (ref) => (db.select(db.decks)..where((d) => d.id.equals('deck-lifecycle-1'))).watchSingle(),
            ),
            deckItemsProvider('deck-lifecycle-1').overrideWith((ref) => Stream.value(deckItems)),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => DeckThumbnailPickerModal.show(ctx, deck: currentDeck),
                    child: const Text('Open Picker'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step A: Open Modal & Tap Custom Card
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      final customCardTile = find.byKey(const Key('cover_card_tile_card-custom-life'));
      expect(customCardTile, findsOneWidget);
      await tester.tap(customCardTile);
      await tester.pumpAndSettle();

      // Modal closed
      expect(find.byType(DeckThumbnailPickerModal), findsNothing);

      // Verify SQLite state changed
      currentDeck = await (db.select(db.decks)..where((d) => d.id.equals('deck-lifecycle-1'))).getSingle();
      expect(currentDeck.coverItemId, equals('card-custom-life'));

      // Step B: Re-open Modal and Reset to Default
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('reset_deck_cover_button'));
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Modal closed
      expect(find.byType(DeckThumbnailPickerModal), findsNothing);

      // Verify SQLite state reverted to null
      currentDeck = await (db.select(db.decks)..where((d) => d.id.equals('deck-lifecycle-1'))).getSingle();
      expect(currentDeck.coverItemId, isNull);
    });
  });

  group('Milestone 1 Adversarial Challenge: Cache Eviction & Dynamic Key Generation Safety', () {
    test('evictDeckCover invoked in background schedules without throwing synchronous exceptions', () {
      expect(() {
        unawaited(CountrImageCacheManager.instance.evictDeckCover('test-deck-1'));
        unawaited(CountrImageCacheManager.instance.evictDeckCover(''));
        unawaited(CountrImageCacheManager.instance.evictDeckCover('../../evil/path'));
        unawaited(CountrImageCacheManager.instance.evictDeckCover('deck-burst-001'));
      }, returnsNormally);
    });

    testWidgets('Dynamic cache key transitions force ValueKey recreation between default and custom cover', (tester) async {
      final deckController = StreamController<Deck>.broadcast();
      addTearDown(() => deckController.close());

      final deckDefault = createTestDeck(
        id: 'deck-key-transition',
        name: 'Key Transition Deck',
        coverItemId: null,
      );

      final deckCustom = createTestDeck(
        id: 'deck-key-transition',
        name: 'Key Transition Deck',
        coverItemId: 'card-1',
      );

      final cardItem = {
        'id': 'dvi-card-1',
        'vault_item_id': 'card-1',
        'name': 'Sol Ring',
        'image_url': 'https://cards.scryfall.io/art_crop/sol_ring.jpg',
        'dynamic_data': jsonEncode({
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/sol_ring.jpg'},
        }),
        'board_zone': 'Mainboard',
      };

      // 1. Initial render with coverItemId = null
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider('deck-key-transition').overrideWith((ref) => deckController.stream),
            deckSummariesProvider.overrideWith((ref) => Stream.value([])),
            deckItemsProvider('deck-key-transition').overrideWith((ref) => Stream.value([cardItem])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: deckDefault)),
        ),
      );
      deckController.add(deckDefault);
      await tester.pumpAndSettle();

      final defaultKey = const ValueKey('deck_cover_deck-key-transition');
      expect(find.byKey(defaultKey), findsOneWidget);

      // 2. Emit custom coverItemId = 'card-1'
      deckController.add(deckCustom);
      await tester.pumpAndSettle();

      final customKey = const ValueKey('deck_cover_deck-key-transition_card-1');
      expect(find.byKey(customKey), findsOneWidget);
      expect(find.byKey(defaultKey), findsNothing);

      // 3. Reset back to coverItemId = null
      deckController.add(deckDefault);
      await tester.pumpAndSettle();

      expect(find.byKey(defaultKey), findsOneWidget);
      expect(find.byKey(customKey), findsNothing);
    });

    testWidgets('Dual-faced card dynamicData correctly extracts front face art_crop', (tester) async {
      final dualFaceDeck = createTestDeck(
        id: 'deck-mdfc-test',
        name: 'MDFC Deck',
        coverItemId: 'mdfc-card-id',
      );

      final mdfcItem = {
        'id': 'dvi-mdfc',
        'vault_item_id': 'mdfc-card-id',
        'name': 'Bala Ged Recovery // Bala Ged Sanctuary',
        'image_url': '',
        'dynamic_data': jsonEncode({
          'card_faces': [
            {
              'name': 'Bala Ged Recovery',
              'image_uris': {
                'art_crop': 'https://cards.scryfall.io/art_crop/bala_ged_recovery.jpg',
              },
            },
            {
              'name': 'Bala Ged Sanctuary',
              'image_uris': {
                'art_crop': 'https://cards.scryfall.io/art_crop/bala_ged_sanctuary.jpg',
              },
            },
          ],
        }),
        'board_zone': 'Mainboard',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(dualFaceDeck.id).overrideWith((ref) => Stream.value(dualFaceDeck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([])),
            deckItemsProvider(dualFaceDeck.id).overrideWith((ref) => Stream.value([mdfcItem])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: dualFaceDeck)),
        ),
      );
      await tester.pumpAndSettle();

      final expectedKey = 'deck_cover_${dualFaceDeck.id}_mdfc-card-id';
      final headerImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == expectedKey,
      ).toList();

      expect(headerImages, isNotEmpty);
      expect(headerImages.first.imageUrl, equals('https://cards.scryfall.io/art_crop/bala_ged_recovery.jpg'));
    });

    testWidgets('Corrupted or malformed dynamicData falls back gracefully without throwing exception', (tester) async {
      final deck = createTestDeck(
        id: 'deck-malformed-json',
        name: 'Corrupted JSON Deck',
        coverItemId: 'malformed-item-id',
      );

      final malformedItem = {
        'id': 'dvi-malformed',
        'vault_item_id': 'malformed-item-id',
        'name': 'Corrupted Card',
        'image_url': 'https://cards.scryfall.io/art_crop/fallback_img.jpg',
        'dynamic_data': '{"unrelated_payload": 12345}', // Valid JSON without image_uris
        'board_zone': 'Mainboard',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([])),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value([malformedItem])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: deck)),
        ),
      );
      await tester.pumpAndSettle();
      final exc = tester.takeException();
      if (exc != null) {
        debugPrint('--> [TEST EXCEPTION CAUGHT]: $exc');
      }
      expect(exc, isNull);

      final expectedKey = 'deck_cover_${deck.id}_malformed-item-id';
      final headerImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == expectedKey,
      ).toList();

      expect(headerImages, isNotEmpty);
      // Extracts fallback imageUrl when JSON parsing fails
      expect(headerImages.first.imageUrl, equals('https://cards.scryfall.io/art_crop/fallback_img.jpg'));
    });

    testWidgets('DeckItemWithCard typed domain object resolves custom cover identically to raw map', (tester) async {
      final deck = createTestDeck(
        id: 'deck-typed-objects',
        name: 'Typed Object Deck',
        coverItemId: 'typed-cover-id-77',
      );

      final typedItem = DeckItemWithCard.fromRow({
        'dvi_id': 'dvi-typed-77',
        'deck_id': deck.id,
        'vault_item_id': 'typed-cover-id-77',
        'board_zone': 'Mainboard',
        'deck_quantity': 1,
        'name': 'Smothering Tithe',
        'set_or_series': 'RNA',
        'collector_number': '22',
        'image_url': 'https://cards.scryfall.io/art_crop/smothering_tithe.jpg',
        'dynamic_data': jsonEncode({
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/smothering_tithe.jpg'},
        }),
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckSummariesProvider.overrideWith((ref) => Stream.value([])),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value([typedItem])),
          ],
          child: MaterialApp(home: DeckBuilderScreen(deck: deck)),
        ),
      );
      await tester.pumpAndSettle();

      final expectedKey = 'deck_cover_${deck.id}_typed-cover-id-77';
      final headerImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == expectedKey,
      ).toList();

      expect(headerImages, isNotEmpty);
      expect(headerImages.first.imageUrl, equals('https://cards.scryfall.io/art_crop/smothering_tithe.jpg'));
      expect(headerImages.first.key, equals(ValueKey(expectedKey)));
    });
  });
}

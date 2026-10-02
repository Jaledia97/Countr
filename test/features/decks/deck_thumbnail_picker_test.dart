import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Deck createTestDeck({
    String id = 'deck-1',
    String name = 'Test Commander Deck',
    String? coverItemId,
  }) {
    return Deck(
      id: id,
      name: name,
      format: 'Commander',
      tcgDomain: 'mtg',
      coverItemId: coverItemId,
      isRegistered: false,
      isCompetitive: false,
      isAssembled: false,
      wins: 0,
      losses: 0,
      draws: 0,
      isDeleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> insertTestCard({
    required String id,
    required String name,
    int quantity = 1,
    String? imageUrl,
    String? dynamicData,
  }) async {
    final now = DateTime.now();
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion(
        id: drift.Value(id),
        collectionType: const drift.Value('mtg'),
        name: drift.Value(name),
        setOrSeries: const drift.Value('DOM'),
        imageUrl: drift.Value(imageUrl ?? 'https://cards.scryfall.io/art_crop/card_$id.jpg'),
        currentMarketPrice: const drift.Value(15.0),
        acquiredPrice: const drift.Value(10.0),
        acquiredDate: drift.Value(now),
        lastPriceUpdate: drift.Value(now),
        condition: const drift.Value('NM'),
        quantity: drift.Value(quantity),
        isDeleted: const drift.Value(false),
        dynamicData: drift.Value(dynamicData ?? jsonEncode({
          'mana_cost': '{2}{U}',
          'oracle_id': 'oracle-$id',
          'image_uris': {
            'art_crop': 'https://cards.scryfall.io/art_crop/card_$id.jpg',
          },
        })),
      ),
    );
  }

  Widget createHarness({
    required Deck deck,
    required List<Map<String, dynamic>> deckItems,
    Size viewportSize = const Size(390, 844),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
        deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(deckItems)),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => DeckThumbnailPickerModal.show(ctx, deck: deck),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('DeckThumbnailPickerModal 3x3 Space-Filling Geometry & Cover Selection', () {
    testWidgets('Cards in Deck tab: renders 3-column grid with 3.0 spacing and minimal margins', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deck = createTestDeck();
      final mockItems = [
        {
          'id': 'dvi-1',
          'vault_item_id': 'card-1',
          'name': 'Sol Ring',
          'image_url': 'https://cards.scryfall.io/art_crop/card-1.jpg',
          'dynamic_data': '{"mana_cost":"{1}"}',
        },
        {
          'id': 'dvi-2',
          'vault_item_id': 'card-2',
          'name': 'Rhystic Study',
          'image_url': 'https://cards.scryfall.io/art_crop/card-2.jpg',
          'dynamic_data': '{"mana_cost":"{2}{U}"}',
        },
        {
          'id': 'dvi-3',
          'vault_item_id': 'card-3',
          'name': 'Demonic Tutor',
          'image_url': 'https://cards.scryfall.io/art_crop/card-3.jpg',
          'dynamic_data': '{"mana_cost":"{1}{B}"}',
        },
      ];

      await tester.pumpWidget(createHarness(deck: deck, deckItems: mockItems));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsOneWidget);

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);

      final gridWidget = tester.widget<GridView>(gridFinder);
      expect(gridWidget.padding, equals(const EdgeInsets.fromLTRB(3, 4, 3, 12)));

      final delegate = gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
      expect(delegate.crossAxisSpacing, equals(3.0));
      expect(delegate.mainAxisSpacing, equals(3.0));
      expect(delegate.childAspectRatio, equals(0.72));

      // Check edge-to-edge tile geometry on 390dp screen
      // Total available width: 390. Left+right padding: 3+3 = 6. Remaining: 384.
      // Inter-tile spacing (2 gaps): 2 * 3 = 6. Card width = (384 - 6) / 3 = 126.0.
      final tile1Rect = tester.getRect(find.byKey(const Key('cover_card_tile_card-1')));
      final tile2Rect = tester.getRect(find.byKey(const Key('cover_card_tile_card-2')));
      final tile3Rect = tester.getRect(find.byKey(const Key('cover_card_tile_card-3')));

      expect(tile1Rect.width, closeTo(126.0, 0.5));
      expect(tile2Rect.width, closeTo(126.0, 0.5));
      expect(tile3Rect.width, closeTo(126.0, 0.5));

      // Verify inter-tile gap is exactly 3.0
      expect(tile2Rect.left - tile1Rect.right, closeTo(3.0, 0.5));
      expect(tile3Rect.left - tile2Rect.right, closeTo(3.0, 0.5));
    });

    testWidgets('Search Catalog tab: renders 3-column grid with 3.0 spacing and minimal margins', (tester) async {
      await insertTestCard(id: 'search-card-1', name: 'Counterspell');
      await insertTestCard(id: 'search-card-2', name: 'Countersquall');
      await insertTestCard(id: 'search-card-3', name: 'Counterbalance');

      final deck = createTestDeck();
      await tester.pumpWidget(createHarness(deck: deck, deckItems: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Switch to Search Catalog tab
      await tester.tap(find.byKey(const Key('tab_search_catalog')));
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('deck_thumbnail_catalog_search_input'));
      expect(searchInput, findsOneWidget);

      await tester.enterText(searchInput, 'Counter');
      // Advance debounce timer (300ms)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final catalogGridFinder = find.byType(GridView);
      expect(catalogGridFinder, findsOneWidget);

      final catalogGrid = tester.widget<GridView>(catalogGridFinder);
      expect(catalogGrid.padding, equals(const EdgeInsets.fromLTRB(3, 4, 3, 12)));

      final delegate = catalogGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
      expect(delegate.crossAxisSpacing, equals(3.0));
      expect(delegate.mainAxisSpacing, equals(3.0));
      expect(delegate.childAspectRatio, equals(0.72));

      expect(find.byKey(const Key('cover_card_tile_search-card-1')), findsOneWidget);
      expect(find.byKey(const Key('cover_card_tile_search-card-2')), findsOneWidget);
      expect(find.byKey(const Key('cover_card_tile_search-card-3')), findsOneWidget);
    });

    testWidgets('Selection: currently selected cover card displays cyan border and checkmark badge', (tester) async {
      final deck = createTestDeck(coverItemId: 'card-selected');
      final mockItems = [
        {
          'id': 'dvi-sel',
          'vault_item_id': 'card-selected',
          'name': 'Black Lotus',
          'image_url': 'https://cards.scryfall.io/art_crop/card-selected.jpg',
          'dynamic_data': '{"mana_cost":"{0}"}',
        },
        {
          'id': 'dvi-other',
          'vault_item_id': 'card-other',
          'name': 'Mox Jet',
          'image_url': 'https://cards.scryfall.io/art_crop/card-other.jpg',
          'dynamic_data': '{"mana_cost":"{0}"}',
        },
      ];

      await tester.pumpWidget(createHarness(deck: deck, deckItems: mockItems));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Selected tile has checkmark icon
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Selected tile has cyan border
      final selectedTileFinder = find.byKey(const Key('cover_card_tile_card-selected'));
      expect(selectedTileFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(
        find.descendant(
          of: selectedTileFinder,
          matching: find.byType(Container),
        ).first,
      );
      final decoration = containerWidget.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, equals(AppColors.accentCyan));
      expect(border.top.width, equals(2.5));

      // Reset button is visible when cover is set
      expect(find.byKey(const Key('reset_deck_cover_button')), findsOneWidget);
    });

    testWidgets('Tapping unselected tile updates cover and dismisses modal', (tester) async {
      // Seed deck in database so dao.updateDeckCover succeeds
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-1',
          name: 'Test Commander Deck',
          format: 'Commander',
          tcgDomain: const drift.Value('mtg'),
          createdAt: DateTime.now(),
        ),
      );
      await insertTestCard(id: 'card-tap-1', name: 'Swords to Plowshares');

      final deck = createTestDeck(id: 'deck-1');
      final mockItems = [
        {
          'id': 'dvi-tap',
          'vault_item_id': 'card-tap-1',
          'name': 'Swords to Plowshares',
          'image_url': 'https://cards.scryfall.io/art_crop/card-tap-1.jpg',
          'dynamic_data': '{"mana_cost":"{W}"}',
        },
      ];

      await tester.pumpWidget(createHarness(deck: deck, deckItems: mockItems));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Tap card
      await tester.tap(find.byKey(const Key('cover_card_tile_card-tap-1')));
      await tester.pumpAndSettle();

      // Modal dismissed
      expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsNothing);

      // Check database updated
      final updatedDeck = await (db.select(db.decks)..where((d) => d.id.equals('deck-1'))).getSingle();
      expect(updatedDeck.coverItemId, equals('card-tap-1'));
    });

    testWidgets('Reset button clears coverItemId and dismisses modal', (tester) async {
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-reset-1',
          name: 'Reset Deck',
          format: 'Commander',
          tcgDomain: const drift.Value('mtg'),
          coverItemId: const drift.Value('card-cover-init'),
          createdAt: DateTime.now(),
        ),
      );

      final deck = createTestDeck(id: 'deck-reset-1', coverItemId: 'card-cover-init');
      await tester.pumpWidget(createHarness(deck: deck, deckItems: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('reset_deck_cover_button'));
      expect(resetButton, findsOneWidget);

      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsNothing);

      final updatedDeck = await (db.select(db.decks)..where((d) => d.id.equals('deck-reset-1'))).getSingle();
      expect(updatedDeck.coverItemId, isNull);
    });

    testWidgets('Empty states: displays placeholder texts when deck is empty or search is blank', (tester) async {
      final deck = createTestDeck();
      await tester.pumpWidget(createHarness(deck: deck, deckItems: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Cards in Deck tab is empty
      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);

      // Switch to Search Catalog tab with blank query
      await tester.tap(find.byKey(const Key('tab_search_catalog')));
      await tester.pumpAndSettle();

      expect(find.text('Type a card name to search the MTG catalog.'), findsOneWidget);
    });
  });
}


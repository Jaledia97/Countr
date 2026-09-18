import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/mtg_filter_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

// ============================================================================
// Test Card Factory
// ============================================================================

VaultItem makeChallengerCard({
  required String id,
  required String name,
  String? flavorName,
  int quantity = 1,
  String collectionType = 'mtg',
  String setOrSeries = 'Dominaria',
  String imageUrl = '',
  double acquiredPrice = 10.0,
  double currentMarketPrice = 20.0,
  String condition = 'NM',
  bool isGraded = false,
  Map<String, dynamic>? dynamicData,
  String? rawDynamicData,
}) {
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    flavorName: flavorName,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime(2026, 9, 18),
    quantity: quantity,
    condition: condition,
    isGraded: isGraded,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    personalNotes: null,
    primaryBinderId: null,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2026, 9, 18),
    dynamicData: rawDynamicData ?? jsonEncode(dynamicData ?? {'layout': 'normal'}),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestHarness(
    Widget child, {
    UserPersona persona = UserPersona.investor,
    CardDisplayLayout layout = CardDisplayLayout.grid,
    VaultViewMode viewMode = VaultViewMode.allVault,
    Stream<List<VaultItem>>? itemsStream,
    MtgFilterState? filterState,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        userPersonaProvider.overrideWith((ref) => persona),
        cardDisplayLayoutProvider.overrideWith((ref) => layout),
        activeGameContextProvider.overrideWith((ref) => 'mtg'),
        vaultShowCatalogProvider.overrideWith((ref) => false),
        vaultSearchQueryProvider.overrideWith((ref) => ''),
        vaultPaginationLimitProvider.overrideWith((ref) => 100),
        vaultIsFetchingMoreProvider.overrideWith((ref) => false),
        vaultViewModeProvider.overrideWith((ref) => viewMode),
        if (itemsStream != null)
          vaultItemsStreamProvider.overrideWith((ref) => itemsStream),
        if (filterState != null)
          mtgFilterProvider.overrideWith((ref) => MtgFilterNotifier(filterState)),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: VaultItemTile Stress & Badges
  // ===========================================================================
  group('Adversarial Challenge 1: VaultItemTile Layout, Badges & Overflows', () {
    testWidgets('1.1: Extremely narrow 82px tile with SLAB (top-left) + 999x duplicate badge (top-right) + high price badge renders without overflow', (tester) async {
      final item = makeChallengerCard(
        id: 'tile-narrow-1',
        name: 'The One Ring (Serial 001/001)',
        flavorName: 'Ash Nazg Gimbatul',
        quantity: 999,
        isGraded: true,
        currentMarketPrice: 2000000.0,
      );

      // Render in tight 82x128 box (typical of 300px screen 3-column grid)
      await tester.pumpWidget(
        buildTestHarness(
          Center(
            child: SizedBox(
              width: 82,
              height: 128,
              child: VaultItemTile(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_slab_badge_${item.id}')), findsOneWidget);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsOneWidget);
      expect(find.text('SLAB'), findsOneWidget);
      expect(find.text('999x'), findsOneWidget);
    });

    testWidgets('1.2: Unowned catalog item (quantity 0) renders REF badge at top-right and unlisted price badge cleanly', (tester) async {
      final item = makeChallengerCard(
        id: 'tile-unowned-1',
        name: 'Black Lotus',
        quantity: 0,
        currentMarketPrice: 0.0,
      );

      await tester.pumpWidget(
        buildTestHarness(
          Center(
            child: SizedBox(
              width: 100,
              height: 156,
              child: VaultItemTile(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_unowned_badge_${item.id}')), findsOneWidget);
      expect(find.text('REF'), findsOneWidget);
      expect(find.text('Unlisted'), findsOneWidget);
      expect(find.text('Check'), findsNothing);
    });

    testWidgets('1.3: Foil badge at top-left when condition contains foil and item is not graded', (tester) async {
      final item = makeChallengerCard(
        id: 'tile-foil-1',
        name: 'Sol Ring Foil',
        quantity: 1,
        condition: 'Near Mint Foil',
        isGraded: false,
      );

      await tester.pumpWidget(
        buildTestHarness(
          Center(
            child: SizedBox(
              width: 100,
              height: 156,
              child: VaultItemTile(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_foil_badge_${item.id}')), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      // Since quantity == 1, no duplicate badge
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsNothing);
    });

    testWidgets('1.4: Placeholder art scales down gracefully under 2.0x text scaling without overflow', (tester) async {
      final item = makeChallengerCard(
        id: 'tile-placeholder-1',
        name: 'Super Long Card Name That Tests Placeholder Text Truncation Extensively',
        imageUrl: '',
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: buildTestHarness(
            Center(
              child: SizedBox(
                width: 90,
                height: 140,
                child: VaultItemTile(item: item),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });

  // ===========================================================================
  // SECTION 2: VaultItemCard (List View) Stress
  // ===========================================================================
  group('Adversarial Challenge 2: VaultItemCard List View Thumbnails & Persona Modes', () {
    testWidgets('2.1: Resolves thumbnail from top-level small image_uris with graceful network fallback', (tester) async {
      final item = makeChallengerCard(
        id: 'card-thumb-1',
        name: 'Lightning Bolt',
        imageUrl: '',
        dynamicData: {
          'image_uris': {
            'small': 'https://cards.scryfall.io/small/bolt.jpg',
            'normal': 'https://cards.scryfall.io/normal/bolt.jpg',
          },
        },
      );

      await tester.pumpWidget(
        buildTestHarness(
          SizedBox(
            width: 380,
            child: VaultItemCard(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Leading thumbnail container was created with key
      expect(find.byKey(Key('vault_card_leading_thumbnail_${item.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.2: Resolves thumbnail from DFC card_faces[0] small image_uris', (tester) async {
      final item = makeChallengerCard(
        id: 'card-thumb-dfc',
        name: 'Delver of Secrets // Insectile Aberration',
        imageUrl: '',
        dynamicData: {
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'image_uris': {'small': 'https://cards.scryfall.io/small/delver.jpg'},
            },
            {
              'name': 'Insectile Aberration',
              'image_uris': {'small': 'https://cards.scryfall.io/small/insect.jpg'},
            },
          ],
        },
      );

      await tester.pumpWidget(
        buildTestHarness(
          SizedBox(
            width: 380,
            child: VaultItemCard(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_card_leading_thumbnail_${item.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.3: Falls back to type icon container when imageUrl and dynamicData have no art', (tester) async {
      final item = makeChallengerCard(
        id: 'card-fallback-art',
        name: 'No Art Card',
        collectionType: 'mtg',
        imageUrl: '',
        dynamicData: {},
      );

      await tester.pumpWidget(
        buildTestHarness(
          SizedBox(
            width: 380,
            child: VaultItemCard(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_card_leading_fallback_${item.id}')), findsOneWidget);
      // Verify size 20 icon is in the fallback container
      final fallbackIcon = find.descendant(
        of: find.byKey(Key('vault_card_leading_fallback_${item.id}')),
        matching: find.byIcon(Icons.auto_awesome_rounded),
      );
      expect(fallbackIcon, findsOneWidget);
    });

    testWidgets('2.4: Player mode with 10+ mechanics badges wraps safely without overflow on narrow screen (320px)', (tester) async {
      final item = makeChallengerCard(
        id: 'card-mechanics-overflow',
        name: 'Atraxa, Praetors\' Voice',
        quantity: 1,
        dynamicData: {
          'mana_cost': '{G}{W}{U}{B}',
          'power': '4',
          'toughness': '4',
          'keywords': [
            'Flying',
            'Vigilance',
            'Deathtouch',
            'Lifelink',
            'Proliferate',
            'Indestructible',
            'Trample',
            'First strike',
            'Hexproof',
            'Haste',
          ],
          'oracle_text': 'Flying, vigilance, deathtouch, lifelink',
        },
      );

      await tester.pumpWidget(
        buildTestHarness(
          SizedBox(
            width: 320,
            child: VaultItemCard(item: item),
          ),
          persona: UserPersona.player,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('⚔️ 4 / 🛡️ 4'), findsOneWidget);
      expect(find.text('{G}{W}{U}{B}'), findsOneWidget);
      expect(find.text('Flying'), findsOneWidget);
      expect(find.text('Lifelink'), findsOneWidget);
    });

    testWidgets('2.5: Investor mode with extreme financial numbers on 300px width does not overflow', (tester) async {
      final item = makeChallengerCard(
        id: 'card-investor-overflow',
        name: 'Black Lotus Alpha PSA 10',
        quantity: 15,
        acquiredPrice: 500000.0,
        currentMarketPrice: 1250000.0,
      );

      await tester.pumpWidget(
        buildTestHarness(
          SizedBox(
            width: 300,
            child: VaultItemCard(item: item),
          ),
          persona: UserPersona.investor,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ACQUIRED'), findsOneWidget);
      expect(find.text('LIVE TMV'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });
  });

  // ===========================================================================
  // SECTION 3: CardDetailSheet Swiping, DFC 3D Flips vs Adventure Suppression
  // ===========================================================================
  group('Adversarial Challenge 3: CardDetailSheet Swiping, DFC 3D Flip & Adventure Card Rules Box', () {
    testWidgets('3.1: DFC card provides 3D flip button and toggles between faces; Adventure card strictly disables flip button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dfcCard = makeChallengerCard(
        id: 'dfc-card',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicData: {
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'type_line': 'Creature — Human Wizard',
              'oracle_text': 'At the beginning of your upkeep, look at top card.',
              'image_uris': {'normal': 'https://cards.scryfall.io/delver.jpg'},
            },
            {
              'name': 'Insectile Aberration',
              'type_line': 'Creature — Human Insect',
              'oracle_text': 'Flying',
              'image_uris': {'normal': 'https://cards.scryfall.io/insect.jpg'},
            },
          ],
        },
      );

      final adventureCard = makeChallengerCard(
        id: 'adventure-card',
        name: 'Brazen Borrower // Petty Theft',
        dynamicData: {
          'layout': 'adventure',
          'card_faces': [
            {
              'name': 'Brazen Borrower',
              'type_line': 'Creature — Faerie Rogue',
              'mana_cost': '{1}{U}{U}',
              'oracle_text': 'Flash, flying',
              'power': '3',
              'toughness': '1',
            },
            {
              'name': 'Petty Theft',
              'type_line': 'Instant — Adventure',
              'mana_cost': '{1}{U}',
              'oracle_text': 'Return target nonland permanent to its owner\'s hand.',
            },
          ],
        },
      );

      int? reportedPage;

      await tester.pumpWidget(
        buildTestHarness(
          CardDetailSheet(
            items: [dfcCard, adventureCard],
            initialIndex: 0,
            onPageChanged: (idx) => reportedPage = idx,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // DFC Face 1 verification
      expect(find.text('Delver of Secrets'), findsWidgets);
      final flipBtn = find.byKey(const Key('card_detail_flip_button'));
      expect(flipBtn, findsOneWidget, reason: 'DFC card must render flip button');

      // Tap flip button
      await tester.tap(flipBtn);
      await tester.pumpAndSettle();

      expect(find.text('View Face 1'), findsOneWidget);

      // Now swipe horizontally to Adventure card (Page 1)
      await tester.drag(find.byKey(const Key('card_detail_page_view')), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(reportedPage, equals(1));
      expect(find.text('Brazen Borrower'), findsWidgets);
      expect(find.text('Petty Theft'), findsWidgets);

      // Adventure card must strictly NOT render flip button or face switch button
      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);

      // Adventure unified rules box verification
      expect(find.text('Flash, flying'), findsOneWidget);
      expect(find.text('Return target nonland permanent to its owner\'s hand.'), findsOneWidget);
    });

    testWidgets('3.2: Swiping resets flip state so next card starts on Face 1', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = makeChallengerCard(
        id: 'dfc-1',
        name: 'Card 1 Front // Card 1 Back',
        dynamicData: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Card 1 Front', 'image_uris': {'normal': 'https://front1.jpg'}},
            {'name': 'Card 1 Back', 'image_uris': {'normal': 'https://back1.jpg'}},
          ],
        },
      );

      final card2 = makeChallengerCard(
        id: 'dfc-2',
        name: 'Card 2 Front // Card 2 Back',
        dynamicData: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Card 2 Front', 'image_uris': {'normal': 'https://front2.jpg'}},
            {'name': 'Card 2 Back', 'image_uris': {'normal': 'https://back2.jpg'}},
          ],
        },
      );

      await tester.pumpWidget(
        buildTestHarness(
          CardDetailSheet(
            items: [card1, card2],
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flip card 1 to Face 2
      await tester.tap(find.byKey(const Key('card_detail_flip_button')));
      await tester.pumpAndSettle();
      expect(find.text('View Face 1'), findsOneWidget);

      // Swipe to card 2
      await tester.drag(find.byKey(const Key('card_detail_page_view')), const Offset(-600, 0));
      await tester.pumpAndSettle();

      // Card 2 must be on Face 1, so button says "View Face 2"
      expect(find.text('View Face 2'), findsOneWidget);
    });
  });

  // ===========================================================================
  // SECTION 4: FullScreenCardViewer Swiping, Zoom Locking & Foil Finish
  // ===========================================================================
  group('Adversarial Challenge 4: FullScreenCardViewer Zoom Arbitration & Foil Shader', () {
    testWidgets('4.1: Pinch-to-zoom locks PageView swiping so panning zoomed card does not change pages', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = makeChallengerCard(id: 'fs-1', name: 'Mox Opal');
      final card2 = makeChallengerCard(id: 'fs-2', name: 'Black Lotus');

      await tester.pumpWidget(
        buildTestHarness(
          FullScreenCardViewer(
            items: [card1, card2],
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pageViewFinder = find.byKey(const Key('fullscreen_page_view'));
      expect(pageViewFinder, findsOneWidget);

      // Initial physics must allow scrolling
      final initialPageView = tester.widget<PageView>(pageViewFinder);
      expect(initialPageView.physics, isA<PageScrollPhysics>());

      // Zoom card via TransformationController scale simulation
      final interactiveViewerFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
      expect(interactiveViewerFinder, findsOneWidget);

      final ivWidget = tester.widget<InteractiveViewer>(interactiveViewerFinder);
      final tc = ivWidget.transformationController!;
      tc.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      await tester.pumpAndSettle();

      // Verify physics switched to NeverScrollableScrollPhysics to prevent accidental page swiping
      final zoomedPageView = tester.widget<PageView>(pageViewFinder);
      expect(zoomedPageView.physics, isA<NeverScrollableScrollPhysics>());

      // Attempt swipe while zoomed: page must remain at Card 1
      await tester.drag(pageViewFinder, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_page_fs-1')), findsOneWidget);
      expect(find.byKey(const Key('fullscreen_card_page_fs-2')), findsNothing);

      // Reset zoom to 1.0
      tc.value = Matrix4.identity();
      await tester.pumpAndSettle();

      final resetPageView = tester.widget<PageView>(pageViewFinder);
      expect(resetPageView.physics, isA<PageScrollPhysics>());

      // Now swipe or tap next to navigate to Card 2
      await tester.tap(find.byKey(const Key('fs_swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_page_fs-2')), findsOneWidget);
    });

    testWidgets('4.2: Foil Finish toggle activates ShaderMask and maintains animation across pages', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = makeChallengerCard(id: 'foil-fs-1', name: 'Force of Will');
      final card2 = makeChallengerCard(id: 'foil-fs-2', name: 'Mana Crypt');

      await tester.pumpWidget(
        buildTestHarness(
          FullScreenCardViewer(
            items: [card1, card2],
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no ShaderMask
      expect(find.byType(ShaderMask), findsNothing);

      // Tap Foil Finish
      await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
      // Advance animation frames with pump (instead of pumpAndSettle due to repeating controller)
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShaderMask), findsWidgets);

      // Swipe to next card
      await tester.tap(find.byKey(const Key('fs_swipe_next_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Foil finish remains active on Card 2
      expect(find.byType(ShaderMask), findsWidgets);
      expect(find.byKey(const Key('fullscreen_card_page_foil-fs-2')), findsOneWidget);

      // Turn off foil
      await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  // ===========================================================================
  // SECTION 5: VaultScreen Continuous Background Scroll Synchronization
  // ===========================================================================
  group('Adversarial Challenge 5: VaultScreen Background Scroll Synchronization Lifecycle', () {
    testWidgets('5.1: Swiping in CardDetailSheet scrolls underlying VaultScreen ScrollController continuously', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Populate database with 30 cards
      for (int i = 0; i < 30; i++) {
        await dao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'scroll-card-$i',
            collectionType: 'mtg',
            name: 'Scroll Test Card $i',
            setOrSeries: 'MH3',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: DateTime(2026, 9, 18),
            quantity: const Value(1),
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 10.0 + i,
            lastPriceUpdate: DateTime(2026, 9, 18),
            dynamicData: '{"layout":"normal"}',
          ),
        );
      }

      await tester.pumpWidget(buildTestHarness(const VaultScreen()));
      await tester.pumpAndSettle();

      // Verify grid rendered with items
      expect(find.byKey(const Key('vault_tile_scroll-card-0')), findsOneWidget);

      final scrollableFinder = find.descendant(
        of: find.byKey(const PageStorageKey<String>('vault_custom_scroll_view')),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0));

      // Tap on item 0 to open CardDetailSheet
      final firstCard = find.byType(VaultItemTile).hitTestable().first;
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      // Verify CardDetailSheet opened
      expect(find.byKey(const Key('card_detail_page_view')), findsOneWidget);

      // Fling across cards in sheet to Card 5
      for (int s = 0; s < 5; s++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }

      // Check underlying scroll position on CustomScrollView has moved down
      expect(scrollable.position.pixels, greaterThan(0.0),
          reason: 'Underlying vault scroll view must have scrolled in sync with card detail swiping');

      // Dismiss CardDetailSheet
      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_page_view')), findsNothing);
      expect(scrollable.position.pixels, greaterThan(0.0),
          reason: 'Scroll position must be preserved after dismissing detail sheet');

      // Clean teardown of Drift stream listeners
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('5.2: Scroll sync handles edge bounds (index 0 and unattached controller) without throwing', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = makeChallengerCard(id: 'edge-card-1', name: 'Edge Card');

      // Pump single item sheet with null or unattached controller
      await tester.pumpWidget(
        buildTestHarness(
          CardDetailSheet(
            items: [card],
            initialIndex: 0,
            onPageChanged: (idx) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // SECTION 6: MtgFilterSheet Extreme Viewport & Font Scaling Stability
  // ===========================================================================
  group('Adversarial Challenge 6: MtgFilterSheet Extreme Viewports (300px, 320px) & Text Scaling (1.5x, 2.0x)', () {
    testWidgets('6.1: Ultra-narrow 300px viewport: Sticky action bar, WUBRGC mana buttons, and stats fit without overflow', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyCards = List.generate(
        15,
        (i) => makeChallengerCard(id: 'filter-card-$i', name: 'Card $i'),
      );

      const activeState = MtgFilterState(
        colors: {'W', 'U'},
        rarities: {'rare'},
        manaCost: '{1}{U}',
        typeLine: 'Creature',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MtgFilterSheet(
              initialState: activeState,
              items: dummyCards,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Filter Cards'), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_apply_button')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_bottom_reset_button')), findsOneWidget);

      // Check Circular mana buttons in 300px width
      expect(find.byKey(const Key('filter_chip_color_W')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_color_U')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_color_B')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_color_R')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_color_G')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_color_C')), findsOneWidget);
    });

    testWidgets('6.2: High Text Scaling 2.0x on 320px width: Tab bar, headers, and inputs render cleanly without crashing', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const Scaffold(
              body: MtgFilterSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Filter Cards'), findsOneWidget);

      // Switch to Collection tab
      await tester.tap(find.byKey(const Key('mtg_filter_tab_collection')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Scroll down Collection tab to bring switches into view under 2.0x magnification
      await tester.scrollUntilVisible(
        find.byKey(const Key('filter_switch_graded')),
        250.0,
        scrollable: find.descendant(
          of: find.byType(TabBarView),
          matching: find.byType(Scrollable),
        ).last,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_switch_graded')), findsOneWidget);
      expect(find.byKey(const Key('filter_switch_signed')), findsOneWidget);
    });
  });
}

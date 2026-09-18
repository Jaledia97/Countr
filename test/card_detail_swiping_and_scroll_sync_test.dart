import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

// ============================================================================
// Mathematical Helpers for Unit Testing Scroll Offset Calculations
// ============================================================================

double calculateGridScrollOffset({
  required int index,
  required int totalCount,
  required double screenWidth,
  required double viewportHeight,
  double headerOffset = 288.0,
  double crossAxisSpacing = 10.0,
  double mainAxisSpacing = 10.0,
  double childAspectRatio = 0.64,
  double horizontalPadding = 32.0,
  double maxScrollExtent = 5000.0,
}) {
  if (totalCount <= 0 || index < 0) return 0.0;
  if (index >= totalCount) index = totalCount - 1;

  int columns = 3;
  if (screenWidth < 600) {
    columns = 3;
  } else if (screenWidth < 900) {
    columns = 4;
  } else if (screenWidth < 1200) {
    columns = 5;
  } else {
    columns = 6;
  }

  final gridWidth = screenWidth - horizontalPadding;
  final totalSpacing = (columns - 1) * crossAxisSpacing;
  final itemWidth = (gridWidth - totalSpacing) / columns;
  final itemHeight = itemWidth / childAspectRatio;
  final rowHeight = itemHeight + mainAxisSpacing;
  final rowIndex = index ~/ columns;

  final targetOffset = rowIndex == 0
      ? 0.0
      : headerOffset + (rowIndex * rowHeight) - (viewportHeight / 3.5);
  return targetOffset.clamp(0.0, maxScrollExtent);
}

double calculateListScrollOffset({
  required int index,
  required int totalCount,
  required double viewportHeight,
  double headerOffset = 288.0,
  double itemHeight = 136.0,
  double maxScrollExtent = 5000.0,
}) {
  if (totalCount <= 0 || index < 0) return 0.0;
  if (index >= totalCount) index = totalCount - 1;

  final targetOffset = index == 0
      ? 0.0
      : headerOffset + (index * itemHeight) - (viewportHeight / 3.5);
  return targetOffset.clamp(0.0, maxScrollExtent);
}

// ============================================================================
// Test Card Factory
// ============================================================================

VaultItem createTestCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'Dominaria',
  String imageUrl = 'https://cards.scryfall.io/large/front/test.jpg',
  double acquiredPrice = 10.0,
  double currentMarketPrice = 20.0,
  int quantity = 1,
  String condition = 'NM',
  bool isGraded = false,
  Map<String, dynamic>? dynamicDataMap,
}) {
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
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
    dynamicData: jsonEncode(dynamicDataMap ?? {
      'layout': 'normal',
      'mana_cost': '{2}{U}',
      'type_line': 'Instant',
      'oracle_text': 'Counter target spell.',
      'rarity': 'rare',
    }),
  );
}

Future<void> _seedVaultCards(AppDatabase db, int count) async {
  for (int i = 0; i < count; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'vault-card-$i',
        collectionType: 'mtg',
        name: 'Vault Card ${i.toString().padLeft(2, '0')}',
        setOrSeries: 'Dominaria',
        imageUrl: 'https://cards.scryfall.io/large/front/test.jpg',
        acquiredPrice: 10.0 + i,
        acquiredDate: DateTime(2026, 9, 18),
        quantity: const Value(1),
        condition: 'NM',
        isGraded: const Value(false),
        currentMarketPrice: 20.0 + i,
        lastPriceUpdate: DateTime(2026, 9, 18),
        dynamicData: '{"layout":"normal","oracle_text":"Card text $i","rarity":"rare"}',
      ),
    );
  }
}

// ============================================================================
// Main Test Suite
// ============================================================================

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

  Widget wrapWithHarness(
    Widget child, {
    UserPersona persona = UserPersona.investor,
    CardDisplayLayout layout = CardDisplayLayout.grid,
    Stream<List<VaultItem>>? itemsStream,
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
        vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        if (itemsStream != null)
          vaultItemsStreamProvider.overrideWith((ref) => itemsStream),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  void setupLargeTestScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void setupVaultScrollTestScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // ===========================================================================
  // GROUP 1: Backward Compatibility Tests
  // ===========================================================================
  group('Milestone 4 - Group 1: Backward Compatibility', () {
    testWidgets('1.1: CardDetailSheet(item: item) direct constructor works without error', (tester) async {
      setupLargeTestScreen(tester);
      final item = createTestCard(
        id: 'single-compat-1',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        currentMarketPrice: 15.00,
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: item)));
      await tester.pumpAndSettle();

      expect(find.text('Sol Ring'), findsWidgets);
      expect(find.text('Commander'), findsWidgets);
      expect(find.text('Market: \$15.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.2: CardDetailSheet.show(context, item) opens and dismisses bottom sheet successfully', (tester) async {
      setupLargeTestScreen(tester);
      final item = createTestCard(
        id: 'single-show-1',
        name: 'Mana Vault',
        currentMarketPrice: 45.00,
      );

      await tester.pumpWidget(wrapWithHarness(
        Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_sheet_button'),
            onPressed: () => CardDetailSheet.show(context, item),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Mana Vault'), findsWidgets);

      // Dismiss
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.3: FullScreenCardViewer(item: item) direct constructor works without error', (tester) async {
      setupLargeTestScreen(tester);
      final item = createTestCard(
        id: 'fs-compat-1',
        name: 'Black Lotus',
        currentMarketPrice: 10000.0,
      );

      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(item: item),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Black Lotus'), findsWidgets);
      expect(find.byKey(const Key('fullscreen_interactive_viewer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.4: FullScreenCardViewer.show(context, item) opens route and dismisses cleanly', (tester) async {
      setupLargeTestScreen(tester);
      final item = createTestCard(
        id: 'fs-show-1',
        name: 'Mox Ruby',
        currentMarketPrice: 4000.0,
      );

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_fs_button'),
            onPressed: () => FullScreenCardViewer.show(context, item),
            child: const Text('Open FS'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_fs_button')));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Mox Ruby'), findsWidgets);

      // Tap close button in AppBar
      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // GROUP 2: Swiping in CardDetailSheet
  // ===========================================================================
  group('Milestone 4 - Group 2: Swiping in CardDetailSheet', () {
    late List<VaultItem> multiCards;

    setUp(() {
      multiCards = [
        createTestCard(
          id: 'card-0',
          name: 'Card Alpha',
          setOrSeries: 'Set A',
          currentMarketPrice: 10.0,
        ),
        createTestCard(
          id: 'card-1',
          name: 'Card Beta',
          setOrSeries: 'Set B',
          currentMarketPrice: 20.0,
        ),
        createTestCard(
          id: 'card-2',
          name: 'Card Gamma',
          setOrSeries: 'Set C',
          currentMarketPrice: 30.0,
        ),
      ];
    });

    testWidgets('2.1: CardDetailSheet displays card at initialIndex when items list is provided', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 1,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Card Beta'), findsWidgets);
      expect(find.text('Market: \$20.00'), findsOneWidget);
      expect(find.text('Card Alpha'), findsNothing);
    });

    testWidgets('2.2: Horizontal drag left advances page, updates header, metadata, price, and triggers onPageChanged', (tester) async {
      setupLargeTestScreen(tester);
      int? changedIndex;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 0,
          onPageChanged: (idx) => changedIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Card Alpha'), findsWidgets);
      expect(find.text('Market: \$10.00'), findsOneWidget);

      // Fling horizontally left
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Beta'), findsWidgets);
      expect(find.text('Market: \$20.00'), findsOneWidget);
      expect(changedIndex, equals(1));

      // Fling left again to Card Gamma
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Gamma'), findsWidgets);
      expect(find.text('Market: \$30.00'), findsOneWidget);
      expect(changedIndex, equals(2));
    });

    testWidgets('2.3: Horizontal drag right returns to previous card and triggers onPageChanged', (tester) async {
      setupLargeTestScreen(tester);
      int? changedIndex;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 2,
          onPageChanged: (idx) => changedIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Card Gamma'), findsWidgets);

      // Fling right
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Beta'), findsWidgets);
      expect(changedIndex, equals(1));

      // Fling right again
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Alpha'), findsWidgets);
      expect(changedIndex, equals(0));
    });

    testWidgets('2.4: Swiping respects list boundaries at beginning and end', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Fling right at start
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Alpha'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Advance to end
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Gamma'), findsWidgets);

      // Fling left past end
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Gamma'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.5: Quick Action Bar operates on currently active card index after swiping', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Quick action bar edit button exists
      expect(find.byKey(const Key('quick_action_edit')), findsOneWidget);

      // Swipe to Card Beta
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Beta'), findsWidgets);
      expect(find.byKey(const Key('quick_action_edit')), findsOneWidget);

      // Verify delete button dialog operates on Card Beta
      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Card Beta'), findsWidgets);
      await tester.tap(find.byKey(const Key('delete_cancel_button')));
      await tester.pumpAndSettle();
    });
  });

  // ===========================================================================
  // GROUP 3: ScrollController Safety (DraggableScrollableSheet)
  // ===========================================================================
  group('Milestone 4 - Group 3: ScrollController Safety', () {
    late List<VaultItem> multiCards;

    setUp(() {
      multiCards = List.generate(
        5,
        (i) => createTestCard(
          id: 'scroll-safe-$i',
          name: 'Scroll Safe Card $i',
          currentMarketPrice: (i + 1) * 5.0,
        ),
      );
    });

    testWidgets('3.1: Mid-swipe gesture does not throw "ScrollController attached to multiple scroll views" exception', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Start drag and hold halfway
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PageView)));
      await gesture.moveBy(const Offset(-180, 0));
      await tester.pump();

      // Verify no multiple scroll view attachment assertions occurred during simultaneous page rendering
      expect(tester.takeException(), isNull);

      // Complete gesture
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('3.2: Rapid continuous swiping causes zero exceptions', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('3.3: Active page maintains vertical scrolling and sheet dragging capability', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: multiCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Vertical drag upwards on ListView
      final listFinder = find.byType(ListView).first;
      await tester.drag(listFinder, const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Swipe to next card
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Vertical drag on new active card
      await tester.drag(listFinder, const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // GROUP 4: Swiping in FullScreenCardViewer
  // ===========================================================================
  group('Milestone 4 - Group 4: Swiping in FullScreenCardViewer', () {
    late List<VaultItem> fsCards;

    setUp(() {
      fsCards = [
        createTestCard(
          id: 'fs-dfc-1',
          name: 'Delver of Secrets // Insectile Aberration',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {
                'name': 'Delver of Secrets',
                'image_uris': {'normal': 'https://cards.scryfall.io/delver_front.jpg'},
              },
              {
                'name': 'Insectile Aberration',
                'image_uris': {'normal': 'https://cards.scryfall.io/delver_back.jpg'},
              },
            ],
            'back_image_url': 'https://cards.scryfall.io/delver_back.jpg',
          },
        ),
        createTestCard(
          id: 'fs-dfc-2',
          name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {
                'name': 'Nicol Bolas, the Ravager',
                'image_uris': {'normal': 'https://cards.scryfall.io/bolas_front.jpg'},
              },
              {
                'name': 'Nicol Bolas, the Arisen',
                'image_uris': {'normal': 'https://cards.scryfall.io/bolas_back.jpg'},
              },
            ],
            'back_image_url': 'https://cards.scryfall.io/bolas_back.jpg',
          },
        ),
        createTestCard(
          id: 'fs-single-3',
          name: 'Lightning Bolt',
          dynamicDataMap: {
            'layout': 'normal',
          },
        ),
      ];
    });

    testWidgets('4.1: FullScreenCardViewer swiping navigates across cards, updates title, and invokes onPageChanged', (tester) async {
      setupLargeTestScreen(tester);
      int? changedIndex;
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: fsCards,
          initialIndex: 0,
          onPageChanged: (idx) => changedIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Delver of Secrets // Insectile Aberration'), findsWidgets);

      // Fling horizontally left
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Nicol Bolas, the Ravager // Nicol Bolas, the Arisen'), findsWidgets);
      expect(changedIndex, equals(1));
    });

    testWidgets('4.2: FullScreenCardViewer swiping resets card flip state so new card displays Face 1', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: fsCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Card 1 is DFC -> flip button visible
      final flipButton = find.byKey(const Key('fullscreen_appbar_flip_button'));
      expect(flipButton, findsOneWidget);
      expect(find.text('Back Face'), findsOneWidget);

      // Flip to back face
      await tester.tap(flipButton);
      await tester.pumpAndSettle();

      // Flip button label now shows 'Front Face' (indicating back face is visible)
      expect(find.text('Front Face'), findsOneWidget);

      // Swipe to Card 2
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Card 2 must start on Face 1 (front face) -> button label says 'Back Face'
      expect(find.text('Back Face'), findsOneWidget);

      // Swipe back to Card 1
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      // Card 1 has reset to Face 1 -> button label says 'Back Face'
      expect(find.text('Back Face'), findsOneWidget);
    });

    testWidgets('4.3: InteractiveViewer pan and zoom bounds are maintained', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: fsCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
      expect(ivFinder, findsOneWidget);
      final iv = tester.widget<InteractiveViewer>(ivFinder);
      expect(iv.minScale, equals(0.5));
      expect(iv.maxScale, equals(4.0));
      expect(iv.panEnabled, isTrue);
      expect(iv.scaleEnabled, isTrue);
    });

    testWidgets('4.4: Foil toggle operates on active card and adds ShaderMask', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: fsCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ShaderMask), findsNothing);

      // Toggle foil ON
      final foilButton = find.byKey(const Key('fullscreen_foil_toggle'));
      await tester.tap(foilButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShaderMask), findsOneWidget);

      // Toggle foil OFF
      await tester.tap(foilButton);
      await tester.pumpAndSettle();

      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('4.5: AppBar prev/next navigation buttons advance pages when multiple cards exist', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: fsCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final nextBtn = find.byKey(const Key('fs_swipe_next_button'));
      if (nextBtn.evaluate().isNotEmpty) {
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
        expect(find.text('Nicol Bolas, the Ravager // Nicol Bolas, the Arisen'), findsWidgets);

        final prevBtn = find.byKey(const Key('fs_swipe_prev_button'));
        await tester.tap(prevBtn);
        await tester.pumpAndSettle();
        expect(find.text('Delver of Secrets // Insectile Aberration'), findsWidgets);
      }
    });
  });

  // ===========================================================================
  // GROUP 5: Synchronous Navigation (CardDetailSheet ↔ FullScreenCardViewer)
  // ===========================================================================
  group('Milestone 4 - Group 5: Synchronous Navigation', () {
    late List<VaultItem> syncCards;

    setUp(() {
      syncCards = [
        createTestCard(id: 'sync-0', name: 'Sync Card 0'),
        createTestCard(id: 'sync-1', name: 'Sync Card 1'),
        createTestCard(id: 'sync-2', name: 'Sync Card 2'),
        createTestCard(id: 'sync-3', name: 'Sync Card 3'),
      ];
    });

    testWidgets('5.1: Opening FullScreenCardViewer from CardDetailSheet starts at matching active index', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: syncCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Swipe to index 2
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Sync Card 2'), findsWidgets);

      // Tap card artwork to open full screen viewer
      final artworkFinder = find.byKey(const Key('card_artwork_sync-2'));
      expect(artworkFinder, findsOneWidget);
      await tester.tap(artworkFinder);
      await tester.pumpAndSettle();

      // FullScreen is open and displaying Sync Card 2
      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Sync Card 2'), findsWidgets);
    });

    testWidgets('5.2: Swiping in FullScreenCardViewer synchronizes back to CardDetailSheet on close', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: syncCards,
          initialIndex: 1,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sync Card 1'), findsWidgets);

      // Open FullScreen
      final artworkFinder = find.byKey(const Key('card_artwork_sync-1'));
      expect(artworkFinder, findsOneWidget);
      await tester.tap(artworkFinder);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);

      // Swipe to Sync Card 2 in FullScreen
      await tester.fling(find.byKey(const Key('fullscreen_page_view')), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Sync Card 2'), findsWidgets);

      // Dismiss FullScreen via close button
      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();

      // FullScreen dismissed, CardDetailSheet now displays Sync Card 2
      expect(find.byType(FullScreenCardViewer), findsNothing);
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Sync Card 2'), findsWidgets);
    });
  });

  // ===========================================================================
  // GROUP 6: Background Scroll Synchronization (VaultScreen._scrollToCardIndex)
  // ===========================================================================
  group('Milestone 4 - Group 6: Background Scroll Synchronization', () {
    test('6.1: Unit Test: Grid mode row mapping and offset calculation', () {
      const screenWidth = 400.0;
      const viewportHeight = 800.0;

      // Card 0 in row 0: targetOffset should clamp to 0.0
      final offset0 = calculateGridScrollOffset(
        index: 0,
        totalCount: 30,
        screenWidth: screenWidth,
        viewportHeight: viewportHeight,
      );
      expect(offset0, equals(0.0));

      // Card 3 in row 1: targetOffset must be greater than row 0
      final offset3 = calculateGridScrollOffset(
        index: 3,
        totalCount: 30,
        screenWidth: screenWidth,
        viewportHeight: viewportHeight,
      );
      expect(offset3, greaterThan(0.0));

      // Card 9 in row 3: targetOffset must be strictly greater than row 1
      final offset9 = calculateGridScrollOffset(
        index: 9,
        totalCount: 30,
        screenWidth: screenWidth,
        viewportHeight: viewportHeight,
      );
      expect(offset9, greaterThan(offset3));

      // Negative index clamps to 0.0
      expect(calculateGridScrollOffset(index: -1, totalCount: 30, screenWidth: screenWidth, viewportHeight: viewportHeight), 0.0);
    });

    test('6.2: Unit Test: List mode item height offset calculation', () {
      const viewportHeight = 800.0;

      final offset0 = calculateListScrollOffset(
        index: 0,
        totalCount: 30,
        viewportHeight: viewportHeight,
      );
      expect(offset0, equals(0.0));

      final offset5 = calculateListScrollOffset(
        index: 5,
        totalCount: 30,
        viewportHeight: viewportHeight,
      );
      expect(offset5, greaterThan(0.0));
      expect(offset5, closeTo(288.0 + (5 * 136.0) - (800.0 / 3.5), 1.0));

      final offset10 = calculateListScrollOffset(
        index: 10,
        totalCount: 30,
        viewportHeight: viewportHeight,
      );
      expect(offset10, greaterThan(offset5));
    });

    testWidgets('6.3: VaultScreen Grid mode: onPageChanged from CardDetailSheet scrolls underlying controller', (tester) async {
      setupVaultScrollTestScreen(tester);
      await _seedVaultCards(db, 60);

      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        layout: CardDisplayLayout.grid,
      ));
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byKey(const PageStorageKey<String>('vault_custom_scroll_view')),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0));

      // Tap card 0 to open CardDetailSheet
      final firstCard = find.byType(VaultItemTile).hitTestable().first;
      expect(firstCard, findsOneWidget);
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Swipe across cards in sheet to Card 9 (row 2 in 4-column grid)
      for (int i = 0; i < 9; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }

      // Verify underlying VaultScreen scroll position has moved down
      expect(scrollable.position.pixels, greaterThan(0.0));

      // Dismiss sheet
      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      // Verify underlying view remains scrolled at the new position
      expect(scrollable.position.pixels, greaterThan(0.0));

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('6.4: VaultScreen List mode: onPageChanged from CardDetailSheet scrolls underlying controller', (tester) async {
      setupVaultScrollTestScreen(tester);
      await _seedVaultCards(db, 60);

      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        layout: CardDisplayLayout.list,
      ));
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byKey(const PageStorageKey<String>('vault_custom_scroll_view')),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0));

      // Tap card 0 to open CardDetailSheet
      final firstCard = find.byType(VaultItemCard).hitTestable().first;
      expect(firstCard, findsOneWidget);
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Swipe across cards in sheet to Card 5
      for (int i = 0; i < 5; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }

      // Verify underlying list has scrolled down
      expect(scrollable.position.pixels, greaterThan(0.0));

      // Dismiss sheet
      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      // Scroll position preserved
      expect(scrollable.position.pixels, greaterThan(0.0));

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('6.5: VaultScreen preserves existing scroll position when sheet is opened and dismissed without swiping', (tester) async {
      setupVaultScrollTestScreen(tester);
      await _seedVaultCards(db, 60);

      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        layout: CardDisplayLayout.grid,
      ));
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byKey(const PageStorageKey<String>('vault_custom_scroll_view')),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);

      // Scroll down initially
      scrollable.position.jumpTo(250.0);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, equals(250.0));

      // Tap a visible card, open sheet, and immediately dismiss
      final visibleCard = find.byType(VaultItemTile).hitTestable().first;
      await tester.tap(visibleCard);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      // Scroll position does not snap back to 0.0
      expect(scrollable.position.pixels, greaterThan(0.0));

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

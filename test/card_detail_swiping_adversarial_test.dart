import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

// Helper to construct test VaultItems
VaultItem createAdvTestCard({
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
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  void setupTestScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // ===========================================================================
  // SUITE 1: Rapid Sequential Horizontal Flings Stress Testing
  // ===========================================================================
  group('Adversarial Stress Suite 1: Rapid Sequential Horizontal Flings', () {
    testWidgets('1.1: CardDetailSheet: rapid continuous horizontal flings with micro-pumps and boundary flings', (tester) async {
      setupTestScreen(tester);
      final cards = List.generate(
        8,
        (i) => createAdvTestCard(
          id: 'rapid-sheet-$i',
          name: 'Rapid Sheet Card $i',
          currentMarketPrice: (i + 1) * 10.0,
        ),
      );

      int lastReportedIndex = 0;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
          onPageChanged: (idx) => lastReportedIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rapid Sheet Card 0'), findsWidgets);

      // Perform 10 rapid flings to the right (scrolling forward) with only 25ms pump between flings
      for (int i = 0; i < 10; i++) {
        await tester.fling(find.byType(PageView), const Offset(-700, 0), 2000);
        await tester.pump(const Duration(milliseconds: 25));
        expect(tester.takeException(), isNull, reason: 'No assertion or exception during forward fling $i');
      }

      // Settle and verify stable landing at boundary
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(lastReportedIndex, equals(7));
      expect(find.text('Rapid Sheet Card 7'), findsWidgets);

      // Violent overscroll flings past the end boundary
      for (int i = 0; i < 5; i++) {
        await tester.fling(find.byType(PageView), const Offset(-700, 0), 2000);
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(lastReportedIndex, equals(7));
      expect(find.text('Rapid Sheet Card 7'), findsWidgets);

      // Rapid reverse flings back to start with variable pump intervals
      for (int i = 0; i < 12; i++) {
        await tester.fling(find.byType(PageView), const Offset(700, 0), 2000);
        await tester.pump(Duration(milliseconds: 15 + (i * 3)));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(lastReportedIndex, equals(0));
      expect(find.text('Rapid Sheet Card 0'), findsWidgets);

      // Violent overscroll flings past the start boundary
      for (int i = 0; i < 5; i++) {
        await tester.fling(find.byType(PageView), const Offset(700, 0), 2000);
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(lastReportedIndex, equals(0));
      expect(find.text('Rapid Sheet Card 0'), findsWidgets);
    });

    testWidgets('1.2: FullScreenCardViewer: rapid horizontal flings and boundary flings cause zero exceptions', (tester) async {
      setupTestScreen(tester);
      final cards = List.generate(
        6,
        (i) => createAdvTestCard(
          id: 'rapid-fs-$i',
          name: 'Rapid FS Card $i',
          currentMarketPrice: (i + 1) * 15.0,
        ),
      );

      int lastReportedIndex = 0;
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: cards,
          initialIndex: 0,
          onPageChanged: (idx) => lastReportedIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rapid FS Card 0'), findsWidgets);

      // Rapid forward flings with 20ms pump
      for (int i = 0; i < 8; i++) {
        await tester.fling(find.byKey(const Key('fullscreen_page_view')), const Offset(-700, 0), 2000);
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(lastReportedIndex, equals(5));
      expect(find.text('Rapid FS Card 5'), findsWidgets);

      // Rapid backward flings
      for (int i = 0; i < 8; i++) {
        await tester.fling(find.byKey(const Key('fullscreen_page_view')), const Offset(700, 0), 2000);
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(lastReportedIndex, equals(0));
      expect(find.text('Rapid FS Card 0'), findsWidgets);
    });
  });

  // ===========================================================================
  // SUITE 2: ScrollController Multi-Attachment Safety in DraggableScrollableSheet
  // ===========================================================================
  group('Adversarial Stress Suite 2: ScrollController Multi-Attachment Safety', () {
    testWidgets('2.1: Mid-swipe multi-page layout does not trigger ScrollController attachment assertions', (tester) async {
      setupTestScreen(tester);
      final cards = List.generate(
        4,
        (i) => createAdvTestCard(
          id: 'multi-attach-$i',
          name: 'Attach Test Card $i',
        ),
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final pageViewFinder = find.byType(PageView);
      final center = tester.getCenter(pageViewFinder);

      // Start drag and advance in fine-grained 20px increments to force PageView to keep both
      // Page 0 and Page 1 mounted in the render tree simultaneously
      final gesture = await tester.startGesture(center);
      for (int step = 0; step < 10; step++) {
        await gesture.moveBy(const Offset(-25, 0));
        await tester.pump(const Duration(milliseconds: 16));
        // Verify zero exceptions on every single frame during simultaneous dual-page mounting
        expect(tester.takeException(), isNull, reason: 'Failed during drag step $step');
      }

      // Drag back and forth rapidly around the midpoint
      for (int j = 0; j < 6; j++) {
        final delta = (j % 2 == 0) ? const Offset(40, 0) : const Offset(-40, 0);
        await gesture.moveBy(delta);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.2: Concurrent vertical scroll and horizontal swipe maintain controller isolation', (tester) async {
      setupTestScreen(tester);
      final cards = List.generate(
        4,
        (i) => createAdvTestCard(
          id: 'concurrent-$i',
          name: 'Concurrent Card $i',
        ),
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Drag vertically up on active card list view
      final listFinder = find.byType(ListView);
      expect(listFinder, findsWidgets);
      await tester.drag(listFinder.first, const Offset(0, -100));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Immediately swipe horizontally to next card
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Concurrent Card 1'), findsWidgets);

      // Drag vertically on the newly active card
      await tester.drag(listFinder.first, const Offset(0, -100));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Swipe back horizontally
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Concurrent Card 0'), findsWidgets);
    });
  });

  // ===========================================================================
  // SUITE 3: InteractiveViewer Pan/Zoom Scale Threshold Verification
  // ===========================================================================
  group('Adversarial Stress Suite 3: InteractiveViewer Pan/Zoom Scale Threshold', () {
    late List<VaultItem> zoomCards;

    setUp(() {
      zoomCards = [
        createAdvTestCard(id: 'zoom-0', name: 'Zoom Card 0'),
        createAdvTestCard(id: 'zoom-1', name: 'Zoom Card 1'),
        createAdvTestCard(id: 'zoom-2', name: 'Zoom Card 2'),
      ];
    });

    testWidgets('3.1: At scale 1.0x, horizontal drag swipes pages', (tester) async {
      setupTestScreen(tester);
      int? activeIndex;
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: zoomCards,
          initialIndex: 0,
          onPageChanged: (idx) => activeIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
      expect(ivFinder, findsOneWidget);
      final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
      expect(ivWidget.transformationController?.value.getMaxScaleOnAxis(), equals(1.0));

      // Horizontal fling at 1.0x
      await tester.fling(ivFinder, const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(activeIndex, equals(1));
      expect(find.text('Zoom Card 1'), findsWidgets);
    });

    testWidgets('3.2: At scale 2.0x, horizontal drag pans image WITHOUT swiping pages', (tester) async {
      setupTestScreen(tester);
      int? activeIndex;
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: zoomCards,
          initialIndex: 1,
          onPageChanged: (idx) => activeIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Zoom Card 1'), findsWidgets);

      final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
      expect(ivFinder, findsOneWidget);
      final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
      final transformController = ivWidget.transformationController!;

      // Zoom in to 2.0x
      transformController.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      await tester.pumpAndSettle();

      expect(transformController.value.getMaxScaleOnAxis(), closeTo(2.0, 0.01));

      // Check PageView physics has transitioned to NeverScrollableScrollPhysics
      final pageView = tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view')));
      expect(pageView.physics, isA<NeverScrollableScrollPhysics>());

      final initialTranslation = transformController.value.getTranslation();

      // Perform horizontal drag on the zoomed image
      await tester.drag(ivFinder, const Offset(-120, 0));
      await tester.pumpAndSettle();

      // Verification: Page did NOT swipe! Still on Card 1
      expect(activeIndex, isNull); // onPageChanged was never invoked
      expect(find.text('Zoom Card 1'), findsWidgets);
      expect(find.text('Zoom Card 2'), findsNothing);
      expect(find.text('Zoom Card 0'), findsNothing);

      // Verification: InteractiveViewer panned (translation changed)
      final newTranslation = transformController.value.getTranslation();
      expect(newTranslation.x, isNot(equals(initialTranslation.x)),
          reason: 'InteractiveViewer should absorb drag and pan the image at 2.0x');
    });

    testWidgets('3.3: Zoom in to 2.0x, pan, zoom out back to 1.0x, then swipe resumes normal page transitions', (tester) async {
      setupTestScreen(tester);
      int? activeIndex;
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: zoomCards,
          initialIndex: 1,
          onPageChanged: (idx) => activeIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
      final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
      final transformController = ivWidget.transformationController!;

      // 1. Zoom to 2.0x
      transformController.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view'))).physics,
          isA<NeverScrollableScrollPhysics>());

      // Drag at 2.0x - does not swipe
      await tester.drag(ivFinder, const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(find.text('Zoom Card 1'), findsWidgets);
      expect(activeIndex, isNull);

      // 2. Reset zoom back to 1.0x
      transformController.value = Matrix4.identity();
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view'))).physics,
          isA<PageScrollPhysics>());

      // 3. Horizontal fling at 1.0x - swiping resumes!
      await tester.fling(ivFinder, const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(activeIndex, equals(2));
      expect(find.text('Zoom Card 2'), findsWidgets);
    });

    testWidgets('3.4: Precision threshold: 1.01x allows swiping, 1.05x disables swiping', (tester) async {
      setupTestScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: zoomCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
      final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
      final transformController = ivWidget.transformationController!;

      // Scale 1.01x (below 1.02 threshold)
      transformController.value = Matrix4.diagonal3Values(1.01, 1.01, 1.0);
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view'))).physics,
          isA<PageScrollPhysics>());

      // Scale 1.05x (above 1.02 threshold)
      transformController.value = Matrix4.diagonal3Values(1.05, 1.05, 1.0);
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view'))).physics,
          isA<NeverScrollableScrollPhysics>());
    });
  });

  // ===========================================================================
  // SUITE 4: Double-Faced Card (DFC) Flip Reset Verification
  // ===========================================================================
  group('Adversarial Stress Suite 4: DFC Card Flip Reset on Swiping', () {
    late List<VaultItem> dfcCards;

    setUp(() {
      dfcCards = [
        createAdvTestCard(
          id: 'dfc-card-a',
          name: 'Delver of Secrets // Insectile Aberration',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {
                'name': 'Delver of Secrets',
                'oracle_text': 'At the beginning of your upkeep, look at top card.',
                'image_uris': {'normal': 'https://cards.scryfall.io/delver_front.jpg'},
              },
              {
                'name': 'Insectile Aberration',
                'oracle_text': 'Flying (Insectile Aberration oracle text)',
                'image_uris': {'normal': 'https://cards.scryfall.io/delver_back.jpg'},
              },
            ],
            'back_image_url': 'https://cards.scryfall.io/delver_back.jpg',
          },
        ),
        createAdvTestCard(
          id: 'dfc-card-b',
          name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {
                'name': 'Nicol Bolas, the Ravager',
                'oracle_text': 'Flying. When enters, each opponent discards.',
                'image_uris': {'normal': 'https://cards.scryfall.io/bolas_front.jpg'},
              },
              {
                'name': 'Nicol Bolas, the Arisen',
                'oracle_text': '+2: Draw two cards. -3: Deal 10 damage.',
                'image_uris': {'normal': 'https://cards.scryfall.io/bolas_back.jpg'},
              },
            ],
            'back_image_url': 'https://cards.scryfall.io/bolas_back.jpg',
          },
        ),
        createAdvTestCard(
          id: 'dfc-card-c',
          name: 'Lightning Bolt',
          dynamicDataMap: {
            'layout': 'normal',
            'oracle_text': 'Lightning Bolt deals 3 damage to any target.',
          },
        ),
      ];
    });

    testWidgets('4.1: CardDetailSheet: Card A flipped to Face 2, swipe to B, swipe back to A -> Card A resets to Face 1', (tester) async {
      setupTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: dfcCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Card A initial state: Face 1 is active
      expect(find.text('View Face 2'), findsOneWidget);
      expect(find.textContaining('At the beginning of your upkeep'), findsWidgets);

      // Flip Card A to Face 2
      final flipButton = find.byKey(const Key('card_detail_switch_face_button'));
      expect(flipButton, findsOneWidget);
      await tester.tap(flipButton);
      await tester.pumpAndSettle();

      // Verified: Card A is now on Face 2
      expect(find.text('View Face 1'), findsOneWidget);
      expect(find.textContaining('Insectile Aberration oracle text'), findsWidgets);

      // Swipe to Card B
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Verified: Card B must start on Face 1
      expect(find.text('Nicol Bolas, the Ravager // Nicol Bolas, the Arisen'), findsWidgets);
      expect(find.text('View Face 2'), findsOneWidget);
      expect(find.textContaining('each opponent discards'), findsWidgets);

      // Swipe back to Card A
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      // CRITICAL ASSERTION: Card A has RESET to Face 1!
      expect(find.text('Delver of Secrets // Insectile Aberration'), findsWidgets);
      expect(find.text('View Face 2'), findsOneWidget);
      expect(find.text('View Face 1'), findsNothing);
      expect(find.textContaining('At the beginning of your upkeep'), findsWidgets);
    });

    testWidgets('4.2: FullScreenCardViewer: Card A flipped to back face, swipe to B, swipe back to A -> Card A resets to front face', (tester) async {
      setupTestScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(
          items: dfcCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Card A initial state: 'Back Face' button indicates front face is shown
      final fsFlipBtn = find.byKey(const Key('fullscreen_appbar_flip_button'));
      expect(fsFlipBtn, findsOneWidget);
      expect(find.text('Back Face'), findsOneWidget);

      // Tap flip button -> flips to back face
      await tester.tap(fsFlipBtn);
      await tester.pumpAndSettle();

      // Button now reads 'Front Face' (indicating back face is showing)
      expect(find.text('Front Face'), findsOneWidget);

      // Swipe to Card B
      await tester.fling(find.byKey(const Key('fullscreen_page_view')), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Card B must start on front face
      expect(find.text('Nicol Bolas, the Ravager // Nicol Bolas, the Arisen'), findsWidgets);
      expect(find.text('Back Face'), findsOneWidget);

      // Swipe back to Card A
      await tester.fling(find.byKey(const Key('fullscreen_page_view')), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      // CRITICAL ASSERTION: Card A has reset to front face!
      expect(find.text('Delver of Secrets // Insectile Aberration'), findsWidgets);
      expect(find.text('Back Face'), findsOneWidget);
      expect(find.text('Front Face'), findsNothing);
    });

    testWidgets('4.3: Cascading traversal: Flip A, swipe to B, flip B, swipe to C (single-faced), swipe back to B, swipe back to A', (tester) async {
      setupTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: dfcCards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final flipBtn = find.byKey(const Key('card_detail_switch_face_button'));

      // 1. Flip Card A to Face 2
      await tester.tap(flipBtn);
      await tester.pumpAndSettle();
      expect(find.text('View Face 1'), findsOneWidget);

      // 2. Swipe to Card B
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('View Face 2'), findsOneWidget);

      // 3. Flip Card B to Face 2
      await tester.tap(flipBtn);
      await tester.pumpAndSettle();
      expect(find.text('View Face 1'), findsOneWidget);
      expect(find.textContaining('+2: Draw two cards'), findsWidgets);

      // 4. Advance to Card C (single-faced)
      final pv = tester.widget<PageView>(find.byType(PageView));
      pv.controller!.jumpToPage(2);
      await tester.pumpAndSettle();
      expect(find.text('Lightning Bolt'), findsWidgets);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);

      // 5. Swipe back to Card B
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Nicol Bolas, the Ravager // Nicol Bolas, the Arisen'), findsWidgets);
      expect(find.text('View Face 2'), findsOneWidget);
      expect(find.textContaining('each opponent discards'), findsWidgets);

      // 6. Swipe back to Card A
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Delver of Secrets // Insectile Aberration'), findsWidgets);
      expect(find.text('View Face 2'), findsOneWidget);
      expect(find.textContaining('At the beginning of your upkeep'), findsWidgets);
    });
  });
}

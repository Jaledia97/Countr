import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    required String id,
    required String name,
    String imageUrl = 'https://cards.scryfall.io/large/front/test.jpg',
    Map<String, dynamic>? dynamicDataMap,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'MH3',
      imageUrl: imageUrl,
      acquiredPrice: 10.0,
      acquiredDate: DateTime(2026, 9, 18),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      personalNotes: null,
      primaryBinderId: null,
      currentMarketPrice: 25.0,
      lastPriceUpdate: DateTime(2026, 9, 18),
      dynamicData: jsonEncode(dynamicDataMap ?? {
        'layout': 'normal',
        'type_line': 'Creature — Dragon',
        'oracle_text': 'Flying, trample',
        'rarity': 'mythic',
      }),
    );
  }

  Widget wrapWithHarness(Widget child, {Size? physicalSize}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        userPersonaProvider.overrideWith((ref) => UserPersona.investor),
        cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
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

  group('Challenger Remediation R3: Card Detail Artwork Tap & Gesture Adversarial Stress Suite', () {
    testWidgets('R3.1: Rapid swiping across 6 cards and tapping artwork opens FullScreenCardViewer accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cards = List.generate(6, (i) => createTestCard(id: 'stress-c$i', name: 'Stress Card $i'));

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Stress Card 0'), findsWidgets);

      // Rapidly swipe forward 3 times
      for (int i = 0; i < 3; i++) {
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
        await tester.pumpAndSettle();
      }

      expect(find.text('Stress Card 3'), findsWidgets);

      // Tap card artwork on active card 3
      final artFinder3 = find.byKey(const Key('card_artwork_stress-c3'));
      expect(artFinder3, findsOneWidget);
      await tester.tap(artFinder3);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Stress Card 3'), findsWidgets);

      // Close full-screen viewer
      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenCardViewer), findsNothing);

      // Rapidly swipe backwards 2 times to card 1
      for (int i = 0; i < 2; i++) {
        await tester.fling(find.byType(PageView), const Offset(400, 0), 1200);
        await tester.pumpAndSettle();
      }

      expect(find.text('Stress Card 1'), findsWidgets);

      final artFinder1 = find.byKey(const Key('card_artwork_stress-c1'));
      expect(artFinder1, findsOneWidget);
      await tester.tap(artFinder1);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Stress Card 1'), findsWidgets);

      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('R3.2: Bounds extremes: compact screen (360x640) artwork tap hit-testing', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(id: 'compact-c1', name: 'Compact Device Card');

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [card],
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final artFinder = find.byKey(const Key('card_artwork_compact-c1'));
      expect(artFinder, findsOneWidget);
      await tester.tap(artFinder);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Compact Device Card'), findsWidgets);

      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenCardViewer), findsNothing);
    });

    testWidgets('R3.3: Bounds extremes: tablet/landscape screen (1280x800) artwork tap hit-testing', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(id: 'tablet-c1', name: 'Tablet Landscape Card');

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [card],
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final artFinder = find.byKey(const Key('card_artwork_tablet-c1'));
      expect(artFinder, findsOneWidget);
      await tester.tap(artFinder);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Tablet Landscape Card'), findsWidgets);

      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('R3.4: Nested sliver scrolling - partially collapsed header still registers artwork tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(id: 'sliver-c1', name: 'Sliver Collapse Card');

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [card],
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll nested scroll view down slightly (40px) to partially collapse header without pushing out of viewport
      final listView = find.byType(ListView).first;
      await tester.drag(listView, const Offset(0, -40));
      await tester.pumpAndSettle();

      // Tap card artwork
      final artFinder = find.byKey(const Key('card_artwork_sliver-c1'));
      expect(artFinder, findsOneWidget);
      await tester.tap(artFinder);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Sliver Collapse Card'), findsWidgets);

      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('R3.5: Multi-tab navigation & scrolling does not break artwork tap gesture', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(id: 'tabs-c1', name: 'Tab Switching Card');

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [card],
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap 'Values' tab
      final valuesTab = find.text('Values');
      expect(valuesTab, findsOneWidget);
      await tester.tap(valuesTab);
      await tester.pumpAndSettle();

      // Tap artwork while on Values tab
      final artFinder = find.byKey(const Key('card_artwork_tabs-c1'));
      expect(artFinder, findsOneWidget);
      await tester.tap(artFinder);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Tab Switching Card'), findsWidgets);

      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();

      // Switch back to Details tab
      final detailsTab = find.text('Details');
      await tester.tap(detailsTab);
      await tester.pumpAndSettle();

      await tester.tap(artFinder);
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenCardViewer), findsOneWidget);

      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('R3.6: Broken image / error state does NOT block artwork tap to open FullScreenCardViewer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Card with broken image URL that fails to load and renders error widget
      final card = createTestCard(
        id: 'broken-img-c1',
        name: 'Broken Art Card',
        imageUrl: 'https://nonexistent-domain-causing-400-error.com/fail.jpg',
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [card],
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Tapping the artwork must open FullScreenCardViewer despite errorWidget inside CountrCachedImage
      final artFinder = find.byKey(const Key('card_artwork_broken-img-c1'));
      expect(artFinder, findsOneWidget);
      await tester.tap(artFinder);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.text('Broken Art Card'), findsWidgets);

      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('R3.7: Double-faced card (DFC) tap toggles flip animation cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dfcCard = createTestCard(
        id: 'dfc-card-1',
        name: 'Huntmaster of the Fells // Ravager of the Fells',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Huntmaster of the Fells',
              'image_uris': {'normal': 'https://cards.scryfall.io/huntmaster_front.jpg'},
            },
            {
              'name': 'Ravager of the Fells',
              'image_uris': {'normal': 'https://cards.scryfall.io/huntmaster_back.jpg'},
            },
          ],
          'back_image_url': 'https://cards.scryfall.io/huntmaster_back.jpg',
        },
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [dfcCard],
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      final artFinder = find.byKey(const Key('card_artwork_dfc-card-1'));
      expect(artFinder, findsOneWidget);

      // On DFC card, tapping current card toggles flip animation
      await tester.tap(artFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      // Tap again to flip back
      await tester.tap(artFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}

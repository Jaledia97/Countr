import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

VaultItem createItem({
  required String id,
  required String name,
  String setOrSeries = 'Test Set',
  String imageUrl = 'https://example.com/card.jpg',
  int quantity = 1,
  double price = 10.0,
}) {
  return VaultItem(
    id: id,
    collectionType: 'mtg',
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: price,
    acquiredDate: DateTime(2024, 1, 1),
    quantity: quantity,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    isDeleted: false,
    currentMarketPrice: price,
    lastPriceUpdate: DateTime.now(),
    dynamicData: '{}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M1-2: Empirical Stress Test of Requirement R1', () {
    // ------------------------------------------------------------------------
    // Part 1: InteractiveViewer Zoom Behavior & Horizontal Scroll Physics
    // ------------------------------------------------------------------------
    group('Part 1: FullScreenCardViewer Zoom & Physics Challenge', () {
      testWidgets('1.1: Micro-pinch gesture (< 1.08 scale) auto-resets to identity on interaction end', (tester) async {
        final items = [
          createItem(id: 'c1', name: 'Card 1'),
          createItem(id: 'c2', name: 'Card 2'),
        ];

        await tester.pumpWidget(MaterialApp(
          home: FullScreenCardViewer(items: items, initialIndex: 0),
        ));
        await tester.pumpAndSettle();

        final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
        expect(ivFinder, findsOneWidget);
        final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
        final controller = ivWidget.transformationController!;

        expect(controller.value.isIdentity(), isTrue);
        expect(controller.value.getMaxScaleOnAxis(), equals(1.0));
        expect(ivWidget.panEnabled, isFalse);
        expect(ivWidget.boundaryMargin, equals(EdgeInsets.zero));

        // Test slight zoom programmatically (< 1.08, e.g. 1.05)
        controller.value = Matrix4.diagonal3Values(1.05, 1.05, 1.0);
        await tester.pump();

        // While scale is 1.05, _isZoomed remains false because scale is <= 1.08
        var currentIv = tester.widget<InteractiveViewer>(find.byKey(const Key('fullscreen_interactive_viewer')));
        expect(currentIv.panEnabled, isFalse);

        // Trigger onInteractionEnd
        currentIv.onInteractionEnd?.call(ScaleEndDetails());
        await tester.pumpAndSettle();

        // Verification: scale must auto-reset to identity (1.0)
        expect(controller.value.isIdentity(), isTrue);
        expect(controller.value.getMaxScaleOnAxis(), equals(1.0));

        // Pan must remain disabled and boundaryMargin must remain zero
        final ivAfter = tester.widget<InteractiveViewer>(find.byKey(const Key('fullscreen_interactive_viewer')));
        expect(ivAfter.panEnabled, isFalse);
        expect(ivAfter.boundaryMargin, equals(EdgeInsets.zero));
      });

      testWidgets('1.2: Diagonal multi-pointer gesture pinch and auto-reset (< 1.08 scale)', (tester) async {
        final items = [
          createItem(id: 'c1', name: 'Card 1'),
          createItem(id: 'c2', name: 'Card 2'),
        ];

        await tester.pumpWidget(MaterialApp(
          home: FullScreenCardViewer(items: items, initialIndex: 0),
        ));
        await tester.pumpAndSettle();

        final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
        final center = tester.getCenter(ivFinder);
        final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
        final controller = ivWidget.transformationController!;

        // Perform multi-touch diagonal pinch gesture
        final g1 = await tester.createGesture();
        final g2 = await tester.createGesture();
        addTearDown(g1.removePointer);
        addTearDown(g2.removePointer);

        await g1.down(Offset(center.dx - 30, center.dy - 30));
        await g2.down(Offset(center.dx + 30, center.dy + 30));
        await tester.pump();

        // Move pointers outward slightly
        await g1.moveTo(Offset(center.dx - 45, center.dy - 45));
        await g2.moveTo(Offset(center.dx + 45, center.dy + 45));
        await tester.pump();

        // Release pointers to trigger onInteractionEnd
        await g1.up();
        await g2.up();
        await tester.pumpAndSettle();

        // Scale should either be reset to identity or remain <= 1.08 auto-reset
        if (controller.value.getMaxScaleOnAxis() < 1.08) {
          expect(controller.value.isIdentity(), isTrue);
        }
      });

      testWidgets('1.3: Swipe navigation is uninhibited after slight pinch gesture (< 1.08 scale)', (tester) async {
        final items = [
          createItem(id: 'c1', name: 'Card 1'),
          createItem(id: 'c2', name: 'Card 2'),
          createItem(id: 'c3', name: 'Card 3'),
        ];

        await tester.pumpWidget(MaterialApp(
          home: FullScreenCardViewer(items: items, initialIndex: 0),
        ));
        await tester.pumpAndSettle();

        final appBarTitleFinder = find.descendant(of: find.byType(AppBar), matching: find.text('Card 1'));
        expect(appBarTitleFinder, findsOneWidget);

        final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
        final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
        final controller = ivWidget.transformationController!;

        // Simulate slight pinch touch by setting scale 1.06 (< 1.08)
        controller.value = Matrix4.diagonal3Values(1.06, 1.06, 1.0);
        await tester.pump();

        // End interaction
        final currentIv = tester.widget<InteractiveViewer>(find.byKey(const Key('fullscreen_interactive_viewer')));
        currentIv.onInteractionEnd?.call(ScaleEndDetails());
        await tester.pumpAndSettle();

        // Must be reset to identity
        expect(controller.value.isIdentity(), isTrue);

        // PageView physics must be BouncingScrollPhysics
        final pageViewFinder = find.byKey(const Key('fullscreen_page_view'));
        final pageView = tester.widget<PageView>(pageViewFinder);
        expect(pageView.physics, isA<BouncingScrollPhysics>());

        // Swiping left should smoothly navigate to Card 2 without resistance
        await tester.fling(pageViewFinder, const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();

        final card2AppBarFinder = find.descendant(of: find.byType(AppBar), matching: find.text('Card 2'));
        expect(card2AppBarFinder, findsOneWidget);

        // Another swipe should navigate to Card 3
        await tester.fling(pageViewFinder, const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();

        final card3AppBarFinder = find.descendant(of: find.byType(AppBar), matching: find.text('Card 3'));
        expect(card3AppBarFinder, findsOneWidget);

        // Swipe right back to Card 2
        await tester.fling(pageViewFinder, const Offset(400, 0), 1000);
        await tester.pumpAndSettle();

        expect(find.descendant(of: find.byType(AppBar), matching: find.text('Card 2')), findsOneWidget);
      });

      testWidgets('1.4: Deep zoom (> 1.08) locks PageView physics and enables panning; zoom-out resets', (tester) async {
        final items = [
          createItem(id: 'c1', name: 'Card 1'),
          createItem(id: 'c2', name: 'Card 2'),
        ];

        await tester.pumpWidget(MaterialApp(
          home: FullScreenCardViewer(items: items, initialIndex: 0),
        ));
        await tester.pumpAndSettle();

        final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
        final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
        final controller = ivWidget.transformationController!;

        // Perform significant zoom (> 1.08, e.g. 1.5x)
        controller.value = Matrix4.diagonal3Values(1.5, 1.5, 1.0);
        await tester.pump();

        // Zoomed: PageView physics switches to NeverScrollableScrollPhysics to prevent accidental page turn while panning
        final pageViewZoomed = tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view')));
        expect(pageViewZoomed.physics, isA<NeverScrollableScrollPhysics>());

        final ivZoomed = tester.widget<InteractiveViewer>(find.byKey(const Key('fullscreen_interactive_viewer')));
        expect(ivZoomed.panEnabled, isTrue);
        expect(ivZoomed.boundaryMargin, equals(const EdgeInsets.all(60)));

        // End interaction while still zoomed (> 1.08)
        ivZoomed.onInteractionEnd?.call(ScaleEndDetails());
        await tester.pumpAndSettle();

        // Scale should remain zoomed
        expect(controller.value.getMaxScaleOnAxis(), equals(1.5));

        // Now zoom back out below 1.08 (e.g. 1.03)
        controller.value = Matrix4.diagonal3Values(1.03, 1.03, 1.0);
        await tester.pump();

        final ivNearReset = tester.widget<InteractiveViewer>(find.byKey(const Key('fullscreen_interactive_viewer')));
        ivNearReset.onInteractionEnd?.call(ScaleEndDetails());
        await tester.pumpAndSettle();

        // Should auto-reset to identity
        expect(controller.value.isIdentity(), isTrue);
        final ivReset = tester.widget<InteractiveViewer>(find.byKey(const Key('fullscreen_interactive_viewer')));
        expect(ivReset.panEnabled, isFalse);
        expect(ivReset.boundaryMargin, equals(EdgeInsets.zero));

        // PageView physics restored to BouncingScrollPhysics
        final pageViewRestored = tester.widget<PageView>(find.byKey(const Key('fullscreen_page_view')));
        expect(pageViewRestored.physics, isA<BouncingScrollPhysics>());
      });

      testWidgets('1.5: Page navigation via buttons auto-resets zoom state on next card', (tester) async {
        final items = [
          createItem(id: 'c1', name: 'Card 1'),
          createItem(id: 'c2', name: 'Card 2'),
        ];

        await tester.pumpWidget(MaterialApp(
          home: FullScreenCardViewer(items: items, initialIndex: 0),
        ));
        await tester.pumpAndSettle();

        final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
        final ivWidget = tester.widget<InteractiveViewer>(ivFinder);
        final controller = ivWidget.transformationController!;

        // Zoom Card 1
        controller.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
        await tester.pump();
        expect(controller.value.getMaxScaleOnAxis(), equals(2.0));

        // Tap next button in appbar
        await tester.tap(find.byKey(const Key('fs_swipe_next_button')));
        await tester.pumpAndSettle();

        expect(find.descendant(of: find.byType(AppBar), matching: find.text('Card 2')), findsOneWidget);

        // Card 2 interactive viewer must be unzoomed with identity matrix
        final ivCard2 = tester.widget<InteractiveViewer>(find.byKey(const Key('fullscreen_interactive_viewer')));
        expect(ivCard2.transformationController!.value.isIdentity(), isTrue);
        expect(ivCard2.panEnabled, isFalse);
        expect(ivCard2.boundaryMargin, equals(EdgeInsets.zero));
      });
    });

    // ------------------------------------------------------------------------
    // Part 2: Tile Mode Aspect Ratio & Image Containment Challenge
    // ------------------------------------------------------------------------
    group('Part 2: Tile Mode Aspect Ratio & Image Containment Challenge', () {
      testWidgets('2.1: VaultItemTile strictly uses BoxFit.contain to prevent frame clipping', (tester) async {
        final item = createItem(id: 'tile-card-1', name: 'Black Lotus', imageUrl: 'https://example.com/lotus.jpg');

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                height: 250,
                child: VaultItemTile(item: item),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final cachedImageFinder = find.byType(CountrCachedImage);
        expect(cachedImageFinder, findsOneWidget);
        final cachedImage = tester.widget<CountrCachedImage>(cachedImageFinder);
        expect(cachedImage.fit, equals(BoxFit.contain));

        // Find rendered Image widget
        final imageFinder = find.descendant(of: cachedImageFinder, matching: find.byType(Image));
        expect(imageFinder, findsOneWidget);
        final imageWidget = tester.widget<Image>(imageFinder);
        expect(imageWidget.fit, equals(BoxFit.contain));
      });

      testWidgets('2.2: Image containment verified: BoxFit.contain keeps entire image inside container while BoxFit.cover crops source', (tester) async {
        final testRatios = [
          {'name': 'Standard MTG 5:7', 'width': 500.0, 'height': 700.0},
          {'name': 'Square 1:1', 'width': 500.0, 'height': 500.0},
          {'name': 'Wide Art Crop 2:1', 'width': 1000.0, 'height': 500.0},
          {'name': 'Tall Art Crop 1:2', 'width': 500.0, 'height': 1000.0},
        ];

        for (final entry in testRatios) {
          final sourceSize = Size(entry['width'] as double, entry['height'] as double);

          // Test under various tile container dimensions
          final containerSizes = [
            const Size(112.6, 160.0), // Standard 3-column mobile tile image area
            const Size(150.0, 180.0), // Wider tablet tile
            const Size(90.0, 130.0),  // Narrow mobile tile
          ];

          for (final cSize in containerSizes) {
            final containSizes = applyBoxFit(BoxFit.contain, sourceSize, cSize);
            // With BoxFit.contain, 100% of source is preserved (source width and height are unchanged)
            expect(
              containSizes.source.width,
              equals(sourceSize.width),
              reason: 'BoxFit.contain clipped source width for ${entry['name']}',
            );
            expect(
              containSizes.source.height,
              equals(sourceSize.height),
              reason: 'BoxFit.contain clipped source height for ${entry['name']}',
            );

            // And destination size fits within container
            expect(
              containSizes.destination.width,
              lessThanOrEqualTo(cSize.width + 0.001),
              reason: 'Fitted width exceeded container for ${entry['name']} in $cSize',
            );
            expect(
              containSizes.destination.height,
              lessThanOrEqualTo(cSize.height + 0.001),
              reason: 'Fitted height exceeded container for ${entry['name']} in $cSize',
            );

            // Contrast with BoxFit.cover:
            // When aspect ratio doesn't match container, BoxFit.cover crops either width or height of the source
            final sourceAspect = sourceSize.width / sourceSize.height;
            final containerAspect = cSize.width / cSize.height;
            if ((sourceAspect - containerAspect).abs() > 0.05) {
              final coverSizes = applyBoxFit(BoxFit.cover, sourceSize, cSize);
              final isClipped = coverSizes.source.width < sourceSize.width - 0.01 ||
                  coverSizes.source.height < sourceSize.height - 0.01;
              expect(
                isClipped,
                isTrue,
                reason: 'BoxFit.cover should crop source frame when aspect ratios differ',
              );
            }
          }
        }
      });

      testWidgets('2.3: Child aspect ratio dynamically adapts to text scale factor without overflow', (tester) async {
        late AppDatabase db;
        db = AppDatabase(NativeDatabase.memory());
        await db.vaultDao.clearAllItems();
        addTearDown(() => db.close());

        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'aspect-test-card',
            collectionType: 'mtg',
            name: 'A very long card name that takes multiple lines under large font sizes',
            setOrSeries: 'Special Expansion Set 2024 (Extended)',
            imageUrl: 'https://example.com/lotus.jpg',
            acquiredPrice: 50.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(2),
            condition: 'NM (Foil)',
            isGraded: const drift.Value(true),
            currentMarketPrice: 100.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"oracle_text":"Test"}',
          ),
        );

        final textScales = [1.0, 1.4, 2.0];
        final expectedAspectRatios = [0.54, 0.44, 0.36];

        for (int i = 0; i < textScales.length; i++) {
          final scale = textScales[i];
          final expectedRatio = expectedAspectRatios[i];

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
              activeGameContextProvider.overrideWith((ref) => 'mtg'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
              cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
            ],
          );

          await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    size: const Size(390, 844),
                  ),
                  child: child!,
                );
              },
              home: const VaultScreen(),
            ),
          ));
          await tester.pumpAndSettle();

          final gridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
          expect(gridFinder, findsOneWidget);
          final grid = tester.widget<SliverGrid>(gridFinder);
          final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
          expect(delegate.childAspectRatio, equals(expectedRatio));

          // Ensure VaultItemTile renders without any RenderFlex overflow exceptions
          expect(tester.takeException(), isNull);
          expect(find.byType(VaultItemTile), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });

      testWidgets('2.4: Tile mode renders cleanly across varying screen sizes without clipping or overflow', (tester) async {
        late AppDatabase db;
        db = AppDatabase(NativeDatabase.memory());
        await db.vaultDao.clearAllItems();
        addTearDown(() => db.close());

        for (int i = 0; i < 6; i++) {
          await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'grid-card-$i',
              collectionType: 'mtg',
              name: 'Card Title $i',
              setOrSeries: 'Set Series $i',
              imageUrl: 'https://example.com/card$i.jpg',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2024, 1, 1),
              quantity: drift.Value(i),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 20.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );
        }

        final viewports = [
          const Size(320, 568),  // Small phone (iPhone SE 1st gen)
          const Size(390, 844),  // Standard phone (iPhone 14)
          const Size(768, 1024), // Tablet portrait (iPad)
          const Size(1200, 800), // Desktop / tablet landscape
        ];

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
              activeGameContextProvider.overrideWith((ref) => 'mtg'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
              cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
            ],
          );

          await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: VaultScreen(),
            ),
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: 'Overflow or crash at size $size');
          expect(find.byType(VaultItemTile), findsWidgets);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 100));
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}

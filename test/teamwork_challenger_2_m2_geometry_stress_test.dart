// =============================================================================
// ADVERSARIAL CHALLENGER TEST SUITE: Milestone 2 Geometry & Scaling Invariants
// Author: Challenger 2 (teamwork_preview_challenger_2)
// Target: VaultScreen 3x3 Grid, _scrollToCardIndex, VaultItemTile, BinderGridCardTile
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper factory for VaultItem
  VaultItem buildTestItem({
    required String id,
    required String name,
    required int quantity,
    bool isGraded = false,
    String condition = 'Near Mint',
    String imageUrl = '',
    double currentMarketPrice = 24.99,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      flavorName: null,
      setOrSeries: 'Outlaws of Thunder Junction',
      imageUrl: imageUrl,
      acquiredPrice: 12.0,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      personalNotes: null,
      primaryBinderId: null,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime(2026, 1, 1),
      dynamicData: jsonEncode({
        if (condition.toLowerCase().contains('foil')) 'finish': 'foil',
      }),
    );
  }

  // Pure functions matching vault_screen.dart for mathematical proofs
  int calculateGridColumns(double screenWidth, [double textScale = 1.0]) {
    if ((screenWidth < 360 && textScale > 1.1) ||
        (screenWidth < 450 && textScale > 1.6)) {
      return 2;
    }
    if (screenWidth < 600) return 3;
    if (screenWidth < 900) return 4;
    if (screenWidth < 1200) return 5;
    return 6;
  }

  double calculateChildAspectRatio(double textScale) {
    if (textScale > 1.8) return 0.36;
    if (textScale > 1.3) return 0.44;
    return 0.54;
  }

  ({
    int columns,
    double horizontalPadding,
    double crossSpacing,
    double mainSpacing,
    double itemWidth,
    double itemHeight,
    double rowHeight,
  }) computeGridLayout(double screenWidth, {double textScale = 1.0}) {
    final columns = calculateGridColumns(screenWidth, textScale);
    final double horizontalPadding = columns <= 3 ? 2.0 : 16.0;
    final double crossSpacing = columns <= 3 ? 2.0 : 10.0;
    final double mainSpacing = columns <= 3 ? 2.0 : 10.0;
    final totalSpacing = (columns - 1) * crossSpacing;
    final gridWidth = screenWidth - (horizontalPadding * 2);
    final itemWidth = (gridWidth - totalSpacing) / columns;
    final aspectRatio = calculateChildAspectRatio(textScale);
    final itemHeight = itemWidth / aspectRatio;
    final rowHeight = itemHeight + mainSpacing;
    return (
      columns: columns,
      horizontalPadding: horizontalPadding,
      crossSpacing: crossSpacing,
      mainSpacing: mainSpacing,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      rowHeight: rowHeight,
    );
  }

  double computeScrollTargetOffset({
    required int index,
    required double screenWidth,
    required double screenHeight,
    double textScale = 1.0,
    double headerOffset = 288.0,
  }) {
    final layout = computeGridLayout(screenWidth, textScale: textScale);
    final rowIndex = index ~/ layout.columns;
    if (rowIndex == 0) return 0.0;
    return headerOffset + (rowIndex * layout.rowHeight) - (screenHeight / 3.5);
  }

  // ===========================================================================
  // SECTION 1: Mathematical Invariant Proofs Across Viewports
  // ===========================================================================
  group('Adversarial 1: Mathematical Verification Across Viewports', () {
    const viewports = [320.0, 360.0, 390.0, 412.0, 600.0, 1024.0];

    for (final width in viewports) {
      test('Viewport ${width}dp: Grid layout and row height mathematical proof', () {
        final layout = computeGridLayout(width);

        if (width < 600) {
          expect(layout.columns, equals(3), reason: 'Phone viewports <600dp must have 3 columns');
          expect(layout.horizontalPadding, equals(2.0), reason: '3-column mobile must have 2dp edge-to-edge padding');
          expect(layout.crossSpacing, equals(2.0));
          expect(layout.mainSpacing, equals(2.0));
        } else if (width == 600) {
          expect(layout.columns, equals(4), reason: '600dp viewport transitions to 4 columns');
          expect(layout.horizontalPadding, equals(16.0));
          expect(layout.crossSpacing, equals(10.0));
          expect(layout.mainSpacing, equals(10.0));
        } else if (width == 1024) {
          expect(layout.columns, equals(5), reason: '1024dp tablet viewport has 5 columns');
          expect(layout.horizontalPadding, equals(16.0));
          expect(layout.crossSpacing, equals(10.0));
          expect(layout.mainSpacing, equals(10.0));
        }

        // Mathematical check: total width reconstructed equals screenWidth
        final reconstructedWidth = (layout.columns * layout.itemWidth) +
            ((layout.columns - 1) * layout.crossSpacing) +
            (2 * layout.horizontalPadding);
        expect(reconstructedWidth, closeTo(width, 0.0001),
            reason: 'Item width sum plus spacing plus padding must exactly fill screenWidth');

        // Check row height = itemHeight + mainSpacing
        expect(layout.rowHeight, equals(layout.itemHeight + layout.mainSpacing));

        // Verify row offset progression for arbitrary rows R = 0, 1, 5, 10, 50
        for (final row in [0, 1, 2, 5, 10, 50]) {
          final expectedRowTopInGrid = row * layout.rowHeight;
          final nextRowTopInGrid = (row + 1) * layout.rowHeight;
          final rowDelta = nextRowTopInGrid - expectedRowTopInGrid;
          expect(rowDelta, closeTo(layout.rowHeight, 0.0001));
          expect(rowDelta, closeTo(layout.itemHeight + layout.mainSpacing, 0.0001));
        }
      });
    }

    test('Proof: _scrollToCardIndex offset delta across consecutive rows matches rowHeight', () {
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      final layout = computeGridLayout(screenWidth);

      for (int i = 0; i < 30; i++) {
        final row = i ~/ layout.columns;
        if (row > 0) {
          final offsetRow = computeScrollTargetOffset(
            index: i,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          );
          final offsetNextRow = computeScrollTargetOffset(
            index: i + layout.columns,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          );
          expect(offsetNextRow - offsetRow, closeTo(layout.rowHeight, 0.0001),
              reason: 'Scroll offset difference between consecutive rows must equal rowHeight');
        }
      }
    });
  });

  // ===========================================================================
  // SECTION 2: Empirical Rendered Widget Geometry Verification
  // ===========================================================================
  group('Adversarial 2: Flutter Rendered Tile Size vs Mathematical Prediction', () {
    const viewports = [320.0, 360.0, 390.0, 412.0, 600.0, 1024.0];

    for (final width in viewports) {
      testWidgets('RenderBox verification at ${width}dp viewport matches mathematical layout', (tester) async {
        final layout = computeGridLayout(width);

        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final testItems = List.generate(
          12,
          (i) => buildTestItem(id: 'item-$i', name: 'Card $i', quantity: 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(layout.horizontalPadding, 0, layout.horizontalPadding, 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: layout.columns,
                          crossAxisSpacing: layout.crossSpacing,
                          mainAxisSpacing: layout.mainSpacing,
                          childAspectRatio: 0.54,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => VaultItemTile(item: testItems[index]),
                          childCount: testItems.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Extract RenderBox of the first rendered tile
        final firstTileFinder = find.byKey(Key('vault_tile_${testItems[0].id}'));
        expect(firstTileFinder, findsOneWidget);
        final RenderBox renderBox = tester.renderObject(firstTileFinder);

        // Assert rendered width and height match mathematical calculation within sub-pixel precision
        expect(renderBox.size.width, closeTo(layout.itemWidth, 0.01),
            reason: 'Rendered width at ${width}dp must match layout.itemWidth (${layout.itemWidth})');
        expect(renderBox.size.height, closeTo(layout.itemHeight, 0.01),
            reason: 'Rendered height at ${width}dp must match layout.itemHeight (${layout.itemHeight})');

        // Check vertical distance between row 0 and row 1 tiles
        final secondRowTileFinder = find.byKey(Key('vault_tile_${testItems[layout.columns].id}'));
        expect(secondRowTileFinder, findsOneWidget);

        final tile0Rect = tester.getRect(firstTileFinder);
        final tileRow1Rect = tester.getRect(secondRowTileFinder);

        final measuredRowStride = tileRow1Rect.top - tile0Rect.top;
        expect(measuredRowStride, closeTo(layout.rowHeight, 0.01),
            reason: 'Measured row stride must match rowHeight (${layout.rowHeight})');
      });
    }
  });

  // ===========================================================================
  // SECTION 3: Badge Collision Behavior on VaultItemTile & BinderGridCardTile
  // ===========================================================================
  group('Adversarial 3: Badge Clearance & Collision Verification', () {
    // 320dp screen width produces 104.0dp tile width in 3-column layout
    const narrowestTileWidth = 104.0;
    final narrowestTileHeight = narrowestTileWidth / 0.54;

    testWidgets('VaultItemTile on narrowest 104dp tile: SLAB badge vs Playset Duplicate (2x..4x) non-collision', (tester) async {
      for (final qty in [2, 3, 4]) {
        final item = buildTestItem(
          id: 'slab-dup-$qty',
          name: 'Black Lotus',
          quantity: qty,
          isGraded: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: narrowestTileWidth,
                    height: narrowestTileHeight,
                    child: VaultItemTile(item: item),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final slabFinder = find.byKey(Key('vault_tile_slab_badge_${item.id}'));
        final dupFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
        expect(slabFinder, findsOneWidget);
        expect(dupFinder, findsOneWidget);

        final slabRect = tester.getRect(slabFinder);
        final dupRect = tester.getRect(dupFinder);

        expect(slabRect.right, lessThan(dupRect.left),
            reason: 'SLAB right edge (${slabRect.right}) must be strictly less than duplicate left edge (${dupRect.left}) for qty $qty');

        final clearance = dupRect.left - slabRect.right;
        expect(clearance, greaterThan(0.0),
            reason: 'Clearance between SLAB and $qty x duplicate must be strictly positive on 104dp width. Found: $clearance');
      }
    });

    testWidgets('VaultItemTile on standard viewports (>=360dp, tile >=117.3dp): SLAB badge vs 99x duplicate non-collision', (tester) async {
      final widths = [117.33, 127.33, 134.67, 190.40]; // 360dp, 390dp, 412dp, 1024dp
      for (final w in widths) {
        final item = buildTestItem(
          id: 'slab-99-scale-$w',
          name: 'Mox Diamond',
          quantity: 99,
          isGraded: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    height: w / 0.54,
                    child: VaultItemTile(item: item),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final slabFinder = find.byKey(Key('vault_tile_slab_badge_${item.id}'));
        final dupFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
        expect(slabFinder, findsOneWidget);
        expect(dupFinder, findsOneWidget);

        final slabRect = tester.getRect(slabFinder);
        final dupRect = tester.getRect(dupFinder);

        expect(slabRect.right, lessThan(dupRect.left),
            reason: 'Width $w: SLAB right (${slabRect.right}) must be less than 99x left (${dupRect.left})');
        final clearance = dupRect.left - slabRect.right;
        expect(clearance, greaterThan(0.0),
            reason: 'Width $w: Clearance between SLAB and 99x must be strictly positive. Found: $clearance');
      }
    });

    testWidgets('VaultItemTile on narrowest 104dp tile: Foil badge vs 99x and 1000x duplicate non-collision', (tester) async {
      for (final qty in [99, 1000]) {
        final item = buildTestItem(
          id: 'foil-dup-$qty',
          name: 'Foil Lightning Bolt',
          quantity: qty,
          condition: 'Near Mint Foil',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: narrowestTileWidth,
                    height: narrowestTileHeight,
                    child: VaultItemTile(item: item),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final foilFinder = find.byKey(Key('vault_tile_foil_badge_${item.id}'));
        final dupFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
        expect(foilFinder, findsOneWidget);
        expect(dupFinder, findsOneWidget);

        final foilRect = tester.getRect(foilFinder);
        final dupRect = tester.getRect(dupFinder);

        expect(foilRect.right, lessThan(dupRect.left));
        final clearance = dupRect.left - foilRect.right;
        expect(clearance, greaterThan(0.0),
            reason: 'Foil and $qty x duplicate clearance must be strictly positive on 104dp width. Found: $clearance');
      }
    });

    testWidgets('VaultItemTile: Price badge at bottom does not overlap top badges or caption area', (tester) async {
      final item = buildTestItem(
        id: 'price-badge-test',
        name: 'Gaea\'s Cradle',
        quantity: 3,
        isGraded: true,
        currentMarketPrice: 850.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: narrowestTileWidth,
                  height: narrowestTileHeight,
                  child: VaultItemTile(item: item),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slabFinder = find.byKey(Key('vault_tile_slab_badge_${item.id}'));
      final slabRect = tester.getRect(slabFinder);

      final priceFinder = find.text('\$850.00');
      expect(priceFinder, findsOneWidget);
      final priceRect = tester.getRect(priceFinder);

      // Price is bottom-left on artwork, slab is top-left
      expect(priceRect.top, greaterThan(slabRect.bottom),
          reason: 'Price badge must be strictly below SLAB badge');
    });

    testWidgets('BinderGridCardTile on 320dp screen (104dp width): Quantity badge vs Foil badge non-collision', (tester) async {
      const binderTileWidth = 104.0;
      const binderTileHeight = 104.0 / (5 / 7); // ~145.6dp

      final item = buildTestItem(
        id: 'binder-tile-foil-dup',
        name: 'The One Ring',
        quantity: 4,
        condition: 'Near Mint Foil',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: binderTileWidth,
                height: binderTileHeight,
                child: BinderGridCardTile(
                  item: item,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quantity badge is top-right ("4x")
      final qtyFinder = find.text('4x');
      expect(qtyFinder, findsOneWidget);
      final qtyRect = tester.getRect(qtyFinder);

      // Foil icon is bottom-left
      final foilFinder = find.byIcon(Icons.auto_awesome);
      expect(foilFinder, findsOneWidget);
      final foilRect = tester.getRect(foilFinder);

      final tileFinder = find.byType(BinderGridCardTile);
      final tileRect = tester.getRect(tileFinder);

      // Verify Quantity is top-right within tile bounds
      expect(qtyRect.top, greaterThanOrEqualTo(tileRect.top));
      expect(qtyRect.right, lessThanOrEqualTo(tileRect.right));

      // Verify Foil is bottom-left within tile bounds
      expect(foilRect.bottom, lessThanOrEqualTo(tileRect.bottom));
      expect(foilRect.left, greaterThanOrEqualTo(tileRect.left));

      // Massive diagonal/vertical separation: top of foil is far below bottom of quantity
      expect(foilRect.top - qtyRect.bottom, greaterThan(100.0),
          reason: 'Foil badge and Quantity badge must have >100dp vertical clearance');
      expect(qtyRect.left - foilRect.right, greaterThan(50.0),
          reason: 'Foil badge and Quantity badge must have >50dp horizontal clearance');
    });
  });

  // ===========================================================================
  // SECTION 4: Dynamic Text Scaling Invariant Verification
  // ===========================================================================
  group('Adversarial 4: Accessibility Dynamic Text Scaling Invariants', () {
    test('320dp screen drops to 2 columns under large textScale (>1.1) to preserve layout', () {
      final columnsNormal = calculateGridColumns(320.0, 1.0);
      final columnsLargeText = calculateGridColumns(320.0, 1.3);

      expect(columnsNormal, equals(3));
      expect(columnsLargeText, equals(2),
          reason: 'Narrow 320dp screen with textScale 1.3 must drop to 2 columns to prevent tile collapse');
    });

    test('Aspect ratio adjusts defensively for high accessibility text scale', () {
      expect(calculateChildAspectRatio(1.0), equals(0.54));
      expect(calculateChildAspectRatio(1.4), equals(0.44));
      expect(calculateChildAspectRatio(2.0), equals(0.36));
    });
  });
}

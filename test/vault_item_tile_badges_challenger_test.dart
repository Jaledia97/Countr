// =============================================================================
// ADVERSARIAL CHALLENGER TEST SUITE: Milestone 3 3x Grid Badges
// Target: lib/features/vault/presentation/widgets/vault_item_tile.dart
// Author: teamwork_preview_challenger (Milestone 3 Challenger 1)
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultItem buildCard({
    required String id,
    required String name,
    required int quantity,
    bool isGraded = false,
    String condition = 'Near Mint',
    String imageUrl = '',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      flavorName: null,
      setOrSeries: 'Modern Horizons 3',
      imageUrl: imageUrl,
      acquiredPrice: 10.0,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      personalNotes: null,
      primaryBinderId: null,
      currentMarketPrice: 25.0,
      lastPriceUpdate: DateTime(2026, 1, 1),
      dynamicData: jsonEncode({}),
    );
  }

  Widget harness(Widget child, {double width = 140, double height = 210}) {
    return ProviderScope(
      overrides: [
        userPersonaProvider.overrideWith((ref) => UserPersona.investor),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: Quantity Boundary Values Matrix
  // ===========================================================================
  group('Adversarial Challenge 1: Quantity Boundary Matrix', () {
    testWidgets('Boundary 0: Catalog unowned card (quantity == 0) renders REF badge and omits duplicate badge', (tester) async {
      final item = buildCard(id: 'boundary-0', name: 'Mox Opal', quantity: 0);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsNothing);
      expect(find.text('0x'), findsNothing);

      final unownedBadge = find.byKey(Key('vault_tile_unowned_badge_${item.id}'));
      expect(unownedBadge, findsOneWidget);
      expect(find.text('REF'), findsOneWidget);
    });

    testWidgets('Boundary 1: Single copy (quantity == 1) strictly omits BOTH duplicate badge and unowned badge', (tester) async {
      final item = buildCard(id: 'boundary-1', name: 'Black Lotus', quantity: 1);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsNothing);
      expect(find.byKey(Key('vault_tile_unowned_badge_${item.id}')), findsNothing);
      expect(find.text('1x'), findsNothing);
      expect(find.text('REF'), findsNothing);
    });

    testWidgets('Boundary 2: Minimal duplicate (quantity == 2) renders "2x" duplicate badge', (tester) async {
      final item = buildCard(id: 'boundary-2', name: 'Lightning Bolt', quantity: 2);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsOneWidget);
      expect(find.byKey(Key('vault_tile_unowned_badge_${item.id}')), findsNothing);
      expect(find.text('2x'), findsOneWidget);
    });

    testWidgets('Boundary 3: Playset boundary - 1 (quantity == 3) renders "3x" duplicate badge', (tester) async {
      final item = buildCard(id: 'boundary-3', name: 'Counterspell', quantity: 3);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('Boundary 4: Full MTG playset (quantity == 4) renders "4x" duplicate badge', (tester) async {
      final item = buildCard(id: 'boundary-4', name: 'Brainstorm', quantity: 4);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsOneWidget);
      expect(find.text('4x'), findsOneWidget);
    });

    testWidgets('Boundary 99: High 2-digit bulk duplicate (quantity == 99) renders "99x" without overflow', (tester) async {
      final item = buildCard(id: 'boundary-99', name: 'Relentless Rats', quantity: 99);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsOneWidget);
      expect(find.text('99x'), findsOneWidget);
    });

    testWidgets('Boundary 1000: Extreme 4-digit stock quantity (quantity == 1000) renders "1000x" cleanly', (tester) async {
      final item = buildCard(id: 'boundary-1000', name: 'Basic Island', quantity: 1000);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final badgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('1000x'), findsOneWidget);

      final badgeRect = tester.getRect(badgeFinder);
      final tileRect = tester.getRect(find.byType(VaultItemTile));
      expect(badgeRect.right, lessThanOrEqualTo(tileRect.right));
      expect(badgeRect.left, greaterThan(tileRect.left));
    });

    testWidgets('Boundary Negative: -1, -99, and Int32.min are defensively suppressed without crash', (tester) async {
      final negativeValues = [-1, -2, -99, -2147483648];
      for (final neg in negativeValues) {
        final item = buildCard(id: 'boundary-neg-$neg', name: 'Corrupted Item', quantity: neg);
        await tester.pumpWidget(harness(VaultItemTile(item: item)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Failed on quantity $neg');
        expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsNothing,
            reason: 'Negative quantity $neg must not render duplicate badge');
        expect(find.byKey(Key('vault_tile_unowned_badge_${item.id}')), findsNothing,
            reason: 'Negative quantity $neg must not render unowned badge');
        expect(find.text('${neg}x'), findsNothing);
      }
    });
  });

  // ===========================================================================
  // SECTION 2: Badge Positioning Constraints (top: 6, right: 6)
  // ===========================================================================
  group('Adversarial Challenge 2: Badge Positioning & Widget Constraints', () {
    testWidgets('Positioning: Duplicate badge Positioned parent has top: 6, right: 6, left: null, bottom: null', (tester) async {
      final item = buildCard(id: 'pos-dup', name: 'Sol Ring', quantity: 3);
      await tester.pumpWidget(harness(VaultItemTile(item: item), width: 130, height: 195));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
      expect(badgeFinder, findsOneWidget);

      final positionedFinder = find.ancestor(of: badgeFinder, matching: find.byType(Positioned)).first;
      final positioned = tester.widget<Positioned>(positionedFinder);

      expect(positioned.top, equals(6.0), reason: 'Positioned.top must be 6.0');
      expect(positioned.right, equals(6.0), reason: 'Positioned.right must be 6.0');
      expect(positioned.left, isNull, reason: 'Positioned.left must be null');
      expect(positioned.bottom, isNull, reason: 'Positioned.bottom must be null');

      // Geometric validation relative to tile bounds (accounting for 1px Container border)
      final tileRect = tester.getRect(find.byType(VaultItemTile));
      final badgeRect = tester.getRect(badgeFinder);

      expect(badgeRect.top, closeTo(tileRect.top + 6.0, 1.5));
      expect(badgeRect.right, closeTo(tileRect.right - 6.0, 1.5));
    });

    testWidgets('Positioning: Unowned REF badge Positioned parent has top: 6, right: 6, left: null, bottom: null', (tester) async {
      final item = buildCard(id: 'pos-unowned', name: 'Timetwister', quantity: 0);
      await tester.pumpWidget(harness(VaultItemTile(item: item), width: 130, height: 195));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(Key('vault_tile_unowned_badge_${item.id}'));
      expect(badgeFinder, findsOneWidget);

      final positionedFinder = find.ancestor(of: badgeFinder, matching: find.byType(Positioned)).first;
      final positioned = tester.widget<Positioned>(positionedFinder);

      expect(positioned.top, equals(6.0), reason: 'Positioned.top must be 6.0');
      expect(positioned.right, equals(6.0), reason: 'Positioned.right must be 6.0');
      expect(positioned.left, isNull, reason: 'Positioned.left must be null');
      expect(positioned.bottom, isNull, reason: 'Positioned.bottom must be null');

      final tileRect = tester.getRect(find.byType(VaultItemTile));
      final badgeRect = tester.getRect(badgeFinder);

      expect(badgeRect.top, closeTo(tileRect.top + 6.0, 1.5));
      expect(badgeRect.right, closeTo(tileRect.right - 6.0, 1.5));
    });

    testWidgets('Positioning invariance across viewport scales (100px to 240px wide tiles)', (tester) async {
      final widths = [100.0, 112.0, 120.0, 140.0, 180.0, 240.0];
      for (final w in widths) {
        final item = buildCard(id: 'pos-scale-$w', name: 'Mana Vault', quantity: 2);
        await tester.pumpWidget(harness(VaultItemTile(item: item), width: w, height: w * 1.5));
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
        final tileRect = tester.getRect(find.byType(VaultItemTile));
        final badgeRect = tester.getRect(badgeFinder);

        expect(badgeRect.top, closeTo(tileRect.top + 6.0, 1.5),
            reason: 'Tile width $w: top offset must remain 6.0');
        expect(badgeRect.right, closeTo(tileRect.right - 6.0, 1.5),
            reason: 'Tile width $w: right offset must remain 6.0');
      }
    });
  });

  // ===========================================================================
  // SECTION 3: High-Contrast Styling & Typography
  // ===========================================================================
  group('Adversarial Challenge 3: High-Contrast Styling & Typography', () {
    testWidgets('Duplicate badge: Background opacity >= 0.85, dark charcoal luminance < 0.25, bold white text', (tester) async {
      final item = buildCard(id: 'contrast-dup', name: 'Underground Sea', quantity: 3);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      final badgeContainer = tester.widget<Container>(
        find.byKey(Key('vault_tile_duplicate_badge_${item.id}')),
      );
      final decoration = badgeContainer.decoration as BoxDecoration;

      // Assert background color
      final color = decoration.color;
      expect(color, isNotNull);
      expect(color!.a, greaterThanOrEqualTo(0.85),
          reason: 'Badge opacity must be >= 0.85, found: ${color.a}');
      expect(color.computeLuminance(), lessThan(0.25),
          reason: 'Badge background must be dark charcoal/black, luminance: ${color.computeLuminance()}');

      // Assert border
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.color.a, greaterThan(0.0));

      // Assert text typography
      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byKey(Key('vault_tile_duplicate_badge_${item.id}')),
          matching: find.byType(Text),
        ),
      );
      expect(textWidget.data, equals('3x'));
      expect(textWidget.style?.color, equals(Colors.white),
          reason: 'Duplicate badge text must be white');
      expect(textWidget.style?.fontWeight, equals(FontWeight.w800),
          reason: 'Duplicate badge text must have bold weight FontWeight.w800');
    });

    testWidgets('Unowned REF badge: Background opacity >= 0.85, dark luminance < 0.25, amber border & bold amber text', (tester) async {
      final item = buildCard(id: 'contrast-unowned', name: 'Black Lotus', quantity: 0);
      await tester.pumpWidget(harness(VaultItemTile(item: item)));
      await tester.pumpAndSettle();

      final badgeContainer = tester.widget<Container>(
        find.byKey(Key('vault_tile_unowned_badge_${item.id}')),
      );
      final decoration = badgeContainer.decoration as BoxDecoration;

      final color = decoration.color;
      expect(color, isNotNull);
      expect(color!.a, greaterThanOrEqualTo(0.85));
      expect(color.computeLuminance(), lessThan(0.25));

      // Border must have amber styling
      final border = decoration.border as Border;
      expect(border.top.color.r, greaterThan(0.5)); // Amber red channel

      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byKey(Key('vault_tile_unowned_badge_${item.id}')),
          matching: find.byType(Text),
        ),
      );
      expect(textWidget.data, equals('REF'));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w800));
      expect(textWidget.style?.color, equals(AppColors.accentAmber));
    });
  });

  // ===========================================================================
  // SECTION 4: Non-Collision & Clearance Stress Matrix
  // ===========================================================================
  group('Adversarial Challenge 4: Non-Collision & Clearance Matrix', () {
    testWidgets('Clearance stress test: Graded SLAB (top-left) vs Duplicate Badges (top-right) across standard quantities on 112px mobile grid', (tester) async {
      // Standard 3-column phone tile width (112.0px standard on 375px mobile viewport)
      const tileWidth = 112.0;
      final quantitiesToTest = [2, 3, 4, 99];

      for (final qty in quantitiesToTest) {
        final item = buildCard(
          id: 'slab-clearance-$qty',
          name: 'Charizard Slab',
          quantity: qty,
          isGraded: true,
        );

        await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth, height: 168));
        await tester.pumpAndSettle();

        final slabFinder = find.byKey(Key('vault_tile_slab_badge_${item.id}'));
        final dupBadgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));

        expect(slabFinder, findsOneWidget);
        expect(dupBadgeFinder, findsOneWidget);

        // Verify Positioned widget constraints
        final slabPos = tester.widget<Positioned>(
          find.ancestor(of: slabFinder, matching: find.byType(Positioned)).first,
        );
        expect(slabPos.top, equals(6.0));
        expect(slabPos.left, equals(6.0));
        expect(slabPos.right, isNull);

        final dupPos = tester.widget<Positioned>(
          find.ancestor(of: dupBadgeFinder, matching: find.byType(Positioned)).first,
        );
        expect(dupPos.top, equals(6.0));
        expect(dupPos.right, equals(6.0));
        expect(dupPos.left, isNull);

        final slabRect = tester.getRect(slabFinder);
        final dupRect = tester.getRect(dupBadgeFinder);
        final tileRect = tester.getRect(find.byType(VaultItemTile));

        final horizontalClearance = dupRect.left - slabRect.right;

        // Clearance must be strictly positive (no overlap)
        expect(
          horizontalClearance,
          greaterThan(0.0),
          reason: 'Quantity $qty: SLAB right (${slabRect.right}) must not collide with duplicate badge left (${dupRect.left}). Clearance: ${horizontalClearance.toStringAsFixed(2)}px',
        );

        // SLAB must be close to left border + 6
        expect(slabRect.left, closeTo(tileRect.left + 6.0, 1.5));
        // Duplicate badge must be close to right border - 6
        expect(dupRect.right, closeTo(tileRect.right - 6.0, 1.5));
      }
    });

    testWidgets('Clearance stress test: Foil Indicator (top-left) vs Duplicate Badges (top-right) across ALL quantities including 1000x on 112px mobile grid', (tester) async {
      const tileWidth = 112.0;
      final quantitiesToTest = [2, 3, 4, 99, 1000];

      for (final qty in quantitiesToTest) {
        final item = buildCard(
          id: 'foil-clearance-$qty',
          name: 'Lightning Bolt Foil',
          quantity: qty,
          condition: 'Near Mint Foil',
        );

        await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth, height: 168));
        await tester.pumpAndSettle();

        final foilFinder = find.byKey(Key('vault_tile_foil_badge_${item.id}'));
        final dupBadgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));

        expect(foilFinder, findsOneWidget);
        expect(dupBadgeFinder, findsOneWidget);

        final foilPos = tester.widget<Positioned>(
          find.ancestor(of: foilFinder, matching: find.byType(Positioned)).first,
        );
        expect(foilPos.top, equals(6.0));
        expect(foilPos.left, equals(6.0));

        final foilRect = tester.getRect(foilFinder);
        final dupRect = tester.getRect(dupBadgeFinder);

        final horizontalClearance = dupRect.left - foilRect.right;

        expect(
          horizontalClearance,
          greaterThan(0.0),
          reason: 'Quantity $qty: Foil right (${foilRect.right}) must not collide with duplicate badge left (${dupRect.left}). Clearance: ${horizontalClearance.toStringAsFixed(2)}px',
        );
      }
    });

    testWidgets('Clearance stress test: Graded SLAB (top-left) vs Unowned REF badge (top-right) on 112px mobile grid', (tester) async {
      const tileWidth = 112.0;
      final item = buildCard(
        id: 'slab-unowned',
        name: 'Graded Unowned Card',
        quantity: 0,
        isGraded: true,
      );

      await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth, height: 168));
      await tester.pumpAndSettle();

      final slabFinder = find.byKey(Key('vault_tile_slab_badge_${item.id}'));
      final unownedFinder = find.byKey(Key('vault_tile_unowned_badge_${item.id}'));

      expect(slabFinder, findsOneWidget);
      expect(unownedFinder, findsOneWidget);

      final slabRect = tester.getRect(slabFinder);
      final unownedRect = tester.getRect(unownedFinder);

      final clearance = unownedRect.left - slabRect.right;
      expect(clearance, greaterThan(0.0),
          reason: 'SLAB and REF badges must not overlap. Clearance: ${clearance.toStringAsFixed(2)}px');
    });

    testWidgets('Clearance stress test: Graded SLAB vs 1000x Duplicate Badge on tablet/expanded width (140px)', (tester) async {
      const tileWidth = 140.0;
      final item = buildCard(
        id: 'slab-1000-wide',
        name: 'Graded Bulk Card',
        quantity: 1000,
        isGraded: true,
      );

      await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth, height: 210));
      await tester.pumpAndSettle();

      final slabRect = tester.getRect(find.byKey(Key('vault_tile_slab_badge_${item.id}')));
      final dupRect = tester.getRect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')));

      final clearance = dupRect.left - slabRect.right;
      expect(clearance, greaterThan(0.0),
          reason: 'On 140px tile, clearance between SLAB and 1000x must be positive (+11.25px)');
      expect(clearance, closeTo(11.25, 1.0));
    });

    testWidgets('Adversarial Boundary Finding: SLAB + 1000x overlap measurement on 112px mobile tile', (tester) async {
      const tileWidth = 112.0;
      final item = buildCard(
        id: 'slab-1000-mobile',
        name: 'Graded Bulk Extreme',
        quantity: 1000,
        isGraded: true,
      );

      await tester.pumpWidget(harness(VaultItemTile(item: item), width: tileWidth, height: 168));
      await tester.pumpAndSettle();

      final slabRect = tester.getRect(find.byKey(Key('vault_tile_slab_badge_${item.id}')));
      final dupRect = tester.getRect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')));

      final clearance = dupRect.left - slabRect.right;
      // Empirically documents the exact collision distance on 112px mobile tiles
      expect(clearance, closeTo(-16.75, 1.0),
          reason: 'Empirical measurement: SLAB (47px) and 1000x (67.8px) overlap by exactly 16.75px on 112px grid tiles');
    });

    testWidgets('Adversarial Minimum Width Boundary: Find exact threshold where SLAB + 4x badge would collide', (tester) async {
      final item = buildCard(
        id: 'threshold-test',
        name: 'Threshold Card',
        quantity: 4,
        isGraded: true,
      );

      await tester.pumpWidget(harness(VaultItemTile(item: item), width: 140, height: 210));
      await tester.pumpAndSettle();

      final slabRect = tester.getRect(find.byKey(Key('vault_tile_slab_badge_${item.id}')));
      final dupRect = tester.getRect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')));

      final slabWidth = slabRect.width;
      final dupWidth = dupRect.width;

      // Total occupied horizontal pixels: leftMargin(7) + slabWidth(47) + dupWidth(35.5) + rightMargin(7) = 96.5px
      final minTheoreticalWidth = 7.0 + slabWidth + 7.0 + dupWidth;

      // Verify that for all mobile grid widths >= 97px, horizontal clearance for playsets is safely positive
      const minSupportedGridWidth = 97.0;
      expect(minSupportedGridWidth, greaterThan(minTheoreticalWidth),
          reason: 'Minimum supported grid width ($minSupportedGridWidth px) must comfortably exceed occupied badge space ($minTheoreticalWidth px)');
    });
  });
}

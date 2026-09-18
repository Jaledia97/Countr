// =============================================================================
// TEST SUITE: test/m3_empirical_adversarial_review_test.dart
// Adversarial Stress & Robustness Review for Milestone 3 (Reviewer 2)
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultItem makeCard({
    required String id,
    required String name,
    required int quantity,
    String collectionType = 'mtg',
    String setOrSeries = 'Standard Set',
    String? flavorName,
    String imageUrl = '',
    double currentMarketPrice = 25.0,
    double acquiredPrice = 20.0,
    String condition = 'NM',
    bool isGraded = false,
    Map<String, dynamic>? dynamicDataMap,
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
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      personalNotes: null,
      primaryBinderId: null,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime(2026, 1, 1),
      dynamicData: rawDynamicData ?? jsonEncode(dynamicDataMap ?? {}),
    );
  }

  Widget wrapInApp(Widget child, {UserPersona persona = UserPersona.investor}) {
    return ProviderScope(
      overrides: [
        userPersonaProvider.overrideWith((ref) => persona),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  group('Milestone 3 Adversarial Review: Tile Badges & Layout Robustness', () {
    testWidgets('Extremely narrow tile width (100px) does not overflow with SLAB + 99x', (tester) async {
      final card = makeCard(
        id: 'tight-tile',
        name: 'Urza',
        quantity: 99,
        isGraded: true,
      );

      await tester.pumpWidget(
        wrapInApp(
          SizedBox(
            width: 100,
            height: 150,
            child: VaultItemTile(item: card),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_slab_badge_${card.id}')), findsOneWidget);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsOneWidget);
      expect(find.text('99x'), findsOneWidget);
    });

    testWidgets('Huge quantity 9999x renders cleanly without exception', (tester) async {
      final card = makeCard(
        id: 'huge-qty',
        name: 'Mountain',
        quantity: 9999,
      );

      await tester.pumpWidget(
        wrapInApp(
          SizedBox(
            width: 140,
            height: 200,
            child: VaultItemTile(item: card),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('9999x'), findsOneWidget);
    });

    testWidgets('Negative quantity does not render duplicate or unowned badge', (tester) async {
      final card = makeCard(
        id: 'neg-qty',
        name: 'Negative Item',
        quantity: -5,
      );

      await tester.pumpWidget(
        wrapInApp(
          SizedBox(
            width: 140,
            height: 200,
            child: VaultItemTile(item: card),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsNothing);
      expect(find.byKey(Key('vault_tile_unowned_badge_${card.id}')), findsNothing);
    });

    testWidgets('Graded unowned card renders SLAB at top-left and REF at top-right', (tester) async {
      final card = makeCard(
        id: 'graded-unowned',
        name: 'Alpha Black Lotus',
        quantity: 0,
        isGraded: true,
      );

      await tester.pumpWidget(
        wrapInApp(
          SizedBox(
            width: 140,
            height: 200,
            child: VaultItemTile(item: card),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_slab_badge_${card.id}')), findsOneWidget);
      expect(find.byKey(Key('vault_tile_unowned_badge_${card.id}')), findsOneWidget);
      expect(find.text('SLAB'), findsOneWidget);
      expect(find.text('REF'), findsOneWidget);

      final slabRect = tester.getRect(find.byKey(Key('vault_tile_slab_badge_${card.id}')));
      final refRect = tester.getRect(find.byKey(Key('vault_tile_unowned_badge_${card.id}')));
      expect(slabRect.right, lessThan(refRect.left));
    });
  });

  group('Milestone 3 Adversarial Review: List View Thumbnail & Persona Robustness', () {
    testWidgets('Unknown collection type renders generic style icon fallback', (tester) async {
      final card = makeCard(
        id: 'unknown-coll',
        name: 'Custom Card',
        quantity: 1,
        collectionType: 'lorcana',
        imageUrl: '',
      );

      await tester.pumpWidget(wrapInApp(VaultItemCard(item: card)));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      final fallbackFinder = find.byKey(Key('vault_card_leading_fallback_${card.id}'));
      expect(fallbackFinder, findsOneWidget);
      expect(
        find.descendant(of: fallbackFinder, matching: find.byIcon(Icons.style_rounded)),
        findsOneWidget,
      );
    });

    testWidgets('Deeply nested or odd types in dynamicData JSON does not crash', (tester) async {
      final oddPayloads = [
        '{"image_uris": {"small": 12345}}',
        '{"image_uris": {"small": true}}',
        '{"image_uris": {"small": []}}',
        '{"card_faces": [{"image_uris": {"small": {}}}]}',
        '{"card_faces": "not list"}',
      ];

      for (int i = 0; i < oddPayloads.length; i++) {
        final card = makeCard(
          id: 'odd-json-$i',
          name: 'Odd JSON Card $i',
          quantity: 1,
          rawDynamicData: oddPayloads[i],
        );

        await tester.pumpWidget(wrapInApp(VaultItemCard(item: card)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(VaultItemCard), findsOneWidget);
      }
    });

    testWidgets('Investor mode shows financial metrics while Player mode shows mechanics, with identical leading thumbnails', (tester) async {
      final card = makeCard(
        id: 'persona-parity',
        name: 'Tarmogoyf',
        quantity: 2,
        currentMarketPrice: 35.0,
        acquiredPrice: 20.0,
        dynamicDataMap: {
          'mana_cost': '{1}{G}',
          'power': '1+*',
          'toughness': '2+*',
          'keywords': ['Trample'],
        },
      );

      // 1. Check Investor Mode
      await tester.pumpWidget(wrapInApp(VaultItemCard(item: card, persona: UserPersona.investor), persona: UserPersona.investor));
      await tester.pumpAndSettle();

      expect(find.text('\$35.00'), findsOneWidget);
      expect(find.byKey(Key('vault_card_leading_fallback_${card.id}')), findsOneWidget);
      // Keyword Trample should not be visible in investor financial row
      expect(find.text('Trample'), findsNothing);

      // 2. Check Player Mode
      await tester.pumpWidget(wrapInApp(VaultItemCard(item: card, persona: UserPersona.player), persona: UserPersona.player));
      await tester.pumpAndSettle();

      // Power/Toughness should be visible in player mechanics row
      expect(find.text('⚔️ 1+* / 🛡️ 2+*'), findsOneWidget);
      expect(find.text('Trample'), findsOneWidget);
      // Leading fallback thumbnail still intact
      expect(find.byKey(Key('vault_card_leading_fallback_${card.id}')), findsOneWidget);
    });
  });
}

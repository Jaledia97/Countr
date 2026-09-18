// =============================================================================
// TEST SUITE: test/vault_ui_polish_test.dart
// Milestone 3: Vault UI Polish (3x Grid Badges & List View Thumbnails)
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

  /// Helper factory to construct standard test [VaultItem] models.
  VaultItem createTestCard({
    required String id,
    required String name,
    required int quantity,
    String collectionType = 'mtg',
    String setOrSeries = 'Dominaria',
    String? flavorName,
    String imageUrl = '',
    double currentMarketPrice = 15.0,
    double acquiredPrice = 10.0,
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

  /// Helper harness to wrap widgets in MaterialApp and optional ProviderScope.
  Widget buildHarness(
    Widget child, {
    UserPersona persona = UserPersona.investor,
  }) {
    return ProviderScope(
      overrides: [
        userPersonaProvider.overrideWith((ref) => persona),
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
  // GROUP 1: 3x Grid Quantity & Unowned Badges (VaultItemTile)
  // ===========================================================================
  group('Milestone 3 - Requirement R3: 3x Grid Quantity Badges (VaultItemTile)', () {
    // -------------------------------------------------------------------------
    // 1.1 Placement & Top-Right Alignment
    // -------------------------------------------------------------------------
    testWidgets('M3.1.1: Duplicate badge is positioned strictly at the top-right corner', (tester) async {
      final item = createTestCard(
        id: 'dup-pos-test',
        name: 'Sol Ring',
        quantity: 3,
        imageUrl: '',
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
      expect(badgeFinder, findsOneWidget);

      // Verify Positioned widget constraints
      final positionedWidget = tester.widget<Positioned>(
        find.ancestor(of: badgeFinder, matching: find.byType(Positioned)).first,
      );
      expect(positionedWidget.top, equals(6.0), reason: 'Badge must have top: 6');
      expect(positionedWidget.right, equals(6.0), reason: 'Badge must have right: 6');
      expect(positionedWidget.left, isNull, reason: 'Badge must not be pinned to the left edge');

      // Geometric screen coordinate validation
      final tileRect = tester.getRect(find.byType(VaultItemTile));
      final badgeRect = tester.getRect(badgeFinder);

      // Top edge must be within ~6px of tile top
      expect(badgeRect.top, closeTo(tileRect.top + 6.0, 2.0));
      // Right edge must be within ~6px of tile right
      expect(badgeRect.right, closeTo(tileRect.right - 6.0, 2.0));
      // Badge must be strictly on the right half of the tile
      expect(badgeRect.left, greaterThan(tileRect.center.dx));
    });

    testWidgets('M3.1.2: Unowned catalog card (quantity == 0) renders unowned reference badge at top-right', (tester) async {
      final unownedItem = createTestCard(
        id: 'unowned-pos-test',
        name: 'Mox Diamond',
        quantity: 0,
        imageUrl: '',
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: unownedItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Duplicate badge must NOT be present
      expect(find.byKey(Key('vault_tile_duplicate_badge_${unownedItem.id}')), findsNothing);

      // Unowned reference badge must be present
      final unownedBadgeFinder = find.byKey(Key('vault_tile_unowned_badge_${unownedItem.id}'));
      expect(unownedBadgeFinder, findsOneWidget);
      expect(find.text('REF'), findsOneWidget);

      // Verify top-right positioning
      final positioned = tester.widget<Positioned>(
        find.ancestor(of: unownedBadgeFinder, matching: find.byType(Positioned)).first,
      );
      expect(positioned.top, equals(6.0));
      expect(positioned.right, equals(6.0));
      expect(positioned.left, isNull);

      final tileRect = tester.getRect(find.byType(VaultItemTile));
      final badgeRect = tester.getRect(unownedBadgeFinder);
      expect(badgeRect.right, closeTo(tileRect.right - 6.0, 2.0));
    });

    // -------------------------------------------------------------------------
    // 1.2 High-Contrast Dark Background (Opacity >= 0.85)
    // -------------------------------------------------------------------------
    testWidgets('M3.1.3: Duplicate badge background has opacity >= 0.85 and dark charcoal/black luminance', (tester) async {
      final item = createTestCard(
        id: 'contrast-test',
        name: 'Force of Will',
        quantity: 4,
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byKey(Key('vault_tile_duplicate_badge_${item.id}')),
      );
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;

      final color = decoration.color;
      expect(color, isNotNull, reason: 'Badge must have a background color');

      // Opacity requirement: opacity >= 0.85
      final alphaChannel = color!.a; // Flutter 3.27+ alpha value (0.0 to 1.0)
      expect(alphaChannel, greaterThanOrEqualTo(0.85),
          reason: 'Duplicate badge background opacity must be >= 0.85 (got $alphaChannel)');

      // Dark charcoal/black requirement: luminance < 0.25 (ensures strong contrast against white text)
      expect(color.computeLuminance(), lessThan(0.25),
          reason: 'Badge background must be a dark charcoal or black hue');

      // Border styling check
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, equals(BorderRadius.circular(6)));
    });

    testWidgets('M3.1.4: Unowned badge background has opacity >= 0.85 with amber accent border', (tester) async {
      final item = createTestCard(
        id: 'unowned-contrast-test',
        name: 'Mana Crypt',
        quantity: 0,
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byKey(Key('vault_tile_unowned_badge_${item.id}')),
      );
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, isNotNull);
      expect(decoration.color!.a, greaterThanOrEqualTo(0.85));
      expect(decoration.color!.computeLuminance(), lessThan(0.25));
      expect(decoration.border, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 1.3 Bold White Typography
    // -------------------------------------------------------------------------
    testWidgets('M3.1.5: Duplicate badge displays bold white text formatted as "\${quantity}x"', (tester) async {
      final item = createTestCard(
        id: 'typo-test',
        name: 'Demonic Tutor',
        quantity: 5,
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFinder = find.descendant(
        of: find.byKey(Key('vault_tile_duplicate_badge_${item.id}')),
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.data, equals('5x'));
      expect(textWidget.style?.color, equals(Colors.white),
          reason: 'Duplicate badge text must be bold white');
      expect(textWidget.style?.fontWeight, equals(FontWeight.w800),
          reason: 'Duplicate badge text must have bold weight (FontWeight.w800)');
      expect(textWidget.style?.fontSize, closeTo(10.5, 0.5));
    });

    // -------------------------------------------------------------------------
    // 1.4 Visibility Invariants & Bounds Matrix
    // -------------------------------------------------------------------------
    testWidgets('M3.1.6: Single owned copy (quantity == 1) strictly HIDES duplicate badge', (tester) async {
      final item = createTestCard(
        id: 'single-copy-test',
        name: 'Black Lotus',
        quantity: 1,
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No duplicate badge
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsNothing);
      expect(find.text('1x'), findsNothing);
      // No unowned badge
      expect(find.byKey(Key('vault_tile_unowned_badge_${item.id}')), findsNothing);
      expect(find.text('REF'), findsNothing);
    });

    testWidgets('M3.1.7: Duplicate badge scales cleanly for large quantities without overflow', (tester) async {
      final item = createTestCard(
        id: 'large-qty-test',
        name: 'Relentless Rats',
        quantity: 99,
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsOneWidget);
      expect(find.text('99x'), findsOneWidget);
    });

    testWidgets('M3.1.8: Defensive check: negative quantity does NOT render duplicate badge', (tester) async {
      final item = createTestCard(
        id: 'negative-qty-test',
        name: 'Corrupted Item',
        quantity: -2,
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 140,
            height: 210,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${item.id}')), findsNothing);
      expect(find.text('-2x'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 1.5 Non-Collision with Relocated Top-Left Indicators
    // -------------------------------------------------------------------------
    testWidgets('M3.1.9: Graded card renders SLAB badge at top-left and duplicate badge at top-right without collision', (tester) async {
      final item = createTestCard(
        id: 'graded-dup-test',
        name: 'Charizard 1st Edition',
        quantity: 2,
        isGraded: true,
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 150,
            height: 220,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SLAB badge must be at top-left
      final slabFinder = find.text('SLAB');
      expect(slabFinder, findsOneWidget);
      final slabPositioned = tester.widget<Positioned>(
        find.ancestor(of: slabFinder, matching: find.byType(Positioned)).first,
      );
      expect(slabPositioned.top, equals(6.0));
      expect(slabPositioned.left, equals(6.0));
      expect(slabPositioned.right, isNull);

      // Duplicate badge must be at top-right
      final dupBadgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
      expect(dupBadgeFinder, findsOneWidget);
      final dupPositioned = tester.widget<Positioned>(
        find.ancestor(of: dupBadgeFinder, matching: find.byType(Positioned)).first,
      );
      expect(dupPositioned.top, equals(6.0));
      expect(dupPositioned.right, equals(6.0));
      expect(dupPositioned.left, isNull);

      // Verify zero collision (horizontal separation)
      final slabRect = tester.getRect(slabFinder);
      final dupRect = tester.getRect(dupBadgeFinder);
      expect(slabRect.right, lessThan(dupRect.left),
          reason: 'SLAB badge on left must not overlap duplicate badge on right');
    });

    testWidgets('M3.1.10: Foil card renders sparkle icon at top-left and duplicate badge at top-right without collision', (tester) async {
      final item = createTestCard(
        id: 'foil-dup-test',
        name: 'Lightning Bolt',
        quantity: 3,
        condition: 'NM Foil',
      );

      await tester.pumpWidget(
        buildHarness(
          SizedBox(
            width: 150,
            height: 220,
            child: VaultItemTile(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final foilFinder = find.byIcon(Icons.auto_awesome);
      expect(foilFinder, findsOneWidget);
      final foilPositioned = tester.widget<Positioned>(
        find.ancestor(of: foilFinder, matching: find.byType(Positioned)).first,
      );
      expect(foilPositioned.top, equals(6.0));
      expect(foilPositioned.left, equals(6.0));

      final dupFinder = find.byKey(Key('vault_tile_duplicate_badge_${item.id}'));
      expect(dupFinder, findsOneWidget);

      final foilRect = tester.getRect(foilFinder);
      final dupRect = tester.getRect(dupFinder);
      expect(foilRect.right, lessThan(dupRect.left));
    });
  });

  // ===========================================================================
  // GROUP 2: List View Thumbnails & Graceful Fallbacks (VaultItemCard)
  // ===========================================================================
  group('Milestone 3 - Requirement R3: List View Thumbnails (VaultItemCard)', () {
    // -------------------------------------------------------------------------
    // 2.1 Artwork Retrieval Hierarchy & Network Image Rendering
    // -------------------------------------------------------------------------
    testWidgets('M3.2.1: Renders Image.network with dynamicData image_uris.small URL', (tester) async {
      final smallUrl = 'https://cards.scryfall.io/small/front/sol_ring.jpg';
      final item = createTestCard(
        id: 'thumb-small-test',
        name: 'Sol Ring',
        quantity: 1,
        dynamicDataMap: {
          'image_uris': {
            'small': smallUrl,
            'normal': 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
          },
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      // Note: We don't pumpAndSettle network images as HTTP is blocked in test binding
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      expect((imageWidget.image as NetworkImage).url, equals(smallUrl));
      expect(imageWidget.fit, equals(BoxFit.cover));

      // Verify rounded container wrapping the image
      final clipContainer = tester.widget<Container>(
        find.ancestor(of: imageFinder, matching: find.byType(Container)).first,
      );
      expect(clipContainer.constraints?.maxWidth ?? (clipContainer.child != null ? 38.0 : null), equals(38.0));
      expect(clipContainer.clipBehavior, equals(Clip.antiAlias));
      final decoration = clipContainer.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(6.0)));
    });

    testWidgets('M3.2.2: DFC card resolves thumbnail from card_faces[0].image_uris.small', (tester) async {
      final dfcFrontSmall = 'https://cards.scryfall.io/small/front/delver_front.jpg';
      final item = createTestCard(
        id: 'thumb-dfc-test',
        name: 'Delver of Secrets // Insectile Aberration',
        quantity: 1,
        dynamicDataMap: {
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'image_uris': {'small': dfcFrontSmall},
            },
            {
              'name': 'Insectile Aberration',
              'image_uris': {'small': 'https://cards.scryfall.io/small/front/delver_back.jpg'},
            },
          ],
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(dfcFrontSmall));
    });

    testWidgets('M3.2.3: Falls back to direct item.imageUrl when dynamicData image_uris is missing', (tester) async {
      final directUrl = 'https://cards.scryfall.io/normal/front/lotus.jpg';
      final item = createTestCard(
        id: 'thumb-direct-test',
        name: 'Black Lotus',
        quantity: 1,
        imageUrl: directUrl,
        dynamicDataMap: {},
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(directUrl));
    });

    // -------------------------------------------------------------------------
    // 2.2 Graceful Fallback on Missing Image URL
    // -------------------------------------------------------------------------
    testWidgets('M3.2.4: Card with empty imageUrl and empty dynamicData renders fallback type icon directly', (tester) async {
      final item = createTestCard(
        id: 'thumb-empty-test',
        name: 'No Image Card',
        quantity: 1,
        imageUrl: '',
        dynamicDataMap: {},
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pumpAndSettle();

      // Zero Image.network widgets must be rendered
      expect(find.byType(Image), findsNothing);

      // Fallback type icon container must be rendered in leading slot
      final fallbackContainerFinder = find.byKey(Key('vault_card_leading_fallback_${item.id}'));
      expect(fallbackContainerFinder, findsOneWidget);

      final iconFinder = find.descendant(
        of: fallbackContainerFinder,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      );
      expect(iconFinder, findsOneWidget);

      final container = tester.widget<Container>(fallbackContainerFinder);
      expect(container.constraints?.maxWidth ?? 38.0, equals(38.0));
    });

    testWidgets('M3.2.5: Card with whitespace-only image URLs cleanly falls back to type icon', (tester) async {
      final item = createTestCard(
        id: 'thumb-whitespace-test',
        name: 'Whitespace Card',
        quantity: 1,
        imageUrl: '   ',
        dynamicDataMap: {
          'image_uris': {'small': '   '},
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      final fallbackContainerFinder = find.byKey(Key('vault_card_leading_fallback_${item.id}'));
      expect(fallbackContainerFinder, findsOneWidget);
      expect(
        find.descendant(
          of: fallbackContainerFinder,
          matching: find.byIcon(Icons.auto_awesome_rounded),
        ),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // 2.3 Graceful Error Handling via errorBuilder
    // -------------------------------------------------------------------------
    testWidgets('M3.2.6: Image.network defines errorBuilder that cleanly returns fallback type icon', (tester) async {
      final item = createTestCard(
        id: 'thumb-error-test',
        name: 'Broken Network Card',
        quantity: 1,
        imageUrl: 'https://broken.domain/image.jpg',
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.errorBuilder, isNotNull,
          reason: 'Image.network must supply an errorBuilder for graceful offline/network failure');

      // Directly trigger errorBuilder to inspect rendered fallback widget
      final errorWidget = imageWidget.errorBuilder!(
        tester.element(imageFinder),
        Exception('Network connection refused (offline)'),
        StackTrace.empty,
      );

      // Pump the fallback widget in isolation
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: errorWidget),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 2.4 Multi-Collection Type Fallbacks
    // -------------------------------------------------------------------------
    testWidgets('M3.2.7: Renders collection-specific fallback icons when image is absent', (tester) async {
      final collections = <String, IconData>{
        'mtg': Icons.auto_awesome_rounded,
        'pokemon': Icons.catching_pokemon_rounded,
        'comic': Icons.menu_book_rounded,
        'sports_card': Icons.sports_football_rounded,
      };

      for (final entry in collections.entries) {
        final item = createTestCard(
          id: 'coll-icon-${entry.key}',
          name: '${entry.key} Item',
          quantity: 1,
          collectionType: entry.key,
          imageUrl: '',
        );

        await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
        await tester.pumpAndSettle();

        final leadingFinder = find.byKey(Key('vault_card_leading_fallback_${item.id}'));
        expect(leadingFinder, findsOneWidget);
        expect(
          find.descendant(
            of: leadingFinder,
            matching: find.byIcon(entry.value),
          ),
          findsOneWidget,
          reason: 'Collection "${entry.key}" must render ${entry.value} in leading fallback slot',
        );
      }
    });

    // -------------------------------------------------------------------------
    // 2.5 Robustness Against Corrupted Dynamic Metadata
    // -------------------------------------------------------------------------
    testWidgets('M3.2.8: Handles malformed and corrupted dynamicData without throwing exceptions', (tester) async {
      final corruptPayloads = [
        '<<not-valid-json>>',
        'null',
        '42',
        '"just a string"',
        '[1, 2, 3]',
        '{"image_uris": null}',
        '{"image_uris": "string_not_map"}',
        '{"image_uris": {"small": null}}',
        '{"card_faces": null}',
        '{"card_faces": []}',
        '{"card_faces": [{}]}',
        '{"card_faces": [{"image_uris": null}]}',
        '{"card_faces": "not_a_list"}',
      ];

      for (int i = 0; i < corruptPayloads.length; i++) {
        final item = createTestCard(
          id: 'corrupt-dyn-$i',
          name: 'Corrupt Item $i',
          quantity: 1,
          imageUrl: '',
          rawDynamicData: corruptPayloads[i],
        );

        await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Failed on corrupt payload #$i: ${corruptPayloads[i]}');
        expect(find.byType(VaultItemCard), findsOneWidget);
        expect(find.text('Corrupt Item $i'), findsOneWidget);
      }
    });

    // -------------------------------------------------------------------------
    // 2.6 Dual Persona Layout Alignment Invariance
    // -------------------------------------------------------------------------
    testWidgets('M3.2.9: Leading thumbnail slot dimensions and text offset are identical across Investor and Player personas', (tester) async {
      final item = createTestCard(
        id: 'persona-thumb-test',
        name: 'Umezawa\'s Jitte',
        quantity: 1,
        imageUrl: '',
      );

      // 1. Investor Mode
      await tester.pumpWidget(buildHarness(VaultItemCard(item: item, persona: UserPersona.investor)));
      await tester.pumpAndSettle();

      final investorTitleRect = tester.getRect(find.text('Umezawa\'s Jitte'));
      final investorIconRect = tester.getRect(find.byKey(Key('vault_card_leading_fallback_${item.id}')));

      // 2. Player Mode
      await tester.pumpWidget(buildHarness(VaultItemCard(item: item, persona: UserPersona.player)));
      await tester.pumpAndSettle();

      final playerTitleRect = tester.getRect(find.text('Umezawa\'s Jitte'));
      final playerIconRect = tester.getRect(find.byKey(Key('vault_card_leading_fallback_${item.id}')));

      // Both must match exactly
      expect(playerIconRect.left, equals(investorIconRect.left));
      expect(playerIconRect.width, equals(investorIconRect.width));
      expect(playerTitleRect.left, equals(investorTitleRect.left),
          reason: 'Text offset must not shift between personas');
    });
  });
}

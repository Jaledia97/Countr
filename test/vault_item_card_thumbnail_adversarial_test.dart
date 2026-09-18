// =============================================================================
// ADVERSARIAL CHALLENGER TEST SUITE: Milestone 3 List View Thumbnails
// Target: lib/features/vault/presentation/widgets/vault_item_card.dart
// Author: teamwork_preview_challenger (Milestone 3 Challenger 2)
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Helper factory to construct standard test [VaultItem] models.
  VaultItem buildCard({
    required String id,
    required String name,
    int quantity = 1,
    String collectionType = 'mtg',
    String setOrSeries = 'Dominaria',
    String? flavorName,
    String imageUrl = '',
    double currentMarketPrice = 25.0,
    double acquiredPrice = 15.0,
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
    double? width,
  }) {
    final wrapped = width != null ? SizedBox(width: width, child: child) : child;
    return ProviderScope(
      overrides: [
        userPersonaProvider.overrideWith((ref) => persona),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: wrapped,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: URL RESOLUTION HIERARCHY ADVERSARIAL STRESS TESTS
  // Priority: Scryfall small -> DFC face 0 small -> imageUrl -> fallback
  // ===========================================================================
  group('Section 1: URL Resolution Hierarchy Strictness & Edge Precedence', () {
    testWidgets('ADV 1.1: Full Competition - Scryfall small strictly dominates DFC face 0 and direct imageUrl', (tester) async {
      const p1ScryfallSmall = 'https://scryfall.io/small/sol_ring.jpg';
      const p2DfcFace0Small = 'https://scryfall.io/small/delver_front.jpg';
      const p3DirectImageUrl = 'https://direct.cdn/lotus.jpg';

      final item = buildCard(
        id: 'adv-comp-1',
        name: 'Sol Ring',
        imageUrl: p3DirectImageUrl,
        dynamicDataMap: {
          'image_uris': {
            'small': p1ScryfallSmall,
            'normal': 'https://scryfall.io/normal/sol_ring.jpg',
          },
          'card_faces': [
            {
              'name': 'Delver Face 0',
              'image_uris': {'small': p2DfcFace0Small},
            },
          ],
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(p1ScryfallSmall),
          reason: 'Scryfall image_uris.small must strictly win over card_faces[0] and direct imageUrl');
    });

    testWidgets('ADV 1.2: P1 missing small key (only normal/art_crop) -> DFC face 0 small promoted over direct imageUrl', (tester) async {
      const p2DfcFace0Small = 'https://scryfall.io/small/dfc_face0.jpg';
      const p3DirectImageUrl = 'https://direct.cdn/direct_lotus.jpg';

      final item = buildCard(
        id: 'adv-p1-no-small',
        name: 'Transforming Werewolf',
        imageUrl: p3DirectImageUrl,
        dynamicDataMap: {
          'image_uris': {
            'normal': 'https://scryfall.io/normal/normal_art.jpg',
            'art_crop': 'https://scryfall.io/art_crop/crop.jpg',
          },
          'card_faces': [
            {
              'name': 'Front Face',
              'image_uris': {'small': p2DfcFace0Small},
            },
            {
              'name': 'Back Face',
              'image_uris': {'small': 'https://scryfall.io/small/dfc_face1.jpg'},
            },
          ],
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(p2DfcFace0Small),
          reason: 'When top-level image_uris lacks "small", DFC face 0 small must take precedence over direct imageUrl');
    });

    testWidgets('ADV 1.3: P1 whitespace small -> DFC face 0 small promoted', (tester) async {
      const p2DfcFace0Small = 'https://scryfall.io/small/dfc_front_trim.jpg';
      const p3Direct = 'https://direct.cdn/card.jpg';

      final item = buildCard(
        id: 'adv-p1-ws',
        name: 'Whitespace Card',
        imageUrl: p3Direct,
        dynamicDataMap: {
          'image_uris': {
            'small': '   \t  \n  ',
          },
          'card_faces': [
            {
              'name': 'Face 0',
              'image_uris': {'small': '  $p2DfcFace0Small  '},
            },
          ],
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(p2DfcFace0Small),
          reason: 'Whitespace P1 must fall through to P2, and P2 must be trimmed');
    });

    testWidgets('ADV 1.4: DFC face 0 empty but face 1 present -> falls through to direct imageUrl (face 0 rule)', (tester) async {
      const p3Direct = 'https://direct.cdn/correct_fallback.jpg';

      final item = buildCard(
        id: 'adv-dfc-face0-empty',
        name: 'Inverted DFC',
        imageUrl: p3Direct,
        dynamicDataMap: {
          'card_faces': [
            {
              'name': 'Face 0 with no art',
              'image_uris': {'small': '   '},
            },
            {
              'name': 'Face 1 (Back Face)',
              'image_uris': {'small': 'https://scryfall.io/small/back_face.jpg'},
            },
          ],
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(p3Direct),
          reason: 'Must strictly check face 0; empty face 0 must fall back to direct imageUrl rather than face 1');
    });

    testWidgets('ADV 1.5: Direct imageUrl trimming and whitespace handling', (tester) async {
      const rawDirect = '   https://direct.cdn/trimmed_card.jpg   ';
      const expectedClean = 'https://direct.cdn/trimmed_card.jpg';

      final item = buildCard(
        id: 'adv-direct-trim',
        name: 'Untrimmed Direct',
        imageUrl: rawDirect,
        dynamicDataMap: {},
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(expectedClean));
    });

    testWidgets('ADV 1.6: All tiers missing or whitespace -> Zero Image widgets, direct fallback icon rendered', (tester) async {
      final item = buildCard(
        id: 'adv-all-empty',
        name: 'Completely Void Art Card',
        imageUrl: '     ',
        dynamicDataMap: {
          'image_uris': {'small': '   '},
          'card_faces': [
            {
              'image_uris': {'small': ''}
            }
          ],
        },
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing, reason: 'Zero Image widgets should be instantiated when no URL is valid');
      final fallbackFinder = find.byKey(Key('vault_card_leading_fallback_${item.id}'));
      expect(fallbackFinder, findsOneWidget);
      expect(find.descendant(of: fallbackFinder, matching: find.byIcon(Icons.auto_awesome_rounded)), findsOneWidget);
    });
  });

  // ===========================================================================
  // SECTION 2: NETWORK ERROR SIMULATION & ERRORBUILDER FALLBACK
  // ===========================================================================
  group('Section 2: Network Error Simulation & errorBuilder Fallback', () {
    testWidgets('ADV 2.1: errorBuilder handles NetworkImageLoadException (HTTP 404)', (tester) async {
      final item = buildCard(
        id: 'adv-err-404',
        name: '404 Card',
        imageUrl: 'https://cdn.example.com/missing_404.jpg',
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.errorBuilder, isNotNull);

      // Invoke errorBuilder with NetworkImageLoadException
      final exception = NetworkImageLoadException(
        statusCode: 404,
        uri: Uri.parse('https://cdn.example.com/missing_404.jpg'),
      );
      final errorResultWidget = imageWidget.errorBuilder!(
        tester.element(imageFinder),
        exception,
        StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: errorResultWidget)),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV 2.2: errorBuilder handles SocketException (offline network drop)', (tester) async {
      final item = buildCard(
        id: 'adv-err-offline',
        name: 'Offline Card',
        imageUrl: 'https://cdn.example.com/offline.jpg',
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      final imageWidget = tester.widget<Image>(imageFinder);

      const socketException = SocketException('Failed host lookup: "cdn.example.com"');
      final errorResultWidget = imageWidget.errorBuilder!(
        tester.element(imageFinder),
        socketException,
        StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: errorResultWidget)),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV 2.3: errorBuilder handles TimeoutException without crashing', (tester) async {
      final item = buildCard(
        id: 'adv-err-timeout',
        name: 'Timeout Card',
        imageUrl: 'https://cdn.example.com/timeout.jpg',
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      final imageWidget = tester.widget<Image>(imageFinder);

      final timeoutException = TimeoutException('Connection timed out after 5000ms');
      final errorResultWidget = imageWidget.errorBuilder!(
        tester.element(imageFinder),
        timeoutException,
        StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: errorResultWidget)),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV 2.4: errorBuilder renders exact collection-specific icon and tint across all 5 collection types', (tester) async {
      final testMatrix = [
        {'type': 'mtg', 'icon': Icons.auto_awesome_rounded, 'color': AppColors.accentViolet},
        {'type': 'pokemon', 'icon': Icons.catching_pokemon_rounded, 'color': AppColors.accentAmber},
        {'type': 'comic', 'icon': Icons.menu_book_rounded, 'color': AppColors.accentEmerald},
        {'type': 'sports_card', 'icon': Icons.sports_football_rounded, 'color': AppColors.accentCyan},
        {'type': 'custom_unknown', 'icon': Icons.style_rounded, 'color': AppColors.accentCyan},
      ];

      for (final spec in testMatrix) {
        final collectionType = spec['type'] as String;
        final expectedIcon = spec['icon'] as IconData;
        final expectedColor = spec['color'] as Color;

        final item = buildCard(
          id: 'adv-coll-$collectionType',
          name: '$collectionType Item',
          collectionType: collectionType,
          imageUrl: 'https://broken.network/image_$collectionType.jpg',
        );

        await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
        await tester.pump();

        final imageFinder = find.byType(Image);
        final imageWidget = tester.widget<Image>(imageFinder);

        final errorWidget = imageWidget.errorBuilder!(
          tester.element(imageFinder),
          const HttpException('503 Service Unavailable'),
          StackTrace.empty,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Center(child: errorResultWidgetWrapper(errorWidget))),
          ),
        );
        await tester.pump();

        final iconFinder = find.byIcon(expectedIcon);
        expect(iconFinder, findsOneWidget, reason: 'Failed for collection $collectionType');

        final iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.color, equals(expectedColor));
      }
    });

    testWidgets('ADV 2.5: Loading builder renders mini CircularProgressIndicator with 1.5 stroke and accentCyan', (tester) async {
      final item = buildCard(
        id: 'adv-loading-test',
        name: 'Loading Card',
        imageUrl: 'https://cards.scryfall.io/small/loading.jpg',
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.loadingBuilder, isNotNull);

      // Invoke loadingBuilder with simulated active progress
      final progress = ImageChunkEvent(
        cumulativeBytesLoaded: 50,
        expectedTotalBytes: 100,
      );
      final loadingWidget = imageWidget.loadingBuilder!(
        tester.element(imageFinder),
        const SizedBox(),
        progress,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: loadingWidget)),
        ),
      );
      await tester.pump();

      final cpiFinder = find.byType(CircularProgressIndicator);
      expect(cpiFinder, findsOneWidget);
      final cpi = tester.widget<CircularProgressIndicator>(cpiFinder);
      expect(cpi.strokeWidth, equals(1.5));
      expect(cpi.color, equals(AppColors.accentCyan));
    });
  });

  // ===========================================================================
  // SECTION 3: MALFORMED, CORRUPTED, & HOSTILE DYNAMICDATA PAYLOADS
  // ===========================================================================
  group('Section 3: Pathological & Hostile dynamicData JSON Stress Harness', () {
    final hostileDynamicDataPayloads = <String, String>{
      'Unclosed JSON brace': '{"image_uris": {"small": "https://test.com"',
      'Raw control characters': '\x00\x01\x02\x03\x04\x05\x06\x07',
      'Bare integer': '4294967296',
      'Bare negative float': '-3.1415926535',
      'Bare string primitive': '"https://scryfall.io/small/art.jpg"',
      'Bare boolean true': 'true',
      'Bare boolean false': 'false',
      'Bare null': 'null',
      'Empty array at root': '[]',
      'Array of primitives': '[1, "two", 3.0, false, null]',
      'Array containing map': '[{"image_uris": {"small": "https://bad.com"}}]',
      'image_uris is null': '{"image_uris": null}',
      'image_uris is integer': '{"image_uris": 123456}',
      'image_uris is boolean': '{"image_uris": true}',
      'image_uris is list': '{"image_uris": ["small", "https://url.com"]}',
      'image_uris is empty map': '{"image_uris": {}}',
      'image_uris.small is null': '{"image_uris": {"small": null}}',
      'image_uris.small is empty': '{"image_uris": {"small": ""}}',
      'image_uris.small is whitespace': '{"image_uris": {"small": "    \\t\\n   "}}',
      'image_uris.small is integer': '{"image_uris": {"small": 987654321}}',
      'image_uris.small is boolean': '{"image_uris": {"small": false}}',
      'image_uris.small is map': '{"image_uris": {"small": {"nested": "url"}}}',
      'image_uris.small is array': '{"image_uris": {"small": ["https://nested.com"]}}',
      'card_faces is null': '{"card_faces": null}',
      'card_faces is integer': '{"card_faces": 42}',
      'card_faces is boolean': '{"card_faces": false}',
      'card_faces is string': '{"card_faces": "string_not_list"}',
      'card_faces is map': '{"card_faces": {"0": {"image_uris": {}}}}',
      'card_faces is empty list': '{"card_faces": []}',
      'card_faces has null element': '{"card_faces": [null]}',
      'card_faces has string element': '{"card_faces": ["not a map"]}',
      'card_faces has int element': '{"card_faces": [99]}',
      'card_faces has list element': '{"card_faces": [[]]}',
      'card_faces[0].image_uris is null': '{"card_faces": [{"image_uris": null}]}',
      'card_faces[0].image_uris is string': '{"card_faces": [{"image_uris": "string"}]}',
      'card_faces[0].image_uris is int': '{"card_faces": [{"image_uris": 123}]}',
      'card_faces[0].image_uris.small is null': '{"card_faces": [{"image_uris": {"small": null}}]}',
      'card_faces[0].image_uris.small is empty': '{"card_faces": [{"image_uris": {"small": ""}}]}',
      'card_faces[0].image_uris.small is whitespace': '{"card_faces": [{"image_uris": {"small": "   "}}]}',
      'card_faces[0].image_uris.small is map': '{"card_faces": [{"image_uris": {"small": {}}}]}',
      'Deeply nested 10KB payload': '{"a": {"b": {"c": {"d": ${jsonEncode(List.generate(500, (i) => "item_$i"))}}}}}',
      'Unicode and emojis in keys and values': '{"🧙‍♂️": "✨", "image_uris": {"small": "https://scryfall.io/🃏/🔥.jpg"}}',
    };

    for (final entry in hostileDynamicDataPayloads.entries) {
      testWidgets('ADV 3: Payload [${entry.key}] does not throw exceptions and cleanly renders fallback', (tester) async {
        final item = buildCard(
          id: 'adv-hostile-${entry.key.hashCode.abs()}',
          name: 'Hostile Test: ${entry.key}',
          imageUrl: '',
          rawDynamicData: entry.value,
        );

        await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'Payload "${entry.key}" crashed with unhandled exception');
        expect(find.byType(VaultItemCard), findsOneWidget);
      });
    }

    testWidgets('ADV 3.1: Corrupt top-level image_uris safely falls through to valid DFC card_faces[0].small', (tester) async {
      const validDfcSmall = 'https://scryfall.io/small/valid_dfc.jpg';
      final item = buildCard(
        id: 'adv-corrupt-p1-valid-p2',
        name: 'Recoverable DFC',
        imageUrl: 'https://direct.com/ignored.jpg',
        rawDynamicData: jsonEncode({
          'image_uris': 'CORRUPTED_NOT_A_MAP',
          'card_faces': [
            {
              'name': 'Valid Front',
              'image_uris': {'small': validDfcSmall},
            },
          ],
        }),
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(validDfcSmall));
    });

    testWidgets('ADV 3.2: Corrupt image_uris and corrupt card_faces safely falls through to valid item.imageUrl', (tester) async {
      const validDirect = 'https://direct.cdn/salvaged_art.jpg';
      final item = buildCard(
        id: 'adv-corrupt-all-valid-direct',
        name: 'Recoverable Direct Art',
        imageUrl: validDirect,
        rawDynamicData: '{"image_uris": 12345, "card_faces": false, "syntax_error": [',
      );

      await tester.pumpWidget(buildHarness(VaultItemCard(item: item)));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, equals(validDirect));
    });
  });

  // ===========================================================================
  // SECTION 4: LAYOUT STABILITY ACROSS INVESTOR & PLAYER MODES
  // ===========================================================================
  group('Section 4: Layout Stability Across Investor & Player Personas', () {
    testWidgets('ADV 4.1: Leading thumbnail slot dimensions and coordinates are strictly invariant across personas', (tester) async {
      const thumbUrl = 'https://scryfall.io/small/invariant_test.jpg';
      final item = buildCard(
        id: 'adv-persona-invar',
        name: 'Invariance Test Card',
        dynamicDataMap: {
          'image_uris': {'small': thumbUrl},
        },
      );

      // 1. Measure Investor Mode
      await tester.pumpWidget(buildHarness(VaultItemCard(item: item, persona: UserPersona.investor)));
      await tester.pump();

      final investorThumbFinder = find.byKey(Key('vault_card_leading_thumbnail_${item.id}'));
      expect(investorThumbFinder, findsOneWidget);
      final investorThumbRect = tester.getRect(investorThumbFinder);
      final investorTitleRect = tester.getRect(find.text('Invariance Test Card'));

      // 2. Measure Player Mode
      await tester.pumpWidget(buildHarness(VaultItemCard(item: item, persona: UserPersona.player)));
      await tester.pump();

      final playerThumbFinder = find.byKey(Key('vault_card_leading_thumbnail_${item.id}'));
      expect(playerThumbFinder, findsOneWidget);
      final playerThumbRect = tester.getRect(playerThumbFinder);
      final playerTitleRect = tester.getRect(find.text('Invariance Test Card'));

      // Strict assertions: Geometry must not shift by even a fraction of a pixel
      expect(playerThumbRect.width, equals(38.0));
      expect(playerThumbRect.height, equals(52.0));
      expect(playerThumbRect.width, equals(investorThumbRect.width));
      expect(playerThumbRect.height, equals(investorThumbRect.height));
      expect(playerThumbRect.left, equals(investorThumbRect.left));
      expect(playerThumbRect.top, equals(investorThumbRect.top));

      // Title offset must be identical
      expect(playerTitleRect.left, equals(investorTitleRect.left));
      expect(playerTitleRect.left - playerThumbRect.right, equals(12.0),
          reason: 'Leading thumbnail must maintain exact 12px margin to title column');
    });

    testWidgets('ADV 4.2: Viewport width stress test (300px compact to 800px tablet) in both modes', (tester) async {
      final widths = [300.0, 320.0, 375.0, 414.0, 600.0, 800.0];
      final item = buildCard(
        id: 'adv-width-stress',
        name: 'The Most Absurdly Long Card Name Ever Conceived in Any Trading Card Game History',
        flavorName: 'Adamantium Bonding Tank of Ultimate Doom and Celestial Reckoning',
        quantity: 12,
        isGraded: true,
        acquiredPrice: 9999.99,
        currentMarketPrice: 15000.00,
        dynamicDataMap: {
          'image_uris': {'small': 'https://scryfall.io/small/wide_art.jpg'},
          'mana_cost': '{3}{W}{U}{B}{R}{G}',
          'power': '15',
          'toughness': '15',
          'keywords': ['Flying', 'First Strike', 'Vigilance', 'Trample', 'Indestructible', 'Haste'],
          'oracle_text': 'Whenever this creature attacks, you win the game if you control ten or more permanents.',
        },
      );

      for (final w in widths) {
        // Investor Mode
        await tester.pumpWidget(buildHarness(
          VaultItemCard(item: item, persona: UserPersona.investor),
          width: w,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Investor Mode overflowed at viewport width $w');

        // Player Mode
        await tester.pumpWidget(buildHarness(
          VaultItemCard(item: item, persona: UserPersona.player),
          width: w,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Player Mode overflowed at viewport width $w');
      }
    });

    testWidgets('ADV 4.3: Unowned catalog card (quantity == 0) renders CATALOG / UNOWNED pill in Investor Mode', (tester) async {
      final unownedItem = buildCard(
        id: 'adv-unowned-inv',
        name: 'Mox Diamond',
        quantity: 0,
        currentMarketPrice: 650.0,
        imageUrl: '',
      );

      await tester.pumpWidget(buildHarness(
        VaultItemCard(item: unownedItem, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CATALOG / UNOWNED'), findsOneWidget);
      expect(find.text('MARKET VALUE'), findsOneWidget);
      expect(find.text('\$650.00'), findsOneWidget);
      expect(find.text('ACQUIRED'), findsNothing,
          reason: 'Unowned items must not display acquired cost');
    });

    testWidgets('ADV 4.4: Player Mode handles Planeswalker loyalty and Pokemon HP cleanly', (tester) async {
      // 1. Planeswalker with Loyalty (no P/T)
      final walker = buildCard(
        id: 'adv-walker',
        name: 'Jace, the Mind Sculptor',
        dynamicDataMap: {
          'mana_cost': '{2}{U}{U}',
          'loyalty': '3',
          'keywords': [],
        },
      );

      await tester.pumpWidget(buildHarness(
        VaultItemCard(item: walker, persona: UserPersona.player),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Loyalty: 3'), findsOneWidget);
      expect(find.textContaining('⚔️'), findsNothing);

      // 2. Pokemon with HP and Stage
      final pokemon = buildCard(
        id: 'adv-pokemon',
        name: 'Charizard ex',
        collectionType: 'pokemon',
        dynamicDataMap: {
          'hp': '330',
          'stage': 'Stage 2',
        },
      );

      await tester.pumpWidget(buildHarness(
        VaultItemCard(item: pokemon, persona: UserPersona.player),
      ));
      await tester.pumpAndSettle();

      expect(find.text('HP 330 • Stage 2'), findsOneWidget);
    });

    testWidgets('ADV 4.5: Massive font scale factor (2.0x accessibility) does not cause layout crashes', (tester) async {
      final item = buildCard(
        id: 'adv-a11y-font-scale',
        name: 'Accessibility High Font Scale Card',
        quantity: 3,
        imageUrl: 'https://scryfall.io/small/font_scale.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userPersonaProvider.overrideWith((ref) => UserPersona.investor),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: VaultItemCard(item: item),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'Large text scale factor 2.0x must render cleanly without unhandled exceptions');
      expect(find.byType(VaultItemCard), findsOneWidget);
    });
  });
}

Widget errorResultWidgetWrapper(Widget widget) {
  return SizedBox(
    width: 38,
    height: 52,
    child: widget,
  );
}

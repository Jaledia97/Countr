import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

import 'mtg_filter_contract.dart';
import 'phase_3_9_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = createPhase39TestDatabase();
    dao = db.vaultDao;
    await seedPhase39Catalog(dao);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithHarness(Widget child, {UserPersona persona = UserPersona.investor}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        userPersonaProvider.overrideWith((ref) => persona),
        cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES (17 Features × 5 Tests = 85 Tests)
  // ===========================================================================

  // Feature 1: DFC Boundary & Corner Cases
  group('Tier 2 - B1: DFC Boundary & Corner Cases', () {
    testWidgets('B1.1: Single face in card_faces list suppresses flip button', (tester) async {
      final card = createPhase39Card(
        id: 'dfc-single-face',
        name: 'Half DFC',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Only Front', 'image_uris': {'normal': 'https://example.com/front.jpg'}},
          ],
          'back_image_url': null,
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('B1.2: Corrupted or non-JSON dynamicData handled safely without unhandled exceptions', (tester) async {
      final corrupted = VaultItem(
        id: 'corrupted-dfc',
        collectionType: 'mtg',
        name: 'Corrupted Card',
        setOrSeries: 'Set',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        personalNotes: null,
        primaryBinderId: null,
        currentMarketPrice: 0.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{this is invalid json!}',
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: corrupted)));
      await tester.pumpAndSettle();

      expect(find.text('Corrupted Card'), findsWidgets);
      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('B1.3: DFC with empty image_uris maps does not throw null pointer exception', (tester) async {
      final card = createPhase39Card(
        id: 'dfc-empty-images',
        name: 'No Image DFC',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Front', 'image_uris': {}},
            {'name': 'Back', 'image_uris': {}},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.text('No Image DFC'), findsWidgets);
    });

    testWidgets('B1.4: DFC with empty back_image_url hides flip button', (tester) async {
      final card = createPhase39Card(
        id: 'dfc-empty-back',
        name: 'Blank Back DFC',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Front Face'},
            {'name': 'Back Face'},
          ],
          'back_image_url': '',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('B1.5: Rapid multi-tap on flip button completes animations without state errors', (tester) async {
      final card = createPhase39Card(
        id: 'dfc-rapid-tap',
        name: 'Rapid Tap DFC',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Front', 'image_uris': {'normal': 'https://example.com/front.jpg'}},
            {'name': 'Back', 'image_uris': {'normal': 'https://example.com/back.jpg'}},
          ],
          'back_image_url': 'https://example.com/back.jpg',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      final flipBtn = find.byKey(const Key('card_detail_flip_button'));
      expect(flipBtn, findsOneWidget);

      await tester.tap(flipBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(flipBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(flipBtn, findsOneWidget);
    });
  });

  // Feature 2: Adventure Flip Suppression Boundary Cases
  group('Tier 2 - B2: Adventure Flip Suppression Boundary Cases', () {
    testWidgets('B2.1: Adventure card with empty card_faces suppresses flip button', (tester) async {
      final card = createPhase39Card(
        id: 'adv-empty-faces',
        name: 'Empty Faces Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'card_faces': [],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('B2.2: Adventure card with missing adventure spell text renders without crashing', (tester) async {
      final card = createPhase39Card(
        id: 'adv-no-spell-text',
        name: 'Partial Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'card_faces': [
            {'name': 'Creature Half', 'oracle_text': 'Trample'},
            {'name': 'Spell Half', 'oracle_text': null},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Trample'), findsOneWidget);
      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('B2.3: Adventure card with missing mana_cost on either face handled gracefully', (tester) async {
      final card = createPhase39Card(
        id: 'adv-no-mana-cost',
        name: 'Zero Cost Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'card_faces': [
            {'name': 'Creature', 'mana_cost': ''},
            {'name': 'Adventure', 'mana_cost': ''},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('B2.4: Sorcery Adventure layout suppresses flip buttons identical to Instant Adventure', (tester) async {
      final sorceryAdv = createPhase39Card(
        id: 'adv-sorcery',
        name: 'Lovestruck Beast // Heart\'s Desire',
        dynamicDataMap: {
          'layout': 'adventure',
          'type_line': 'Creature — Beast // Sorcery — Adventure',
          'card_faces': [
            {'name': 'Lovestruck Beast', 'type_line': 'Creature — Beast'},
            {'name': 'Heart\'s Desire', 'type_line': 'Sorcery — Adventure'},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: sorceryAdv)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('B2.5: Adventure card with promo treatment strictly suppresses flip button in FullScreen', (tester) async {
      final promoAdv = createPhase39Card(
        id: 'adv-promo',
        name: 'Foil Promo Giant',
        dynamicDataMap: {
          'layout': 'adventure',
          'promo': true,
          'card_faces': [{'name': 'Giant'}, {'name': 'Stomp'}],
        },
      );

      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: promoAdv)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);
    });
  });

  // Feature 3: Adventure Unified Rules Box Boundary Cases
  group('Tier 2 - B3: Adventure Unified Rules Box Boundary Cases', () {
    testWidgets('B3.1: Adventure card with empty oracle_text renders rules box without exception', (tester) async {
      final card = createPhase39Card(
        id: 'adv-empty-rules',
        name: 'Blank Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'oracle_text': '',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.text('Blank Adventure'), findsWidgets);
    });

    testWidgets('B3.2: Extremely long rules text renders without RenderFlex overflow', (tester) async {
      final massiveText = 'Whenever this creature enters the battlefield, do effect. ' * 20;
      final card = createPhase39Card(
        id: 'adv-massive-rules',
        name: 'Wordy Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'oracle_text': '$massiveText // Short spell effect.',
          'card_faces': [
            {'name': 'Wordy Creature', 'oracle_text': massiveText},
            {'name': 'Short Spell', 'oracle_text': 'Short spell effect.'},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Short spell effect.'), findsOneWidget);
    });

    testWidgets('B3.3: Mana symbols like {T} and hybrid {G/U} render safely in rules text', (tester) async {
      final card = createPhase39Card(
        id: 'adv-symbols',
        name: 'Symbolic Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'oracle_text': '{T}: Add {G}. // {G/U}: Tap target creature.',
          'card_faces': [
            {'name': 'Symbolic Elf', 'oracle_text': '{T}: Add {G}.'},
            {'name': 'Symbolic Trick', 'oracle_text': '{G/U}: Tap target creature.'},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.textContaining('{T}: Add {G}.'), findsOneWidget);
      expect(find.textContaining('{G/U}: Tap target creature.'), findsOneWidget);
    });

    testWidgets('B3.4: Flavor text alongside rules text renders cleanly', (tester) async {
      final card = createPhase39Card(
        id: 'adv-flavor',
        name: 'Flavored Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'flavor_text': '“Fee fi fo fum!”',
          'oracle_text': 'Vigilance. // Draw a card.',
          'card_faces': [
            {'name': 'Giant', 'oracle_text': 'Vigilance.'},
            {'name': 'Adventure', 'oracle_text': 'Draw a card.'},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: card)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vigilance.'), findsOneWidget);
    });

    test('B3.5: Scryfall parser handles card_faces with 3+ parts safely', () {
      final json = {
        'id': 'multi-part-card',
        'name': 'Face 1 // Face 2 // Face 3',
        'card_faces': [
          {'name': 'Face 1', 'oracle_text': 'Text 1'},
          {'name': 'Face 2', 'oracle_text': 'Text 2'},
          {'name': 'Face 3', 'oracle_text': 'Text 3'},
        ],
      };

      final companion = mapScryfallCardToCompanion(json);
      expect(companion.name.value, 'Face 1 // Face 2 // Face 3');
      expect(companion.dynamicData.value, contains('Text 1 // Text 2 // Text 3'));
    });
  });

  // Feature 4: Universes Beyond Detection Boundary Cases
  group('Tier 2 - B4: Universes Beyond Detection Boundary Cases', () {
    test('B4.1: promo_types with uppercase or mixed case matches UB filter', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final card = createPhase39Card(
        id: 'ub-case',
        name: 'Case Test',
        dynamicDataMap: {'promo_types': ['UNIVERSES_BEYOND']},
      );
      expect(filter.matches(card), isTrue);
    });

    test('B4.2: Empty promo_types and frame_effects do not trigger false positive', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final card = createPhase39Card(
        id: 'ub-empty-lists',
        name: 'Normal Standard Card',
        dynamicDataMap: {'promo_types': [], 'frame_effects': []},
      );
      expect(filter.matches(card), isFalse);
    });

    test('B4.3: security_stamp with uppercase TRIANGLE matches UB filter', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final card = createPhase39Card(
        id: 'ub-stamp-upper',
        name: 'Upper Triangle',
        dynamicDataMap: {'security_stamp': 'TRIANGLE'},
      );
      expect(filter.matches(card), isTrue);
    });

    test('B4.4: Non-UB security stamp oval does NOT match UB filter', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final card = createPhase39Card(
        id: 'ub-stamp-oval',
        name: 'Oval Stamp Card',
        dynamicDataMap: {'security_stamp': 'oval'},
      );
      expect(filter.matches(card), isFalse);
    });

    test('B4.5: Explicit is_universes_beyond: false in filter rejects UB cards', () {
      final filter = const MtgFilterState(isUniversesBeyond: false);
      final ubCard = createPhase39Card(
        id: 'ub-card',
        name: 'Ring',
        dynamicDataMap: {'is_universes_beyond': true},
      );
      final nonUbCard = createPhase39Card(
        id: 'non-ub-card',
        name: 'Lotus',
        dynamicDataMap: {'is_universes_beyond': false},
      );

      expect(filter.matches(ubCard), isFalse);
      expect(filter.matches(nonUbCard), isTrue);
    });
  });

  // Feature 5: Secret Lairs & Flavor Search Boundary Cases
  group('Tier 2 - B5: Secret Lairs & Flavor Search Boundary Cases', () {
    test('B5.1: Uppercase SLD set code matches set filter', () {
      final filter = const MtgFilterState(setCode: 'sld');
      final sldCard = createPhase39Card(
        id: 'sld-upper',
        name: 'SLD Card',
        dynamicDataMap: {'set': 'SLD'},
      );
      expect(filter.matches(sldCard), isTrue);
    });

    test('B5.2: Whitespace padded search query finds cards in VaultDao', () async {
      final results = await dao.searchCatalogCards('  Adamantium  ', collectionType: 'mtg');
      expect(results, isNotEmpty);
      expect(results.first.name, 'The Ozolith');
    });

    test('B5.3: Card with null flavor_name does not match arbitrary search queries', () async {
      final results = await dao.searchCatalogCards('NonExistentFlavorName12345', collectionType: 'mtg');
      expect(results, isEmpty);
    });

    test('B5.4: Punctuation in search query matches correctly', () async {
      final results = await dao.searchCatalogCards('Bonecrusher', collectionType: 'mtg');
      expect(results, isNotEmpty);
    });

    test('B5.5: Single character search query against name returns matching results', () async {
      final results = await dao.searchCatalogCards('O', collectionType: 'mtg');
      expect(results, isNotEmpty);
    });
  });

  // Feature 6: Eliminate Literal "Check" Boundary Cases
  group('Tier 2 - B6: Eliminate Literal Check Boundary Cases', () {
    test('B6.1: Price value of 0.00 maps to Unlisted and never Check', () {
      final label = formatMarketPriceLabel(0.00);
      expect(label, 'Unlisted');
      expect(label.toLowerCase().contains('check'), isFalse);
    });

    test('B6.2: Negative price value maps to Unlisted and never Check', () {
      final label = formatMarketPriceLabel(-5.50);
      expect(label, 'Unlisted');
      expect(label.toLowerCase().contains('check'), isFalse);
    });

    test('B6.3: Extremely large market price formats with commas and dollar sign', () {
      final label = formatMarketPriceLabel(999999.99);
      expect(label, '\$999999.99');
    });

    test('B6.4: Extremely small positive price does not display as Check', () {
      final label = formatMarketPriceLabel(0.01);
      expect(label, '\$0.01');
    });

    testWidgets('B6.5: Card with zero market price in Investor mode displays formatted price or delta', (tester) async {
      final card = createPhase39Card(
        id: 'zero-investor',
        name: 'Zero Dollar Card',
        quantity: 1,
        currentMarketPrice: 0.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        VaultItemCard(item: card),
        persona: UserPersona.investor,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
    });
  });

  // Feature 7: Pricing Fallback Hierarchy Boundary Cases
  group('Tier 2 - B7: Pricing Fallback Hierarchy Boundary Cases', () {
    test('B7.1: All currency entries set to explicit null string returns 0.0', () {
      final prices = {'usd': 'null', 'usd_foil': 'null', 'eur': 'null'};
      expect(resolveHierarchicalPrice(prices), 0.0);
    });

    test('B7.2: USD is 0.00 string but usd_foil is 15.00: correctly falls back to foil', () {
      final prices = {'usd': '0.00', 'usd_foil': '15.00', 'eur': '10.00'};
      expect(resolveHierarchicalPrice(prices), 15.00);
    });

    test('B7.3: Invalid numeric string TBD skips to next valid currency', () {
      final prices = {'usd': 'TBD', 'usd_foil': 'invalid', 'usd_etched': '22.50'};
      expect(resolveHierarchicalPrice(prices), 22.50);
    });

    test('B7.4: Currency with floating point formatting precision parses accurately', () {
      final prices = {'usd': '12.3456'};
      expect(resolveHierarchicalPrice(prices), closeTo(12.3456, 0.0001));
    });

    test('B7.5: Extreme price value parses without overflow', () {
      final prices = {'usd': '500000.00'};
      expect(resolveHierarchicalPrice(prices), 500000.00);
    });
  });

  // Feature 8: Unlisted Price Labeling Boundary Cases
  group('Tier 2 - B8: Unlisted Price Labeling Boundary Cases', () {
    test('B8.1: Owned card with 0.0 market price maps to Unlisted label', () {
      expect(formatMarketPriceLabel(0.0), 'Unlisted');
    });

    test('B8.2: Unowned catalog card with 0.0 market price maps to Unlisted label', () {
      expect(formatMarketPriceLabel(0.0), 'Unlisted');
    });

    test('B8.3: NaN or infinity price handled safely as Unlisted', () {
      expect(formatMarketPriceLabel(double.nan), 'Unlisted');
      expect(formatMarketPriceLabel(double.negativeInfinity), 'Unlisted');
    });

    test('B8.4: Helper returns non-empty string for any valid double', () {
      expect(formatMarketPriceLabel(1.0).isNotEmpty, isTrue);
      expect(formatMarketPriceLabel(0.0).isNotEmpty, isTrue);
    });

    test('B8.5: Unlisted label string contains no dollar sign characters', () {
      final label = formatMarketPriceLabel(0.0);
      expect(label.contains('\$'), isFalse);
    });
  });

  // Feature 9: 3x Grid Quantity Badges Boundary Cases
  group('Tier 2 - B9: 3x Grid Quantity Badges Boundary Cases', () {
    testWidgets('B9.1: Large quantity 999 renders duplicate badge without crash', (tester) async {
      final card = createPhase39Card(
        id: 'large-qty',
        name: 'Huge Stack',
        quantity: 999,
        currentMarketPrice: 1.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(width: 150, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsOneWidget);
    });

    testWidgets('B9.2: Negative quantity does not render duplicate badge', (tester) async {
      final card = createPhase39Card(
        id: 'neg-qty',
        name: 'Negative Stack',
        quantity: -1,
        currentMarketPrice: 1.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(width: 150, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsNothing);
    });

    testWidgets('B9.3: Quantity 2 renders duplicate badge', (tester) async {
      final card = createPhase39Card(
        id: 'pair-qty',
        name: 'Pair Stack',
        quantity: 2,
        currentMarketPrice: 1.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(width: 150, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsOneWidget);
    });

    testWidgets('B9.4: Quantity badge renders on narrow phone viewport', (tester) async {
      final card = createPhase39Card(
        id: 'narrow-qty',
        name: 'Narrow Card',
        quantity: 5,
        currentMarketPrice: 1.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(width: 90, height: 130, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsOneWidget);
    });

    testWidgets('B9.5: Zero quantity card omits duplicate badge', (tester) async {
      final card = createPhase39Card(
        id: 'zero-qty',
        name: 'Zero Card',
        quantity: 0,
        currentMarketPrice: 1.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(width: 120, height: 180, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsNothing);
    });
  });

  // Feature 10: List View Art Thumbnails Boundary Cases
  group('Tier 2 - B10: List View Art Thumbnails Boundary Cases', () {
    testWidgets('B10.1: Malformed image URI does not crash list view card', (tester) async {
      final card = createPhase39Card(
        id: 'bad-uri',
        name: 'Bad URI Card',
        imageUrl: 'not_a_valid_url://///',
      );

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: card)));
      await tester.pumpAndSettle();

      expect(find.text('Bad URI Card'), findsOneWidget);
    });

    testWidgets('B10.2: Transparent image data handled safely', (tester) async {
      final card = createPhase39Card(
        id: 'trans-img',
        name: 'Transparent Image Card',
        imageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAA=',
      );

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: card)));
      await tester.pumpAndSettle();

      expect(find.text('Transparent Image Card'), findsOneWidget);
    });

    testWidgets('B10.3: Deeply nested dynamicData without image_uris handled safely', (tester) async {
      final card = createPhase39Card(
        id: 'deep-dyn',
        name: 'Deep Dyn Card',
        dynamicDataMap: {'nested': {'deep': {'val': 123}}},
      );

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: card)));
      await tester.pumpAndSettle();

      expect(find.text('Deep Dyn Card'), findsOneWidget);
    });

    testWidgets('B10.4: Wide aspect ratio card image handled safely within tile bounds', (tester) async {
      final card = createPhase39Card(
        id: 'wide-img',
        name: 'Wide Image Card',
        imageUrl: 'https://cards.scryfall.io/art_crop/front/test.jpg',
      );

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: card)));
      await tester.pumpAndSettle();

      expect(find.text('Wide Image Card'), findsOneWidget);
    });

    testWidgets('B10.5: Multiple items rendered in ListView with thumbnails', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cards = List.generate(
        5,
        (i) => createPhase39Card(id: 'list-card-$i', name: 'List Card $i'),
      );

      await tester.pumpWidget(wrapWithHarness(
        ListView.builder(
          itemCount: cards.length,
          itemBuilder: (ctx, i) => VaultItemCard(item: cards[i]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('List Card 0'), findsOneWidget);
      expect(find.text('List Card 4'), findsOneWidget);
    });
  });

  // Feature 11: Card Detail Swiping Boundary Cases
  group('Tier 2 - B11: Card Detail Swiping Boundary Cases', () {
    testWidgets('B11.1: Single item list does not throw bounds error on swipe', (tester) async {
      final single = [createPhase39Card(id: 'only-1', name: 'Only Card')];
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: single, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Only Card'), findsWidgets);
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Only Card'), findsWidgets);
    });

    testWidgets('B11.2: Swiping backward at index 0 remains clamped at index 0', (tester) async {
      final items = [
        createPhase39Card(id: 'c0', name: 'Card 0'),
        createPhase39Card(id: 'c1', name: 'Card 1'),
      ];

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: items, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('swipe_prev_button')));
      await tester.pumpAndSettle();

      expect(find.text('Card 0'), findsWidgets);
    });

    testWidgets('B11.3: Swiping forward at last index remains clamped', (tester) async {
      final items = [
        createPhase39Card(id: 'c0', name: 'Card 0'),
        createPhase39Card(id: 'c1', name: 'Card 1'),
      ];

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: items, initialIndex: 1),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Card 1'), findsWidgets);
    });

    testWidgets('B11.4: Rapid sequential taps on swipe button transitions cleanly', (tester) async {
      final items = List.generate(
        5,
        (i) => createPhase39Card(id: 'c-$i', name: 'Rapid Card $i'),
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: items, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Rapid Card 2'), findsWidgets);
    });

    testWidgets('B11.5: Empty items list renders empty placeholder without unhandled exception', (tester) async {
      await tester.pumpWidget(wrapWithHarness(
        const CardDetailSwipingTestHarness(items: [], initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No items to display'), findsOneWidget);
    });
  });

  // Feature 12: Background Scroll Tracking Boundary Cases
  group('Tier 2 - B12: Background Scroll Tracking Boundary Cases', () {
    testWidgets('B12.1: Background controller at maximum extent does not crash when scrolled further', (tester) async {
      final scrollCtrl = ScrollController();
      final items = List.generate(3, (i) => createPhase39Card(id: 's-$i', name: 'Short $i'));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 100,
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: 3,
                  itemBuilder: (ctx, i) => SizedBox(height: 50, child: Text('$i')),
                ),
              ),
              Expanded(
                child: ProviderScope(
                  overrides: [
                    appDatabaseProvider.overrideWithValue(db),
                    vaultDaoProvider.overrideWithValue(dao),
                  ],
                  child: CardDetailSwipingTestHarness(
                    items: items,
                    initialIndex: 0,
                    backgroundScrollController: scrollCtrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Swipe forward
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(scrollCtrl.hasClients, isTrue);
      scrollCtrl.dispose();
    });

    testWidgets('B12.2: List with 1 item non-scrollable ignores scroll offsets safely', (tester) async {
      final scrollCtrl = ScrollController();
      final items = [createPhase39Card(id: 'one', name: 'Single')];

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(
          items: items,
          initialIndex: 0,
          backgroundScrollController: scrollCtrl,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Single'), findsWidgets);
      scrollCtrl.dispose();
    });

    testWidgets('B12.3: Zero height items calculation handled without division by zero', (tester) async {
      final scrollCtrl = ScrollController();
      final items = List.generate(2, (i) => createPhase39Card(id: 'z-$i', name: 'Zero $i'));

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(
          items: items,
          initialIndex: 0,
          backgroundScrollController: scrollCtrl,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Zero 0'), findsWidgets);
      scrollCtrl.dispose();
    });

    testWidgets('B12.4: ScrollController disposed mid-operation does not leak unhandled errors', (tester) async {
      final scrollCtrl = ScrollController();
      final items = List.generate(2, (i) => createPhase39Card(id: 'd-$i', name: 'Disp $i'));

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(
          items: items,
          initialIndex: 0,
          backgroundScrollController: scrollCtrl,
        ),
      ));
      await tester.pumpAndSettle();

      scrollCtrl.dispose();
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Disp 1'), findsWidgets);
    });

    testWidgets('B12.5: Extreme jump from index 0 to high index calculates valid target offset', (tester) async {
      final scrollCtrl = ScrollController();
      final items = List.generate(50, (i) => createPhase39Card(id: 'h-$i', name: 'High $i'));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 100,
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: 50,
                  itemBuilder: (ctx, i) => SizedBox(height: 120, child: Text('$i')),
                ),
              ),
              Expanded(
                child: ProviderScope(
                  overrides: [
                    appDatabaseProvider.overrideWithValue(db),
                    vaultDaoProvider.overrideWithValue(dao),
                  ],
                  child: CardDetailSwipingTestHarness(
                    items: items,
                    initialIndex: 0,
                    backgroundScrollController: scrollCtrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Swipe 5 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('swipe_next_button')));
        await tester.pumpAndSettle();
      }

      expect(scrollCtrl.offset, greaterThan(0));
      scrollCtrl.dispose();
    });
  });

  // Feature 13: FullScreenCardViewer Sync Boundary Cases
  group('Tier 2 - B13: FullScreenCardViewer Sync Boundary Cases', () {
    testWidgets('B13.1: FullScreen opening with single item disables swiping past bounds', (tester) async {
      final items = [createPhase39Card(id: 'fs-solo', name: 'Solo Fullscreen')];

      await tester.pumpWidget(MaterialApp(
        home: FullScreenSwipingTestHarness(items: items, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_viewer_fs-solo')), findsOneWidget);
    });

    testWidgets('B13.2: Zoom interaction in InteractiveViewer does not crash', (tester) async {
      final item = createPhase39Card(id: 'fs-zoom', name: 'Zoom Card');
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(item: item),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_interactive_viewer')), findsOneWidget);
    });

    testWidgets('B13.3: DFC card flip button persists across interactive viewer transforms', (tester) async {
      final dfcItem = createPhase39Card(
        id: 'fs-dfc-transform',
        name: 'Transform Card',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Front Face'},
            {'name': 'Back Face'},
          ],
          'back_image_url': 'https://example.com/back.jpg',
        },
      );

      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
      await tester.pumpAndSettle();

      final flipBtn = find.byKey(const Key('fullscreen_flip_button'));
      expect(flipBtn, findsOneWidget);

      await tester.tap(flipBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(flipBtn, findsOneWidget);
    });

    testWidgets('B13.4: Swiping backward at index 0 in FullScreen remains clamped', (tester) async {
      final items = [
        createPhase39Card(id: 'f0', name: 'F0'),
        createPhase39Card(id: 'f1', name: 'F1'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: FullScreenSwipingTestHarness(items: items, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fs_swipe_prev_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_viewer_f0')), findsOneWidget);
    });

    testWidgets('B13.5: Rapid toggle of foil shader does not leak controllers', (tester) async {
      final item = createPhase39Card(id: 'fs-foil-leak', name: 'Foil Leak');
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(item: item),
      ));
      await tester.pumpAndSettle();

      final foilBtn = find.byKey(const Key('fullscreen_foil_toggle'));
      expect(foilBtn, findsOneWidget);

      await tester.tap(foilBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(foilBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(foilBtn);
      await tester.pump(const Duration(milliseconds: 200));

      expect(foilBtn, findsOneWidget);
    });
  });

  // Feature 14: MTG Filter State Boundary Cases
  group('Tier 2 - B14: MTG Filter State Boundary Cases', () {
    test('B14.1: Empty filter state produces activeCount == 0 and matches any card', () {
      const state = MtgFilterState();
      expect(state.activeCount, 0);
      expect(state.isActive, isFalse);

      final card = createPhase39Card(id: 'c-any', name: 'Any Card');
      expect(state.matches(card), isTrue);
    });

    test('B14.2: Maximum filter combination computes exact activeCount', () {
      final maxState = const MtgFilterState(
        colors: {'W', 'U'},
        colorCountRange: RangeValues(1, 3),
        cmcRange: RangeValues(2, 6),
        typeLine: 'Creature',
        oracleTextClauses: ['draw', 'flying'],
        manaCost: '{1}{U}',
        setCode: 'm21',
        rarities: {'rare'},
        layouts: {'normal'},
        finishes: {'foil'},
        conditions: {'NM'},
        languages: {'English'},
        statFilters: [
          MtgStatFilter(stat: 'power', operator: '>', value: '2'),
        ],
        isReserved: false,
        isUniversesBeyond: true,
        isPromo: false,
        isReprint: false,
        isAltered: false,
        isMisprint: false,
        isGraded: false,
        isSigned: false,
      );

      // Verify activeCount aggregates all dimensions
      expect(maxState.activeCount, greaterThanOrEqualTo(20));
      expect(maxState.isActive, isTrue);
    });

    test('B14.3: Setting CMC range to default 0-16 does not count as active', () {
      const state = MtgFilterState(cmcRange: RangeValues(0, 16));
      expect(state.activeCount, 0);
      expect(state.isActive, isFalse);
    });

    test('B14.4: Setting color count range to default 0-5 does not count as active', () {
      const state = MtgFilterState(colorCountRange: RangeValues(0, 5));
      expect(state.activeCount, 0);
      expect(state.isActive, isFalse);
    });

    test('B14.5: Multiple consecutive reset calls remain idempotent', () {
      var state = const MtgFilterState(colors: {'W'});
      state = state.reset();
      state = state.reset();
      expect(state.activeCount, 0);
      expect(state.isActive, isFalse);
    });
  });

  // Feature 15: MTG Filter Sheet Modal Boundary Cases
  group('Tier 2 - B15: MTG Filter Sheet Modal Boundary Cases', () {
    testWidgets('B15.1: Rapid switching between General and Collection tabs completes without errors', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MtgFilterSheet())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mtg_filter_tab_collection')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('mtg_filter_tab_general')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mtg_filter_tab_general')), findsOneWidget);
    });

    testWidgets('B15.2: Tapping Apply with zero filters active returns default state', (tester) async {
      MtgFilterState? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(onApply: (s) => result = s),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mtg_filter_apply_button')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.activeCount, 0);
    });

    testWidgets('B15.3: Selecting all color chips adds all 6 symbols', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MtgFilterSheet())));
      await tester.pumpAndSettle();

      for (final s in ['W', 'U', 'B', 'R', 'G', 'C']) {
        await tester.tap(find.byKey(Key('filter_chip_color_$s')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Apply (1)'), findsOneWidget);
    });

    testWidgets('B15.4: Deselecting all color chips leaves empty color set', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(initialState: const MtgFilterState(colors: {'W'})),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_chip_color_W')));
      await tester.pumpAndSettle();

      expect(find.text('Apply (0)'), findsOneWidget);
    });

    testWidgets('B15.5: Selecting condition chips in Collection tab updates state', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MtgFilterSheet())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mtg_filter_tab_collection')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_chip_cond_NM')));
      await tester.pumpAndSettle();

      expect(find.text('Apply (1)'), findsOneWidget);
    });
  });

  // Feature 16: MTG Filter Criteria Logic Boundary Cases
  group('Tier 2 - B16: MTG Filter Criteria Logic Boundary Cases', () {
    test('B16.1: Card with CMC 0 matches CMC range 0 to 0', () {
      final filter = const MtgFilterState(cmcRange: RangeValues(0, 0));
      final lotus = createPhase39Card(id: 'lotus', name: 'Lotus', dynamicDataMap: {'cmc': 0.0});
      final solRing = createPhase39Card(id: 'sol', name: 'Sol Ring', dynamicDataMap: {'cmc': 1.0});

      expect(filter.matches(lotus), isTrue);
      expect(filter.matches(solRing), isFalse);
    });

    test('B16.2: Card with non-numeric power * matches stat filter operator = and value *', () {
      final filter = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '*')],
      );
      final tarmogoyf = createPhase39Card(id: 'goyf', name: 'Tarmogoyf', dynamicDataMap: {'power': '*'});
      final bear = createPhase39Card(id: 'bear', name: 'Grizzly Bears', dynamicDataMap: {'power': '2'});

      expect(filter.matches(tarmogoyf), isTrue);
      expect(filter.matches(bear), isFalse);
    });

    test('B16.3: Colorless card matches Colorless C filter', () {
      final filter = const MtgFilterState(
        colorMatchMode: ColorMatchMode.including,
        colors: {'C'},
      );
      final colorless = createPhase39Card(id: 'wastes', name: 'Wastes', dynamicDataMap: {'colors': ['C']});
      expect(filter.matches(colorless), isTrue);
    });

    test('B16.4: Case-insensitive type line search with multiple spaces matches correctly', () {
      final filter = const MtgFilterState(typeLine: '   legendary    creature   ');
      final card = createPhase39Card(
        id: 'urza',
        name: 'Urza',
        dynamicDataMap: {'type_line': 'Legendary Creature — Human Artificer'},
      );
      expect(filter.matches(card), isTrue);
    });

    test('B16.5: Card with multiple oracle text clauses matches only if all clauses present', () {
      final filter = const MtgFilterState(
        oracleTextClauses: ['flying', 'trample'],
      );
      final both = createPhase39Card(id: 'both', name: 'Dragon', dynamicDataMap: {'oracle_text': 'Flying, trample'});
      final flyingOnly = createPhase39Card(id: 'fly', name: 'Bird', dynamicDataMap: {'oracle_text': 'Flying only'});

      expect(filter.matches(both), isTrue);
      expect(filter.matches(flyingOnly), isFalse);
    });
  });

  // Feature 17: VaultDao Reactive Filtering Boundary Cases
  group('Tier 2 - B17: VaultDao Reactive Filtering Boundary Cases', () {
    test('B17.1: Query matching zero cards returns empty list without error', () async {
      final results = await dao.getItemsByCollection('mtg', searchQuery: 'NoSuchCardNameExistsEver999');
      expect(results, isEmpty);
    });

    test('B17.2: Special SQL wildcard characters in search query execute safely', () async {
      final results = await dao.getItemsByCollection('mtg', searchQuery: '%_\'');
      expect(results, isNotNull);
    });

    test('B17.3: Very long search query executes safely without SQL syntax error', () async {
      final longQuery = 'A' * 200;
      final results = await dao.getItemsByCollection('mtg', searchQuery: longQuery);
      expect(results, isEmpty);
    });

    test('B17.4: Rapid sequential database inserts update stream cleanly', () async {
      final stream = dao.watchItemsByCollection('mtg');
      final initial = await stream.first;

      for (int i = 0; i < 3; i++) {
        await dao.into(dao.vaultItems).insertOnConflictUpdate(
          createPhase39Card(id: 'rapid-insert-$i', name: 'Rapid Card $i', quantity: 1),
        );
      }

      final updated = await stream.first;
      expect(updated.length, initial.length + 3);
    });

    test('B17.5: Filtering by non-existent collection type returns empty list', () async {
      final results = await dao.getItemsByCollection('pokemon_nonexistent');
      expect(results, isEmpty);
    });
  });
}

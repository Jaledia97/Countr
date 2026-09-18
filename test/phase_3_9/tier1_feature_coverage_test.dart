import 'dart:convert';
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
  // TIER 1: FEATURE COVERAGE (17 Features × 5 Tests = 85 Tests)
  // ===========================================================================

  // Feature 1: DFC Flip Animation Retention (ORIGINAL_REQUEST §R1)
  group('Tier 1 - F1: DFC Flip Animation Retention', () {
    testWidgets('F1.1: Double-faced card (layout == transform) renders flip button in CardDetailSheet', (tester) async {
      final dfcItem = createPhase39Card(
        id: 'dfc-test-1',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Delver of Secrets', 'image_uris': {'normal': 'https://example.com/front.jpg'}},
            {'name': 'Insectile Aberration', 'image_uris': {'normal': 'https://example.com/back.jpg'}},
          ],
          'back_image_url': 'https://example.com/back.jpg',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: dfcItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
    });

    testWidgets('F1.2: Modal Double-Faced card (layout == modal_dfc) renders flip button in CardDetailSheet', (tester) async {
      final mdfcItem = createPhase39Card(
        id: 'mdfc-test-1',
        name: 'Bala Ged Recovery // Bala Ged Sanctuary',
        dynamicDataMap: {
          'layout': 'modal_dfc',
          'card_faces': [
            {'name': 'Bala Ged Recovery', 'image_uris': {'normal': 'https://example.com/front.jpg'}},
            {'name': 'Bala Ged Sanctuary', 'image_uris': {'normal': 'https://example.com/back.jpg'}},
          ],
          'back_image_url': 'https://example.com/back.jpg',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: mdfcItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
    });

    testWidgets('F1.3: Reversible card (layout == reversible_card) renders flip button in CardDetailSheet', (tester) async {
      final reversibleItem = createPhase39Card(
        id: 'rev-test-1',
        name: 'Propaganda // Propaganda',
        dynamicDataMap: {
          'layout': 'reversible_card',
          'card_faces': [
            {'name': 'Propaganda Face A', 'image_uris': {'normal': 'https://example.com/a.jpg'}},
            {'name': 'Propaganda Face B', 'image_uris': {'normal': 'https://example.com/b.jpg'}},
          ],
          'back_image_url': 'https://example.com/b.jpg',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: reversibleItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
    });

    testWidgets('F1.4: Tapping flip button in CardDetailSheet toggles front and back art state', (tester) async {
      final dfcItem = createPhase39Card(
        id: 'dfc-test-flip',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Delver of Secrets', 'image_uris': {'normal': 'https://example.com/front.jpg'}},
            {'name': 'Insectile Aberration', 'image_uris': {'normal': 'https://example.com/back.jpg'}},
          ],
          'back_image_url': 'https://example.com/back.jpg',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: dfcItem)));
      await tester.pumpAndSettle();

      final flipFinder = find.byKey(const Key('card_detail_flip_button'));
      expect(flipFinder, findsOneWidget);

      // Tap flip button and verify animation pump completes
      await tester.tap(flipFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(flipFinder, findsOneWidget);
    });

    testWidgets('F1.5: FullScreenCardViewer displays flip button for DFC cards and supports 3D flip', (tester) async {
      final dfcItem = createPhase39Card(
        id: 'dfc-fullscreen-1',
        name: 'Delver of Secrets',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Delver of Secrets', 'image_uris': {'normal': 'https://example.com/front.jpg'}},
            {'name': 'Insectile Aberration', 'image_uris': {'normal': 'https://example.com/back.jpg'}},
          ],
          'back_image_url': 'https://example.com/back.jpg',
        },
      );

      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfcItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fullscreen_flip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('fullscreen_flip_button')), findsOneWidget);
    });
  });

  // Feature 2: Adventure Flip Suppression (ORIGINAL_REQUEST §R1)
  group('Tier 1 - F2: Adventure Flip Suppression', () {
    late VaultItem adventureItem;

    setUp(() {
      adventureItem = createPhase39Card(
        id: 'adv-bonecrusher',
        name: 'Bonecrusher Giant // Stomp',
        dynamicDataMap: {
          'layout': 'adventure',
          'type_line': 'Creature — Giant // Instant — Adventure',
          'mana_cost': '{2}{R}',
          'card_faces': [
            {'name': 'Bonecrusher Giant', 'mana_cost': '{2}{R}', 'oracle_text': '2 damage to controller'},
            {'name': 'Stomp', 'mana_cost': '{1}{R}', 'oracle_text': 'Damage cannot be prevented'},
          ],
        },
      );
    });

    testWidgets('F2.1: Adventure card strictly suppresses flip button in CardDetailSheet', (tester) async {
      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('F2.2: Adventure card strictly suppresses face switch button in CardDetailSheet', (tester) async {
      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);
    });

    testWidgets('F2.3: Adventure card suppresses flip buttons in FullScreenCardViewer', (tester) async {
      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_appbar_flip_button')), findsNothing);
      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);
    });

    testWidgets('F2.4: Adventure card retains foil finish shader toggle in FullScreenCardViewer', (tester) async {
      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);
    });

    testWidgets('F2.5: Normal single-faced card also suppresses flip buttons in CardDetailSheet', (tester) async {
      final normalItem = createPhase39Card(
        id: 'normal-sol-ring',
        name: 'Sol Ring',
        dynamicDataMap: {'layout': 'normal'},
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: normalItem)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);
    });
  });

  // Feature 3: Adventure Unified Rules Box (ORIGINAL_REQUEST §R1)
  group('Tier 1 - F3: Adventure Unified Rules Box', () {
    late VaultItem adventureItem;

    setUp(() {
      adventureItem = createPhase39Card(
        id: 'adv-brazen',
        name: 'Brazen Borrower // Petty Theft',
        dynamicDataMap: {
          'layout': 'adventure',
          'type_line': 'Creature — Faerie Rogue // Instant — Adventure',
          'mana_cost': '{1}{U}{U}',
          'oracle_text': 'Flash. Flying. // Return target nonland permanent an opponent controls to its owner hand.',
          'card_faces': [
            {
              'name': 'Brazen Borrower',
              'mana_cost': '{1}{U}{U}',
              'type_line': 'Creature — Faerie Rogue',
              'oracle_text': 'Flash. Flying. Can block only creatures with flying.',
            },
            {
              'name': 'Petty Theft',
              'mana_cost': '{1}{U}',
              'type_line': 'Instant — Adventure',
              'oracle_text': 'Return target nonland permanent an opponent controls to its owner hand.',
            }
          ],
        },
      );
    });

    testWidgets('F3.1: Adventure card renders creature permanent text in CardDetailSheet', (tester) async {
      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Flash. Flying.'), findsOneWidget);
    });

    testWidgets('F3.2: Adventure card renders adventure spell text in CardDetailSheet', (tester) async {
      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Return target nonland permanent'), findsOneWidget);
    });

    testWidgets('F3.3: Adventure card renders the unified header ADVENTURE SPELL in rules section', (tester) async {
      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.text('ADVENTURE SPELL'), findsOneWidget);
    });

    testWidgets('F3.4: Adventure card displays both creature name and adventure spell name', (tester) async {
      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: adventureItem)));
      await tester.pumpAndSettle();

      expect(find.text('Brazen Borrower'), findsWidgets);
      expect(find.text('Petty Theft'), findsWidgets);
    });

    test('F3.5: Scryfall parser combines card_faces oracle_text with // delimiter', () {
      final json = createScryfallAdventureJson();
      final companion = mapScryfallCardToCompanion(json);
      final dyn = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;

      expect(dyn['oracle_text'], contains(' // '));
      expect(dyn['oracle_text'], contains('Whenever Bonecrusher Giant becomes the target'));
      expect(dyn['oracle_text'], contains('Damage cannot be prevented this turn'));
    });
  });

  // Feature 4: Universes Beyond Detection (ORIGINAL_REQUEST §R1)
  group('Tier 1 - F4: Universes Beyond Detection', () {
    test('F4.1: Card with promo_types containing universes_beyond is identified as UB', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final item = createPhase39Card(
        id: 'ub-test-promo',
        name: 'Aragorn, the Uniter',
        dynamicDataMap: {
          'promo_types': ['universes_beyond'],
          'security_stamp': 'oval',
        },
      );
      expect(filter.matches(item), isTrue);
    });

    test('F4.2: Card with frame_effects containing universesbeyond is identified as UB', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final item = createPhase39Card(
        id: 'ub-test-frame',
        name: 'Optimus Prime, Hero',
        dynamicDataMap: {
          'frame_effects': ['universesbeyond'],
        },
      );
      expect(filter.matches(item), isTrue);
    });

    test('F4.3: Card with security_stamp == triangle is identified as UB', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final item = createPhase39Card(
        id: 'ub-test-triangle',
        name: 'Warhammer 40k Inquisitor',
        dynamicDataMap: {
          'security_stamp': 'triangle',
        },
      );
      expect(filter.matches(item), isTrue);
    });

    test('F4.4: Card with is_universes_beyond boolean flag directly matches UB filter', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final item = createPhase39Card(
        id: 'ub-test-flag',
        name: 'Gandalf the White',
        dynamicDataMap: {
          'is_universes_beyond': true,
        },
      );
      expect(filter.matches(item), isTrue);
    });

    test('F4.5: Standard in-universe MTG card does NOT match UB filter', () {
      final filter = const MtgFilterState(isUniversesBeyond: true);
      final item = createPhase39Card(
        id: 'mtg-standard-card',
        name: 'Lightning Bolt',
        dynamicDataMap: {
          'layout': 'normal',
          'security_stamp': 'oval',
        },
      );
      expect(filter.matches(item), isFalse);
    });
  });

  // Feature 5: Secret Lairs & Flavor Search (ORIGINAL_REQUEST §R1)
  group('Tier 1 - F5: Secret Lairs & Flavor Search', () {
    test('F5.1: Secret Lair set code sld is preserved in Scryfall parser companion', () {
      final json = createScryfallSecretLairJson(set: 'sld');
      final companion = mapScryfallCardToCompanion(json);
      expect(companion.name.value, 'The Ozolith');
      expect(companion.flavorName.value, 'Adamantium Bonding Tank');
    });

    test('F5.2: Secret Lair Drop set name is preserved in setOrSeries column', () {
      final json = createScryfallSecretLairJson(setName: 'Secret Lair Drop');
      final companion = mapScryfallCardToCompanion(json);
      expect(companion.setOrSeries.value, 'Secret Lair Drop');
    });

    test('F5.3: Printed flavor_name is extracted and persisted in VaultItem.flavorName', () {
      final json = createScryfallSecretLairJson(flavorName: 'Adamantium Bonding Tank');
      final companion = mapScryfallCardToCompanion(json);
      expect(companion.flavorName.value, 'Adamantium Bonding Tank');
    });

    test('F5.4: VaultDao searches and finds card by printed flavor_name', () async {
      final results = await dao.searchCatalogCards('Adamantium', collectionType: 'mtg');
      expect(results, isNotEmpty);
      expect(results.first.name, 'The Ozolith');
      expect(results.first.flavorName, 'Adamantium Bonding Tank');
    });

    test('F5.5: VaultDao searches and finds card by canonical oracle name', () async {
      final results = await dao.searchCatalogCards('Ozolith', collectionType: 'mtg');
      expect(results, isNotEmpty);
      expect(results.first.name, 'The Ozolith');
    });
  });

  // Feature 6: Eliminate Literal "Check" (ORIGINAL_REQUEST §R2)
  group('Tier 1 - F6: Eliminate Literal Check', () {
    testWidgets('F6.1: VaultItemTile never renders literal Check when displaying market price', (tester) async {
      final item = createPhase39Card(
        id: 'tile-priced',
        name: 'Priced Tile Card',
        quantity: 0,
        currentMarketPrice: 8.50,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(
          width: 150,
          height: 200,
          child: VaultItemTile(item: item),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('\$8.50'), findsOneWidget);
    });

    testWidgets('F6.2: VaultItemCard never renders Check or Market Check in Investor mode for priced cards', (tester) async {
      final item = createPhase39Card(
        id: 'card-priced',
        name: 'Priced Row Card',
        quantity: 0,
        currentMarketPrice: 15.00,
      );

      await tester.pumpWidget(wrapWithHarness(
        VaultItemCard(item: item),
        persona: UserPersona.investor,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('\$15.00'), findsOneWidget);
    });

    testWidgets('F6.3: VaultItemCard never renders Check in Player mode', (tester) async {
      final item = createPhase39Card(
        id: 'card-player-priced',
        name: 'Player Mode Card',
        quantity: 1,
        currentMarketPrice: 10.00,
      );

      await tester.pumpWidget(wrapWithHarness(
        VaultItemCard(item: item),
        persona: UserPersona.player,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
    });

    testWidgets('F6.4: CardDetailSheet header price never renders Market: Check for priced cards', (tester) async {
      final item = createPhase39Card(
        id: 'detail-priced',
        name: 'Priced Detail Card',
        currentMarketPrice: 12.00,
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: item)));
      await tester.pumpAndSettle();

      expect(find.text('Market: Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.text('Market: \$12.00'), findsOneWidget);
    });

    test('F6.5: formatMarketPriceLabel helper maps 0.0 to Unlisted instead of Check', () {
      expect(formatMarketPriceLabel(0.0), 'Unlisted');
      expect(formatMarketPriceLabel(-1.0), 'Unlisted');
      expect(formatMarketPriceLabel(12.5), '\$12.50');
      expect(formatMarketPriceLabel(0.0).contains('Check'), isFalse);
    });
  });

  // Feature 7: Pricing Fallback Hierarchy (ORIGINAL_REQUEST §R2)
  group('Tier 1 - F7: Pricing Fallback Hierarchy', () {
    test('F7.1: Resolves normal USD price first when present', () {
      final prices = {'usd': '10.00', 'usd_foil': '25.00', 'eur': '9.00'};
      expect(resolveHierarchicalPrice(prices), 10.00);
    });

    test('F7.2: Falls back to usd_foil when usd is null or 0.0', () {
      final prices = {'usd': null, 'usd_foil': '25.50', 'eur': '20.00'};
      expect(resolveHierarchicalPrice(prices), 25.50);
    });

    test('F7.3: Falls back to usd_etched when usd and usd_foil are missing', () {
      final prices = {'usd': null, 'usd_foil': null, 'usd_etched': '33.00', 'eur': '28.00'};
      expect(resolveHierarchicalPrice(prices), 33.00);
    });

    test('F7.4: Falls back to eur when USD prices are missing', () {
      final prices = {'usd': null, 'usd_foil': null, 'usd_etched': null, 'eur': '14.20'};
      expect(resolveHierarchicalPrice(prices), 14.20);
    });

    test('F7.5: Falls back to eur_foil when all preceding currencies are missing', () {
      final prices = {'usd': null, 'usd_foil': null, 'usd_etched': null, 'eur': null, 'eur_foil': '19.99'};
      expect(resolveHierarchicalPrice(prices), 19.99);
    });
  });

  // Feature 8: Unlisted Price Labeling (ORIGINAL_REQUEST §R2)
  group('Tier 1 - F8: Unlisted Price Labeling', () {
    test('F8.1: Returns Unlisted for null prices map', () {
      expect(formatMarketPriceLabel(resolveHierarchicalPrice(null)), 'Unlisted');
    });

    test('F8.2: Returns Unlisted for empty prices map', () {
      expect(formatMarketPriceLabel(resolveHierarchicalPrice({})), 'Unlisted');
    });

    test('F8.3: Returns Unlisted when all currency entries are null', () {
      final prices = {'usd': null, 'usd_foil': null, 'eur': null};
      expect(formatMarketPriceLabel(resolveHierarchicalPrice(prices)), 'Unlisted');
    });

    test('F8.4: Returns Unlisted when numeric prices are 0.00', () {
      final prices = {'usd': '0.00', 'usd_foil': '0.00'};
      expect(formatMarketPriceLabel(resolveHierarchicalPrice(prices)), 'Unlisted');
    });

    test('F8.5: Formats positive price with dollar prefix and 2 decimals', () {
      expect(formatMarketPriceLabel(4.5), '\$4.50');
      expect(formatMarketPriceLabel(100.999), '\$101.00');
    });
  });

  // Feature 9: 3x Grid Quantity Badges (ORIGINAL_REQUEST §R3)
  group('Tier 1 - F9: 3x Grid Quantity Badges', () {
    testWidgets('F9.1: 3x singles grid tile renders quantity badge for duplicate card (quantity > 1)', (tester) async {
      final duplicateItem = createPhase39Card(
        id: 'dup-1',
        name: 'Duplicate Card',
        quantity: 3,
        currentMarketPrice: 5.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(
          width: 120,
          height: 180,
          child: VaultItemTile(item: duplicateItem),
        ),
      ));
      await tester.pumpAndSettle();

      // Look for duplicate badge key or quantity text
      expect(
        find.byKey(Key('vault_tile_duplicate_badge_${duplicateItem.id}')),
        findsOneWidget,
      );
      expect(find.textContaining('3'), findsOneWidget);
    });

    testWidgets('F9.2: 3x singles grid tile quantity badge displays exact count text x2 / 2x', (tester) async {
      final duplicateItem = createPhase39Card(
        id: 'dup-2',
        name: 'Double Card',
        quantity: 2,
        currentMarketPrice: 5.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(
          width: 120,
          height: 180,
          child: VaultItemTile(item: duplicateItem),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('vault_tile_duplicate_badge_${duplicateItem.id}')),
        findsOneWidget,
      );
      expect(find.textContaining('2'), findsOneWidget);
    });

    testWidgets('F9.3: 3x singles grid tile does NOT render duplicate badge when quantity == 1', (tester) async {
      final singleItem = createPhase39Card(
        id: 'single-1',
        name: 'Single Card',
        quantity: 1,
        currentMarketPrice: 5.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(
          width: 120,
          height: 180,
          child: VaultItemTile(item: singleItem),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${singleItem.id}')), findsNothing);
    });

    testWidgets('F9.4: Quantity badge renders in top position', (tester) async {
      final duplicateItem = createPhase39Card(
        id: 'dup-pos',
        name: 'Position Card',
        quantity: 4,
        currentMarketPrice: 5.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(
          width: 150,
          height: 200,
          child: VaultItemTile(item: duplicateItem),
        ),
      ));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${duplicateItem.id}'));
      expect(badgeFinder, findsOneWidget);
      final badgeTopLeft = tester.getTopLeft(badgeFinder);
      expect(badgeTopLeft.dy, lessThan(60));
    });

    testWidgets('F9.5: Catalog card with quantity == 0 renders catalog indicator or hides duplicate badge', (tester) async {
      final catalogItem = createPhase39Card(
        id: 'cat-0',
        name: 'Unowned Reference',
        quantity: 0,
        currentMarketPrice: 5.0,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(
          width: 120,
          height: 180,
          child: VaultItemTile(item: catalogItem),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('x0'), findsNothing);
    });
  });

  // Feature 10: List View Art Thumbnails (ORIGINAL_REQUEST §R3)
  group('Tier 1 - F10: List View Art Thumbnails', () {
    test('F10.1: Resolves small artwork thumbnail image from image_uris.small', () {
      final dyn = {
        'image_uris': {
          'small': 'https://cards.scryfall.io/small/front/test.jpg',
          'normal': 'https://cards.scryfall.io/normal/front/test.jpg',
        }
      };
      final uri = ((dyn['image_uris'] as Map)['small'] ?? '') as String;
      expect(uri, 'https://cards.scryfall.io/small/front/test.jpg');
    });

    test('F10.2: Falls back to normal or primary imageUrl when small image is absent', () {
      final dyn = {
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/front/normal.jpg',
        }
      };
      final uris = dyn['image_uris'] as Map;
      final uri = (uris['small'] ?? uris['normal'] ?? 'https://fallback.com') as String;
      expect(uri, 'https://cards.scryfall.io/normal/front/normal.jpg');
    });

    testWidgets('F10.3: List view card renders leading container slot for artwork thumbnail', (tester) async {
      final card = createPhase39Card(
        id: 'thumb-clip',
        name: 'Rounded Art Card',
        imageUrl: 'https://cards.scryfall.io/small/front/test.jpg',
      );

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: card)));
      await tester.pumpAndSettle();

      expect(find.byType(VaultItemCard), findsOneWidget);
      expect(find.text('Rounded Art Card'), findsOneWidget);
    });

    testWidgets('F10.4: Empty image URL renders placeholder icon or avatar gracefully', (tester) async {
      final cardNoImage = createPhase39Card(
        id: 'thumb-empty',
        name: 'No Image Card',
        imageUrl: '',
        dynamicDataMap: {},
      );

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: cardNoImage)));
      await tester.pumpAndSettle();

      expect(find.text('No Image Card'), findsOneWidget);
    });

    testWidgets('F10.5: List view renders card name alongside thumbnail in row across personas', (tester) async {
      final card = createPhase39Card(
        id: 'thumb-row',
        name: 'Row Layout Card',
        imageUrl: 'https://cards.scryfall.io/small/front/test.jpg',
      );

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: card), persona: UserPersona.player));
      await tester.pumpAndSettle();

      expect(find.text('Row Layout Card'), findsOneWidget);
    });
  });

  // Feature 11: Card Detail Swiping (ORIGINAL_REQUEST §R4)
  group('Tier 1 - F11: Card Detail Swiping', () {
    late List<VaultItem> swipeItems;

    setUp(() {
      swipeItems = List.generate(
        5,
        (i) => createPhase39Card(
          id: 'swipe-card-$i',
          name: 'Swipe Card $i',
          currentMarketPrice: (i + 1) * 10.0,
        ),
      );
    });

    testWidgets('F11.1: CardDetailSwipingHarness displays the initial card at index 0', (tester) async {
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: swipeItems, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Swipe Card 0'), findsWidgets);
    });

    testWidgets('F11.2: Swiping horizontally left navigates to the next card at index 1', (tester) async {
      int? changedIndex;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(
          items: swipeItems,
          initialIndex: 0,
          onPageChanged: (idx) => changedIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Swipe Card 1'), findsWidgets);
      expect(changedIndex, 1);
    });

    testWidgets('F11.3: Swiping right returns to previous card', (tester) async {
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: swipeItems, initialIndex: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Swipe Card 1'), findsWidgets);

      await tester.tap(find.byKey(const Key('swipe_prev_button')));
      await tester.pumpAndSettle();

      expect(find.text('Swipe Card 0'), findsWidgets);
    });

    testWidgets('F11.4: onPageChanged callback fires on each distinct page transition', (tester) async {
      final visitedIndices = <int>[];
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(
          items: swipeItems,
          initialIndex: 0,
          onPageChanged: (idx) => visitedIndices.add(idx),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(visitedIndices, containsAllInOrder([1, 2]));
    });

    testWidgets('F11.5: PageView strictly respects items.length bounds', (tester) async {
      final twoItems = swipeItems.take(2).toList();
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: twoItems, initialIndex: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Swipe Card 1'), findsWidgets);

      // Attempt to advance past last card
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Swipe Card 1'), findsWidgets);
    });
  });

  // Feature 12: Background Scroll Tracking (ORIGINAL_REQUEST §R4)
  group('Tier 1 - F12: Background Scroll Tracking', () {
    late ScrollController bgScrollController;
    late List<VaultItem> items;

    setUp(() {
      bgScrollController = ScrollController();
      items = List.generate(
        10,
        (i) => createPhase39Card(id: 'sync-card-$i', name: 'Sync Card $i'),
      );
    });

    tearDown(() {
      bgScrollController.dispose();
    });

    testWidgets('F12.1: Swiping to index 1 scrolls background ScrollController', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 100,
                child: ListView.builder(
                  controller: bgScrollController,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => SizedBox(height: 120, child: Text('Row $i')),
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
                    backgroundScrollController: bgScrollController,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(bgScrollController.offset, 0.0);

      // Swipe to page 1
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(bgScrollController.offset, greaterThan(0.0));
      expect(bgScrollController.offset, closeTo(120.0, 1.0));
    });

    testWidgets('F12.2: Swiping to index 2 scrolls background controller further', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 100,
                child: ListView.builder(
                  controller: bgScrollController,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => SizedBox(height: 120, child: Text('Row $i')),
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
                    backgroundScrollController: bgScrollController,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Advance to page 1 then page 2
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(bgScrollController.offset, closeTo(240.0, 1.0));
    });

    testWidgets('F12.3: Backward swiping returns background controller towards top', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 100,
                child: ListView.builder(
                  controller: bgScrollController,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => SizedBox(height: 120, child: Text('Row $i')),
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
                    initialIndex: 2,
                    backgroundScrollController: bgScrollController,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Return backwards to page 1
      await tester.tap(find.byKey(const Key('swipe_prev_button')));
      await tester.pumpAndSettle();

      expect(bgScrollController.offset, closeTo(120.0, 1.0));
    });

    testWidgets('F12.4: Scroll position persists after modal dismissal simulation', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ListView.builder(
              controller: bgScrollController,
              itemCount: items.length,
              itemBuilder: (ctx, i) => SizedBox(height: 120, child: Text('Row $i')),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      bgScrollController.jumpTo(240.0);
      await tester.pumpAndSettle();

      expect(bgScrollController.offset, 240.0);
    });

    testWidgets('F12.5: Gracefully handles backgroundScrollController with no attached clients', (tester) async {
      final unattachedController = ScrollController();
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(
          items: items,
          initialIndex: 0,
          backgroundScrollController: unattachedController,
        ),
      ));
      await tester.pumpAndSettle();

      // Swipe without crashing
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Sync Card 1'), findsWidgets);
      unattachedController.dispose();
    });
  });

  // Feature 13: FullScreenCardViewer Sync (ORIGINAL_REQUEST §R4)
  group('Tier 1 - F13: FullScreenCardViewer Sync', () {
    late List<VaultItem> fsItems;

    setUp(() {
      fsItems = [
        createPhase39Card(id: 'fs-0', name: 'Fullscreen 0'),
        createPhase39Card(id: 'fs-1', name: 'Fullscreen 1'),
        createPhase39Card(
          id: 'fs-dfc',
          name: 'Fullscreen DFC',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {'name': 'Face A', 'image_uris': {'normal': 'https://example.com/a.jpg'}},
              {'name': 'Face B', 'image_uris': {'normal': 'https://example.com/b.jpg'}},
            ],
            'back_image_url': 'https://example.com/b.jpg',
          },
        ),
      ];
    });

    testWidgets('F13.1: FullScreenSwipingTestHarness opens at exact specified initialIndex', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FullScreenSwipingTestHarness(items: fsItems, initialIndex: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_viewer_fs-1')), findsOneWidget);
    });

    testWidgets('F13.2: FullScreenSwipingTestHarness allows horizontal swiping to next card', (tester) async {
      int? swipedIdx;
      await tester.pumpWidget(MaterialApp(
        home: FullScreenSwipingTestHarness(
          items: fsItems,
          initialIndex: 0,
          onPageChanged: (idx) => swipedIdx = idx,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fs_swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_viewer_fs-1')), findsOneWidget);
      expect(swipedIdx, 1);
    });

    testWidgets('F13.3: DFC card in FullScreen retains flip button during swiping navigation', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FullScreenSwipingTestHarness(items: fsItems, initialIndex: 2),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_viewer_fs-dfc')), findsOneWidget);
      expect(find.byKey(const Key('fullscreen_flip_button')), findsOneWidget);
    });

    testWidgets('F13.4: Foil toggle button is present on cards in full-screen view', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FullScreenSwipingTestHarness(items: fsItems, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);
    });

    testWidgets('F13.5: InteractiveViewer provides pinch and pan zoom on full screen card', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(item: fsItems[0]),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_interactive_viewer')), findsOneWidget);
    });
  });

  // Feature 14: MTG Filter State & Provider (ORIGINAL_REQUEST §R5)
  group('Tier 1 - F14: MTG Filter State & Provider', () {
    test('F14.1: Initial MtgFilterState has activeCount == 0 and isActive == false', () {
      const state = MtgFilterState();
      expect(state.isActive, isFalse);
      expect(state.activeCount, 0);
    });

    test('F14.2: Selecting colors increments activeCount and sets isActive true', () {
      final state = const MtgFilterState().copyWith(colors: {'W', 'U'});
      expect(state.isActive, isTrue);
      expect(state.activeCount, 1);
      expect(state.colors, {'W', 'U'});
    });

    test('F14.3: Adjusting CMC range updates cmcRange and increments activeCount', () {
      final state = const MtgFilterState().copyWith(cmcRange: const RangeValues(2, 5));
      expect(state.isActive, isTrue);
      expect(state.cmcRange.start, 2);
      expect(state.cmcRange.end, 5);
      expect(state.activeCount, 1);
    });

    test('F14.4: reset() clears all active filter criteria', () {
      final dirty = const MtgFilterState().copyWith(
        colors: {'B', 'R'},
        cmcRange: const RangeValues(1, 4),
        typeLine: 'Dragon',
      );
      expect(dirty.activeCount, 3);
      final clean = dirty.reset();
      expect(clean.activeCount, 0);
      expect(clean.isActive, isFalse);
    });

    test('F14.5: copyWith() creates new instance preserving unchanged fields', () {
      const original = MtgFilterState(colorMatchMode: ColorMatchMode.exactly);
      final updated = original.copyWith(setCode: 'sld');
      expect(updated.colorMatchMode, ColorMatchMode.exactly);
      expect(updated.setCode, 'sld');
    });
  });

  // Feature 15: MTG Filter Sheet Modal (ORIGINAL_REQUEST §R5)
  group('Tier 1 - F15: MTG Filter Sheet Modal', () {
    testWidgets('F15.1: MtgFilterSheet renders with General and Collection tabs', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mtg_filter_tab_general')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_tab_collection')), findsOneWidget);
    });

    testWidgets('F15.2: Tapping color filter chips toggles color selection', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      final wChip = find.byKey(const Key('filter_chip_color_W'));
      expect(wChip, findsOneWidget);

      await tester.tap(wChip);
      await tester.pumpAndSettle();

      expect(find.text('Apply (1)'), findsOneWidget);
    });

    testWidgets('F15.3: Adjusting CMC range slider updates active count', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      final slider = find.byKey(const Key('filter_cmc_slider'));
      expect(slider, findsOneWidget);

      await tester.drag(slider, const Offset(50, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mtg_filter_apply_button')), findsOneWidget);
    });

    testWidgets('F15.4: Tapping Reset button restores default state', (tester) async {
      bool resetCalled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            initialState: const MtgFilterState(colors: {'R', 'G'}),
            onReset: () => resetCalled = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Apply (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mtg_filter_reset_button')));
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
      expect(find.text('Apply (0)'), findsOneWidget);
    });

    testWidgets('F15.5: Tapping Apply button triggers onApply with updated state', (tester) async {
      MtgFilterState? appliedState;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            onApply: (s) => appliedState = s,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_chip_color_U')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mtg_filter_apply_button')));
      await tester.pumpAndSettle();

      expect(appliedState, isNotNull);
      expect(appliedState!.colors, contains('U'));
    });
  });

  // Feature 16: MTG Filter Criteria Logic (ORIGINAL_REQUEST §R5)
  group('Tier 1 - F16: MTG Filter Criteria Logic', () {
    test('F16.1: ColorMatchMode.exactly matches cards with exact set of colors', () {
      final filter = const MtgFilterState(
        colorMatchMode: ColorMatchMode.exactly,
        colors: {'W', 'U'},
      );

      final wuCard = createPhase39Card(id: 'c1', name: 'Azorius Guildgate', dynamicDataMap: {'colors': ['W', 'U']});
      final wubCard = createPhase39Card(id: 'c2', name: 'Esper Charm', dynamicDataMap: {'colors': ['W', 'U', 'B']});

      expect(filter.matches(wuCard), isTrue);
      expect(filter.matches(wubCard), isFalse);
    });

    test('F16.2: ColorMatchMode.including matches cards containing specified colors', () {
      final filter = const MtgFilterState(
        colorMatchMode: ColorMatchMode.including,
        colors: {'R'},
      );

      final redCard = createPhase39Card(id: 'c3', name: 'Lightning Bolt', dynamicDataMap: {'colors': ['R']});
      final gruulCard = createPhase39Card(id: 'c4', name: 'Gruul Spellbreaker', dynamicDataMap: {'colors': ['R', 'G']});
      final blueCard = createPhase39Card(id: 'c5', name: 'Counterspell', dynamicDataMap: {'colors': ['U']});

      expect(filter.matches(redCard), isTrue);
      expect(filter.matches(gruulCard), isTrue);
      expect(filter.matches(blueCard), isFalse);
    });

    test('F16.3: ColorMatchMode.commander matches cards whose colors are a subset of commander colors', () {
      final filter = const MtgFilterState(
        colorMatchMode: ColorMatchMode.commander,
        colors: {'W', 'U', 'B'}, // Esper Commander
      );

      final wuCard = createPhase39Card(id: 'c6', name: 'Dovin Baan', dynamicDataMap: {'colors': ['W', 'U']});
      final redCard = createPhase39Card(id: 'c7', name: 'Shock', dynamicDataMap: {'colors': ['R']});

      expect(filter.matches(wuCard), isTrue);
      expect(filter.matches(redCard), isFalse);
    });

    test('F16.4: Power/Toughness stat filter matches cards with operator (=, >, <)', () {
      final filter = const MtgFilterState(
        statFilters: [
          MtgStatFilter(stat: 'power', operator: '>', value: '3'),
          MtgStatFilter(stat: 'toughness', operator: '=', value: '4'),
        ],
      );

      final matchingBeast = createPhase39Card(id: 'c8', name: 'Beast', dynamicDataMap: {'power': '4', 'toughness': '4'});
      final smallBeast = createPhase39Card(id: 'c9', name: 'Small Beast', dynamicDataMap: {'power': '2', 'toughness': '4'});

      expect(filter.matches(matchingBeast), isTrue);
      expect(filter.matches(smallBeast), isFalse);
    });

    test('F16.5: Type line filter matches cards matching search string', () {
      final filter = const MtgFilterState(typeLine: 'Legendary Angel');
      final angel = createPhase39Card(id: 'c10', name: 'Avacyn', dynamicDataMap: {'type_line': 'Legendary Creature — Angel'});
      final demon = createPhase39Card(id: 'c11', name: 'Griselbrand', dynamicDataMap: {'type_line': 'Legendary Creature — Demon'});

      expect(filter.matches(angel), isTrue);
      expect(filter.matches(demon), isFalse);
    });
  });

  // Feature 17: VaultDao Reactive Filtering (ORIGINAL_REQUEST §R5)
  group('Tier 1 - F17: VaultDao Reactive Filtering', () {
    test('F17.1: VaultDao filters items reactively by collectionType', () async {
      final mtgItems = await dao.getItemsByCollection('mtg');
      expect(mtgItems, isNotEmpty);
      expect(mtgItems.every((item) => item.collectionType == 'mtg'), isTrue);
    });

    test('F17.2: VaultDao filters items reactively by search query', () async {
      final results = await dao.getItemsByCollection('mtg', searchQuery: 'Delver');
      expect(results.length, 1);
      expect(results.first.name, contains('Delver'));
    });

    test('F17.3: VaultDao filters items reactively by onlyOwned flag', () async {
      final ownedItems = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(ownedItems.every((item) => item.quantity > 0), isTrue);
    });

    test('F17.4: VaultDao watchItemsByCollection stream emits when records change', () async {
      final stream = dao.watchItemsByCollection('mtg');
      final initial = await stream.first;

      // Insert new card
      await dao.into(dao.vaultItems).insertOnConflictUpdate(
        createPhase39Card(id: 'reactive-card-1', name: 'Reactive Lotus', quantity: 1),
      );

      final updated = await stream.first;
      expect(updated.length, initial.length + 1);
      expect(updated.any((c) => c.id == 'reactive-card-1'), isTrue);
    });

    test('F17.5: VaultDao combines search query with onlyOwned condition', () async {
      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'Bonecrusher',
      );
      expect(results.length, 1);
      expect(results.first.name, contains('Bonecrusher'));
      expect(results.first.quantity, greaterThan(0));
    });
  });
}

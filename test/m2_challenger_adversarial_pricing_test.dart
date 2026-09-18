import 'dart:convert';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

/// Factory for generating adversarial test cards with customizable properties.
VaultItem createChallengerCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  int quantity = 1,
  double currentMarketPrice = 0.0,
  double acquiredPrice = 0.0,
  String condition = 'NM',
  bool isGraded = false,
  String? flavorName,
  Map<String, dynamic>? prices,
  Map<String, dynamic>? extraDynamicData,
  String? rawDynamicData,
}) {
  final dyn = <String, dynamic>{
    'prices': ?prices,
    'layout': 'normal',
    'mana_cost': '{1}{U}{B}',
    'type_line': 'Creature — Wizard',
    'power': '2',
    'toughness': '3',
    'keywords': ['Flying'],
    'oracle_text': 'Flying. When this creature enters the battlefield, draw a card.',
    ...?extraDynamicData,
  };

  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    flavorName: flavorName,
    setOrSeries: 'MH3',
    imageUrl: '',
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime(2026, 9, 18),
    quantity: quantity,
    condition: condition,
    isGraded: isGraded,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2026, 9, 18),
    dynamicData: rawDynamicData ?? jsonEncode(dyn),
  );
}

/// Test harness wrapper providing necessary Riverpod providers and Scaffold.
Widget buildChallengerHarness(
  Widget child, {
  AppDatabase? db,
  UserPersona persona = UserPersona.investor,
}) {
  final database = db ?? AppDatabase(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      vaultDaoProvider.overrideWithValue(database.vaultDao),
      userPersonaProvider.overrideWith((ref) => persona),
      cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
      activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // GROUP 1: VAULT ITEM TILE ADVERSARIAL PRICING CHALLENGE
  // ===========================================================================
  group('Adversarial Challenge: VaultItemTile Pricing States', () {
    testWidgets('T1.1: Unpriced unowned tile renders "Unlisted", never "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'tile-unpriced-unowned',
        name: 'Black Lotus',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {},
      );

      await tester.pumpWidget(buildChallengerHarness(
        SizedBox(width: 150, height: 220, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('T1.2: Zero-priced unowned tile (usd: "0.00") renders "Unlisted", never "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'tile-zero-unowned',
        name: 'Mox Sapphire',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00', 'usd_foil': '0.00', 'eur': '0.00'},
      );

      await tester.pumpWidget(buildChallengerHarness(
        SizedBox(width: 150, height: 220, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('T1.3: Unpriced owned tile renders "Unlisted", never "\$0.00" or "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'tile-unpriced-owned',
        name: 'Timetwister',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: null,
      );

      await tester.pumpWidget(buildChallengerHarness(
        SizedBox(width: 150, height: 220, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text(r'$0.00'), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('T1.4: Zero-priced owned tile (usd: "0.00") renders "Unlisted", never "\$0.00" or "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'tile-zero-owned',
        name: 'Ancestral Recall',
        quantity: 3,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00'},
      );

      await tester.pumpWidget(buildChallengerHarness(
        SizedBox(width: 150, height: 220, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text(r'$0.00'), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('T1.5: Negative and corrupted price strings safely resolve to "Unlisted"', (tester) async {
      final card = createChallengerCard(
        id: 'tile-negative-corrupted',
        name: 'Force of Will',
        quantity: 1,
        currentMarketPrice: -15.0,
        prices: {'usd': '-99.99', 'usd_foil': 'N/A', 'eur': 'invalid_string'},
      );

      await tester.pumpWidget(buildChallengerHarness(
        SizedBox(width: 150, height: 220, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.textContaining(r'$-'), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('T1.6: DynamicData card_faces pricing fallback works when top-level prices missing', (tester) async {
      final card = createChallengerCard(
        id: 'tile-faces-fallback',
        name: 'Delver of Secrets // Insectile Aberration',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: {},
        extraDynamicData: {
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'prices': {'usd': '2.75'},
            },
            {
              'name': 'Insectile Aberration',
              'prices': {'usd': '0.00'},
            }
          ]
        },
      );

      await tester.pumpWidget(buildChallengerHarness(
        SizedBox(width: 150, height: 220, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text(r'$2.75'), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 2: VAULT ITEM CARD ADVERSARIAL PRICING CHALLENGE (INVESTOR & PLAYER)
  // ===========================================================================
  group('Adversarial Challenge: VaultItemCard Pricing States & Persona Modes', () {
    testWidgets('C2.1: Investor mode unowned unpriced renders "Unlisted" under MARKET VALUE, never "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'card-unpriced-unowned-inv',
        name: 'Mox Jet',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {'usd': null, 'usd_foil': null},
      );

      await tester.pumpWidget(buildChallengerHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('CATALOG / UNOWNED'), findsOneWidget);
      expect(find.text('MARKET VALUE'), findsOneWidget);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('C2.2: Investor mode unowned zero-priced ("0.00") renders "Unlisted", never "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'card-zero-unowned-inv',
        name: 'Mox Ruby',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00', 'usd_foil': '0.00'},
      );

      await tester.pumpWidget(buildChallengerHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('C2.3: Investor mode owned unpriced renders "Unlisted" under LIVE TMV, never "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'card-unpriced-owned-inv',
        name: 'Underground Sea',
        quantity: 2,
        acquiredPrice: 450.0,
        currentMarketPrice: 0.0,
        prices: {},
      );

      await tester.pumpWidget(buildChallengerHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('LIVE TMV'), findsOneWidget);
      expect(find.text('Unlisted'), findsOneWidget);
      expect(find.text(r'$450.00'), findsOneWidget);
    });

    testWidgets('C2.4: Investor mode owned zero-priced ("0.00") renders "Unlisted" under LIVE TMV', (tester) async {
      final card = createChallengerCard(
        id: 'card-zero-owned-inv',
        name: 'Volcanic Island',
        quantity: 1,
        acquiredPrice: 550.0,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00'},
      );

      await tester.pumpWidget(buildChallengerHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('LIVE TMV'), findsOneWidget);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('C2.5: Player mode unowned unpriced suppresses all financial metrics and has NO "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'card-unpriced-unowned-play',
        name: 'Mana Vault',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {},
      );

      await tester.pumpWidget(buildChallengerHarness(
        VaultItemCard(item: card, persona: UserPersona.player),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('MARKET VALUE'), findsNothing);
      expect(find.text('LIVE TMV'), findsNothing);
      expect(find.text('Unlisted'), findsNothing);
      expect(find.text('GAME UTILITY'), findsOneWidget);
    });

    testWidgets('C2.6: Player mode owned unpriced suppresses all financial metrics and has NO "Check"', (tester) async {
      final card = createChallengerCard(
        id: 'card-unpriced-owned-play',
        name: 'Mana Crypt',
        quantity: 1,
        acquiredPrice: 180.0,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00'},
      );

      await tester.pumpWidget(buildChallengerHarness(
        VaultItemCard(item: card, persona: UserPersona.player),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('LIVE TMV'), findsNothing);
      expect(find.text(r'$180.00'), findsNothing);
      expect(find.text('Unlisted'), findsNothing);
      expect(find.text('GAME UTILITY'), findsOneWidget);
    });

    testWidgets('C2.7: Non-MTG (Pokemon) card unpriced in Investor mode displays "Unlisted", never "Check"', (tester) async {
      final pokemonCard = createChallengerCard(
        id: 'card-pokemon-unpriced',
        name: 'Charizard Base Set',
        collectionType: 'pokemon',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: null,
        extraDynamicData: {
          'hp': '120',
          'stage': 'Stage 2',
        },
      );

      await tester.pumpWidget(buildChallengerHarness(
        VaultItemCard(item: pokemonCard, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('LIVE TMV'), findsOneWidget);
      expect(find.text('Unlisted'), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 3: CARD DETAIL SHEET ADVERSARIAL PRICING CHALLENGE
  // ===========================================================================
  group('Adversarial Challenge: CardDetailSheet Pricing States', () {
    testWidgets('S3.1: Owned unpriced card renders "Market: Unlisted", never "Market: Check"', (tester) async {
      final card = createChallengerCard(
        id: 'detail-unpriced-owned',
        name: 'Gaea\'s Cradle',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: null,
      );

      await tester.pumpWidget(buildChallengerHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Market: Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('Market: Unlisted'), findsOneWidget);
    });

    testWidgets('S3.2: Owned zero-priced card ("0.00") renders "Market: Unlisted", never "Market: Check"', (tester) async {
      final card = createChallengerCard(
        id: 'detail-zero-owned',
        name: 'Tabernacle at Pendrell Vale',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00', 'usd_foil': '0.00', 'eur': '0.00'},
      );

      await tester.pumpWidget(buildChallengerHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Market: Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('Market: Unlisted'), findsOneWidget);
    });

    testWidgets('S3.3: Unowned unpriced card renders "Market: Unlisted", never "Market: Check"', (tester) async {
      final card = createChallengerCard(
        id: 'detail-unpriced-unowned',
        name: 'Bazaar of Baghdad',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {},
      );

      await tester.pumpWidget(buildChallengerHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Market: Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('Market: Unlisted'), findsOneWidget);
    });

    testWidgets('S3.4: Adventure card unpriced renders "Market: Unlisted" without flip controls', (tester) async {
      final card = createChallengerCard(
        id: 'detail-adventure-unpriced',
        name: 'Brazen Borrower // Petty Theft',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00'},
        extraDynamicData: {
          'layout': 'adventure',
          'card_faces': [
            {'name': 'Brazen Borrower', 'type_line': 'Creature — Faerie Rogue'},
            {'name': 'Petty Theft', 'type_line': 'Instant — Adventure'},
          ],
        },
      );

      await tester.pumpWidget(buildChallengerHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Market: Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.text('Market: Unlisted'), findsOneWidget);
      // Flip button must NOT be present for adventure cards
      expect(find.byIcon(Icons.flip_camera_android_rounded), findsNothing);
      expect(find.byIcon(Icons.cached_rounded), findsNothing);
    });

    testWidgets('S3.5: Transforming DFC unpriced renders "Market: Unlisted" and retains flip button', (tester) async {
      final card = createChallengerCard(
        id: 'detail-dfc-unpriced',
        name: 'Jace, Vryn\'s Prodigy // Jace, Telepath Unbound',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: {},
        extraDynamicData: {
          'layout': 'transform',
          'card_faces': [
            {'name': 'Jace, Vryn\'s Prodigy', 'type_line': 'Legendary Creature'},
            {'name': 'Jace, Telepath Unbound', 'type_line': 'Legendary Planeswalker'},
          ],
          'back_image_url': 'https://example.com/jace_back.jpg',
        },
      );

      await tester.pumpWidget(buildChallengerHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Market: Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.text('Market: Unlisted'), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 4: ADVERSARIAL EDGE CASE & BOUNDARY ORACLE TESTS
  // ===========================================================================
  group('Adversarial Challenge: Mathematical & Type Robustness Oracles', () {
    test('E4.1: parsePositivePrice rejects all invalid, non-positive, and non-finite numbers', () {
      // Non-positive doubles
      expect(parsePositivePrice(0.0), isNull);
      expect(parsePositivePrice(-0.0), isNull);
      expect(parsePositivePrice(-1.0), isNull);
      expect(parsePositivePrice(-0.0001), isNull);

      // String zeroes
      expect(parsePositivePrice('0'), isNull);
      expect(parsePositivePrice('0.0'), isNull);
      expect(parsePositivePrice('0.00'), isNull);
      expect(parsePositivePrice('00.000'), isNull);
      expect(parsePositivePrice('.00'), isNull);
      expect(parsePositivePrice('-0.00'), isNull);

      // Non-finite
      expect(parsePositivePrice(double.nan), isNull);
      expect(parsePositivePrice(double.infinity), isNull);
      expect(parsePositivePrice(double.negativeInfinity), isNull);
      expect(parsePositivePrice('NaN'), isNull);
      expect(parsePositivePrice('Infinity'), isNull);
      expect(parsePositivePrice('-Infinity'), isNull);

      // Malformed / Non-numeric
      expect(parsePositivePrice(''), isNull);
      expect(parsePositivePrice('   '), isNull);
      expect(parsePositivePrice('Free'), isNull);
      expect(parsePositivePrice('Check'), isNull);
      expect(parsePositivePrice('null'), isNull);
      expect(parsePositivePrice(null), isNull);
      expect(parsePositivePrice([]), isNull);
      expect(parsePositivePrice({}), isNull);

      // Valid positives
      expect(parsePositivePrice('0.01'), equals(0.01));
      expect(parsePositivePrice('0.00001'), equals(0.00001));
      expect(parsePositivePrice('  99.95  '), equals(99.95));
      expect(parsePositivePrice(100), equals(100.0));
      expect(parsePositivePrice('1e3'), equals(1000.0));
    });

    test('E4.2: Pricing hierarchy skips multiple intermediate zero and corrupted currencies', () {
      // Hierarchy: usd -> usd_foil -> usd_etched -> eur -> eur_foil
      final complexPrices = {
        'usd': '0.00',
        'usd_foil': null,
        'usd_etched': '-12.00', // negative: skip
        'eur': 'invalid_eur', // unparseable: skip
        'eur_foil': '31.25', // valid: resolve!
      };
      expect(resolveHierarchicalPrice(complexPrices), equals(31.25));
    });

    test('E4.3: extractFromDynamicData is immune to malformed inputs', () {
      expect(VaultPricingHelper.extractFromDynamicData(null), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData(''), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData('{"prices": null}'), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData('{"prices": "not_a_map"}'), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData('{"prices": []}'), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData('{"prices": {"usd": "0.00"}}'), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData('{malformed json!'), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData(42), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData(['array', 'instead', 'of', 'map']), equals(0.0));
    });

    test('E4.4: formatMarketPriceLabel and formatMarketHeaderLabel support custom fallback "—"', () {
      expect(formatMarketPriceLabel(0.0, fallback: '—'), equals('—'));
      expect(formatMarketPriceLabel(-5.0, fallback: '—'), equals('—'));
      expect(formatMarketPriceLabel(15.20, fallback: '—'), equals(r'$15.20'));

      expect(formatMarketHeaderLabel(0.0, fallback: '—'), equals('Market: —'));
      expect(formatMarketHeaderLabel(-5.0, fallback: '—'), equals('Market: —'));
      expect(formatMarketHeaderLabel(15.20, fallback: '—'), equals('Market: \$15.20'));
    });
  });
}

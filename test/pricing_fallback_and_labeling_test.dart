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
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

/// Helper to create a test [VaultItem] with customized prices and quantities.
VaultItem createTestCard({
  required String id,
  required String name,
  int quantity = 0,
  double currentMarketPrice = 0.0,
  double acquiredPrice = 0.0,
  Map<String, dynamic>? prices,
  Map<String, dynamic>? extraDynamicData,
}) {
  final dyn = <String, dynamic>{
    'prices': ?prices,
    'layout': 'normal',
    'mana_cost': '{2}{U}',
    'type_line': 'Instant',
    ...?extraDynamicData,
  };

  return VaultItem(
    id: id,
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'MH3',
    imageUrl: '',
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime(2026, 9, 18),
    quantity: quantity,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2026, 9, 18),
    dynamicData: jsonEncode(dyn),
  );
}

/// Standalone harness wrapping test widgets in a valid ProviderScope & MaterialApp.
Widget wrapWithPricingHarness(
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
  // GROUP 1: UNIT TESTS — PRICING FALLBACK CHAIN EXTRACTION & 0.00 BUG FIX
  // ===========================================================================
  group('Unit Tests: Pricing Fallback Hierarchy & 0.00 Short-Circuit Fix', () {
    test('U1.1: Uses USD normal price when present', () {
      final prices = {
        'usd': '1.50',
        'usd_foil': '4.00',
        'usd_etched': '5.00',
        'eur': '1.20',
        'eur_foil': '3.50',
      };
      expect(resolveHierarchicalPrice(prices), equals(1.50));
    });

    test('U1.2: Falls back to usd_foil when usd is null', () {
      final prices = {
        'usd': null,
        'usd_foil': '25.00',
        'usd_etched': '30.00',
        'eur': '20.00',
      };
      expect(resolveHierarchicalPrice(prices), equals(25.00));
    });

    test('U1.3: Falls back to usd_foil when usd is "0.00" (Fixes short-circuit bug)', () {
      final prices = {
        'usd': '0.00',
        'usd_foil': '24.50',
        'usd_etched': '30.00',
        'eur': '20.00',
      };
      // In flawed logic, double.tryParse('0.00') returned 0.0 which was non-null and halted fallback.
      // With the fix, it must correctly resolve to 24.50.
      expect(resolveHierarchicalPrice(prices), equals(24.50));
    });

    test('U1.4: Falls back to usd_etched when usd and usd_foil are "0.00" or null', () {
      final prices = {
        'usd': '0.00',
        'usd_foil': null,
        'usd_etched': '37.80',
        'eur': '25.00',
      };
      expect(resolveHierarchicalPrice(prices), equals(37.80));
    });

    test('U1.5: Falls back to eur when all USD variants are "0.00" or null', () {
      final prices = {
        'usd': '0.00',
        'usd_foil': '0.00',
        'usd_etched': null,
        'eur': '14.25',
        'eur_foil': '22.00',
      };
      expect(resolveHierarchicalPrice(prices), equals(14.25));
    });

    test('U1.6: Falls back to eur_foil when all preceding currencies are "0.00" or null', () {
      final prices = {
        'usd': '0.00',
        'usd_foil': null,
        'usd_etched': '0.00',
        'eur': '0.00',
        'eur_foil': '19.99',
      };
      expect(resolveHierarchicalPrice(prices), equals(19.99));
    });

    test('U1.7: Sets 0.0 when all currency variants are null or "0.00"', () {
      final prices = {
        'usd': '0.00',
        'usd_foil': null,
        'usd_etched': '0.00',
        'eur': null,
        'eur_foil': '0.00',
      };
      expect(resolveHierarchicalPrice(prices), equals(0.0));
    });

    test('U1.8: Sets 0.0 when prices map is empty or missing', () {
      expect(resolveHierarchicalPrice({}), equals(0.0));
      expect(resolveHierarchicalPrice(null), equals(0.0));
    });

    test('U1.9: Handles non-numeric, negative, or whitespace price values safely', () {
      final prices = {
        'usd': '-12.00', // negative: must be ignored
        'usd_foil': 'N/A', // invalid: must be ignored
        'usd_etched': '  18.50  ', // whitespace: must parse cleanly
      };
      expect(resolveHierarchicalPrice(prices), equals(18.50));
    });

    test('U1.10: parsePositivePrice returns positive finite doubles or null', () {
      expect(parsePositivePrice('12.50'), equals(12.50));
      expect(parsePositivePrice('0.01'), equals(0.01));
      expect(parsePositivePrice(50), equals(50.0));
      expect(parsePositivePrice(19.99), equals(19.99));

      expect(parsePositivePrice('0.00'), isNull);
      expect(parsePositivePrice('0'), isNull);
      expect(parsePositivePrice('-5.00'), isNull);
      expect(parsePositivePrice('null'), isNull);
      expect(parsePositivePrice(''), isNull);
      expect(parsePositivePrice(null), isNull);
      expect(parsePositivePrice(double.nan), isNull);
      expect(parsePositivePrice(double.infinity), isNull);
      expect(parsePositivePrice(double.negativeInfinity), isNull);
    });

    test('U1.11: formatMarketPriceLabel and formatMarketHeaderLabel format correctly', () {
      expect(formatMarketPriceLabel(12.50), equals('\$12.50'));
      expect(formatMarketPriceLabel(0.0), equals('Unlisted'));
      expect(formatMarketPriceLabel(-1.0), equals('Unlisted'));
      expect(formatMarketPriceLabel(double.nan), equals('Unlisted'));
      expect(formatMarketPriceLabel(double.infinity), equals('Unlisted'));
      expect(formatMarketPriceLabel(0.0, fallback: '—'), equals('—'));

      expect(formatMarketHeaderLabel(12.50), equals('Market: \$12.50'));
      expect(formatMarketHeaderLabel(0.0), equals('Market: Unlisted'));
      expect(formatMarketHeaderLabel(-1.0), equals('Market: Unlisted'));
      expect(formatMarketHeaderLabel(0.0, fallback: '—'), equals('Market: —'));
      expect(formatMarketHeaderLabel(0.0).contains('Check'), isFalse);
    });

    test('U1.12: VaultItemPricing extension provides ergonomic accessors', () {
      final cardWithDirectPrice = createTestCard(
        id: 'u1-12a',
        name: 'Extension Direct Card',
        currentMarketPrice: 42.50,
      );
      expect(cardWithDirectPrice.effectiveMarketPrice, equals(42.50));
      expect(cardWithDirectPrice.formatMarketPrice(), equals('\$42.50'));
      expect(cardWithDirectPrice.formatMarketHeader(), equals('Market: \$42.50'));

      final cardWithDynamicFallback = createTestCard(
        id: 'u1-12b',
        name: 'Extension Dynamic Card',
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00', 'usd_foil': '17.25'},
      );
      expect(cardWithDynamicFallback.effectiveMarketPrice, equals(17.25));
      expect(cardWithDynamicFallback.formatMarketPrice(), equals('\$17.25'));
      expect(cardWithDynamicFallback.formatMarketHeader(), equals('Market: \$17.25'));

      final unpricedCard = createTestCard(
        id: 'u1-12c',
        name: 'Extension Unpriced Card',
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00'},
      );
      expect(unpricedCard.effectiveMarketPrice, equals(0.0));
      expect(unpricedCard.formatMarketPrice(), equals('Unlisted'));
      expect(unpricedCard.formatMarketHeader(), equals('Market: Unlisted'));
    });
  });

  // ===========================================================================
  // GROUP 2: WIDGET TESTS — VERIFY "CHECK" IS ABSENT WHEN ITEMS ARE UNPRICED
  // ===========================================================================
  group('Widget Tests: Absolute Absence of "Check" Across All Widgets', () {
    testWidgets('W2.1: VaultItemTile renders "Unlisted" and NEVER "Check" for unpriced catalog item', (tester) async {
      final unpricedCatalogTile = createTestCard(
        id: 'tile-unpriced-0',
        name: 'Sol Ring Unpriced',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {'usd': null, 'usd_foil': null, 'eur': null},
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(
          width: 140,
          height: 200,
          child: VaultItemTile(item: unpricedCatalogTile),
        ),
      ));
      await tester.pumpAndSettle();

      // Assert literal "Check" is strictly absent
      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);

      // Assert "Unlisted" is prominently rendered
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets(r'W2.2: VaultItemTile renders "Unlisted" and NEVER "$0.00" / "Check" for unpriced owned item', (tester) async {
      final unpricedOwnedTile = createTestCard(
        id: 'tile-unpriced-owned',
        name: 'Dark Ritual Unpriced',
        quantity: 2,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00', 'usd_foil': '0.00'},
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(
          width: 140,
          height: 200,
          child: VaultItemTile(item: unpricedOwnedTile),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('W2.3: VaultItemCard renders "Unlisted" and NEVER "Market Check" in Investor Mode', (tester) async {
      final unpricedCatalogCard = createTestCard(
        id: 'card-unpriced-catalog',
        name: 'Black Lotus Unpriced',
        quantity: 0,
        currentMarketPrice: 0.0,
        prices: {'usd': '0.00', 'usd_foil': null},
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(
          item: unpricedCatalogCard,
          persona: UserPersona.investor,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert "Market Check" and "Check" are strictly absent
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);

      // Assert "Unlisted" is rendered
      expect(find.text('Unlisted'), findsOneWidget);
    });

    testWidgets('W2.4: VaultItemCard in Player Mode suppresses financial rows and has NO "Check"', (tester) async {
      final unpricedPlayerCard = createTestCard(
        id: 'card-unpriced-player',
        name: 'Lightning Bolt Unpriced',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: {},
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(
          item: unpricedPlayerCard,
          persona: UserPersona.player,
        ),
      ));
      await tester.pumpAndSettle();

      // In Player mode, utility mechanics appear while financial rows are omitted
      expect(find.text('Check'), findsNothing);
      expect(find.text('Market Check'), findsNothing);
      expect(find.text('MARKET VALUE'), findsNothing);
      expect(find.text('Unlisted'), findsNothing);
    });

    testWidgets('W2.5: CardDetailSheet header renders "Market: Unlisted" and NEVER "Market: Check"', (tester) async {
      final unpricedDetailCard = createTestCard(
        id: 'detail-unpriced',
        name: 'Mox Diamond Unpriced',
        quantity: 1,
        currentMarketPrice: 0.0,
        prices: {'usd': null, 'usd_foil': '0.00', 'eur': null},
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: unpricedDetailCard),
        db: db,
      ));
      await tester.pumpAndSettle();

      // Assert "Market: Check" and "Check" are absent
      expect(find.text('Market: Check'), findsNothing);
      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);

      // Assert "Market: Unlisted" is rendered
      expect(find.text('Market: Unlisted'), findsOneWidget);
    });

    testWidgets('W2.6: FullScreenCardViewer has NO "Check" text when item is unpriced', (tester) async {
      final unpricedFullScreenCard = createTestCard(
        id: 'fs-unpriced',
        name: 'Time Walk Unpriced',
        quantity: 1,
        currentMarketPrice: 0.0,
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        FullScreenCardViewer(item: unpricedFullScreenCard),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 3: WIDGET TESTS — COMPLETE PRICING FALLBACK CHAIN
  // ===========================================================================
  group('Widget Tests: Pricing Fallback Hierarchy in UI Components', () {
    // -------------------------------------------------------------------------
    // Priority 1: Normal USD present -> uses USD ($12.50)
    // -------------------------------------------------------------------------
    testWidgets(r'W3.1: Tier 1 - Normal USD present uses USD ($12.50)', (tester) async {
      final card = createTestCard(
        id: 'tier1-card',
        name: 'Tarmogoyf',
        prices: {
          'usd': '12.50',
          'usd_foil': '30.00',
          'usd_etched': '40.00',
          'eur': '11.00',
          'eur_foil': '25.00',
        },
      );

      // 1. VaultItemTile
      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$12.50'), findsOneWidget);

      // 2. VaultItemCard
      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$12.50'), findsOneWidget);

      // 3. CardDetailSheet
      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Market: \$12.50'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Priority 2A: USD null, USD Foil present -> uses USD Foil ($25.00)
    // -------------------------------------------------------------------------
    testWidgets(r'W3.2: Tier 2A - USD null falls back to USD Foil ($25.00)', (tester) async {
      final card = createTestCard(
        id: 'tier2a-card',
        name: 'Chandra Foil Exclusive',
        prices: {
          'usd': null,
          'usd_foil': '25.00',
          'usd_etched': '45.00',
          'eur': '20.00',
        },
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$25.00'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$25.00'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Market: \$25.00'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Priority 2B: USD "0.00" (String zero bug), USD Foil present -> uses USD Foil ($25.00)
    // -------------------------------------------------------------------------
    testWidgets(r'W3.3: Tier 2B - USD "0.00" does NOT short-circuit; uses USD Foil ($25.00)', (tester) async {
      final card = createTestCard(
        id: 'tier2b-card',
        name: 'Jace Foil Over Zero USD',
        prices: {
          'usd': '0.00',
          'usd_foil': '25.00',
          'eur': '18.00',
        },
      );

      // Verify VaultItemTile renders $25.00, NOT "Unlisted" or "$0.00"
      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$25.00'), findsOneWidget);
      expect(find.text('Unlisted'), findsNothing);

      // Verify VaultItemCard renders $25.00
      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$25.00'), findsOneWidget);

      // Verify CardDetailSheet renders Market: $25.00
      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Market: \$25.00'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Priority 3: USD / USD Foil "0.00" or null, USD Etched present -> uses USD Etched ($34.50)
    // -------------------------------------------------------------------------
    testWidgets(r'W3.4: Tier 3 - USD & Foil "0.00"/null falls back to USD Etched ($34.50)', (tester) async {
      final card = createTestCard(
        id: 'tier3-card',
        name: 'Teferi Etched Foil',
        prices: {
          'usd': '0.00',
          'usd_foil': null,
          'usd_etched': '34.50',
          'eur': '22.00',
        },
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$34.50'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$34.50'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Market: \$34.50'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Priority 4: All USD variants "0.00" or null, EUR present -> uses EUR ($16.75)
    // -------------------------------------------------------------------------
    testWidgets(r'W3.5: Tier 4 - USD variants missing/zero falls back to EUR ($16.75)', (tester) async {
      final card = createTestCard(
        id: 'tier4-card',
        name: 'Urza Saga Euro Only',
        prices: {
          'usd': '0.00',
          'usd_foil': '0.00',
          'usd_etched': null,
          'eur': '16.75',
          'eur_foil': '28.00',
        },
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$16.75'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$16.75'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Market: \$16.75'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Priority 5: USD variants and EUR missing/zero, EUR Foil present -> uses EUR Foil ($28.50)
    // -------------------------------------------------------------------------
    testWidgets(r'W3.6: Tier 5 - All preceding missing/zero falls back to EUR Foil ($28.50)', (tester) async {
      final card = createTestCard(
        id: 'tier5-card',
        name: 'Ragavan Euro Foil Only',
        prices: {
          'usd': '0.00',
          'usd_foil': null,
          'usd_etched': '0.00',
          'eur': '0.00',
          'eur_foil': '28.50',
        },
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$28.50'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$28.50'), findsOneWidget);

      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Market: \$28.50'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Priority 6: All variants null or "0.00" -> displays "Unlisted"
    // -------------------------------------------------------------------------
    testWidgets('W3.7: Tier 6 - All variants "0.00" or null displays "Unlisted"', (tester) async {
      final card = createTestCard(
        id: 'tier6-card',
        name: 'Totally Unlisted Card',
        prices: {
          'usd': '0.00',
          'usd_foil': '0.00',
          'usd_etched': null,
          'eur': '0.00',
          'eur_foil': null,
        },
      );

      // VaultItemTile
      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Unlisted'), findsOneWidget);
      expect(find.text('Check'), findsNothing);

      // VaultItemCard
      await tester.pumpWidget(wrapWithPricingHarness(
        VaultItemCard(item: card, persona: UserPersona.investor),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Unlisted'), findsOneWidget);
      expect(find.text('Market Check'), findsNothing);

      // CardDetailSheet
      await tester.pumpWidget(wrapWithPricingHarness(
        CardDetailSheet(item: card),
        db: db,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Market: Unlisted'), findsOneWidget);
      expect(find.text('Market: Check'), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 4: ADVERSARIAL & BOUNDARY CASES
  // ===========================================================================
  group('Widget Tests: Adversarial & Corrupted Metadata Resiliency', () {
    testWidgets('W4.1: Corrupted or non-JSON dynamicData safely renders "Unlisted"', (tester) async {
      final card = createTestCard(
        id: 'adv-corrupted',
        name: 'Corrupted Dynamic Data Card',
        extraDynamicData: {},
      ).copyWith(dynamicData: 'MALFORMED_JSON_STRING');

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Unlisted'), findsOneWidget);
      expect(find.text('Check'), findsNothing);
    });

    testWidgets('W4.2: Direct SQLite currentMarketPrice overrides dynamicData prices', (tester) async {
      final card = createTestCard(
        id: 'adv-direct-sqlite',
        name: 'Direct SQLite Price Precedence Card',
        currentMarketPrice: 88.00,
        prices: {'usd': '10.00'}, // dynamicData has $10, but SQLite column has $88
      );

      await tester.pumpWidget(wrapWithPricingHarness(
        SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('\$88.00'), findsOneWidget);
    });
  });
}

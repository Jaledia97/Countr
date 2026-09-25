// =============================================================================
// TEST SUITE: test/m4_empirical_adversarial_stress_test.dart
// Empirical Adversarial Stress & Verification Harness for Milestone 4
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_totals.dart';
import 'package:countr/features/values/domain/services/deck_values_calculator.dart';
import 'package:countr/features/values/domain/pareto_analytics_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ===========================================================================
  // GROUP 1: DeckItemWithCard Empirical Stress Tests
  // ===========================================================================
  group('1. DeckItemWithCard Empirical Stress Tests', () {
    test('1.1 Map indexing, containsKey, and MapView interface contract', () {
      final rawMap = <String, dynamic>{
        'dvi_id': 'dvi-101',
        'version_id': 'ver-500',
        'vault_item_id': 'vault-999',
        'deck_quantity': 3,
        'board_zone': 'Sideboard',
        'is_proxy': 0,
        'id': 'vault-999',
        'name': 'Force of Will',
        'set_or_series': 'EMA',
        'image_url': 'https://example.com/fow.png',
        'dynamic_data': '{"prices":{"usd":"85.00"}}',
        'current_market_price': 85.0,
        'vault_quantity': 4,
        'is_graded': 0,
        'condition': 'NM',
        'acquired_price': 70.0,
        'purchase_price': 75.0,
        'acquired_date': '2026-01-15T00:00:00.000Z',
        'date_obtained': '2026-02-01T00:00:00.000Z',
        'notes': 'Pack pulled and sleeved',
        'protection_status': 'Double-Sleeved',
        'custom_extra_key': 'special_value_42',
        'card_id': 'scryfall-guid-1234',
      };

      final item = DeckItemWithCard.fromRow(rawMap);

      // Map indexing verification
      expect(item['dvi_id'], equals('dvi-101'));
      expect(item['version_id'], equals('ver-500'));
      expect(item['vault_item_id'], equals('vault-999'));
      expect(item['deck_quantity'], equals(3));
      expect(item['board_zone'], equals('Sideboard'));
      expect(item['is_proxy'], equals(0));
      expect(item['name'], equals('Force of Will'));
      expect(item['set_or_series'], equals('EMA'));
      expect(item['current_market_price'], equals(85.0));
      expect(item['purchase_price'], equals(75.0));
      expect(item['acquired_price'], equals(70.0));
      expect(item['protection_status'], equals('Double-Sleeved'));
      expect(item['notes'], equals('Pack pulled and sleeved'));

      // Preserved non-standard fields
      expect(item['custom_extra_key'], equals('special_value_42'));
      expect(item['card_id'], equals('scryfall-guid-1234'));

      // containsKey verification
      expect(item.containsKey('name'), isTrue);
      expect(item.containsKey('purchase_price'), isTrue);
      expect(item.containsKey('acquired_price'), isTrue);
      expect(item.containsKey('custom_extra_key'), isTrue);
      expect(item.containsKey('card_id'), isTrue);
      expect(item.containsKey('non_existent_key_xyz'), isFalse);

      // MapView collection invariants
      expect(item.keys, contains('custom_extra_key'));
      expect(item.values, contains(75.0));
      expect(item.isNotEmpty, isTrue);
      expect(item.length, greaterThanOrEqualTo(15));
    });

    test('1.2 Typed getters, cost basis precedence, and financial calculations', () {
      // Purchase price precedence over acquired price
      final itemBothPrices = DeckItemWithCard.fromRow({
        'name': 'Underground Sea',
        'deck_quantity': 2,
        'current_market_price': 800.0,
        'purchase_price': 650.0,
        'acquired_price': 400.0,
      });

      expect(itemBothPrices.effectiveCostBasis, equals(650.0));
      expect(itemBothPrices.lineCostBasis, equals(1300.0));
      expect(itemBothPrices.lineMarketValue(AppCurrency.usd), equals(1600.0));

      // Acquired price fallback when purchase_price is null
      final itemAcquiredOnly = DeckItemWithCard.fromRow({
        'name': 'Volcanic Island',
        'deck_quantity': 1,
        'current_market_price': 700.0,
        'purchase_price': null,
        'acquired_price': 550.0,
      });

      expect(itemAcquiredOnly.effectiveCostBasis, equals(550.0));
      expect(itemAcquiredOnly.lineCostBasis, equals(550.0));

      // Zero fallback when both prices are null or missing
      final itemNoPrices = DeckItemWithCard.fromRow({
        'name': 'Basic Island',
        'deck_quantity': 10,
        'current_market_price': 0.5,
      });

      expect(itemNoPrices.effectiveCostBasis, equals(0.0));
      expect(itemNoPrices.lineCostBasis, equals(0.0));
    });

    test('1.3 Null safety & malformed row defense', () {
      // Empty map
      final emptyItem = DeckItemWithCard.fromRow({});
      expect(emptyItem.id, equals(''));
      expect(emptyItem.name, equals('Unknown Card'));
      expect(emptyItem.setOrSeries, equals('MTG'));
      expect(emptyItem.deckQuantity, equals(1));
      expect(emptyItem.vaultQuantity, equals(1));
      expect(emptyItem.currentMarketPrice, equals(0.0));
      expect(emptyItem.acquiredPrice, equals(0.0));
      expect(emptyItem.purchasePrice, isNull);
      expect(emptyItem.effectiveCostBasis, equals(0.0));
      expect(emptyItem.boardZone, equals('Mainboard'));
      expect(emptyItem.isProxy, isFalse);
      expect(emptyItem.protectionStatus, equals('Sleeved'));

      // All null fields
      final nullFieldsItem = DeckItemWithCard.fromRow({
        'dvi_id': null,
        'version_id': null,
        'vault_item_id': null,
        'deck_quantity': null,
        'board_zone': null,
        'is_proxy': null,
        'id': null,
        'name': null,
        'set_or_series': null,
        'image_url': null,
        'dynamic_data': null,
        'current_market_price': null,
        'vault_quantity': null,
        'is_graded': null,
        'condition': null,
        'acquired_price': null,
        'purchase_price': null,
        'acquired_date': null,
        'date_obtained': null,
        'notes': null,
        'protection_status': null,
      });

      expect(nullFieldsItem.name, equals('Unknown Card'));
      expect(nullFieldsItem.effectiveCostBasis, equals(0.0));
      expect(nullFieldsItem.resolveMarketPrice(AppCurrency.usd), equals(0.0));

      // Corrupted numeric / date formats
      final corruptTypesItem = DeckItemWithCard.fromRow({
        'name': 'Fuzzed Card',
        'deck_quantity': 4,
        'acquired_price': double.nan,
        'purchase_price': -99.0,
        'acquired_date': 1704067200000, // Unix epoch ms
        'date_obtained': '2026-03-10',
        'dynamic_data': 'CORRUPT_JSON_DATA{{{',
      });

      // purchasePrice is negative, acquiredPrice is NaN -> effectiveCostBasis must sanitize to 0.0
      expect(corruptTypesItem.effectiveCostBasis, equals(0.0));
      expect(corruptTypesItem.acquiredDate, isNotNull);
      expect(corruptTypesItem.dateObtained, isNotNull);
      // Malformed dynamicData does not throw during market price resolution
      expect(corruptTypesItem.resolveMarketPrice(AppCurrency.usd), equals(0.0));
    });

    test('1.4 toVaultItem() DataClass conversion roundtrip', () {
      final dateObt = DateTime(2026, 2, 14);
      final acqDate = DateTime(2026, 1, 1);
      final item = DeckItemWithCard.fromRow({
        'id': 'v-888',
        'collection_type': 'mtg',
        'name': 'Mox Opal',
        'set_or_series': 'SOM',
        'image_url': 'https://example.com/mox_opal.png',
        'current_market_price': 115.0,
        'quantity': 2,
        'vault_quantity': 2,
        'condition': 'LP',
        'is_graded': 1,
        'is_altered': 0,
        'is_misprint': 0,
        'is_signed': 1,
        'acquired_price': 80.0,
        'purchase_price': 95.0,
        'acquired_date': acqDate,
        'date_obtained': dateObt,
        'binder_page': 4,
        'binder_slot': 'B2',
        'notes': 'Signed by artist',
        'protection_status': 'Toploader',
        'dynamic_data': '{"prices":{"usd":"115.00"}}',
      });

      final vaultItem = item.toVaultItem();

      expect(vaultItem.id, equals('v-888'));
      expect(vaultItem.name, equals('Mox Opal'));
      expect(vaultItem.setOrSeries, equals('SOM'));
      expect(vaultItem.currentMarketPrice, equals(115.0));
      expect(vaultItem.acquiredPrice, equals(80.0));
      expect(vaultItem.purchasePrice, equals(95.0));
      expect(vaultItem.dateObtained, equals(dateObt));
      expect(vaultItem.binderPage, equals(4));
      expect(vaultItem.binderSlot, equals('B2'));
      expect(vaultItem.notes, equals('Signed by artist'));
      expect(vaultItem.protectionStatus, equals('Toploader'));
      expect(vaultItem.isSigned, isTrue);
      expect(vaultItem.isGraded, isTrue);

      // Calling toVaultItem on empty item succeeds defensively without exception
      final emptyVaultItem = DeckItemWithCard.fromRow({}).toVaultItem();
      expect(emptyVaultItem.name, equals('Unknown Card'));
      expect(emptyVaultItem.protectionStatus, equals('Sleeved'));
    });
  });

  // ===========================================================================
  // GROUP 2: VaultDao SQL Totals Cost Basis Calculation
  // ===========================================================================
  group('2. VaultDao SQL Totals Cost Basis Calculation', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      // Clear auto-seeded items to test exact permutations from a clean slate
      await db.delete(db.vaultItems).go();
    });

    tearDown(() async {
      await db.close();
    });

    VaultItemsCompanion buildItem({
      required String id,
      required String name,
      int quantity = 1,
      double marketPrice = 10.0,
      double? purchasePrice,
      double acquiredPrice = 0.0,
      String? binderId,
    }) {
      return VaultItemsCompanion.insert(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'Test Set',
        imageUrl: 'https://example.com/$id.png',
        acquiredPrice: acquiredPrice,
        acquiredDate: DateTime(2026, 1, 1),
        quantity: drift.Value(quantity),
        condition: 'NM',
        currentMarketPrice: marketPrice,
        lastPriceUpdate: DateTime(2026, 1, 1),
        dynamicData: '{}',
        purchasePrice: purchasePrice != null
            ? drift.Value(purchasePrice)
            : const drift.Value.absent(),
        primaryBinderId: binderId != null
            ? drift.Value(binderId)
            : const drift.Value.absent(),
      );
    }

    test('2.1 SQL Totals: Only purchase_price present', () async {
      // purchase_price = 45.0, acquired_price = 0.0 (default), qty = 2 -> Cost basis = 90.0
      await db.into(db.vaultItems).insert(
        buildItem(
          id: 'card-1',
          name: 'Purchase Only',
          quantity: 2,
          marketPrice: 60.0,
          purchasePrice: 45.0,
          acquiredPrice: 0.0,
        ),
      );

      final totals = await dao.getVaultTotals();
      expect(totals.totalCount, equals(2));
      expect(totals.uniqueCount, equals(1));
      expect(totals.totalMarketValue, equals(120.0));
      expect(totals.totalCostBasis, equals(90.0));
      expect(totals.totalProfitLoss, equals(30.0));
      expect(totals.profitLossPercentage, closeTo((30.0 / 90.0) * 100, 0.001));
    });

    test('2.2 SQL Totals: Only acquired_price present (legacy item)', () async {
      // purchase_price = null, acquired_price = 30.0, qty = 3 -> Cost basis = 90.0
      await db.into(db.vaultItems).insert(
        buildItem(
          id: 'card-2',
          name: 'Acquired Only',
          quantity: 3,
          marketPrice: 50.0,
          purchasePrice: null,
          acquiredPrice: 30.0,
        ),
      );

      final totals = await dao.getVaultTotals();
      expect(totals.totalCount, equals(3));
      expect(totals.totalMarketValue, equals(150.0));
      expect(totals.totalCostBasis, equals(90.0));
      expect(totals.totalProfitLoss, equals(60.0));
      expect(totals.profitLossPercentage, closeTo((60.0 / 90.0) * 100, 0.001));
    });

    test('2.3 SQL Totals: Both purchase_price and acquired_price present (precedence test)', () async {
      // purchase_price = 50.0, acquired_price = 20.0, qty = 2 -> Cost basis = 100.0 (COALESCE takes purchase_price)
      await db.into(db.vaultItems).insert(
        buildItem(
          id: 'card-3',
          name: 'Both Prices',
          quantity: 2,
          marketPrice: 80.0,
          purchasePrice: 50.0,
          acquiredPrice: 20.0,
        ),
      );

      final totals = await dao.getVaultTotals();
      expect(totals.totalCostBasis, equals(100.0));
      expect(totals.totalMarketValue, equals(160.0));
      expect(totals.totalProfitLoss, equals(60.0));
    });

    test('2.4 SQL Totals: Neither present (cost basis 0.0, division-by-zero defense)', () async {
      // purchase_price = null, acquired_price = 0.0, qty = 4 -> Cost basis = 0.0
      await db.into(db.vaultItems).insert(
        buildItem(
          id: 'card-4',
          name: 'Free Card',
          quantity: 4,
          marketPrice: 25.0,
          purchasePrice: null,
          acquiredPrice: 0.0,
        ),
      );

      final totals = await dao.getVaultTotals();
      expect(totals.totalCount, equals(4));
      expect(totals.totalMarketValue, equals(100.0));
      expect(totals.totalCostBasis, equals(0.0));
      expect(totals.totalProfitLoss, equals(100.0));
      // Division-by-zero defense check:
      expect(totals.profitLossPercentage, equals(0.0));
      expect(totals.profitLossPercentage.isNaN, isFalse);
      expect(totals.profitLossPercentage.isInfinite, isFalse);
    });

    test('2.5 SQL Totals: Mixed batch across all 4 cost basis permutations in watchVaultTotals', () async {
      // 1. Purchase only: qty 2, purchase 10.0 -> cost 20.0, market 30.0
      await db.into(db.vaultItems).insert(
        buildItem(id: 'mix-1', name: 'Mix 1', quantity: 2, marketPrice: 15.0, purchasePrice: 10.0, acquiredPrice: 0.0),
      );
      // 2. Acquired only: qty 3, acquired 15.0 -> cost 45.0, market 60.0
      await db.into(db.vaultItems).insert(
        buildItem(id: 'mix-2', name: 'Mix 2', quantity: 3, marketPrice: 20.0, purchasePrice: null, acquiredPrice: 15.0),
      );
      // 3. Both: qty 1, purchase 40.0, acquired 5.0 -> cost 40.0, market 50.0
      await db.into(db.vaultItems).insert(
        buildItem(id: 'mix-3', name: 'Mix 3', quantity: 1, marketPrice: 50.0, purchasePrice: 40.0, acquiredPrice: 5.0),
      );
      // 4. Neither: qty 4, purchase null, acquired 0.0 -> cost 0.0, market 20.0
      await db.into(db.vaultItems).insert(
        buildItem(id: 'mix-4', name: 'Mix 4', quantity: 4, marketPrice: 5.0, purchasePrice: null, acquiredPrice: 0.0),
      );
      // 5. INBOX binder item (must be excluded from default vault totals)
      await db.into(db.vaultItems).insert(
        buildItem(id: 'inbox-1', name: 'Inbox Item', quantity: 10, marketPrice: 100.0, purchasePrice: 80.0, binderId: 'INBOX'),
      );
      // 6. Zero quantity item (must be excluded)
      await db.into(db.vaultItems).insert(
        buildItem(id: 'zero-1', name: 'Zero Qty', quantity: 0, marketPrice: 100.0, purchasePrice: 50.0),
      );

      final streamTotals = await dao.watchVaultTotals().first;

      // Expected included: mix-1 (2), mix-2 (3), mix-3 (1), mix-4 (4) = 10 cards, 4 unique
      expect(streamTotals.totalCount, equals(10));
      expect(streamTotals.uniqueCount, equals(4));

      // Expected cost basis: 20 + 45 + 40 + 0 = 105.0
      expect(streamTotals.totalCostBasis, equals(105.0));

      // Expected market value: 30 + 60 + 50 + 20 = 160.0
      expect(streamTotals.totalMarketValue, equals(160.0));

      // Profit/Loss: 160 - 105 = 55.0
      expect(streamTotals.totalProfitLoss, equals(55.0));
      expect(streamTotals.profitLossPercentage, closeTo((55.0 / 105.0) * 100, 0.001));
    });
  });

  // ===========================================================================
  // GROUP 3: DeckValuesCalculator Empirical Stress Tests
  // ===========================================================================
  group('3. DeckValuesCalculator Empirical Stress Tests', () {
    test('3.1 Division-by-zero defense: cost basis 0.0 and negative cost basis', () {
      final freeCards = [
        DeckItemWithCard.fromRow({
          'name': 'Gift Card 1',
          'deck_quantity': 1,
          'current_market_price': 50.0,
          'purchase_price': null,
          'acquired_price': 0.0,
        }),
        DeckItemWithCard.fromRow({
          'name': 'Gift Card 2',
          'deck_quantity': 2,
          'current_market_price': 25.0,
          'purchase_price': 0.0,
          'acquired_price': 0.0,
        }),
      ];

      final summary = DeckValuesCalculator.calculate(
        deckId: 'deck-free',
        items: freeCards,
        currency: AppCurrency.usd,
      );

      expect(summary.totalMarketValue, equals(100.0));
      expect(summary.totalCostBasis, equals(0.0));
      expect(summary.dollarReturn, equals(100.0));
      expect(summary.percentageReturn, equals(0.0));
      expect(summary.percentageReturn.isNaN, isFalse);
      expect(summary.percentageReturn.isInfinite, isFalse);

      // Corrupted items with negative cost basis
      final negativeCostCards = [
        DeckItemWithCard.fromRow({
          'name': 'Corrupt Cost',
          'deck_quantity': 1,
          'current_market_price': 30.0,
          'purchase_price': -50.0,
          'acquired_price': -10.0,
        }),
      ];

      final summaryNeg = DeckValuesCalculator.calculate(
        deckId: 'deck-neg',
        items: negativeCostCards,
        currency: AppCurrency.usd,
      );

      expect(summaryNeg.totalCostBasis, equals(0.0));
      expect(summaryNeg.percentageReturn, equals(0.0));
      expect(summaryNeg.percentageReturn.isNaN, isFalse);
      expect(summaryNeg.percentageReturn.isInfinite, isFalse);
    });

    test('3.2 Boundary deck card counts: 0, 1, 2, 3, 4, 5, 10 items', () {
      // 0 items
      final zeroSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-0',
        items: [],
        currency: AppCurrency.usd,
      );
      expect(zeroSummary.uniqueCardCount, equals(0));
      expect(zeroSummary.totalCardCount, equals(0));
      expect(zeroSummary.totalMarketValue, equals(0.0));
      expect(zeroSummary.totalCostBasis, equals(0.0));
      expect(zeroSummary.dollarReturn, equals(0.0));
      expect(zeroSummary.percentageReturn, equals(0.0));
      expect(zeroSummary.paretoConcentration, equals(0.0));
      expect(zeroSummary.heavyHitters, isEmpty);
      expect(zeroSummary.paretoHeadline, equals('No cards in deck to calculate concentration.'));

      // 1 item
      final oneSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-1',
        items: [
          DeckItemWithCard.fromRow({'name': 'Solo', 'deck_quantity': 1, 'current_market_price': 100.0}),
        ],
        currency: AppCurrency.usd,
      );
      expect(oneSummary.uniqueCardCount, equals(1));
      expect(oneSummary.heavyHitters.length, equals(1));
      expect(oneSummary.paretoConcentration, equals(100.0));
      expect(oneSummary.paretoHeadline, equals("The top card represents 100.0% of this deck's total value."));

      // 2 items
      final twoSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-2',
        items: [
          DeckItemWithCard.fromRow({'name': 'C1', 'deck_quantity': 1, 'current_market_price': 60.0}),
          DeckItemWithCard.fromRow({'name': 'C2', 'deck_quantity': 1, 'current_market_price': 40.0}),
        ],
        currency: AppCurrency.usd,
      );
      expect(twoSummary.uniqueCardCount, equals(2));
      expect(twoSummary.heavyHitters.length, equals(2));
      expect(twoSummary.paretoConcentration, equals(100.0));
      expect(twoSummary.paretoHeadline, equals("The top 2 cards represent 100.0% of this deck's total value."));

      // 3 items
      final threeSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-3',
        items: [
          DeckItemWithCard.fromRow({'name': 'C1', 'deck_quantity': 1, 'current_market_price': 50.0}),
          DeckItemWithCard.fromRow({'name': 'C2', 'deck_quantity': 1, 'current_market_price': 30.0}),
          DeckItemWithCard.fromRow({'name': 'C3', 'deck_quantity': 1, 'current_market_price': 20.0}),
        ],
        currency: AppCurrency.usd,
      );
      expect(threeSummary.uniqueCardCount, equals(3));
      expect(threeSummary.heavyHitters.length, equals(3));
      expect(threeSummary.paretoConcentration, equals(100.0));
      expect(threeSummary.paretoHeadline, equals("The top 3 cards represent 100.0% of this deck's total value."));

      // 4 items
      final fourSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-4',
        items: [
          DeckItemWithCard.fromRow({'name': 'C1', 'deck_quantity': 1, 'current_market_price': 40.0}),
          DeckItemWithCard.fromRow({'name': 'C2', 'deck_quantity': 1, 'current_market_price': 30.0}),
          DeckItemWithCard.fromRow({'name': 'C3', 'deck_quantity': 1, 'current_market_price': 20.0}),
          DeckItemWithCard.fromRow({'name': 'C4', 'deck_quantity': 1, 'current_market_price': 10.0}),
        ],
        currency: AppCurrency.usd,
      );
      expect(fourSummary.uniqueCardCount, equals(4));
      expect(fourSummary.heavyHitters.length, equals(4));
      expect(fourSummary.paretoConcentration, equals(100.0));
      expect(fourSummary.paretoHeadline, equals("The top 4 cards represent 100.0% of this deck's total value."));

      // 10 items (k capped at 5)
      final tenItems = List.generate(
        10,
        (i) => DeckItemWithCard.fromRow({
          'name': 'Card ${i + 1}',
          'deck_quantity': 1,
          'current_market_price': (10 - i) * 10.0, // 100, 90, 80, 70, 60, 50, 40, 30, 20, 10 -> total 550
        }),
      );
      final tenSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-10',
        items: tenItems,
        currency: AppCurrency.usd,
      );
      expect(tenSummary.uniqueCardCount, equals(10));
      expect(tenSummary.heavyHitters.length, equals(5)); // capped at 5
      // Top 5 sum = 100 + 90 + 80 + 70 + 60 = 400.0
      // 400 / 550 = 72.7272%
      expect(tenSummary.paretoConcentration, closeTo(72.7, 0.1));
      expect(tenSummary.paretoHeadline, equals("The top 5 cards represent 72.7% of this deck's total value."));
    });

    test('3.3 Value distributions: all \$0.00, equal price, and extreme concentration', () {
      // All $0.00 price
      final zeroValCards = List.generate(
        6,
        (i) => DeckItemWithCard.fromRow({
          'name': 'Token $i',
          'deck_quantity': 2,
          'current_market_price': 0.0,
        }),
      );
      final zeroValSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-zero-val',
        items: zeroValCards,
        currency: AppCurrency.usd,
      );
      expect(zeroValSummary.totalMarketValue, equals(0.0));
      expect(zeroValSummary.paretoConcentration, equals(0.0));
      for (final h in zeroValSummary.heavyHitters) {
        expect(h.shareOfTotal, equals(0.0));
      }

      // Equal price: 5 cards, each $10.00
      final equalCards = List.generate(
        5,
        (i) => DeckItemWithCard.fromRow({
          'name': 'Equal Card $i',
          'deck_quantity': 1,
          'current_market_price': 10.0,
        }),
      );
      final equalSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-equal',
        items: equalCards,
        currency: AppCurrency.usd,
      );
      expect(equalSummary.totalMarketValue, equals(50.0));
      expect(equalSummary.paretoConcentration, equals(100.0));
      for (final h in equalSummary.heavyHitters) {
        expect(h.shareOfTotal, closeTo(20.0, 0.01));
      }

      // Extreme concentration: 1 card worth $1,000,000, 99 cards worth $0.01
      final extremeCards = <DeckItemWithCard>[
        DeckItemWithCard.fromRow({
          'name': 'Black Lotus Alpha',
          'deck_quantity': 1,
          'current_market_price': 1000000.0,
        }),
        ...List.generate(
          99,
          (i) => DeckItemWithCard.fromRow({
            'name': 'Penny Card $i',
            'deck_quantity': 1,
            'current_market_price': 0.01,
          }),
        ),
      ];
      final extremeSummary = DeckValuesCalculator.calculate(
        deckId: 'deck-extreme',
        items: extremeCards,
        currency: AppCurrency.usd,
      );
      expect(extremeSummary.heavyHitters.first.cardName, equals('Black Lotus Alpha'));
      expect(extremeSummary.heavyHitters.first.shareOfTotal, greaterThan(99.99));
    });

    test('3.4 Deterministic tie-breaking across identically valued lines', () {
      // 4 cards with line value = 20.00
      // 1. "Zendikar Resurgent": 2x $10 = $20
      // 2. "Avacyn, Angel of Hope": 1x $20 = $20
      // 3. "Mana Vault": 4x $5 = $20
      // 4. "avacyn, angel of hope" (lowercase): 1x $20 = $20
      final tiedCards = [
        DeckItemWithCard.fromRow({'id': '1', 'name': 'Zendikar Resurgent', 'deck_quantity': 2, 'current_market_price': 10.0}),
        DeckItemWithCard.fromRow({'id': '2', 'name': 'Avacyn, Angel of Hope', 'deck_quantity': 1, 'current_market_price': 20.0}),
        DeckItemWithCard.fromRow({'id': '3', 'name': 'Mana Vault', 'deck_quantity': 4, 'current_market_price': 5.0}),
        DeckItemWithCard.fromRow({'id': '4', 'name': 'Chrome Mox', 'deck_quantity': 1, 'current_market_price': 20.0}),
      ];

      final summary = DeckValuesCalculator.calculate(
        deckId: 'deck-tied',
        items: tiedCards,
        currency: AppCurrency.usd,
      );

      final hitters = summary.heavyHitters;
      // Invariant: all have equal lineValue
      for (final h in hitters) {
        expect(h.lineValue, equals(20.0));
      }

      // Secondary sort: case-insensitive name ascending
      // 'Avacyn, Angel of Hope' -> 'Chrome Mox' -> 'Mana Vault' -> 'Zendikar Resurgent'
      expect(hitters[0].cardName, equals('Avacyn, Angel of Hope'));
      expect(hitters[1].cardName, equals('Chrome Mox'));
      expect(hitters[2].cardName, equals('Mana Vault'));
      expect(hitters[3].cardName, equals('Zendikar Resurgent'));
    });
  });

  // ===========================================================================
  // GROUP 4: ParetoDistributionCalculator & ParetoAnalyticsCalculator
  // ===========================================================================
  group('4. ParetoDistributionCalculator & ParetoAnalyticsCalculator', () {
    test('4.1 Property invariant testing: weights in [0, 1], concentration in [0, 100]', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Card A', unitPrice: 150.0, quantity: 2),
        const ParetoCardInput(id: '2', name: 'Card B', unitPrice: 50.0, quantity: 1),
        const ParetoCardInput(id: '3', name: 'Card C', unitPrice: 25.0, quantity: 4),
        const ParetoCardInput(id: '4', name: 'Card D', unitPrice: 0.0, quantity: 1),
        const ParetoCardInput(id: '5', name: 'Card E', unitPrice: -10.0, quantity: 2), // negative price
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 5);

      // Card A: 300.0, Card B: 50.0, Card C: 100.0, Card D: 0.0, Card E: sanitized to 0.0
      // Total deck value = 450.0
      expect(result.totalDeckValue, equals(450.0));
      expect(result.concentrationPercentage, greaterThanOrEqualTo(0.0));
      expect(result.concentrationPercentage, lessThanOrEqualTo(100.0));

      for (final item in result.topCards) {
        expect(item.weightRatio, greaterThanOrEqualTo(0.0));
        expect(item.weightRatio, lessThanOrEqualTo(1.0));
        expect(item.percentageShare, greaterThanOrEqualTo(0.0));
        expect(item.percentageShare, lessThanOrEqualTo(100.0));
      }

      // Strictly descending order by line value
      for (int i = 0; i < result.topCards.length - 1; i++) {
        expect(
          result.topCards[i].lineValue >= result.topCards[i + 1].lineValue,
          isTrue,
        );
      }
    });

    test('4.2 Privacy mode headline formatting on ParetoDistributionResult', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Mox Diamond', unitPrice: 650.0, quantity: 1),
        const ParetoCardInput(id: '2', name: 'Mana Crypt', unitPrice: 180.0, quantity: 1),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 2);

      // Non-privacy headline
      final normalHeadline = result.getHeadline(isPrivacyMode: false);
      expect(normalHeadline, equals("The top 2 cards represent 100.0% of this deck's total value."));

      // Privacy headline
      final privacyHeadline = result.getHeadline(isPrivacyMode: true);
      expect(privacyHeadline, equals("The top 2 cards represent **** of this deck's total value."));

      // Empty result headline
      final emptyResult = ParetoDistributionResult.empty();
      expect(
        emptyResult.getHeadline(isPrivacyMode: false),
        equals('No cards in deck to calculate concentration.'),
      );
      expect(
        emptyResult.getHeadline(isPrivacyMode: true),
        equals('No cards in deck to calculate concentration.'),
      );
    });

    test('4.3 ParetoAnalyticsCalculator compatibility layer verification', () {
      final values = [500.0, 300.0, 200.0, double.nan, -10.0, 0.0];
      final concentration = ParetoAnalyticsCalculator.computeConcentration(
        itemLineValues: values,
        topK: 2,
      );

      // Sanitized values: 500.0, 300.0, 200.0 -> total = 1000.0
      // Top 2: 500 + 300 = 800.0 -> 80.0%
      expect(concentration, equals(80.0));

      final headline = ParetoAnalyticsCalculator.generateHeadline(concentration, topK: 2);
      expect(headline, equals("The top 2 cards represent 80.0% of this deck's total value."));

      // Empty / invalid list
      final zeroConcentration = ParetoAnalyticsCalculator.computeConcentration(
        itemLineValues: [double.nan, -5.0, 0.0],
        topK: 5,
      );
      expect(zeroConcentration, equals(0.0));
    });
  });

  // ===========================================================================
  // GROUP 5: Advanced SQL & Stream Reactivity Stress Tests
  // ===========================================================================
  group('5. Advanced SQL & Stream Reactivity Stress Tests', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await db.delete(db.vaultItems).go();
      await db.delete(db.deckVersionItems).go();
      await db.delete(db.deckVersions).go();
      await db.delete(db.decks).go();
    });

    tearDown(() async {
      await db.close();
    });

    test('5.1 Real-time mutation stream reactivity on watchVaultTotals', () async {
      final emissions = <VaultTotals>[];
      final sub = dao.watchVaultTotals().listen(emissions.add);

      // Initial clean state emission
      await pumpEventQueue(times: 20);
      expect(emissions.isNotEmpty, isTrue);
      expect(emissions.last.totalCount, equals(0));

      // 1. Insert item: qty = 1, purchase = 50.0, market = 100.0
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'reactive-card-1',
              collectionType: 'mtg',
              name: 'Reactive Card',
              setOrSeries: 'M21',
              imageUrl: '',
              acquiredPrice: 30.0,
              acquiredDate: DateTime(2026, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 100.0,
              lastPriceUpdate: DateTime(2026, 1, 1),
              dynamicData: '{}',
              purchasePrice: const drift.Value(50.0),
            ),
          );

      await pumpEventQueue(times: 20);
      expect(emissions.last.totalCount, equals(1));
      expect(emissions.last.totalCostBasis, equals(50.0));
      expect(emissions.last.totalMarketValue, equals(100.0));

      // 2. Update quantity from 1 to 3
      await (db.update(db.vaultItems)..where((t) => t.id.equals('reactive-card-1'))).write(
        const VaultItemsCompanion(quantity: drift.Value(3)),
      );

      await pumpEventQueue(times: 20);
      expect(emissions.last.totalCount, equals(3));
      expect(emissions.last.totalCostBasis, equals(150.0));
      expect(emissions.last.totalMarketValue, equals(300.0));

      // 3. Update purchase_price from 50.0 to 70.0
      await (db.update(db.vaultItems)..where((t) => t.id.equals('reactive-card-1'))).write(
        const VaultItemsCompanion(purchasePrice: drift.Value(70.0)),
      );

      await pumpEventQueue(times: 20);
      expect(emissions.last.totalCostBasis, equals(210.0)); // 3 * 70.0
      expect(emissions.last.totalProfitLoss, equals(90.0)); // 300 - 210

      // 4. Move card to binder 'INBOX' -> must immediately drop to 0
      await (db.update(db.vaultItems)..where((t) => t.id.equals('reactive-card-1'))).write(
        const VaultItemsCompanion(primaryBinderId: drift.Value('INBOX')),
      );

      await pumpEventQueue(times: 20);
      expect(emissions.last.totalCount, equals(0));
      expect(emissions.last.totalCostBasis, equals(0.0));
      expect(emissions.last.totalMarketValue, equals(0.0));

      await sub.cancel();
    });

    test('5.2 watchDeckItems(deckId) query join, version filtering, and typed model output', () async {
      final now = DateTime.now();

      // Create deck
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck-alpha',
              name: 'Alpha Commander',
              format: 'Commander',
              createdAt: now,
            ),
          );

      // Create active version and inactive historical version
      await db.into(db.deckVersions).insert(
            DeckVersionsCompanion.insert(
              id: 'ver-active',
              deckId: 'deck-alpha',
              versionNumber: 2,
              isActive: const drift.Value(true),
              createdAt: now,
            ),
          );
      await db.into(db.deckVersions).insert(
            DeckVersionsCompanion.insert(
              id: 'ver-old',
              deckId: 'deck-alpha',
              versionNumber: 1,
              isActive: const drift.Value(false),
              createdAt: now.subtract(const Duration(days: 7)),
            ),
          );

      // Create vault items
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'vault-active-card',
              collectionType: 'mtg',
              name: 'Active Card',
              setOrSeries: 'MH3',
              imageUrl: 'https://example.com/act.png',
              acquiredPrice: 20.0,
              acquiredDate: now,
              quantity: const drift.Value(4),
              condition: 'NM',
              currentMarketPrice: 35.0,
              lastPriceUpdate: now,
              dynamicData: '{}',
              purchasePrice: const drift.Value(25.0),
              protectionStatus: const drift.Value('Double-Sleeved'),
            ),
          );
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'vault-old-card',
              collectionType: 'mtg',
              name: 'Old Version Card',
              setOrSeries: 'LEA',
              imageUrl: '',
              acquiredPrice: 500.0,
              acquiredDate: now,
              quantity: const drift.Value(1),
              condition: 'HP',
              currentMarketPrice: 1200.0,
              lastPriceUpdate: now,
              dynamicData: '{}',
            ),
          );

      // Link items: 1 in active version, 1 in old inactive version
      await db.into(db.deckVersionItems).insert(
            DeckVersionItemsCompanion.insert(
              id: 'dvi-active',
              versionId: 'ver-active',
              vaultItemId: 'vault-active-card',
              quantity: const drift.Value(2),
              boardZone: 'Mainboard',
              isProxy: const drift.Value(false),
            ),
          );
      await db.into(db.deckVersionItems).insert(
            DeckVersionItemsCompanion.insert(
              id: 'dvi-old',
              versionId: 'ver-old',
              vaultItemId: 'vault-old-card',
              quantity: const drift.Value(1),
              boardZone: 'Sideboard',
              isProxy: const drift.Value(false),
            ),
          );

      // Verify watchDeckItems emits ONLY active version item
      final items = await dao.watchDeckItems('deck-alpha').first;
      expect(items.length, equals(1));

      final activeItem = items.first;
      expect(activeItem, isA<DeckItemWithCard>());
      expect(activeItem.name, equals('Active Card'));
      expect(activeItem.deckQuantity, equals(2));
      expect(activeItem.boardZone, equals('Mainboard'));
      expect(activeItem.purchasePrice, equals(25.0));
      expect(activeItem.effectiveCostBasis, equals(25.0));
      expect(activeItem.lineCostBasis, equals(50.0));
      expect(activeItem.protectionStatus, equals('Double-Sleeved'));

      // Verify backward-compatible map indexing
      expect(activeItem['purchase_price'], equals(25.0));
      expect(activeItem['deck_quantity'], equals(2));
      expect(activeItem['board_zone'], equals('Mainboard'));
    });
  });

  // ===========================================================================
  // GROUP 6: Fuzzing, Corrupted Inputs, and Multi-Currency Oracles
  // ===========================================================================
  group('6. Fuzzing, Corrupted Inputs, and Multi-Currency Oracles', () {
    test('6.1 DeckValuesCalculator handles heterogeneous and corrupt item collections', () {
      final junkItems = <dynamic>[
        null,
        12345,
        'not_an_item',
        <String, dynamic>{'unrecognized_structure': true},
        DeckItemWithCard.fromRow({
          'name': 'Resilient Card',
          'deck_quantity': 2,
          'current_market_price': 15.0,
          'purchase_price': 10.0,
        }),
        null,
      ];

      final summary = DeckValuesCalculator.calculate(
        deckId: 'deck-fuzz',
        items: junkItems,
        currency: AppCurrency.usd,
      );

      expect(summary.uniqueCardCount, equals(2)); // The valid item + the fallback Map
      expect(summary.totalCardCount, greaterThanOrEqualTo(2));
      expect(summary.totalMarketValue, greaterThanOrEqualTo(30.0));
      expect(summary.totalCostBasis, greaterThanOrEqualTo(20.0));
    });

    test('6.2 Extreme Float values (NaN, +Infinity, -Infinity) sanitized to 0.0', () {
      final extremeItems = [
        DeckItemWithCard.fromRow({
          'name': 'Infinite Market',
          'deck_quantity': 1,
          'current_market_price': double.infinity,
          'purchase_price': double.nan,
        }),
        DeckItemWithCard.fromRow({
          'name': 'Infinite Cost',
          'deck_quantity': 1,
          'current_market_price': double.nan,
          'purchase_price': double.negativeInfinity,
        }),
      ];

      final summary = DeckValuesCalculator.calculate(
        deckId: 'deck-nan',
        items: extremeItems,
        currency: AppCurrency.usd,
      );

      expect(summary.totalMarketValue, equals(0.0));
      expect(summary.totalCostBasis, equals(0.0));
      expect(summary.dollarReturn, equals(0.0));
      expect(summary.percentageReturn, equals(0.0));
      expect(summary.paretoConcentration, equals(0.0));
    });

    test('6.3 Multi-currency conversion oracle across USD, EUR, GBP, CAD', () {
      final items = [
        DeckItemWithCard.fromRow({
          'name': 'Global Mana Crypt',
          'deck_quantity': 1,
          'current_market_price': 200.0, // $200 USD
          'purchase_price': 150.0,
        }),
      ];

      final usdSummary = DeckValuesCalculator.calculate(
        deckId: 'fx-deck',
        items: items,
        currency: AppCurrency.usd,
      );
      final eurSummary = DeckValuesCalculator.calculate(
        deckId: 'fx-deck',
        items: items,
        currency: AppCurrency.eur,
      );
      final gbpSummary = DeckValuesCalculator.calculate(
        deckId: 'fx-deck',
        items: items,
        currency: AppCurrency.gbp,
      );
      final cadSummary = DeckValuesCalculator.calculate(
        deckId: 'fx-deck',
        items: items,
        currency: AppCurrency.cad,
      );

      expect(usdSummary.totalMarketValue, equals(200.0));
      // Rates from ExchangeRateService: EUR ~0.92, GBP ~0.79, CAD ~1.36
      expect(eurSummary.totalMarketValue, closeTo(200.0 * 0.92, 1.0));
      expect(gbpSummary.totalMarketValue, closeTo(200.0 * 0.79, 1.0));
      expect(cadSummary.totalMarketValue, closeTo(200.0 * 1.36, 1.0));
    });

    test('6.4 ParetoDistributionCalculator tertiary tie-breaking (equal line value, equal name, different unit price)', () {
      final cards = [
        const ParetoCardInput(
          id: '1',
          name: 'Sol Ring',
          unitPrice: 1.0,
          quantity: 100, // line value = 100.0
        ),
        const ParetoCardInput(
          id: '2',
          name: 'Sol Ring',
          unitPrice: 100.0,
          quantity: 1, // line value = 100.0
        ),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 2);
      expect(result.topCards.length, equals(2));
      // Both have lineValue 100.0 and same name 'Sol Ring'.
      // Tertiary sort: unit price descending -> unitPrice 100.0 ranks first!
      expect(result.topCards[0].unitPrice, equals(100.0));
      expect(result.topCards[0].quantity, equals(1));
      expect(result.topCards[1].unitPrice, equals(1.0));
      expect(result.topCards[1].quantity, equals(100));
    });

    test('6.5 ParetoDistributionCalculator boundary targetK values (e.g. targetK <= 0)', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Card 1', unitPrice: 50.0, quantity: 1),
      ];

      final resultZeroK = ParetoDistributionCalculator.calculate(cards: cards, targetK: 0);
      expect(resultZeroK.topCards, isEmpty);
      expect(resultZeroK.topK, equals(0));
      expect(resultZeroK.concentrationPercentage, equals(0.0));

      // Negative targetK causes RangeError from ListBase.take()
      expect(
        () => ParetoDistributionCalculator.calculate(cards: cards, targetK: -3),
        throwsA(isA<RangeError>()),
      );
    });
  });
}


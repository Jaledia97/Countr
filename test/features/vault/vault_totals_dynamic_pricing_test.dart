import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 3: Dynamic Data Pricing Fallback & Finish Awareness', () {
    test('Falls back to dynamic_data.prices.usd when current_market_price is 0.0', () async {
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-fallback-usd',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'Commander',
              imageUrl: 'https://example.com/sol_ring.jpg',
              acquiredPrice: 1.50,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 0.0, // Unset market price
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'prices': {
                  'usd': '12.50',
                  'usd_foil': '25.00',
                },
              }),
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(1));
      expect(totals.totalMarketValue, equals(12.50));
    });

    test('Finish-aware pricing: etched finish selects usd_etched with fallback to foil and usd', () async {
      // 1. Etched card with dedicated usd_etched price
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-etched-full',
              collectionType: 'mtg',
              name: 'Mox Diamond Etched',
              setOrSeries: 'Vintage Masters',
              imageUrl: 'https://example.com/mox_etched.jpg',
              acquiredPrice: 50.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'etched',
                'prices': {
                  'usd': '10.00',
                  'usd_foil': '25.00',
                  'usd_etched': '45.00',
                },
              }),
            ),
          );

      // 2. Etched card lacking usd_etched -> falls back to usd_foil
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-etched-fallback-foil',
              collectionType: 'mtg',
              name: 'Etched Without Etched Price',
              setOrSeries: 'Vintage Masters',
              imageUrl: 'https://example.com/etched2.jpg',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'treatment': 'etched',
                'prices': {
                  'usd': '8.00',
                  'usd_foil': '22.00',
                },
              }),
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(2));
      // 45.00 + 22.00 = 67.00
      expect(totals.totalMarketValue, equals(67.00));
    });

    test('Finish-aware pricing: foil and surge finishes select correct variant pricing', () async {
      // 1. Traditional Foil
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-foil',
              collectionType: 'mtg',
              name: 'Foil Card',
              setOrSeries: 'Modern Horizons',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(2), // Multi-copy
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'foil',
                'prices': {
                  'usd': '10.00',
                  'usd_foil': '30.00',
                },
              }),
            ),
          );

      // 2. Surge Foil
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-surge',
              collectionType: 'mtg',
              name: 'Surge Card',
              setOrSeries: 'Warhammer 40k',
              imageUrl: '',
              acquiredPrice: 15.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'surge',
                'prices': {
                  'usd': '12.00',
                  'usd_surge': '55.00',
                  'usd_foil': '35.00',
                },
              }),
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(3)); // 2 foil + 1 surge
      // (30.00 * 2) + 55.00 = 60.00 + 55.00 = 115.00
      expect(totals.totalMarketValue, equals(115.00));
    });

    test('EUR fallback when all USD prices are null or missing', () async {
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-eur-only',
              collectionType: 'mtg',
              name: 'European Card',
              setOrSeries: 'European Promos',
              imageUrl: '',
              acquiredPrice: 4.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(3),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'prices': {
                  'eur': '8.50',
                },
              }),
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(3));
      // 8.50 * 3 = 25.50
      expect(totals.totalMarketValue, equals(25.50));
    });

    test('Quantity multiplication scales market value and cost basis accurately', () async {
      // 4x playset with dedicated market price
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-playset',
              collectionType: 'mtg',
              name: 'Lightning Bolt 4x',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 5.00,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(4),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 20.00,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(4));
      expect(totals.uniqueCount, equals(1));
      expect(totals.totalMarketValue, equals(80.00)); // 20.00 * 4
      expect(totals.totalCostBasis, equals(20.00)); // 5.00 * 4
      expect(totals.totalProfitLoss, equals(60.00));
      expect(totals.profitLossPercentage, equals(300.0));
    });
  });

  group('Milestone 3: Looking For Binder Exclusion & Traded Cards', () {
    test('Strictly excludes Looking For binders from portfolio value and item counts', () async {
      // 1. Owned inventory item
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'owned-item',
              collectionType: 'mtg',
              name: 'Black Lotus',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 5000.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 10000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      // 2. Unowned item inside system Looking For binder
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'wishlist-item-1',
              collectionType: 'mtg',
              name: 'Timetwister Wishlist',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 4000.0,
              lastPriceUpdate: DateTime.now(),
              primaryBinderId: const drift.Value('system_looking_for'),
              dynamicData: '{}',
            ),
          );

      // 3. Unowned item inside sub-looking_for binder
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'wishlist-item-2',
              collectionType: 'mtg',
              name: 'Mox Ruby Wishlist',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 3500.0,
              lastPriceUpdate: DateTime.now(),
              primaryBinderId: const drift.Value('system_looking_for_sub_123'),
              dynamicData: '{}',
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      // Only the owned Black Lotus should be included
      expect(totals.totalCount, equals(1));
      expect(totals.totalMarketValue, equals(10000.0));
      expect(totals.totalCostBasis, equals(5000.0));
    });

    test('Strictly excludes traded cards (is_traded = 1)', () async {
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'traded-card',
              collectionType: 'mtg',
              name: 'Traded Away Card',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 50.0,
              lastPriceUpdate: DateTime.now(),
              isTraded: const drift.Value(true),
              dynamicData: '{}',
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(0));
      expect(totals.totalMarketValue, equals(0.0));
    });
  });

  group('Milestone 3: User Scoping Reactivity', () {
    test('User scoping correctly includes user-current-me and guest alongside unowned seeds', () async {
      // 1. Seed card with user_id = null
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'seed-card',
              collectionType: 'mtg',
              name: 'Seeded Starter Card',
              setOrSeries: 'Starter 1999',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 5.0,
              lastPriceUpdate: DateTime.now(),
              userId: const drift.Value(null),
              dynamicData: '{}',
            ),
          );

      // 2. Card added by user-current-me
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'me-card',
              collectionType: 'mtg',
              name: 'My Card',
              setOrSeries: 'Starter 1999',
              imageUrl: '',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 10.0,
              lastPriceUpdate: DateTime.now(),
              userId: const drift.Value('user-current-me'),
              dynamicData: '{}',
            ),
          );

      // Scoped to 'user-current-me'
      final meTotals = await dao.getVaultTotals(
        collectionType: 'mtg',
        userId: 'user-current-me',
      );
      expect(meTotals.totalCount, equals(2));
      expect(meTotals.totalMarketValue, equals(15.00));

      // Scoped to another authenticated user
      final otherTotals = await dao.getVaultTotals(
        collectionType: 'mtg',
        userId: 'user_auth_other_999',
      );
      // Includes seed-card (user_id IS NULL) but excludes me-card
      expect(otherTotals.totalCount, equals(1));
      expect(otherTotals.totalMarketValue, equals(5.00));
    });

    test('Live reactivity: watchVaultTotals emits new totals upon database insertion', () async {
      final stream = dao.watchVaultTotals(collectionType: 'mtg', userId: 'user-current-me');
      expectLater(
        stream.map((t) => t.totalMarketValue),
        emitsInOrder([
          0.0, // Initial empty
          35.0, // After inserting 35.0 item
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'reactive-card',
              collectionType: 'mtg',
              name: 'Reactive Card',
              setOrSeries: 'Kamigawa',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 35.0,
              lastPriceUpdate: DateTime.now(),
              userId: const drift.Value('user-current-me'),
              dynamicData: '{}',
            ),
          );

      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  group('Milestone 3: Fast Collections Set Summary (< 50ms) & Strictly-Scoped 3x3 Master Set View', () {
    test('watchSetSummaryList and getSetSummaryList return aggregated sets with completion metrics', () async {
      // Insert cards for set 'LTR' (Tales of Middle-earth)
      // 1. Owned card
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'ltr-card-1',
              collectionType: 'mtg',
              name: 'Frodo',
              setOrSeries: 'Tales of Middle-earth',
              imageUrl: 'https://example.com/frodo.jpg',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 8.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'ltr',
                'collector_number': '1',
                'released_at': '2023-06-23',
              }),
            ),
          );

      // 2. Unowned catalog card
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'ltr-card-2',
              collectionType: 'mtg',
              name: 'The One Ring',
              setOrSeries: 'Tales of Middle-earth',
              imageUrl: 'https://example.com/ring.jpg',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 100.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'ltr',
                'collector_number': '2',
                'released_at': '2023-06-23',
              }),
            ),
          );

      final stopwatch = Stopwatch()..start();
      final summaries = await dao.getSetSummaryList(collectionType: 'mtg');
      stopwatch.stop();

      // Verify < 50ms requirement
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(summaries.length, equals(1));

      final ltr = summaries.first;
      expect(ltr.setName, equals('Tales of Middle-earth'));
      expect(ltr.setCode, equals('LTR'));
      expect(ltr.totalCount, equals(2));
      expect(ltr.ownedCount, equals(1));
      expect(ltr.completionPercentage, equals(0.5));
    });

    test('watchItemsBySet with setCode parameter strictly scopes to selected set code and sorts by collector number', () async {
      final setName = 'The Lord of the Rings';

      // Insert LTR card (set_code: ltr, collector_number: 10)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'ltr-10',
              collectionType: 'mtg',
              name: 'Gondor Archer',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'ltr',
                'collector_number': '10',
              }),
            ),
          );

      // Insert LTR card (set_code: ltr, collector_number: 2)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'ltr-2',
              collectionType: 'mtg',
              name: 'Aragorn',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'ltr',
                'collector_number': '2',
              }),
            ),
          );

      // Insert LTC supplement card (set_code: ltc, same setOrSeries name!)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'ltc-1',
              collectionType: 'mtg',
              name: 'Gandalf Commander',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'ltc',
                'collector_number': '1',
              }),
            ),
          );

      // Query strictly scoped to 'ltr'
      final scopedItems = await dao
          .watchItemsBySet(
            setName,
            setCode: 'ltr',
            collectionType: 'mtg',
          )
          .first;

      // Must strictly contain ONLY the 2 LTR cards, NOT the LTC card!
      expect(scopedItems.length, equals(2));
      expect(scopedItems.any((c) => c.id == 'ltc-1'), isFalse);

      // Ordered numerically by collector number: 2 before 10!
      expect(scopedItems[0].id, equals('ltr-2'));
      expect(scopedItems[1].id, equals('ltr-10'));
    });

    test('VaultPricingHelper automatically infers finish from dynamicData JSON map', () {
      final dynamicDataFoil = jsonEncode({
        'finish': 'foil',
        'prices': {
          'usd': '5.00',
          'usd_foil': '18.00',
        },
      });

      final dynamicDataEtched = jsonEncode({
        'treatment': 'etched',
        'prices': {
          'usd': '5.00',
          'usd_foil': '18.00',
          'usd_etched': '35.00',
        },
      });

      // Without passing explicit finish parameter:
      final priceFoil = VaultPricingHelper.extractFromDynamicData(dynamicDataFoil);
      expect(priceFoil, equals(18.00));

      final priceEtched = VaultPricingHelper.extractFromDynamicData(dynamicDataEtched);
      expect(priceEtched, equals(35.00));
    });
  });
}

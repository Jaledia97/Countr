// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Empirical Stress Test Suite for Milestone 3 (Features 11–15).
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    VaultDao.invalidateSetMetadataCache();
    await dao.clearAllItems();
  });

  tearDown(() async {
    VaultDao.invalidateSetMetadataCache();
    await db.close();
  });

  group('CHALLENGER STRESS 1: SQLite Pricing Fallbacks & Finish Awareness', () {
    test('1.1 Etched finish price resolution and fallbacks', () async {
      // 1. Etched card with full pricing: must pick usd_etched ($55.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'etched-1',
              collectionType: 'mtg',
              name: 'Etched Full',
              setOrSeries: 'Double Masters',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'etched',
                'prices': {
                  'usd': '10.00',
                  'usd_foil': '25.00',
                  'usd_etched': '55.00',
                  'eur': '8.00',
                },
              }),
            ),
          );

      // 2. Etched card without usd_etched: must fallback to usd_foil ($30.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'etched-2',
              collectionType: 'mtg',
              name: 'Etched Foil Fallback',
              setOrSeries: 'Double Masters',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'treatment': 'etched',
                'prices': {
                  'usd': '12.00',
                  'usd_foil': '30.00',
                  'usd_etched': null,
                  'eur': '9.00',
                },
              }),
            ),
          );

      // 3. Etched card without usd_etched or usd_foil: must fallback to usd ($14.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'etched-3',
              collectionType: 'mtg',
              name: 'Etched USD Fallback',
              setOrSeries: 'Double Masters',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'etched',
                'prices': {
                  'usd': '14.00',
                  'eur': '11.00',
                },
              }),
            ),
          );

      // 4. Etched card with ONLY EUR prices: must fallback to eur_foil ($22.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'etched-4',
              collectionType: 'mtg',
              name: 'Etched EUR Foil Fallback',
              setOrSeries: 'Double Masters',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'etched',
                'prices': {
                  'usd': null,
                  'usd_foil': null,
                  'usd_etched': null,
                  'eur_foil': '22.00',
                  'eur': '15.00',
                },
              }),
            ),
          );

      // 5. Etched card with ONLY regular EUR: must fallback to eur ($18.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'etched-5',
              collectionType: 'mtg',
              name: 'Etched EUR Regular Fallback',
              setOrSeries: 'Double Masters',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'treatment': 'etched',
                'prices': {
                  'usd': null,
                  'eur': '18.00',
                },
              }),
            ),
          );

      // Expected total: 55 + 30 + 14 + 22 + 18 = 139.00
      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(5));
      expect(totals.totalMarketValue, closeTo(139.00, 0.001));
    });

    test('1.2 Foil and Surge finishes price resolution and fallbacks', () async {
      // 1. Foil card with usd_foil: must pick usd_foil ($40.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'foil-1',
              collectionType: 'mtg',
              name: 'Foil Card',
              setOrSeries: 'Innistrad',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'foil',
                'prices': {
                  'usd': '10.00',
                  'usd_foil': '40.00',
                  'usd_etched': '50.00',
                },
              }),
            ),
          );

      // 2. Foil card without usd_foil: must fallback to usd_etched ($35.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'foil-2',
              collectionType: 'mtg',
              name: 'Foil Etched Fallback',
              setOrSeries: 'Innistrad',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'foil',
                'prices': {
                  'usd': '10.00',
                  'usd_foil': null,
                  'usd_etched': '35.00',
                },
              }),
            ),
          );

      // 3. Surge finish card: must pick usd_surge ($120.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'surge-1',
              collectionType: 'mtg',
              name: 'Surge Card',
              setOrSeries: 'Warhammer 40k',
              imageUrl: '',
              acquiredPrice: 20.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'surge',
                'prices': {
                  'usd': '15.00',
                  'usd_foil': '50.00',
                  'usd_surge': '120.00',
                },
              }),
            ),
          );

      // 4. Surgefoil finish card without usd_surge: falls back to usd_foil ($45.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'surge-2',
              collectionType: 'mtg',
              name: 'Surgefoil Card Fallback',
              setOrSeries: 'Warhammer 40k',
              imageUrl: '',
              acquiredPrice: 20.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'treatment': 'surgefoil',
                'prices': {
                  'usd': '12.00',
                  'usd_foil': '45.00',
                  'usd_surge': null,
                },
              }),
            ),
          );

      // Expected total: 40 + 35 + 120 + 45 = 240.00
      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(4));
      expect(totals.totalMarketValue, closeTo(240.00, 0.001));
    });

    test('1.3 Nonfoil finish with EUR currency fallback when USD is null or missing', () async {
      // 1. Nonfoil card with both USD and EUR: picks USD ($16.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'nf-1',
              collectionType: 'mtg',
              name: 'Regular Dual Currency',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'nonfoil',
                'prices': {
                  'usd': '16.00',
                  'eur': '14.00',
                },
              }),
            ),
          );

      // 2. Nonfoil card with null USD: falls back to EUR ($11.50)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'nf-2',
              collectionType: 'mtg',
              name: 'Regular EUR Fallback',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'nonfoil',
                'prices': {
                  'usd': null,
                  'eur': '11.50',
                },
              }),
            ),
          );

      // 3. Card with default finish (no finish key) and null USD: falls back to EUR ($7.25)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'nf-3',
              collectionType: 'mtg',
              name: 'Default Finish EUR Fallback',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 2.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'prices': {
                  'eur': '7.25',
                },
              }),
            ),
          );

      // Expected total: 16.00 + 11.50 + 7.25 = 34.75
      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(3));
      expect(totals.totalMarketValue, closeTo(34.75, 0.001));
    });

    test('1.4 Precedence of positive currentMarketPrice over dynamicData prices', () async {
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'override-1',
              collectionType: 'mtg',
              name: 'Price Override Card',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 85.00, // Explicit market price overrides JSON
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'prices': {
                  'usd': '10.00',
                  'usd_foil': '20.00',
                },
              }),
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(1));
      expect(totals.totalMarketValue, equals(85.00));
    });
  });

  group('CHALLENGER STRESS 2: Quantity Scaling Across Finishes & Quantities', () {
    test('2.1 Quantity scaling with quantity = 4', () async {
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'playset-1',
              collectionType: 'mtg',
              name: 'Lightning Bolt 4x',
              setOrSeries: 'M11',
              imageUrl: '',
              acquiredPrice: 2.50, // Cost basis = 4 * 2.50 = 10.00
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(4),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'foil',
                'prices': {
                  'usd': '3.00',
                  'usd_foil': '12.50', // Unit price = 12.50; 4 * 12.50 = 50.00
                },
              }),
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(4));
      expect(totals.uniqueCount, equals(1));
      expect(totals.totalMarketValue, closeTo(50.00, 0.001));
      expect(totals.totalCostBasis, closeTo(10.00, 0.001));
      expect(totals.totalProfitLoss, closeTo(40.00, 0.001));
    });

    test('2.2 Zero quantity cards are strictly excluded from totals', () async {
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'zero-qty-1',
              collectionType: 'mtg',
              name: 'Catalog Reference Only',
              setOrSeries: 'M11',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(0), // Quantity is zero
              condition: 'NM',
              currentMarketPrice: 100.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'prices': {'usd': '100.00'},
              }),
            ),
          );

      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(0));
      expect(totals.totalMarketValue, equals(0.0));
    });

    test('2.3 Multiple items with varying quantities (1x, 3x, 10x)', () async {
      // Item A: 1x @ $25.00
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'multi-a',
              collectionType: 'mtg',
              name: 'Item A',
              setOrSeries: 'Set 1',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 25.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      // Item B: 3x @ $15.00 via dynamicData EUR fallback = $45.00
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'multi-b',
              collectionType: 'mtg',
              name: 'Item B',
              setOrSeries: 'Set 1',
              imageUrl: '',
              acquiredPrice: 5.0, // 3 * 5 = 15 cost basis
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(3),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'prices': {'eur': '15.00'},
              }),
            ),
          );

      // Item C: 10x @ $2.00 via dynamicData etched fallback = $20.00
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'multi-c',
              collectionType: 'mtg',
              name: 'Item C',
              setOrSeries: 'Set 1',
              imageUrl: '',
              acquiredPrice: 1.0, // 10 * 1 = 10 cost basis
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(10),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'finish': 'etched',
                'prices': {'usd_etched': '2.00'},
              }),
            ),
          );

      // Total count = 1 + 3 + 10 = 14
      // Unique count = 3
      // Total market value = 25 + 45 + 20 = 90.00
      // Total cost basis = 10 + 15 + 10 = 35.00
      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(14));
      expect(totals.uniqueCount, equals(3));
      expect(totals.totalMarketValue, closeTo(90.00, 0.001));
      expect(totals.totalCostBasis, closeTo(35.00, 0.001));
    });
  });

  group('CHALLENGER STRESS 3: Looking For Binder & State Exclusion', () {
    test('3.1 Cards in system_looking_for and custom looking_for binders are excluded', () async {
      // 1. Regular owned card in trade binder ($50.00)
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'owned-trade-1',
              collectionType: 'mtg',
              name: 'Black Lotus Trade',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 20.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 50.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: const drift.Value('system_trade_block_me'),
            ),
          );

      // 2. Looking For card in system_looking_for_me ($500.00) -> MUST BE EXCLUDED
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lf-system-1',
              collectionType: 'mtg',
              name: 'Mox Ruby Wishlist',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 500.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: const drift.Value('system_looking_for_me'),
            ),
          );

      // 3. Register custom binder with systemBinderType = 'looking_for'
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'custom_wl_binder_99',
              name: 'My Custom Wishlist',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
              systemBinderType: const drift.Value('looking_for'),
              isSystemBinder: const drift.Value(false),
            ),
          );

      // 4. Card in custom looking_for binder ($800.00) -> MUST BE EXCLUDED
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lf-custom-1',
              collectionType: 'mtg',
              name: 'Time Walk Custom Wishlist',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 800.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: const drift.Value('custom_wl_binder_99'),
            ),
          );

      // 5. Card with isTraded = true ($200.00) -> MUST BE EXCLUDED
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'traded-card-1',
              collectionType: 'mtg',
              name: 'Traded Card',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 50.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 200.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              isTraded: const drift.Value(true),
            ),
          );

      // 6. Card with isDeleted = true ($300.00) -> MUST BE EXCLUDED
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'deleted-card-1',
              collectionType: 'mtg',
              name: 'Deleted Card',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 50.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 300.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              isDeleted: const drift.Value(true),
            ),
          );

      // Verify getVaultTotals: only the $50.00 owned card should count!
      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(1));
      expect(totals.totalMarketValue, equals(50.00));

      // Verify watchVaultTotals stream also emits only $50.00
      final streamTotals = await dao.watchVaultTotals(collectionType: 'mtg').first;
      expect(streamTotals.totalCount, equals(1));
      expect(streamTotals.totalMarketValue, equals(50.00));
    });
  });

  group('CHALLENGER STRESS 4: Strict Set Code Isolation', () {
    test('4.1 Cards from LTC do NOT leak into watchItemsBySet for LTR', () async {
      const setName = 'The Lord of the Rings: Tales of Middle-earth';

      // Insert 6 cards: 3 with set_code 'ltr', 2 with set_code 'ltc', 1 with 'pltr'
      final cards = [
        {
          'id': 'ltr-001',
          'name': 'Frodo, Sauron\'s Bane',
          'set_code': 'ltr',
          'collector_number': '18',
        },
        {
          'id': 'ltr-002',
          'name': 'The One Ring',
          'set_code': 'ltr',
          'collector_number': '246',
        },
        {
          'id': 'ltr-003',
          'name': 'Mount Doom',
          'set_code': 'ltr',
          'collector_number': '258',
        },
        {
          'id': 'ltc-001',
          'name': 'Sol Ring (Commander)',
          'set_code': 'ltc', // LTC Commander card!
          'collector_number': '1',
        },
        {
          'id': 'ltc-002',
          'name': 'Aragorn, King of Gondor',
          'set_code': 'ltc', // LTC Commander card!
          'collector_number': '5',
        },
        {
          'id': 'pltr-001',
          'name': 'Frodo Promo',
          'set_code': 'pltr', // Promo set code with ltr suffix!
          'collector_number': '1',
        },
        {
          'id': 'ltc-adversarial',
          'name': 'LTC Adversarial Note',
          'set_code': 'ltc',
          'collector_number': '99',
          'notes': 'Trade this for ltr cards like "set_code":"ltr"',
        },
      ];

      for (final c in cards) {
        final dynamicMap = <String, dynamic>{
          'set_code': c['set_code'],
          'collector_number': c['collector_number'],
        };
        if (c['notes'] != null) {
          dynamicMap['notes'] = c['notes'];
        }

        await dao.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: c['id']!,
                collectionType: 'mtg',
                name: c['name']!,
                setOrSeries: setName,
                imageUrl: '',
                acquiredPrice: 1.0,
                acquiredDate: DateTime(2023, 6, 23),
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 5.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode(dynamicMap),
              ),
            );
      }

      // Query specifically with setCode: 'LTR'
      final ltrItems = await dao.watchItemsBySet(setName, setCode: 'LTR').first;

      // Must have exactly 3 items: Frodo (18), The One Ring (246), Mount Doom (258)
      expect(ltrItems.length, equals(3), reason: 'LTC and PLTR cards must NOT appear in LTR query');
      expect(ltrItems.map((i) => i.id).toList(), equals(['ltr-001', 'ltr-002', 'ltr-003']));

      // Assert none of the LTC or PLTR cards are present
      final ltrIds = ltrItems.map((i) => i.id).toSet();
      expect(ltrIds.contains('ltc-001'), isFalse);
      expect(ltrIds.contains('ltc-002'), isFalse);
      expect(ltrIds.contains('pltr-001'), isFalse);
      expect(ltrIds.contains('ltc-adversarial'), isFalse);

      // Case-insensitivity check: lowercase 'ltr' must yield identical results
      final ltrLowerItems = await dao.watchItemsBySet(setName, setCode: 'ltr').first;
      expect(ltrLowerItems.length, equals(3));
      expect(ltrLowerItems.map((i) => i.id).toList(), equals(['ltr-001', 'ltr-002', 'ltr-003']));

      // Query specifically for 'LTC'
      final ltcItems = await dao.watchItemsBySet(setName, setCode: 'LTC').first;
      expect(ltcItems.length, equals(3));
      expect(ltcItems.map((i) => i.id).toList(), containsAll(['ltc-001', 'ltc-002', 'ltc-adversarial']));
      expect(ltcItems.any((i) => i.id.startsWith('ltr-')), isFalse);
    });
  });

  group('CHALLENGER STRESS 5: Benchmark Set Summary Query Latency (< 50ms)', () {
    test('5.1 Query latency on populated database (50 sets, 2,500 catalog items, 200 owned)', () async {
      // 1. Populate database: 50 sets with 50 cards each (2,500 catalog cards)
      // 20 of these sets contain 10 owned cards each (200 owned cards total)
      final batch = <VaultItemsCompanion>[];

      for (int s = 0; s < 50; s++) {
        final setCode = 'SET${s.toString().padLeft(2, '0')}';
        final setName = 'Magic Set $s ($setCode)';
        final isOwnedSet = s < 20;

        for (int c = 1; c <= 50; c++) {
          final isOwned = isOwnedSet && c <= 10;
          final cardId = 'card_${setCode}_$c';

          batch.add(
            VaultItemsCompanion.insert(
              id: cardId,
              collectionType: 'mtg',
              name: 'Card $c of $setName',
              setOrSeries: setName,
              imageUrl: 'https://example.com/$cardId.jpg',
              acquiredPrice: isOwned ? 1.50 : 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: drift.Value(isOwned ? 2 : 0), // 2 owned or 0 catalog
              condition: 'NM',
              currentMarketPrice: isOwned ? 5.00 : 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': setCode,
                'collector_number': c.toString(),
                'released_at': '2023-0${(s % 9) + 1}-01',
              }),
            ),
          );
        }
      }

      await db.batch((b) {
        b.insertAll(db.vaultItems, batch);
      });

      // 2. Cold Start: primes the static metadata cache
      final coldStopwatch = Stopwatch()..start();
      final coldResult = await dao.watchSetCollections(collectionType: 'mtg').first;
      coldStopwatch.stop();
      final coldLatencyMs = coldStopwatch.elapsedMilliseconds;

      expect(coldResult.length, equals(50));
      // First set should have 50 total cards and 10 owned cards
      final set0 = coldResult.firstWhere((r) => r.setCode == 'SET00');
      expect(set0.totalCount, equals(50));
      expect(set0.ownedCount, equals(10));
      expect(set0.completionPercentage, closeTo(0.20, 0.01));

      // 3. Hot Benchmark: Run 10 iterations measuring cached execution latency
      final hotLatencies = <int>[];
      for (int i = 0; i < 10; i++) {
        final sw = Stopwatch()..start();
        final list = await dao.watchSetCollections(collectionType: 'mtg').first;
        sw.stop();
        hotLatencies.add(sw.elapsedMilliseconds);
        expect(list.length, equals(50));
      }

      // Also benchmark getSetSummaryList()
      for (int i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        final list = await dao.getSetSummaryList(collectionType: 'mtg');
        sw.stop();
        hotLatencies.add(sw.elapsedMilliseconds);
        expect(list.length, equals(50));
      }

      final maxLatency = hotLatencies.reduce((a, b) => a > b ? a : b);
      final avgLatency = hotLatencies.reduce((a, b) => a + b) / hotLatencies.length;
      // ignore: avoid_print
      print('BENCHMARK 5.1 RESULTS: Cold latency: ${coldLatencyMs}ms, Max cached latency: ${maxLatency}ms, Avg cached latency: ${avgLatency.toStringAsFixed(2)}ms, Latencies: $hotLatencies');

      // EMPIRICAL ASSERTION: Execution latency MUST be strictly < 50ms
      expect(
        maxLatency,
        lessThan(50),
        reason: 'Max cached set summary query latency was $maxLatency ms (exceeded 50ms requirement). Latencies: $hotLatencies',
      );
      expect(
        avgLatency,
        lessThan(25),
        reason: 'Average cached latency was $avgLatency ms',
      );
    });

    test('5.2 Reactive update latency when adding a card to an existing set', () async {
      // Seed a baseline set
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'reactive-card-0',
              collectionType: 'mtg',
              name: 'Seed Card',
              setOrSeries: 'Reactive Test Set',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0), // catalog only
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'RTS',
                'collector_number': '1',
              }),
            ),
          );

      // Prime cache
      await dao.watchSetCollections(collectionType: 'mtg').first;

      final sw = Stopwatch()..start();
      // Insert new owned card
      await dao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'reactive-card-1',
              collectionType: 'mtg',
              name: 'New Owned Card',
              setOrSeries: 'Reactive Test Set',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1), // owned
              condition: 'NM',
              currentMarketPrice: 10.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'RTS',
                'collector_number': '2',
              }),
            ),
          );

      final updatedSets = await dao.watchSetCollections(collectionType: 'mtg').first;
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(50));
      final rts = updatedSets.firstWhere((s) => s.setCode == 'RTS');
      expect(rts.ownedCount, equals(1));
    });

    test('5.3 Extreme Scale Stress Test: 100 sets, 10,000 items in SQLite', () async {
      VaultDao.invalidateSetMetadataCache();
      await dao.clearAllItems();

      final batch = <VaultItemsCompanion>[];
      for (int s = 0; s < 100; s++) {
        final setCode = 'EXT${s.toString().padLeft(3, '0')}';
        final setName = 'Extreme Set $s ($setCode)';
        for (int c = 1; c <= 100; c++) {
          final isOwned = c <= 10; // 10 owned per set = 1,000 owned cards total
          batch.add(
            VaultItemsCompanion.insert(
              id: 'card_${setCode}_$c',
              collectionType: 'mtg',
              name: 'Card $c of $setName',
              setOrSeries: setName,
              imageUrl: 'https://example.com/card.jpg',
              acquiredPrice: isOwned ? 2.0 : 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: drift.Value(isOwned ? 1 : 0),
              condition: 'NM',
              currentMarketPrice: isOwned ? 4.0 : 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': setCode,
                'collector_number': c.toString(),
                'released_at': '2023-05-01',
              }),
            ),
          );
        }
      }

      await db.batch((b) {
        b.insertAll(db.vaultItems, batch);
      });

      // Cold start with 10,000 rows
      final coldSw = Stopwatch()..start();
      final coldList = await dao.watchSetCollections(collectionType: 'mtg').first;
      coldSw.stop();

      expect(coldList.length, equals(100));

      // Hot queries on 10,000 rows
      final hotLatencies = <int>[];
      for (int i = 0; i < 10; i++) {
        final hotSw = Stopwatch()..start();
        final list = await dao.getSetSummaryList(collectionType: 'mtg');
        hotSw.stop();
        hotLatencies.add(hotSw.elapsedMilliseconds);
        expect(list.length, equals(100));
      }

      final maxHot = hotLatencies.reduce((a, b) => a > b ? a : b);
      final avgHot = hotLatencies.reduce((a, b) => a + b) / hotLatencies.length;
      final sorted = List<int>.from(hotLatencies)..sort();
      final p90 = sorted[(sorted.length * 0.9).floor()];
      // ignore: avoid_print
      print('EXTREME BENCHMARK (10k rows): Cold latency: ${coldSw.elapsedMilliseconds}ms, Max hot: ${maxHot}ms, P90: ${p90}ms, Avg hot: ${avgHot.toStringAsFixed(2)}ms, Latencies: $hotLatencies');

      expect(avgHot, lessThan(50), reason: 'Average cached latency on 10,000 rows was $avgHot ms (target < 50ms)');
      expect(p90, lessThan(50), reason: '90th percentile cached latency on 10,000 rows was $p90 ms (target < 50ms)');
    });
  });
}

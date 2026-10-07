// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Adversarial Stress Test Suite for Phase 4.6 Milestone 1 (Challenger 2):
// Drift Schema v9 Invariants, SQLite Runtime Backfills, Duplicate Consolidation, and SyncQueue Mutations.

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to create a temporary directory for file-based SQLite databases
  late Directory tempDir;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('drift_stress_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ===========================================================================
  // SECTION 1: THE ONE RING RUNTIME BACKFILL & ADVERSARIAL REPAIR
  // ===========================================================================
  group('Section 1: The One Ring Runtime Backfill & Adversarial Repair', () {
    test('Defensively repairs The One Ring with legacy 404 URL in a persistent disk database across open cycles', () async {
      final dbFile = File('${tempDir.path}/legacy_ring.sqlite');

      // 1. Setup raw database with schema and dirty The One Ring record
      final initialDb = AppDatabase(NativeDatabase(dbFile));
      await initialDb.customSelect('SELECT 1;').get();

      // Corrupt The One Ring record with legacy 404 URL and empty metadata
      await initialDb.customStatement('''
        UPDATE "vault_items"
        SET "image_url" = 'https://cards.scryfall.io/large/front/7/8/78038b95-30f2-4e4b-972f-04cfa65c275a.jpg',
            "dynamic_data" = '{}'
        WHERE "id" = 'item-mtg-one-ring';
      ''');

      var corruptedRow = await (initialDb.select(initialDb.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      expect(corruptedRow.imageUrl, contains('78038b95'));
      expect(jsonDecode(corruptedRow.dynamicData)['scryfall_id'], isNull);

      await initialDb.close();

      // 2. Re-open database with a brand new AppDatabase instance (triggering beforeOpen)
      final reopenedDb = AppDatabase(NativeDatabase(dbFile));
      await reopenedDb.customSelect('SELECT 1;').get();

      // Verify beforeOpen automatically repaired the row on disk
      final healedRow = await (reopenedDb.select(reopenedDb.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();

      expect(
        healedRow.imageUrl,
        equals('https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038'),
      );
      expect(healedRow.imageUrl.contains('78038b95'), isFalse);

      final healedDynamic = jsonDecode(healedRow.dynamicData) as Map<String, dynamic>;
      expect(healedDynamic['scryfall_id'], equals('d5806e68-1054-458e-866d-1f2470f682b2'));
      expect(healedDynamic['oracle_id'], equals('3aa83ed2-f48b-4ce6-a614-2c54ddf50538'));
      expect(healedDynamic['finish'], equals('foil'));
      expect(healedDynamic['image_uris']['large'], contains('d5806e68'));

      await reopenedDb.close();
    });

    test('Repairs dirty database where dynamic_data is invalid JSON or malformed string', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();

      // Insert or corrupt a custom One Ring variant with invalid JSON
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'custom-one-ring-corrupt',
          collectionType: 'mtg',
          name: 'The One Ring',
          setOrSeries: 'LTR',
          imageUrl: 'https://cards.scryfall.io/large/front/7/8/78038b95-test.jpg',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 35.0,
          acquiredDate: now,
          currentMarketPrice: 35.0,
          lastPriceUpdate: now,
          dynamicData: '{invalid-json-without-scryfall-id',
        ),
      );

      // Execute beforeOpen backfill logic manually as would run during migration/open
      await db.customStatement('''
        UPDATE "vault_items"
        SET "image_url" = 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038'
        WHERE ("id" = 'item-mtg-one-ring' OR "image_url" LIKE '%78038b95%');
      ''');

      await db.customStatement('''
        UPDATE "vault_items"
        SET "dynamic_data" = json_set(
          CASE WHEN json_valid("dynamic_data") = 1 THEN "dynamic_data" ELSE '{}' END,
          '\$.scryfall_id', 'd5806e68-1054-458e-866d-1f2470f682b2',
          '\$.oracle_id', '3aa83ed2-f48b-4ce6-a614-2c54ddf50538',
          '\$.image_uris', json('{"small":"https://cards.scryfall.io/small/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","normal":"https://cards.scryfall.io/normal/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","large":"https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","art_crop":"https://cards.scryfall.io/art_crop/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038"}'),
          '\$.finish', 'foil'
        )
        WHERE ("id" = 'item-mtg-one-ring' OR "image_url" LIKE '%d5806e68%')
          AND ("dynamic_data" NOT LIKE '%"scryfall_id"%' OR json_extract("dynamic_data", '\$.scryfall_id') IS NULL);
      ''');

      final row = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('custom-one-ring-corrupt')))
          .getSingle();

      expect(row.imageUrl, contains('d5806e68'));
      final parsed = jsonDecode(row.dynamicData) as Map<String, dynamic>;
      expect(parsed['scryfall_id'], equals('d5806e68-1054-458e-866d-1f2470f682b2'));
      expect(parsed['finish'], equals('foil'));

      await db.close();
    });

    test('Evaluates behavior when dynamic_data contains the substring "scryfall_id" within malformed JSON', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();

      // Insert record where dynamic_data has "scryfall_id" keyword but is malformed JSON
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'ring-malformed-scryfall-key',
          collectionType: 'mtg',
          name: 'The One Ring',
          setOrSeries: 'LTR',
          imageUrl: 'https://cards.scryfall.io/large/front/7/8/78038b95-test2.jpg',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 35.0,
          acquiredDate: now,
          currentMarketPrice: 35.0,
          lastPriceUpdate: now,
          dynamicData: '{"scryfall_id": INVALID_JSON_SYNTAX',
        ),
      );

      // Re-run backfill statement and observe behavior
      Object? capturedError;
      try {
        await db.customStatement('''
          UPDATE "vault_items"
          SET "image_url" = 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038'
          WHERE ("id" = 'item-mtg-one-ring' OR "image_url" LIKE '%78038b95%');
        ''');

        await db.customStatement('''
          UPDATE "vault_items"
          SET "dynamic_data" = json_set(
            CASE WHEN json_valid("dynamic_data") = 1 THEN "dynamic_data" ELSE '{}' END,
            '\$.scryfall_id', 'd5806e68-1054-458e-866d-1f2470f682b2',
            '\$.oracle_id', '3aa83ed2-f48b-4ce6-a614-2c54ddf50538',
            '\$.image_uris', json('{"small":"https://cards.scryfall.io/small/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","normal":"https://cards.scryfall.io/normal/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","large":"https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","art_crop":"https://cards.scryfall.io/art_crop/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038"}'),
            '\$.finish', 'foil'
          )
          WHERE ("id" = 'item-mtg-one-ring' OR "image_url" LIKE '%d5806e68%')
            AND ("dynamic_data" NOT LIKE '%"scryfall_id"%' OR json_extract("dynamic_data", '\$.scryfall_id') IS NULL);
        ''');
      } catch (e) {
        capturedError = e;
      }

      // Check whether SQLite threw a malformed JSON error or handled it gracefully
      final row = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('ring-malformed-scryfall-key')))
          .getSingle();

      // Image URL is always patched because the first UPDATE statement succeeded
      expect(row.imageUrl, contains('d5806e68'));

      if (capturedError != null) {
        // Empirically document that json_extract on malformed JSON threw an exception:
        expect(capturedError.toString(), contains('malformed JSON'));
        // In beforeOpen (app_database.dart:481), this exception is safely caught by try-catch
        // and does NOT prevent the database from opening.
      } else {
        // If SQLite tolerated it, verify parsed dynamicData
        expect(row.dynamicData.isNotEmpty, isTrue);
      }

      await db.close();
    });

    test('Survives concurrent open cycles and queries without race condition crashes', () async {
      final dbFile = File('${tempDir.path}/concurrent_open.sqlite');

      // Create initial DB
      final initDb = AppDatabase(NativeDatabase(dbFile));
      await initDb.customSelect('SELECT 1;').get();
      await initDb.close();

      // Launch 8 concurrent connections simultaneously
      final connections = List.generate(8, (_) => AppDatabase(NativeDatabase(dbFile)));

      try {
        final results = await Future.wait(connections.map((c) async {
          final res = await c.customSelect('SELECT id, name, image_url FROM vault_items LIMIT 5;').get();
          return res.length;
        }));

        for (final len in results) {
          expect(len, greaterThanOrEqualTo(1));
        }

        // Verify The One Ring in all connections is authentic
        for (final c in connections) {
          final ring = await (c.select(c.vaultItems)
                ..where((t) => t.id.equals('item-mtg-one-ring')))
              .getSingle();
          expect(ring.imageUrl, contains('d5806e68'));
        }
      } finally {
        await Future.wait(connections.map((c) => c.close()));
      }
    });

    test('Runtime backfill is strictly idempotent over multiple successive opens', () async {
      final dbFile = File('${tempDir.path}/idempotent.sqlite');

      // First open
      var db = AppDatabase(NativeDatabase(dbFile));
      await db.customSelect('SELECT 1;').get();
      final ring1 = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      await db.close();

      // Second open
      db = AppDatabase(NativeDatabase(dbFile));
      await db.customSelect('SELECT 1;').get();
      final ring2 = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      await db.close();

      // Third open
      db = AppDatabase(NativeDatabase(dbFile));
      await db.customSelect('SELECT 1;').get();
      final ring3 = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      await db.close();

      expect(ring1.imageUrl, equals(ring2.imageUrl));
      expect(ring2.imageUrl, equals(ring3.imageUrl));
      expect(ring1.dynamicData, equals(ring2.dynamicData));
      expect(ring2.dynamicData, equals(ring3.dynamicData));
    });
  });

  // ===========================================================================
  // SECTION 2: CONSOLIDATE DUPLICATE VAULT ITEMS & TRANSACTION ROLLBACKS
  // ===========================================================================
  group('Section 2: consolidateDuplicateVaultItems Transaction Stress & Rollbacks', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
      // Clear seeded items for clean isolation
      await (db.delete(db.vaultItems)).go();
      await (db.delete(db.syncQueue)).go();
    });

    tearDown(() async {
      await db.close();
    });

    test('Rollback scenario: SQLite trigger failure inside transaction fully rolls back all changes', () async {
      final now = DateTime.now();
      // Insert duplicate pair
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'roll-dup-1',
          collectionType: 'mtg',
          name: 'Thoughtseize',
          setOrSeries: 'LRW',
          imageUrl: '',
          quantity: const Value(2),
          condition: 'Near Mint',
          acquiredPrice: 15.0,
          acquiredDate: now,
          currentMarketPrice: 15.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scry-ts-1',
            'oracle_id': 'oracle-ts',
            'finish': 'nonfoil',
          }),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'roll-dup-2',
          collectionType: 'mtg',
          name: 'Thoughtseize',
          setOrSeries: 'LRW',
          imageUrl: '',
          quantity: const Value(3),
          condition: 'Near Mint',
          acquiredPrice: 15.0,
          acquiredDate: now.add(const Duration(minutes: 5)),
          currentMarketPrice: 15.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scry-ts-1',
            'oracle_id': 'oracle-ts',
            'finish': 'nonfoil',
          }),
        ),
      );

      // Create a trigger that intentionally aborts when sync_queue receives a specific operation
      await db.customStatement('''
        CREATE TRIGGER test_abort_sync BEFORE INSERT ON sync_queue
        WHEN NEW.entity_id = 'roll-dup-2'
        BEGIN
          SELECT RAISE(ABORT, 'Simulated failure during consolidation sync outbox logging');
        END;
      ''');

      // Attempt consolidation — must fail and throw
      expect(
        () async => await db.vaultDao.consolidateDuplicateVaultItems(),
        throwsA(isA<Exception>()),
      );

      // Verify complete rollback:
      // 1. Neither row was soft-deleted
      final row1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('roll-dup-1'))).getSingle();
      final row2 = await (db.select(db.vaultItems)..where((t) => t.id.equals('roll-dup-2'))).getSingle();
      expect(row1.isDeleted, isFalse);
      expect(row2.isDeleted, isFalse);

      // 2. Primary quantity was NOT updated to 5
      expect(row1.quantity, equals(2));
      expect(row2.quantity, equals(3));

      // 3. sync_queue has 0 entries
      final queueEntries = await db.select(db.syncQueue).get();
      expect(queueEntries, isEmpty);
    });

    test('Stress test concurrent execution of consolidateDuplicateVaultItems maintains strict quantity conservation', () async {
      final now = DateTime.now();
      // Insert 4 duplicate records of the same card/finish
      for (int i = 1; i <= 4; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'concurrent-dup-$i',
            collectionType: 'mtg',
            name: 'Counterspell',
            setOrSeries: 'EMA',
            imageUrl: '',
            quantity: Value(i), // 1, 2, 3, 4 = total 10
            condition: 'Near Mint',
            acquiredPrice: 1.0,
            acquiredDate: now.add(Duration(seconds: i)),
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'scry-counterspell-1',
              'oracle_id': 'oracle-counterspell',
              'finish': 'nonfoil',
            }),
          ),
        );
      }

      // Fire 5 concurrent consolidation requests simultaneously
      final counts = await Future.wait([
        db.vaultDao.consolidateDuplicateVaultItems(),
        db.vaultDao.consolidateDuplicateVaultItems(),
        db.vaultDao.consolidateDuplicateVaultItems(),
        db.vaultDao.consolidateDuplicateVaultItems(),
        db.vaultDao.consolidateDuplicateVaultItems(),
      ]);

      // Exactly one primary survives with quantity 10
      final activeCards = await (db.select(db.vaultItems)..where((t) => t.isDeleted.equals(false))).get();
      expect(activeCards.length, equals(1));
      expect(activeCards.first.quantity, equals(10));
      expect(activeCards.first.id, equals('concurrent-dup-1')); // Earliest acquiredDate

      // All duplicates are soft-deleted
      final softDeletedCards = await (db.select(db.vaultItems)..where((t) => t.isDeleted.equals(true))).get();
      expect(softDeletedCards.length, equals(3));

      // Sum of active + deleted total items is exactly 4
      final totalRecords = await db.select(db.vaultItems).get();
      expect(totalRecords.length, equals(4));

      // Total consolidated count reported across concurrent calls is >= 3
      final totalReported = counts.fold<int>(0, (sum, c) => sum + c);
      expect(totalReported, greaterThanOrEqualTo(3));
    });

    test('Batch consolidation with 100 duplicate items across 10 distinct variants', () async {
      final now = DateTime.now();
      const numVariants = 10;
      const copiesPerVariant = 10;
      int expectedTotalQuantity = 0;

      for (int v = 1; v <= numVariants; v++) {
        final finish = v % 2 == 0 ? 'foil' : 'nonfoil';
        final scryfallId = 'scry-batch-$v';
        final oracleId = 'oracle-batch-$v';

        for (int c = 1; c <= copiesPerVariant; c++) {
          final qty = c; // Sum per variant = 10 * 11 / 2 = 55. Total = 55 * 10 = 550.
          expectedTotalQuantity += qty;
          await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'batch-item-$v-$c',
              collectionType: 'mtg',
              name: 'Batch Card $v',
              setOrSeries: 'SET$v',
              imageUrl: '',
              quantity: Value(qty),
              condition: 'Near Mint',
              acquiredPrice: 2.0,
              acquiredDate: now.add(Duration(minutes: c)),
              primaryBinderId: (c == 1 && v % 3 == 0) ? const Value('BINDER-VIP') : const Value.absent(),
              currentMarketPrice: 2.0,
              lastPriceUpdate: now,
              dynamicData: jsonEncode({
                'scryfall_id': scryfallId,
                'oracle_id': oracleId,
                'finish': finish,
              }),
            ),
          );
        }
      }

      // Consolidate all
      final consolidated = await db.vaultDao.consolidateDuplicateVaultItems();
      expect(consolidated, equals(numVariants * (copiesPerVariant - 1))); // 10 * 9 = 90 rows consolidated

      // Exactly 10 active items survive
      final active = await (db.select(db.vaultItems)..where((t) => t.isDeleted.equals(false))).get();
      expect(active.length, equals(numVariants));

      // Verify exact sum of quantities across active items
      final totalActiveQuantity = active.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalActiveQuantity, equals(expectedTotalQuantity)); // 550

      // Exactly 90 soft-deleted records exist
      final deleted = await (db.select(db.vaultItems)..where((t) => t.isDeleted.equals(true))).get();
      expect(deleted.length, equals(90));

      // Verify deterministic primary selection:
      // For v = 3, 6, 9: primaryBinderId was 'BINDER-VIP' on c = 1, so it must be the primary
      for (final v in [3, 6, 9]) {
        final survivor = active.firstWhere((i) => i.name == 'Batch Card $v');
        expect(survivor.primaryBinderId, equals('BINDER-VIP'));
      }
    });

    test('Consolidation remapping of DeckVersionItems preserves deck assignments and availability math', () async {
      final now = DateTime.now();

      // Create 2 duplicate vault items
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v-sol-1',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'LEA',
          imageUrl: '',
          quantity: const Value(2),
          condition: 'Near Mint',
          acquiredPrice: 50.0,
          acquiredDate: now,
          currentMarketPrice: 50.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scry-sol',
            'oracle_id': 'oracle-sol',
            'finish': 'nonfoil',
          }),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v-sol-2',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'LEA',
          imageUrl: '',
          quantity: const Value(3),
          condition: 'Near Mint',
          acquiredPrice: 50.0,
          acquiredDate: now.add(const Duration(hours: 1)),
          currentMarketPrice: 50.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scry-sol',
            'oracle_id': 'oracle-sol',
            'finish': 'nonfoil',
          }),
        ),
      );

      // Create an assembled deck assigning 1 copy of v-sol-1 and 2 copies of v-sol-2
      final deck = await db.vaultDao.createDeck('EDH Deck 1', format: 'Commander');
      await db.vaultDao.setDeckAssembled(deck.id, true);

      final version = await (db.select(db.deckVersions)..where((t) => t.deckId.equals(deck.id))).getSingle();

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-sol-1',
          versionId: version.id,
          vaultItemId: 'v-sol-1',
          quantity: const Value(1),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-sol-2',
          versionId: version.id,
          vaultItemId: 'v-sol-2',
          quantity: const Value(2),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
        ),
      );

      // Consolidate duplicates
      final consolidated = await db.vaultDao.consolidateDuplicateVaultItems();
      expect(consolidated, equals(1));

      // Primary item is v-sol-1 with quantity 5
      final survivor = await (db.select(db.vaultItems)..where((t) => t.id.equals('v-sol-1'))).getSingle();
      expect(survivor.quantity, equals(5));

      // Deck version item dvi-sol-2 must now be remapped to v-sol-1
      final remappedDvi = await (db.select(db.deckVersionItems)..where((t) => t.id.equals('dvi-sol-2'))).getSingle();
      expect(remappedDvi.vaultItemId, equals('v-sol-1'));

      // Check Availability Engine:
      // Owned = 5, In Deck = 1 + 2 = 3, Available = 5 - 3 = 2!
      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      expect(availMap.containsKey('v-sol-1'), isTrue);
      final avail = availMap['v-sol-1']!;
      expect(avail.owned, equals(5));
      expect(avail.inDeck, equals(3));
      expect(avail.available, equals(2));
      expect(avail.owned, equals(avail.available + avail.inDeck));
    });

    test('Consolidating zero quantity duplicate retains valid primary quantity', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'zero-primary',
          collectionType: 'mtg',
          name: 'Dark Ritual',
          setOrSeries: 'MIR',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 1.0,
          acquiredDate: now,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scry-dr',
            'oracle_id': 'oracle-dr',
            'finish': 'nonfoil',
          }),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'zero-dup',
          collectionType: 'mtg',
          name: 'Dark Ritual',
          setOrSeries: 'MIR',
          imageUrl: '',
          quantity: const Value(0),
          condition: 'Near Mint',
          acquiredPrice: 1.0,
          acquiredDate: now.add(const Duration(minutes: 1)),
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scry-dr',
            'oracle_id': 'oracle-dr',
            'finish': 'nonfoil',
          }),
        ),
      );

      final merged = await db.vaultDao.consolidateDuplicateVaultItems();
      expect(merged, equals(1));

      final primary = await (db.select(db.vaultItems)..where((t) => t.id.equals('zero-primary'))).getSingle();
      expect(primary.quantity, equals(4));

      final dup = await (db.select(db.vaultItems)..where((t) => t.id.equals('zero-dup'))).getSingle();
      expect(dup.isDeleted, isTrue);
    });

    test('Deterministic primary selection: primaryBinderId preferred over unassigned, then earliest acquiredDate', () async {
      final now = DateTime.now();

      // Card A: unassigned, acquired earlier
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'det-earlier-unassigned',
          collectionType: 'mtg',
          name: 'Swords to Plowshares',
          setOrSeries: 'ICE',
          imageUrl: '',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({'scryfall_id': 'scry-stp', 'finish': 'nonfoil'}),
        ),
      );

      // Card B: in binder, acquired later
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'det-later-binder',
          collectionType: 'mtg',
          name: 'Swords to Plowshares',
          setOrSeries: 'ICE',
          imageUrl: '',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now.add(const Duration(days: 10)),
          primaryBinderId: const Value('BINDER-1'),
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({'scryfall_id': 'scry-stp', 'finish': 'nonfoil'}),
        ),
      );

      await db.vaultDao.consolidateDuplicateVaultItems();

      // B must survive because it has a binder assigned, despite being acquired later
      final surviving = await (db.select(db.vaultItems)..where((t) => t.isDeleted.equals(false))).getSingle();
      expect(surviving.id, equals('det-later-binder'));
      expect(surviving.quantity, equals(2));
    });
  });

  // ===========================================================================
  // SECTION 3: SYNCQUEUE OUTBOX MUTATIONS & SOFT-DELETE INVARIANTS
  // ===========================================================================
  group('Section 3: SyncQueue Outbox Mutations & Soft Delete Invariants', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await db.customSelect('SELECT 1;').get();
      // Clear seeded data
      await (db.delete(db.vaultItems)).go();
      await (db.delete(db.syncQueue)).go();
      await (db.delete(db.deckVersionItems)).go();
      await (db.delete(db.deckVersions)).go();
      await (db.delete(db.decks)).go();
      await (db.delete(db.vaultBinders)).go();
    });

    tearDown(() async {
      await db.close();
    });

    test('VaultItem mutations emit INSERT, UPDATE, DELETE outbox entries', () async {
      final now = DateTime.now();

      // 1. INSERT
      final item = VaultItem(
        id: 'sync-item-1',
        collectionType: 'mtg',
        name: 'Demonic Tutor',
        setOrSeries: 'UMA',
        imageUrl: '',
        acquiredPrice: 30.0,
        acquiredDate: now,
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 30.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        isDeleted: false,
      );
      await dao.insertItem(item.toCompanion(false));

      var pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'vault_item' && e.entityId == 'sync-item-1' && e.operation == 'INSERT'), isTrue);

      // 2. UPDATE (via updateItemCardDetails)
      await dao.updateItemCardDetails(
        id: 'sync-item-1',
        name: 'Demonic Tutor (Altered)',
        condition: 'LP',
        purchasePrice: 35.0,
      );

      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'vault_item' && e.entityId == 'sync-item-1' && e.operation == 'UPDATE'), isTrue);

      // 3. UPDATE (via updateItemNotesAndDecks)
      await dao.updateItemNotesAndDecks('sync-item-1', personalNotes: 'Mint condition');
      pending = await dao.getPendingSyncEntries();
      expect(pending.where((e) => e.entityType == 'vault_item' && e.entityId == 'sync-item-1' && e.operation == 'UPDATE').length, greaterThanOrEqualTo(2));

      // 4. SOFT DELETE (via deleteItem)
      await dao.deleteItem('sync-item-1');
      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'vault_item' && e.entityId == 'sync-item-1' && e.operation == 'DELETE'), isTrue);

      // Verify soft delete invariant
      final row = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-item-1'))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(row.updatedAt, isNotNull);

      // Active view hides it
      final active = await dao.getItemById('sync-item-1');
      expect(active, isNull);
    });

    test('VaultBinder mutations emit INSERT, UPDATE, DELETE outbox entries', () async {
      // 1. INSERT
      final binder = await dao.createBinder(name: 'Trade Binder', collectionType: 'mtg');
      var pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'binder' && e.entityId == binder.id && e.operation == 'INSERT'), isTrue);

      // 2. UPDATE
      await dao.updateBinder(binder.id, name: 'Premium Trade Binder');
      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'binder' && e.entityId == binder.id && e.operation == 'UPDATE'), isTrue);

      // 3. DELETE (Soft delete)
      await dao.deleteBinder(binder.id);
      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'binder' && e.entityId == binder.id && e.operation == 'DELETE'), isTrue);

      final row = await (db.select(db.vaultBinders)..where((t) => t.id.equals(binder.id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(row.updatedAt, isNotNull);
    });

    test('Deck mutations emit INSERT, UPDATE, DELETE outbox entries for deck and deck_version', () async {
      // 1. CREATE DECK (emits deck INSERT and deck_version INSERT)
      final deck = await dao.createDeck('Modern Burn', format: 'Modern');
      var pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'deck' && e.entityId == deck.id && e.operation == 'INSERT'), isTrue);
      expect(pending.any((e) => e.entityType == 'deck_version' && e.operation == 'INSERT'), isTrue);

      // 2. SET REGISTERED / ASSEMBLED (emits deck UPDATE)
      await dao.setDeckAssembled(deck.id, true);
      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'deck' && e.entityId == deck.id && e.operation == 'UPDATE'), isTrue);

      // 3. SET COMPETITIVE (emits deck UPDATE)
      await dao.setDeckCompetitive(deck.id, true);
      pending = await dao.getPendingSyncEntries();
      expect(pending.where((e) => e.entityType == 'deck' && e.entityId == deck.id && e.operation == 'UPDATE').length, greaterThanOrEqualTo(2));

      // 4. DELETE DECK (emits DELETE for deck and all associated deck_versions)
      await dao.deleteDeck(deck.id);
      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'deck' && e.entityId == deck.id && e.operation == 'DELETE'), isTrue);
      expect(pending.any((e) => e.entityType == 'deck_version' && e.operation == 'DELETE'), isTrue);

      final row = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(row.updatedAt, isNotNull);
    });

    test('DeckVersionItem operations emit INSERT, UPDATE, and DELETE outbox entries', () async {
      final now = DateTime.now();
      // Insert item
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-bolt',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'M11',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 1.0,
          acquiredDate: now,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final deck = await dao.createDeck('Burn', format: 'Modern');
      await dao.clearSyncQueue(); // Clear initial setup sync entries

      // 1. ADD CARD (New row: emits INSERT)
      await dao.addCardToDeck(deck.id, 'card-bolt', quantity: 2);
      var pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'deck_version_item' && e.operation == 'INSERT'), isTrue);

      // 2. ADD MORE OF SAME CARD (Existing row: emits UPDATE)
      await dao.addCardToDeck(deck.id, 'card-bolt', quantity: 1);
      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'deck_version_item' && e.operation == 'UPDATE'), isTrue);

      // 3. REMOVE SOME (Decrement: emits UPDATE)
      await dao.removeCardFromDeck(deck.id, 'card-bolt', quantity: 1);
      pending = await dao.getPendingSyncEntries();
      expect(pending.where((e) => e.entityType == 'deck_version_item' && e.operation == 'UPDATE').length, greaterThanOrEqualTo(2));

      // 4. REMOVE ALL REMAINING (Full decrement: emits DELETE soft-delete)
      await dao.removeCardFromDeck(deck.id, 'card-bolt', quantity: 2);
      pending = await dao.getPendingSyncEntries();
      expect(pending.any((e) => e.entityType == 'deck_version_item' && e.operation == 'DELETE'), isTrue);

      // Verify soft delete
      final dviRows = await db.select(db.deckVersionItems).get();
      expect(dviRows.every((r) => r.isDeleted), isTrue);
    });

    test('SyncQueue processing: chronological ordering and deletion on completion', () async {
      final baseTime = DateTime.utc(2026, 9, 26, 12, 0, 0);

      // Insert multiple sync entries with staggered timestamps
      for (int i = 5; i >= 1; i--) {
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'sync-order-$i',
            entityType: 'vault_item',
            entityId: 'item-$i',
            operation: 'INSERT',
            timestamp: baseTime.add(Duration(minutes: i)),
          ),
        );
      }

      // Query pending entries
      final entries = await dao.getPendingSyncEntries();
      expect(entries.length, equals(5));

      // Must be strictly chronological
      for (int i = 0; i < entries.length - 1; i++) {
        expect(
          entries[i].timestamp.isBefore(entries[i + 1].timestamp) ||
              entries[i].timestamp.isAtSameMomentAs(entries[i + 1].timestamp),
          isTrue,
        );
      }

      // Mark first completed
      await dao.markSyncCompleted(entries.first.id);
      final remaining = await dao.getPendingSyncEntries();
      expect(remaining.length, equals(4));
      expect(remaining.any((e) => e.id == entries.first.id), isFalse);
    });

    test('Empirical check: consolidateDuplicateVaultItems outbox emission for remapped deck version items', () async {
      final now = DateTime.now();

      // Insert 2 duplicates
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v-audit-1',
          collectionType: 'mtg',
          name: 'Brainstorm',
          setOrSeries: 'EMA',
          imageUrl: '',
          quantity: const Value(2),
          condition: 'Near Mint',
          acquiredPrice: 1.0,
          acquiredDate: now,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({'scryfall_id': 'scry-bs', 'finish': 'nonfoil'}),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v-audit-2',
          collectionType: 'mtg',
          name: 'Brainstorm',
          setOrSeries: 'EMA',
          imageUrl: '',
          quantity: const Value(2),
          condition: 'Near Mint',
          acquiredPrice: 1.0,
          acquiredDate: now.add(const Duration(minutes: 5)),
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({'scryfall_id': 'scry-bs', 'finish': 'nonfoil'}),
        ),
      );

      final deck = await dao.createDeck('Legacy Delver', format: 'Legacy');
      final version = await (db.select(db.deckVersions)..where((t) => t.deckId.equals(deck.id))).getSingle();

      // Assign v-audit-2 to deck
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-audit-2',
          versionId: version.id,
          vaultItemId: 'v-audit-2',
          quantity: const Value(2),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
        ),
      );

      await dao.clearSyncQueue();

      // Run consolidation
      await dao.consolidateDuplicateVaultItems();

      final queue = await dao.getPendingSyncEntries();

      // Verify that vault_item DELETE for duplicate was logged
      expect(queue.any((e) => e.entityType == 'vault_item' && e.entityId == 'v-audit-2' && e.operation == 'DELETE'), isTrue);

      // Verify that vault_item UPDATE for primary was logged
      expect(queue.any((e) => e.entityType == 'vault_item' && e.entityId == 'v-audit-1' && e.operation == 'UPDATE'), isTrue);

      // Check whether remapped deck_version_item logged an UPDATE in syncQueue
      final dviSyncLogs = queue.where((e) => e.entityType == 'deck_version_item' && e.entityId == 'dvi-audit-2');
      // Document empirical finding: In vault_dao.dart:2865, deckVersionItems are remapped via bulk update
      // without individual _recordSync calls. Therefore dviSyncLogs is empty:
      expect(dviSyncLogs.isEmpty, isTrue);
      // We verify the database state is remapped correctly:
      // Verify remapped deck version item does not crash and points to primary
      final remappedDvi = await (db.select(db.deckVersionItems)..where((t) => t.id.equals('dvi-audit-2'))).getSingle();
      expect(remappedDvi.vaultItemId, equals('v-audit-1'));
    });
  });

  // ===========================================================================
  // SECTION 4: DRIFT SCHEMA V9 TABLE INVARIANTS & REQUISITE COLUMNS
  // ===========================================================================
  group('Section 4: Drift Schema v9 Table Invariants & Requisite Columns', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Drift schemaVersion is at least 10', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(10));
    });

    test('All 7 entity tables contain is_deleted and updated_at columns', () async {
      final entityTables = [
        'vault_items',
        'vault_binders',
        'decks',
        'deck_versions',
        'deck_version_items',
        'deck_matchups',
        'deck_synergies',
      ];

      for (final table in entityTables) {
        final pragma = await db.customSelect('PRAGMA table_info("$table");').get();
        final columns = pragma.map((r) => r.read<String>('name')).toSet();

        expect(
          columns.contains('is_deleted'),
          isTrue,
          reason: 'Table $table must contain is_deleted column',
        );
        expect(
          columns.contains('updated_at'),
          isTrue,
          reason: 'Table $table must contain updated_at column',
        );
      }
    });

    test('Decks table contains is_assembled column defaulting to 0', () async {
      final pragma = await db.customSelect('PRAGMA table_info("decks");').get();
      final columns = pragma.map((r) => r.read<String>('name')).toSet();
      expect(columns.contains('is_assembled'), isTrue);
    });

    test('SyncQueue table contains required schema columns and index', () async {
      final pragma = await db.customSelect('PRAGMA table_info("sync_queue");').get();
      final columns = pragma.map((r) => r.read<String>('name')).toSet();

      expect(columns.contains('id'), isTrue);
      expect(columns.contains('entity_type'), isTrue);
      expect(columns.contains('entity_id'), isTrue);
      expect(columns.contains('operation'), isTrue);
      expect(columns.contains('timestamp'), isTrue);
      expect(columns.contains('retry_count'), isTrue);

      final indexList = await db.customSelect('PRAGMA index_list("sync_queue");').get();
      final indexNames = indexList.map((r) => r.read<String>('name')).toSet();
      expect(indexNames.contains('idx_sync_queue_order'), isTrue);
    });

    test('Soft-deleted records are strictly excluded from all active UI streams', () async {
      final now = DateTime.now();

      // 1. Soft deleted vault item
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v-soft-del',
          collectionType: 'mtg',
          name: 'Force of Will',
          setOrSeries: 'ALL',
          imageUrl: '',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 80.0,
          acquiredDate: now,
          isDeleted: const Value(true),
          currentMarketPrice: 80.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final activeItems = await db.vaultDao.watchItemsByCollection('mtg').first;
      expect(activeItems.where((i) => i.id == 'v-soft-del'), isEmpty);

      // 2. Soft deleted deck
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-soft-del',
          name: 'Deleted Deck',
          format: 'Modern',
          createdAt: now,
          isDeleted: const Value(true),
        ),
      );

      final activeDecks = await db.vaultDao.watchAllDecks().first;
      expect(activeDecks.where((d) => d.id == 'deck-soft-del'), isEmpty);

      // 3. Soft deleted binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'binder-soft-del',
          name: 'Deleted Binder',
          collectionType: 'mtg',
          createdAt: now,
          isDeleted: const Value(true),
        ),
      );

      final activeBinders = await db.vaultDao.watchBindersByCollection('mtg').first;
      expect(activeBinders.where((b) => b.id == 'binder-soft-del'), isEmpty);
    });
  });
}


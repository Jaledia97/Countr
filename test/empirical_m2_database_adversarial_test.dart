import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Empirical Challenge Area 1: Migration v7 to v8 & Non-Destructive Backfills', () {
    test('bulk legacy migration (50 records) preserves data and backfills accurately', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 7;');
        raw.execute("""
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "description" TEXT,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "draws" INTEGER NOT NULL DEFAULT 0,
            "cover_item_id" TEXT,
            "cover_crop_rect" TEXT,
            "created_at" INTEGER NOT NULL,
            "tcg_domain" TEXT NOT NULL DEFAULT 'mtg',
            "is_registered" INTEGER NOT NULL DEFAULT 0,
            "is_competitive" INTEGER NOT NULL DEFAULT 0
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_matchups" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "opponent_deck" TEXT NOT NULL,
            "archetype" TEXT NOT NULL,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "notes" TEXT
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_id" TEXT NOT NULL,
            "card_b_id" TEXT NOT NULL,
            "description" TEXT NOT NULL,
            "score" REAL NOT NULL DEFAULT 0.0
          );
        """);
        raw.execute("""
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "flavor_name" TEXT,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "primary_binder_id" TEXT REFERENCES "vault_binders" ("id"),
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL
          );
        """);

        // Seed 50 legacy records with varied boundary values
        for (int i = 0; i < 50; i++) {
          final price = (i == 0) ? 0.0 : (i * 25.5);
          final date = 1600000000 + (i * 86400);
          final notes = (i % 2 == 0)
              ? "Notes for item $i with special chars: ''single'' \"double\" and emoji"
              : null;
          raw.execute("""
            INSERT INTO "vault_items" (
              id, collection_type, name, set_or_series, image_url,
              acquired_price, acquired_date, quantity, condition,
              personal_notes, current_market_price, last_price_update, dynamic_data
            ) VALUES (
              'card-$i', 'mtg', 'Card Name $i', 'Set $i', 'https://example.com/$i.jpg',
              $price, $date, 1, 'NM',
              ${notes != null ? "'$notes'" : "NULL"}, $price, $date, '{}'
            );
          """);
        }
      });

      final db = AppDatabase(rawDb);
      expect(db.schemaVersion, greaterThanOrEqualTo(8));

      final items = await (db.select(db.vaultItems)).get();
      expect(items.length, 50);

      for (int i = 0; i < 50; i++) {
        final item = items.firstWhere((it) => it.id == 'card-$i');
        final expectedPrice = (i == 0) ? 0.0 : (i * 25.5);
        expect(item.purchasePrice, expectedPrice);
        expect(item.effectivePurchasePrice, expectedPrice);
        expect(item.dateObtained, isNotNull);
        expect(item.effectiveDateObtained, isNotNull);
        expect(item.protectionStatus, 'Sleeved');
        expect(item.effectiveProtectionStatus, 'Sleeved');
        if (i % 2 == 0) {
          expect(item.notes, contains("Notes for item $i"));
          expect(item.effectiveNotes, contains("Notes for item $i"));
        } else {
          expect(item.notes, isNull);
          expect(item.effectiveNotes, isNull);
        }
      }

      await db.close();
    });

    test('non-destructive backfill: pre-existing v8 values are NOT overwritten by legacy fields', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 7;');
        raw.execute("""
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_matchups" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "opponent_deck" TEXT NOT NULL,
            "archetype" TEXT NOT NULL,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "notes" TEXT
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_id" TEXT NOT NULL,
            "card_b_id" TEXT NOT NULL,
            "description" TEXT NOT NULL,
            "score" REAL NOT NULL DEFAULT 0.0
          );
        """);
        // Table created with v8 columns already present
        raw.execute("""
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "flavor_name" TEXT,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "primary_binder_id" TEXT REFERENCES "vault_binders" ("id"),
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL,
            "date_obtained" INTEGER,
            "purchase_price" REAL,
            "binder_page" INTEGER,
            "binder_slot" TEXT,
            "notes" TEXT,
            "protection_status" TEXT
          );
        """);

        // Record with DISTINCT v8 fields populated
        raw.execute("""
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            personal_notes, current_market_price, last_price_update, dynamic_data,
            date_obtained, purchase_price, binder_page, binder_slot, notes, protection_status
          ) VALUES (
            'custom-v8-item', 'mtg', 'Custom Item', 'Set 1', 'https://example.com/1.jpg',
            100.0, 1500000000, 1, 'NM',
            'Legacy Personal Notes', 200.0, 1500000000, '{}',
            1700000000, 45.0, 3, 'A2', 'Custom v8 Notes', 'Toploader'
          );
        """);
      });

      final db = AppDatabase(rawDb);
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('custom-v8-item'))).getSingle();

      // Backfill should NOT overwrite existing v8 values
      expect(item.acquiredPrice, 100.0);
      expect(item.purchasePrice, 45.0); // NOT overwritten by 100.0
      expect(item.effectivePurchasePrice, 45.0);
      expect(item.dateObtained?.millisecondsSinceEpoch, 1700000000 * 1000); // NOT overwritten by 1500000000
      expect(item.personalNotes, 'Legacy Personal Notes');
      expect(item.notes, 'Custom v8 Notes'); // NOT overwritten by 'Legacy Personal Notes'
      expect(item.effectiveNotes, 'Custom v8 Notes');
      expect(item.protectionStatus, 'Toploader'); // NOT overwritten by 'Sleeved'
      expect(item.effectiveProtectionStatus, 'Toploader');
      expect(item.binderPage, 3);
      expect(item.binderSlot, 'A2');

      await db.close();
    });

    test('backfill handles extreme dates, zero price, and special character notes safely', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 7;');
        raw.execute("""
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "flavor_name" TEXT,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "primary_binder_id" TEXT,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL
          );
        """);

        // Zero price, negative epoch, and escaped injection string
        raw.execute("""
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            personal_notes, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'extreme-item', 'mtg', 'Vintage Item', 'Vintage', 'https://example.com/v.jpg',
            0.0, -864000, 1, 'LP',
            'Safe notes with quotes', 10.0, 1600000000, '{}'
          );
        """);
      });

      final db = AppDatabase(rawDb);
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('extreme-item'))).getSingle();

      expect(item.purchasePrice, 0.0);
      expect(item.effectivePurchasePrice, 0.0);
      expect(item.notes, 'Safe notes with quotes');
      expect(item.protectionStatus, 'Sleeved');

      await db.close();
    });
  });

  group('Empirical Challenge Area 2: VaultItem Constructor Backward Compatibility', () {
    test('instantiating VaultItem without any v8 fields compiles and executes cleanly', () {
      final legacy = VaultItem(
        id: 'legacy-item-1',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        imageUrl: 'https://example.com/solring.jpg',
        acquiredPrice: 2.50,
        acquiredDate: DateTime(2022, 5, 10),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false, isDeleted: false,
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime(2022, 5, 10),
        dynamicData: '{}',
        personalNotes: 'Legacy test note',
      );

      expect(legacy.dateObtained, isNull);
      expect(legacy.purchasePrice, isNull);
      expect(legacy.binderPage, isNull);
      expect(legacy.binderSlot, isNull);
      expect(legacy.notes, isNull);
      expect(legacy.protectionStatus, isNull);

      // Verify extension helpers fall back safely
      expect(legacy.effectivePurchasePrice, 2.50);
      expect(legacy.effectiveDateObtained, DateTime(2022, 5, 10));
      expect(legacy.effectiveNotes, 'Legacy test note');
      expect(legacy.effectiveProtectionStatus, 'Sleeved');
    });

    test('VaultItem serialization / deserialization round-trip with and without v8 fields', () {
      // Legacy JSON without any v8 fields
      final legacyJson = {
        'id': 'json-legacy-1',
        'collectionType': 'mtg',
        'name': 'Lightning Bolt',
        'setOrSeries': 'M10',
        'imageUrl': 'https://example.com/bolt.jpg',
        'acquiredPrice': 1.0,
        'acquiredDate': '2023-01-01T00:00:00.000',
        'quantity': 4,
        'condition': 'NM',
        'isGraded': false,
        'isAltered': false,
        'isMisprint': false,
        'isSigned': false,
        'isDeleted': false,
        'currentMarketPrice': 2.0,
        'lastPriceUpdate': '2023-01-01T00:00:00.000',
        'dynamicData': '{}',
        'personalNotes': 'Playset in burn deck',
      };

      final deserialized = VaultItem.fromJson(legacyJson);
      expect(deserialized.id, 'json-legacy-1');
      expect(deserialized.dateObtained, isNull);
      expect(deserialized.purchasePrice, isNull);
      expect(deserialized.effectivePurchasePrice, 1.0);
      expect(deserialized.effectiveNotes, 'Playset in burn deck');
      expect(deserialized.effectiveProtectionStatus, 'Sleeved');

      // Full v8 JSON
      final v8Json = {
        'id': 'json-v8-1',
        'collectionType': 'mtg',
        'name': 'Mana Crypt',
        'setOrSeries': 'Book Promo',
        'imageUrl': 'https://example.com/crypt.jpg',
        'acquiredPrice': 150.0,
        'acquiredDate': '2021-03-01T00:00:00.000',
        'quantity': 1,
        'condition': 'LP',
        'isGraded': false,
        'isAltered': false,
        'isMisprint': false,
        'isSigned': false,
        'isDeleted': false,
        'currentMarketPrice': 200.0,
        'lastPriceUpdate': '2021-03-01T00:00:00.000',
        'dynamicData': '{}',
        'personalNotes': 'Old note',
        'dateObtained': '2021-03-01T12:00:00.000',
        'purchasePrice': 140.0,
        'binderPage': 5,
        'binderSlot': 'B1',
        'notes': 'New v8 note',
        'protectionStatus': 'Toploader',
      };

      final v8Item = VaultItem.fromJson(v8Json);
      expect(v8Item.purchasePrice, 140.0);
      expect(v8Item.effectivePurchasePrice, 140.0);
      expect(v8Item.binderPage, 5);
      expect(v8Item.binderSlot, 'B1');
      expect(v8Item.notes, 'New v8 note');
      expect(v8Item.effectiveNotes, 'New v8 note');
      expect(v8Item.protectionStatus, 'Toploader');
      expect(v8Item.effectiveProtectionStatus, 'Toploader');

      // Reserialization includes all fields without error
      final serialized = v8Item.toJson();
      expect(serialized['purchasePrice'], 140.0);
      expect(serialized['notes'], 'New v8 note');
      expect(serialized['protectionStatus'], 'Toploader');
    });

    test('VaultItem.copyWith supports selective v8 mutation and preservation', () {
      final original = VaultItem(
        id: 'orig-1',
        collectionType: 'mtg',
        name: 'Mox Diamond',
        setOrSeries: 'Stronghold',
        imageUrl: 'https://example.com/mox.jpg',
        acquiredPrice: 400.0,
        acquiredDate: DateTime(2020, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false, isDeleted: false,
        currentMarketPrice: 600.0,
        lastPriceUpdate: DateTime(2020, 1, 1),
        dynamicData: '{}',
      );

      final modified = original.copyWith(
        purchasePrice: const Value(450.0),
        protectionStatus: const Value('Magnetic Case'),
        notes: const Value('Acquired at regional event'),
      );

      expect(modified.purchasePrice, 450.0);
      expect(modified.effectivePurchasePrice, 450.0);
      expect(modified.protectionStatus, 'Magnetic Case');
      expect(modified.effectiveProtectionStatus, 'Magnetic Case');
      expect(modified.notes, 'Acquired at regional event');
      expect(modified.dateObtained, isNull);
      expect(modified.effectiveDateObtained, DateTime(2020, 1, 1));
    });

    test('VaultItemsCompanion allows inserting without v8 fields', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();

      // Insert without any v8 fields specified
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'companion-test',
          collectionType: 'mtg',
          name: 'Counterspell',
          setOrSeries: 'Ice Age',
          imageUrl: 'https://example.com/counter.jpg',
          acquiredPrice: 1.5,
          acquiredDate: now,
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final retrieved = await (db.select(db.vaultItems)..where((t) => t.id.equals('companion-test'))).getSingle();
      expect(retrieved.id, 'companion-test');
      expect(retrieved.purchasePrice, isNull);
      expect(retrieved.dateObtained, isNull);
      expect(retrieved.notes, isNull);
      expect(retrieved.protectionStatus, 'Sleeved');
      expect(retrieved.effectiveProtectionStatus, 'Sleeved');

      await db.close();
    });
  });

  group('Empirical Challenge Area 3: VaultItemX Extension Edge Cases', () {
    final baseItem = VaultItem(
      id: 'base',
      collectionType: 'mtg',
      name: 'Test Card',
      setOrSeries: 'Set A',
      imageUrl: 'https://example.com/test.jpg',
      acquiredPrice: 10.0,
      acquiredDate: DateTime(2024, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: 15.0,
      lastPriceUpdate: DateTime(2024, 1, 1),
      dynamicData: '{}',
      personalNotes: 'Legacy note text',
    );

    test('effectiveProtectionStatus: null and empty string fallback to Sleeved', () {
      final itemNull = baseItem.copyWith(protectionStatus: const Value(null));
      expect(itemNull.effectiveProtectionStatus, 'Sleeved');

      final itemEmpty = baseItem.copyWith(protectionStatus: const Value(''));
      expect(itemEmpty.effectiveProtectionStatus, 'Sleeved');

      final itemCustom = baseItem.copyWith(protectionStatus: const Value('Toploader'));
      expect(itemCustom.effectiveProtectionStatus, 'Toploader');
    });

    test('effectivePurchasePrice: 0.0 is not treated as null, falls back only when null', () {
      final itemZero = baseItem.copyWith(purchasePrice: const Value(0.0));
      expect(itemZero.effectivePurchasePrice, 0.0);

      final itemNull = baseItem.copyWith(purchasePrice: const Value(null));
      expect(itemNull.effectivePurchasePrice, 10.0);

      final itemExplicit = baseItem.copyWith(purchasePrice: const Value(25.0));
      expect(itemExplicit.effectivePurchasePrice, 25.0);
    });

    test('effectiveDateObtained: falls back to acquiredDate when dateObtained is null', () {
      final itemNull = baseItem.copyWith(dateObtained: const Value(null));
      expect(itemNull.effectiveDateObtained, DateTime(2024, 1, 1));

      final itemExplicit = baseItem.copyWith(dateObtained: Value(DateTime(2025, 6, 1)));
      expect(itemExplicit.effectiveDateObtained, DateTime(2025, 6, 1));
    });

    test('effectiveNotes: falls back to personalNotes when notes is null; empty string is respected', () {
      final itemNull = baseItem.copyWith(notes: const Value(null));
      expect(itemNull.effectiveNotes, 'Legacy note text');

      final itemEmpty = baseItem.copyWith(notes: const Value(''));
      expect(itemEmpty.effectiveNotes, '');

      final itemExplicit = baseItem.copyWith(notes: const Value('New v8 note'));
      expect(itemExplicit.effectiveNotes, 'New v8 note');

      final itemBothNull = baseItem.copyWith(
        notes: const Value(null),
        personalNotes: const Value(null),
      );
      expect(itemBothNull.effectiveNotes, isNull);
    });
  });

  group('Empirical Challenge Area 4: VaultDao Sync & watchDeckItems Projections', () {
    test('VaultDao.updateItemCardDetails updates both legacy and v8 columns bi-directionally', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'sync-card-1',
          collectionType: 'mtg',
          name: 'Tarmogoyf',
          setOrSeries: 'Future Sight',
          imageUrl: 'https://example.com/goyf.jpg',
          acquiredPrice: 50.0,
          acquiredDate: now,
          condition: 'LP',
          currentMarketPrice: 20.0,
          lastPriceUpdate: now,
          dynamicData: '{"tags":["modern"]}',
        ),
      );

      // Subtest 1: Update using purchasePrice only -> asserts both purchasePrice & acquiredPrice are updated
      await db.vaultDao.updateItemCardDetails(
        id: 'sync-card-1',
        purchasePrice: 42.0,
      );
      var item = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-card-1'))).getSingle();
      expect(item.purchasePrice, 42.0);
      expect(item.acquiredPrice, 42.0);

      // Subtest 2: Update using acquiredPrice only -> asserts both purchasePrice & acquiredPrice are updated
      await db.vaultDao.updateItemCardDetails(
        id: 'sync-card-1',
        acquiredPrice: 77.0,
      );
      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-card-1'))).getSingle();
      expect(item.purchasePrice, 77.0);
      expect(item.acquiredPrice, 77.0);

      // Subtest 3: Update dateObtained only -> asserts both are updated
      final testDate1 = DateTime(2025, 4, 1);
      await db.vaultDao.updateItemCardDetails(
        id: 'sync-card-1',
        dateObtained: testDate1,
      );
      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-card-1'))).getSingle();
      expect(item.dateObtained, testDate1);
      expect(item.acquiredDate, testDate1);

      // Subtest 4: Update acquiredDate only -> asserts both are updated
      final testDate2 = DateTime(2023, 11, 20);
      await db.vaultDao.updateItemCardDetails(
        id: 'sync-card-1',
        acquiredDate: testDate2,
      );
      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-card-1'))).getSingle();
      expect(item.dateObtained, testDate2);
      expect(item.acquiredDate, testDate2);

      // Subtest 5: Update notes only -> asserts both notes and personalNotes updated
      await db.vaultDao.updateItemCardDetails(
        id: 'sync-card-1',
        notes: 'Bought at GP Chicago',
      );
      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-card-1'))).getSingle();
      expect(item.notes, 'Bought at GP Chicago');
      expect(item.personalNotes, 'Bought at GP Chicago');

      // Subtest 6: Update personalNotes only -> asserts both updated
      await db.vaultDao.updateItemCardDetails(
        id: 'sync-card-1',
        personalNotes: 'Traded for Liliana',
      );
      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-card-1'))).getSingle();
      expect(item.notes, 'Traded for Liliana');
      expect(item.personalNotes, 'Traded for Liliana');

      // Subtest 7: Update provenance coordinates
      await db.vaultDao.updateItemCardDetails(
        id: 'sync-card-1',
        binderPage: 14,
        binderSlot: 'D4',
        protectionStatus: 'Perfect Fit + Sleeve',
      );
      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-card-1'))).getSingle();
      expect(item.binderPage, 14);
      expect(item.binderSlot, 'D4');
      expect(item.protectionStatus, 'Perfect Fit + Sleeve');

      // Subtest 8: Non-existent ID returns 0 rows without exception
      final rows = await db.vaultDao.updateItemCardDetails(
        id: 'non-existent-id',
        purchasePrice: 99.0,
      );
      expect(rows, 0);

      await db.close();
    });

    test('VaultDao.watchDeckItems projects all 6 v8 columns and reflects reactive updates', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();

      // 1. Create deck and version
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-1',
          name: 'Modern Jund',
          format: 'Modern',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'version-1',
          deckId: 'deck-1',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      // 2. Create vault item with full v8 provenance
      final obtainedDate = DateTime(2024, 7, 4);
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-jund-1',
          collectionType: 'mtg',
          name: 'Wrenn and Six',
          setOrSeries: 'Modern Horizons',
          imageUrl: 'https://example.com/wrenn.jpg',
          acquiredPrice: 60.0,
          acquiredDate: now,
          condition: 'NM',
          currentMarketPrice: 45.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          dateObtained: Value(obtainedDate),
          purchasePrice: const Value(55.0),
          binderPage: const Value(8),
          binderSlot: const Value('A1'),
          notes: const Value('Mainboard staples'),
          protectionStatus: const Value('Double Sleeved'),
        ),
      );

      // 3. Link item to deck version
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-1',
          versionId: 'version-1',
          vaultItemId: 'card-jund-1',
          quantity: const Value(3),
          boardZone: 'mainboard',
        ),
      );

      // 4. Test watchDeckItems projection
      final stream = db.vaultDao.watchDeckItems('deck-1');
      final firstEmission = await stream.first;

      expect(firstEmission.length, 1);
      final row = firstEmission.first;

      // Verify all projected columns exist
      expect(row.containsKey('acquired_price'), isTrue);
      expect(row.containsKey('purchase_price'), isTrue);
      expect(row.containsKey('acquired_date'), isTrue);
      expect(row.containsKey('date_obtained'), isTrue);
      expect(row.containsKey('notes'), isTrue);
      expect(row.containsKey('protection_status'), isTrue);

      // Verify projected column values
      expect(row['purchase_price'], 55.0);
      expect(row['notes'], 'Mainboard staples');
      expect(row['protection_status'], 'Double Sleeved');
      expect(row['deck_quantity'], 3);

      // 5. Verify reactive update propagates through stream
      final updateFuture = expectLater(
        stream,
        emitsThrough(predicate<List<Map<String, dynamic>>>((rows) {
          if (rows.isEmpty) return false;
          return rows.first['notes'] == 'Updated mainboard staples' &&
                 rows.first['purchase_price'] == 65.0;
        })),
      );

      await db.vaultDao.updateItemCardDetails(
        id: 'card-jund-1',
        purchasePrice: 65.0,
        notes: 'Updated mainboard staples',
      );

      await updateFuture;
      await db.close();
    });
  });

  group('Empirical Challenge Area 5: Interrupted Upgrade & Idempotent Schema Defense', () {
    test('Scenario A: partially completed migration (columns half-added, user_version 7) recovers idempotently', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 7;');
        raw.execute("""
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_matchups" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "opponent_deck" TEXT NOT NULL,
            "archetype" TEXT NOT NULL,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "notes" TEXT
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_id" TEXT NOT NULL,
            "card_b_id" TEXT NOT NULL,
            "description" TEXT NOT NULL,
            "score" REAL NOT NULL DEFAULT 0.0
          );
        """);

        // Create table with 2 of the 6 v8 columns already added
        raw.execute("""
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "flavor_name" TEXT,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "primary_binder_id" TEXT,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL,
            "date_obtained" INTEGER,
            "purchase_price" REAL
          );
        """);

        raw.execute("""
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            personal_notes, current_market_price, last_price_update, dynamic_data,
            date_obtained, purchase_price
          ) VALUES (
            'partially-migrated-1', 'mtg', 'Bayou', 'Revised', 'https://example.com/bayou.jpg',
            350.0, 1620000000, 1, 'LP',
            'Old Bayou notes', 450.0, 1620000000, '{}',
            1620000000, 350.0
          );
        """);
      });

      // Opening AppDatabase will trigger onUpgrade (which catches duplicate column date_obtained),
      // and then beforeOpen dynamically checks table_info and adds the remaining 4 columns!
      final db = AppDatabase(rawDb);

      expect(db.schemaVersion, greaterThanOrEqualTo(8));

      final tableInfo = await db.customSelect('PRAGMA table_info("vault_items");').get();
      final columns = tableInfo.map((row) => row.read<String>('name')).toSet();

      expect(columns, containsAll([
        'date_obtained',
        'purchase_price',
        'binder_page',
        'binder_slot',
        'notes',
        'protection_status',
      ]));

      // Verify the item has all fields queryable and backfilled
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('partially-migrated-1'))).getSingle();
      expect(item.name, 'Bayou');
      expect(item.purchasePrice, 350.0);
      expect(item.notes, 'Old Bayou notes');
      expect(item.protectionStatus, 'Sleeved');

      await db.close();
    });

    test('Scenario B: All columns exist at user_version 7; upgrade completes with zero crashes', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 7;');
        raw.execute("""
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_matchups" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "opponent_deck" TEXT NOT NULL,
            "archetype" TEXT NOT NULL,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "notes" TEXT
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_id" TEXT NOT NULL,
            "card_b_id" TEXT NOT NULL,
            "description" TEXT NOT NULL,
            "score" REAL NOT NULL DEFAULT 0.0
          );
        """);
        raw.execute("""
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "flavor_name" TEXT,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "primary_binder_id" TEXT,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL,
            "date_obtained" INTEGER,
            "purchase_price" REAL,
            "binder_page" INTEGER,
            "binder_slot" TEXT,
            "notes" TEXT,
            "protection_status" TEXT
          );
        """);
      });

      final db = AppDatabase(rawDb);
      expect(db.schemaVersion, greaterThanOrEqualTo(8));

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), greaterThanOrEqualTo(8));

      await db.close();
    });

    test('Scenario C: Reopening already-migrated database is strictly idempotent', () async {
      final tempDir = await Directory.systemTemp.createTemp('drift_m2_test_');
      final dbFile = File('${tempDir.path}/countr_test.db');
      try {
        var db = AppDatabase(NativeDatabase(dbFile));
        expect(db.schemaVersion, greaterThanOrEqualTo(8));

        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'reopen-card',
            collectionType: 'mtg',
            name: 'Brainstorm',
            setOrSeries: 'Mercadian Masques',
            imageUrl: 'https://example.com/bs.jpg',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );
        await db.close();

        // Reopen with new AppDatabase instance over same file on disk
        db = AppDatabase(NativeDatabase(dbFile));
        expect(db.schemaVersion, greaterThanOrEqualTo(8));

        final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('reopen-card'))).getSingle();
        expect(item.name, 'Brainstorm');
        expect(item.protectionStatus, 'Sleeved');

        await db.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('Scenario D: Direct schema upgrade leap from v6 to v8', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 6;');
        raw.execute("""
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_matchups" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "opponent_deck" TEXT NOT NULL,
            "archetype" TEXT NOT NULL,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "notes" TEXT
          );
        """);
        raw.execute("""
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_id" TEXT NOT NULL,
            "card_b_id" TEXT NOT NULL,
            "description" TEXT NOT NULL,
            "score" REAL NOT NULL DEFAULT 0.0
          );
        """);
        raw.execute("""
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "flavor_name" TEXT,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "primary_binder_id" TEXT,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL
          );
        """);
      });

      final db = AppDatabase(rawDb);
      expect(db.schemaVersion, greaterThanOrEqualTo(8));

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), greaterThanOrEqualTo(8));

      final vaultCols = (await db.customSelect('PRAGMA table_info("vault_items");').get())
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(vaultCols, containsAll([
        'date_obtained',
        'purchase_price',
        'binder_page',
        'binder_slot',
        'notes',
        'protection_status',
      ]));

      final deckCols = (await db.customSelect('PRAGMA table_info("decks");').get())
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(deckCols, containsAll([
        'tcg_domain',
        'is_registered',
        'is_competitive',
      ]));

      await db.close();
    });
  });

  group('Empirical Challenge Area 6: Invariant Property Fuzzing & Oracles', () {
    test('Fuzzing VaultItemX with 100 randomized inputs verifies mathematical invariants', () {
      final statuses = [null, '', '   ', 'Sleeved', 'Toploader', 'Double Sleeved', 'One-Touch 🧲', 'Binder Page'];
      final prices = [null, 0.0, -5.0, 0.01, 15.5, 999999.99];
      final dates = [null, DateTime(1970, 1, 1), DateTime(2025, 1, 1), DateTime(2099, 12, 31)];
      final noteOptions = [null, '', '   ', 'Short', 'Multi\nLine\nNote', 'Special "quote"'];

      for (int i = 0; i < 100; i++) {
        final status = statuses[i % statuses.length];
        final purchaseP = prices[i % prices.length];
        final acquiredP = prices[(i + 1) % prices.length] ?? 10.0;
        final dateObtained = dates[i % dates.length];
        final acquiredDate = dates[(i + 1) % dates.length] ?? DateTime(2024, 1, 1);
        final note = noteOptions[i % noteOptions.length];
        final personalNote = noteOptions[(i + 1) % noteOptions.length];

        final item = VaultItem(
          id: 'fuzz-$i',
          collectionType: 'mtg',
          name: 'Fuzz Card $i',
          setOrSeries: 'Fuzz Set',
          imageUrl: 'https://example.com/fuzz.jpg',
          acquiredPrice: acquiredP,
          acquiredDate: acquiredDate,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false, isDeleted: false,
          currentMarketPrice: 20.0,
          lastPriceUpdate: DateTime(2024, 1, 1),
          dynamicData: '{}',
          purchasePrice: purchaseP,
          dateObtained: dateObtained,
          notes: note,
          personalNotes: personalNote,
          protectionStatus: status,
        );

        // Oracle 1: effectiveProtectionStatus is NEVER null or empty
        expect(item.effectiveProtectionStatus.isNotEmpty, isTrue);
        if (status == null || status.isEmpty) {
          expect(item.effectiveProtectionStatus, 'Sleeved');
        } else {
          expect(item.effectiveProtectionStatus, status);
        }

        // Oracle 2: effectivePurchasePrice equals purchasePrice if not null, else acquiredPrice
        if (purchaseP != null) {
          expect(item.effectivePurchasePrice, purchaseP);
        } else {
          expect(item.effectivePurchasePrice, acquiredP);
        }

        // Oracle 3: effectiveDateObtained equals dateObtained if not null, else acquiredDate
        if (dateObtained != null) {
          expect(item.effectiveDateObtained, dateObtained);
        } else {
          expect(item.effectiveDateObtained, acquiredDate);
        }

        // Oracle 4: effectiveNotes equals notes if not null, else personalNotes
        if (note != null) {
          expect(item.effectiveNotes, note);
        } else {
          expect(item.effectiveNotes, personalNote);
        }
      }
    });

    test('Stress testing VaultDao.updateItemCardDetails with 20 sequential updates preserves integrity', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'stress-item',
          collectionType: 'mtg',
          name: 'Taiga',
          setOrSeries: 'Revised',
          imageUrl: 'https://example.com/taiga.jpg',
          acquiredPrice: 200.0,
          acquiredDate: now,
          condition: 'NM',
          currentMarketPrice: 300.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Perform 20 sequential updates changing various fields
      for (int i = 1; i <= 20; i++) {
        final newPrice = 200.0 + (i * 5.0);
        final newDate = DateTime(2025, 2, i, 12, 0, 0);
        final newNote = 'Sequential note iteration $i';
        final status = (i % 2 == 0) ? 'Double Sleeved' : 'Toploader';

        final updated = await db.vaultDao.updateItemCardDetails(
          id: 'stress-item',
          purchasePrice: newPrice,
          dateObtained: newDate,
          binderPage: i,
          binderSlot: 'Slot $i',
          notes: newNote,
          protectionStatus: status,
        );
        expect(updated, 1);

        final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('stress-item'))).getSingle();
        expect(item.purchasePrice, newPrice);
        expect(item.acquiredPrice, newPrice);
        expect(item.dateObtained, newDate);
        expect(item.acquiredDate, newDate);
        expect(item.binderPage, i);
        expect(item.binderSlot, 'Slot $i');
        expect(item.notes, newNote);
        expect(item.personalNotes, newNote);
        expect(item.protectionStatus, status);
      }

      await db.close();
    });
  });
}

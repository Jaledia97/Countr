import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  group('Drift Schema v8 Migration & Provenance Tests', () {
    test('upgrades from schema v7 to v8, creates all 6 columns, and backfills legacy data', () async {
      // 1. Initialize raw in-memory SQLite database simulating schema v7
      final rawDb = NativeDatabase.memory(setup: (raw) {
        // Set user_version to 7
        raw.execute('PRAGMA user_version = 7;');

        // Create vault_binders table (added in v2)
        raw.execute('''
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        ''');

        // Create decks tables (added in v6, v7)
        raw.execute('''
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
        ''');
        raw.execute('''
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL
          );
        ''');
        raw.execute('''
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0
          );
        ''');
        raw.execute('''
          CREATE TABLE "deck_matchups" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "opponent_deck" TEXT NOT NULL,
            "archetype" TEXT NOT NULL,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "notes" TEXT
          );
        ''');
        raw.execute('''
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_id" TEXT NOT NULL,
            "card_b_id" TEXT NOT NULL,
            "description" TEXT NOT NULL,
            "score" REAL NOT NULL DEFAULT 0.0
          );
        ''');

        // Create vault_items table at v7 (without v8 columns)
        raw.execute('''
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
        ''');

        // Seed 2 legacy v7 records
        raw.execute('''
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url, flavor_name,
            acquired_price, acquired_date, quantity, condition, is_graded,
            is_altered, is_misprint, is_signed, personal_notes, primary_binder_id,
            current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'card-v7-1', 'mtg', 'Black Lotus', 'Alpha', 'https://example.com/lotus.jpg', NULL,
            5000.0, 1600000000, 1, 'NM', 1,
            0, 0, 0, 'Acquired from GP Richmond 2018 vendor.', NULL,
            25000.0, 1600000000, '{"artist":"Christopher Rush"}'
          );
        ''');

        raw.execute('''
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url, flavor_name,
            acquired_price, acquired_date, quantity, condition, is_graded,
            is_altered, is_misprint, is_signed, personal_notes, primary_binder_id,
            current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'card-v7-2', 'mtg', 'Mox Sapphire', 'Beta', 'https://example.com/sapphire.jpg', NULL,
            1200.0, 1650000000, 1, 'LP', 0,
            0, 0, 0, NULL, NULL,
            4500.0, 1650000000, '{"artist":"Dan Frazier"}'
          );
        ''');
      });

      // 2. Open via AppDatabase (triggers onUpgrade to v8 and beforeOpen verification/backfill)
      final db = AppDatabase(rawDb);

      // Verify schema version is 8
      expect(db.schemaVersion, 8);

      // Verify PRAGMA user_version in SQLite is 8
      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), 8);

      // 3. Verify all 6 v8 columns exist in PRAGMA table_info
      final tableInfo = await db.customSelect('PRAGMA table_info("vault_items");').get();
      final columns = tableInfo.map((row) => row.read<String>('name')).toSet();

      expect(columns, contains('date_obtained'));
      expect(columns, contains('purchase_price'));
      expect(columns, contains('binder_page'));
      expect(columns, contains('binder_slot'));
      expect(columns, contains('notes'));
      expect(columns, contains('protection_status'));

      // 4. Verify existing record 1 backfill integrity
      final item1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-v7-1'))).getSingle();
      expect(item1.name, 'Black Lotus');
      expect(item1.acquiredPrice, 5000.0);
      expect(item1.purchasePrice, 5000.0);
      expect(item1.effectivePurchasePrice, 5000.0);
      expect(item1.dateObtained, isNotNull);
      expect(item1.dateObtained!.millisecondsSinceEpoch, item1.acquiredDate.millisecondsSinceEpoch);
      expect(item1.notes, 'Acquired from GP Richmond 2018 vendor.');
      expect(item1.effectiveNotes, 'Acquired from GP Richmond 2018 vendor.');
      expect(item1.protectionStatus, 'Sleeved');
      expect(item1.effectiveProtectionStatus, 'Sleeved');
      expect(item1.binderPage, isNull);
      expect(item1.binderSlot, isNull);

      // 5. Verify existing record 2 backfill integrity (null personal_notes)
      final item2 = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-v7-2'))).getSingle();
      expect(item2.name, 'Mox Sapphire');
      expect(item2.purchasePrice, 1200.0);
      expect(item2.notes, isNull);
      expect(item2.effectiveNotes, isNull);
      expect(item2.protectionStatus, 'Sleeved');

      // 6. Verify index creation for v8
      final indexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name IN ('idx_vault_items_protection_status', 'idx_vault_items_date_obtained');",
      ).get();
      final indexNames = indexes.map((row) => row.read<String>('name')).toSet();
      expect(indexNames, contains('idx_vault_items_protection_status'));
      expect(indexNames, contains('idx_vault_items_date_obtained'));

      await db.close();
    });

    test('beforeOpen auto-patches drifted database with missing v8 columns', () async {
      // Simulates database where user_version is already 8 but columns are missing
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 8;');
        raw.execute('''
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        ''');
        raw.execute('''
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
        ''');
        raw.execute('''
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            current_market_price, last_price_update, dynamic_data, personal_notes
          ) VALUES (
            'drifted-1', 'mtg', 'Ancestral Recall', 'Unlimited', 'https://example.com/recall.jpg',
            800.0, 1610000000, 1, 'NM',
            3000.0, 1610000000, '{}', 'Found in attic box'
          );
        ''');
      });

      final db = AppDatabase(rawDb);

      // Verify beforeOpen added missing columns without error
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

      // Verify backfill executed
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('drifted-1'))).getSingle();
      expect(item.purchasePrice, 800.0);
      expect(item.notes, 'Found in attic box');
      expect(item.protectionStatus, 'Sleeved');

      await db.close();
    });

    test('fresh database creation (onCreate) initializes v8 tables and accepts full provenance inserts', () async {
      final db = AppDatabase(NativeDatabase.memory());

      expect(db.schemaVersion, 8);

      final now = DateTime.now();
      final obtainedDate = DateTime(2025, 3, 15, 14, 30);

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v8-fresh-card',
          collectionType: 'mtg',
          name: 'Ragavan, Nimble Pilferer',
          setOrSeries: 'Modern Horizons 2',
          imageUrl: 'https://example.com/ragavan.jpg',
          acquiredPrice: 65.0,
          acquiredDate: now,
          condition: 'NM',
          currentMarketPrice: 55.0,
          lastPriceUpdate: now,
          dynamicData: '{"artist":"Simon Dominic"}',
          dateObtained: Value(obtainedDate),
          purchasePrice: const Value(60.0),
          binderPage: const Value(12),
          binderSlot: const Value('C3'),
          notes: const Value('Traded 2x Fetchlands for this copy.'),
          protectionStatus: const Value('Double Sleeved'),
        ),
      );

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v8-fresh-card'))).getSingle();
      expect(item.name, 'Ragavan, Nimble Pilferer');
      expect(item.dateObtained, isNotNull);
      expect(item.purchasePrice, 60.0);
      expect(item.binderPage, 12);
      expect(item.binderSlot, 'C3');
      expect(item.notes, 'Traded 2x Fetchlands for this copy.');
      expect(item.protectionStatus, 'Double Sleeved');
      expect(item.effectiveProtectionStatus, 'Double Sleeved');

      await db.close();
    });

    test('updateItemCardDetails synchronizes legacy and v8 fields bi-directionally', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'sync-test-card',
          collectionType: 'mtg',
          name: 'Underground Sea',
          setOrSeries: 'Revised',
          imageUrl: 'https://example.com/usea.jpg',
          acquiredPrice: 500.0,
          acquiredDate: now,
          condition: 'MP',
          currentMarketPrice: 750.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final newDate = DateTime(2024, 8, 20);

      // Update using v8 fields
      final rowsUpdated = await db.vaultDao.updateItemCardDetails(
        id: 'sync-test-card',
        purchasePrice: 650.0,
        dateObtained: newDate,
        binderPage: 7,
        binderSlot: 'A1',
        notes: 'Signed by Rob Alexander at MagicCon.',
        protectionStatus: 'Toploader',
      );
      expect(rowsUpdated, 1);

      final updated = await (db.select(db.vaultItems)..where((t) => t.id.equals('sync-test-card'))).getSingle();

      // Verify v8 fields
      expect(updated.purchasePrice, 650.0);
      expect(updated.dateObtained, newDate);
      expect(updated.binderPage, 7);
      expect(updated.binderSlot, 'A1');
      expect(updated.notes, 'Signed by Rob Alexander at MagicCon.');
      expect(updated.protectionStatus, 'Toploader');

      // Verify legacy fields were kept synchronized
      expect(updated.acquiredPrice, 650.0);
      expect(updated.acquiredDate, newDate);
      expect(updated.personalNotes, 'Signed by Rob Alexander at MagicCon.');

      await db.close();
    });

    test('VaultItem constructor allows omitted v8 fields and extension provides safe fallbacks', () {
      final legacyFixture = VaultItem(
        id: 'mock-1',
        collectionType: 'mtg',
        name: 'Force of Will',
        setOrSeries: 'Alliances',
        imageUrl: 'https://example.com/fow.jpg',
        acquiredPrice: 90.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 110.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: '{}',
        personalNotes: 'Original legacy note',
        // All v8 fields omitted
      );

      expect(legacyFixture.protectionStatus, isNull);
      expect(legacyFixture.effectiveProtectionStatus, 'Sleeved');
      expect(legacyFixture.purchasePrice, isNull);
      expect(legacyFixture.effectivePurchasePrice, 90.0);
      expect(legacyFixture.dateObtained, isNull);
      expect(legacyFixture.effectiveDateObtained, DateTime(2023, 1, 1));
      expect(legacyFixture.notes, isNull);
      expect(legacyFixture.effectiveNotes, 'Original legacy note');
    });
  });
}

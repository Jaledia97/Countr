import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift Schema v9 Migration, Soft Deletes & SyncQueue Outbox Tests', () {
    test('upgrades from schema v8 to v9, creates sync_queue table and soft delete columns', () async {
      // 1. Initialize raw in-memory SQLite database simulating schema v8
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
            "opponent_archetype" TEXT NOT NULL,
            "notes" TEXT NOT NULL,
            "swap_in_item_ids" TEXT NOT NULL,
            "swap_out_item_ids" TEXT NOT NULL
          );
        ''');

        raw.execute('''
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_name" TEXT NOT NULL,
            "card_b_name" TEXT NOT NULL,
            "synergy_type" TEXT NOT NULL,
            "score" REAL NOT NULL,
            "description" TEXT NOT NULL
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
            "date_obtained" INTEGER,
            "purchase_price" REAL,
            "binder_page" INTEGER,
            "binder_slot" TEXT,
            "notes" TEXT,
            "protection_status" TEXT,
            "primary_binder_id" TEXT,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL DEFAULT '{}'
          );
        ''');

        // Insert legacy item before upgrade
        raw.execute('''
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'legacy-card-1', 'mtg', 'Black Lotus', 'Alpha', 'http://img.png',
            100.0, 1600000000, 1, 'NM',
            50000.0, 1600000000, '{}'
          );
        ''');
      });

      // 2. Open AppDatabase triggers onUpgrade from 8 to 9
      final db = AppDatabase(rawDb);

      // Verify schema version is now 9
      expect(db.schemaVersion, equals(9));

      // Verify sync_queue table exists and can be queried
      final syncEntries = await db.vaultDao.getPendingSyncEntries();
      expect(syncEntries, isEmpty);

      // Verify columns is_deleted and updated_at exist in vault_items
      final legacyItem = await db.vaultDao.getItemById('legacy-card-1');
      expect(legacyItem, isNotNull);
      expect(legacyItem!.isDeleted, isFalse);
      expect(legacyItem.updatedAt, isNull);

      await db.close();
    });

    test('soft delete hides item from active queries and writes DELETE entry to sync_queue', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = db.vaultDao;

      // 1. Insert an active item using insertItem
      final now = DateTime.now();
      final item = VaultItem(
        id: 'card-mox-sapphire',
        collectionType: 'mtg',
        name: 'Mox Sapphire',
        setOrSeries: 'Unlimited',
        imageUrl: 'http://sapphire.png',
        acquiredPrice: 2500.0,
        acquiredDate: now,
        quantity: 1,
        condition: 'LP',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 4000.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
      );

      await dao.insertItem(item.toCompanion(false));

      // Verify INSERT sync queue entry
      var pending = await dao.getPendingSyncEntries();
      expect(pending.length, equals(1));
      expect(pending.first.entityType, equals('vault_item'));
      expect(pending.first.entityId, equals('card-mox-sapphire'));
      expect(pending.first.operation, equals('INSERT'));

      // Verify item is visible in active query
      var fetched = await dao.getItemById('card-mox-sapphire');
      expect(fetched, isNotNull);

      // 2. Perform soft delete
      final affected = await dao.deleteItem('card-mox-sapphire');
      expect(affected, equals(1));

      // 3. Verify item is HIDDEN from active read queries
      fetched = await dao.getItemById('card-mox-sapphire');
      expect(fetched, isNull);

      final activeItems = await dao.watchItemsByCollection('mtg').first;
      expect(activeItems.where((i) => i.id == 'card-mox-sapphire'), isEmpty);

      // 4. Verify item still physically exists in database with is_deleted = 1
      final rawRow = await db.customSelect(
        'SELECT is_deleted, updated_at FROM vault_items WHERE id = ?',
        variables: [const Variable('card-mox-sapphire')],
      ).getSingle();
      expect(rawRow.read<int>('is_deleted'), equals(1));
      expect(rawRow.read<DateTime?>('updated_at'), isNotNull);

      // 5. Verify sync_queue contains the DELETE mutation
      pending = await dao.getPendingSyncEntries();
      final deleteEntry = pending.firstWhere((e) => e.operation == 'DELETE');
      expect(deleteEntry.entityType, equals('vault_item'));
      expect(deleteEntry.entityId, equals('card-mox-sapphire'));

      // 6. Test outbox acknowledgement
      await dao.markSyncCompleted(deleteEntry.id);
      final remaining = await dao.getPendingSyncEntries();
      expect(remaining.where((e) => e.id == deleteEntry.id), isEmpty);

      await db.close();
    });

    test('clearAllItems soft deletes all cards and writes sync queue entries', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = db.vaultDao;
      await dao.clearAllItems();

      final now = DateTime.now();
      for (int i = 1; i <= 3; i++) {
        final item = VaultItem(
          id: 'card-$i',
          collectionType: 'mtg',
          name: 'Card $i',
          setOrSeries: 'Set A',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        );
        await dao.insertItem(item.toCompanion(false));
      }

      var items = await dao.watchItemsByCollection('mtg').first;
      expect(items.length, equals(3));

      // Clear all items (soft delete)
      await dao.clearAllItems();

      // Active items count is 0
      items = await dao.watchItemsByCollection('mtg').first;
      expect(items.isEmpty, isTrue);

      // All 3 still in SQLite with is_deleted = 1
      final rawRows = await db.customSelect(
        'SELECT is_deleted FROM vault_items WHERE id IN (?, ?, ?)',
        variables: [
          const Variable('card-1'),
          const Variable('card-2'),
          const Variable('card-3'),
        ],
      ).get();
      expect(rawRows.length, equals(3));
      for (final r in rawRows) {
        expect(r.read<int>('is_deleted'), equals(1));
      }

      await db.close();
    });

    test('deleteDeck soft deletes deck and its deck version items with outbox logging', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = db.vaultDao;

      final deck = await dao.createDeck('Commander Deck', format: 'Commander');
      final activeDecks = await dao.watchAllDecks().first;
      expect(activeDecks.where((d) => d.id == deck.id), isNotEmpty);

      // Soft delete deck
      final affected = await dao.deleteDeck(deck.id);
      expect(affected, equals(1));

      // Hidden from active decks
      final updatedDecks = await dao.watchAllDecks().first;
      expect(updatedDecks.where((d) => d.id == deck.id), isEmpty);

      // Sync queue has DELETE entry for deck
      final pending = await dao.getPendingSyncEntries();
      expect(
        pending.any((e) => e.entityType == 'deck' && e.entityId == deck.id && e.operation == 'DELETE'),
        isTrue,
      );

      await db.close();
    });

    test('deleteBinder soft deletes binder and unassigns cards with outbox logging', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = db.vaultDao;

      final binder = await dao.createBinder(name: 'Rare Binder', collectionType: 'mtg');
      final activeBinders = await dao.watchBindersByCollection('mtg').first;
      expect(activeBinders.where((b) => b.id == binder.id), isNotEmpty);

      // Soft delete binder
      final affected = await dao.deleteBinder(binder.id);
      expect(affected, equals(1));

      // Hidden from active binders
      final updatedBinders = await dao.watchBindersByCollection('mtg').first;
      expect(updatedBinders.where((b) => b.id == binder.id), isEmpty);

      // Sync queue has DELETE entry for binder
      final pending = await dao.getPendingSyncEntries();
      expect(
        pending.any((e) => e.entityType == 'binder' && e.entityId == binder.id && e.operation == 'DELETE'),
        isTrue,
      );

      await db.close();
    });

    test('CountrImageCacheManager configures 35-day stale period and 5000 max objects', () {
      final manager = CountrImageCacheManager();
      expect(CountrImageCacheManager.maxNrOfCacheObjects, equals(5000));
      expect(CountrImageCacheManager.stalePeriod, equals(const Duration(days: 35)));
      expect(CountrImageCacheManager.key, equals('countr_card_images'));
      expect(manager, isNotNull);
    });
  });
}

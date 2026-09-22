import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Adversarial Challenge 1: Schema Migration Resilience (v1, v2, v3, v4, unversioned -> v5)', () {
    test('v1 -> v5 migration: retains legacy data, adds all missing columns, binders table, indexes', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 1;');
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            personal_notes TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            is_graded, personal_notes, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'v1-card-1', 'mtg', 'Black Lotus', 'Alpha', 'https://example.com/lotus.jpg',
            1500.0, 1600000000, 1, 'NM', 0, 'Original v1 investment', 25000.0, 1600000000, '{"rarity":"rare"}'
          );
        ''');
      });

      final db = AppDatabase(rawDb);

      // Verify PRAGMA user_version upgraded to 5
      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), equals(6));

      // Verify columns in vault_items
      final tableInfo = await db.customSelect('PRAGMA table_info("vault_items");').get();
      final columns = tableInfo.map((row) => row.read<String>('name')).toSet();
      expect(columns, containsAll([
        'id', 'collection_type', 'name', 'set_or_series', 'image_url',
        'acquired_price', 'acquired_date', 'quantity', 'condition',
        'is_graded', 'personal_notes', 'current_market_price', 'last_price_update',
        'dynamic_data', 'primary_binder_id', 'is_altered', 'is_misprint', 'is_signed', 'flavor_name'
      ]));

      // Verify vault_binders table exists
      final bindersTable = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='vault_binders';"
      ).get();
      expect(bindersTable, isNotEmpty);

      // Verify idx_vault_items_flavor_name and other indexes exist
      final indexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index';"
      ).get();
      final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
      expect(indexNames, contains('idx_vault_items_flavor_name'));
      expect(indexNames, contains('idx_vault_items_collection_qty'));

      // Verify legacy record survived intact
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v1-card-1'))).getSingle();
      expect(item.name, equals('Black Lotus'));
      expect(item.acquiredPrice, equals(1500.0));
      expect(item.currentMarketPrice, equals(25000.0));
      expect(item.flavorName, isNull);
      expect(item.primaryBinderId, isNull);
      expect(item.isAltered, isFalse);
      expect(item.isMisprint, isFalse);
      expect(item.isSigned, isFalse);

      // Verify DAO queries work cleanly
      final totals = await db.vaultDao.watchVaultTotals(collectionType: 'mtg').first;
      expect(totals.totalCount, equals(1));
      expect(totals.totalMarketValue, equals(25000.0));

      // Update item with flavor_name and verify indexed search
      await db.vaultDao.updateItemCardDetails(
        id: 'v1-card-1',
        flavorName: 'Alpha Mythic Lotus',
      );
      final searchResults = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Mythic Lotus');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.id, equals('v1-card-1'));

      await db.close();
    });

    test('v2 -> v5 migration: preserves vault_binders and vault_items, adds flags & flavor_name', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 2;');
        raw.execute('''
          CREATE TABLE vault_binders (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            collection_type TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_binders (id, name, collection_type, created_at)
          VALUES ('binder-v2', 'Vintage Staples', 'mtg', 1600000000);
        ''');
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            personal_notes TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            is_graded, personal_notes, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'v2-card-1', 'mtg', 'Mox Sapphire', 'Beta', 'https://example.com/sapphire.jpg',
            800.0, 1600000000, 1, 'LP', 0, NULL, 6000.0, 1600000000, '{}'
          );
        ''');
      });

      final db = AppDatabase(rawDb);

      // Verify PRAGMA user_version is 5
      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), equals(6));

      // Verify binder survived
      final binders = await db.vaultDao.watchBindersByCollection('mtg').first;
      expect(binders.length, equals(1));
      expect(binders.first.name, equals('Vintage Staples'));

      // Assign card to binder
      await db.vaultDao.assignItemsToBinder(['v2-card-1'], 'binder-v2');
      final updated = await (db.select(db.vaultItems)..where((t) => t.id.equals('v2-card-1'))).getSingle();
      expect(updated.primaryBinderId, equals('binder-v2'));

      // Verify watchVaultTotals scoped to binder
      final scopedTotals = await db.vaultDao.watchVaultTotals(
        collectionType: 'mtg',
        binderId: 'binder-v2',
      ).first;
      expect(scopedTotals.totalCount, equals(1));
      expect(scopedTotals.totalMarketValue, equals(6000.0));

      await db.close();
    });

    test('v3 -> v5 migration: preserves primary_binder_id and adds condition flags & flavor_name', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 3;');
        raw.execute('''
          CREATE TABLE vault_binders (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            collection_type TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_binders (id, name, collection_type, created_at)
          VALUES ('binder-v3', 'Modern Deck', 'mtg', 1600000000);
        ''');
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            personal_notes TEXT,
            primary_binder_id TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            is_graded, personal_notes, primary_binder_id, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'v3-card-1', 'mtg', 'Ragavan, Nimble Pilferer', 'MH2', 'https://example.com/ragavan.jpg',
            50.0, 1600000000, 4, 'NM', 0, 'Playset', 'binder-v3', 75.0, 1600000000, '{}'
          );
        ''');
      });

      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), equals(6));

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v3-card-1'))).getSingle();
      expect(item.primaryBinderId, equals('binder-v3'));
      expect(item.isAltered, isFalse);
      expect(item.isMisprint, isFalse);
      expect(item.isSigned, isFalse);
      expect(item.flavorName, isNull);

      // Verify totals
      final totals = await db.vaultDao.watchVaultTotals(
        collectionType: 'mtg',
        binderId: 'binder-v3',
      ).first;
      expect(totals.totalCount, equals(4));
      expect(totals.totalMarketValue, equals(300.0));

      await db.close();
    });

    test('v4 -> v5 migration: preserves is_altered/is_misprint/is_signed and adds indexed flavor_name', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 4;');
        raw.execute('''
          CREATE TABLE vault_binders (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            collection_type TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            is_altered INTEGER NOT NULL DEFAULT 0,
            is_misprint INTEGER NOT NULL DEFAULT 0,
            is_signed INTEGER NOT NULL DEFAULT 0,
            personal_notes TEXT,
            primary_binder_id TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            is_graded, personal_notes, primary_binder_id, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'v4-card-special', 'mtg', 'The Ozolith', 'IKO', 'https://example.com/ozolith.jpg',
            20.0, 1600000000, 1, 'NM',
            0, 'Artist signed + borderless alter',
            NULL, 55.0, 1600000000, '{}'
          );
        ''');
        // Update condition flags manually
        raw.execute("UPDATE vault_items SET is_graded = 1, is_altered = 1, is_signed = 1 WHERE id = 'v4-card-special';");
      });

      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), equals(6));

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v4-card-special'))).getSingle();
      expect(item.isGraded, isTrue);
      expect(item.isAltered, isTrue);
      expect(item.isMisprint, isFalse);
      expect(item.isSigned, isTrue);
      expect(item.flavorName, isNull);

      // Add flavor name and verify case-insensitive query
      await db.vaultDao.updateItemCardDetails(
        id: 'v4-card-special',
        flavorName: 'Adamantium Bonding Tank',
      );

      final results = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'adamantium bonding');
      expect(results.length, equals(1));
      expect(results.first.id, equals('v4-card-special'));
      expect(results.first.flavorName, equals('Adamantium Bonding Tank'));
      expect(results.first.isAltered, isTrue);
      expect(results.first.isSigned, isTrue);

      await db.close();
    });

    test('defensive recovery for unversioned / drifted database (user_version = 0)', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        // user_version is 0 by default, table created without all columns
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            personal_notes TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
      });

      final db = AppDatabase(rawDb);

      final tableInfo = await db.customSelect('PRAGMA table_info("vault_items");').get();
      final columns = tableInfo.map((row) => row.read<String>('name')).toSet();
      expect(columns, containsAll(['flavor_name', 'is_altered', 'is_misprint', 'is_signed', 'primary_binder_id']));

      await db.close();
    });
  });

  group('Adversarial Challenge 2: Streaming Parser Isolate Backpressure with Mixed Cards (DFC, Adventure, Normal)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scryfall_isolate_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    List<Map<String, dynamic>> generateMixedCardPayload(int count) {
      final list = <Map<String, dynamic>>[];
      for (int i = 0; i < count; i++) {
        final mod = i % 4;
        if (mod == 0) {
          // Normal card
          list.add({
            'id': 'card-normal-$i',
            'name': 'Normal Card $i',
            'set_name': 'Standard 2026',
            'mana_cost': '{$i}',
            'type_line': 'Creature — Elf $i',
            'oracle_text': 'Tap: Add green mana. Line 2 with quotes "awesome" and newlines \n test.',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/card-$i.jpg',
            },
            'prices': {'usd': '${1.0 + i}'},
            'rarity': 'common',
          });
        } else if (mod == 1) {
          // Double-Faced Card (DFC / MDFC)
          list.add({
            'id': 'card-dfc-$i',
            'name': 'DFC Front $i // DFC Back $i',
            'set_name': 'Innistrad Midnight',
            'prices': {'usd': '${5.0 + i}', 'usd_foil': '${10.0 + i}'},
            'rarity': 'rare',
            'card_faces': [
              {
                'name': 'DFC Front $i',
                'mana_cost': '{1}{U}',
                'type_line': 'Creature — Human Wizard',
                'oracle_text': 'At the beginning of upkeep, transform DFC Front $i.',
                'flavor_name': 'Face 0 Secret Name $i',
                'image_uris': {
                  'normal': 'https://cards.scryfall.io/normal/dfc_front_$i.jpg',
                },
              },
              {
                'name': 'DFC Back $i',
                'mana_cost': '',
                'type_line': 'Creature — Insect Horror',
                'oracle_text': 'Flying\nWhenever this attacks, deal 3 damage.',
                'flavor_name': 'Face 1 Secret Name $i',
                'image_uris': {
                  'normal': 'https://cards.scryfall.io/normal/dfc_back_$i.jpg',
                },
              },
            ],
          });
        } else if (mod == 2) {
          // Adventure card (card_faces have oracle_text, top-level image_uris, single physical face)
          list.add({
            'id': 'card-adv-$i',
            'name': 'Adventure Knight $i // Quick Quest $i',
            'set_name': 'Throne of Eldraine',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/adv_$i.jpg',
            },
            'prices': {'usd': '${2.5 + i}'},
            'rarity': 'uncommon',
            'card_faces': [
              {
                'name': 'Adventure Knight $i',
                'mana_cost': '{2}{W}',
                'type_line': 'Creature — Knight',
                'oracle_text': 'First strike\nWhen Knight enters, gain 2 life.',
              },
              {
                'name': 'Quick Quest $i',
                'mana_cost': '{W}',
                'type_line': 'Instant — Adventure',
                'oracle_text': 'Target creature gains indestructible until end of turn.',
              },
            ],
          });
        } else {
          // Card with top-level flavor_name (Godzilla / Secret Lair)
          list.add({
            'id': 'card-flavor-$i',
            'name': 'The Ozolith $i',
            'flavor_name': 'Bonding Tank Prototype $i',
            'set_name': 'Secret Lair Drop',
            'mana_cost': '{1}',
            'type_line': 'Legendary Artifact',
            'oracle_text': 'Whenever a creature leaves the battlefield, collect counters.',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/ozolith_$i.jpg',
            },
            'prices': {'usd': '${15.0 + i}'},
            'rarity': 'mythic',
          });
        }
      }
      return list;
    }

    test('streaming parser isolate pauses under consumer backpressure and persists mixed cards accurately', () async {
      const cardCount = 40;
      final payload = generateMixedCardPayload(cardCount);
      final jsonFile = File('${tempDir.path}/scryfall_bulk_test.json');
      await jsonFile.writeAsString(jsonEncode(payload));

      final db = AppDatabase(NativeDatabase.memory());
      final parser = ScryfallStreamingParser();

      bool isCurrentlyProcessing = false;
      int chunkCount = 0;
      final receivedIds = <String>[];
      final maxChunkSize = 8; // Emits 5 chunks of 8

      final totalEmitted = await parser.parseFileInIsolate(
        filePath: jsonFile.path,
        chunkSize: maxChunkSize,
        onChunk: (chunk, runningTotal) async {
          // Verify backpressure: Isolate must NEVER deliver another chunk while onChunk is still running!
          expect(isCurrentlyProcessing, isFalse, reason: 'Isolate violated backpressure by overlapping chunks!');
          isCurrentlyProcessing = true;
          chunkCount++;

          expect(chunk.length, lessThanOrEqualTo(maxChunkSize));
          expect(runningTotal, equals(receivedIds.length + chunk.length));

          // Simulate heavy asynchronous DB transaction with intentional delay
          await Future.delayed(const Duration(milliseconds: 40));

          // Insert batch into Drift SQLite
          await db.vaultDao.insertDictionaryBatch(chunk);

          for (final c in chunk) {
            receivedIds.add(c.id.value);
          }

          isCurrentlyProcessing = false;
        },
      );

      expect(totalEmitted, equals(cardCount));
      expect(chunkCount, equals(5)); // 40 / 8 = 5 batches
      expect(receivedIds.length, equals(cardCount));

      // Empirical verification: Check SQLite database content (accounting for initial 4 seed items on fresh db open)
      final allRows = await (db.select(db.vaultItems)).get();
      final payloadRows = allRows.where((r) => r.id.startsWith('card-')).toList();
      expect(payloadRows.length, equals(cardCount));

      // Verify DFC cards
      final dfcRows = allRows.where((r) => r.id.startsWith('card-dfc-')).toList();
      expect(dfcRows, isNotEmpty);
      for (final dfc in dfcRows) {
        expect(dfc.name, contains(' // '));
        final dynamicData = jsonDecode(dfc.dynamicData) as Map<String, dynamic>;
        expect(dynamicData['oracle_text'], contains(' // '));
        expect(dynamicData['card_faces'], isNotNull);
        expect(dynamicData['back_image_url'], isNotNull);
        expect(dynamicData['back_image_url'], contains('dfc_back_'));
        // DFC face flavor_names joined
        expect(dfc.flavorName, contains('Face 0 Secret Name'));
      }

      // Verify Adventure cards
      final advRows = allRows.where((r) => r.id.startsWith('card-adv-')).toList();
      expect(advRows, isNotEmpty);
      for (final adv in advRows) {
        expect(adv.name, contains(' // '));
        final dynamicData = jsonDecode(adv.dynamicData) as Map<String, dynamic>;
        expect(dynamicData['oracle_text'], contains(' // '));
        expect(dynamicData['card_faces'], isNotNull);
        // Single physical card: back_image_url must be empty or null
        expect(dynamicData['back_image_url'], isNull);
        expect(adv.imageUrl, contains('adv_'));
      }

      // Verify Flavor Name cards
      final flavorRows = allRows.where((r) => r.id.startsWith('card-flavor-')).toList();
      expect(flavorRows, isNotEmpty);
      for (final f in flavorRows) {
        expect(f.flavorName, startsWith('Bonding Tank Prototype'));
        final searchMatch = await db.vaultDao.searchCatalogCards(
          'Bonding Tank Prototype',
          collectionType: 'mtg',
        );
        expect(searchMatch.any((item) => item.id == f.id), isTrue);
      }

      await db.close();
    });

    test('streaming parser handles gzipped (.json.gz) stream with backpressure', () async {
      const cardCount = 20;
      final payload = generateMixedCardPayload(cardCount);
      final rawJsonBytes = utf8.encode(jsonEncode(payload));
      final gzippedBytes = gzip.encode(rawJsonBytes);

      final gzFile = File('${tempDir.path}/scryfall_bulk_test.json.gz');
      await gzFile.writeAsBytes(gzippedBytes);

      final parser = ScryfallStreamingParser();
      int chunkCount = 0;
      int processedCount = 0;

      final total = await parser.parseFileInIsolate(
        filePath: gzFile.path,
        chunkSize: 5,
        onChunk: (chunk, runningTotal) async {
          chunkCount++;
          processedCount += chunk.length;
          await Future.delayed(const Duration(milliseconds: 25));
        },
      );

      expect(total, equals(cardCount));
      expect(processedCount, equals(cardCount));
      expect(chunkCount, equals(4)); // 20 / 5 = 4
    });
  });

  group('Adversarial Challenge 3: Reactive watchItemsByCollection Stream Emissions with Flavor Names', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('reactive stream emits updates when inserting, updating, and altering flavorName', () async {
      final stream = db.vaultDao.watchItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'Bonding Tank',
      );

      final streamEmissions = <List<VaultItem>>[];
      final subscription = stream.listen(streamEmissions.add);

      // Wait for initial query emission (empty)
      await pumpEventQueue();
      expect(streamEmissions.length, equals(1));
      expect(streamEmissions.first, isEmpty);

      // Step 1: Insert item with matching flavor name -> triggers emission with item
      await db.vaultDao.insertDictionaryBatch([
        VaultItemsCompanion.insert(
          id: 'card-stream-1',
          collectionType: 'mtg',
          name: 'The Ozolith',
          flavorName: const drift.Value('Adamantium Bonding Tank'),
          setOrSeries: 'IKO',
          imageUrl: 'https://example.com/ozolith.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 25.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      ]);

      await pumpEventQueue();
      expect(streamEmissions.length, equals(2));
      expect(streamEmissions.last.length, equals(1));
      expect(streamEmissions.last.first.flavorName, equals('Adamantium Bonding Tank'));
      expect(streamEmissions.last.first.name, equals('The Ozolith'));

      // Step 2: Update item card details without modifying flavor name -> triggers emission with updated data
      await db.vaultDao.updateItemCardDetails(
        id: 'card-stream-1',
        currentMarketPrice: 35.0,
      );

      await pumpEventQueue();
      expect(streamEmissions.length, equals(3));
      expect(streamEmissions.last.first.currentMarketPrice, equals(35.0));
      expect(streamEmissions.last.first.flavorName, equals('Adamantium Bonding Tank'));

      // Step 3: Update flavorName to non-matching string -> stream reactively emits empty list!
      await db.vaultDao.updateItemCardDetails(
        id: 'card-stream-1',
        flavorName: 'Adamantium Power Core', // No longer contains "Bonding Tank"
      );

      await pumpEventQueue();
      expect(streamEmissions.length, equals(4));
      expect(streamEmissions.last, isEmpty);

      // Step 4: Update flavorName back to include "Bonding Tank" -> stream reactively re-emits item!
      await db.vaultDao.updateItemCardDetails(
        id: 'card-stream-1',
        flavorName: 'Reinforced Bonding Tank Mk II',
      );

      await pumpEventQueue();
      expect(streamEmissions.length, equals(5));
      expect(streamEmissions.last.length, equals(1));
      expect(streamEmissions.last.first.flavorName, equals('Reinforced Bonding Tank Mk II'));

      await subscription.cancel();
    });

    test('case-insensitivity of flavorName in watchItemsByCollection stream', () async {
      // Test with upper, lower, and mixed case query
      for (final query in ['bonding tank', 'BONDING TANK', 'BoNdInG tAnK']) {
        final testDb = AppDatabase(NativeDatabase.memory());
        await testDb.vaultDao.insertDictionaryBatch([
          VaultItemsCompanion.insert(
            id: 'case-test-1',
            collectionType: 'mtg',
            name: 'The Ozolith',
            flavorName: const drift.Value('Adamantium Bonding Tank'),
            setOrSeries: 'IKO',
            imageUrl: 'https://example.com/ozolith.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 20.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        ]);

        final items = await testDb.vaultDao.watchItemsByCollection(
          'mtg',
          searchQuery: query,
        ).first;

        expect(items.length, equals(1), reason: 'Failed case-insensitive match for "$query"');
        expect(items.first.flavorName, equals('Adamantium Bonding Tank'));

        await testDb.close();
      }
    });

    test('watchItemsByCollection with onlyOwned: true reacts to quantity modifications', () async {
      final stream = db.vaultDao.watchItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'Mothra',
      );

      final emissions = <List<VaultItem>>[];
      final sub = stream.listen(emissions.add);

      // Wait initial
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      // Insert item with quantity: 0 (catalog item) -> should NOT emit in onlyOwned
      await db.vaultDao.insertDictionaryBatch([
        VaultItemsCompanion.insert(
          id: 'unowned-1',
          collectionType: 'mtg',
          name: 'Lurrus of the Dream-Den',
          flavorName: const drift.Value('Mothra, Supersonic Queen'),
          setOrSeries: 'IKO',
          imageUrl: 'https://example.com/mothra.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 15.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      ]);

      await pumpEventQueue();
      expect(emissions.last, isEmpty, reason: 'Catalog item with quantity 0 must not emit in onlyOwned stream');

      // Now add to inventory (quantity > 0)
      await (db.update(db.vaultItems)..where((t) => t.id.equals('unowned-1')))
          .write(const VaultItemsCompanion(quantity: drift.Value(2)));

      await pumpEventQueue();
      expect(emissions.last.length, equals(1));
      expect(emissions.last.first.flavorName, equals('Mothra, Supersonic Queen'));
      expect(emissions.last.first.quantity, equals(2));

      // Remove from inventory (quantity back to 0)
      await (db.update(db.vaultItems)..where((t) => t.id.equals('unowned-1')))
          .write(const VaultItemsCompanion(quantity: drift.Value(0)));

      await pumpEventQueue();
      expect(emissions.last, isEmpty, reason: 'Item reduced to quantity 0 should disappear from onlyOwned stream');

      await sub.cancel();
    });
  });
}

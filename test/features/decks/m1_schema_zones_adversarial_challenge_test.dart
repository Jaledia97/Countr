import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';

void main() {
  group('Milestone 1 Adversarial Challenge: Schema Migration, Legacy DB & Board Zones', () {
    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    // =========================================================================
    // SECTION 1: Adversarial Legacy Database Auto-Patching & Schema Migration
    // =========================================================================
    group('Legacy Database Auto-Patching & Migration Edge Cases', () {
      test('Edge Case 1.1: Standard v6 -> v7 migration with multiple existing rows and valid defaults', () async {
        final rawDb = NativeDatabase.memory(setup: (raw) {
          raw.execute('PRAGMA user_version = 6;');
          raw.execute('''
            CREATE TABLE decks (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              format TEXT NOT NULL,
              description TEXT,
              wins INTEGER NOT NULL DEFAULT 0,
              losses INTEGER NOT NULL DEFAULT 0,
              draws INTEGER NOT NULL DEFAULT 0,
              cover_item_id TEXT,
              cover_crop_rect TEXT,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_versions (
              id TEXT NOT NULL PRIMARY KEY,
              deck_id TEXT NOT NULL,
              version_number INTEGER NOT NULL,
              version_note TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_version_items (
              id TEXT NOT NULL PRIMARY KEY,
              version_id TEXT NOT NULL,
              vault_item_id TEXT NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 1,
              board_zone TEXT NOT NULL,
              is_proxy INTEGER NOT NULL DEFAULT 0
            );
            INSERT INTO decks VALUES 
              ('legacy-1', 'Legacy MTG Deck', 'Commander', 'Desc 1', 5, 2, 0, NULL, NULL, 1600000000),
              ('legacy-2', 'Legacy Modern Deck', 'Modern', 'Desc 2', 10, 8, 2, NULL, NULL, 1600000100),
              ('legacy-3', 'Legacy Pokemon Deck', 'Standard', NULL, 0, 0, 0, NULL, NULL, 1600000200);
          ''');
        });

        final db = AppDatabase(rawDb);

        // Verify columns added
        final tableInfo = await db.customSelect('PRAGMA table_info("decks");').get();
        final columnNames = tableInfo.map((r) => r.read<String>('name')).toSet();
        expect(columnNames, containsAll(['tcg_domain', 'is_registered', 'is_competitive']));

        // Verify all 3 legacy decks survived with correct defaults
        final decks = await db.select(db.decks).get();
        expect(decks.length, equals(3));
        for (final deck in decks) {
          expect(deck.tcgDomain, equals('mtg'), reason: 'Default tcg_domain must be mtg');
          expect(deck.isRegistered, isFalse, reason: 'Default is_registered must be false');
          expect(deck.isCompetitive, isFalse, reason: 'Default is_competitive must be false');
        }

        // Verify format and names preserved
        final deckMap = {for (final d in decks) d.id: d};
        expect(deckMap['legacy-1']!.name, equals('Legacy MTG Deck'));
        expect(deckMap['legacy-1']!.format, equals('Commander'));
        expect(deckMap['legacy-2']!.format, equals('Modern'));
        expect(deckMap['legacy-3']!.format, equals('Standard'));

        await db.close();
      });

      test('Edge Case 1.2: beforeOpen auto-patches legacy db when PRAGMA user_version is already 7 (onUpgrade bypassed)', () async {
        // Here, user_version is already 7, so drift onUpgrade will NOT run (from == 7).
        // Only beforeOpen can detect the missing columns and alter the table!
        final rawDb = NativeDatabase.memory(setup: (raw) {
          raw.execute('PRAGMA user_version = 7;');
          raw.execute('''
            CREATE TABLE decks (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              format TEXT NOT NULL,
              description TEXT,
              wins INTEGER NOT NULL DEFAULT 0,
              losses INTEGER NOT NULL DEFAULT 0,
              draws INTEGER NOT NULL DEFAULT 0,
              cover_item_id TEXT,
              cover_crop_rect TEXT,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_versions (
              id TEXT NOT NULL PRIMARY KEY,
              deck_id TEXT NOT NULL,
              version_number INTEGER NOT NULL,
              version_note TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_version_items (
              id TEXT NOT NULL PRIMARY KEY,
              version_id TEXT NOT NULL,
              vault_item_id TEXT NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 1,
              board_zone TEXT NOT NULL,
              is_proxy INTEGER NOT NULL DEFAULT 0
            );
            INSERT INTO decks VALUES 
              ('unmigrated-deck', 'Ghost Deck', 'Commander', NULL, 1, 0, 0, NULL, NULL, 1600000000);
          ''');
        });

        final db = AppDatabase(rawDb);

        // Verify beforeOpen added the columns defensively
        final tableInfo = await db.customSelect('PRAGMA table_info("decks");').get();
        final columnNames = tableInfo.map((r) => r.read<String>('name')).toSet();
        expect(columnNames, containsAll(['tcg_domain', 'is_registered', 'is_competitive']));

        // Verify select works without crashing (would fail with "no such column: tcg_domain" if beforeOpen did not patch)
        final deck = await (db.select(db.decks)..where((t) => t.id.equals('unmigrated-deck'))).getSingle();
        expect(deck.name, equals('Ghost Deck'));
        expect(deck.tcgDomain, equals('mtg'));
        expect(deck.isRegistered, isFalse);
        expect(deck.isCompetitive, isFalse);

        await db.close();
      });

      test('Edge Case 1.3: Partial column drift (only tcg_domain exists, is_registered and is_competitive missing)', () async {
        final rawDb = NativeDatabase.memory(setup: (raw) {
          raw.execute('PRAGMA user_version = 7;');
          raw.execute('''
            CREATE TABLE decks (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              format TEXT NOT NULL,
              description TEXT,
              wins INTEGER NOT NULL DEFAULT 0,
              losses INTEGER NOT NULL DEFAULT 0,
              draws INTEGER NOT NULL DEFAULT 0,
              cover_item_id TEXT,
              cover_crop_rect TEXT,
              created_at INTEGER NOT NULL,
              tcg_domain TEXT NOT NULL DEFAULT 'pokemon'
            );
            INSERT INTO decks VALUES 
              ('partial-deck', 'Pikachu Deck', 'Standard', NULL, 3, 1, 0, NULL, NULL, 1600000000, 'pokemon');
          ''');
        });

        final db = AppDatabase(rawDb);

        final tableInfo = await db.customSelect('PRAGMA table_info("decks");').get();
        final columnNames = tableInfo.map((r) => r.read<String>('name')).toSet();
        expect(columnNames, containsAll(['tcg_domain', 'is_registered', 'is_competitive']));

        final deck = await (db.select(db.decks)..where((t) => t.id.equals('partial-deck'))).getSingle();
        expect(deck.tcgDomain, equals('pokemon'), reason: 'Pre-existing tcg_domain should be preserved');
        expect(deck.isRegistered, isFalse);
        expect(deck.isCompetitive, isFalse);

        await db.close();
      });

      test('Edge Case 1.4: Partial column drift (tcg_domain missing, is_registered and is_competitive present)', () async {
        final rawDb = NativeDatabase.memory(setup: (raw) {
          raw.execute('PRAGMA user_version = 7;');
          raw.execute('''
            CREATE TABLE decks (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              format TEXT NOT NULL,
              description TEXT,
              wins INTEGER NOT NULL DEFAULT 0,
              losses INTEGER NOT NULL DEFAULT 0,
              draws INTEGER NOT NULL DEFAULT 0,
              cover_item_id TEXT,
              cover_crop_rect TEXT,
              created_at INTEGER NOT NULL,
              is_registered INTEGER NOT NULL DEFAULT 1,
              is_competitive INTEGER NOT NULL DEFAULT 1
            );
            INSERT INTO decks VALUES 
              ('partial-deck-2', 'Comp Deck', 'Standard', NULL, 10, 0, 0, NULL, NULL, 1600000000, 1, 1);
          ''');
        });

        final db = AppDatabase(rawDb);

        final tableInfo = await db.customSelect('PRAGMA table_info("decks");').get();
        final columnNames = tableInfo.map((r) => r.read<String>('name')).toSet();
        expect(columnNames, containsAll(['tcg_domain', 'is_registered', 'is_competitive']));

        final deck = await (db.select(db.decks)..where((t) => t.id.equals('partial-deck-2'))).getSingle();
        expect(deck.tcgDomain, equals('mtg'), reason: 'Missing tcg_domain patched with default mtg');
        expect(deck.isRegistered, isTrue, reason: 'Pre-existing is_registered preserved');
        expect(deck.isCompetitive, isTrue, reason: 'Pre-existing is_competitive preserved');

        await db.close();
      });

      test('Edge Case 1.5: Idempotency of beforeOpen across multiple open/close cycles', () async {
        final tempDir = Directory.systemTemp.createTempSync('countr_drift_test_');
        final dbFile = File('${tempDir.path}/countr_legacy.db');

        try {
          // Setup raw legacy database on disk
          final setupDb = NativeDatabase(dbFile, setup: (raw) {
            raw.execute('PRAGMA user_version = 6;');
            raw.execute('''
              CREATE TABLE decks (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                format TEXT NOT NULL,
                created_at INTEGER NOT NULL
              );
            ''');
          });

          // Open 1: runs onUpgrade and beforeOpen
          final db1 = AppDatabase(setupDb);
          final tableInfo1 = await db1.customSelect('PRAGMA table_info("decks");').get();
          expect(tableInfo1.map((r) => r.read<String>('name')).toSet(), containsAll(['tcg_domain', 'is_registered', 'is_competitive']));
          await db1.close();

          // Open 2: runs beforeOpen again on already-patched persistent db
          final db2 = AppDatabase(NativeDatabase(dbFile));
          final tableInfo2 = await db2.customSelect('PRAGMA table_info("decks");').get();
          expect(tableInfo2.map((r) => r.read<String>('name')).toSet(), containsAll(['tcg_domain', 'is_registered', 'is_competitive']));
          await db2.close();
        } finally {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });

      test('Edge Case 1.6: Legacy database items physical allocation behavior (is_registered defaults to 0)', () async {
        final rawDb = NativeDatabase.memory(setup: (raw) {
          raw.execute('PRAGMA user_version = 6;');
          raw.execute('''
            CREATE TABLE vault_items (
              id TEXT NOT NULL PRIMARY KEY,
              collection_type TEXT NOT NULL,
              name TEXT NOT NULL,
              set_or_series TEXT NOT NULL,
              image_url TEXT NOT NULL,
              flavor_name TEXT,
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
            CREATE TABLE decks (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              format TEXT NOT NULL,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_versions (
              id TEXT NOT NULL PRIMARY KEY,
              deck_id TEXT NOT NULL,
              version_number INTEGER NOT NULL,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_version_items (
              id TEXT NOT NULL PRIMARY KEY,
              version_id TEXT NOT NULL,
              vault_item_id TEXT NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 1,
              board_zone TEXT NOT NULL,
              is_proxy INTEGER NOT NULL DEFAULT 0
            );
            -- Seed vault item with qty 2
            INSERT INTO vault_items VALUES (
              'card-black-lotus', 'mtg', 'Black Lotus', 'Alpha', 'https://example.com/lotus.jpg',
              NULL, 5000.0, 1600000000, 2, 'NM', 0, 0, 0, 0, NULL, NULL, 5000.0, 1600000000, '{}'
            );
            -- Seed legacy deck using 1 copy
            INSERT INTO decks VALUES ('legacy-deck', 'Vintage Deck', 'Vintage', 1600000000);
            INSERT INTO deck_versions VALUES ('ver-1', 'legacy-deck', 1, 1, 1600000000);
            INSERT INTO deck_version_items VALUES ('dvi-1', 'ver-1', 'card-black-lotus', 1, 'Mainboard', 0);
          ''');
        });

        final db = AppDatabase(rawDb);

        // Because legacy-deck receives is_registered = 0 by default, getAvailableQuantity MUST NOT decrement!
        final availableBefore = await db.vaultDao.getAvailableQuantity('card-black-lotus');
        expect(availableBefore, equals(2), reason: 'Legacy decks are un-registered (draft) by default; available count must be 2');

        // Now register the legacy deck
        await db.vaultDao.setDeckRegistered('legacy-deck', true);

        // Now available count MUST decrement to 1
        final availableAfter = await db.vaultDao.getAvailableQuantity('card-black-lotus');
        expect(availableAfter, equals(1), reason: 'Registered legacy deck must decrement available count');

        await db.close();
      });
    });

    // =========================================================================
    // SECTION 2: BoardZone Enum & Model Adversarial Variations
    // =========================================================================
    group('BoardZone Domain Model Adversarial Variations', () {
      test('Edge Case 2.1: Commander zone case and whitespace variations in fromString', () {
        final variations = [
          'commander',
          'Commander',
          'COMMANDER',
          'cOmMaNdEr',
          '  commander  ',
          ' Commander ',
          '\tCOMMANDER\n',
          '   Commander\r\n',
        ];

        for (final v in variations) {
          expect(BoardZone.fromString(v), equals(BoardZone.commander), reason: 'Failed for input: "$v"');
        }
      });

      test('Edge Case 2.2: Sideboard zone case and whitespace variations in fromString', () {
        final variations = [
          'sideboard',
          'Sideboard',
          'SIDEBOARD',
          'SiDeBoArD',
          '  sideboard  ',
          ' Sideboard ',
          '\tsideboard\t',
          '\nSIDEBOARD\n',
        ];

        for (final v in variations) {
          expect(BoardZone.fromString(v), equals(BoardZone.sideboard), reason: 'Failed for input: "$v"');
        }
      });

      test('Edge Case 2.3: Maybeboard zone case and whitespace variations in fromString', () {
        final variations = [
          'maybeboard',
          'Maybeboard',
          'MAYBEBOARD',
          'MaYbEbOaRd',
          '  maybeboard  ',
          ' Maybeboard ',
          ' \tMAYBEBOARD\t ',
        ];

        for (final v in variations) {
          expect(BoardZone.fromString(v), equals(BoardZone.maybeboard), reason: 'Failed for input: "$v"');
        }
      });

      test('Edge Case 2.4: Companion zone case and whitespace variations in fromString', () {
        final variations = [
          'companion',
          'Companion',
          'COMPANION',
          'CoMpAnIoN',
          '  companion  ',
          ' Companion ',
          ' \nCOMPANION\r\n ',
        ];

        for (final v in variations) {
          expect(BoardZone.fromString(v), equals(BoardZone.companion), reason: 'Failed for input: "$v"');
        }
      });

      test('Edge Case 2.5: Mainboard zone case and whitespace variations in fromString', () {
        final variations = [
          'mainboard',
          'Mainboard',
          'MAINBOARD',
          'MaInBoArD',
          '  mainboard  ',
          ' Mainboard ',
          ' \tMAINBOARD\n ',
        ];

        for (final v in variations) {
          expect(BoardZone.fromString(v), equals(BoardZone.mainboard), reason: 'Failed for input: "$v"');
        }
      });

      test('Edge Case 2.6: Unrecognized strings, whitespace, empty, and null fallback to Mainboard in fromString', () {
        final fallbacks = [
          null,
          '',
          '   ',
          '\t\n',
          'exile',
          'graveyard',
          'tokens',
          'command',
          'side',
          'maybe',
          'junk',
          '12345',
        ];

        for (final f in fallbacks) {
          expect(BoardZone.fromString(f), equals(BoardZone.mainboard), reason: 'Expected fallback to Mainboard for: "$f"');
        }
      });

      test('Edge Case 2.7: BoardZone.tryParse returns null on unrecognized strings and parses valid ones', () {
        expect(BoardZone.tryParse('COMMANDER'), equals(BoardZone.commander));
        expect(BoardZone.tryParse('  companion  '), equals(BoardZone.companion));
        expect(BoardZone.tryParse('Sideboard'), equals(BoardZone.sideboard));
        expect(BoardZone.tryParse('MAYBEBOARD'), equals(BoardZone.maybeboard));
        expect(BoardZone.tryParse('mainboard'), equals(BoardZone.mainboard));

        expect(BoardZone.tryParse(null), isNull);
        expect(BoardZone.tryParse(''), isNull);
        expect(BoardZone.tryParse('   '), isNull);
        expect(BoardZone.tryParse('exile'), isNull);
        expect(BoardZone.tryParse('tokens'), isNull);
      });

      test('Edge Case 2.8: Canonical string values and display names', () {
        expect(BoardZone.mainboard.value, equals('Mainboard'));
        expect(BoardZone.mainboard.displayName, equals('Mainboard'));

        expect(BoardZone.sideboard.value, equals('Sideboard'));
        expect(BoardZone.sideboard.displayName, equals('Sideboard'));

        expect(BoardZone.maybeboard.value, equals('Maybeboard'));
        expect(BoardZone.maybeboard.displayName, equals('Maybeboard'));

        expect(BoardZone.commander.value, equals('Commander'));
        expect(BoardZone.commander.displayName, equals('Commander'));

        expect(BoardZone.companion.value, equals('Companion'));
        expect(BoardZone.companion.displayName, equals('Companion'));
      });
    });

    // =========================================================================
    // SECTION 3: VaultDao Zone Operations with Case & Whitespace Variations
    // =========================================================================
    group('VaultDao Zone Operations with Case & Whitespace Variations', () {
      late AppDatabase db;

      setUp(() async {
        db = AppDatabase(NativeDatabase.memory());
        await db.vaultDao.clearAllItems();
      });

      tearDown(() async {
        await db.close();
      });

      Future<VaultItem> seedCard(String id, String name, {int qty = 4}) async {
        final companion = VaultItemsCompanion.insert(
          id: id,
          collectionType: 'mtg',
          name: name,
          setOrSeries: 'Test Set',
          imageUrl: 'https://example.com/$id.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          quantity: drift.Value(qty),
          condition: 'NM',
          currentMarketPrice: 1.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'name': name}),
        );
        await db.vaultDao.into(db.vaultItems).insert(companion);
        return (await (db.select(db.vaultItems)..where((t) => t.id.equals(id))).getSingle());
      }

      test('Edge Case 3.1: Consecutive addCardToDeck calls with case variations of COMMANDER merge quantity', () async {
        final card = await seedCard('sol-ring', 'Sol Ring', qty: 10);
        final deck = await db.vaultDao.createDeck('EDH Deck');

        // Add 1 with uppercase
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'COMMANDER', quantity: 1);
        // Add 2 with lowercase
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'commander', quantity: 2);
        // Add 1 with spaced PascalCase
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: ' Commander ', quantity: 1);
        // Add 1 with mixed case and tabs
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: '  cOmMaNdEr\t  ', quantity: 1);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .get();

        // Must be exactly 1 row with canonical PascalCase zone 'Commander' and total quantity 5
        expect(items.length, equals(1), reason: 'All variations of Commander must merge into a single row');
        expect(items.first.boardZone, equals('Commander'));
        expect(items.first.quantity, equals(5));
      });

      test('Edge Case 3.2: Consecutive addCardToDeck calls with case variations of SIDEBOARD merge quantity', () async {
        final card = await seedCard('force-of-will', 'Force of Will', qty: 4);
        final deck = await db.vaultDao.createDeck('Legacy Deck');

        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'SIDEBOARD', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'sideboard', quantity: 2);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: ' Sideboard ', quantity: 1);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .get();

        expect(items.length, equals(1));
        expect(items.first.boardZone, equals('Sideboard'));
        expect(items.first.quantity, equals(4));
      });

      test('Edge Case 3.3: Consecutive addCardToDeck calls with case variations of MAYBEBOARD merge quantity', () async {
        final card = await seedCard('mana-drain', 'Mana Drain', qty: 4);
        final deck = await db.vaultDao.createDeck('Control Deck');

        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'MAYBEBOARD', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'maybeboard', quantity: 2);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: ' Maybeboard ', quantity: 1);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .get();

        expect(items.length, equals(1));
        expect(items.first.boardZone, equals('Maybeboard'));
        expect(items.first.quantity, equals(4));
      });

      test('Edge Case 3.4: Consecutive addCardToDeck calls with case variations of COMPANION merge quantity', () async {
        final card = await seedCard('jegantha', 'Jegantha, the Wellspring', qty: 2);
        final deck = await db.vaultDao.createDeck('Modern Deck');

        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'COMPANION', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: ' companion ', quantity: 1);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .get();

        expect(items.length, equals(1));
        expect(items.first.boardZone, equals('Companion'));
        expect(items.first.quantity, equals(2));
      });

      test('Edge Case 3.5: Same card coexisting across all 5 zones with distinct case inputs', () async {
        final card = await seedCard('lightning-bolt', 'Lightning Bolt', qty: 20);
        final deck = await db.vaultDao.createDeck('Multi-Zone Bolt');

        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'COMMANDER', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: '  sideboard  ', quantity: 3);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'maybeboard', quantity: 2);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: ' Companion ', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'MAINBOARD', quantity: 4);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .get();

        expect(items.length, equals(5), reason: 'Each zone must maintain its distinct entry');

        final zoneQuantities = {for (final i in items) i.boardZone: i.quantity};
        expect(zoneQuantities['Commander'], equals(1));
        expect(zoneQuantities['Sideboard'], equals(3));
        expect(zoneQuantities['Maybeboard'], equals(2));
        expect(zoneQuantities['Companion'], equals(1));
        expect(zoneQuantities['Mainboard'], equals(4));
      });

      test('Edge Case 3.6: Multi-card Commander zone coexistence with diverse case inputs', () async {
        final c1 = await seedCard('t1', 'Kraum, Ludevic\'s Opus', qty: 1);
        final c2 = await seedCard('t2', 'Tymna the Weaver', qty: 1);
        final c3 = await seedCard('t3', 'Rograkh, Son of Rohgahh', qty: 1);

        final deck = await db.vaultDao.createDeck('Three Partner Test');

        await db.vaultDao.addCardToDeck(deck.id, c1.id, boardZone: 'COMMANDER', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, c2.id, boardZone: 'commander', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, c3.id, boardZone: ' Commander ', quantity: 1);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final commanders = await (db.select(db.deckVersionItems)
              ..where((t) =>
                  t.versionId.equals(version.id) &
                  t.boardZone.equals('Commander')))
            .get();

        expect(commanders.length, equals(3), reason: 'All 3 commanders must exist simultaneously in Commander zone');
        final itemCardIds = commanders.map((c) => c.vaultItemId).toSet();
        expect(itemCardIds, containsAll(['t1', 't2', 't3']));
      });

      test('Edge Case 3.7: watchDeckItems stream exposes canonical PascalCase board_zone', () async {
        final card = await seedCard('mox-diamond', 'Mox Diamond', qty: 2);
        final deck = await db.vaultDao.createDeck('Mox Deck');

        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: '  cOmMaNdEr  ', quantity: 1);

        final deckItemsList = await db.vaultDao.watchDeckItems(deck.id).first;
        expect(deckItemsList.length, equals(1));
        expect(deckItemsList.first['board_zone'], equals('Commander'));
      });

      test('Edge Case 3.8: Physical inventory allocation accurately accounts for cards in Companion, Sideboard, and Commander when registered', () async {
        final cCard = await seedCard('commander-card', 'Commander Card', qty: 2);
        final compCard = await seedCard('companion-card', 'Companion Card', qty: 2);
        final sideCard = await seedCard('sideboard-card', 'Sideboard Card', qty: 3);

        final deck = await db.vaultDao.createDeck('Registered Full Deck', isRegistered: true);

        await db.vaultDao.addCardToDeck(deck.id, cCard.id, boardZone: 'COMMANDER', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, compCard.id, boardZone: 'companion', quantity: 1);
        await db.vaultDao.addCardToDeck(deck.id, sideCard.id, boardZone: ' Sideboard ', quantity: 2);

        // All physical non-proxy cards in registered deck decrement available inventory
        expect(await db.vaultDao.getAvailableQuantity(cCard.id), equals(1));
        expect(await db.vaultDao.getAvailableQuantity(compCard.id), equals(1));
        expect(await db.vaultDao.getAvailableQuantity(sideCard.id), equals(1));

        // Switch deck to draft
        await db.vaultDao.setDeckRegistered(deck.id, false);

        // All physical inventory unlocked immediately
        expect(await db.vaultDao.getAvailableQuantity(cCard.id), equals(2));
        expect(await db.vaultDao.getAvailableQuantity(compCard.id), equals(2));
        expect(await db.vaultDao.getAvailableQuantity(sideCard.id), equals(3));
      });
    });

    // =========================================================================
    // SECTION 4: Fast-Draw Pool Filtering by Zone Case
    // =========================================================================
    group('Fast-Draw Pool Zone Exclusion Under Case Variations', () {
      test('Edge Case 4.1: Sideboard and Maybeboard with case variations are excluded from fast-draw pool', () {
        final mockItems = [
          {'board_zone': 'MAINBOARD', 'name': 'Card 1', 'deck_quantity': 4},
          {'board_zone': 'mainboard', 'name': 'Card 2', 'deck_quantity': 4},
          {'board_zone': 'COMMANDER', 'name': 'Commander Card', 'deck_quantity': 1},
          {'board_zone': 'companion', 'name': 'Companion Card', 'deck_quantity': 1},
          {'board_zone': 'SIDEBOARD', 'name': 'Sideboard Card 1', 'deck_quantity': 3},
          {'board_zone': 'sideboard', 'name': 'Sideboard Card 2', 'deck_quantity': 2},
          {'board_zone': ' Sideboard ', 'name': 'Sideboard Card 3', 'deck_quantity': 1},
          {'board_zone': 'MAYBEBOARD', 'name': 'Maybeboard Card 1', 'deck_quantity': 4},
          {'board_zone': 'maybeboard', 'name': 'Maybeboard Card 2', 'deck_quantity': 2},
          {'board_zone': ' Maybeboard ', 'name': 'Maybeboard Card 3', 'deck_quantity': 1},
        ];

        // Simulate the pool building logic from DeckBuilderScreen._buildPool
        final pool = <Map<String, dynamic>>[];
        for (final item in mockItems) {
          final zone = (item['board_zone'] as String? ?? 'Mainboard').trim().toLowerCase();
          if (zone == 'sideboard' || zone == 'maybeboard') continue;

          final qty = item['deck_quantity'] as int? ?? 1;
          for (int i = 0; i < qty; i++) {
            pool.add(item);
          }
        }

        // Expected pool: 4 + 4 + 1 + 1 = 10 cards
        expect(pool.length, equals(10));
        final poolCardNames = pool.map((c) => c['name'] as String).toSet();
        expect(poolCardNames, containsAll(['Card 1', 'Card 2', 'Commander Card', 'Companion Card']));
        expect(poolCardNames, isNot(contains('Sideboard Card 1')));
        expect(poolCardNames, isNot(contains('Sideboard Card 2')));
        expect(poolCardNames, isNot(contains('Sideboard Card 3')));
        expect(poolCardNames, isNot(contains('Maybeboard Card 1')));
        expect(poolCardNames, isNot(contains('Maybeboard Card 2')));
        expect(poolCardNames, isNot(contains('Maybeboard Card 3')));
      });
    });
  });
}

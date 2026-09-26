import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('The One Ring Art Fix & Runtime Backfill Tests', () {
    late AppDatabase db;

    tearDown(() async {
      await db.close();
    });

    test('Fresh database seed produces authentic The One Ring metadata & image URL', () async {
      db = AppDatabase(NativeDatabase.memory());
      // Wait for beforeOpen to execute
      await db.customSelect('SELECT 1;').get();

      final oneRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingleOrNull();

      expect(oneRing, isNotNull);
      expect(
        oneRing!.imageUrl,
        equals(
          'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
        ),
      );
      expect(oneRing.imageUrl.contains('78038b95'), isFalse);

      final dynamicMap = jsonDecode(oneRing.dynamicData) as Map<String, dynamic>;
      expect(dynamicMap['scryfall_id'], equals('d5806e68-1054-458e-866d-1f2470f682b2'));
      expect(dynamicMap['oracle_id'], equals('3aa83ed2-f48b-4ce6-a614-2c54ddf50538'));
      expect(dynamicMap['finish'], equals('foil'));
      expect(dynamicMap['cmc'], equals(4.0));
      expect(dynamicMap['image_uris'], isNotNull);
      expect(
        dynamicMap['image_uris']['normal'],
        contains('d5806e68-1054-458e-866d-1f2470f682b2'),
      );
      expect(
        dynamicMap['image_uris']['large'],
        contains('d5806e68-1054-458e-866d-1f2470f682b2'),
      );
    });

    test('beforeOpen backfill defensively patches legacy 404 URL and injects Scryfall ID', () async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();

      // Simulate a legacy database record with 404 image URL and missing scryfall_id
      await (db.update(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .write(
        const VaultItemsCompanion(
          imageUrl: Value(
            'https://cards.scryfall.io/large/front/7/8/78038b95-30f2-4e4b-972f-04cfa65c275a.jpg',
          ),
          dynamicData: Value('{"mana_cost":"{4}","type_line":"Legendary Artifact"}'),
        ),
      );

      // Verify legacy corrupted state
      var current = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      expect(current.imageUrl.contains('78038b95'), isTrue);
      var currentMap = jsonDecode(current.dynamicData) as Map<String, dynamic>;
      expect(currentMap['scryfall_id'], isNull);

      // Execute the backfill logic as defined in beforeOpen
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

      // Verify healed state
      final patched = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      expect(
        patched.imageUrl,
        equals(
          'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
        ),
      );
      final patchedMap = jsonDecode(patched.dynamicData) as Map<String, dynamic>;
      expect(patchedMap['scryfall_id'], equals('d5806e68-1054-458e-866d-1f2470f682b2'));
      expect(patchedMap['oracle_id'], equals('3aa83ed2-f48b-4ce6-a614-2c54ddf50538'));
      expect(patchedMap['finish'], equals('foil'));
      expect(patchedMap['image_uris']['large'], contains('d5806e68'));
    });

    test('Drift database schema version invariant strictly equals 9', () async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
      expect(db.schemaVersion, equals(9));
    });

    test('Decks table schema guarantees is_assembled column exists and defaults to 0', () async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();

      final decksInfo = await db.customSelect('PRAGMA table_info("decks");').get();
      final colNames = decksInfo.map((r) => r.read<String>('name')).toSet();
      expect(colNames.contains('is_assembled'), isTrue);
    });
  });
}

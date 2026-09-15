import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';

void main() {
  group('Requirement R3: Text Sanitizer Helper', () {
    test('sanitize() converts to lowercase and strips all non-alphanumeric characters', () {
      expect(sanitize('Sol Ring'), equals('solring'));
      expect(sanitize("Urza's Saga"), equals('urzassaga'));
      expect(sanitize('Urza’s Saga'), equals('urzassaga'));
      expect(sanitize('"Lifetime" Pass Holder'), equals('lifetimepassholder'));
      expect(sanitize('Boseiju, Who Endures'), equals('boseijuwhoendures'));
      expect(sanitize('Black Lotus, Alpha-Edition!'), equals('blacklotusalphaedition'));
      expect(sanitize('123/250'), equals('123250'));
      expect(sanitize('#001 (Serialized @ \$500)'), equals('001serialized500'));
      expect(sanitize('Fire // Ice'), equals('fireice'));
      expect(sanitize('   spaces and symbols --- *** '), equals('spacesandsymbols'));
      expect(sanitize(''), equals(''));
      expect(sanitize('---***___'), equals(''));
    });

    test('OcrHeuristicMatcher.sanitize matches top-level sanitize helper', () {
      expect(OcrHeuristicMatcher.sanitize('Sol Ring'), equals(sanitize('Sol Ring')));
      expect(OcrHeuristicMatcher.sanitize("Urza's Saga"), equals(sanitize("Urza's Saga")));
      expect(OcrHeuristicMatcher.sanitize('"Lifetime" Pass Holder'), equals(sanitize('"Lifetime" Pass Holder')));
    });

    test('OcrHeuristicMatcher.sanitizeText is preserved for backward compatibility', () {
      expect(OcrHeuristicMatcher.sanitizeText('"Lifetime" Pass Holder'), equals('lifetime pass holder'));
      expect(OcrHeuristicMatcher.sanitizeText("Urza's Saga"), equals('urzas saga'));
      expect(OcrHeuristicMatcher.sanitizeText('Black Lotus, Alpha-Edition!'), equals('black lotus alphaedition'));
    });
  });

  group('Requirement R3: Hybrid Matching Engine (Dart + SQLite)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      // Seed catalog cards (quantity: 0)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-sol-ring',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'Commander Masters',
              imageUrl: 'https://example.com/solring.jpg',
              acquiredPrice: 1.5,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number":"400","rarity":"uncommon"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-urzas-saga',
              collectionType: 'mtg',
              name: "Urza's Saga",
              setOrSeries: 'Modern Horizons 2',
              imageUrl: 'https://example.com/urza.jpg',
              acquiredPrice: 35.0,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 42.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number":"259","rarity":"rare"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-lifetime-pass-holder',
              collectionType: 'mtg',
              name: '"Lifetime" Pass Holder',
              setOrSeries: 'Unfinity',
              imageUrl: 'https://example.com/lifetime.jpg',
              acquiredPrice: 0.15,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 0.25,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number":"201","rarity":"uncommon"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-black-lotus',
              collectionType: 'mtg',
              name: 'Black Lotus',
              setOrSeries: 'Alpha',
              imageUrl: 'https://example.com/lotus.jpg',
              acquiredPrice: 10000.0,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 25000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number":"232","rarity":"rare"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-obyra',
              collectionType: 'mtg',
              name: "Obyra's Attendants // Desperate Parry",
              setOrSeries: 'Wilds of Eldraine',
              imageUrl: 'https://example.com/obyra.jpg',
              acquiredPrice: 0.25,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 0.35,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number":"061","rarity":"common"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-one-ring',
              collectionType: 'mtg',
              name: 'The One Ring (Serialized #001/100)',
              setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
              imageUrl: 'https://example.com/onering.jpg',
              acquiredPrice: 2000000.0,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 2000000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number":"001"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'pokemon-charizard',
              collectionType: 'pokemon',
              name: 'Charizard ex',
              setOrSeries: 'Obsidian Flames',
              imageUrl: 'https://example.com/charizard.jpg',
              acquiredPrice: 60.0,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 75.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number": "125"}', // Note space after colon
            ),
          );

      // Seed owned inventory card (quantity: 1)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-owned-mox-diamond',
              collectionType: 'mtg',
              name: 'Mox Diamond',
              setOrSeries: 'Stronghold',
              imageUrl: 'https://example.com/mox.jpg',
              acquiredPrice: 500.0,
              acquiredDate: DateTime.now(),
              quantity: const Value(1),
              condition: 'LP',
              isGraded: const Value(false),
              currentMarketPrice: 650.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number":"138"}',
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('Step 1: explicit collectorNumber overrides name query via dynamic_data', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['Completely Irrelevant Text', 'Random Noise Line'],
        'mtg',
        collectorNumber: '400',
      );
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-sol-ring'));
      expect(match.name, equals('Sol Ring'));
    });

    test('Step 1: fraction collector number in OCR lines overrides name matching', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['Artifact', 'Tap: Add 3 mana', '232/250'],
        'mtg',
      );
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-black-lotus'));
      expect(match.name, equals('Black Lotus'));
    });

    test('Step 1: set-dash collector number (SV03-125) overrides name matching', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['HP 330', 'Infernal Reign', 'SV03-125'],
        'pokemon',
      );
      expect(match, isNotNull);
      expect(match!.id, equals('pokemon-charizard'));
      expect(match.name, equals('Charizard ex'));
    });

    test('Step 1: creature stat box (5/5) does NOT falsely trigger collector number override', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['5/5', 'Some Random Text'],
        'mtg',
      );
      expect(match, isNull);
    });

    test('Step 2 & 3: matches card when OCR line has trailing card type noise', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['Sol Ring Artifact 1'],
        'mtg',
      );
      expect(match, isNotNull);
      expect(match!.name, equals('Sol Ring'));
      expect(match.id, equals('mtg-sol-ring'));
    });

    test('Step 2 & 3: matches card with leading/enclosing quotes like "Lifetime" Pass Holder', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['lifetime pass holder'],
        'mtg',
      );
      expect(match, isNotNull);
      expect(match!.name, equals('"Lifetime" Pass Holder'));
      expect(match.id, equals('mtg-lifetime-pass-holder'));
    });

    test('Step 2 & 3: matches split/adventure card via base name containment', () async {
      final match = await db.vaultDao.matchScannedCard(
        ["Obyra's Attendants 1U Creature"],
        'mtg',
      );
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-obyra'));
      expect(match.name, equals("Obyra's Attendants // Desperate Parry"));
    });

    test('Step 2 & 3: matches card with parenthesized subtitle/variant', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['The One Ring Legendary Artifact'],
        'mtg',
      );
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-one-ring'));
      expect(match.name, equals('The One Ring (Serialized #001/100)'));
    });

    test('Step 2 & 3: matches card with apostrophes (straight and curly)', () async {
      final matchStraight = await db.vaultDao.matchScannedCard(
        ["Urza's Saga Enchantment Land"],
        'mtg',
      );
      expect(matchStraight, isNotNull);
      expect(matchStraight!.id, equals('mtg-urzas-saga'));

      final matchCurly = await db.vaultDao.matchScannedCard(
        ['Urza’s Saga Enchantment Land'],
        'mtg',
      );
      expect(matchCurly, isNotNull);
      expect(matchCurly!.id, equals('mtg-urzas-saga'));
    });

    test('Step 2 & 3: rejects noise text that shares first 5 chars but fails contains check', () async {
      // "Solarion" or prefix "solar" would not match if it were in DB
      final match = await db.vaultDao.matchScannedCard(
        ['tap to add mana', 'wizards of the coast', 'illustrator mark tedin'],
        'mtg',
      );
      expect(match, isNull);
    });

    test('Fallback: matches owned inventory card (quantity > 0) when no catalog card exists', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['Mox Diamond Artifact 0'],
        'mtg',
      );
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-owned-mox-diamond'));
      expect(match.name, equals('Mox Diamond'));
    });

    test('Fallback: matches cross-collection card when activeContext does not match', () async {
      // Active context is mtg, but Charizard ex is pokemon
      final match = await db.vaultDao.matchScannedCard(
        ['Charizard ex Stage 2'],
        'mtg',
      );
      expect(match, isNotNull);
      expect(match!.id, equals('pokemon-charizard'));
      expect(match.collectionType, equals('pokemon'));
    });
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();

    // 1. Seed "\"Lifetime\" Pass Holder" (alphabetically first due to leading quote)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'mtg-lifetime-pass-holder',
            collectionType: 'mtg',
            name: '"Lifetime" Pass Holder',
            setOrSeries: 'Unfinity',
            imageUrl: 'https://example.com/lifetime.jpg',
            acquiredPrice: 0.15,
            acquiredDate: DateTime.now(),
            quantity: const Value(0), // Catalog card
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 0.25,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"collector_number":"201","rarity":"uncommon"}',
          ),
        );

    // 2. Seed other standard MTG catalog cards
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
            id: 'mtg-boseiju',
            collectionType: 'mtg',
            name: 'Boseiju, Who Endures',
            setOrSeries: 'Kamigawa: Neon Dynasty',
            imageUrl: 'https://example.com/boseiju.jpg',
            acquiredPrice: 30.0,
            acquiredDate: DateTime.now(),
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 38.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"collector_number":"266","rarity":"rare"}',
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
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 3.5: "Lifetime Pass Holder" Bug Fix & Return Integrity', () {
    test('empty string and short noise lines (< 3 chars) immediately return null without querying', () async {
      // 1. Completely empty list
      final emptyResult = await db.vaultDao.matchScannedCard([], 'mtg');
      expect(emptyResult, isNull);

      // 2. Lines that are whitespace or < 3 chars
      final noiseResult = await db.vaultDao.matchScannedCard(['', '  ', 'a', '1', '--', "''"], 'mtg');
      expect(noiseResult, isNull);

      // 3. Punctuation only
      final punctResult = await db.vaultDao.matchScannedCard([',', '"', "'", '-'], 'mtg');
      expect(punctResult, isNull);
    });

    test('random OCR noise NEVER defaults to "Lifetime" Pass Holder', () async {
      final noiseLines = [
        'tap to add mana',
        'flavor text here',
        'illustrator mark tedin',
        'wizards of the coast',
      ];

      final match = await db.vaultDao.matchScannedCard(noiseLines, 'mtg');
      expect(match, isNull, reason: 'Arbitrary text must never match "Lifetime" Pass Holder');
    });

    test('properly escapes single quotes in OCR text without throwing SQLite syntax error', () async {
      // OCR line with single quote
      final match = await db.vaultDao.matchScannedCard(["urza's saga"], 'mtg');
      expect(match, isNotNull);
      expect(match!.name, equals("Urza's Saga"));

      // Sanitized OCR line without single quote
      final matchSanitized = await db.vaultDao.matchScannedCard(["urzas saga"], 'mtg');
      expect(matchSanitized, isNotNull);
      expect(matchSanitized!.name, equals("Urza's Saga"));
    });

    test('exact line-by-line match returns correct card', () async {
      final lines = ['sol ring', 'artifact', 'tap add cc'];
      final match = await db.vaultDao.matchScannedCard(lines, 'mtg');
      expect(match, isNotNull);
      expect(match!.name, equals('Sol Ring'));
      expect(match.id, equals('mtg-sol-ring'));
    });

    test('correctly matches "Lifetime" Pass Holder ONLY when specifically scanned', () async {
      // Cleaned line with quotes stripped
      final matchClean = await db.vaultDao.matchScannedCard(['lifetime pass holder'], 'mtg');
      expect(matchClean, isNotNull);
      expect(matchClean!.id, equals('mtg-lifetime-pass-holder'));

      // Raw OCR line with quotes
      final matchRaw = await db.vaultDao.matchScannedCard(['"Lifetime" Pass Holder'], 'mtg');
      expect(matchRaw, isNotNull);
      expect(matchRaw!.id, equals('mtg-lifetime-pass-holder'));
    });

    test('correctly matches card names with commas (e.g. Boseiju, Who Endures)', () async {
      final match = await db.vaultDao.matchScannedCard(['boseiju who endures'], 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-boseiju'));
      expect(match.name, equals('Boseiju, Who Endures'));
    });

    test('correctly matches split / adventure cards by front-face name', () async {
      final match = await db.vaultDao.matchScannedCard(['obyras attendants'], 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-obyra'));
      expect(match.name, equals("Obyra's Attendants // Desperate Parry"));
    });

    test('correctly matches smart curly apostrophes (e.g. Urza’s Saga)', () async {
      final match = await db.vaultDao.matchScannedCard(['urza’s saga'], 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-urzas-saga'));
    });

    test('collector number override prioritizes collector number match over name', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['random card text'],
        'mtg',
        collectorNumber: '400',
      );
      expect(match, isNotNull);
      expect(match!.name, equals('Sol Ring'));
    });

    test('OcrHeuristicMatcher.sanitizeText removes all punctuation and lowercases', () {
      expect(OcrHeuristicMatcher.sanitizeText('"Lifetime" Pass Holder'), equals('lifetime pass holder'));
      expect(OcrHeuristicMatcher.sanitizeText("Urza's Saga"), equals('urzas saga'));
      expect(OcrHeuristicMatcher.sanitizeText('Black Lotus, Alpha-Edition!'), equals('black lotus alphaedition'));
      expect(OcrHeuristicMatcher.sanitizeText('---'), equals(''));
    });

    test('OcrHeuristicMatcher.sanitizeLines filters out noise lines shorter than 3 chars', () {
      final rawLines = [
        'Sol Ring',
        '--',
        '1',
        'Artifact',
        '',
        '  ',
      ];
      final cleaned = OcrHeuristicMatcher.sanitizeLines(rawLines);
      expect(cleaned, equals(['sol ring', 'artifact']));
    });
  });
}

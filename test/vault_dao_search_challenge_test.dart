import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultDao Adversarial Challenge: Secret Lairs, Flavor Names & Search Robustness', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.ensureSecretLairIndexes();

      // 1. Standard Secret Lair Drop card with flavor name (Universes Beyond: Marvel / X-Men)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ozolith-sld',
          collectionType: 'mtg',
          name: 'The Ozolith',
          flavorName: const drift.Value('Adamantium Bonding Tank'),
          setOrSeries: 'Secret Lair Drop',
          imageUrl: 'https://cards.scryfall.io/large/front/ozolith.jpg',
          acquiredPrice: 25.00,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(2),
          condition: 'NM',
          currentMarketPrice: 35.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'sld',
            'set_code': 'sld',
            'set_name': 'Secret Lair Drop',
            'is_universes_beyond': true,
            'promo_types': ['universes_beyond'],
            'flavor_name': 'Adamantium Bonding Tank',
          }),
        ),
      );

      // 2. Secret Lair card with code 'SLD' in setOrSeries and no flavor name
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-solring-sld',
          collectionType: 'mtg',
          name: 'Sol Ring',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'SLD',
          imageUrl: 'https://cards.scryfall.io/large/front/solring.jpg',
          acquiredPrice: 15.00,
          acquiredDate: DateTime(2024, 2, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 20.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'sld',
            'set_code': 'sld',
            'set_name': 'Secret Lair Drop',
            'is_universes_beyond': false,
          }),
        ),
      );

      // 3. Secret Lair card with mixed-case 'sLd' and uppercase 'SLD' inside dynamicData
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-demonic-sld',
          collectionType: 'mtg',
          name: 'Demonic Tutor',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Secret Lair',
          imageUrl: 'https://cards.scryfall.io/large/front/demonic.jpg',
          acquiredPrice: 40.00,
          acquiredDate: DateTime(2024, 3, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 50.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'SLD',
            'set_code': 'sLd',
            'set_name': 'Secret Lair',
            'is_universes_beyond': false,
          }),
        ),
      );

      // 4. Secret Lair 30th Anniversary variation
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-bolt-sld',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Secret Lair: 30th Anniversary',
          imageUrl: 'https://cards.scryfall.io/large/front/bolt.jpg',
          acquiredPrice: 8.00,
          acquiredDate: DateTime(2024, 4, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 12.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'sld',
            'set_code': 'sld',
            'set_name': 'Secret Lair: 30th Anniversary',
          }),
        ),
      );

      // 5. Godzilla series flavor card (Ikoria: Lair of Behemoths - has 'Lair' in set name!)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-godzilla-iko',
          collectionType: 'mtg',
          name: 'Zilortha, Strength Incarnate',
          flavorName: const drift.Value('Godzilla, King of the Monsters'),
          setOrSeries: 'Ikoria: Lair of Behemoths',
          imageUrl: 'https://cards.scryfall.io/large/front/godzilla.jpg',
          acquiredPrice: 10.00,
          acquiredDate: DateTime(2020, 5, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 18.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'iko',
            'set_code': 'iko',
            'set_name': 'Ikoria: Lair of Behemoths',
            'flavor_name': 'Godzilla, King of the Monsters',
            'is_universes_beyond': false,
          }),
        ),
      );

      // 6. Card with single quote and special chars in name: Urza's Saga
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-urza-mh2',
          collectionType: 'mtg',
          name: "Urza's Saga",
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Modern Horizons 2',
          imageUrl: 'https://cards.scryfall.io/large/front/urza.jpg',
          acquiredPrice: 30.00,
          acquiredDate: DateTime(2021, 6, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 42.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'mh2',
            'set_code': 'mh2',
            'type_line': "Enchantment Land — Urza's Saga",
          }),
        ),
      );

      // 7. Non-ASCII accented card: Dandân
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-dandan-arn',
          collectionType: 'mtg',
          name: 'Dandân',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Arabian Nights',
          imageUrl: 'https://cards.scryfall.io/large/front/dandan.jpg',
          acquiredPrice: 5.00,
          acquiredDate: DateTime(2022, 1, 1),
          quantity: const drift.Value(4),
          condition: 'LP',
          currentMarketPrice: 8.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'arn',
            'set_code': 'arn',
          }),
        ),
      );

      // 8. Non-ASCII diphthong card: Æther Vial
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-aether-dst',
          collectionType: 'mtg',
          name: 'Æther Vial',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Darksteel',
          imageUrl: 'https://cards.scryfall.io/large/front/aether.jpg',
          acquiredPrice: 10.00,
          acquiredDate: DateTime(2022, 2, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 14.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'dst',
            'set_code': 'dst',
          }),
        ),
      );

      // 9. Multi-faced card with dual flavor name: Front Flavor // Back Flavor
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-dfc-flavor',
          collectionType: 'mtg',
          name: 'Jacob Hauken, Inspector // Hauken\'s Insight',
          flavorName: const drift.Value('Investigator Holmes // Mind Palace'),
          setOrSeries: 'Innistrad: Crimson Vow',
          imageUrl: 'https://cards.scryfall.io/large/front/jacob.jpg',
          acquiredPrice: 2.00,
          acquiredDate: DateTime(2022, 3, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 3.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'layout': 'transform',
            'set': 'vow',
            'flavor_name': 'Investigator Holmes // Mind Palace',
          }),
        ),
      );

      // 10. Catalog unowned Secret Lair item (quantity = 0)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sld-unowned',
          collectionType: 'mtg',
          name: 'Brainstorm',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Secret Lair Drop',
          imageUrl: 'https://cards.scryfall.io/large/front/brainstorm.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime(2024, 5, 1),
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 10.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'sld',
            'set_code': 'sld',
            'set_name': 'Secret Lair Drop',
          }),
        ),
      );

      // 11. INBOX holding item (should be excluded from standard collection queries)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sld-inbox',
          collectionType: 'mtg',
          name: 'Mana Crypt',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Secret Lair Drop',
          imageUrl: 'https://cards.scryfall.io/large/front/crypt.jpg',
          acquiredPrice: 150.0,
          acquiredDate: DateTime(2024, 6, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 180.00,
          lastPriceUpdate: DateTime.now(),
          primaryBinderId: const drift.Value('INBOX'),
          dynamicData: jsonEncode({
            'set': 'sld',
            'set_code': 'sld',
          }),
        ),
      );

      // 12. Pokémon card (cross-collection control)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-pika-base',
          collectionType: 'pokemon',
          name: 'Pikachu',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Base Set',
          imageUrl: 'https://cards.pokemon.io/pika.jpg',
          acquiredPrice: 20.0,
          acquiredDate: DateTime(1999, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 50.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'base1',
          }),
        ),
      );

      // 13. Alpha control card
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-lotus-alpha',
          collectionType: 'mtg',
          name: 'Black Lotus',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Limited Edition Alpha',
          imageUrl: 'https://cards.scryfall.io/large/front/lotus.jpg',
          acquiredPrice: 5000.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 10000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'lea',
            'set_code': 'lea',
            'set_name': 'Limited Edition Alpha',
          }),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // CHALLENGE 1: SECRET LAIRS CASE SENSITIVITY & PARTIAL MATCHING
    // =========================================================================
    group('1. Secret Lairs Case Sensitivity & Partial Matching', () {
      final sldCaseVariations = [
        'sld',
        'SLD',
        'sLd',
        'Sld',
        'slD',
        'sLD',
        'Secret Lair',
        'SECRET LAIR',
        'secret lair',
        'sEcReT lAiR',
        'Secret Lair Drop',
        'SECRET LAIR DROP',
        'secret lair drop',
        '  sld  ',
        '  SLD  ',
        '  sLd  ',
        '  Secret Lair  ',
        '  Secret Lair Drop  ',
      ];

      for (final query in sldCaseVariations) {
        test('searchCatalogCards matches Secret Lairs for query: "$query"', () async {
          final results = await db.vaultDao.searchCatalogCards(query);
          final resultIds = results.map((c) => c.id).toSet();

          // Must match the core Secret Lair cards
          expect(resultIds.contains('card-ozolith-sld'), isTrue,
              reason: 'Failed to match card-ozolith-sld for "$query"');
          expect(resultIds.contains('card-solring-sld'), isTrue,
              reason: 'Failed to match card-solring-sld for "$query"');
          expect(resultIds.contains('card-demonic-sld'), isTrue,
              reason: 'Failed to match card-demonic-sld for "$query"');
          expect(resultIds.contains('card-bolt-sld'), isTrue,
              reason: 'Failed to match card-bolt-sld for "$query"');

          // Must NOT match non-Secret Lair Alpha card
          expect(resultIds.contains('card-lotus-alpha'), isFalse,
              reason: 'Incorrectly matched card-lotus-alpha for "$query"');
          // Must NOT match Pokemon card
          expect(resultIds.contains('card-pika-base'), isFalse,
              reason: 'Incorrectly matched Pokemon card for "$query"');
        });

        test('getItemsByCollection matches Secret Lairs for query: "$query"', () async {
          final results = await db.vaultDao.getItemsByCollection('mtg', searchQuery: query);
          final resultIds = results.map((c) => c.id).toSet();

          expect(resultIds.contains('card-ozolith-sld'), isTrue,
              reason: 'getItemsByCollection failed for card-ozolith-sld with "$query"');
          expect(resultIds.contains('card-solring-sld'), isTrue,
              reason: 'getItemsByCollection failed for card-solring-sld with "$query"');
          expect(resultIds.contains('card-demonic-sld'), isTrue,
              reason: 'getItemsByCollection failed for card-demonic-sld with "$query"');
          expect(resultIds.contains('card-bolt-sld'), isTrue,
              reason: 'getItemsByCollection failed for card-bolt-sld with "$query"');

          expect(resultIds.contains('card-lotus-alpha'), isFalse);
          expect(resultIds.contains('card-pika-base'), isFalse);
        });

        test('watchItemsByCollection reactive stream matches Secret Lairs for query: "$query"', () async {
          final results = await db.vaultDao.watchItemsByCollection('mtg', searchQuery: query).first;
          final resultIds = results.map((c) => c.id).toSet();

          expect(resultIds.contains('card-ozolith-sld'), isTrue);
          expect(resultIds.contains('card-solring-sld'), isTrue);
          expect(resultIds.contains('card-demonic-sld'), isTrue);
          expect(resultIds.contains('card-bolt-sld'), isTrue);
          expect(resultIds.contains('card-lotus-alpha'), isFalse);
        });
      }

      test('partial set name matching: "Secret", "Lair", "Drop"', () async {
        // Query 'Secret' should match all Secret Lairs
        final secretResults = await db.vaultDao.searchCatalogCards('Secret');
        final secretIds = secretResults.map((c) => c.id).toSet();
        expect(secretIds.contains('card-ozolith-sld'), isTrue);
        expect(secretIds.contains('card-demonic-sld'), isTrue);
        expect(secretIds.contains('card-bolt-sld'), isTrue);
        expect(secretIds.contains('card-lotus-alpha'), isFalse);

        // Query 'Lair' should match Secret Lairs AND Ikoria: Lair of Behemoths
        final lairResults = await db.vaultDao.searchCatalogCards('Lair');
        final lairIds = lairResults.map((c) => c.id).toSet();
        expect(lairIds.contains('card-ozolith-sld'), isTrue);
        expect(lairIds.contains('card-godzilla-iko'), isTrue);
        expect(lairIds.contains('card-lotus-alpha'), isFalse);

        // Query 'Drop' should match Secret Lair Drop
        final dropResults = await db.vaultDao.searchCatalogCards('Drop');
        final dropIds = dropResults.map((c) => c.id).toSet();
        expect(dropIds.contains('card-ozolith-sld'), isTrue);
        expect(dropIds.contains('card-lotus-alpha'), isFalse);
      });

      test('dedicated Secret Lair DAO methods: watchSecretLairItems & getSecretLairItems', () async {
        final getResults = await db.vaultDao.getSecretLairItems();
        final getIds = getResults.map((c) => c.id).toSet();

        expect(getIds.contains('card-ozolith-sld'), isTrue);
        expect(getIds.contains('card-solring-sld'), isTrue);
        expect(getIds.contains('card-demonic-sld'), isTrue);
        expect(getIds.contains('card-bolt-sld'), isTrue);
        expect(getIds.contains('card-sld-unowned'), isTrue);
        // Excluded from standard inventory if in INBOX
        expect(getIds.contains('card-sld-inbox'), isFalse);
        expect(getIds.contains('card-lotus-alpha'), isFalse);
        expect(getIds.contains('card-godzilla-iko'), isFalse);

        // Test onlyOwned filter on Secret Lairs
        final ownedOnly = await db.vaultDao.getSecretLairItems(onlyOwned: true);
        final ownedIds = ownedOnly.map((c) => c.id).toSet();
        expect(ownedIds.contains('card-sld-unowned'), isFalse);
        expect(ownedIds.contains('card-ozolith-sld'), isTrue);

        // Test watch stream
        final streamResults = await db.vaultDao.watchSecretLairItems().first;
        expect(streamResults.map((c) => c.id).toSet(), equals(getIds));
      });
    });

    // =========================================================================
    // CHALLENGE 2: FLAVOR NAME & UNDERLYING ORACLE CARD NAME SEARCH
    // =========================================================================
    group('2. Flavor Name & Underlying Oracle Name Search', () {
      final flavorQueries = [
        'Adamantium Bonding Tank',
        'adamantium bonding tank',
        'ADAMANTIUM BONDING TANK',
        'aDaMaNtIuM bOnDiNg TaNk',
        'Adamantium',
        'adamantium',
        'ADAMANTIUM',
        'Bonding',
        'bonding',
        'BONDING',
        'Tank',
        'tank',
        'TANK',
        'Bonding Tank',
        'bonding tank',
        'BONDING TANK',
        'Adamantium Bonding',
        'adamantium bonding',
        'manti',
        'damant',
        'onding',
        '  Adamantium Bonding Tank  ',
        '  adamantium  ',
      ];

      for (final q in flavorQueries) {
        test('flavor name query "$q" returns underlying card "The Ozolith"', () async {
          final resCatalog = await db.vaultDao.searchCatalogCards(q);
          expect(resCatalog.any((c) => c.id == 'card-ozolith-sld'), isTrue,
              reason: 'searchCatalogCards failed for "$q"');
          expect(resCatalog.firstWhere((c) => c.id == 'card-ozolith-sld').name, 'The Ozolith');

          final resCollection = await db.vaultDao.getItemsByCollection('mtg', searchQuery: q);
          expect(resCollection.any((c) => c.id == 'card-ozolith-sld'), isTrue,
              reason: 'getItemsByCollection failed for "$q"');

          final resStream = await db.vaultDao.watchItemsByCollection('mtg', searchQuery: q).first;
          expect(resStream.any((c) => c.id == 'card-ozolith-sld'), isTrue,
              reason: 'watchItemsByCollection failed for "$q"');
        });
      }

      final oracleQueries = [
        'The Ozolith',
        'the ozolith',
        'THE OZOLITH',
        'tHe OzOlItH',
        'Ozolith',
        'ozolith',
        'OZOLITH',
        'zolith',
        '  The Ozolith  ',
        '  ozolith  ',
      ];

      for (final q in oracleQueries) {
        test('underlying oracle card name query "$q" returns "The Ozolith"', () async {
          final res = await db.vaultDao.searchCatalogCards(q);
          expect(res.any((c) => c.id == 'card-ozolith-sld'), isTrue,
              reason: 'Oracle name query "$q" failed');
          expect(res.firstWhere((c) => c.id == 'card-ozolith-sld').flavorName, 'Adamantium Bonding Tank');
        });
      }

      test('secondary flavor card Godzilla returns Zilortha', () async {
        final godzillaQueries = [
          'Godzilla',
          'godzilla',
          'GODZILLA',
          'King of the Monsters',
          'king of the monsters',
          'Zilortha',
          'zilortha',
          'Zilortha, Strength Incarnate',
        ];

        for (final gq in godzillaQueries) {
          final res = await db.vaultDao.searchCatalogCards(gq);
          expect(res.any((c) => c.id == 'card-godzilla-iko'), isTrue,
              reason: 'Failed to find Godzilla/Zilortha with query "$gq"');
        }
      });

      test('multi-faced card dual flavor name search', () async {
        // Front flavor
        final frontRes = await db.vaultDao.searchCatalogCards('Investigator Holmes');
        expect(frontRes.any((c) => c.id == 'card-dfc-flavor'), isTrue);

        // Back flavor
        final backRes = await db.vaultDao.searchCatalogCards('Mind Palace');
        expect(backRes.any((c) => c.id == 'card-dfc-flavor'), isTrue);

        // Combined delimiter
        final combinedRes = await db.vaultDao.searchCatalogCards('Investigator Holmes // Mind Palace');
        expect(combinedRes.any((c) => c.id == 'card-dfc-flavor'), isTrue);

        // Front oracle name
        final nameRes = await db.vaultDao.searchCatalogCards('Jacob Hauken');
        expect(nameRes.any((c) => c.id == 'card-dfc-flavor'), isTrue);
      });
    });

    // =========================================================================
    // CHALLENGE 3: EMPTY QUERIES, WHITESPACE QUERIES & SPECIAL CHARACTERS
    // =========================================================================
    group('3. Empty Queries, Whitespace & Special Characters', () {
      test('empty string query returns unconstrained list without throwing', () async {
        final catalogAll = await db.vaultDao.searchCatalogCards('');
        expect(catalogAll.isNotEmpty, isTrue);

        final itemsAll = await db.vaultDao.getItemsByCollection('mtg', searchQuery: '');
        expect(itemsAll.isNotEmpty, isTrue);

        final itemsNull = await db.vaultDao.getItemsByCollection('mtg', searchQuery: null);
        expect(itemsNull.length, equals(itemsAll.length));

        final streamAll = await db.vaultDao.watchItemsByCollection('mtg', searchQuery: '').first;
        expect(streamAll.length, equals(itemsAll.length));
      });

      test('whitespace-only queries are safely normalized to unconstrained search', () async {
        final whitespaceInputs = [
          ' ',
          '   ',
          '\t',
          '\n',
          '\r\n',
          ' \t \n \r ',
        ];

        final baseline = await db.vaultDao.getItemsByCollection('mtg', searchQuery: null);

        for (final ws in whitespaceInputs) {
          final resCatalog = await db.vaultDao.searchCatalogCards(ws);
          expect(resCatalog.isNotEmpty, isTrue, reason: 'searchCatalogCards was empty for "$ws"');

          final resCollection = await db.vaultDao.getItemsByCollection('mtg', searchQuery: ws);
          expect(resCollection.length, equals(baseline.length),
              reason: 'getItemsByCollection count differed for "$ws"');

          final resStream = await db.vaultDao.watchItemsByCollection('mtg', searchQuery: ws).first;
          expect(resStream.length, equals(baseline.length),
              reason: 'watchItemsByCollection count differed for "$ws"');
        }
      });

      test('single quote and apostrophe searches match accurately without SQL syntax errors', () async {
        // Query "Urza's" should match Urza's Saga
        final urzaRes = await db.vaultDao.searchCatalogCards("Urza's");
        expect(urzaRes.any((c) => c.id == 'card-urza-mh2'), isTrue);

        final singleQuoteOnly = await db.vaultDao.searchCatalogCards("'");
        // Must execute safely and match items with quotes
        expect(singleQuoteOnly.any((c) => c.id == 'card-urza-mh2'), isTrue);
        expect(singleQuoteOnly.any((c) => c.id == 'card-dfc-flavor'), isTrue);

        final multipleQuotes = await db.vaultDao.searchCatalogCards("'''");
        expect(multipleQuotes, isA<List<VaultItem>>());
      });

      test('double quote searches execute safely', () async {
        final doubleQuote = await db.vaultDao.searchCatalogCards('"');
        expect(doubleQuote, isA<List<VaultItem>>());

        final phraseInQuotes = await db.vaultDao.searchCatalogCards('"The Ozolith"');
        expect(phraseInQuotes, isA<List<VaultItem>>());
      });

      test('wildcard characters (% and _) execute safely without unhandled regex/escape errors', () async {
        // In SQLite LIKE, % is a wildcard. Drift handles parameterized queries.
        final percentQuery = await db.vaultDao.searchCatalogCards('%');
        expect(percentQuery, isA<List<VaultItem>>());

        final underscoreQuery = await db.vaultDao.searchCatalogCards('_');
        expect(underscoreQuery, isA<List<VaultItem>>());

        final backslashQuery = await db.vaultDao.searchCatalogCards('\\');
        expect(backslashQuery, isA<List<VaultItem>>());
      });

      test('dividers, symbols, and punctuation execute safely', () async {
        // Slash divider used in DFCs / Adventures
        final slashRes = await db.vaultDao.searchCatalogCards(' // ');
        expect(slashRes.any((c) => c.id == 'card-dfc-flavor'), isTrue);

        // Brackets & Mana symbols
        final bracketRes = await db.vaultDao.searchCatalogCards('{2}{U}');
        expect(bracketRes, isA<List<VaultItem>>());

        final punctuation = [
          ',',
          '-',
          ':',
          ';',
          '!',
          '?',
          '.',
          '(',
          ')',
          '[',
          ']',
          '{',
          '}',
        ];
        for (final p in punctuation) {
          final res = await db.vaultDao.searchCatalogCards(p);
          expect(res, isA<List<VaultItem>>(), reason: 'Failed on punctuation "$p"');
        }
      });

      test('non-ASCII, unicode, accents, and emojis execute safely', () async {
        // Dandân
        final dandanExact = await db.vaultDao.searchCatalogCards('Dandân');
        expect(dandanExact.any((c) => c.id == 'card-dandan-arn'), isTrue);

        final dandanLower = await db.vaultDao.searchCatalogCards('dandân');
        expect(dandanLower.any((c) => c.id == 'card-dandan-arn'), isTrue);

        // Æther Vial
        final aetherRes = await db.vaultDao.searchCatalogCards('Æther');
        expect(aetherRes.any((c) => c.id == 'card-aether-dst'), isTrue);

        // Emojis
        final emojiRes = await db.vaultDao.searchCatalogCards('🔥⚡');
        expect(emojiRes, isEmpty);
      });

      test('adversarial SQL injection attempts are safely sanitized via parameterized queries', () async {
        final injectionPayloads = [
          "' OR 1=1 --",
          "'; DROP TABLE vault_items; --",
          "admin' --",
          "' UNION SELECT * FROM vault_items --",
          "1' OR '1' = '1",
          "' OR ''='",
          "'; DELETE FROM vault_items WHERE 1=1; --",
        ];

        for (final payload in injectionPayloads) {
          // Should not throw and should not return unauthorized all-table dumps
          final res = await db.vaultDao.searchCatalogCards(payload);
          expect(res, isA<List<VaultItem>>(), reason: 'Failed on payload "$payload"');

          final resColl = await db.vaultDao.getItemsByCollection('mtg', searchQuery: payload);
          expect(resColl, isA<List<VaultItem>>(), reason: 'Failed on payload "$payload"');
        }

        // Verify database is completely intact after all injection attempts
        final remainingItems = await db.vaultDao.getItemsByCollection('mtg');
        expect(remainingItems.length, greaterThan(5),
            reason: 'Database tables or rows were corrupted by injection payloads!');
      });
    });

    // =========================================================================
    // CHALLENGE 4: SCOPING, OWNERSHIP & INBOX BOUNDARY CONDITIONS
    // =========================================================================
    group('4. Scoping, Ownership & Boundary Conditions', () {
      test('collection scoping: MTG search does not leak into Pokemon and vice versa', () async {
        // Searching 'sld' with collectionType 'pokemon' must return 0 items
        final pkmSld = await db.vaultDao.searchCatalogCards('sld', collectionType: 'pokemon');
        expect(pkmSld, isEmpty);

        final pkmColl = await db.vaultDao.getItemsByCollection('pokemon', searchQuery: 'sld');
        expect(pkmColl, isEmpty);

        // Searching 'Pikachu' in MTG collection must return 0 items
        final mtgPika = await db.vaultDao.searchCatalogCards('Pikachu', collectionType: 'mtg');
        expect(mtgPika, isEmpty);

        // Searching 'Pikachu' in Pokemon collection finds Pikachu
        final pkmPika = await db.vaultDao.searchCatalogCards('Pikachu', collectionType: 'pokemon');
        expect(pkmPika.length, 1);
        expect(pkmPika.first.id, 'card-pika-base');

        // Searching 'all' finds both
        final allCards = await db.vaultDao.searchCatalogCards('', collectionType: 'all');
        expect(allCards.any((c) => c.collectionType == 'mtg'), isTrue);
        expect(allCards.any((c) => c.collectionType == 'pokemon'), isTrue);
      });

      test('onlyOwned filtering with search query', () async {
        // card-sld-unowned has quantity = 0
        final withUnowned = await db.vaultDao.getItemsByCollection(
          'mtg',
          onlyOwned: false,
          searchQuery: 'Brainstorm',
        );
        expect(withUnowned.any((c) => c.id == 'card-sld-unowned'), isTrue);

        final ownedOnly = await db.vaultDao.getItemsByCollection(
          'mtg',
          onlyOwned: true,
          searchQuery: 'Brainstorm',
        );
        expect(ownedOnly.any((c) => c.id == 'card-sld-unowned'), isFalse);
      });

      test('INBOX items are strictly excluded from standard watch and get queries', () async {
        // card-sld-inbox has primaryBinderId = 'INBOX'
        final items = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Mana Crypt');
        expect(items.any((c) => c.id == 'card-sld-inbox'), isFalse);

        final streamItems = await db.vaultDao.watchItemsByCollection('mtg', searchQuery: 'Mana Crypt').first;
        expect(streamItems.any((c) => c.id == 'card-sld-inbox'), isFalse);
      });

      test('pagination limit and offset work deterministically during search', () async {
        final page1 = await db.vaultDao.getItemsByCollection(
          'mtg',
          searchQuery: 'sld',
          limit: 2,
          offset: 0,
        );
        expect(page1.length, 2);

        final page2 = await db.vaultDao.getItemsByCollection(
          'mtg',
          searchQuery: 'sld',
          limit: 2,
          offset: 2,
        );
        expect(page2.length, greaterThanOrEqualTo(1));

        // Pages should have disjoint sets of items
        final page1Ids = page1.map((c) => c.id).toSet();
        for (final item in page2) {
          expect(page1Ids.contains(item.id), isFalse,
              reason: 'Pagination overlap detected for item ${item.id}');
        }
      });
    });
  });
}

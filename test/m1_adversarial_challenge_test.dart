import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Milestone 1 Adversarial Challenge: Multi-Faced Card Parsing', () {
    test('parses card with 4+ faces (Who // What // When // Where) correctly', () {
      final multiFacedCard = {
        'id': 'unhinged-who-what-when-where',
        'name': 'Who // What // When // Where // Why',
        'set_name': 'Unhinged',
        'card_faces': [
          {
            'name': 'Who',
            'mana_cost': '{X}{W}',
            'oracle_text': 'Target player gains X life.',
            'image_uris': {'normal': 'https://example.com/who.jpg'},
          },
          {
            'name': 'What',
            'mana_cost': '{2}{U}',
            'oracle_text': 'Destroy target artifact.',
            'image_uris': {'normal': 'https://example.com/what.jpg'},
          },
          {
            'name': 'When',
            'mana_cost': '{2}{B}',
            'oracle_text': 'Counter target creature spell.',
            'image_uris': {'normal': 'https://example.com/when.jpg'},
          },
          {
            'name': 'Where',
            'mana_cost': '{3}{R}',
            'oracle_text': 'Destroy target land.',
            'image_uris': {'normal': 'https://example.com/where.jpg'},
          },
          {
            'name': 'Why',
            'mana_cost': '{1}{G}',
            'oracle_text': 'Destroy target enchantment.',
            'image_uris': {'normal': 'https://example.com/why.jpg'},
          },
        ],
        'prices': {'usd': '5.00'},
      };

      final companion = mapScryfallCardToCompanion(multiFacedCard);
      expect(companion.imageUrl.value, 'https://example.com/who.jpg');

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(
        dynamicData['oracle_text'],
        'Target player gains X life. // Destroy target artifact. // Counter target creature spell. // Destroy target land. // Destroy target enchantment.',
      );
      expect(dynamicData['back_image_url'], 'https://example.com/what.jpg');

      final faces = dynamicData['card_faces'] as List;
      expect(faces.length, 5);
      expect(faces[0]['name'], 'Who');
      expect(faces[4]['name'], 'Why');
    });

    test('handles multi-faced cards where all face oracle texts are null or whitespace without crashing', () {
      final cardWithNullFaceTexts = {
        'id': 'dfc-null-oracle',
        'name': 'Full Art Land // Back Land',
        'card_faces': [
          {
            'name': 'Front Full Art',
            'oracle_text': null,
            'image_uris': {'normal': 'https://example.com/front.jpg'},
          },
          {
            'name': 'Back Full Art',
            'oracle_text': '   \n  \t ',
            'image_uris': {'normal': 'https://example.com/back.jpg'},
          },
        ],
      };

      final companion = mapScryfallCardToCompanion(cardWithNullFaceTexts);
      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['oracle_text'], isEmpty);
      expect(dynamicData['oracle_text'], isNot(contains('//')));
    });

    test('handles multi-faced cards where one face has oracle text and other has null without dangling //', () {
      // Case A: Face 0 has text, Face 1 has null
      final cardA = {
        'id': 'dfc-partial-1',
        'name': 'Front Creature // Vanilla Back',
        'card_faces': [
          {
            'name': 'Front Creature',
            'oracle_text': 'Flying, Vigilance',
            'image_uris': {'normal': 'https://example.com/front_a.jpg'},
          },
          {
            'name': 'Vanilla Back',
            'oracle_text': null,
            'image_uris': {'normal': 'https://example.com/back_a.jpg'},
          },
        ],
      };

      final companionA = mapScryfallCardToCompanion(cardA);
      final dynamicDataA = jsonDecode(companionA.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicDataA['oracle_text'], equals('Flying, Vigilance'));
      expect(dynamicDataA['oracle_text'], isNot(endsWith(' // ')));
      expect(dynamicDataA['oracle_text'], isNot(startsWith(' // ')));

      // Case B: Face 0 has null, Face 1 has text
      final cardB = {
        'id': 'dfc-partial-2',
        'name': 'Vanilla Front // Spell Back',
        'card_faces': [
          {
            'name': 'Vanilla Front',
            'oracle_text': '',
            'image_uris': {'normal': 'https://example.com/front_b.jpg'},
          },
          {
            'name': 'Spell Back',
            'oracle_text': 'Draw three cards.',
            'image_uris': {'normal': 'https://example.com/back_b.jpg'},
          },
        ],
      };

      final companionB = mapScryfallCardToCompanion(cardB);
      final dynamicDataB = jsonDecode(companionB.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicDataB['oracle_text'], equals('Draw three cards.'));
      expect(dynamicDataB['oracle_text'], isNot(endsWith(' // ')));
      expect(dynamicDataB['oracle_text'], isNot(startsWith(' // ')));
    });

    test('handles missing image_uris completely across top-level and all faces', () {
      final cardMissingImages = {
        'id': 'dfc-no-images',
        'name': 'Invisible Card // Blind Realm',
        'card_faces': [
          {
            'name': 'Invisible Card',
            'oracle_text': 'You cannot see this.',
          },
          {
            'name': 'Blind Realm',
            'oracle_text': 'You cannot see this either.',
          },
        ],
      };

      final companion = mapScryfallCardToCompanion(cardMissingImages);
      expect(companion.imageUrl.value, isEmpty);

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['back_image_url'], isNull);
      expect(dynamicData['image_uris'], isNull);
      expect(dynamicData['oracle_text'], 'You cannot see this. // You cannot see this either.');
    });

    test('handles partial image_uris fallback (only small or png, missing normal/large)', () {
      final cardWithFallbackUris = {
        'id': 'dfc-png-only',
        'name': 'Retro Card // Retro Back',
        'card_faces': [
          {
            'name': 'Retro Card',
            'image_uris': {
              'small': 'https://example.com/small.jpg',
              'png': 'https://example.com/large.png',
            },
          },
          {
            'name': 'Retro Back',
            'image_uris': {
              'png': 'https://example.com/back.png',
            },
          },
        ],
      };

      final companion = mapScryfallCardToCompanion(cardWithFallbackUris);
      // Fallback hierarchy: normal -> large -> small -> png -> ''
      expect(companion.imageUrl.value, 'https://example.com/small.jpg');

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['back_image_url'], 'https://example.com/back.png');
    });

    test('handles weird flavor_name structures (whitespace, asymmetric faces, 3 faces)', () {
      // 1. Asymmetric: Face 0 has flavor_name, Face 1 has null
      final cardAsymmetric = {
        'id': 'dfc-flavor-asym',
        'name': 'Original Name // Other Face',
        'card_faces': [
          {
            'name': 'Original Name',
            'flavor_name': 'MechaGodzilla, the Weapon',
          },
          {
            'name': 'Other Face',
            'flavor_name': null,
          },
        ],
      };
      final compAsym = mapScryfallCardToCompanion(cardAsymmetric);
      expect(compAsym.flavorName.value, 'MechaGodzilla, the Weapon');

      // 2. 3 faces with flavor_names
      final cardThreeFlavors = {
        'id': 'dfc-3-flavors',
        'name': 'F1 // F2 // F3',
        'card_faces': [
          {'name': 'F1', 'flavor_name': 'Alpha Form'},
          {'name': 'F2', 'flavor_name': 'Beta Form'},
          {'name': 'F3', 'flavor_name': 'Gamma Form'},
        ],
      };
      final compThree = mapScryfallCardToCompanion(cardThreeFlavors);
      expect(compThree.flavorName.value, 'Alpha Form // Beta Form // Gamma Form');

      // 3. Both faces have whitespace-only flavor_name
      final cardWhitespaceFlavors = {
        'id': 'dfc-whitespace-flavor',
        'name': 'Normal Card // Normal Flip',
        'card_faces': [
          {'name': 'Normal Card', 'flavor_name': '   \t'},
          {'name': 'Normal Flip', 'flavor_name': '  '},
        ],
      };
      final compWhite = mapScryfallCardToCompanion(cardWhitespaceFlavors);
      expect(compWhite.flavorName.present, isFalse);

      // 4. Top-level flavor_name is whitespace-only, should fall back to face flavor_name
      final cardTopWhitespace = {
        'id': 'dfc-top-whitespace',
        'name': 'Top Whitespace // Face Valid',
        'flavor_name': '   ',
        'card_faces': [
          {'name': 'Top Whitespace', 'flavor_name': 'Valid Face Flavor'},
        ],
      };
      final compTopWhite = mapScryfallCardToCompanion(cardTopWhitespace);
      expect(compTopWhite.flavorName.value, 'Valid Face Flavor');
    });

    test('tolerates malformed card_faces array with nulls, numbers, and strings gracefully', () {
      final malformedCard = {
        'id': 'malformed-faces-card',
        'name': 'Resilient Card',
        'card_faces': [
          null,
          42,
          'not a face map',
          {
            'name': 'Valid Face',
            'oracle_text': 'Valid rules text.',
            'image_uris': {'normal': 'https://example.com/valid.jpg'},
          },
        ],
      };

      final companion = mapScryfallCardToCompanion(malformedCard);
      expect(companion.name.value, 'Resilient Card');
      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['oracle_text'], 'Valid rules text.');
      final faces = dynamicData['card_faces'] as List;
      expect(faces.length, 1);
      expect(faces[0]['name'], 'Valid Face');
    });
  });

  group('Milestone 1 Adversarial Challenge: VaultDao Search & Special Characters', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      // Seed cards with diverse flavor names, accents, and special characters
      await db.batch((b) {
        b.insertAll(db.vaultItems, [
        // Card 1: Standard alternate flavor name
        VaultItemsCompanion.insert(
          id: 'card-ozolith',
          collectionType: 'mtg',
          name: 'The Ozolith',
          flavorName: const drift.Value('Adamantium Bonding Tank'),
          setOrSeries: 'Secret Lair Drop',
          imageUrl: 'https://example.com/ozolith.jpg',
          acquiredPrice: 40.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 50.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),

        // Card 2: Flavor name with apostrophe / single quote
        VaultItemsCompanion.insert(
          id: 'card-gishath',
          collectionType: 'mtg',
          name: 'Gishath, Sun\'s Avatar',
          flavorName: const drift.Value('Godzilla, Primeval Champion\'s Roar'),
          setOrSeries: 'Ikoria: Lair of Behemoths',
          imageUrl: 'https://example.com/gishath.jpg',
          acquiredPrice: 15.0,
          acquiredDate: DateTime(2024, 1, 2),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 22.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),

        // Card 3: Flavor name with hyphens, commas, and parentheses
        VaultItemsCompanion.insert(
          id: 'card-brokkos',
          collectionType: 'mtg',
          name: 'Brokkos, Apex of Forever',
          flavorName: const drift.Value('Bio-Quartz Spacegodzilla (Death Corona)'),
          setOrSeries: 'Ikoria Showcase',
          imageUrl: 'https://example.com/brokkos.jpg',
          acquiredPrice: 8.0,
          acquiredDate: DateTime(2024, 1, 3),
          quantity: const drift.Value(2),
          condition: 'NM',
          currentMarketPrice: 12.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),

        // Card 4: Multi-faced card flavor name with " // " delimiter
        VaultItemsCompanion.insert(
          id: 'card-dfc-split-flavor',
          collectionType: 'mtg',
          name: 'Invasion of Ikoria // Zilortha, Apex of Ikoria',
          flavorName: const drift.Value('Siege of Monster Island // Godzilla, King of the Monsters'),
          setOrSeries: 'March of the Machine',
          imageUrl: 'https://example.com/invasion.jpg',
          acquiredPrice: 18.0,
          acquiredDate: DateTime(2024, 1, 4),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 20.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),

        // Card 5: Card with NULL flavor name
        VaultItemsCompanion.insert(
          id: 'card-sol-ring-noflavor',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'Commander Masters',
          imageUrl: 'https://example.com/solring.jpg',
          acquiredPrice: 2.0,
          acquiredDate: DateTime(2024, 1, 5),
          quantity: const drift.Value(4),
          condition: 'NM',
          currentMarketPrice: 2.5,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),

        // Card 6: Card with ampersand & exclamation mark
        VaultItemsCompanion.insert(
          id: 'card-special-punct',
          collectionType: 'mtg',
          name: 'B.F.M. (Big Furry Monster)',
          flavorName: const drift.Value('Rock & Roll, Baby!'),
          setOrSeries: 'Unglued',
          imageUrl: 'https://example.com/bfm.jpg',
          acquiredPrice: 100.0,
          acquiredDate: DateTime(2024, 1, 6),
          quantity: const drift.Value(1),
          condition: 'LP',
          currentMarketPrice: 120.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      ]);
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('case sensitivity: matches uppercase, lowercase, mixed-case, and inverted-case', () async {
      const variations = [
        'adamantium',
        'ADAMANTIUM',
        'AdAmAnTiUm',
        'aDaMaNtIuM',
        'BONDING',
        'bonding',
        'bOnDiNg',
        'tAnK',
      ];

      for (final query in variations) {
        // 1. Test getItemsByCollection
        final getResults = await db.vaultDao.getItemsByCollection('mtg', searchQuery: query);
        expect(getResults.length, equals(1), reason: 'Failed getItemsByCollection for query: $query');
        expect(getResults.first.id, equals('card-ozolith'), reason: 'Wrong item for query: $query');

        // 2. Test watchItemsByCollection
        final streamResults = await db.vaultDao.watchItemsByCollection('mtg', searchQuery: query).first;
        expect(streamResults.length, equals(1), reason: 'Failed watchItemsByCollection for query: $query');
        expect(streamResults.first.id, equals('card-ozolith'), reason: 'Wrong item for query: $query');

        // 3. Test searchCatalogCards
        final catalogResults = await db.vaultDao.searchCatalogCards(query, collectionType: 'mtg');
        expect(catalogResults.length, equals(1), reason: 'Failed searchCatalogCards for query: $query');
        expect(catalogResults.first.id, equals('card-ozolith'), reason: 'Wrong item for query: $query');
      }
    });

    test('substring matching: prefix, suffix, and infix slices match accurately', () async {
      // Prefix match
      final prefix = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Adam');
      expect(prefix.length, equals(1));
      expect(prefix.first.flavorName, equals('Adamantium Bonding Tank'));

      // Infix match
      final infix = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'mant');
      expect(infix.length, equals(1));
      expect(infix.first.flavorName, equals('Adamantium Bonding Tank'));

      // Suffix match
      final suffix = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Tank');
      expect(suffix.length, equals(1));
      expect(suffix.first.flavorName, equals('Adamantium Bonding Tank'));

      // Suffix of another card
      final suffixRoar = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Roar');
      expect(suffixRoar.length, equals(1));
      expect(suffixRoar.first.id, equals('card-gishath'));
    });

    test('special characters: apostrophe / single quote in query does not crash SQLite', () async {
      // Searching for exact apostrophe phrase
      final results1 = await db.vaultDao.getItemsByCollection('mtg', searchQuery: "Champion's");
      expect(results1.length, equals(1));
      expect(results1.first.id, equals('card-gishath'));

      // Searching for just apostrophe and letter
      final results2 = await db.vaultDao.getItemsByCollection('mtg', searchQuery: "'s");
      expect(results2.length, equals(1));
      expect(results2.first.id, equals('card-gishath'));

      // Also works in searchCatalogCards
      final catalogResults = await db.vaultDao.searchCatalogCards("Champion's Roar", collectionType: 'mtg');
      expect(catalogResults.length, equals(1));
      expect(catalogResults.first.id, equals('card-gishath'));
    });

    test('special characters: hyphens, parentheses, commas, ampersand, and exclamation', () async {
      // Hyphen
      final hyphenRes = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Bio-Quartz');
      expect(hyphenRes.length, equals(1));
      expect(hyphenRes.first.id, equals('card-brokkos'));

      // Parenthesis
      final parenRes = await db.vaultDao.getItemsByCollection('mtg', searchQuery: '(Death Corona)');
      expect(parenRes.length, equals(1));
      expect(parenRes.first.id, equals('card-brokkos'));

      // Slashes // from multi-face card
      final slashRes = await db.vaultDao.getItemsByCollection('mtg', searchQuery: '// Godzilla');
      expect(slashRes.length, equals(1));
      expect(slashRes.first.id, equals('card-dfc-split-flavor'));

      // Ampersand & exclamation
      final punctRes = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Rock & Roll, Baby!');
      expect(punctRes.length, equals(1));
      expect(punctRes.first.id, equals('card-special-punct'));
    });

    test('adversarial SQL injection input does not compromise database or error out', () async {
      final maliciousQueries = [
        "' OR '1'='1",
        "'; DROP TABLE vault_items; --",
        "' UNION SELECT * FROM vault_items --",
        "\" OR \"\"=\"",
        "\\",
      ];

      for (final malicious in maliciousQueries) {
        final results = await db.vaultDao.getItemsByCollection('mtg', searchQuery: malicious);
        // None of these should match any card (unless a card literally contained it)
        expect(results, isEmpty, reason: 'Malicious query returned unexpected rows: $malicious');

        // Ensure table was not dropped
        final allItems = await db.vaultDao.getItemsByCollection('mtg');
        expect(allItems.length, equals(6), reason: 'Database was modified by injection: $malicious');
      }
    });

    test('SQL wildcard characters (% and _) execute safely without crashing', () async {
      // Searching for '%' matches all records that have non-empty matching fields
      final percentResults = await db.vaultDao.getItemsByCollection('mtg', searchQuery: '%');
      expect(percentResults, isNotEmpty);

      // Searching for '_' matches records with at least 1 character
      final underscoreResults = await db.vaultDao.getItemsByCollection('mtg', searchQuery: '_');
      expect(underscoreResults, isNotEmpty);
    });

    test('null flavor_name rows do not throw and are excluded when searching for flavor names', () async {
      final results = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Adamantium');
      expect(results.length, equals(1));
      // Sol Ring has null flavor_name, so it must not be included
      expect(results.any((r) => r.id == 'card-sol-ring-noflavor'), isFalse);
    });
  });

  group('Milestone 1 Adversarial Challenge: Database Upsert Conflicts & Transitions', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('upsert transition 1: null flavor_name transitions to non-null flavor_name on conflict', () async {
      // 1. Initial insert with null flavorName
      final initialItem = VaultItemsCompanion.insert(
        id: 'test-card-upsert',
        collectionType: 'mtg',
        name: 'The Ozolith',
        setOrSeries: 'Ikoria: Lair of Behemoths',
        imageUrl: 'https://example.com/ozolith_v1.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 20.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: '{}',
      );
      await db.vaultDao.insertDictionaryBatch([initialItem]);

      var row = await db.vaultDao.getItemById('test-card-upsert');
      expect(row, isNotNull);
      expect(row!.flavorName, isNull);

      // 2. Incoming Scryfall update with flavor_name populated
      final updatedCatalog = VaultItemsCompanion.insert(
        id: 'test-card-upsert',
        collectionType: 'mtg',
        name: 'The Ozolith',
        flavorName: const drift.Value('Adamantium Bonding Tank'),
        setOrSeries: 'Secret Lair Drop',
        imageUrl: 'https://example.com/ozolith_v2.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 6, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 45.0,
        lastPriceUpdate: DateTime(2023, 6, 1),
        dynamicData: '{"flavor_name":"Adamantium Bonding Tank"}',
      );
      await db.vaultDao.insertDictionaryBatch([updatedCatalog]);

      row = await db.vaultDao.getItemById('test-card-upsert');
      expect(row, isNotNull);
      expect(row!.flavorName, equals('Adamantium Bonding Tank'));
      expect(row.setOrSeries, equals('Secret Lair Drop'));
      expect(row.currentMarketPrice, equals(45.0));

      // 3. Search can now immediately find it via flavorName
      final searchRes = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Adamantium');
      expect(searchRes.length, equals(1));
      expect(searchRes.first.id, equals('test-card-upsert'));
    });

    test('upsert transition 2: non-null flavor_name transitions to null on conflict when companion provides Value(null)', () async {
      // 1. Initial insert with non-null flavorName
      final initialItem = VaultItemsCompanion.insert(
        id: 'test-card-clear-flavor',
        collectionType: 'mtg',
        name: 'Normal Card With Old Flavor',
        flavorName: const drift.Value('Old Obsolete Flavor Name'),
        setOrSeries: 'Old Set',
        imageUrl: 'https://example.com/old.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: '{}',
      );
      await db.vaultDao.insertDictionaryBatch([initialItem]);

      var row = await db.vaultDao.getItemById('test-card-clear-flavor');
      expect(row!.flavorName, equals('Old Obsolete Flavor Name'));

      // 2. Incoming Scryfall update where flavor name was revoked/cleared (explicit null)
      final clearedCatalog = VaultItemsCompanion.insert(
        id: 'test-card-clear-flavor',
        collectionType: 'mtg',
        name: 'Normal Card With Old Flavor',
        flavorName: const drift.Value(null), // explicitly cleared
        setOrSeries: 'New Set',
        imageUrl: 'https://example.com/new.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 6, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 12.0,
        lastPriceUpdate: DateTime(2023, 6, 1),
        dynamicData: '{}',
      );
      await db.vaultDao.insertDictionaryBatch([clearedCatalog]);

      row = await db.vaultDao.getItemById('test-card-clear-flavor');
      expect(row!.flavorName, isNull);
      expect(row.setOrSeries, equals('New Set'));

      // 3. Search for old flavor should now return empty
      final searchOld = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Obsolete');
      expect(searchOld, isEmpty);
    });

    test('upsert transition 3: non-null flavor_name updates to another non-null flavor_name', () async {
      // 1. Initial insert
      final initial = VaultItemsCompanion.insert(
        id: 'test-card-flavor-switch',
        collectionType: 'mtg',
        name: 'Godzilla Card',
        flavorName: const drift.Value('Godzilla, King of the Monsters'),
        setOrSeries: 'Ikoria',
        imageUrl: 'https://example.com/v1.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 20.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: '{}',
      );
      await db.vaultDao.insertDictionaryBatch([initial]);

      // 2. Upsert with updated translation or corrected flavor_name
      final updated = VaultItemsCompanion.insert(
        id: 'test-card-flavor-switch',
        collectionType: 'mtg',
        name: 'Godzilla Card',
        flavorName: const drift.Value('Godzilla, Doom Desired'),
        setOrSeries: 'Ikoria Promo',
        imageUrl: 'https://example.com/v2.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 6, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 35.0,
        lastPriceUpdate: DateTime(2023, 6, 1),
        dynamicData: '{}',
      );
      await db.vaultDao.insertDictionaryBatch([updated]);

      final row = await db.vaultDao.getItemById('test-card-flavor-switch');
      expect(row!.flavorName, equals('Godzilla, Doom Desired'));
      expect(row.currentMarketPrice, equals(35.0));

      final oldSearch = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Monsters');
      expect(oldSearch, isEmpty);

      final newSearch = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'Doom Desired');
      expect(newSearch.length, equals(1));
    });

    test('upsert conflict strictly preserves user-owned inventory fields while updating flavorName', () async {
      // 1. User owns 3 copies of this card in a binder with custom condition & notes
      final userAcquiredDate = DateTime(2022, 10, 15);
      final userOwnedItem = VaultItemsCompanion.insert(
        id: 'user-owned-crossover-card',
        collectionType: 'mtg',
        name: 'The Ozolith',
        flavorName: const drift.Value(null), // not known at time of acquisition
        setOrSeries: 'Ikoria: Lair of Behemoths',
        imageUrl: 'https://example.com/user_card.jpg',
        acquiredPrice: 18.50,
        acquiredDate: userAcquiredDate,
        quantity: const drift.Value(3),
        condition: 'LP',
        isGraded: const drift.Value(true),
        isAltered: const drift.Value(true),
        isMisprint: const drift.Value(true),
        isSigned: const drift.Value(true),
        personalNotes: const drift.Value('Signed by artist at MagicCon 2022'),
        primaryBinderId: const drift.Value('binder-special-edh'),
        currentMarketPrice: 22.00,
        lastPriceUpdate: DateTime(2022, 10, 15),
        dynamicData: '{"user_custom": true}',
      );
      await db.vaultDao.into(db.vaultItems).insert(userOwnedItem);

      // Verify row before upsert
      var row = await db.vaultDao.getItemById('user-owned-crossover-card');
      expect(row!.quantity, equals(3));
      expect(row.acquiredPrice, equals(18.50));
      expect(row.condition, equals('LP'));
      expect(row.isGraded, isTrue);
      expect(row.isAltered, isTrue);
      expect(row.isMisprint, isTrue);
      expect(row.isSigned, isTrue);
      expect(row.personalNotes, equals('Signed by artist at MagicCon 2022'));
      expect(row.primaryBinderId, equals('binder-special-edh'));
      expect(row.flavorName, isNull);

      // 2. Later, Hydration engine or catalog sync runs and attempts to insert/update catalog entry:
      // Catalog entries have quantity: 0, acquiredPrice: 0, default condition, flags false, etc.
      final incomingCatalogCompanion = VaultItemsCompanion.insert(
        id: 'user-owned-crossover-card',
        collectionType: 'mtg',
        name: 'The Ozolith',
        flavorName: const drift.Value('Adamantium Bonding Tank'),
        setOrSeries: 'Secret Lair Drop',
        imageUrl: 'https://example.com/high_res_ozolith.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0), // MUST NOT OVERWRITE USER'S 3 COPIES!
        condition: 'NM', // MUST NOT OVERWRITE USER'S 'LP'!
        isGraded: const drift.Value(false), // MUST NOT OVERWRITE!
        isAltered: const drift.Value(false), // MUST NOT OVERWRITE!
        isMisprint: const drift.Value(false), // MUST NOT OVERWRITE!
        isSigned: const drift.Value(false), // MUST NOT OVERWRITE!
        personalNotes: const drift.Value(null), // MUST NOT OVERWRITE!
        primaryBinderId: const drift.Value(null), // MUST NOT OVERWRITE!
        currentMarketPrice: 65.00, // SHOULD update catalog pricing
        lastPriceUpdate: DateTime(2024, 1, 1),
        dynamicData: '{"oracle_text":"Updated rules"}', // SHOULD update catalog metadata
      );

      await db.vaultDao.insertDictionaryBatch([incomingCatalogCompanion]);

      // 3. Verify that user-level inventory fields remained completely uncorrupted!
      row = await db.vaultDao.getItemById('user-owned-crossover-card');
      expect(row, isNotNull);

      // Catalog-level fields updated:
      expect(row!.flavorName, equals('Adamantium Bonding Tank'));
      expect(row.currentMarketPrice, equals(65.00));
      expect(row.imageUrl, equals('https://example.com/high_res_ozolith.jpg'));
      expect(row.dynamicData, equals('{"oracle_text":"Updated rules"}'));

      // User-level fields STRICTLY preserved:
      expect(row.quantity, equals(3), reason: 'Quantity was corrupted by catalog upsert!');
      expect(row.acquiredPrice, equals(18.50), reason: 'Acquired price was overwritten!');
      expect(row.condition, equals('LP'), reason: 'Condition was reset to NM!');
      expect(row.isGraded, isTrue, reason: 'isGraded was reset to false!');
      expect(row.isAltered, isTrue, reason: 'isAltered was reset to false!');
      expect(row.isMisprint, isTrue, reason: 'isMisprint was reset to false!');
      expect(row.isSigned, isTrue, reason: 'isSigned was reset to false!');
      expect(row.personalNotes, equals('Signed by artist at MagicCon 2022'), reason: 'Personal notes were wiped!');
      expect(row.primaryBinderId, equals('binder-special-edh'), reason: 'Binder assignment was cleared!');

      // 4. Searching for 'Adamantium' returns the user's owned card!
      final ownedSearch = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'Adamantium');
      expect(ownedSearch.length, equals(1));
      expect(ownedSearch.first.id, equals('user-owned-crossover-card'));
      expect(ownedSearch.first.quantity, equals(3));
    });
  });
}

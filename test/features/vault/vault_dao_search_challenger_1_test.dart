import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItemsCompanion createItem({
    required String id,
    required String name,
    String? flavorName,
    String collectionType = 'mtg',
    String setOrSeries = 'TEST',
    double price = 10.0,
    int quantity = 1,
    DateTime? acquiredDate,
    String dynamicData = '{}',
  }) {
    final date = acquiredDate ?? DateTime(2026, 1, 1);
    return VaultItemsCompanion.insert(
      id: id,
      collectionType: collectionType,
      name: name,
      flavorName: flavorName != null
          ? drift.Value(flavorName)
          : const drift.Value.absent(),
      setOrSeries: setOrSeries,
      imageUrl: 'https://example.com/$id.jpg',
      acquiredPrice: price,
      acquiredDate: date,
      quantity: drift.Value(quantity),
      condition: 'NM',
      currentMarketPrice: price,
      lastPriceUpdate: date,
      dynamicData: dynamicData,
    );
  }

  group('Challenger 1: Exact Acceptance Criterion Verification', () {
    test(
        'Querying "aether" strictly ranks Aether Vial (Tier 1) < The Aether Reservoir (Tier 1.5) < Serum Aether (Tier 2)',
        () async {
      // Seed cards in inverted rank and non-alphabetical order
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-serum',
            name: 'Serum Aether',
            price: 5.0,
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-reservoir',
            name: 'The Aether Reservoir',
            price: 15.0,
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-vial',
            name: 'Aether Vial',
            price: 40.0,
          ));

      // 1. getItemsByCollection
      final getResults =
          await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(getResults.length, 3);
      expect(getResults[0].name, equals('Aether Vial'),
          reason: 'Tier 1 exact prefix must be ranked 1st');
      expect(getResults[1].name, equals('The Aether Reservoir'),
          reason: 'Tier 1.5 "The " bypass prefix must be ranked 2nd');
      expect(getResults[2].name, equals('Serum Aether'),
          reason: 'Tier 2 substring match must be ranked 3rd');

      // 2. watchItemsByCollection
      final watchResults =
          await dao.watchItemsByCollection('mtg', searchQuery: 'aether').first;
      expect(watchResults.length, 3);
      expect(watchResults[0].name, equals('Aether Vial'));
      expect(watchResults[1].name, equals('The Aether Reservoir'));
      expect(watchResults[2].name, equals('Serum Aether'));

      // 3. searchCatalogCards
      final catalogResults =
          await dao.searchCatalogCards('aether', collectionType: 'mtg');
      expect(catalogResults.length, 3);
      expect(catalogResults[0].name, equals('Aether Vial'));
      expect(catalogResults[1].name, equals('The Aether Reservoir'));
      expect(catalogResults[2].name, equals('Serum Aether'));
    });

    test(
        'Case variations (AETHER, aEtHeR, Aether) and whitespace preserve exact ranking',
        () async {
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-serum',
            name: 'Serum Aether',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-reservoir',
            name: 'The Aether Reservoir',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-vial',
            name: 'Aether Vial',
          ));

      for (final query in ['AETHER', 'aEtHeR', '   aether   ', '  AETHER  ']) {
        final results =
            await dao.getItemsByCollection('mtg', searchQuery: query);
        expect(results.length, 3, reason: 'Failed on query: "$query"');
        expect(results[0].name, equals('Aether Vial'),
            reason: 'Tier 1 failed for: "$query"');
        expect(results[1].name, equals('The Aether Reservoir'),
            reason: 'Tier 1.5 failed for: "$query"');
        expect(results[2].name, equals('Serum Aether'),
            reason: 'Tier 2 failed for: "$query"');
      }
    });
  });

  group('Challenger 1: Flavor Name Search & Weight Equivalence', () {
    test(
        'Flavor names starting with "aether" (Tier 1), "The aether" (Tier 1.5), and containing "aether" (Tier 2) receive identical rank weights to name',
        () async {
      // Card names do NOT contain "aether" at all, matching solely through flavor_name
      await db.into(db.vaultItems).insert(createItem(
            id: 'f-sub',
            name: 'Chamber of Secrets',
            flavorName: 'Ancient Aether Chamber', // Tier 2 substring
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'f-the',
            name: 'Energy Tap',
            flavorName: 'The Aether Collector', // Tier 1.5 "The " bypass
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'f-pre',
            name: 'Power Conduit',
            flavorName: 'Aether Reservoir', // Tier 1 prefix
          ));

      // 1. getItemsByCollection
      final getResults =
          await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(getResults.length, 3);
      expect(getResults[0].name, equals('Power Conduit'),
          reason: 'Flavor prefix "Aether..." must rank Tier 1');
      expect(getResults[1].name, equals('Energy Tap'),
          reason: 'Flavor "The Aether..." must rank Tier 1.5');
      expect(getResults[2].name, equals('Chamber of Secrets'),
          reason: 'Flavor "...Aether..." substring must rank Tier 2');

      // 2. watchItemsByCollection
      final watchResults =
          await dao.watchItemsByCollection('mtg', searchQuery: 'aether').first;
      expect(watchResults.length, 3);
      expect(watchResults[0].name, equals('Power Conduit'));
      expect(watchResults[1].name, equals('Energy Tap'));
      expect(watchResults[2].name, equals('Chamber of Secrets'));

      // 3. searchCatalogCards
      final catalogResults =
          await dao.searchCatalogCards('aether', collectionType: 'mtg');
      expect(catalogResults.length, 3);
      expect(catalogResults[0].name, equals('Power Conduit'));
      expect(catalogResults[1].name, equals('Energy Tap'));
      expect(catalogResults[2].name, equals('Chamber of Secrets'));
    });

    test(
        'Interleaved ranking: Cards matching via name and flavor_name across all tiers rank strictly by tier',
        () async {
      // 2 Tier 1: one via name ("Aether Adept"), one via flavor_name ("Zeta Conduit" with flavor "Aether Dynamo")
      // 2 Tier 1.5: one via name ("The Aether Engine"), one via flavor_name ("Beta Prism" with flavor "The Aether Well")
      // 2 Tier 2: one via name ("Serum Aether"), one via flavor_name ("Alpha Beacon" with flavor "Essence of Aether")

      await db.into(db.vaultItems).insert(createItem(
            id: 't2-flavor',
            name: 'Alpha Beacon',
            flavorName: 'Essence of Aether', // Tier 2 flavor
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 't2-name',
            name: 'Serum Aether', // Tier 2 name
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 't15-name',
            name: 'The Aether Engine', // Tier 1.5 name
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 't15-flavor',
            name: 'Beta Prism',
            flavorName: 'The Aether Well', // Tier 1.5 flavor
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 't1-flavor',
            name: 'Zeta Conduit',
            flavorName: 'Aether Dynamo', // Tier 1 flavor
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 't1-name',
            name: 'Aether Adept', // Tier 1 name
          ));

      final results =
          await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(results.length, 6);

      // Tier 1 (rank 1): Aether Adept (name "Aether...") and Zeta Conduit (flavor "Aether...")
      // Secondary sort: "Aether Adept" < "Zeta Conduit"
      expect(results[0].name, equals('Aether Adept'),
          reason: 'Tier 1 alphabetical 1st');
      expect(results[1].name, equals('Zeta Conduit'),
          reason: 'Tier 1 alphabetical 2nd');

      // Tier 1.5 (rank 2): Beta Prism (flavor "The Aether...") and The Aether Engine (name "The Aether...")
      // Secondary sort: "Beta Prism" < "The Aether Engine"
      expect(results[2].name, equals('Beta Prism'),
          reason: 'Tier 1.5 alphabetical 1st');
      expect(results[3].name, equals('The Aether Engine'),
          reason: 'Tier 1.5 alphabetical 2nd');

      // Tier 2 (rank 3): Alpha Beacon (flavor "...Aether") and Serum Aether (name "...Aether")
      // Secondary sort: "Alpha Beacon" < "Serum Aether"
      expect(results[4].name, equals('Alpha Beacon'),
          reason: 'Tier 2 alphabetical 1st');
      expect(results[5].name, equals('Serum Aether'),
          reason: 'Tier 2 alphabetical 2nd');
    });

    test(
        'Dual match priority: Card matching Tier 2 on name but Tier 1 on flavor_name promotes to Tier 1',
        () async {
      // Card has name "Serum Aether" (Tier 2 for query "aether")
      // But flavorName is "Aether Supreme" (Tier 1 for query "aether")
      await db.into(db.vaultItems).insert(createItem(
            id: 'dual-promoted',
            name: 'Serum Aether',
            flavorName: 'Aether Supreme',
          ));
      // Comparison card with Tier 1.5 name
      await db.into(db.vaultItems).insert(createItem(
            id: 't15-comp',
            name: 'The Aether Reservoir',
          ));

      final results =
          await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(results.length, 2);
      expect(results[0].name, equals('Serum Aether'),
          reason:
              'Card promoted to Tier 1 via flavor_name must rank ahead of Tier 1.5 card');
      expect(results[1].name, equals('The Aether Reservoir'));
    });
  });

  group('Challenger 1: Secondary Alphabetical Fallback Sorting', () {
    test(
        'Multiple cards within same tier strictly fall back to alphabetical order by name ASC',
        () async {
      // 4 Tier 1 cards inserted in reverse alphabetical order
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-spouts',
            name: 'Aetherspouts',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-vial',
            name: 'Aether Vial',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-hub',
            name: 'Aether Hub',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-adept',
            name: 'Aether Adept',
          ));

      // 3 Tier 1.5 cards inserted in reverse order
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-the-res',
            name: 'The Aether Reservoir',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-the-flux',
            name: 'The Aether Flux',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-the-eng',
            name: 'The Aether Engine',
          ));

      // 3 Tier 2 cards inserted in reverse order
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-vial-of',
            name: 'Vial of Aether',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-serum-ae',
            name: 'Serum Aether',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-burst-ae',
            name: 'Burst of Aether',
          ));

      for (final endpoint in ['get', 'watch', 'catalog']) {
        List<VaultItem> items;
        if (endpoint == 'get') {
          items = await dao.getItemsByCollection('mtg', searchQuery: 'aether');
        } else if (endpoint == 'watch') {
          items = await dao
              .watchItemsByCollection('mtg', searchQuery: 'aether')
              .first;
        } else {
          items = await dao.searchCatalogCards('aether',
              collectionType: 'mtg', limit: 50);
        }

        expect(items.length, 10, reason: 'Endpoint $endpoint count mismatch');

        final names = items.map((i) => i.name).toList();

        // Tier 1 block (indices 0..3)
        expect(names.sublist(0, 4), equals([
          'Aether Adept',
          'Aether Hub',
          'Aether Vial',
          'Aetherspouts',
        ]), reason: 'Tier 1 alphabetical sort failed on $endpoint');

        // Tier 1.5 block (indices 4..6)
        expect(names.sublist(4, 7), equals([
          'The Aether Engine',
          'The Aether Flux',
          'The Aether Reservoir',
        ]), reason: 'Tier 1.5 alphabetical sort failed on $endpoint');

        // Tier 2 block (indices 7..9)
        expect(names.sublist(7, 10), equals([
          'Burst of Aether',
          'Serum Aether',
          'Vial of Aether',
        ]), reason: 'Tier 2 alphabetical sort failed on $endpoint');
      }
    });
  });

  group('Challenger 1: All Entry Points & Catalog / Inventory Modes', () {
    test(
        'Catalog search (quantity == 0) and inventory search (quantity > 0) behave consistently',
        () async {
      // Insert catalog items (quantity == 0)
      await db.into(db.vaultItems).insert(createItem(
            id: 'cat-serum',
            name: 'Serum Aether',
            quantity: 0,
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'cat-res',
            name: 'The Aether Reservoir',
            quantity: 0,
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'cat-vial',
            name: 'Aether Vial',
            quantity: 0,
          ));

      // searchCatalogCards must find and rank them properly even with quantity == 0
      final catalogCards =
          await dao.searchCatalogCards('aether', collectionType: 'mtg');
      expect(catalogCards.length, 3);
      expect(catalogCards[0].name, equals('Aether Vial'));
      expect(catalogCards[1].name, equals('The Aether Reservoir'));
      expect(catalogCards[2].name, equals('Serum Aether'));

      // getItemsByCollection with onlyOwned: true should return empty
      final ownedOnly = await dao.getItemsByCollection('mtg',
          searchQuery: 'aether', onlyOwned: true);
      expect(ownedOnly, isEmpty);

      // Now add quantity to vial and serum
      await (db.update(db.vaultItems)..where((t) => t.id.equals('cat-vial')))
          .write(const VaultItemsCompanion(quantity: drift.Value(2)));
      await (db.update(db.vaultItems)..where((t) => t.id.equals('cat-serum')))
          .write(const VaultItemsCompanion(quantity: drift.Value(1)));

      final ownedAfter = await dao.getItemsByCollection('mtg',
          searchQuery: 'aether', onlyOwned: true);
      expect(ownedAfter.length, 2);
      expect(ownedAfter[0].name, equals('Aether Vial'),
          reason: 'Tier 1 must still rank first among owned');
      expect(ownedAfter[1].name, equals('Serum Aether'),
          reason: 'Tier 2 must rank second among owned');
    });

    test(
        'watchItemsByCollection emits live updates in ranked order when new items are added',
        () async {
      final stream = dao.watchItemsByCollection('mtg', searchQuery: 'aether');

      // Initially empty
      expect(await stream.first, isEmpty);

      // Add Tier 2 card first
      await db.into(db.vaultItems).insert(createItem(
            id: 'live-t2',
            name: 'Serum Aether',
          ));
      final emit1 = await stream.first;
      expect(emit1.length, 1);
      expect(emit1[0].name, 'Serum Aether');

      // Add Tier 1 card
      await db.into(db.vaultItems).insert(createItem(
            id: 'live-t1',
            name: 'Aether Vial',
          ));
      final emit2 = await stream.first;
      expect(emit2.length, 2);
      expect(emit2[0].name, 'Aether Vial',
          reason: 'Tier 1 item must jump ahead of Tier 2 item in stream');
      expect(emit2[1].name, 'Serum Aether');

      // Add Tier 1.5 card
      await db.into(db.vaultItems).insert(createItem(
            id: 'live-t15',
            name: 'The Aether Reservoir',
          ));
      final emit3 = await stream.first;
      expect(emit3.length, 3);
      expect(emit3[0].name, 'Aether Vial');
      expect(emit3[1].name, 'The Aether Reservoir');
      expect(emit3[2].name, 'Serum Aether');
    });
  });

  group('Challenger 1: Stress & Adversarial Edge Cases', () {
    test(
        'Cards matching via setOrSeries or dynamicData receive Tier 4 fallback after name/flavor matches',
        () async {
      // Card 1: matches name Tier 1
      await db.into(db.vaultItems).insert(createItem(
            id: 't1-name',
            name: 'Aether Hub',
          ));
      // Card 2: matches name Tier 1.5
      await db.into(db.vaultItems).insert(createItem(
            id: 't15-name',
            name: 'The Aether Core',
          ));
      // Card 3: matches name Tier 2
      await db.into(db.vaultItems).insert(createItem(
            id: 't2-name',
            name: 'Serum Aether',
          ));
      // Card 4: does not match name/flavor at all, but matches setOrSeries
      await db.into(db.vaultItems).insert(createItem(
            id: 't4-set',
            name: 'Disallow',
            flavorName: 'Counterspell',
            setOrSeries: 'Aether Revolt', // set matches "aether"
          ));
      // Card 5: does not match name/flavor/set, but matches dynamicData
      await db.into(db.vaultItems).insert(createItem(
            id: 't4-data',
            name: 'Bomat Courier',
            dynamicData: '{"oracle_text": "Pay {R} and sacrifice aether-fueled vehicle"}',
          ));

      final results =
          await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(results.length, 5);
      expect(results[0].name, equals('Aether Hub'), reason: 'Tier 1 rank 1');
      expect(results[1].name, equals('The Aether Core'),
          reason: 'Tier 1.5 rank 2');
      expect(results[2].name, equals('Serum Aether'), reason: 'Tier 2 rank 3');

      // Rank 4 items sorted alphabetically by name:
      // "Bomat Courier" < "Disallow"
      expect(results[3].name, equals('Bomat Courier'),
          reason: 'Tier 4 rank 4 alphabetical 1st');
      expect(results[4].name, equals('Disallow'),
          reason: 'Tier 4 rank 4 alphabetical 2nd');
    });

    test(
        '"The " bypass does NOT trigger on words merely starting with "The" (e.g. "Theatre")',
        () async {
      // Query is "atre"
      // "Theatre of Horrors" -> starts with "Theatre", NOT "The atre"
      // It must match as Tier 2 (substring), not Tier 1.5
      await db.into(db.vaultItems).insert(createItem(
            id: 'theatre-card',
            name: 'Theatre of Horrors',
          ));
      // Card starting with "The atre..." -> Tier 1.5
      await db.into(db.vaultItems).insert(createItem(
            id: 'the-atre-card',
            name: 'The Atreides Way',
          ));
      // Card starting exactly with "atre..." -> Tier 1
      await db.into(db.vaultItems).insert(createItem(
            id: 'atre-card',
            name: 'Atreides Banner',
          ));

      final results =
          await dao.getItemsByCollection('mtg', searchQuery: 'atre');
      expect(results.length, 3);
      expect(results[0].name, equals('Atreides Banner'), reason: 'Tier 1');
      expect(results[1].name, equals('The Atreides Way'), reason: 'Tier 1.5');
      expect(results[2].name, equals('Theatre of Horrors'), reason: 'Tier 2');
    });

    test('Empty and whitespace-only queries fallback gracefully to default sort',
        () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-old',
            name: 'Old Card',
            acquiredDate: now.subtract(const Duration(days: 10)),
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'c-new',
            name: 'New Card',
            acquiredDate: now,
          ));

      for (final emptyQuery in ['', '   ', ' \t \n ']) {
        final results = await dao.getItemsByCollection('mtg',
            searchQuery: emptyQuery.isEmpty ? null : emptyQuery);
        expect(results.length, 2);
        // Default sort is acquiredDate DESC
        expect(results[0].name, equals('New Card'));
        expect(results[1].name, equals('Old Card'));
      }
    });

    test('Collection type isolation under search ranking', () async {
      await db.into(db.vaultItems).insert(createItem(
            id: 'mtg-aether',
            name: 'Aether Vial',
            collectionType: 'mtg',
          ));
      await db.into(db.vaultItems).insert(createItem(
            id: 'pokemon-aether',
            name: 'Aether Paradise Conservation Area',
            collectionType: 'pokemon',
          ));

      final mtgResults =
          await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(mtgResults.length, 1);
      expect(mtgResults[0].name, 'Aether Vial');

      final pokemonResults =
          await dao.getItemsByCollection('pokemon', searchQuery: 'aether');
      expect(pokemonResults.length, 1);
      expect(pokemonResults[0].name, 'Aether Paradise Conservation Area');

      final allResults =
          await dao.getItemsByCollection('all', searchQuery: 'aether');
      expect(allResults.length, 2);
      expect(allResults[0].name, 'Aether Paradise Conservation Area',
          reason: 'Both are Tier 1; sorted alphabetically');
      expect(allResults[1].name, 'Aether Vial');
    });
  });
}

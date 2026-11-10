import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/card_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.delete(dao.vaultItems).go();

    // 1. Seed Multi-TCG catalog cards (quantity = 0)
    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'pkmn_charizard_base',
        collectionType: 'pokemon',
        name: 'Charizard',
        setOrSeries: 'Base Set',
        imageUrl: 'https://images.pokemontcg.io/base1/4.png',
        acquiredPrice: 350.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 350.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'pkmn-charizard-id',
          'type_line': 'Pokémon — Stage 2',
          'oracle_text': 'Energy Burn: As often as you like during your turn...',
          'prices': {'usd': '350.00'},
        }),
      ),
    );

    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'lorcana_elsa_spirit',
        collectionType: 'lorcana',
        name: 'Elsa - Snow Queen',
        setOrSeries: 'The First Chapter',
        imageUrl: 'https://images.lorcana.com/elsa.png',
        acquiredPrice: 45.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 45.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'lorcana-elsa-id',
          'type_line': 'Character — Storyborn Hero Queen Sorcerer',
          'oracle_text': 'FREEZE: Exert chosen opposing character.',
          'prices': {'usd': '45.00'},
        }),
      ),
    );

    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'ygo_blue_eyes',
        collectionType: 'yugioh',
        name: 'Blue-Eyes White Dragon',
        setOrSeries: 'LOB',
        imageUrl: 'https://images.yugioh.com/blue_eyes.png',
        acquiredPrice: 120.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 120.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'ygo-blue-eyes-id',
          'type_line': 'Dragon / Normal',
          'oracle_text': 'This legendary dragon is a powerful engine of destruction.',
          'prices': {'usd': '120.00'},
        }),
      ),
    );

    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'sw_darth_vader',
        collectionType: 'starwars',
        name: 'Darth Vader',
        setOrSeries: 'SOR',
        imageUrl: 'https://images.swunlimited.com/vader.png',
        acquiredPrice: 75.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 75.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'sw-vader-id',
          'type_line': 'Leader — Imperial Sith',
          'oracle_text': 'Epic Action: Deploy Darth Vader.',
          'prices': {'usd': '75.00'},
        }),
      ),
    );

    // 2. Seed owned items (quantity > 0) with wildcards in name and oracle_text
    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'owned_pct_card',
        collectionType: 'mtg',
        name: '100% Orlando Card',
        setOrSeries: 'EXP',
        imageUrl: 'https://cards.scryfall.io/pct.jpg',
        acquiredPrice: 10.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'pct-scryfall-id',
          'type_line': 'Enchantment',
          'oracle_text': 'Grants +100% power and toughness.',
          'prices': {'usd': '10.00'},
        }),
      ),
    );

    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'owned_underscore_card',
        collectionType: 'mtg',
        name: 'Special_Variable_Card',
        setOrSeries: 'EXP',
        imageUrl: 'https://cards.scryfall.io/und.jpg',
        acquiredPrice: 15.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 15.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'und-scryfall-id',
          'type_line': 'Instant',
          'oracle_text': 'Executes run_special_routine() when cast.',
          'prices': {'usd': '15.00'},
        }),
      ),
    );

    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'owned_regular_card',
        collectionType: 'mtg',
        name: 'Regular Plains Land',
        setOrSeries: 'EXP',
        imageUrl: 'https://cards.scryfall.io/plains.jpg',
        acquiredPrice: 0.5,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 0.5,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'plains-scryfall-id',
          'type_line': 'Basic Land — Plains',
          'oracle_text': '{T}: Add {W}.',
          'prices': {'usd': '0.50'},
        }),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestScope({required Widget child, List<dynamic>? overrides}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        ...?overrides,
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  // =========================================================================
  // 1. MULTI-TCG SLUG PREFIX RESOLUTION
  // =========================================================================
  group('Multi-TCG Slug Prefixes Adversarial Verification', () {
    test('Pokemon slug item-pokemon-charizard resolves to Charizard', () async {
      final res = await dao.findCatalogCard(identifier: 'item-pokemon-charizard');
      expect(res, isNotNull, reason: 'Failed to resolve item-pokemon-charizard');
      expect(res!.name, equals('Charizard'));
      expect(res.collectionType, equals('pokemon'));
    });

    test('Lorcana slug item-lorcana-elsa resolves to Elsa - Snow Queen', () async {
      final res = await dao.findCatalogCard(identifier: 'item-lorcana-elsa');
      expect(res, isNotNull, reason: 'Failed to resolve item-lorcana-elsa');
      expect(res!.name, equals('Elsa - Snow Queen'));
      expect(res.collectionType, equals('lorcana'));
    });

    test('Yu-Gi-Oh! slug item-yugioh-blue-eyes-white-dragon resolves correctly', () async {
      final res = await dao.findCatalogCard(identifier: 'item-yugioh-blue-eyes-white-dragon');
      expect(res, isNotNull, reason: 'Failed to resolve item-yugioh-blue-eyes-white-dragon');
      expect(res!.name, equals('Blue-Eyes White Dragon'));
      expect(res.collectionType, equals('yugioh'));
    });

    test('Star Wars slug item-starwars-darth-vader resolves correctly', () async {
      final res = await dao.findCatalogCard(identifier: 'item-starwars-darth-vader');
      expect(res, isNotNull, reason: 'Failed to resolve item-starwars-darth-vader');
      expect(res!.name, equals('Darth Vader'));
      expect(res.collectionType, equals('starwars'));
    });

    test('Case-insensitive multi-TCG slug prefixes resolve cleanly', () async {
      final resPkmn = await dao.findCatalogCard(identifier: 'Item-Pokemon-Charizard');
      expect(resPkmn, isNotNull);
      expect(resPkmn!.name, equals('Charizard'));

      final resLorc = await dao.findCatalogCard(identifier: 'ITEM-LORCANA-ELSA');
      expect(resLorc, isNotNull);
      expect(resLorc!.name, equals('Elsa - Snow Queen'));
    });
  });

  // =========================================================================
  // 2. WILDCARD CHARACTER QUERIES (% and _)
  // =========================================================================
  group('Wildcard Character Queries Adversarial Verification', () {
    test('Querying literal 100% matches exact card without SQL syntax error', () async {
      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: '100%',
      );
      expect(results.length, equals(1));
      expect(results.first.name, equals('100% Orlando Card'));
    });

    test('Querying literal underscore _ matches underscore card', () async {
      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'Special_Variable',
      );
      expect(results.length, equals(1));
      expect(results.first.name, equals('Special_Variable_Card'));
    });

    test('Querying literal % or _ does not crash VaultDao or leak unrelated cards', () async {
      final resultsUnder = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'run_special_routine',
      );
      expect(resultsUnder.length, equals(1));
      expect(resultsUnder.first.name, equals('Special_Variable_Card'));
    });

    test('findCatalogCard handles escaped wildcard characters safely', () async {
      final res = await dao.findCatalogCard(identifier: 'owned_pct_card');
      expect(res, isNotNull);
      expect(res!.name, equals('100% Orlando Card'));
    });
  });

  // =========================================================================
  // 3. NON-EXISTENT CARD RESOLUTION IN CardDetailsScreen
  // =========================================================================
  group('Non-Existent Card Resolution in CardDetailsScreen Adversarial Verification', () {
    testWidgets('Non-existent Pokemon slug renders error tile and suppresses quick actions', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const CardDetailsScreen(cardId: 'item-pokemon-non-existent-mew-holo-xyz'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('card_detail_error_tile')), findsOneWidget);
      expect(find.text('Card not found'), findsOneWidget);
      expect(find.text('Unable to locate details for "item-pokemon-non-existent-mew-holo-xyz".'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      // Pinned bottom quick action bar should be suppressed
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsNothing);
    });

    testWidgets('Non-existent Lorcana slug renders error tile without crashing', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const CardDetailsScreen(cardId: 'item-lorcana-non-existent-stitch-404'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('card_detail_error_tile')), findsOneWidget);
      expect(find.text('Card not found'), findsOneWidget);
    });

    testWidgets('Non-existent Star Wars slug renders error tile without crashing', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const CardDetailsScreen(cardId: 'item-starwars-non-existent-yoda-grandmaster'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('card_detail_error_tile')), findsOneWidget);
      expect(find.text('Card not found'), findsOneWidget);
    });

    testWidgets('Non-existent Yu-Gi-Oh! slug renders error tile without crashing', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const CardDetailsScreen(cardId: 'item-yugioh-non-existent-dark-magician-xyz'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('card_detail_error_tile')), findsOneWidget);
      expect(find.text('Card not found'), findsOneWidget);
    });

    testWidgets('Dismiss button on error tile pops dialog/screen cleanly', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const CardDetailsScreen(cardId: '00000000-0000-0000-0000-000000000000'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final dismissButton = find.text('Dismiss');
      expect(dismissButton, findsOneWidget);
      await tester.tap(dismissButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Tapping dismiss did not crash
    });
  });
}

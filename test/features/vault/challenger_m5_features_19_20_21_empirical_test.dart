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
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.delete(dao.vaultItems).go();

    // Seed test catalog items
    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'c_mox_1',
        collectionType: 'mtg',
        name: 'Mox Diamond',
        setOrSeries: 'STH',
        imageUrl: 'https://cards.scryfall.io/mox.jpg',
        acquiredPrice: 650.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 650.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'b8703868-47a7-4a00-93a3-c475f1b0ef22',
          'oracle_id': 'oracle-mox-id',
          'mana_cost': '{0}',
          'type_line': 'Artifact',
          'oracle_text': 'Discard a land card: Add one mana of any color.',
          'prices': {'usd': '650.00'},
        }),
      ),
    );

    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'c_lim_1',
        collectionType: 'mtg',
        name: "Lim-Dul's Vault",
        setOrSeries: 'ALL',
        imageUrl: 'https://cards.scryfall.io/lim.jpg',
        acquiredPrice: 4.5,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 4.5,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'aec89c76-56f3-4c42-8942-9c4c274245d4',
          'oracle_id': 'oracle-lim-id',
          'mana_cost': '{U}{B}',
          'type_line': 'Instant',
          'oracle_text': 'Look at the top five cards of your library.',
          'prices': {'usd': '4.50'},
        }),
      ),
    );

    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'c_promo_1',
        collectionType: 'mtg',
        name: 'Promo Card Without Pricing',
        setOrSeries: 'PRM',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 0.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': '11111111-1111-1111-1111-111111111111',
          'mana_cost': '{1}',
          'type_line': 'Creature — Human',
          'oracle_text': 'Promo text.',
          'prices': <String, dynamic>{},
        }),
      ),
    );

    // Seed 1 owned item for singles search
    await dao.into(dao.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'owned_sol_ring',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'C21',
        imageUrl: 'https://cards.scryfall.io/sol.jpg',
        acquiredPrice: 1.5,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 2.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'scryfall_id': 'sol-ring-scryfall-id',
          'type_line': 'Artifact',
          'oracle_text': '{T}: Add {C}{C}.',
          'prices': {'usd': '2.00'},
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
  // FEATURE 19: CARD DETAILS RESOLUTION & SLUG HANDLING
  // =========================================================================
  group('Feature 19 Empirical Adversarial Challenge', () {
    test('F19-EMP-1: Multi-hyphenated slug resolution in VaultDao.findCatalogCard', () async {
      final res1 = await dao.findCatalogCard(identifier: 'item-mtg-lim---dul-s-vault');
      expect(res1, isNotNull, reason: 'Failed to resolve multi-hyphenated slug lim---dul-s-vault');
      expect(res1!.name, equals("Lim-Dul's Vault"));

      final res2 = await dao.findCatalogCard(identifier: 'item-mtg-lim--dul-s-vault');
      expect(res2, isNotNull);
      expect(res2!.name, equals("Lim-Dul's Vault"));
    });

    test('F19-EMP-1b: Slug with ASCII words fails to resolve card with diacritics (Lim-Dûl)', () async {
      await dao.into(dao.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_lim_diacritic',
          collectionType: 'mtg',
          name: "Lim-Dûl's Vault",
          setOrSeries: 'ALL',
          imageUrl: 'https://cards.scryfall.io/lim.jpg',
          acquiredPrice: 4.5,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 4.5,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'scryfall_id': 'aec89c76-56f3-4c42-8942-9c4c274245d4',
            'oracle_id': 'oracle-lim-id',
            'mana_cost': '{U}{B}',
            'type_line': 'Instant',
            'oracle_text': 'Look at the top five cards of your library.',
            'prices': {'usd': '4.50'},
          }),
        ),
      );

      // Attempt to resolve via slug
      final res = await dao.findCatalogCard(identifier: 'item-mtg-lim-dul-s-vault');
      expect(res, isNotNull);
      // If dao has Lim-Dul's Vault and Lim-Dûl's Vault, let's delete the non-diacritic one first
      await (dao.delete(dao.vaultItems)..where((t) => t.id.equals('c_lim_1'))).go();

      final resDiacriticOnly = await dao.findCatalogCard(identifier: 'item-mtg-lim-dul-s-vault');
      expect(
        resDiacriticOnly,
        isNotNull,
        reason: "Slug 'item-mtg-lim-dul-s-vault' must resolve to Scryfall card name 'Lim-Dûl's Vault'",
      );
    });

    test('F19-EMP-2: Uppercase slug resolution in VaultDao.findCatalogCard', () async {
      final res = await dao.findCatalogCard(identifier: 'item-mtg-MOX-DIAMOND');
      expect(res, isNotNull, reason: 'Failed to resolve uppercase slug item-mtg-MOX-DIAMOND');
      expect(res!.name, equals('Mox Diamond'));

      final resMixed = await dao.findCatalogCard(identifier: 'Item-MTG-Mox-Diamond');
      expect(resMixed, isNotNull);
      expect(resMixed!.name, equals('Mox Diamond'));
    });

    test('F19-EMP-3: Malformed slug with empty core throws ArgumentError', () async {
      expect(
        () => dao.findCatalogCard(identifier: 'item-mtg-'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => dao.findCatalogCard(identifier: 'item-mtg----'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('F19-EMP-4: Unknown UUID returns null safely without exception', () async {
      final res = await dao.findCatalogCard(identifier: '00000000-0000-0000-0000-000000000000');
      expect(res, isNull);
    });

    test('F19-EMP-5: Card with missing price data parses and maps safely', () async {
      final res = await dao.findCatalogCard(identifier: 'c_promo_1');
      expect(res, isNotNull);
      final dyn = jsonDecode(res!.dynamicData) as Map<String, dynamic>;
      expect(dyn['prices'], isEmpty);
      expect(dyn['prices']['usd'], isNull);
    });

    testWidgets('F19-EMP-6: CardDetailsScreen mounts cleanly with known card item', (tester) async {
      final item = await dao.findCatalogCard(identifier: 'c_mox_1');
      expect(item, isNotNull);

      await tester.pumpWidget(buildTestScope(
        child: CardDetailsScreen(item: item),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CardDetailsScreen), findsOneWidget);
      expect(find.text('Mox Diamond'), findsWidgets);
    });

    testWidgets('F19-EMP-7: CardDetailsScreen with unknown UUID renders error tile without crashing', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const CardDetailsScreen(cardId: '00000000-0000-0000-0000-000000000000'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('card_detail_error_tile')), findsOneWidget);
      expect(find.text('Card not found'), findsOneWidget);
    });

    testWidgets('F19-EMP-8: CardDetailsScreen with unknown slug renders error tile without crashing', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const CardDetailsScreen(cardId: 'item-mtg-completely-non-existent-card-xyz'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      debugPrint('Widgets found in CardDetailsScreen for unknown slug:');
      for (final textWidget in tester.widgetList<Text>(find.byType(Text))) {
        debugPrint('CardDetail text: "${textWidget.data}"');
      }

      final errorTileFinder = find.byKey(const Key('card_detail_error_tile'));
      expect(errorTileFinder, findsOneWidget, reason: 'Unknown legacy slug did not render card_detail_error_tile');
    });
  });

  // =========================================================================
  // FEATURE 20: VAULT SINGLES HEADER SPACING & ZERO DEAD SPACE
  // =========================================================================
  group('Feature 20 Empirical Adversarial Challenge', () {
    testWidgets('F20-EMP-1: Header completely omitted and search bar flush when showEstimatedValue is false', (tester) async {
      await tester.pumpWidget(buildTestScope(
        overrides: [
          vaultShowEstimatedValueProvider.overrideWith((ref) => false),
        ],
        child: const Scaffold(body: VaultScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('vault_value_header')), findsNothing);
      expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);

      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      final searchBarTop = tester.getTopLeft(find.byKey(const Key('vault_singles_search_bar'))).dy;
      final deadSpace = searchBarTop - appBarBottom;
      expect(deadSpace, equals(0.0), reason: 'Search bar should sit flush below AppBar with zero dead space');
    });

    testWidgets('F20-EMP-2: Header present when showEstimatedValue is true', (tester) async {
      await tester.pumpWidget(buildTestScope(
        overrides: [
          vaultShowEstimatedValueProvider.overrideWith((ref) => true),
        ],
        child: const Scaffold(body: VaultScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('vault_value_header')), findsOneWidget);
    });

    testWidgets('F20-EMP-3: Dynamic toggling between expanded and collapsed states while mounted', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: VaultScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially true
      expect(find.byKey(const Key('vault_value_header')), findsOneWidget);

      // Toggle to false
      container.read(vaultShowEstimatedValueProvider.notifier).state = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('vault_value_header')), findsNothing);

      // Toggle back to true
      container.read(vaultShowEstimatedValueProvider.notifier).state = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('vault_value_header')), findsOneWidget);
    });
  });

  // =========================================================================
  // FEATURE 21: VAULT SINGLES LIVE SQLITE SEARCH
  // =========================================================================
  group('Feature 21 Empirical Adversarial Challenge', () {
    test('F21-EMP-1: SQL Injection string does not leak rows or cause syntax error', () async {
      const sqlInjectionQuery = "' OR 1=1 --";
      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: sqlInjectionQuery,
      );
      expect(results, isEmpty, reason: "SQL Injection query '$sqlInjectionQuery' must not return all rows!");
    });

    test('F21-EMP-2: 250+ character search query executes safely', () async {
      final longQuery = 'a' * 250;
      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: longQuery,
      );
      expect(results, isEmpty);
    });

    test('F21-EMP-3: Regex metacharacters match literally without crashing', () async {
      for (final meta in [r'.*', r'[a-z]+', r'\d+', r'^$', r'+', r'(']) {
        final results = await dao.getItemsByCollection(
          'mtg',
          onlyOwned: true,
          searchQuery: meta,
        );
        expect(results, isEmpty);
      }
    });

    test('F21-EMP-4: Search matches on name, type_line, and oracle_text in SQLite', () async {
      // 1. Match by name
      final byName = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'Sol Ring',
      );
      expect(byName.length, equals(1));
      expect(byName.first.name, equals('Sol Ring'));

      // 2. Match by type_line
      final byType = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'Artifact',
      );
      expect(byType.length, equals(1));
      expect(byType.first.name, equals('Sol Ring'));

      // 3. Match by oracle_text
      final byOracle = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'Add {C}{C}',
      );
      expect(byOracle.length, equals(1));
      expect(byOracle.first.name, equals('Sol Ring'));
    });

    testWidgets('F21-EMP-5: Search matching 0 items displays clean empty state message', (tester) async {
      await tester.pumpWidget(buildTestScope(
        child: const Scaffold(body: VaultScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expand search bar
      final expandButton = find.byKey(const Key('vault_search_expand_button'));
      if (expandButton.evaluate().isNotEmpty) {
        await tester.tap(expandButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Enter search query that matches 0 cards
      final searchInput = find.byType(TextField);
      expect(searchInput, findsWidgets);
      await tester.enterText(searchInput.first, 'NonExistentCardXYZ123');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text("No cards found matching 'NonExistentCardXYZ123'"),
        findsOneWidget,
        reason: "VaultScreen did not display required empty state 'No cards found matching NonExistentCardXYZ123'",
      );
    });
  });
}

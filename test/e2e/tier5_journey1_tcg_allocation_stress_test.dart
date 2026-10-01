import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/conflict_resolution_modal.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/multi_deck_allocation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 5 - Journey 1: TCG Context -> FAB -> Multi-Deck Stepper -> Physical Allocation Stress Suite', () {
    late AppDatabase db;
    late VaultDao dao;

    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    /// Helper to seed standard test cards into Vault
    Future<VaultItem> seedVaultCard({
      required String id,
      required String name,
      String collectionType = 'pokemon',
      int quantity = 3,
      double price = 45.0,
      String? primaryBinderId,
    }) async {
      final companion = VaultItemsCompanion.insert(
        id: id,
        collectionType: collectionType,
        name: name,
        setOrSeries: 'Test Series',
        imageUrl: 'https://example.com/$id.jpg',
        acquiredPrice: price,
        acquiredDate: DateTime.now(),
        quantity: drift.Value(quantity),
        condition: 'NM',
        currentMarketPrice: price,
        lastPriceUpdate: DateTime.now(),
        primaryBinderId: drift.Value(primaryBinderId),
        dynamicData: jsonEncode({'name': name}),
      );
      await dao.into(dao.vaultItems).insert(companion);
      return (await (dao.select(dao.vaultItems)..where((t) => t.id.equals(id))).getSingle());
    }

    /// Helper to build test widget harness
    Widget buildHarness({
      required Widget child,
      String initialFilter = 'all',
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeDeckTcgFilterProvider.overrideWith((ref) => initialFilter),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      );
    }

    // =========================================================================
    // Test 1: TCG Dropdown Switching to Pokémon -> FAB Deck Creation & Domain Binding
    // =========================================================================
    testWidgets('Test 1: TCG dropdown switching to Pokémon -> FAB deck creation defaults domain to pokemon and ruleset to Pokémon Standard (0/60)', (tester) async {
      // 1. Seed baseline vault inventory
      final charizard = await seedVaultCard(
        id: 'pkm-charizard',
        name: 'Charizard ex',
        collectionType: 'pokemon',
        quantity: 3,
        price: 45.0,
      );
      final lotus = await seedVaultCard(
        id: 'mtg-lotus',
        name: 'Black Lotus',
        collectionType: 'mtg',
        quantity: 1,
        price: 5000.0,
      );

      expect(await dao.getAvailableQuantity(charizard.id), equals(3));
      expect(await dao.getAvailableQuantity(lotus.id), equals(1));

      // 2. Launch DecksScreen
      await tester.pumpWidget(buildHarness(child: const DecksScreen()));
      await tester.pumpAndSettle();

      // Dropdown exists defaulting to 'All Decks'
      final dropdownFinder = find.byKey(const Key('decks_tcg_context_switcher'));
      expect(dropdownFinder, findsOneWidget);
      expect(find.text('All Decks (6)'), findsOneWidget);

      // 3. Switch TCG domain filter to Pokémon
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final pokemonMenuItem = find.widgetWithText(PopupMenuItem<String>, 'Pokémon');
      expect(pokemonMenuItem, findsOneWidget);
      await tester.tap(pokemonMenuItem);
      await tester.pumpAndSettle();

      // Dropdown title updates to Pokémon and filters visible decks to 2
      expect(find.text('Pokémon'), findsOneWidget);
      expect(find.text('All Decks (2)'), findsOneWidget);
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
      expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsNothing);
      expect(find.text('Modern Mono-Green Tron'), findsNothing);

      // 4. Tap FAB to create new deck under active Pokémon filter
      final fab = find.byKey(const Key('decks_new_deck_fab'));
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Countr 4.8 launches DeckSetupWizardModal with pre-set domain
      expect(find.byType(DeckSetupWizardModal), findsOneWidget);
      await tester.enterText(find.byKey(const Key('deck_wizard_name_input')), 'Mewtwo VSTAR');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck_wizard_create_button')));
      await tester.pumpAndSettle();

      // 5. DeckSetupWizardModal opens DeckBuilderScreen directly with the created Deck model
      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      final builderScreen = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      expect(builderScreen.deck.tcgDomain, equals('pokemon'));
      expect(builderScreen.deck.format, equals('Pokémon Standard'));
      expect(builderScreen.deck.isRegistered, isFalse);
      expect(builderScreen.deck.isCompetitive, isFalse);

      // Return back to DecksScreen to inspect deck list and tab count
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Tab count increments to 3
      expect(find.text('All Decks (3)'), findsOneWidget);
      expect(find.textContaining('Pokémon Standard • 0/60'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // =========================================================================
    // Test 2: Allocating Physical Cards via MultiDeckAllocationSheet Steppers
    // =========================================================================
    testWidgets('Test 2: Allocating physical cards into this deck via MultiDeckAllocationSheet steppers', (tester) async {
      final charizard = await seedVaultCard(
        id: 'pkm-charizard',
        name: 'Charizard ex',
        collectionType: 'pokemon',
        quantity: 3,
        price: 45.0,
      );

      // Persist draft deck in SQLite database
      final deckPkmBrew = await dao.createDeck(
        'Charizard Standard Brew',
        tcgDomain: 'pokemon',
        format: 'Pokémon Standard',
        isRegistered: false,
      );

      // Open MultiDeckAllocationSheet for Charizard
      await tester.pumpWidget(
        buildHarness(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () => MultiDeckAllocationSheet.show(ctx, charizard),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Verify sheet header and inventory summary
      expect(find.byKey(const Key('multi_deck_sheet_title')), findsOneWidget);
      expect(find.text('Total Owned'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('In Decks'), findsOneWidget);

      // Stepper row for deck exists with initial quantity 0
      final rowFinder = find.byKey(Key('deck_allocation_row_${deckPkmBrew.id}'));
      expect(rowFinder, findsOneWidget);
      expect(find.text('Charizard Standard Brew'), findsOneWidget);

      final qtyContainer = find.byKey(Key('stepper_quantity_${deckPkmBrew.id}'));
      expect(qtyContainer, findsOneWidget);
      expect(find.descendant(of: qtyContainer, matching: find.text('0')), findsOneWidget);

      // Tap '+' stepper button once: quantity becomes 1
      final incBtn = find.byKey(Key('stepper_increment_${deckPkmBrew.id}'));
      await tester.tap(incBtn);
      await tester.pumpAndSettle();

      expect(find.descendant(of: qtyContainer, matching: find.text('1')), findsOneWidget);

      // Tap '+' stepper button again: quantity becomes 2
      await tester.tap(incBtn);
      await tester.pumpAndSettle();

      expect(find.descendant(of: qtyContainer, matching: find.text('2')), findsOneWidget);

      // Tap '-' decrement button: quantity becomes 1
      final decBtn = find.byKey(Key('stepper_decrement_${deckPkmBrew.id}'));
      await tester.tap(decBtn);
      await tester.pumpAndSettle();

      expect(find.descendant(of: qtyContainer, matching: find.text('1')), findsOneWidget);

      // Restore to 2 copies
      await tester.tap(incBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: qtyContainer, matching: find.text('2')), findsOneWidget);

      // Verify database persistence of 2 copies
      final allocations = await dao.watchCardDeckAllocations(charizard.id).first;
      expect(allocations[deckPkmBrew.id], equals(2));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // =========================================================================
    // Test 3: Invariant: While is_registered == false, getAvailableQuantity does NOT deduct stock
    // =========================================================================
    test('Test 3: Invariant: While is_registered == false, VaultDao.getAvailableQuantity does NOT deduct stock', () async {
      final charizard = await seedVaultCard(
        id: 'pkm-charizard',
        name: 'Charizard ex',
        quantity: 3,
      );

      // Create two draft decks (is_registered == false)
      final draftDeck1 = await dao.createDeck(
        'Charizard Standard Brew',
        tcgDomain: 'pokemon',
        format: 'Pokémon Standard',
        isRegistered: false,
      );
      final draftDeck2 = await dao.createDeck(
        'Charizard Casual Draft',
        tcgDomain: 'pokemon',
        format: 'Pokémon Standard',
        isRegistered: false,
      );

      // Allocate 2 copies to draftDeck1 and 1 copy to draftDeck2 (3 total copies staged)
      await dao.addCardToDeck(draftDeck1.id, charizard.id, quantity: 2, isProxy: false);
      await dao.addCardToDeck(draftDeck2.id, charizard.id, quantity: 1, isProxy: false);

      // Verify allocations in database
      final allocations = await dao.watchCardDeckAllocations(charizard.id).first;
      expect(allocations[draftDeck1.id], equals(2));
      expect(allocations[draftDeck2.id], equals(1));

      // CRITICAL INVARIANT: Available quantity MUST strictly evaluate to 3
      // Because NEITHER draft deck is registered (is_registered == 0)!
      final available = await dao.getAvailableQuantity(charizard.id);
      expect(
        available,
        equals(3),
        reason: 'Draft decks (is_registered == false) must never lock or deduct physical inventory',
      );
    });

    // =========================================================================
    // Test 4: When setDeckRegistered(deckId, true) is called, getAvailableQuantity strictly decrements
    // =========================================================================
    test('Test 4: When setDeckRegistered(deckId, true) is called, getAvailableQuantity strictly decrements physical inventory', () async {
      final charizard = await seedVaultCard(
        id: 'pkm-charizard',
        name: 'Charizard ex',
        quantity: 3,
      );

      final deck1 = await dao.createDeck('Charizard Standard Brew', isRegistered: false);
      final deck2 = await dao.createDeck('Charizard Casual Draft', isRegistered: false);

      await dao.addCardToDeck(deck1.id, charizard.id, quantity: 2, isProxy: false);
      await dao.addCardToDeck(deck2.id, charizard.id, quantity: 1, isProxy: false);

      // Baseline before registration: 3 available
      expect(await dao.getAvailableQuantity(charizard.id), equals(3));

      // Register deck1 (locks 2 physical copies)
      await dao.setDeckRegistered(deck1.id, true);

      // INVARIANT: Available quantity drops strictly to 3 - 2 = 1!
      // deck2's 1 copy is still draft, so it must NOT be deducted.
      final availablePostReg = await dao.getAvailableQuantity(charizard.id);
      expect(
        availablePostReg,
        equals(1),
        reason: 'Registered deck must deduct its 2 physical copies; draft deck copy must remain unlocked',
      );
    });

    // =========================================================================
    // Test 5: Reactive StreamBuilder / watchAvailableQuantity updates live without restart
    // =========================================================================
    testWidgets('Test 5: Reactive StreamBuilder / watchAvailableQuantity updates live without restart', (tester) async {
      final charizard = await seedVaultCard(
        id: 'pkm-charizard',
        name: 'Charizard ex',
        quantity: 3,
      );

      final deck1 = await dao.createDeck('Charizard Standard Brew', isRegistered: false);
      await dao.addCardToDeck(deck1.id, charizard.id, quantity: 2, isProxy: false);

      // Launch sheet with live StreamBuilder watching watchAvailableQuantity
      await tester.pumpWidget(
        buildHarness(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () => MultiDeckAllocationSheet.show(ctx, charizard),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Initially, Available shows 3 (deck1 is draft)
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Total Owned'), findsOneWidget);

      // Dynamically toggle deck registration in database while sheet remains open
      await dao.setDeckRegistered(deck1.id, true);

      // Pump frames for reactive StreamBuilder to consume new emission
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Available column reactively updates from 3 to 1 live without restarting modal
      expect(find.text('1'), findsOneWidget); // Available is now 1

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // =========================================================================
    // Test 6: Over-allocation Conflict Prompt on Registered Decks & Proxy Clamping Invariant
    // =========================================================================
    testWidgets('Test 6: Over-allocation conflict prompt on registered decks when available quantity == 0; proxy selection does not deduct physical inventory', (tester) async {
      final charizard = await seedVaultCard(
        id: 'pkm-charizard',
        name: 'Charizard ex',
        quantity: 3,
      );

      // Create registered tournament deck 1 with 2 physical copies
      final tourneyDeck1 = await dao.createDeck(
        'Tourney Deck Alpha',
        tcgDomain: 'pokemon',
        isRegistered: true,
      );
      await dao.addCardToDeck(tourneyDeck1.id, charizard.id, quantity: 2, isProxy: false);

      // Create registered tournament deck 2 with 1 physical copy
      final tourneyDeck2 = await dao.createDeck(
        'Tourney Deck Beta',
        tcgDomain: 'pokemon',
        isRegistered: true,
      );
      await dao.addCardToDeck(tourneyDeck2.id, charizard.id, quantity: 1, isProxy: false);

      // At this point: 2 + 1 = 3 physical copies allocated in registered decks.
      // Available physical copies strictly equals 0.
      expect(await dao.getAvailableQuantity(charizard.id), equals(0));

      // Verify getDecksUsingItem returns both registered deck names
      final activeRegisteredDecks = await dao.getDecksUsingItem(charizard.id, onlyRegistered: true);
      expect(activeRegisteredDecks, containsAll(['Tourney Deck Alpha', 'Tourney Deck Beta']));

      // Open MultiDeckAllocationSheet
      await tester.pumpWidget(
        buildHarness(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () => MultiDeckAllocationSheet.show(ctx, charizard),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Available shows 0
      expect(find.text('0'), findsWidgets);

      // Tap '+' stepper on Tourney Deck Beta when available is 0
      final incBtnBeta = find.byKey(Key('stepper_increment_${tourneyDeck2.id}'));
      await tester.tap(incBtnBeta);
      await tester.pumpAndSettle();

      // ADVERSARIAL VERIFICATION: ConflictResolutionModal is surfaced!
      expect(find.byType(ConflictResolutionModal), findsOneWidget);
      expect(find.text('Inventory Conflict'), findsOneWidget);
      expect(find.descendant(of: find.byType(ConflictResolutionModal), matching: find.textContaining('Tourney Deck Alpha')), findsOneWidget);
      expect(find.text('Add as Proxy'), findsOneWidget);

      // Tap 'Add as Proxy'
      await tester.tap(find.text('Add as Proxy'));
      await tester.pumpAndSettle();

      // Modal dismissed
      expect(find.byType(ConflictResolutionModal), findsNothing);

      // INVARIANT 1: Available quantity MUST remain clamped at 0 (never negative)
      final availablePostProxy = await dao.getAvailableQuantity(charizard.id);
      expect(availablePostProxy, equals(0));

      // INVARIANT 2: Proxies never lock physical inventory
      // Verify proxy was added to tourneyDeck2
      final tourney2Items = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(charizard.id) & t.isProxy.equals(true)))
          .get();
      expect(tourney2Items.length, equals(1));
      expect(tourney2Items.first.isProxy, isTrue);

      // INVARIANT 3: De-registration inventory rollback
      // Unregister tourneyDeck1: available count bounces from 0 to 2 (3 owned - 1 physical in tourneyDeck2)
      await dao.setDeckRegistered(tourneyDeck1.id, false);
      expect(await dao.getAvailableQuantity(charizard.id), equals(2));

      // Unregister tourneyDeck2: available count restores completely to 3
      await dao.setDeckRegistered(tourneyDeck2.id, false);
      expect(await dao.getAvailableQuantity(charizard.id), equals(3));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

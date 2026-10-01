import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.delete(dao.vaultItems).go();
    await dao.delete(dao.decks).go();
    await dao.delete(dao.deckVersions).go();
    await dao.delete(dao.deckVersionItems).go();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    required String id,
    required String name,
    List<String> deckHistory = const [],
    List<String> assignmentHistory = const [],
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'MH3',
      imageUrl: 'https://cards.scryfall.io/normal/$id.jpg',
      acquiredPrice: 10.0,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: 10.0,
      lastPriceUpdate: DateTime(2026, 1, 1),
      personalNotes: null,
      dynamicData: jsonEncode({
        'collector_number': '001',
        'set': 'mh3',
        'mana_cost': '{1}{R}',
        'type_line': 'Instant',
        'deck_history': deckHistory,
        'assignment_history': assignmentHistory,
      }),
    );
  }

  Widget createHarness(Widget child) {
    final mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(800, 3000)),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> pumpCardDetail(WidgetTester tester, VaultItem card) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
    await tester.pumpAndSettle();

    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.first, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
  }

  group('R8 & R9 — Adversarial Stress Test: Automated Deck Assignment & Lifecycle Ledger', () {
    // -------------------------------------------------------------------------
    // 1. True End-to-End Assemble / Disassemble Toggles with Database Verification
    // -------------------------------------------------------------------------
    testWidgets('R8-R9-ADV-1: setDeckAssembled true/false transitions card dynamicData between formal and drafted without manual intervention', (tester) async {
      // 1. Insert card into DB
      final initialCard = createTestCard(id: 'c-adv-lifecycle-1', name: 'Orcish Bowmasters');
      await db.into(db.vaultItems).insert(initialCard);

      // 2. Create non-assembled deck
      final deck = await dao.createDeck('Mono Black Burn');
      expect(deck.isAssembled, isFalse);

      // 3. Add card to deck -> triggers automated _syncItemDeckHistory
      await dao.addCardToDeck(deck.id, initialCard.id);

      // 4. Verify DB state: Drafted in
      var cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(initialCard.id))).getSingle();
      var data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
      var assignmentHistory = (data['assignment_history'] as List).cast<String>();
      var deckHistory = (data['deck_history'] as List).cast<String>();

      expect(deckHistory, isEmpty, reason: 'deck_history must be empty for non-assembled deck');
      expect(assignmentHistory.length, equals(1));
      expect(assignmentHistory.first, startsWith('Drafted in - Mono Black Burn - '));

      // 5. Verify UI rendering: shows "Draft" glyph and "Drafted in - Mono Black Burn"
      await pumpCardDetail(tester, cardInDb);
      expect(find.textContaining('Drafted in - Mono Black Burn'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('+ Mono Black Burn'), findsNothing);

      // 6. TOGGLE TO ASSEMBLED
      await dao.setDeckAssembled(deck.id, true);

      // 7. Verify DB state updated automatically via _cascadeSyncDeckMembers
      cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(initialCard.id))).getSingle();
      data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
      assignmentHistory = (data['assignment_history'] as List).cast<String>();
      deckHistory = (data['deck_history'] as List).cast<String>();

      expect(deckHistory, equals(['Mono Black Burn']), reason: 'deck_history must contain formal deck name');
      expect(assignmentHistory, equals(['Mono Black Burn']), reason: 'Drafted entry must be replaced with formal entry');

      // 8. Verify UI rendering: shows "+" glyph and formal "+ Mono Black Burn"
      await pumpCardDetail(tester, cardInDb);
      expect(find.text('+ Mono Black Burn'), findsOneWidget);
      expect(find.textContaining('Drafted in'), findsNothing);

      // 9. TOGGLE BACK TO DISASSEMBLED
      await dao.setDeckAssembled(deck.id, false);

      // 10. Verify DB state automatically reverts back to Drafted
      cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(initialCard.id))).getSingle();
      data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
      assignmentHistory = (data['assignment_history'] as List).cast<String>();
      deckHistory = (data['deck_history'] as List).cast<String>();

      expect(deckHistory, isEmpty, reason: 'deck_history must be cleared when disassembled');
      expect(assignmentHistory.length, equals(1));
      expect(assignmentHistory.first, startsWith('Drafted in - Mono Black Burn - '));

      // 11. Verify UI reverts to Drafted
      await pumpCardDetail(tester, cardInDb);
      expect(find.textContaining('Drafted in - Mono Black Burn'), findsOneWidget);
      expect(find.text('+ Mono Black Burn'), findsNothing);
    });

    test('R8-R9-ADV-2: Rapid 10x assemble/disassemble toggle stress preserves database consistency', () async {
      final card = createTestCard(id: 'c-adv-rapid-toggle', name: 'Sheoldred, the Apocalypse');
      await db.into(db.vaultItems).insert(card);

      final deck = await dao.createDeck('Dimir Reanimator');
      await dao.addCardToDeck(deck.id, card.id);

      // Toggle assemble status 10 times in rapid succession
      for (int i = 1; i <= 10; i++) {
        final shouldAssemble = i.isOdd; // odd -> true, even -> false
        await dao.setDeckAssembled(deck.id, shouldAssemble);

        final cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
        final data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
        final assignmentHistory = (data['assignment_history'] as List).cast<String>();

        if (shouldAssemble) {
          expect(assignmentHistory, equals(['Dimir Reanimator']), reason: 'Iteration $i failed assembly check');
        } else {
          expect(assignmentHistory.length, equals(1), reason: 'Iteration $i accumulated entries');
          expect(assignmentHistory.first, startsWith('Drafted in - Dimir Reanimator - '));
        }
      }
    });

    // -------------------------------------------------------------------------
    // 2. Multiple Deck Memberships (Mixed Assembled & Drafted)
    // -------------------------------------------------------------------------
    testWidgets('R8-R9-ADV-3: Card in 4 decks simultaneously partitions formal and drafted entries accurately', (tester) async {
      final card = createTestCard(id: 'c-adv-multi-deck', name: 'Lightning Bolt');
      await db.into(db.vaultItems).insert(card);

      // Deck 1: Assembled
      final d1 = await dao.createDeck('Modern Burn');
      await dao.setDeckAssembled(d1.id, true);

      // Deck 2: Drafted (Non-assembled)
      final d2 = await dao.createDeck('Pioneer Red');

      // Deck 3: Assembled
      final d3 = await dao.createDeck('Legacy Delver');
      await dao.setDeckAssembled(d3.id, true);

      // Deck 4: Drafted (Non-assembled)
      final d4 = await dao.createDeck('Commander Tor Wauki');

      // Add card to all 4 decks
      await dao.addCardToDeck(d1.id, card.id);
      await dao.addCardToDeck(d2.id, card.id);
      await dao.addCardToDeck(d3.id, card.id);
      await dao.addCardToDeck(d4.id, card.id);

      // Re-read card from DB
      final cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      final data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
      final deckHistory = (data['deck_history'] as List).cast<String>();
      final assignmentHistory = (data['assignment_history'] as List).cast<String>();

      // Deck history has exactly 2 assembled decks
      expect(deckHistory.length, equals(2));
      expect(deckHistory, containsAll(['Modern Burn', 'Legacy Delver']));

      // Assignment history has all 4 (2 formal, 2 drafted)
      expect(assignmentHistory.length, equals(4));
      expect(assignmentHistory, containsAll(['Modern Burn', 'Legacy Delver']));
      expect(assignmentHistory.any((s) => s.startsWith('Drafted in - Pioneer Red - ')), isTrue);
      expect(assignmentHistory.any((s) => s.startsWith('Drafted in - Commander Tor Wauki - ')), isTrue);

      // Pump CardDetailSheet and verify UI renders both formal and drafted rows
      await pumpCardDetail(tester, cardInDb);
      expect(find.text('+ Modern Burn'), findsOneWidget);
      expect(find.text('+ Legacy Delver'), findsOneWidget);
      expect(find.textContaining('Drafted in - Pioneer Red'), findsOneWidget);
      expect(find.textContaining('Drafted in - Commander Tor Wauki'), findsOneWidget);

      // Now assemble Deck 2 ('Pioneer Red')
      await dao.setDeckAssembled(d2.id, true);
      final updatedCardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      final updatedData = jsonDecode(updatedCardInDb.dynamicData) as Map<String, dynamic>;
      final updatedDeckHistory = (updatedData['deck_history'] as List).cast<String>();
      final updatedAssignmentHistory = (updatedData['assignment_history'] as List).cast<String>();

      // Formal count is now 3, drafted count is 1
      expect(updatedDeckHistory.length, equals(3));
      expect(updatedDeckHistory, containsAll(['Modern Burn', 'Legacy Delver', 'Pioneer Red']));
      expect(updatedAssignmentHistory.where((s) => s.startsWith('Drafted in')).length, equals(1));
    });

    // -------------------------------------------------------------------------
    // 3. Proxies Tracking
    // -------------------------------------------------------------------------
    test('R8-R9-ADV-4: Proxy card entries are tracked in assignment history and transition on assembly', () async {
      final proxyCard = createTestCard(id: 'c-adv-proxy', name: 'Black Lotus');
      await db.into(db.vaultItems).insert(proxyCard);

      final vintageDeck = await dao.createDeck('Vintage Oath');
      // Add as proxy
      await dao.addCardToDeck(vintageDeck.id, proxyCard.id, isProxy: true);

      var cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(proxyCard.id))).getSingle();
      var data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
      var assignmentHistory = (data['assignment_history'] as List).cast<String>();

      expect(assignmentHistory.length, equals(1));
      expect(assignmentHistory.first, startsWith('Drafted in - Vintage Oath - '));

      // Assemble Vintage Oath
      await dao.setDeckAssembled(vintageDeck.id, true);

      cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(proxyCard.id))).getSingle();
      data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
      assignmentHistory = (data['assignment_history'] as List).cast<String>();

      expect(assignmentHistory, equals(['Vintage Oath']));
    });

    // -------------------------------------------------------------------------
    // 4. Card Removal from Deck
    // -------------------------------------------------------------------------
    testWidgets('R8-R9-ADV-5: removeCardFromDeck immediately purges assignment entry and restores clean empty state', (tester) async {
      final card = createTestCard(id: 'c-adv-removal', name: 'Grief');
      await db.into(db.vaultItems).insert(card);

      final deck = await dao.createDeck('Rakdos Scam');
      await dao.setDeckAssembled(deck.id, true);
      await dao.addCardToDeck(deck.id, card.id);

      var cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      await pumpCardDetail(tester, cardInDb);
      expect(find.text('+ Rakdos Scam'), findsOneWidget);

      // Remove card from deck
      await dao.removeCardFromDeck(deck.id, card.id);

      cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      var data = jsonDecode(cardInDb.dynamicData) as Map<String, dynamic>;
      expect(data['deck_history'], isEmpty);
      expect(data['assignment_history'], isEmpty);

      // UI returns to clean empty state
      await pumpCardDetail(tester, cardInDb);
      expect(find.text('No recorded deck assignment history.'), findsOneWidget);
      expect(find.text('+ Rakdos Scam'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. Deck Soft Deletion and Sync
    // -------------------------------------------------------------------------
    testWidgets('R8-R9-ADV-6: Deleting a deck marks deck and deck_version_items as deleted', (tester) async {
      final card = createTestCard(id: 'c-adv-del-deck', name: 'Thoughtseize');
      await db.into(db.vaultItems).insert(card);

      final deck = await dao.createDeck('Jund Saga');
      await dao.setDeckAssembled(deck.id, true);
      await dao.addCardToDeck(deck.id, card.id);

      // Verify active decks stream finds the deck
      var activeDecks = await dao.watchItemActiveDecks(card.id).first;
      expect(activeDecks, contains('Jund Saga'));

      // Delete deck
      await dao.deleteDeck(deck.id);

      // Verify active decks stream immediately excludes the deleted deck
      activeDecks = await dao.watchItemActiveDecks(card.id).first;
      expect(activeDecks, isEmpty);

      // Verify dynamicData is updated and stale deck is cleared
      final cardAfterDeckDelete = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      final dataAfterDelete = jsonDecode(cardAfterDeckDelete.dynamicData) as Map<String, dynamic>;
      expect(dataAfterDelete['deck_history'], isEmpty);
      expect(dataAfterDelete['assignment_history'], isEmpty);

      // Verify that CardDetailSheet reflects no active decks
      await pumpCardDetail(tester, cardAfterDeckDelete);
      expect(find.text('+ Jund Saga'), findsNothing);
      expect(find.text('No recorded deck assignment history.'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 6. Special Characters and Extreme Formatting in Deck Names
    // -------------------------------------------------------------------------
    testWidgets('R8-R9-ADV-7: Decks with quotes, brackets, slashes, and emojis render safely without malformation', (tester) async {
      final specialDeckName = 'Deck // "Omnath" & <Fire> 🌋 [2026]';
      final card = createTestCard(id: 'c-adv-special-name', name: 'Omnath, Locus of Creation');
      await db.into(db.vaultItems).insert(card);

      final deck = await dao.createDeck(specialDeckName);
      await dao.addCardToDeck(deck.id, card.id);

      final cardInDb = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      await pumpCardDetail(tester, cardInDb);

      expect(find.textContaining('Drafted in - $specialDeckName'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 7. Manual Input UI Controls Absence Invariant Check
    // -------------------------------------------------------------------------
    testWidgets('R8-R9-ADV-8: Invariant check: Manual assignment input TextField and buttons are strictly absent across all states', (tester) async {
      final card = createTestCard(id: 'c-adv-no-manual', name: 'Mox Opal');
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      // Check TextField
      expect(find.widgetWithText(TextField, 'Add deck assignment...'), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // Check Action Buttons
      expect(find.byTooltip('Add assignment'), findsNothing);
      expect(find.byIcon(Icons.add_circle), findsNothing);
    });
  });
}

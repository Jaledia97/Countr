import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    required String id,
    required String name,
    List<String> tags = const [],
    List<String> deckHistory = const [],
    String? personalNotes,
    double marketPrice = 10.0,
  }) {
    final now = DateTime.now();
    final dynamicMap = <String, dynamic>{
      'tags': tags,
      'deck_history': deckHistory,
    };

    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'MH2',
      imageUrl: 'https://example.com/$id.jpg',
      acquiredPrice: 5.0,
      acquiredDate: now,
      quantity: 4,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: now,
      personalNotes: personalNotes,
      dynamicData: jsonEncode(dynamicMap),
    );
  }

  group('Adversarial Challenge 1: Concurrency between Tags and Deck Allocations', () {
    test('Concurrently adding tags while modifying deck allocations does NOT wipe deck_history', () async {
      final card = createTestCard(
        id: 'concurrent-card-1',
        name: 'Ragavan, Nimble Pilferer',
        tags: ['modern-staple'],
        deckHistory: ['Initial Deck Alpha'],
      );
      await db.into(db.vaultItems).insert(card);

      // Create target decks
      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-red-aggro',
        name: 'Mono Red Aggro',
        format: 'Modern',
        createdAt: now,
      ));
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-murktide',
        name: 'Izzet Murktide',
        format: 'Modern',
        createdAt: now,
      ));
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-cube',
        name: 'Vintage Cube',
        format: 'Cube',
        createdAt: now,
      ));

      // Concurrently execute tag updates and deck allocations
      await Future.wait([
        db.vaultDao.updateItemCardDetails(
          id: 'concurrent-card-1',
          tags: ['modern-staple', 'pirate', 'monkey', 'red-one-drop', 'treasure'],
        ),
        db.vaultDao.setCardQuantityInDeck('deck-red-aggro', 'concurrent-card-1', 4),
        db.vaultDao.setCardQuantityInDeck('deck-murktide', 'concurrent-card-1', 4),
        db.vaultDao.setCardQuantityInDeck('deck-cube', 'concurrent-card-1', 1),
      ]);

      // Verify in SQLite directly
      final itemFromDb = await db.vaultDao.getItemById('concurrent-card-1');
      expect(itemFromDb, isNotNull);

      final parsed = jsonDecode(itemFromDb!.dynamicData) as Map<String, dynamic>;
      final tags = (parsed['tags'] as List?)?.cast<String>() ?? [];
      final deckHistory = (parsed['deck_history'] as List?)?.cast<String>() ?? [];

      // Critical Assertions:
      // 1. Tags must NOT overwrite deck_history with tags list
      expect(deckHistory, isNot(equals(tags)));
      expect(deckHistory, isNotEmpty, reason: 'deck_history must not be wiped empty');

      // 2. Custom tags must be preserved
      expect(tags, contains('monkey'));
      expect(tags, contains('treasure'));

      // 3. Active decks in SQLite must be accurately queryable
      final activeDecks = await db.vaultDao.watchItemActiveDecks('concurrent-card-1').first;
      expect(activeDecks, contains('Mono Red Aggro'));
      expect(activeDecks, contains('Izzet Murktide'));
      expect(activeDecks, contains('Vintage Cube'));
      expect(activeDecks.length, 3);

      // 4. Custom tags must not appear inside active decks or deck_history
      for (final t in tags) {
        expect(activeDecks.contains(t), isFalse, reason: 'Custom tag "$t" should not be an active deck');
      }
    });

    test('Stress Test: Rapid interleaved tag modifications and deck allocations maintain disentanglement', () async {
      final card = createTestCard(
        id: 'interleaved-stress-card',
        name: 'Mox Diamond',
        tags: ['fast-mana'],
        deckHistory: [],
      );
      await db.into(db.vaultItems).insert(card);

      final now = DateTime.now();
      for (int i = 1; i <= 5; i++) {
        await db.into(db.decks).insert(DecksCompanion.insert(
          id: 'stress-deck-$i',
          name: 'Tournament Deck #$i',
          format: 'Legacy',
          createdAt: now,
        ));
      }

      // Execute 10 rapid interleaved operations
      for (int step = 1; step <= 10; step++) {
        if (step % 2 == 1) {
          // Mutate tags
          await db.vaultDao.updateItemCardDetails(
            id: 'interleaved-stress-card',
            tags: List.generate(step, (index) => 'tag-version-$step-$index'),
          );
        } else {
          // Mutate deck allocations
          final deckIndex = (step ~/ 2);
          await db.vaultDao.setCardQuantityInDeck(
            'stress-deck-$deckIndex',
            'interleaved-stress-card',
            step % 4 + 1,
          );
        }
      }

      final item = await db.vaultDao.getItemById('interleaved-stress-card');
      expect(item, isNotNull);

      final parsed = jsonDecode(item!.dynamicData) as Map<String, dynamic>;
      final tags = (parsed['tags'] as List?)?.cast<String>() ?? [];
      final deckHistory = (parsed['deck_history'] as List?)?.cast<String>() ?? [];

      // Tags must reflect the latest odd step (step 9 had 9 tags)
      expect(tags.length, 9);
      expect(tags, contains('tag-version-9-0'));

      // Active decks must reflect allocated decks (stress-deck-1 through 5)
      final activeDecks = await db.vaultDao.watchItemActiveDecks('interleaved-stress-card').first;
      expect(activeDecks.length, 5);
      for (int i = 1; i <= 5; i++) {
        expect(activeDecks, contains('Tournament Deck #$i'));
      }

      // Disentanglement: tags and deck_history must not pollute each other
      for (final t in tags) {
        expect(deckHistory.contains(t), isFalse);
      }
    });

    test('Adversarial Name Collisions: Tags matching Deck Names are stored in separate namespaces', () async {
      final card = createTestCard(
        id: 'collision-card',
        name: 'Urza, Lord High Artificer',
        tags: ['Commander - Urza', 'Artifacts'],
        deckHistory: [],
      );
      await db.into(db.vaultItems).insert(card);

      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-urza-collision',
        name: 'Commander - Urza', // Identical string as a user tag
        format: 'Commander',
        createdAt: now,
      ));

      // Allocate card to deck with identical name
      await db.vaultDao.setCardQuantityInDeck('deck-urza-collision', 'collision-card', 1);

      // Now remove the tag 'Commander - Urza' from custom tags
      await db.vaultDao.updateItemCardDetails(
        id: 'collision-card',
        tags: ['Artifacts', 'cEDH'],
      );

      // Verify in SQLite
      final item = await db.vaultDao.getItemById('collision-card');
      final parsed = jsonDecode(item!.dynamicData) as Map<String, dynamic>;
      final tags = (parsed['tags'] as List).cast<String>();
      final deckHistory = (parsed['deck_history'] as List).cast<String>();

      // Tags removed 'Commander - Urza'
      expect(tags.contains('Commander - Urza'), isFalse);
      expect(tags, equals(['Artifacts', 'cEDH']));

      // Deck allocation MUST STILL HAVE 'Commander - Urza' in deck_history and active decks!
      expect(deckHistory, contains('Commander - Urza'));
      final activeDecks = await db.vaultDao.watchItemActiveDecks('collision-card').first;
      expect(activeDecks, contains('Commander - Urza'));
    });
  });

  group('Adversarial Challenge 2: CardDetailSheet Note Saving & Deck Allocations', () {
    testWidgets('Saving notes in CardDetailSheet does NOT erase fresh external deck allocations', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createTestCard(
        id: 'sheet-note-card',
        name: 'Demonic Tutor',
        tags: ['black-tutor'],
        deckHistory: [],
        personalNotes: 'Original note: Needs tournament sleeve.',
      );
      await db.into(db.vaultItems).insert(card);

      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-external-1',
        name: 'Grixis Control',
        format: 'Legacy',
        createdAt: now,
      ));

      // Pump CardDetailSheet with the initial card
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CardDetailSheet.show(context, card, fetchOnlinePrintings: false),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Demonic Tutor'), findsWidgets);
      expect(find.text('Original note: Needs tournament sleeve.'), findsOneWidget);

      // EXTERNAL EVENT: Card is allocated to 'Grixis Control' in SQLite while sheet is open
      await db.vaultDao.setCardQuantityInDeck('deck-external-1', 'sheet-note-card', 2);

      // Verify that SQLite already recorded the deck allocation
      final activeDecksBeforeSave = await db.vaultDao.watchItemActiveDecks('sheet-note-card').first;
      expect(activeDecksBeforeSave, contains('Grixis Control'));

      // Now the user edits notes inside the open CardDetailSheet
      final notesFinder = find.byWidgetPredicate((w) => w is TextField && w.maxLines == 3);
      expect(notesFinder, findsOneWidget);
      await tester.enterText(notesFinder, 'Updated note: Key combo finder for Thoracle.');
      await tester.pumpAndSettle();

      // Tap 'Save Notes'
      final saveNotesButton = find.text('Save Notes');
      expect(saveNotesButton, findsOneWidget);
      await tester.tap(saveNotesButton);
      await tester.pumpAndSettle();

      // Direct SQLite Inspection
      final refreshed = await db.vaultDao.getItemById('sheet-note-card');
      expect(refreshed, isNotNull);
      expect(refreshed!.personalNotes, 'Updated note: Key combo finder for Thoracle.');

      // CRITICAL CHECK: Did note save erase the deck allocation?
      final dyn = jsonDecode(refreshed.dynamicData) as Map<String, dynamic>;
      final deckHistory = (dyn['deck_history'] as List?)?.cast<String>() ?? [];
      expect(deckHistory, contains('Grixis Control'),
          reason: 'External deck allocation in deck_history must NOT be wiped by CardDetailSheet note save');

      final activeDecksAfterSave = await db.vaultDao.watchItemActiveDecks('sheet-note-card').first;
      expect(activeDecksAfterSave, contains('Grixis Control'),
          reason: 'Active deck allocations in deck_version_items must be untouched');

      // Custom tags must also remain intact
      final tags = (dyn['tags'] as List?)?.cast<String>() ?? [];
      expect(tags, contains('black-tutor'));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Emptying personal notes in CardDetailSheet preserves deck allocations and tags', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createTestCard(
        id: 'sheet-empty-note-card',
        name: 'Brainstorm',
        tags: ['cantrip', 'blue-staple'],
        deckHistory: ['Miracles Legacy'],
        personalNotes: 'Keep 1 fetchland in hand before casting.',
      );
      await db.into(db.vaultItems).insert(card);

      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-miracles',
        name: 'Miracles Legacy',
        format: 'Legacy',
        createdAt: now,
      ));
      await db.vaultDao.setCardQuantityInDeck('deck-miracles', 'sheet-empty-note-card', 4);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CardDetailSheet.show(context, card, fetchOnlinePrintings: false),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Clear the notes text completely
      final notesFinder = find.byWidgetPredicate((w) => w is TextField && w.maxLines == 3);
      expect(notesFinder, findsOneWidget);
      await tester.enterText(notesFinder, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Notes'));
      await tester.pumpAndSettle();

      final refreshed = await db.vaultDao.getItemById('sheet-empty-note-card');
      expect(refreshed, isNotNull);
      expect(refreshed!.personalNotes, anyOf(isNull, isEmpty));

      final dyn = jsonDecode(refreshed.dynamicData) as Map<String, dynamic>;
      final deckHistory = (dyn['deck_history'] as List?)?.cast<String>() ?? [];
      final tags = (dyn['tags'] as List?)?.cast<String>() ?? [];

      expect(deckHistory, contains('Miracles Legacy'));
      expect(tags, contains('blue-staple'));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Adversarial Challenge 3: Live Stream Emission on cardActiveDecksProvider and cardCustomTagsProvider', () {
    test('cardActiveDecksProvider reactively emits transitions across add, multi-deck, rename, and zero-removal', () async {
      final card = createTestCard(
        id: 'stream-test-card',
        name: 'Sol Ring',
      );
      await db.into(db.vaultItems).insert(card);

      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-alpha',
        name: 'Commander Deck Alpha',
        format: 'Commander',
        createdAt: now,
      ));
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-beta',
        name: 'Commander Deck Beta',
        format: 'Commander',
        createdAt: now,
      ));

      final container = ProviderContainer(
        overrides: [
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      final emissions = <List<String>>[];
      final sub = container.listen<AsyncValue<List<String>>>(
        cardActiveDecksProvider('stream-test-card'),
        (prev, next) {
          if (next.hasValue) emissions.add(next.value!);
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Wait for initial emission (card is in 0 decks)
      while (emissions.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(emissions.last, isEmpty);

      // Step 1: Add to Deck Alpha
      await db.vaultDao.setCardQuantityInDeck('deck-alpha', 'stream-test-card', 1);
      while (emissions.length < 2 || !emissions.last.contains('Commander Deck Alpha')) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(emissions.last, ['Commander Deck Alpha']);

      // Step 2: Add to Deck Beta (Multi-deck allocation)
      await db.vaultDao.setCardQuantityInDeck('deck-beta', 'stream-test-card', 1);
      while (emissions.last.length < 2) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(emissions.last, containsAll(['Commander Deck Alpha', 'Commander Deck Beta']));

      // Step 3: Add proxy in another deck -> Must NOT be included in active physical decks
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-proxy-gamma',
        name: 'Proxy Testing Deck',
        format: 'Commander',
        createdAt: now,
      ));
      await db.vaultDao.setCardQuantityInDeck('deck-proxy-gamma', 'stream-test-card', 1, isProxy: true);
      await Future.delayed(const Duration(milliseconds: 50));
      // Emissions should NOT contain 'Proxy Testing Deck'
      expect(emissions.last.contains('Proxy Testing Deck'), isFalse);

      // Step 4: Rename Deck Alpha in SQLite
      await (db.update(db.decks)..where((t) => t.id.equals('deck-alpha'))).write(
        const DecksCompanion(name: drift.Value('Renamed Deck Omega')),
      );
      while (!emissions.last.contains('Renamed Deck Omega')) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(emissions.last, containsAll(['Renamed Deck Omega', 'Commander Deck Beta']));

      // Step 5: Remove from Deck Beta (set quantity to 0)
      await db.vaultDao.setCardQuantityInDeck('deck-beta', 'stream-test-card', 0);
      while (emissions.last.contains('Commander Deck Beta')) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(emissions.last, ['Renamed Deck Omega']);

      // Step 6: Remove from Deck Alpha completely
      await db.vaultDao.setCardQuantityInDeck('deck-alpha', 'stream-test-card', 0);
      while (emissions.last.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(emissions.last, isEmpty);
    });

    test('cardCustomTagsProvider reactively emits updates, supports emptying, and survives metadata edits', () async {
      final card = createTestCard(
        id: 'stream-tag-card',
        name: 'Lightning Bolt',
        tags: ['burn', 'red'],
      );
      await db.into(db.vaultItems).insert(card);

      final container = ProviderContainer(
        overrides: [
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      final tagEmissions = <List<String>>[];
      final sub = container.listen<AsyncValue<List<String>>>(
        cardCustomTagsProvider('stream-tag-card'),
        (prev, next) {
          if (next.hasValue) tagEmissions.add(next.value!);
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Wait for initial emission
      while (tagEmissions.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(tagEmissions.last, ['burn', 'red']);

      // Step 1: Add new tags
      await db.vaultDao.updateItemCardDetails(
        id: 'stream-tag-card',
        tags: ['burn', 'red', 'instant', '3-damage', 'staple'],
      );
      while (tagEmissions.last.length != 5) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(tagEmissions.last, ['burn', 'red', 'instant', '3-damage', 'staple']);

      // Step 2: Empty all tags
      await db.vaultDao.updateItemCardDetails(
        id: 'stream-tag-card',
        tags: [],
      );
      while (tagEmissions.last.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(tagEmissions.last, isEmpty);

      // Step 3: Set single tag
      await db.vaultDao.updateItemCardDetails(
        id: 'stream-tag-card',
        tags: ['lightning'],
      );
      while (tagEmissions.last.isEmpty || tagEmissions.last.first != 'lightning') {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(tagEmissions.last, ['lightning']);

      // Step 4: Update other fields (price, condition) with tags: null
      // Tags stream MUST NOT be erased or corrupted
      await db.vaultDao.updateItemCardDetails(
        id: 'stream-tag-card',
        currentMarketPrice: 4.50,
        condition: 'HP',
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(tagEmissions.last, ['lightning']);
    });

    test('Isolation: cardActiveDecksProvider and cardCustomTagsProvider do not trigger false cross-talk', () async {
      final card = createTestCard(
        id: 'isolation-card',
        name: 'Chalice of the Void',
        tags: ['lockpiece', 'artifact'],
        deckHistory: [],
      );
      await db.into(db.vaultItems).insert(card);

      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-prison',
        name: 'Prison Legacy',
        format: 'Legacy',
        createdAt: now,
      ));

      final container = ProviderContainer(
        overrides: [
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      final deckEmissions = <List<String>>[];
      final deckSub = container.listen<AsyncValue<List<String>>>(
        cardActiveDecksProvider('isolation-card'),
        (prev, next) {
          if (next.hasValue) deckEmissions.add(next.value!);
        },
        fireImmediately: true,
      );
      addTearDown(deckSub.close);

      final tagEmissions = <List<String>>[];
      final tagSub = container.listen<AsyncValue<List<String>>>(
        cardCustomTagsProvider('isolation-card'),
        (prev, next) {
          if (next.hasValue) tagEmissions.add(next.value!);
        },
        fireImmediately: true,
      );
      addTearDown(tagSub.close);

      while (deckEmissions.isEmpty || tagEmissions.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(deckEmissions.last, isEmpty);
      expect(tagEmissions.last, ['lockpiece', 'artifact']);


      // 1. Allocate card to deck: deck stream should update, tag stream must preserve tags
      await db.vaultDao.setCardQuantityInDeck('deck-prison', 'isolation-card', 4);

      while (deckEmissions.last.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(deckEmissions.last, ['Prison Legacy']);
      expect(tagEmissions.last, ['lockpiece', 'artifact']);

      // 2. Update tags: tag stream should update, deck stream must preserve deck allocations
      await db.vaultDao.updateItemCardDetails(
        id: 'isolation-card',
        tags: ['lockpiece', 'artifact', 'modern-banned'],
      );

      while (tagEmissions.last.length != 3) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(tagEmissions.last, ['lockpiece', 'artifact', 'modern-banned']);
      expect(deckEmissions.last, ['Prison Legacy']);
    });
  });
}

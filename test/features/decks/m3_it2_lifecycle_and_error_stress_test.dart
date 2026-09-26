import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
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
    String id = 'card-stress-1',
    String name = 'Mox Diamond',
    String setOrSeries = 'Stronghold',
    int quantity = 2,
    double price = 650.0,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://example.com/card.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'deck_history': <String>[],
        'oracle_text': 'Discard a land card: Add one mana of any color.',
      }),
    );
  }

  Future<void> seedCard(VaultItem item) async {
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: item.id,
            collectionType: item.collectionType,
            name: item.name,
            setOrSeries: item.setOrSeries,
            imageUrl: item.imageUrl,
            acquiredPrice: item.acquiredPrice,
            acquiredDate: item.acquiredDate,
            quantity: drift.Value(item.quantity),
            condition: item.condition,
            isGraded: drift.Value(item.isGraded),
            isAltered: drift.Value(item.isAltered),
            isMisprint: drift.Value(item.isMisprint),
            isSigned: drift.Value(item.isSigned),
            currentMarketPrice: item.currentMarketPrice,
            lastPriceUpdate: item.lastPriceUpdate,
            dynamicData: item.dynamicData,
          ),
        );
  }

  Widget buildTestHost(VaultItem card, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open_sheet_button'),
                onPressed: () => CardDetailSheet.show(context, card),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SUITE 1: deckProvider Error Handling & Stream Robustness
  // =========================================================================
  group('Empirical Challenge 1: deckProvider Error Handling & Stream Robustness', () {
    test('transitions to AsyncError with underlying StateError when watching invalid deck IDs', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      final invalidIds = [
        'non-existent-uuid-12345',
        'invalid!@#\$%^&*()',
        '',
        '   ',
        'deck-that-was-never-created',
      ];

      for (final id in invalidIds) {
        final sub = container.listen(deckProvider(id), (_, _) {});
        addTearDown(sub.close);

        // Initially loading
        expect(container.read(deckProvider(id)), isA<AsyncLoading>());

        // Reading .future must reject with the underlying StateError from Drift watchSingle
        expect(
          () => container.read(deckProvider(id).future),
          throwsA(isA<StateError>()),
          reason: 'deckProvider($id).future must throw StateError',
        );

        // Wait for microtasks to settle
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final state = container.read(deckProvider(id));
        expect(state, isA<AsyncError>(), reason: 'Provider for "$id" must be AsyncError');
        expect(state.error, isA<StateError>(), reason: 'Underlying error must be StateError');
        expect(state.isLoading, isFalse, reason: 'Must NOT be stuck in AsyncLoading');
      }
    });

    test('concurrent listeners watching an invalid deck ID all receive AsyncError without deadlock', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      const invalidId = 'concurrent-missing-deck-id';

      final sub1 = container.listen(deckProvider(invalidId), (_, _) {});
      final sub2 = container.listen(deckProvider(invalidId), (_, _) {});
      final sub3 = container.listen(deckProvider(invalidId), (_, _) {});
      addTearDown(sub1.close);
      addTearDown(sub2.close);
      addTearDown(sub3.close);

      await expectLater(
        container.read(deckProvider(invalidId).future),
        throwsA(isA<StateError>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(deckProvider(invalidId));
      expect(state, isA<AsyncError>());
      expect(state.error, isA<StateError>());
      expect((state.error as StateError).message, contains('Expected exactly one element'));
    });

    test('transitions from AsyncData to AsyncError when a watched deck is deleted from database', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      // Create a deck
      final deck = await db.vaultDao.createDeck('Doomed Deck', format: 'Standard');

      final states = <AsyncValue<Deck>>[];
      final sub = container.listen(deckProvider(deck.id), (_, next) {
        states.add(next);
      }, fireImmediately: true);
      addTearDown(sub.close);

      final loadedDeck = await container.read(deckProvider(deck.id).future);
      expect(loadedDeck.name, 'Doomed Deck');
      expect(container.read(deckProvider(deck.id)), isA<AsyncData<Deck>>());

      // Now delete the deck from SQLite
      await (db.delete(db.decks)..where((tbl) => tbl.id.equals(deck.id))).go();

      // Allow Drift watch query to emit error
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final stateAfterDelete = container.read(deckProvider(deck.id));
      expect(stateAfterDelete, isA<AsyncError>(),
          reason: 'Deleting a watched deck must cause deckProvider to transition to AsyncError');
      expect(stateAfterDelete.error, isA<StateError>());
    });

    testWidgets('Consumer widget watching invalid deck cleanly renders error branch without crash', (tester) async {
      const invalidDeckId = 'ui-missing-deck-id';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final deckAsync = ref.watch(deckProvider(invalidDeckId));
                  return deckAsync.when(
                    data: (deck) => Text('Loaded: ${deck.name}'),
                    loading: () => const CircularProgressIndicator(key: Key('loading_indicator')),
                    error: (err, stack) => Text('Error: ${err.runtimeType}', key: const Key('error_text')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially loading
      expect(find.byKey(const Key('loading_indicator')), findsOneWidget);

      // Settle stream
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Must have transitioned to error widget
      expect(find.byKey(const Key('error_text')), findsOneWidget);
      expect(find.text('Error: StateError'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // SUITE 2: _showAddToDeckDialog Lifecycle & Frame Stepping Stress
  // =========================================================================
  group('Empirical Challenge 2: _showAddToDeckDialog Lifecycle & Frame-by-Frame Stepping', () {
    testWidgets('frame-stepping during dismiss by tapping existing deck throws 0 controller exceptions', (tester) async {
      final card = createTestCard();
      await seedCard(card);
      await db.vaultDao.createDeck('Commander Deck Gamma', format: 'Commander');

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);

      // Tap deck
      await tester.tap(find.text('Commander Deck Gamma'));

      // Advance frames finely during exit transition
      await tester.pump(const Duration(milliseconds: 16)); // Frame 1
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 33)); // Frame 2
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 50)); // Frame 3
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100)); // Frame 4
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle(); // Finished animation
      expect(tester.takeException(), isNull);

      expect(find.text('Add Card to Deck'), findsNothing);
    });

    testWidgets('frame-stepping during dismiss via Close button throws 0 controller exceptions', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      // Tap Close button in dialog
      await tester.tap(find.byIcon(Icons.close).last);

      // Frame stepping
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 75));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Add Card to Deck'), findsNothing);
    });

    testWidgets('dismiss during active text entry in TextField completes without use-after-dispose', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      // Enter text into the custom deck name field
      await tester.enterText(find.byType(TextField), 'Active Typing Deck Name');
      await tester.pump(const Duration(milliseconds: 50));

      // Dismiss while text is populated and focused
      await tester.tap(find.byIcon(Icons.close).last);

      // Granular stepping
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Add Card to Deck'), findsNothing);
    });

    testWidgets('rapid repeated open and dismiss churn executes cleanly 5 times in sequence', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      for (int cycle = 1; cycle <= 5; cycle++) {
        await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
        await tester.pumpAndSettle(); // Fully open modal
        expect(find.text('Add Card to Deck'), findsOneWidget);

        // Tap close
        await tester.tap(find.byIcon(Icons.close).last);
        // Step through exit animation
        await tester.pump(const Duration(milliseconds: 25));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Failed during churn cycle $cycle');
        expect(find.text('Add Card to Deck'), findsNothing);
      }
    });
  });

  // =========================================================================
  // SUITE 3: _showAddToDeckDialog Layout, Deck Counts & Viewport Stress
  // =========================================================================
  group('Empirical Challenge 3: Layout Bounds, Viewports & Deck Counts', () {
    testWidgets('stress-test with 25 decks renders inside scroll view with zero RenderFlex overflow', (tester) async {
      final card = createTestCard(quantity: 100);
      await seedCard(card);

      // Seed 25 decks
      for (int i = 1; i <= 25; i++) {
        await db.vaultDao.createDeck('Deck #$i Alpha Omega', format: 'Modern');
      }

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);

      // Verify scrolling down to access the last deck and TextField
      final scrollFinder = find.byType(SingleChildScrollView).last;
      await tester.drag(scrollFinder, const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Deck #25 Alpha Omega'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll back up to close cleanly via close button
      await tester.drag(scrollFinder, const Offset(0, 1000));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('small viewport 320x568 (iPhone SE) renders dialog cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard();
      await seedCard(card);
      for (int i = 1; i <= 8; i++) {
        await db.vaultDao.createDeck('SE Deck $i', format: 'Commander');
      }

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });


    testWidgets('ultra-short vertical height 400x320 renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard();
      await seedCard(card);
      await db.vaultDao.createDeck('Short Viewport Deck', format: 'Pauper');

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('software keyboard bottom viewInsets (350px) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard();
      await seedCard(card);
      await db.vaultDao.createDeck('Keyboard Test Deck', format: 'Commander');

      await tester.pumpWidget(buildTestHost(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap TextField to type
      await tester.enterText(find.byType(TextField).last, 'Keyboard Deck');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

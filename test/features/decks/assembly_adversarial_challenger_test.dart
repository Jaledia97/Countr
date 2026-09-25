import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/assembly_models.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';
import 'package:countr/features/decks/presentation/widgets/assembly_pick_list_dialog.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

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

  Widget createTestWidget({
    required Deck deck,
    DeckAssemblyPlan? precomputedPlan,
    double textScale = 1.0,
    ValueChanged<bool>? onRegistrationChanged,
  }) {
    return ProviderScope(
      overrides: [
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AssemblyPickListDialog(
                    deck: deck,
                    precomputedPlan: precomputedPlan,
                    onRegistrationChanged: onRegistrationChanged,
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Challenger M3-It2-1: Adversarial Layout & Resilience Verification', () {
    testWidgets('Adversarial 1: 300px viewport + 2.0x font scaling with 999 cards & super long binder name', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const longBinder = 'Supercalifragilisticexpialidocious Ultra Rare Masterpiece Binder 2026 With Extremely Long Nomenclature';
      final item = AssemblyPickItem(
        dviId: 'dvi-999',
        vaultItemId: 'v-999',
        cardName: 'Our Market Research Is Shows That Players Like Really Long Names So We Made This Card',
        setCode: 'UNH',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 999,
        availableQuantity: 999,
        pullQuantity: 999,
        deficitQuantity: 0,
        locationName: longBinder,
      );

      final plan = DeckAssemblyPlan(
        deckId: 'deck-long',
        deckName: 'Extremely Long Deck Name For Boundary Testing On Small Screen',
        items: [item],
        itemsByLocation: {longBinder: [item]},
        deficitItems: [],
      );

      final mockDeck = Deck(
        id: plan.deckId,
        name: plan.deckName,
        format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
      ));

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Ensure zero RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Verify that badge rendered and Check All exists
      expect(find.text('999 cards'), findsOneWidget);
      expect(find.byKey(const Key('check_all_$longBinder')), findsOneWidget);

      // Tap Check All
      await tester.tap(find.byKey(const Key('check_all_$longBinder')));
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Expected no overflow but encountered: $exception');
      expect(find.text('999 / 999 Pulled'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('Adversarial 1b: 300px viewport + 2.0x font scaling with 100 cards when pulled', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final item = AssemblyPickItem(
        dviId: 'bulk-100',
        vaultItemId: 'v-100',
        cardName: 'Relentless Rats Bulk 100',
        setCode: 'A25',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 100,
        availableQuantity: 100,
        pullQuantity: 100,
        deficitQuantity: 0,
        locationName: 'Bulk Box Alpha',
      );

      final plan = DeckAssemblyPlan(
        deckId: 'deck-100',
        deckName: 'Bulk Rats 100',
        items: [item],
        itemsByLocation: {'Bulk Box Alpha': [item]},
        deficitItems: [],
      );

      final mockDeck = Deck(
        id: plan.deckId,
        name: plan.deckName,
        format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
      ));

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Tap Check All
      await tester.tap(find.byKey(const Key('check_all_Bulk Box Alpha')));
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Expected no overflow but encountered: $exception');
      expect(find.text('100 / 100 Pulled'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('Adversarial 2: 320px viewport + 2.0x font scaling with multiple locations and 3-digit card counts', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final itemA = AssemblyPickItem(
        dviId: 'item-a',
        vaultItemId: 'va',
        cardName: 'Relentless Rats 1',
        setCode: 'A25',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 100,
        availableQuantity: 100,
        pullQuantity: 100,
        deficitQuantity: 0,
        locationName: 'Binder Alpha - 100 Cards Capacity',
      );

      final itemB = AssemblyPickItem(
        dviId: 'item-b',
        vaultItemId: 'vb',
        cardName: 'Shadowborn Apostle 1',
        setCode: 'M14',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 250,
        availableQuantity: 250,
        pullQuantity: 250,
        deficitQuantity: 0,
        locationName: 'Binder Beta - 250 Cards Box',
      );

      final plan = DeckAssemblyPlan(
        deckId: 'deck-ab',
        deckName: 'Rats and Apostles',
        items: [itemA, itemB],
        itemsByLocation: {
          'Binder Alpha - 100 Cards Capacity': [itemA],
          'Binder Beta - 250 Cards Box': [itemB],
        },
        deficitItems: [],
      );

      final mockDeck = Deck(
        id: plan.deckId,
        name: plan.deckName,
        format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
      ));

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('100 cards'), findsOneWidget);
      expect(find.text('250 cards'), findsOneWidget);
      expect(find.text('0 / 350 Pulled'), findsOneWidget);
    });

    testWidgets('Adversarial 3: Hit-testing of off-screen items & bottom clearance above sticky action bar', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Generate 12 locations with 2 items each (24 items total), guaranteeing deep scrolling
      final items = <AssemblyPickItem>[];
      final itemsByLocation = <String, List<AssemblyPickItem>>{};

      for (int loc = 1; loc <= 12; loc++) {
        final locName = 'Location $loc Long Title Storage Bin';
        itemsByLocation[locName] = [];
        for (int c = 1; c <= 2; c++) {
          final item = AssemblyPickItem(
            dviId: 'dvi-$loc-$c',
            vaultItemId: 'v-$loc-$c',
            cardName: 'Card L$loc C$c Specimen',
            setCode: 'SET$loc',
            boardZone: BoardZone.mainboard,
            requiredQuantity: 1,
            availableQuantity: 1,
            pullQuantity: 1,
            deficitQuantity: 0,
            locationName: locName,
          );
          items.add(item);
          itemsByLocation[locName]!.add(item);
        }
      }

      final plan = DeckAssemblyPlan(
        deckId: 'deep-scroll-deck',
        deckName: 'Deep Scrolling Stress Deck',
        items: items,
        itemsByLocation: itemsByLocation,
        deficitItems: [],
      );

      final mockDeck = Deck(
        id: plan.deckId,
        name: plan.deckName,
        format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 1.5,
      ));

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify the sticky action bar is present
      final registerBtn = find.byKey(const Key('assembly_register_deck_button'));
      expect(registerBtn, findsOneWidget);
      final registerBtnRect = tester.getRect(registerBtn);

      // The last card is 'Card L12 C2 Specimen' and is off-screen initially
      final lastCardFinder = find.text('Card L12 C2 Specimen');
      expect(lastCardFinder, findsNothing); // Off screen (virtualized)

      // Use scrollUntilVisible to bring it completely into view
      await tester.scrollUntilVisible(
        lastCardFinder,
        250.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(lastCardFinder, findsOneWidget);

      // Verify bottom clearance: The bottom of the last card tile MUST be ABOVE the top of the sticky action bar!
      final lastCardRect = tester.getRect(lastCardFinder);
      expect(
        lastCardRect.bottom < registerBtnRect.top,
        isTrue,
        reason: 'Last card (${lastCardRect.bottom}) must be completely clear of sticky action bar (${registerBtnRect.top})',
      );

      // Hit-test: Tap the last card row directly
      await tester.tap(lastCardFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Item should now be marked as pulled!
      expect(itemsByLocation['Location 12 Long Title Storage Bin']![1].isPulled, isTrue);

      // Check All on Location 12
      final checkAll12 = find.byKey(const Key('check_all_Location 12 Long Title Storage Bin'));
      expect(checkAll12, findsOneWidget);
      await tester.tap(checkAll12);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(itemsByLocation['Location 12 Long Title Storage Bin']!.every((i) => i.isPulled), isTrue);

      // Hit-test the sticky action bar while scrolled to bottom
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Adversarial 4: Sticky action bar button hit-testing and text fitting on 300px + 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(300, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final item = AssemblyPickItem(
        dviId: 'item-reg',
        vaultItemId: 'v-reg',
        cardName: 'Sol Ring',
        setCode: 'C21',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 1,
        availableQuantity: 1,
        pullQuantity: 1,
        deficitQuantity: 0,
        locationName: 'Main Binder',
      );

      final plan = DeckAssemblyPlan(
        deckId: 'deck-fit',
        deckName: 'Fitting Test',
        items: [item],
        itemsByLocation: {'Main Binder': [item]},
        deficitItems: [],
      );

      final mockDeck = Deck(
        id: plan.deckId,
        name: plan.deckName,
        format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
      ));

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final cancelBtn = find.text('Cancel');
      final registerBtn = find.byKey(const Key('assembly_register_deck_button'));

      expect(cancelBtn, findsOneWidget);
      expect(registerBtn, findsOneWidget);

      // Verify hit testing on Cancel button under 2.0x text scaling
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Dialog was popped
      expect(tester.takeException(), isNull);
      expect(find.byType(AssemblyPickListDialog), findsNothing);
    });

    testWidgets('Adversarial 5: Deficit registration prompt dialog at 300px + 2.0x text scale with long card list', (tester) async {
      tester.view.physicalSize = const Size(300, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final missingItem1 = AssemblyPickItem(
        dviId: 'dvi-m1',
        vaultItemId: 'v-m1',
        cardName: 'Black Lotus Alpha Edition Graded 10',
        setCode: 'LEA',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 1,
        availableQuantity: 0,
        pullQuantity: 0,
        deficitQuantity: 1,
        locationName: 'Unassigned',
      );

      final missingItem2 = AssemblyPickItem(
        dviId: 'dvi-m2',
        vaultItemId: 'v-m2',
        cardName: 'Mox Emerald Beta Edition Signed',
        setCode: 'LEB',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 1,
        availableQuantity: 0,
        pullQuantity: 0,
        deficitQuantity: 1,
        locationName: 'Unassigned',
      );

      final plan = DeckAssemblyPlan(
        deckId: 'deck-def-stress',
        deckName: 'Deficit Stress Deck',
        items: [missingItem1, missingItem2],
        itemsByLocation: {},
        deficitItems: [missingItem1, missingItem2],
      );

      final mockDeck = Deck(
        id: plan.deckId,
        name: plan.deckName,
        format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false,
      );

      bool registeredWithProxies = false;

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
        onRegistrationChanged: (val) {
          if (val) registeredWithProxies = true;
        },
      ));

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Tap Register Deck to show deficit modal
      final registerBtn = find.byKey(const Key('assembly_register_deck_button'));
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Missing Cards Fallback'), findsOneWidget);

      final confirmBtn = find.byKey(const Key('confirm_register_with_proxies_button'));
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(registeredWithProxies, isTrue);
    });
  });
}

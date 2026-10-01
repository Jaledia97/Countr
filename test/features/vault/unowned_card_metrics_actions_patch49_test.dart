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
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    required String id,
    required String name,
    required int quantity,
    double price = 4.50,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'MH3',
      imageUrl: 'https://cards.scryfall.io/normal/$id.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2026, 1, 1),
      personalNotes: null,
      dynamicData: jsonEncode({
        'collector_number': '101',
        'set': 'mh3',
        'mana_cost': '{1}{U}',
        'type_line': 'Instant',
        'oracle_text': 'Counter target spell unless its controller pays {2}.',
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
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(800, 2400)),
            child: child,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TIER 1 — ISOLATED FEATURE TESTS (R5, R6, R7)
  // ===========================================================================
  group('R5 — Tier 1: Portfolio & Collection Metrics Terminology ("owned" / "unowned")', () {
    testWidgets('R5-T1-1: Unowned card (quantity == 0) displays "unowned" in status metric', (tester) async {
      final unownedCard = createTestCard(id: 'c-unowned', name: 'Mana Drain', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Status box should display "unowned" or "Unowned", replacing static "Catalog Item"
      final unownedFinder = find.textContaining(RegExp(r'unowned', caseSensitive: false));
      expect(unownedFinder, findsWidgets);
      expect(find.text('Catalog Item'), findsNothing);
    });

    testWidgets('R5-T1-2: Owned card (quantity == 1) displays "owned" in status metric', (tester) async {
      final ownedCard = createTestCard(id: 'c-owned', name: 'Force of Will', quantity: 1);
      await db.into(db.vaultItems).insert(ownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: ownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final ownedFinder = find.textContaining(RegExp(r'owned', caseSensitive: false));
      expect(ownedFinder, findsWidgets);
      expect(find.text('Catalog Item'), findsNothing);
    });

    testWidgets('R5-T1-3: Owned card with multiple copies (quantity == 4) displays "owned"', (tester) async {
      final playsetCard = createTestCard(id: 'c-playset', name: 'Lightning Bolt', quantity: 4);
      await db.into(db.vaultItems).insert(playsetCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: playsetCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('4x'), findsOneWidget);
      final ownedFinder = find.textContaining(RegExp(r'owned', caseSensitive: false));
      expect(ownedFinder, findsWidgets);
    });

    testWidgets('R5-T1-4: Metric box retains "Status" label header', (tester) async {
      final card = createTestCard(id: 'c-test', name: 'Sol Ring', quantity: 0);
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('R5-T1-5: Obsolete "Catalog Item" text is never rendered for any card', (tester) async {
      final card = createTestCard(id: 'c-obs', name: 'Black Lotus', quantity: 0);
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Catalog Item'), findsNothing);
    });
  });

  group('R6 — Tier 1: Remove Delete Action for Unowned Items', () {
    testWidgets('R6-T1-1: Unowned reference card (quantity == 0) hides delete button', (tester) async {
      final unownedCard = createTestCard(id: 'c-unowned-del', name: 'Mox Diamond', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // quick_action_delete must NOT be present
      expect(find.byKey(const Key('quick_action_delete')), findsNothing);
    });

    testWidgets('R6-T1-2: Owned card (quantity == 1) renders delete button', (tester) async {
      final ownedCard = createTestCard(id: 'c-owned-del', name: 'Mox Opal', quantity: 1);
      await db.into(db.vaultItems).insert(ownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: ownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);
    });

    testWidgets('R6-T1-3: Owned card (quantity == 3) renders delete button', (tester) async {
      final multiCard = createTestCard(id: 'c-multi-del', name: 'Birds of Paradise', quantity: 3);
      await db.into(db.vaultItems).insert(multiCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: multiCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);
    });

    testWidgets('R6-T1-4: Delete icon is completely absent from action bar on unowned card', (tester) async {
      final unownedCard = createTestCard(id: 'c-unowned-icon', name: 'Bayou', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final actionBar = find.byKey(const Key('card_detail_quick_action_bar'));
      expect(actionBar, findsOneWidget);
      expect(
        find.descendant(of: actionBar, matching: find.byIcon(Icons.delete_outline_rounded)),
        findsNothing,
      );
    });

    testWidgets('R6-T1-5: Share and edit actions remain present regardless of ownership', (tester) async {
      final unownedCard = createTestCard(id: 'c-unowned-share', name: 'Tropical Island', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_action_share')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_edit')), findsOneWidget);
    });
  });

  group('R7 — Tier 1: Unowned Card Routing via "Add to +" & Removal of Standalone "Add to Vault"', () {
    testWidgets('R7-T1-1: Unowned card displays "Add to +" instead of "Add to deck"', (tester) async {
      final unownedCard = createTestCard(id: 'c-unowned-plus', name: 'Taiga', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // quick_action_add_to_plus must be present, quick_action_add_to_deck absent
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_deck')), findsNothing);
      expect(find.text('Add to +'), findsOneWidget);
    });

    testWidgets('R7-T1-2: Owned card displays standard "Add to Deck" button', (tester) async {
      final ownedCard = createTestCard(id: 'c-owned-deck', name: 'Volcanic Island', quantity: 1);
      await db.into(db.vaultItems).insert(ownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: ownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_action_add_to_deck')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsNothing);
      expect(find.text('Add to Deck'), findsOneWidget);
    });

    testWidgets('R7-T1-3: Standalone "Add to Vault" button is removed from unowned card details', (tester) async {
      final unownedCard = createTestCard(id: 'c-unowned-no-btn', name: 'Scrubland', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_add_to_vault')), findsNothing);
    });

    testWidgets('R7-T1-4: Standalone "Add to Vault" button is absent for owned cards as well', (tester) async {
      final ownedCard = createTestCard(id: 'c-owned-no-btn', name: 'Badlands', quantity: 1);
      await db.into(db.vaultItems).insert(ownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: ownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_add_to_vault')), findsNothing);
    });

    testWidgets('R7-T1-5: Tapping "Add to +" opens destination selector modal', (tester) async {
      final unownedCard = createTestCard(id: 'c-unowned-tap', name: 'Plateau', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();

      // Modal bottom sheet should display Binders and Decks routing options
      expect(find.textContaining('Binders'), findsWidgets);
      expect(find.textContaining('Decks'), findsWidgets);
    });
  });

  // ===========================================================================
  // TIER 2 — BOUNDARY & CORNER CASES
  // ===========================================================================
  group('R5, R6, R7 — Tier 2: Boundary & Corner Cases', () {
    testWidgets('R5-T2-1: Negative quantity defensive boundary displays "unowned"', (tester) async {
      final negativeCard = createTestCard(id: 'c-neg', name: 'Savannah', quantity: -1);
      await db.into(db.vaultItems).insert(negativeCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: negativeCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final unownedFinder = find.textContaining(RegExp(r'unowned', caseSensitive: false));
      expect(unownedFinder, findsWidgets);
    });

    testWidgets('R5-T2-2: Large quantity (quantity == 99) displays "owned"', (tester) async {
      final largeCard = createTestCard(id: 'c-large', name: 'Relentless Rats', quantity: 99);
      await db.into(db.vaultItems).insert(largeCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: largeCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('99x'), findsOneWidget);
      final ownedFinder = find.textContaining(RegExp(r'owned', caseSensitive: false));
      expect(ownedFinder, findsWidgets);
    });

    testWidgets('R6-T2-1: Delete action on owned card triggers confirmation prompt', (tester) async {
      final ownedCard = createTestCard(id: 'c-del-confirm', name: 'Tundra', quantity: 1);
      await db.into(db.vaultItems).insert(ownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: ownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('R7-T2-1: Selecting Decks from "Add to +" presents deck selection', (tester) async {
      final unownedCard = createTestCard(id: 'c-decks-proxy', name: 'Underground Sea', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();

      // Tap on Decks option in modal
      final decksOption = find.textContaining('Decks');
      expect(decksOption, findsWidgets);
      await tester.tap(decksOption.first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('R7-T2-2: Rapid double tap on "Add to +" does not produce unhandled exception', (tester) async {
      final unownedCard = createTestCard(id: 'c-rapid-tap', name: 'Gaea\'s Cradle', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final plusBtn = find.byKey(const Key('quick_action_add_to_plus'));
      await tester.tap(plusBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // TIER 3 — PAIRWISE & CROSS-FEATURE COMBINATIONS
  // ===========================================================================
  group('R5, R6, R7 — Tier 3: Cross-Feature State Invariants', () {
    testWidgets('R5-R6-R7-T3-1: Unowned card satisfies all Patch 4.9 inventory invariants conjointly', (tester) async {
      final card = createTestCard(id: 'c-invariant-unowned', name: 'Lion\'s Eye Diamond', quantity: 0);
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // 1. Status metric is unowned
      expect(find.textContaining(RegExp(r'unowned', caseSensitive: false)), findsWidgets);
      expect(find.text('Catalog Item'), findsNothing);

      // 2. Delete button is hidden
      expect(find.byKey(const Key('quick_action_delete')), findsNothing);

      // 3. Add to + is present; Add to Deck is absent
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_deck')), findsNothing);

      // 4. Standalone Add to Vault button is absent
      expect(find.byKey(const Key('card_detail_add_to_vault')), findsNothing);
    });

    testWidgets('R5-R6-R7-T3-2: Owned card satisfies all Patch 4.9 inventory invariants conjointly', (tester) async {
      final card = createTestCard(id: 'c-invariant-owned', name: 'Candelabra of Tawnos', quantity: 2);
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // 1. Status metric is owned
      expect(find.textContaining(RegExp(r'owned', caseSensitive: false)), findsWidgets);
      expect(find.text('Catalog Item'), findsNothing);

      // 2. Delete button is present
      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);

      // 3. Add to Deck is present; Add to + is absent
      expect(find.byKey(const Key('quick_action_add_to_deck')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsNothing);

      // 4. Standalone Add to Vault button is absent
      expect(find.byKey(const Key('card_detail_add_to_vault')), findsNothing);
    });
  });

  // ===========================================================================
  // TIER 4 — REAL-WORLD WORKLOAD SCENARIOS & E2E FLOWS
  // ===========================================================================
  group('R5, R6, R7 — Tier 4: Real-World Workload Scenarios & E2E Flows', () {
    testWidgets('R5-R6-R7-T4-1: Unowned catalog card inspection and routing workflow', (tester) async {
      final unownedCard = createTestCard(id: 'c-flow-1', name: 'City of Traitors', quantity: 0);
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Step 1: Verify initial unowned presentation
      expect(find.text('0x'), findsOneWidget);
      expect(find.byKey(const Key('quick_action_delete')), findsNothing);
      expect(find.byKey(const Key('card_detail_add_to_vault')), findsNothing);

      // Step 2: User taps 'Add to +'
      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();

      // Step 3: Destination selector appears
      expect(find.textContaining('Binders'), findsWidgets);
      expect(find.textContaining('Decks'), findsWidgets);
    });
  });
}

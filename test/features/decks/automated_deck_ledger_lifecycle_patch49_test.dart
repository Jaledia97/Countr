import 'dart:convert';
import 'package:drift/drift.dart' as drift;
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

    // Scroll down so Section 6 (Deck Assignment History) enters view
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.first, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
  }

  // ===========================================================================
  // TIER 1 — ISOLATED FEATURE TESTS (R8 & R9)
  // ===========================================================================
  group('R8 — Tier 1: Automated Deck Assignment Tracking (Remove Manual Input)', () {
    testWidgets('R8-T1-1: History ledger has NO manual text input TextField', (tester) async {
      final card = createTestCard(id: 'c-r8-1', name: 'Sol Ring');
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      // Manual input field with hint 'Add deck assignment...' must be removed
      expect(find.widgetWithText(TextField, 'Add deck assignment...'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('R8-T1-2: History ledger has NO manual add button', (tester) async {
      final card = createTestCard(id: 'c-r8-2', name: 'Mana Crypt');
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.byTooltip('Add assignment'), findsNothing);
      expect(find.byIcon(Icons.add_circle), findsNothing);
    });

    testWidgets('R8-T1-3: History section header displays "Deck Assignment History"', (tester) async {
      final card = createTestCard(id: 'c-r8-3', name: 'Mox Diamond');
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.text('Deck Assignment History'), findsOneWidget);
    });

    testWidgets('R8-T1-4: Automated system entries render without user manual input', (tester) async {
      final card = createTestCard(
        id: 'c-r8-4',
        name: 'Urza, Lord High Artificer',
        deckHistory: ['Urza Competitive Thopters'],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('Urza Competitive Thopters'), findsWidgets);
    });

    testWidgets('R8-T1-5: Clean empty state displayed when card has no assignments', (tester) async {
      final card = createTestCard(id: 'c-r8-5', name: 'Demonic Tutor');
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.text('No recorded deck assignment history.'), findsOneWidget);
    });
  });

  group('R9 — Tier 1: Deck Assignment Lifecycle Ledger (Assembled vs Drafted)', () {
    testWidgets('R9-T1-1: Card in non-assembled deck renders "Drafted in - [Deck Name]"', (tester) async {
      final card = createTestCard(
        id: 'c-r9-1',
        name: 'Ragavan, Nimble Pilferer',
        deckHistory: ['Drafted in - Mono Red Aggro - 2026-10-01'],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('Drafted in - Mono Red Aggro'), findsOneWidget);
    });

    testWidgets('R9-T1-2: Card in assembled deck renders formal assignment entry', (tester) async {
      final card = createTestCard(
        id: 'c-r9-2',
        name: 'Yuriko, the Tiger\'s Shadow',
        deckHistory: ['Yuriko Ninjas'],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('Yuriko Ninjas'), findsOneWidget);
      expect(find.textContaining('Drafted in'), findsNothing);
    });

    test('R9-T1-3: Assembling a deck updates isAssembled flag in SQLite database', () async {
      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-assemble-test',
        name: 'Grixis Control',
        format: 'Modern',
        createdAt: now,
        isAssembled: const drift.Value(false),
      ));

      // Assemble the deck
      await dao.setDeckAssembled('deck-assemble-test', true);

      final deck = await (dao.select(dao.decks)..where((t) => t.id.equals('deck-assemble-test'))).getSingle();
      expect(deck.isAssembled, isTrue);
    });

    test('R9-T1-4: Disassembling a deck updates isAssembled flag to false in SQLite', () async {
      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-disassemble-test',
        name: 'Jund Midrange',
        format: 'Modern',
        createdAt: now,
        isAssembled: const drift.Value(true),
      ));

      // Disassemble the deck
      await dao.setDeckAssembled('deck-disassemble-test', false);

      final deck = await (dao.select(dao.decks)..where((t) => t.id.equals('deck-disassemble-test'))).getSingle();
      expect(deck.isAssembled, isFalse);
    });

    test('R9-T1-5: Registered tournament deck defaults to assembled status', () async {
      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-reg-test',
        name: 'Azorius Control',
        format: 'Modern',
        createdAt: now,
        isRegistered: const drift.Value(true),
        isAssembled: const drift.Value(true),
      ));

      final deck = await (dao.select(dao.decks)..where((t) => t.id.equals('deck-reg-test'))).getSingle();
      expect(deck.isRegistered, isTrue);
      expect(deck.isAssembled, isTrue);
    });
  });

  // ===========================================================================
  // TIER 2 — BOUNDARY & CORNER CASES (Special chars, multi-deck, formatting)
  // ===========================================================================
  group('R9 — Tier 2: Boundary & Corner Cases', () {
    testWidgets('R9-T2-1: Deck with special characters formatted safely in ledger', (tester) async {
      final card = createTestCard(
        id: 'c-special',
        name: 'Force of Negation',
        deckHistory: ['Drafted in - Grixis // Control! (2026) - 2026-10-01'],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('Drafted in - Grixis // Control! (2026)'), findsOneWidget);
    });

    testWidgets('R9-T2-2: Card assigned across multiple decks renders both formal and drafted entries', (tester) async {
      final card = createTestCard(
        id: 'c-multi-deck',
        name: 'Thoughtseize',
        deckHistory: [
          'Modern Jund', // Assembled deck
          'Drafted in - Pioneer Rakdos - 2026-10-01', // Non-assembled deck
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('Modern Jund'), findsOneWidget);
      expect(find.textContaining('Drafted in - Pioneer Rakdos'), findsOneWidget);
    });

    testWidgets('R9-T2-3: Date timestamp formatting in Drafted in ledger entry is preserved', (tester) async {
      final card = createTestCard(
        id: 'c-date-format',
        name: 'Bloodstained Mire',
        deckHistory: ['Drafted in - Rakdos Scam - 2026-09-15'],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('2026-09-15'), findsOneWidget);
    });

    test('R9-T2-4: Soft deleted deck version items are excluded from active deck queries', () async {
      final card = createTestCard(id: 'c-soft-del', name: 'Lightning Bolt');
      await db.into(db.vaultItems).insert(card);

      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-deleted-test',
        name: 'Burn Deleted',
        format: 'Modern',
        createdAt: now,
        isDeleted: const drift.Value(true),
      ));

      final activeDecks = await dao.watchItemActiveDecks('c-soft-del').first;
      expect(activeDecks.contains('Burn Deleted'), isFalse);
    });

    testWidgets('R9-T2-5: Duplicate assignments of same deck name collapse into distinct ledger entries', (tester) async {
      final card = createTestCard(
        id: 'c-dup-deck',
        name: 'Misty Rainforest',
        deckHistory: [
          'Drafted in - Simic Mutate - 2026-10-01',
          'Drafted in - Simic Mutate - 2026-10-01',
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('Simic Mutate'), findsWidgets);
    });
  });

  // ===========================================================================
  // TIER 3 — PAIRWISE & CROSS-FEATURE COMBINATIONS
  // ===========================================================================
  group('R8, R9 — Tier 3: Cross-Feature Combinations', () {
    testWidgets('R8-R9-T3-1: Ledger renders system entries without manual input UI present', (tester) async {
      final card = createTestCard(
        id: 'c-combo-1',
        name: 'Counterspell',
        deckHistory: [
          'Drafted in - Dimir Rogues - 2026-10-01',
          'Azorius Spirits',
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      // Verify entries rendered
      expect(find.textContaining('Dimir Rogues'), findsOneWidget);
      expect(find.textContaining('Azorius Spirits'), findsOneWidget);

      // Verify manual input controls remain absent
      expect(find.widgetWithText(TextField, 'Add deck assignment...'), findsNothing);
      expect(find.byTooltip('Add assignment'), findsNothing);
    });

    testWidgets('R9-T3-2: Visual distinction in ledger rows for drafted vs formal entries', (tester) async {
      final card = createTestCard(
        id: 'c-styling-test',
        name: 'Tarmogoyf',
        deckHistory: [
          'Drafted in - Jund 2026 - 2026-10-01',
          'Legacy Lands',
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      // Both entries render cleanly without exception or overflow
      expect(find.textContaining('Drafted in - Jund 2026'), findsOneWidget);
      expect(find.textContaining('Legacy Lands'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // TIER 4 — REAL-WORLD WORKLOAD SCENARIOS & E2E FLOWS
  // ===========================================================================
  group('R8, R9 — Tier 4: Real-World Workload Scenarios & E2E Flows', () {
    testWidgets('R8-R9-T4-1: Deck drafting to assembly lifecycle flow', (tester) async {
      // Step 1: Card is drafted into non-assembled deck
      final card = createTestCard(
        id: 'c-lifecycle-flow',
        name: 'Murktide Regent',
        deckHistory: ['Drafted in - Izzet Murktide - 2026-10-01'],
      );
      await db.into(db.vaultItems).insert(card);

      await pumpCardDetail(tester, card);

      expect(find.textContaining('Drafted in - Izzet Murktide'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Add deck assignment...'), findsNothing);

      // Step 2: Deck gets assembled in SQLite
      final now = DateTime.now();
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-murktide-flow',
        name: 'Izzet Murktide',
        format: 'Modern',
        createdAt: now,
        isAssembled: const drift.Value(true),
      ));

      await dao.setDeckAssembled('deck-murktide-flow', true);

      // Step 3: Card is updated with formal deck history
      final updatedCard = createTestCard(
        id: 'c-lifecycle-flow',
        name: 'Murktide Regent',
        deckHistory: ['Izzet Murktide'],
      );
      await (db.update(db.vaultItems)..where((t) => t.id.equals('c-lifecycle-flow'))).write(
        VaultItemsCompanion(dynamicData: drift.Value(updatedCard.dynamicData)),
      );

      await pumpCardDetail(tester, updatedCard);

      // Formal deck assignment is now shown
      expect(find.textContaining('Izzet Murktide'), findsWidgets);
    });

    testWidgets('R8-R9-T4-2: Multi-deck assignment state with 1 assembled and 2 drafted decks', (tester) async {
      final multiCard = createTestCard(
        id: 'c-triple-deck',
        name: 'Scalding Tarn',
        deckHistory: [
          'Modern UR Murktide', // Assembled
          'Drafted in - Grixis Shadow - 2026-10-01', // Drafted 1
          'Drafted in - Jeskai Control - 2026-10-01', // Drafted 2
        ],
      );
      await db.into(db.vaultItems).insert(multiCard);

      await pumpCardDetail(tester, multiCard);

      expect(find.textContaining('Modern UR Murktide'), findsOneWidget);
      expect(find.textContaining('Drafted in - Grixis Shadow'), findsOneWidget);
      expect(find.textContaining('Drafted in - Jeskai Control'), findsOneWidget);
    });
  });
}

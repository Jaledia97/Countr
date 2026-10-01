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
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';
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

  VaultItem createCardWithKeywords({
    String id = 'card-mechanics-test',
    String name = 'Keyword Monster',
    List<String> keywords = const ['Flying', 'Haste'],
    String oracleText = 'Flying, haste.',
    String collectionType = 'mtg',
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'MH3',
      imageUrl: 'https://cards.scryfall.io/normal/monster.jpg',
      acquiredPrice: 5.0,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: 5.0,
      lastPriceUpdate: DateTime(2026, 1, 1),
      personalNotes: null,
      dynamicData: jsonEncode({
        'keywords': keywords,
        'oracle_text': oracleText,
        'type_line': 'Creature — Dragon',
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
  // TIER 1 — ISOLATED FEATURE TESTS (R4: Card Mechanics Tag Deduplication)
  // ===========================================================================
  group('R4 — Tier 1: Isolated Keyword & Mechanics Deduplication Tests', () {
    test('R4-T1-1: extractKeywords deduplicates identical duplicate keywords', () {
      final extracted = MtgKeywordGlossary.extractKeywords(
        keywords: ['Flying', 'Flying'],
        oracleText: '',
      );
      expect(extracted.length, equals(1));
      expect(extracted.first, equals('Flying'));
    });

    test('R4-T1-2: extractKeywords deduplicates case-variant keywords', () {
      final extracted = MtgKeywordGlossary.extractKeywords(
        keywords: ['trample', 'Trample', 'TRAMPLE'],
        oracleText: '',
      );
      expect(extracted.length, equals(1));
      expect(extracted.first, equals('Trample'));
    });

    test('R4-T1-3: extractKeywords preserves distinct multiple keywords', () {
      final extracted = MtgKeywordGlossary.extractKeywords(
        keywords: ['Flying', 'Lifelink', 'Deathtouch'],
        oracleText: '',
      );
      expect(extracted.length, equals(3));
      expect(extracted, containsAll(['Flying', 'Lifelink', 'Deathtouch']));
    });

    testWidgets('R4-T1-4: CardDetailSheet renders exactly 1 badge for duplicate keyword in list', (tester) async {
      final card = createCardWithKeywords(
        keywords: ['Flying', 'Flying'],
        oracleText: 'Flying',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Card Mechanics & Rulings section should render
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      // The keyword chip for Flying should appear exactly once in the mechanics badge wrap
      final flyingBadge = find.descendant(
        of: find.byType(Wrap),
        matching: find.text('Flying'),
      );
      expect(flyingBadge, findsOneWidget);
    });

    testWidgets('R4-T1-5: Non-MTG card or card with zero keywords renders no mechanics section', (tester) async {
      final card = createCardWithKeywords(
        collectionType: 'pokemon',
        keywords: [],
        oracleText: 'Do 50 damage.',
      );

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics & Rulings'), findsNothing);
    });
  });

  // ===========================================================================
  // TIER 2 — BOUNDARY & CORNER CASES (Empty strings, 50x duplicates, Multi-word)
  // ===========================================================================
  group('R4 — Tier 2: Boundary & Corner Cases', () {
    test('R4-T2-1: Ignores null, empty, and whitespace strings in keywords list', () {
      final extracted = MtgKeywordGlossary.extractKeywords(
        keywords: [null, '', '   ', 'Haste', '   '],
        oracleText: '',
      );
      expect(extracted.length, equals(1));
      expect(extracted.first, equals('Haste'));
    });

    test('R4-T2-2: Extreme volume duplicate stress (50x "Haste") collapses to 1 keyword', () {
      final fiftyHastes = List.generate(50, (_) => 'Haste');
      final extracted = MtgKeywordGlossary.extractKeywords(
        keywords: fiftyHastes,
        oracleText: 'Haste haste Haste',
      );
      expect(extracted.length, equals(1));
      expect(extracted.first, equals('Haste'));
    });

    test('R4-T2-3: Multi-word keywords with varying case and boundaries ("First Strike")', () {
      final extracted = MtgKeywordGlossary.extractKeywords(
        keywords: ['First Strike', 'first strike', 'FIRST STRIKE'],
        oracleText: 'First strike',
      );
      expect(extracted.length, equals(1));
      expect(extracted.first, equals('First Strike'));
    });

    test('R4-T2-4: Substring protection does not accidentally extract non-keywords', () {
      // e.g. "flying" in "butterfly" should not match if proper word boundaries are used
      final extracted = MtgKeywordGlossary.extractKeywords(
        keywords: [],
        oracleText: 'Create a butterfly token with fluttering wings.',
      );
      expect(extracted.contains('Flying'), isFalse);
    });

    testWidgets('R4-T2-5: CardDetailSheet with 10 duplicate keywords renders exactly 1 badge and 1 glossary definition', (tester) async {
      final card = createCardWithKeywords(
        keywords: List.generate(10, (_) => 'Vigilance'),
        oracleText: 'Vigilance. Vigilance.',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      // 'Vigilance' badge in chip wrap
      expect(find.text('Vigilance'), findsOneWidget);
      // Glossary definition should also appear exactly once
      expect(find.text(MtgKeywordGlossary.dictionary['Vigilance']!), findsOneWidget);
    });
  });

  // ===========================================================================
  // TIER 3 — PAIRWISE & CROSS-FEATURE COMBINATIONS
  // ===========================================================================
  group('R4 — Tier 3: Cross-Feature Combinations', () {
    testWidgets('R4-T3-1: Keywords combined from keywords list and oracleText are merged without duplicates', (tester) async {
      final card = createCardWithKeywords(
        keywords: ['Flying', 'Deathtouch'],
        oracleText: 'Flying. When this creature dies, it deals 1 damage to each opponent.',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Flying'), findsOneWidget);
      expect(find.text('Deathtouch'), findsOneWidget);
    });

    testWidgets('R4-T3-2: Multiple distinct keywords render side-by-side in wrap layout', (tester) async {
      final card = createCardWithKeywords(
        keywords: ['Flying', 'Lifelink', 'First Strike'],
        oracleText: 'Flying, first strike, lifelink',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Flying'), findsOneWidget);
      expect(find.text('Lifelink'), findsOneWidget);
      expect(find.text('First Strike'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TIER 4 — REAL-WORLD WORKLOAD SCENARIOS & E2E FLOWS
  // ===========================================================================
  group('R4 — Tier 4: Real-World Workload Scenarios & E2E Flows', () {
    testWidgets('R4-T4-1: Danitha Capashen style legendary creature with 3 keywords verifies 0 duplicate tags', (tester) async {
      final danitha = VaultItem(
        id: 'c-danitha',
        collectionType: 'mtg',
        name: 'Danitha Capashen, Paragon',
        setOrSeries: 'DOM',
        imageUrl: 'https://cards.scryfall.io/danitha.jpg',
        acquiredPrice: 0.50,
        acquiredDate: DateTime(2026, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 0.50,
        lastPriceUpdate: DateTime(2026, 1, 1),
        dynamicData: jsonEncode({
          'keywords': ['First Strike', 'Lifelink', 'Vigilance', 'First Strike', 'lifelink'],
          'oracle_text':
              'First strike, vigilance, lifelink\nAura and Equipment spells you cast cost {1} less to cast.',
          'type_line': 'Legendary Creature — Human Knight',
        }),
      );
      await db.into(db.vaultItems).insert(danitha);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: danitha, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Zero duplicate tags
      expect(find.text('First Strike'), findsOneWidget);
      expect(find.text('Lifelink'), findsOneWidget);
      expect(find.text('Vigilance'), findsOneWidget);

      // Verify each definition appears exactly once
      expect(find.text(MtgKeywordGlossary.dictionary['First Strike']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Lifelink']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Vigilance']!), findsOneWidget);
    });

    testWidgets('R4-T4-2: Rebuilding sheet preserves deduplicated tags without widget accumulation', (tester) async {
      final card = createCardWithKeywords(
        keywords: ['Trample', 'trample'],
        oracleText: 'Trample',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final trampleFinder = find.descendant(
        of: find.byType(Wrap),
        matching: find.text('Trample'),
      );
      expect(trampleFinder, findsOneWidget);

      // Trigger rebuild
      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(trampleFinder, findsOneWidget);
    });
  });
}

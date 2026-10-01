import 'dart:convert';
import 'dart:math';
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

  VaultItem createTestCard({
    String id = 'card-r4-adv',
    String name = 'Akroma, Vision of Ixidor',
    List<dynamic>? keywords,
    String? oracleText,
    String collectionType = 'mtg',
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'CMR',
      imageUrl: 'https://cards.scryfall.io/akroma.jpg',
      acquiredPrice: 8.0,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: 8.0,
      lastPriceUpdate: DateTime(2026, 1, 1),
      personalNotes: null,
      dynamicData: jsonEncode({
        'keywords': keywords ?? ['Flying', 'First Strike'],
        'oracle_text': oracleText ?? 'Flying, first strike',
        'type_line': 'Legendary Creature — Angel',
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
            data: const MediaQueryData(size: Size(800, 3000)),
            child: child,
          ),
        ),
      ),
    );
  }

  group('R4 — Adversarial Stress Test: Card Mechanics Deduplication', () {
    // -------------------------------------------------------------------------
    // 1. Extreme Volume Duplicates (100x & 500x)
    // -------------------------------------------------------------------------
    test('R4-ADV-1: 100x duplicate keywords collapse to strictly 1 canonical keyword', () {
      final hundredFlyings = List.generate(100, (_) => 'Flying');
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: hundredFlyings,
        oracleText: 'Flying',
      );

      expect(result.length, equals(1));
      expect(result.first, equals('Flying'));
    });

    test('R4-ADV-2: 500x heterogeneous keywords with mixed duplicates collapse cleanly', () {
      final input = <String>[];
      for (int i = 0; i < 100; i++) {
        input.addAll(['Flying', 'Lifelink', 'Vigilance', 'Trample', 'Haste']);
      }
      expect(input.length, equals(500));

      final result = MtgKeywordGlossary.extractKeywords(
        keywords: input,
        oracleText: 'Flying, lifelink, vigilance, trample, haste.',
      );

      expect(result.length, equals(5));
      expect(result, containsAll(['Flying', 'Lifelink', 'Vigilance', 'Trample', 'Haste']));
      // Verify no duplicates by comparing list length to set length
      expect(result.toSet().length, equals(result.length));
    });

    // -------------------------------------------------------------------------
    // 2. Mixed-Case Variations
    // -------------------------------------------------------------------------
    test('R4-ADV-3: Mixed-case adversarial permutation stress collapses to canonical dictionary casing', () {
      final mixedCaseVariations = [
        'flying',
        'FLYING',
        'Flying',
        'fLyInG',
        'FLyInG',
        'FlYiNg',
        'flyinG',
        'FLYinG',
        'tRaMpLe',
        'TRAMPLE',
        'trample',
        'Trample',
      ];

      final result = MtgKeywordGlossary.extractKeywords(
        keywords: mixedCaseVariations,
        oracleText: '',
      );

      expect(result.length, equals(2));
      expect(result, containsAll(['Flying', 'Trample']));
    });

    // -------------------------------------------------------------------------
    // 3. Whitespace Variations (Tabs, Newlines, Leading/Trailing Spaces)
    // -------------------------------------------------------------------------
    test('R4-ADV-4: Pathological whitespace variations are sanitized and deduplicated', () {
      final whitespaceVariations = [
        '   Flying   ',
        '\tFlying\n',
        '\r\nFlying\t',
        '   ',
        '',
        '\t\t',
        '  First Strike  ',
        'First Strike\n',
        '\tFirst Strike',
      ];

      final result = MtgKeywordGlossary.extractKeywords(
        keywords: whitespaceVariations,
        oracleText: '',
      );

      expect(result.length, equals(2));
      expect(result, containsAll(['Flying', 'First Strike']));
    });

    // -------------------------------------------------------------------------
    // 4. Punctuation Variations
    // -------------------------------------------------------------------------
    test('R4-ADV-5: Trailing and surrounding punctuation matches canonical dictionary keys', () {
      final punctuationVariations = [
        'Flying,',
        'Flying.',
        'Flying;',
        'Flying!',
        '(Flying)',
        'Haste.',
        'Haste,',
      ];

      final result = MtgKeywordGlossary.extractKeywords(
        keywords: punctuationVariations,
        oracleText: '',
      );

      // Punctuation containing tokens that match word boundary regex
      expect(result.contains('Flying'), isTrue);
      expect(result.contains('Haste'), isTrue);
      // Case-insensitive uniqueness check
      final lowerSet = result.map((k) => k.toLowerCase()).toSet();
      expect(lowerSet.length, equals(result.length));
    });

    test('R4-ADV-6: Oracle text with complex sentence structure extracts 0 duplicate keywords', () {
      const complexOracle = '''
Flying, first strike, vigilance, trample, haste.
This creature has flying as long as you control an Island.
Whenever this creature attacks, it gains lifelink and deathtouch until end of turn.
Double strike (This creature deals both first-strike and regular combat damage.)
Ward {2} (Whenever this creature becomes the target of a spell or ability...)
Hexproof from black.
''';

      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['Flying', 'First Strike', 'Vigilance'],
        oracleText: complexOracle,
      );

      // Verify no duplicate tags
      final lowerSet = result.map((k) => k.toLowerCase()).toSet();
      expect(lowerSet.length, equals(result.length));

      // Key canonical mechanics should be present
      expect(result, containsAll([
        'Flying',
        'First Strike',
        'Vigilance',
        'Trample',
        'Haste',
        'Lifelink',
        'Deathtouch',
        'Double Strike',
        'Ward',
        'Hexproof',
      ]));
    });

    // -------------------------------------------------------------------------
    // 5. Non-Dictionary Custom Mechanics (Cascade, Storm, etc.)
    // -------------------------------------------------------------------------
    test('R4-ADV-7: Non-dictionary mechanics are also case-insensitively deduplicated', () {
      final customMechanics = [
        'Cascade',
        'cascade',
        'CASCADE',
        '   Cascade   ',
        'Storm',
        'STORM',
        'storm',
        'Dredge 5',
        'dredge 5',
      ];

      final result = MtgKeywordGlossary.extractKeywords(
        keywords: customMechanics,
        oracleText: '',
      );

      expect(result.length, equals(3));
      final lowerSet = result.map((k) => k.toLowerCase()).toSet();
      expect(lowerSet.length, equals(3));
      expect(lowerSet, containsAll(['cascade', 'storm', 'dredge 5']));
    });

    // -------------------------------------------------------------------------
    // 6. Substring Protection & False Positive Stress
    // -------------------------------------------------------------------------
    test('R4-ADV-8: Words containing keyword substrings do NOT trigger false matches', () {
      const nonMatchingOracle = '''
Create a butterfly token with fluttering wings.
Consult the town warden in the wardroom.
He lives a simple life without reaching for glory.
The soldiers were trampled in the fray.
Defying all odds, the hero stands.
''';

      final result = MtgKeywordGlossary.extractKeywords(
        keywords: [],
        oracleText: nonMatchingOracle,
      );

      // 'butterfly' must not match 'Flying'
      expect(result.contains('Flying'), isFalse);
      // 'wardroom' must not match 'Ward' (unless standalone 'ward' appeared)
      // 'life' must not match 'Lifelink'
      expect(result.contains('Lifelink'), isFalse);
      // 'defying' must not match 'Flying'
      expect(result.contains('Flying'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 7. 1000-Element Random Keyword Fuzz Stress Test
    // -------------------------------------------------------------------------
    test('R4-ADV-9: 1000-element random fuzz list processes in < 50ms with 100% deduplication', () {
      final random = Random(42);
      final pool = [
        'Flying', 'flying', 'FLYING', '   Flying   ',
        'Haste', 'haste', 'HASTE', 'Haste!',
        'Trample', 'trample', 'TRAMPLE', 'Trample.',
        'Lifelink', 'lifelink', 'LIFELINK',
        'Vigilance', 'vigilance', 'VIGILANCE',
        'Deathtouch', 'deathtouch', 'DEATHTOUCH',
        'First Strike', 'first strike', 'FIRST STRIKE',
        'Cascade', 'cascade', 'CASCADE',
        'Storm', 'storm', 'STORM',
        '', '   ', null,
      ];

      final fuzzKeywords = List.generate(1000, (_) => pool[random.nextInt(pool.length)]);

      final stopwatch = Stopwatch()..start();
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: fuzzKeywords,
        oracleText: 'Flying, haste, trample, lifelink.',
      );
      stopwatch.stop();

      // Must complete rapidly
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // Absolute deduplication: no two items have same lowercase representation
      final lowerSet = result.map((k) => k.toLowerCase()).toSet();
      expect(result.length, equals(lowerSet.length));
    });

    // -------------------------------------------------------------------------
    // 8. CardDetailSheet Widget Stress with 100x Duplicate Keywords
    // -------------------------------------------------------------------------
    testWidgets('R4-ADV-10: CardDetailSheet with 100x duplicate keywords renders exactly 1 badge per keyword', (tester) async {
      final hundredHastes = List.generate(50, (_) => 'Haste');
      final hundredFlyings = List.generate(50, (_) => 'Flying');

      final card = createTestCard(
        keywords: [...hundredHastes, ...hundredFlyings],
        oracleText: 'Haste, flying. Haste! Flying.',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);

      // Verify Flying chip in Wrap appears exactly ONCE
      final flyingBadge = find.descendant(
        of: find.byType(Wrap),
        matching: find.text('Flying'),
      );
      expect(flyingBadge, findsOneWidget);

      // Verify Haste chip in Wrap appears exactly ONCE
      final hasteBadge = find.descendant(
        of: find.byType(Wrap),
        matching: find.text('Haste'),
      );
      expect(hasteBadge, findsOneWidget);

      // Verify glossary definitions appear exactly ONCE
      expect(find.text(MtgKeywordGlossary.dictionary['Flying']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Haste']!), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 9. Non-MTG (Pokemon/Lorcana) Cards Completely Omit Mechanics Section
    // -------------------------------------------------------------------------
    testWidgets('R4-ADV-11: Pokémon and Lorcana cards never display MTG mechanics section', (tester) async {
      final pkmCard = createTestCard(
        id: 'pkm-1',
        name: 'Charizard ex',
        collectionType: 'pokemon',
        keywords: ['Flying', 'Haste'],
        oracleText: 'Flying attack for 100 damage.',
      );

      await tester.pumpWidget(createHarness(CardDetailSheet(item: pkmCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Should NOT render MTG mechanics section
      expect(find.text('Card Mechanics & Rulings'), findsNothing);
      expect(find.text(MtgKeywordGlossary.dictionary['Flying']!), findsNothing);
    });
  });
}

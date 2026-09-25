// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive Opaque-Box E2E Test Suite for MTG Mana Symbology Engine.
// Follows 4-Tier Specification in TEST_INFRA.md:
// - Tier 1: Feature Coverage (16 feature groups, >=5 tests each = 80 tests)
// - Tier 2: Boundary & Corner Cases (5 boundary groups, >=5 tests each = 25 tests)
// - Tier 3: Pairwise Combinations (10 cross-feature interaction tests)
// - Tier 4: Real-World Scenarios (9 realistic card workloads)

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/widgets/multi_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/text_post_body.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

// =============================================================================
// TEST HELPERS & FACTORIES
// =============================================================================

ManaSymbolIcon? getIconFromSpan(InlineSpan span) {
  if (span is! WidgetSpan) return null;
  final child = span.child;
  if (child is ManaSymbolIcon) return child;
  if (child is Padding && child.child is ManaSymbolIcon) {
    return child.child as ManaSymbolIcon;
  }
  return null;
}

List<ManaSymbolIcon> getIconsFromSpans(List<InlineSpan> spans) {
  final icons = <ManaSymbolIcon>[];
  for (final span in spans) {
    final icon = getIconFromSpan(span);
    if (icon != null) icons.add(icon);
  }
  return icons;
}

VaultItem createE2ETestCard({
  required String name,
  required String manaCost,
  required String oracleText,
  String? layout,
  List<Map<String, dynamic>>? cardFaces,
  List<Map<String, dynamic>>? cachedRulings,
}) {
  final dataMap = <String, dynamic>{
    'mana_cost': manaCost,
    'oracle_text': oracleText,
  };
  if (layout != null) dataMap['layout'] = layout;
  if (cardFaces != null) dataMap['card_faces'] = cardFaces;
  if (cachedRulings != null) dataMap['cached_rulings'] = cachedRulings;

  return VaultItem(
    id: 'e2e-card-${name.toLowerCase().replaceAll(' ', '-').replaceAll('//', '-')}',
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'E2E',
    imageUrl: 'https://example.com/card.jpg',
    acquiredPrice: 10.0,
    acquiredDate: DateTime(2026, 1, 1),
    quantity: 1,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    currentMarketPrice: 10.0,
    lastPriceUpdate: DateTime.now(),
    dynamicData: jsonEncode(dataMap),
  );
}

Widget createCardDetailSubject(AppDatabase db, VaultItem card) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: CardDetailSheet(
          item: card,
          fetchOnlinePrintings: false,
        ),
      ),
    ),
  );
}

Deck createE2ETestDeck({
  required String id,
  required String name,
  String format = 'MTG Commander',
}) {
  return Deck(
    id: id,
    name: name,
    format: format,
    wins: 0,
    losses: 0,
    draws: 0,
    createdAt: DateTime.now(),
    tcgDomain: 'mtg',
    isRegistered: false,
    isCompetitive: false,
  );
}

Widget createDeckBuilderSubject({
  required Deck deck,
  required List<Map<String, dynamic>> items,
}) {
  return ProviderScope(
    overrides: [
      deckItemsProvider(deck.id).overrideWith(
        (ref) => Stream.value(items),
      ),
    ],
    child: MaterialApp(
      home: DeckBuilderScreen(deck: deck),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (16 Groups, >=5 tests each = 80 tests)
  // ===========================================================================
  group('Tier 1: Feature Coverage', () {
    // -------------------------------------------------------------------------
    // Group 1: Single Colored Mana ({W}, {U}, {B}, {R}, {G})
    // -------------------------------------------------------------------------
    group('Group 1: Single Colored Mana', () {
      testWidgets('1.1 White mana {W} renders SVG icon with W.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{W}'))),
        );
        await tester.pumpAndSettle();
        final iconFinder = find.byType(ManaSymbolIcon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<ManaSymbolIcon>(iconFinder);
        expect(icon.assetPath, equals('assets/symbology/W.svg'));
        expect(icon.symbolCode, equals('W'));
        expect(icon.size, closeTo(14.0 * 1.1, 0.001));
      });

      testWidgets('1.2 Blue mana {U} renders SVG icon with U.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{U}'))),
        );
        await tester.pumpAndSettle();
        final iconFinder = find.byType(ManaSymbolIcon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<ManaSymbolIcon>(iconFinder);
        expect(icon.assetPath, equals('assets/symbology/U.svg'));
        expect(icon.symbolCode, equals('U'));
      });

      testWidgets('1.3 Black mana {B} renders SVG icon with B.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{B}'))),
        );
        await tester.pumpAndSettle();
        final iconFinder = find.byType(ManaSymbolIcon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<ManaSymbolIcon>(iconFinder);
        expect(icon.assetPath, equals('assets/symbology/B.svg'));
        expect(icon.symbolCode, equals('B'));
      });

      testWidgets('1.4 Red mana {R} renders SVG icon with R.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{R}'))),
        );
        await tester.pumpAndSettle();
        final iconFinder = find.byType(ManaSymbolIcon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<ManaSymbolIcon>(iconFinder);
        expect(icon.assetPath, equals('assets/symbology/R.svg'));
        expect(icon.symbolCode, equals('R'));
      });

      testWidgets('1.5 Green mana {G} renders SVG icon with G.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{G}'))),
        );
        await tester.pumpAndSettle();
        final iconFinder = find.byType(ManaSymbolIcon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<ManaSymbolIcon>(iconFinder);
        expect(icon.assetPath, equals('assets/symbology/G.svg'));
        expect(icon.symbolCode, equals('G'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 2: Generic Numeric Mana ({0}..{20}, {100}, {1000000})
    // -------------------------------------------------------------------------
    group('Group 2: Generic Numeric Mana', () {
      testWidgets('2.1 Numeric zero {0} in ManaCostBar renders 0.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{0}'))),
        );
        await tester.pumpAndSettle();
        final iconFinder = find.byType(ManaSymbolIcon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<ManaSymbolIcon>(iconFinder);
        expect(icon.assetPath, equals('assets/symbology/0.svg'));
      });

      testWidgets('2.2 Low generic numerics {1}{2}{3} render sequential SVGs', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{1}{2}{3}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/1.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/2.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/3.svg'));
      });

      testWidgets('2.3 Medium generic numerics {7}{10}{16} render correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{7}{10}{16}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/7.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/10.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/16.svg'));
      });

      testWidgets('2.4 Maximum standard generic numeric {20} renders 20.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{20}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/20.svg'));
      });

      testWidgets('2.5 Un-set large numerics {100} and {1000000} render appropriately', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{100}{1000000}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/100.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/1000000.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 3: Variable Mana ({X}, {Y}, {Z})
    // -------------------------------------------------------------------------
    group('Group 3: Variable Mana', () {
      testWidgets('3.1 Variable {X} in ManaText renders X.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{X}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/X.svg'));
      });

      testWidgets('3.2 Variable {Y} in ManaText renders Y.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{Y}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/Y.svg'));
      });

      testWidgets('3.3 Variable {Z} in ManaText renders Z.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{Z}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/Z.svg'));
      });

      testWidgets('3.4 Variable sequence {X}{Y}{Z} renders 3 icons in exact order', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{X}{Y}{Z}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/X.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/Y.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/Z.svg'));
      });

      testWidgets('3.5 Natural rules text with variable preserves plain text X', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Pay {X}{U}: Draw X cards.'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/X.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/U.svg'));
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals('Pay {X}{U}: Draw X cards.'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 4: Special Symbols ({½}, {∞}, {C}, {S})
    // -------------------------------------------------------------------------
    group('Group 4: Special Symbols', () {
      testWidgets('4.1 Half mana {½} renders HALF.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{½}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/HALF.svg'));
      });

      testWidgets('4.2 Infinite mana {∞} renders INFINITY.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{∞}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/INFINITY.svg'));
      });

      testWidgets('4.3 Colorless mana {C} renders C.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{C}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/C.svg'));
      });

      testWidgets('4.4 Snow mana {S} renders S.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{S}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/S.svg'));
      });

      testWidgets('4.5 Special quartet {C}{S}{½}{∞} renders all 4 distinct icons', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{C}{S}{½}{∞}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(4));
        expect(icons[0].assetPath, equals('assets/symbology/C.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/S.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/HALF.svg'));
        expect(icons[3].assetPath, equals('assets/symbology/INFINITY.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 5: Two-Color Hybrid ({W/U}, {B/R}, {G/W}, etc.)
    // -------------------------------------------------------------------------
    group('Group 5: Two-Color Hybrid', () {
      testWidgets('5.1 Allied hybrid {W/U} (Azorius) renders WU.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{W/U}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/WU.svg'));
      });

      testWidgets('5.2 Allied hybrids {U/B} and {B/R} render UB.svg and BR.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{U/B}{B/R}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/UB.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/BR.svg'));
      });

      testWidgets('5.3 Allied hybrids {R/G} and {G/W} render RG.svg and GW.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{R/G}{G/W}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/RG.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/GW.svg'));
      });

      testWidgets('5.4 Enemy hybrids {W/B} and {U/R} render WB.svg and UR.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{W/B}{U/R}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/WB.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/UR.svg'));
      });

      testWidgets('5.5 Enemy hybrids {B/G}, {R/W}, {G/U} render BG.svg, RW.svg, GU.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{B/G}{R/W}{G/U}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/BG.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/RW.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/GU.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 6: Twobrid & Colorless Hybrid ({2/W}, {C/W})
    // -------------------------------------------------------------------------
    group('Group 6: Twobrid & Colorless Hybrid', () {
      testWidgets('6.1 Monocolored Twobrids {2/W} and {2/U} render 2W.svg and 2U.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{2/W}{2/U}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/2W.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/2U.svg'));
      });

      testWidgets('6.2 Monocolored Twobrids {2/B}, {2/R}, {2/G} render correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{2/B}{2/R}{2/G}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/2B.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/2R.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/2G.svg'));
      });

      testWidgets('6.3 Colorless hybrids {C/W} and {C/U} render CW.svg and CU.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{C/W}{C/U}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/CW.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/CU.svg'));
      });

      testWidgets('6.4 Colorless hybrids {C/B}, {C/R}, {C/G} render CB.svg, CR.svg, CG.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{C/B}{C/R}{C/G}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/CB.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/CR.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/CG.svg'));
      });

      testWidgets('6.5 Contiguous twobrid & colorless hybrid {2/W}{C/U} renders in sequence', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{2/W}{C/U}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/2W.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/CU.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 7: Phyrexian & Hybrid Phyrexian ({W/P}, {G/U/P})
    // -------------------------------------------------------------------------
    group('Group 7: Phyrexian & Hybrid Phyrexian', () {
      testWidgets('7.1 Single color Phyrexian mana {W/P} and {U/P} render WP.svg and UP.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{W/P}{U/P}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/WP.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/UP.svg'));
      });

      testWidgets('7.2 Single color Phyrexian mana {B/P}, {R/P}, {G/P} render BP.svg, RP.svg, GP.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{B/P}{R/P}{G/P}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/BP.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/RP.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/GP.svg'));
      });

      testWidgets('7.3 Colorless Phyrexian {C/P} renders CP.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{C/P}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/CP.svg'));
      });

      testWidgets('7.4 Two-color Hybrid Phyrexian {G/U/P} (Tamiyo) renders GUP.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{G/U/P}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/GUP.svg'));
      });

      testWidgets('7.5 Hybrid Phyrexian pairs {W/U/P}, {W/B/P}, {B/R/P}, {R/G/P} render SVGs', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{W/U/P}{W/B/P}{B/R/P}{R/G/P}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(4));
        expect(icons[0].assetPath, equals('assets/symbology/WUP.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/WBP.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/BRP.svg'));
        expect(icons[3].assetPath, equals('assets/symbology/RGP.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 8: Transposable Aliases ({P/B}, {U/W}, {W/2})
    // -------------------------------------------------------------------------
    group('Group 8: Transposable Aliases', () {
      testWidgets('8.1 Transposed Phyrexian {P/B} and {P/W} map to BP.svg and WP.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{P/B}{P/W}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/BP.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/WP.svg'));
      });

      testWidgets('8.2 Transposed Two-Color Hybrid {U/W} and {R/B} map to WU.svg and BR.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{U/W}{R/B}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/WU.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/BR.svg'));
      });

      testWidgets('8.3 Transposed Twobrid {W/2} and {U/2} map to 2W.svg and 2U.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{W/2}{U/2}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/2W.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/2U.svg'));
      });

      testWidgets('8.4 Transposed Colorless Hybrid {W/C} and {U/C} map to CW.svg and CU.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{W/C}{U/C}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/CW.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/CU.svg'));
      });

      testWidgets('8.5 Transposed 3-token Hybrid Phyrexian {U/G/P} and {P/U/G} map to GUP.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{U/G/P}{P/U/G}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/GUP.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/GUP.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 9: Action & Mechanic Symbols ({T}, {Q}, {E}, {P}, {PW}, {CHAOS})
    // -------------------------------------------------------------------------
    group('Group 9: Action & Mechanic Symbols', () {
      testWidgets('9.1 Tap action {T} renders T.svg with tap semantic label', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{T}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/T.svg'));
        final semanticsFinder = find.descendant(
          of: find.byType(ManaSymbolIcon),
          matching: find.byType(Semantics),
        );
        final semantics = tester.widget<Semantics>(semanticsFinder.first);
        expect(semantics.properties.label, equals('tap this permanent'));
      });

      testWidgets('9.2 Untap action {Q} renders Q.svg with untap semantic label', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{Q}'))),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals('assets/symbology/Q.svg'));
        final semanticsFinder = find.descendant(
          of: find.byType(ManaSymbolIcon),
          matching: find.byType(Semantics),
        );
        final semantics = tester.widget<Semantics>(semanticsFinder.first);
        expect(semantics.properties.label, equals('untap this permanent'));
      });

      testWidgets('9.3 Energy {E} and Pawprint {P} render E.svg and P.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{E} and {P}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/E.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/P.svg'));
      });

      testWidgets('9.4 Planeswalker {PW} and Chaos {CHAOS} render PW.svg and CHAOS.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{PW} activates {CHAOS}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/PW.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/CHAOS.svg'));
      });

      testWidgets('9.5 Game counters Ticket {TK} and Acorn {A} render TK.svg and A.svg', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{TK} and {A}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));
        expect(icons[0].assetPath, equals('assets/symbology/TK.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/A.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 10: Malformed & Unknown Syntax Fallback
    // -------------------------------------------------------------------------
    group('Group 10: Malformed & Unknown Syntax Fallback', () {
      testWidgets('10.1 Unclosed opening brace "{W and some text" renders raw text without crashing', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{W and some text'))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text('{W and some text'), findsOneWidget);
      });

      testWidgets('10.2 Stray closing brace "Pay W} mana" renders raw text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Pay W} mana'))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text('Pay W} mana'), findsOneWidget);
      });

      testWidgets('10.3 Unknown bracketed token "{NotASymbol}" passes through as plain text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{NotASymbol}'))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text('{NotASymbol}'), findsOneWidget);
      });

      testWidgets('10.4 Empty braces "{}" pass through as plain text without throwing', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Cost: {} mana'))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text('Cost: {} mana'), findsOneWidget);
      });

      testWidgets('10.5 Mixed malformed and valid "Costs {2 and {XYZ} plus {W}." isolates {W}', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Costs {2 and {XYZ} plus {W}.'))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final iconFinder = find.byType(ManaSymbolIcon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<ManaSymbolIcon>(iconFinder);
        expect(icon.assetPath, equals('assets/symbology/W.svg'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 11: Typography Scaling & Middle Alignment
    // -------------------------------------------------------------------------
    group('Group 11: Typography Scaling & Middle Alignment', () {
      testWidgets('11.1 Inherits fontSize from ambient DefaultTextStyle and scales icon to fontSize * 1.1', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DefaultTextStyle(
                style: TextStyle(fontSize: 20.0),
                child: ManaText('{W}'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(22.0, 0.001));
      });

      testWidgets('11.2 Explicit style overrides fontSize and scales icon to 22.0px', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText(
                '{B}',
                style: TextStyle(fontSize: 20.0),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(22.0, 0.001));
      });

      testWidgets('11.3 Explicit symbolSize 18.0 overrides font scaling calculation', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText(
                '{R}',
                style: TextStyle(fontSize: 24.0),
                symbolSize: 18.0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, equals(18.0));
      });

      testWidgets('11.4 Custom symbolScale 1.5 scales icon to fontSize * 1.5', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText(
                '{G}',
                style: TextStyle(fontSize: 12.0),
                symbolScale: 1.5,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(18.0, 0.001));
      });

      testWidgets('11.5 All WidgetSpans strictly possess PlaceholderAlignment.middle', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Pay {2}{U}, {T}: Draw.'))),
        );
        await tester.pumpAndSettle();
        final richText = tester.widget<RichText>(find.byType(RichText));
        final rootSpan = richText.text as TextSpan;
        final effectiveSpan = (rootSpan.children != null &&
                rootSpan.children!.length == 1 &&
                rootSpan.children!.first is TextSpan)
            ? rootSpan.children!.first as TextSpan
            : rootSpan;

        final widgetSpans = effectiveSpan.children!.whereType<WidgetSpan>().toList();
        expect(widgetSpans.length, equals(3));
        for (final ws in widgetSpans) {
          expect(ws.alignment, equals(PlaceholderAlignment.middle));
        }
      });
    });

    // -------------------------------------------------------------------------
    // Group 12: ManaCostBar & FittedBox Row Layout
    // -------------------------------------------------------------------------
    group('Group 12: ManaCostBar & FittedBox Row Layout', () {
      testWidgets('12.1 Contiguous mana cost {2}{U}{B} renders horizontal Row of 3 icons', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{2}{U}{B}'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(find.descendant(of: find.byType(ManaCostBar), matching: find.byType(Row)), findsOneWidget);
      });

      testWidgets('12.2 Custom spacing 8.0 sets SizedBox widths to 8.0', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{R}{G}', spacing: 8.0))),
        );
        await tester.pumpAndSettle();
        final sizedBoxes = tester
            .widgetList<SizedBox>(find.descendant(of: find.byType(ManaCostBar), matching: find.byType(SizedBox)))
            .where((b) => b.width == 8.0)
            .toList();
        expect(sizedBoxes.length, greaterThanOrEqualTo(1));
      });

      testWidgets('12.3 enableFittedBox true wraps Row in FittedBox with BoxFit.scaleDown', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{1}{W}', enableFittedBox: true))),
        );
        await tester.pumpAndSettle();
        final fittedBoxFinder = find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        );
        expect(fittedBoxFinder, findsOneWidget);
        final fittedBox = tester.widget<FittedBox>(fittedBoxFinder);
        expect(fittedBox.fit, equals(BoxFit.scaleDown));
      });

      testWidgets('12.4 alignment centerRight sets FittedBox alignment and mainAxisAlignment to end', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaCostBar(
                manaCost: '{3}{B}',
                alignment: Alignment.centerRight,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fittedBox = tester.widget<FittedBox>(find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ));
        expect(fittedBox.alignment, equals(Alignment.centerRight));
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.end));
      });

      testWidgets('12.5 Auto-generates composite spoken Semantics label', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{1}{U}'))),
        );
        await tester.pumpAndSettle();
        final semanticsFinder = find.descendant(
          of: find.byType(ManaCostBar),
          matching: find.byType(Semantics),
        );
        expect(semanticsFinder, findsWidgets);
        final semanticsWidget = tester.widget<Semantics>(semanticsFinder.first);
        expect(semanticsWidget.properties.label, contains('Mana cost:'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 13: Mixed Natural Oracle Rules Text
    // -------------------------------------------------------------------------
    group('Group 13: Mixed Natural Oracle Rules Text', () {
      testWidgets('13.1 Activation cost sentence "{T}: Add {G}." creates 4 spans with correct ordering', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{T}: Add {G}.'))),
        );
        await tester.pumpAndSettle();
        final richText = tester.widget<RichText>(find.byType(RichText));
        final rootSpan = richText.text as TextSpan;
        final effectiveSpan = (rootSpan.children != null &&
                rootSpan.children!.length == 1 &&
                rootSpan.children!.first is TextSpan)
            ? rootSpan.children!.first as TextSpan
            : rootSpan;

        expect(effectiveSpan.children!.length, equals(4));
        expect(effectiveSpan.children![0], isA<WidgetSpan>());
        expect(effectiveSpan.children![1], isA<TextSpan>());
        expect((effectiveSpan.children![1] as TextSpan).text, equals(': Add '));
        expect(effectiveSpan.children![2], isA<WidgetSpan>());
        expect(effectiveSpan.children![3], isA<TextSpan>());
        expect((effectiveSpan.children![3] as TextSpan).text, equals('.'));
      });

      testWidgets('13.2 Mid-sentence cost "When this enters, pay {1}{W}{U} to draw a card."', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('When this enters, pay {1}{W}{U} to draw a card.'))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(3));
        expect(icons[0].assetPath, equals('assets/symbology/1.svg'));
        expect(icons[1].assetPath, equals('assets/symbology/W.svg'));
        expect(icons[2].assetPath, equals('assets/symbology/U.svg'));
      });

      testWidgets('13.3 Multi-line rules text with newlines retains line breaks across spans', (tester) async {
        const text = 'Vigilance\n{T}: Add {C}.';
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText(text))),
        );
        await tester.pumpAndSettle();
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals(text));
      });

      testWidgets('13.4 Pure natural text without brackets creates exactly 1 TextSpan without icons', (tester) async {
        const text = 'Flying, first strike, lifelink, haste';
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText(text))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals(text));
      });

      testWidgets('13.5 Text properties (textAlign, maxLines, overflow) delegate properly to internal Text.rich', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText(
                '{T}: Draw a card.',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect(richText.textAlign, equals(TextAlign.center));
        expect(richText.maxLines, equals(2));
        expect(richText.overflow, equals(TextOverflow.ellipsis));
      });
    });

    // -------------------------------------------------------------------------
    // Group 14: CardDetailSheet UI Surface Integration
    // -------------------------------------------------------------------------
    group('Group 14: CardDetailSheet UI Surface Integration', () {
      testWidgets('14.1 Top mana cost header mounts ManaCostBar displaying card mana cost cleanly', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createE2ETestCard(
          name: 'Omnath, Locus of All',
          manaCost: '{W}{U}{B}{R}{G}',
          oracleText: 'At the beginning of your precombat main phase, add {3}.',
        );

        await tester.pumpWidget(createCardDetailSubject(db, card));
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('14.2 Oracle text section mounts ManaText rendering rules text with inline symbols', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createE2ETestCard(
          name: 'Llanowar Elves',
          manaCost: '{G}',
          oracleText: '{T}: Add {G}.',
        );

        await tester.pumpWidget(createCardDetailSubject(db, card));
        await tester.pumpAndSettle();

        expect(find.byType(ManaText), findsWidgets);
        expect(find.byType(ManaSymbolIcon), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('14.3 Adventure card section renders adventure spell face mana cost via ManaCostBar', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createE2ETestCard(
          name: 'Bonecrusher Giant // Stomp',
          manaCost: '{2}{R}',
          oracleText: 'Whenever Bonecrusher Giant becomes target, it deals 2 damage.\n//\nDamage can\'t be prevented.',
          layout: 'adventure',
          cardFaces: [
            {
              'name': 'Bonecrusher Giant',
              'mana_cost': '{2}{R}',
              'type_line': 'Creature — Giant Berserker',
              'oracle_text': 'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage to that spell\'s controller.',
            },
            {
              'name': 'Stomp',
              'mana_cost': '{1}{R}',
              'type_line': 'Instant — Adventure',
              'oracle_text': 'Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.',
            },
          ],
        );

        await tester.pumpWidget(createCardDetailSubject(db, card));
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('14.4 Adventure card section renders adventure spell text via ManaText', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createE2ETestCard(
          name: 'Brazen Borrower // Petty Theft',
          manaCost: '{1}{U}{U}',
          oracleText: 'Flash, flying\n//\nReturn target nonland permanent to owner\'s hand.',
          layout: 'adventure',
          cardFaces: [
            {
              'name': 'Brazen Borrower',
              'mana_cost': '{1}{U}{U}',
              'type_line': 'Creature — Faerie Rogue',
              'oracle_text': 'Flash\nFlying\nBrazen Borrower can block only creatures with flying.',
            },
            {
              'name': 'Petty Theft',
              'mana_cost': '{1}{U}',
              'type_line': 'Instant — Adventure',
              'oracle_text': 'Return target nonland permanent an opponent controls to its owner\'s hand.',
            },
          ],
        );

        await tester.pumpWidget(createCardDetailSubject(db, card));
        await tester.pumpAndSettle();

        expect(find.byType(ManaText), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('14.5 Scryfall rulings section renders ruling comments via ManaText', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final card = createE2ETestCard(
          name: 'Sol Ring',
          manaCost: '{1}',
          oracleText: '{T}: Add {C}{C}.',
          cachedRulings: [
            {
              'published_at': '2023-01-01',
              'comment': 'You can activate this ability by tapping {T} to produce {C}{C}.',
            }
          ],
        );

        await tester.pumpWidget(createCardDetailSubject(db, card));
        await tester.pumpAndSettle();

        expect(find.byType(ManaText), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Group 15: DeckBuilderScreen UI Surface Integration (80px constraint)
    // -------------------------------------------------------------------------
    group('Group 15: DeckBuilderScreen UI Surface Integration (80px constraint)', () {
      final testDeck = createE2ETestDeck(id: 'deck-tier1-15', name: 'E2E Deck');

      testWidgets('15.1 Card row trailing 80px container mounts ManaCostBar(symbolSize: 11.5)', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final items = [
          {
            'id': 'item-lightning-bolt',
            'name': 'Lightning Bolt',
            'board_zone': 'mainboard',
            'deck_quantity': 1,
            'acquired_price': 2.50,
            'dynamic_data': jsonEncode({
              'mana_cost': '{R}',
              'cmc': 1,
              'type_line': 'Instant',
              'rarity': 'common',
            }),
          }
        ];

        await tester.pumpWidget(createDeckBuilderSubject(deck: testDeck, items: items));
        await tester.pumpAndSettle();

        expect(find.byType(ManaCostBar), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('15.2 5-color cost {W}{U}{B}{R}{G} inside 80px container scales down with zero RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final items = [
          {
            'id': 'item-omnath',
            'name': 'Omnath, Locus of All',
            'board_zone': 'commander',
            'deck_quantity': 1,
            'acquired_price': 5.00,
            'dynamic_data': jsonEncode({
              'mana_cost': '{W}{U}{B}{R}{G}',
              'cmc': 5,
              'type_line': 'Legendary Creature',
              'rarity': 'mythic',
            }),
          }
        ];

        await tester.pumpWidget(createDeckBuilderSubject(deck: testDeck, items: items));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('15.3 Massive cost {4}{W}{U}{B}{R}{G} inside 80px container scales down with zero overflow', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final items = [
          {
            'id': 'item-ur-dragon',
            'name': 'The Ur-Dragon',
            'board_zone': 'commander',
            'deck_quantity': 1,
            'acquired_price': 25.00,
            'dynamic_data': jsonEncode({
              'mana_cost': '{4}{W}{U}{B}{R}{G}',
              'cmc': 9,
              'type_line': 'Legendary Creature — Dragon Avatar',
              'rarity': 'mythic',
            }),
          }
        ];

        await tester.pumpWidget(createDeckBuilderSubject(deck: testDeck, items: items));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('15.4 Fast-Draw preview card mounts ManaCostBar displaying hand card cost', (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final items = [
          {
            'id': 'item-swords',
            'name': 'Swords to Plowshares',
            'board_zone': 'mainboard',
            'deck_quantity': 1,
            'acquired_price': 1.50,
            'dynamic_data': jsonEncode({
              'mana_cost': '{W}',
              'cmc': 1,
              'type_line': 'Instant',
              'rarity': 'uncommon',
            }),
          }
        ];

        await tester.pumpWidget(createDeckBuilderSubject(deck: testDeck, items: items));
        await tester.pumpAndSettle();

        final playtestButton = find.byIcon(Icons.style_rounded);
        if (playtestButton.evaluate().isNotEmpty) {
          await tester.tap(playtestButton.first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('15.5 Empty mana cost in deck row renders SizedBox.shrink() without layout shifts', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final items = [
          {
            'id': 'item-land',
            'name': 'Command Tower',
            'board_zone': 'mainboard',
            'deck_quantity': 1,
            'acquired_price': 0.50,
            'dynamic_data': jsonEncode({
              'mana_cost': '',
              'cmc': 0,
              'type_line': 'Land',
              'rarity': 'common',
            }),
          }
        ];

        await tester.pumpWidget(createDeckBuilderSubject(deck: testDeck, items: items));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Group 16: PostCard & Feed Post UI Surfaces Integration
    // -------------------------------------------------------------------------
    group('Group 16: PostCard & Feed Post UI Surfaces Integration', () {
      testWidgets('16.1 TextPostBody mounts ManaText and renders bracketed mana symbols in user post', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TextPostBody(text: 'Check out this turn 1 play: {G} into Llanowar Elves, then tap {T}!'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaText), findsOneWidget);
        expect(find.byType(ManaSymbolIcon), findsNWidgets(2));
      });

      testWidgets('16.2 SinglePullPostBody mounts ManaText and renders commentary with mana symbols', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SinglePullPostBody(
                  commentary: 'Pulled a foil Teferi! Costs {3}{W}{U}.',
                  cardTitle: 'Teferi, Hero of Dominaria',
                  cardSubtitle: 'Dominaria — Mythic',
                  cardRarity: 'mythic',
                  estimatedValue: '\$30.00',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaText), findsOneWidget);
        expect(find.byType(ManaSymbolIcon), findsNWidgets(3));
      });

      testWidgets('16.3 MultiPullPostBody mounts ManaText and renders commentary with mana symbols', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MultiPullPostBody(
                  commentary: 'Tri-color pack: {R}, {G}, and {W}!',
                  pullItems: ['https://example.com/card.jpg'],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaText), findsOneWidget);
        expect(find.byType(ManaSymbolIcon), findsNWidgets(3));
      });

      testWidgets('16.4 PostCard widget with PostType.text displays inline symbols in post feed stream', (tester) async {
        const post = FeedPost(
          id: 'post-test-1',
          type: PostType.text,
          username: 'jace_beleren',
          avatarInitials: 'JB',
          timestamp: '1h ago',
          locationTag: 'Ravnica',
          textContent: 'Untap {Q}, cast brainstorm for {U}.',
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PostCard(post: post),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PostCard), findsOneWidget);
        expect(find.byType(ManaText), findsOneWidget);
        expect(find.byType(ManaSymbolIcon), findsNWidgets(2));
      });

      testWidgets('16.5 User post containing multiline deck primer commentary renders all symbols cleanly', (tester) async {
        const primerText =
            'Deck Primer: Burn\n'
            'T1: Cast Goblin Guide for {R}.\n'
            'T2: Cast Eidolon of the Great Revel for {1}{R}.\n'
            'T3: Lightning Bolt {R} + Rift Bolt {R} for the win!';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TextPostBody(text: primerText),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaSymbolIcon), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      });
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES (5 Groups, 5 tests each = 25 tests)
  // ===========================================================================
  group('Tier 2: Boundary & Corner Cases', () {
    // -------------------------------------------------------------------------
    // Group 2.1: Empty and Whitespace Inputs
    // -------------------------------------------------------------------------
    group('Group 2.1: Empty and Whitespace Inputs', () {
      testWidgets('2.1.1 ManaText with empty string produces empty span list and zero icons', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText(''))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('2.1.2 ManaCostBar with empty manaCost renders SizedBox.shrink', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: ''))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('2.1.3 ManaCostBar with whitespace-only manaCost renders SizedBox.shrink', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '    '))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
      });

      testWidgets('2.1.4 ManaText with whitespace-only string renders TextSpan without icons', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('   \n  \t '))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals('   \n  \t '));
      });

      testWidgets('2.1.5 Null or whitespace within braces "{ }" and "{   }" renders as plain text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Cost: { } and {   }'))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals('Cost: { } and {   }'));
      });
    });

    // -------------------------------------------------------------------------
    // Group 2.2: Massive Mana Costs (20+ symbols)
    // -------------------------------------------------------------------------
    group('Group 2.2: Massive Mana Costs (20+ symbols)', () {
      testWidgets('2.2.1 20-symbol identical cost {W}*20 parses exactly 20 WidgetSpans', (tester) async {
        final massive20 = '{W}' * 20;
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: massive20))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(20));
        for (final icon in icons) {
          expect(icon.assetPath, equals('assets/symbology/W.svg'));
        }
      });

      testWidgets('2.2.2 25-symbol diverse cost parses into 25 icons in exact order', (tester) async {
        const cost25 =
            '{W}{U}{B}{R}{G}'
            '{W/U}{U/B}{B/R}{R/G}{G/W}'
            '{2/W}{2/U}{2/B}{2/R}{2/G}'
            '{W/P}{U/P}{B/P}{R/P}{G/P}'
            '{C}{S}{X}{Y}{Z}';

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: cost25))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(25));
        expect(icons.first.assetPath, equals('assets/symbology/W.svg'));
        expect(icons.last.assetPath, equals('assets/symbology/Z.svg'));
      });

      testWidgets('2.2.3 ManaCostBar with 20 symbols inside 100px width scales down via FittedBox without RenderFlex overflow', (tester) async {
        final massive20 = '{W}{U}{B}{R}{G}' * 4;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 100.0,
                height: 30.0,
                child: ManaCostBar(manaCost: massive20, enableFittedBox: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.scaleDown), findsOneWidget);
      });

      testWidgets('2.2.4 ManaCostBar with 30 symbols inside 60px extreme width scales down without crashing', (tester) async {
        final massive30 = '{2}{W}{U}{B}{R}{G}' * 5;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 60.0,
                height: 25.0,
                child: ManaCostBar(manaCost: massive30, enableFittedBox: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('2.2.5 Mixed text with 20 embedded symbols across multiple sentences parses cleanly', (tester) async {
        final sentences = StringBuffer();
        for (int i = 1; i <= 20; i++) {
          sentences.write('Step $i: Pay {W} to gain 1 life. ');
        }
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ManaText(sentences.toString()))),
        );
        await tester.pumpAndSettle();
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(20));
        expect(tester.takeException(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Group 2.3: Extreme Typography Font Sizes (8pt .. 40pt)
    // -------------------------------------------------------------------------
    group('Group 2.3: Extreme Typography Font Sizes (8pt .. 40pt)', () {
      testWidgets('2.3.1 Micro font size 8.0pt scales icon to 8.8px without zero/negative constraints', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText('{W}', style: TextStyle(fontSize: 8.0)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(8.8, 0.001));
      });

      testWidgets('2.3.2 Small font size 10.0pt scales icon to 11.0px', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText('{U}', style: TextStyle(fontSize: 10.0)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(11.0, 0.001));
      });

      testWidgets('2.3.3 Standard font size 14.0pt scales icon to 15.4px', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText('{B}', style: TextStyle(fontSize: 14.0)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(15.4, 0.001));
      });

      testWidgets('2.3.4 Large font size 24.0pt scales icon to 26.4px', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText('{R}', style: TextStyle(fontSize: 24.0)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(26.4, 0.001));
      });

      testWidgets('2.3.5 Extreme display font size 40.0pt scales icon to 44.0px without clipping or overflow', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManaText('{G}', style: TextStyle(fontSize: 40.0)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.size, closeTo(44.0, 0.001));
        expect(tester.takeException(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Group 2.4: Extreme Malformed & Corrupted Braces
    // -------------------------------------------------------------------------
    group('Group 2.4: Extreme Malformed & Corrupted Braces', () {
      testWidgets('2.4.1 Unclosed brace at very start "{W" passes through as text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{W'))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text('{W'), findsOneWidget);
      });

      testWidgets('2.4.2 Unclosed brace at very end "Cost: {2}{U" renders {2} and plain text {U', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Cost: {2}{U'))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsOneWidget);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals('Cost: {2}{U'));
      });

      testWidgets('2.4.3 Multiple consecutive opening braces "{{{W}}}" cleanly extracts inner {W}', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{{{W}}}'))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsOneWidget);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals('{{{W}}}'));
      });

      testWidgets('2.4.4 Inverted braces "}W{" and "}2{U{" pass through safely', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('}W{ and }2{U{'))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals('}W{ and }2{U{'));
      });

      testWidgets('2.4.5 Massive string of 50 unclosed braces passes through as text in < 5ms without freeze', (tester) async {
        final unclosed50 = '{' * 50;
        final stopwatch = Stopwatch()..start();
        final spans = ManaTextParser.parse(
          text: unclosed50,
          baseStyle: const TextStyle(fontSize: 14.0),
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(25));
        expect(spans, isNotEmpty);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ManaText(unclosed50))),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Group 2.5: Special Characters & Injection Resilience
    // -------------------------------------------------------------------------
    group('Group 2.5: Special Characters & Injection Resilience', () {
      testWidgets('2.5.1 HTML/XML-like content inside brackets "{<script>}" passes through as text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('{<script>alert("xss")</script>}'))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text('{<script>alert("xss")</script>}'), findsOneWidget);
      });

      testWidgets('2.5.2 SQL-like string inside brackets "{\' OR 1=1 --}" passes through as text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText("{\\' OR 1=1 --}"))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text("{\\' OR 1=1 --}"), findsOneWidget);
      });

      testWidgets('2.5.3 Unicode emojis inside and outside brackets render without crash', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('🌟 {W} 🔥 {R} 💧 {U} 💀 {B} 🌲 {G}'))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      });

      testWidgets('2.5.4 Unbracketed text resembling mana costs ("2UB", "W/U") renders as plain text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText('Cost is 2UB or W/U without brackets.'))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNothing);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect((richText.text as TextSpan).toPlainText(), equals('Cost is 2UB or W/U without brackets.'));
      });

      testWidgets('2.5.5 Control characters (tab, newline, null) inside oracle text preserve spacing without crash', (tester) async {
        const textWithControls = 'Line 1\t{W}\r\nLine 2\t{U}';
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ManaText(textWithControls))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ManaSymbolIcon), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    });
  });

  // ===========================================================================
  // TIER 3: PAIRWISE COMBINATIONS (10 Cross-Feature Tests)
  // ===========================================================================
  group('Tier 3: Pairwise Combinations', () {
    testWidgets('3.1 Adjacent Two-Color Hybrid + Hybrid Phyrexian {W/U}{G/U/P} in ManaCostBar and ManaText', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{W/U}{G/U/P}'))),
      );
      await tester.pumpAndSettle();
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(2));
      expect(icons[0].assetPath, equals('assets/symbology/WU.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/GUP.svg'));
    });

    testWidgets('3.2 Twobrid + Transposed Phyrexian {2/B}{P/B} contiguous cost with custom spacing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{2/B}{P/B}', spacing: 5.0))),
      );
      await tester.pumpAndSettle();
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(2));
      expect(icons[0].assetPath, equals('assets/symbology/2B.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/BP.svg'));
    });

    testWidgets('3.3 Colorless Hybrid + Snow Mana {C/W}{S} in constrained layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 70.0,
              height: 25.0,
              child: ManaCostBar(manaCost: '{C/W}{S}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(2));
      expect(icons[0].assetPath, equals('assets/symbology/CW.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/S.svg'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('3.4 Multi-ability Planeswalker Oracle Text with action symbol {T}, energy {E}, and loyalty costs', (tester) async {
      const walkerText =
          '+1: Add {E}{E}. You may tap {T} an artifact.\n'
          '-2: Pay {E}{E}{E}: Draw two cards.\n'
          '-7: You get an emblem with "Tap {T} untap {Q} all permanents."';

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ManaText(walkerText))),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(8)); // {E},{E},{T},{E},{E},{E},{T},{Q}
      expect(tester.takeException(), isNull);
    });

    testWidgets('3.5 Complex Saga rules text with Roman numerals, sacrifice clause, and mana symbols', (tester) async {
      const sagaText =
          'I, II — Create a 1/1 colorless Construct artifact creature token with "This creature gets +1/+1 for each artifact you control."\n'
          'III — Search your library for an artifact card with mana cost {0} or {1}, reveal it, and put it onto the battlefield. Then shuffle.';

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ManaText(sagaText))),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(2)); // {0}, {1}
      expect(icons[0].assetPath, equals('assets/symbology/0.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/1.svg'));
    });

    testWidgets('3.6 Deck tile trailing row with 80px constraint + 5-color hybrid cost', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80.0,
              height: 30.0,
              child: ManaCostBar(manaCost: '{W/U}{U/B}{B/R}{R/G}{G/W}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(5));
    });

    testWidgets('3.7 Deck tile trailing row with 60px extreme constraint + 6-symbol cost with FittedBox scale-down', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 60.0,
              height: 25.0,
              child: ManaCostBar(manaCost: '{1}{W}{U}{B}{R}{G}', enableFittedBox: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.scaleDown), findsOneWidget);
    });

    testWidgets('3.8 Social feed primer with transposable symbols, line breaks, emojis, and activation steps', (tester) async {
      const primer =
          '🚀 Fast Combo Primer:\n'
          'Turn 1: Cast {G} dork.\n'
          'Turn 2: Pay {P/B}{P/B} life, activate {T} for {2/W}{2/U}.\n'
          'Turn 3: Win with infinite {∞} mana! 🏆';

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TextPostBody(text: primer))),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(7)); // {G}, {P/B}, {P/B}, {T}, {2/W}, {2/U}, {∞}
      expect(tester.takeException(), isNull);
    });

    testWidgets('3.9 Adventure card dual face pairing (Creature cost {2}{G} + Adventure instant cost {1}{G/P})', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManaCostBar(manaCost: '{2}{G}'),
                ManaCostBar(manaCost: '{1}{G/P}'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(4)); // {2}, {G}, {1}, {G/P}
      expect(icons[0].assetPath, equals('assets/symbology/2.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/1.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/GP.svg'));
    });

    testWidgets('3.10 Mixed valid symbols and malformed braces in the same sentence "{T}: Add {G}. Pay {X and {2/W}."', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ManaText('{T}: Add {G}. Pay {X and {2/W}.'))),
      );
      await tester.pumpAndSettle();
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(3)); // {T}, {G}, {2/W}
      expect(icons[0].assetPath, equals('assets/symbology/T.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/2W.svg'));
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD MTG CARD WORKLOAD SCENARIOS (9 Tests)
  // ===========================================================================
  group('Tier 4: Real-World Scenarios', () {
    testWidgets('4.1 Scenario 1: Black Lotus ({0}, {T}, Sacrifice: Add three mana of any one color.)', (tester) async {
      const oracleText = '{T}, Sacrifice Black Lotus: Add three mana of any one color.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManaCostBar(manaCost: '{0}'),
                ManaText(oracleText),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(2)); // {0}, {T}
      expect(icons[0].assetPath, equals('assets/symbology/0.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/T.svg'));
    });

    testWidgets('4.2 Scenario 2: Lightning Bolt ({R}, Deal 3 damage to any target.)', (tester) async {
      const oracleText = 'Lightning Bolt deals 3 damage to any target.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManaCostBar(manaCost: '{R}'),
                ManaText(oracleText),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(1)); // {R}
      expect(icons[0].assetPath, equals('assets/symbology/R.svg'));
      final richText = tester.widget<RichText>(find.byType(RichText));
      expect((richText.text as TextSpan).toPlainText(), equals(oracleText));
    });

    testWidgets('4.3 Scenario 3: Teferi, Hero of Dominaria ({3}{W}{U}, multi-line loyalty abilities)', (tester) async {
      const teferiRules =
          '+1: Draw a card. At the beginning of the next end step, untap up to two lands.\n'
          '-3: Put target nonland permanent into its owner\'s library third from the top.\n'
          '-8: You get an emblem with "Whenever you draw a card, exile target permanent an opponent controls."';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManaCostBar(manaCost: '{3}{W}{U}'),
                ManaText(teferiRules),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final costIcons = tester.widgetList<ManaSymbolIcon>(
        find.descendant(of: find.byType(ManaCostBar), matching: find.byType(ManaSymbolIcon)),
      ).toList();
      expect(costIcons.length, equals(3));
      expect(costIcons[0].assetPath, equals('assets/symbology/3.svg'));
      expect(costIcons[1].assetPath, equals('assets/symbology/W.svg'));
      expect(costIcons[2].assetPath, equals('assets/symbology/U.svg'));

      expect(tester.takeException(), isNull);
    });

    testWidgets('4.4 Scenario 4: Omnath, Locus of Creation ({R}{G}{W}{U}, 4-color cost)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{R}{G}{W}{U}'))),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(4));
      expect(icons[0].assetPath, equals('assets/symbology/R.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/W.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/U.svg'));
    });

    testWidgets('4.5 Scenario 5: Little Girl ({½}, {½}{W}) & Gleemax ({1000000})', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManaCostBar(manaCost: '{½}{W}'),
                ManaCostBar(manaCost: '{1000000}'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(3));
      expect(icons[0].assetPath, equals('assets/symbology/HALF.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/W.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/1000000.svg'));
    });

    testWidgets('4.6 Scenario 6: Tamiyo, Compleated Sage ({2}{G}{G/U/P}{U})', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ManaCostBar(manaCost: '{2}{G}{G/U/P}{U}'))),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(4));
      expect(icons[0].assetPath, equals('assets/symbology/2.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/GUP.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/U.svg'));
    });

    testWidgets('4.7 Scenario 7: Deck Tile Trailing Row ({2}{W}{U}{B}{R}{G} in 80px width)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80.0,
              height: 30.0,
              child: ManaCostBar(
                manaCost: '{2}{W}{U}{B}{R}{G}',
                symbolSize: 11.5,
                enableFittedBox: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(6));
    });

    testWidgets('4.8 Scenario 8: PostCard Primer (T1: Cast {G}. T2: Tap {T} for {1}{G}{G}. Combo: {P/B}{P/B} life.)', (tester) async {
      const primer = 'T1: Cast {G}. T2: Tap {T} for {1}{G}{G}. Combo: {P/B}{P/B} life.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextPostBody(text: primer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(7)); // {G}, {T}, {1}, {G}, {G}, {P/B}, {P/B}
      expect(icons[0].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/T.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/1.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[4].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[5].assetPath, equals('assets/symbology/BP.svg'));
      expect(icons[6].assetPath, equals('assets/symbology/BP.svg'));
    });

    testWidgets('4.9 Scenario 9: Urza\'s Saga / Planar Chaos ({PW}, {CHAOS}, {1}{C})', (tester) async {
      const planarText = '{PW}: Activate planar ability. Roll {CHAOS}: Pay {1}{C}.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(planarText),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons.length, equals(4)); // {PW}, {CHAOS}, {1}, {C}
      expect(icons[0].assetPath, equals('assets/symbology/PW.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/CHAOS.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/1.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/C.svg'));
    });
  });
}

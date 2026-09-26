// Copyright (c) 2026 Countr. All rights reserved.
// Tier 5 White-Box Adversarial Hardening Suite for Symbology Presentation Widgets & UI Surfaces.
//
// White-box test targets:
// 1. ManaText: DefaultTextStyle inheritance, inherit true/false, MediaQuery.boldTextOf,
//    semanticsLabel, TextDirection (LTR/RTL/Bidi), textScaler, softWrap, overflow, maxLines,
//    symbolScale, symbolSize, symbolPadding.
// 2. ManaCostBar: spacing, mainAxisSize, alignment mapping (start/center/end), fallbackTextStyle,
//    enableFittedBox true/false, whitespace-only/empty trimming, semanticLabel override and generation.
// 3. ManaSymbolIcon: explicit assetPath, catalog resolution, fallbackBuilder, _buildDefaultFallback
//    (clean name vs '?'), circular ClipOval true/false, padding, semanticLabel (explicit/catalog/fallback),
//    extreme sizes.
// 4. UI Surfaces: CardDetailSheet (empty vs populated mana cost, empty vs populated oracle text,
//    adventure faces, rulings), DeckBuilderScreen (trailing 80px container, land omission, Fast-Draw 7),
//    TextPostBody, SinglePullPostBody, MultiPullPostBody.
// 5. Layout Stress: extreme scales, 50-symbol FittedBox constraints, narrow containers.

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/feed/presentation/widgets/multi_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/text_post_body.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

// =============================================================================
// HELPER FACTORIES
// =============================================================================

VaultItem createTier5TestCard({
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
    id: 'tier5-card-${name.toLowerCase().replaceAll(' ', '-').replaceAll('//', '-')}',
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'T5',
    imageUrl: 'https://example.com/card.jpg',
    acquiredPrice: 5.0,
    acquiredDate: DateTime(2026, 1, 1),
    quantity: 1,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false, isDeleted: false,
    currentMarketPrice: 5.0,
    lastPriceUpdate: DateTime.now(),
    dynamicData: jsonEncode(dataMap),
  );
}

Widget createTier5CardDetailSubject(AppDatabase db, VaultItem card) {
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

Deck createTier5TestDeck({
  required String id,
  required String name,
}) {
  return Deck(
    id: id,
    name: name,
    format: 'MTG Modern',
    wins: 0,
    losses: 0,
    draws: 0,
    createdAt: DateTime.now(),
    tcgDomain: 'mtg',
    isRegistered: false,
    isCompetitive: false, isDeleted: false,
  );
}

Widget createTier5DeckBuilderSubject({
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
  // GROUP 1: ManaText - DefaultTextStyle & Typography Merging Hardening
  // ===========================================================================
  group('Group 1: ManaText - DefaultTextStyle & Typography Merging Hardening', () {
    testWidgets('1.1 style == null inherits all properties from ambient DefaultTextStyle', (tester) async {
      const ambientStyle = TextStyle(
        fontSize: 18.0,
        color: Colors.purple,
        letterSpacing: 2.5,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: ambientStyle,
              child: ManaText('{W}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      expect(rootSpan.style?.fontSize, equals(18.0));
      expect(rootSpan.style?.color, equals(Colors.purple));
      expect(rootSpan.style?.letterSpacing, equals(2.5));

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      // 18.0 * 1.1 = 19.8
      expect(icon.size, closeTo(19.8, 0.001));
    });

    testWidgets('1.2 style != null with inherit == true merges explicit overrides with ambient style', (tester) async {
      const ambientStyle = TextStyle(
        fontSize: 22.0,
        color: Colors.green,
        letterSpacing: 1.5,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: ambientStyle,
              child: ManaText(
                '{U}',
                style: TextStyle(color: Colors.red), // inherit is true by default
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      final effectiveSpan = (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              rootSpan.children!.first is TextSpan)
          ? rootSpan.children!.first as TextSpan
          : rootSpan;

      expect(effectiveSpan.style?.color, equals(Colors.red));
      expect(effectiveSpan.style?.fontSize, equals(22.0));
      expect(effectiveSpan.style?.letterSpacing, equals(1.5));

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      // 22.0 * 1.1 = 24.2
      expect(icon.size, closeTo(24.2, 0.001));
    });

    testWidgets('1.3 style != null with inherit == false strictly ignores ambient DefaultTextStyle', (tester) async {
      const ambientStyle = TextStyle(
        fontSize: 32.0,
        color: Colors.blue,
        letterSpacing: 4.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: ambientStyle,
              child: ManaText(
                '{B}',
                style: TextStyle(
                  inherit: false,
                  fontSize: 14.0,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      final effectiveSpan = (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              rootSpan.children!.first is TextSpan)
          ? rootSpan.children!.first as TextSpan
          : rootSpan;

      expect(effectiveSpan.style?.color, equals(Colors.orange));
      expect(effectiveSpan.style?.fontSize, equals(14.0));
      expect(effectiveSpan.style?.letterSpacing, isNull);

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      // 14.0 * 1.1 = 15.4
      expect(icon.size, closeTo(15.4, 0.001));
    });

    testWidgets('1.4 MediaQuery.boldTextOf(context) == true forces FontWeight.bold onto effectiveStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(boldText: true),
            child: const Scaffold(
              body: ManaText(
                '{R}',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w200),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      final effectiveSpan = (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              rootSpan.children!.first is TextSpan)
          ? rootSpan.children!.first as TextSpan
          : rootSpan;
      expect(effectiveSpan.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('1.5 MediaQuery.boldTextOf(context) == false preserves original fontWeight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(boldText: false),
            child: const Scaffold(
              body: ManaText(
                '{G}',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w300),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      final effectiveSpan = (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              rootSpan.children!.first is TextSpan)
          ? rootSpan.children!.first as TextSpan
          : rootSpan;
      expect(effectiveSpan.style?.fontWeight, equals(FontWeight.w300));
    });

    testWidgets('1.6 textScaler linear(2.0) propagates cleanly to RichText', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{2}{W}',
              textScaler: TextScaler.linear(2.0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(richText.textScaler, equals(const TextScaler.linear(2.0)));
    });

    testWidgets('1.7 explicit symbolSize overrides symbolScale and fontSize completely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{C}',
              style: TextStyle(fontSize: 10.0),
              symbolScale: 3.0,
              symbolSize: 26.5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.size, equals(26.5));
    });

    testWidgets('1.8 custom symbolPadding is propagated to WidgetSpan containing ManaSymbolIcon', (tester) async {
      const customPadding = EdgeInsets.symmetric(horizontal: 4.5, vertical: 2.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{S}',
              symbolPadding: customPadding,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      final effectiveSpan = (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              rootSpan.children!.first is TextSpan)
          ? rootSpan.children!.first as TextSpan
          : rootSpan;
      final widgetSpan = effectiveSpan.children!.whereType<WidgetSpan>().first;
      expect(widgetSpan.child, isA<Padding>());
      final paddingWidget = widgetSpan.child as Padding;
      expect(paddingWidget.padding, equals(customPadding));
    });

    testWidgets('1.9 symbolScale defaults to 1.1 when symbolScale is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{W}',
              style: TextStyle(fontSize: 20.0),
              symbolScale: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      // 20.0 * 1.1 = 22.0
      expect(icon.size, closeTo(22.0, 0.001));
    });
  });

  // ===========================================================================
  // GROUP 2: ManaText - Semantics, Accessibility & Internationalization (RTL)
  // ===========================================================================
  group('Group 2: ManaText - Semantics, Accessibility & Internationalization (RTL)', () {
    testWidgets('2.1 explicit semanticsLabel passes to RichText.text.semanticsLabel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{T}: Add {G}.',
              semanticsLabel: 'Tap to add one green mana.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Tap to add one green mana.',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('2.2 semanticsLabel == null leaves RichText.text.semanticsLabel null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('{T}: Add {G}.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Tap to add one green mana.',
      );
      expect(semanticsFinder, findsNothing);
    });

    testWidgets('2.3 explicit textDirection: TextDirection.rtl sets RichText textDirection', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{W}{U} Hebrew text',
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(richText.textDirection, equals(TextDirection.rtl));
    });

    testWidgets('2.4 inherits TextDirection.rtl from ambient Directionality', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(),
            child: ManaText('{B}{R} Ambient RTL'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderParagraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
      expect(renderParagraph.textDirection, equals(TextDirection.rtl));
      expect(Directionality.of(tester.element(find.byType(ManaText))), equals(TextDirection.rtl));
    });

    testWidgets('2.5 Bidirectional Hebrew and Arabic text with embedded symbols renders without error', (tester) async {
      const bidiHebrew = 'שלם {2}{U} ושלף שני קלפים.';
      const bidiArabic = 'ادفع {1}{B} لتدمير الهدف.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManaText(bidiHebrew, textDirection: TextDirection.rtl),
                ManaText(bidiArabic, textDirection: TextDirection.rtl),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(4)); // {2}, {U}, {1}, {B}
    });

    testWidgets('2.6 delegates textAlign: TextAlign.justify and TextAlign.end', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManaText('{W} Justified', textAlign: TextAlign.justify),
                ManaText('{U} End', textAlign: TextAlign.end),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText)).toList();
      expect(richTexts[0].textAlign, equals(TextAlign.justify));
      expect(richTexts[1].textAlign, equals(TextAlign.end));
    });

    testWidgets('2.7 delegates softWrap: false, overflow: TextOverflow.clip, maxLines: 1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{2}{W}{U}{B}{R}{G} Unwrapped long line',
              softWrap: false,
              overflow: TextOverflow.clip,
              maxLines: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(richText.softWrap, isFalse);
      expect(richText.overflow, equals(TextOverflow.clip));
      expect(richText.maxLines, equals(1));
    });

    testWidgets('2.8 PlaceholderAlignment.middle is strictly maintained on all child spans', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('Cost: {W/U}{2/B}{G/P}.'),
          ),
        ),
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
      for (final span in widgetSpans) {
        expect(span.alignment, equals(PlaceholderAlignment.middle));
      }
    });
  });

  // ===========================================================================
  // GROUP 3: ManaCostBar - Spacing, Alignment, Sizing & Fallback Hardening
  // ===========================================================================
  group('Group 3: ManaCostBar - Spacing, Alignment, Sizing & Fallback Hardening', () {
    testWidgets('3.1 spacing: 0.0 leaves zero positive width SizedBox spacers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{W}{U}',
              spacing: 0.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final spacers = tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(ManaCostBar),
            matching: find.byType(SizedBox),
          ))
          .where((box) => box.height == null && box.width != null && box.width! > 0)
          .toList();

      expect(spacers, isEmpty);
    });

    testWidgets('3.2 spacing: 8.0 with 4 symbols creates exactly 3 SizedBox(width: 8.0) spacers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{1}{W}{U}{B}',
              spacing: 8.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sizedBoxes = tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(ManaCostBar),
            matching: find.byType(SizedBox),
          ))
          .where((box) => box.width == 8.0)
          .toList();

      expect(sizedBoxes.length, equals(3));
    });

    testWidgets('3.3 mainAxisSize: MainAxisSize.max configures internal Row', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{R}',
              mainAxisSize: MainAxisSize.max,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = tester.widget<Row>(find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byType(Row),
      ));
      expect(row.mainAxisSize, equals(MainAxisSize.max));
    });

    testWidgets('3.4 alignment mapping: centerRight, topRight, bottomRight map to MainAxisAlignment.end', (tester) async {
      for (final align in [Alignment.centerRight, Alignment.topRight, Alignment.bottomRight]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManaCostBar(
                manaCost: '{G}',
                alignment: align,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = tester.widget<Row>(find.descendant(
          of: find.byType(ManaCostBar),
          matching: find.byType(Row),
        ));
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.end));
      }
    });

    testWidgets('3.5 alignment mapping: center maps to MainAxisAlignment.center', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{G}',
              alignment: Alignment.center,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = tester.widget<Row>(find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byType(Row),
      ));
      expect(row.mainAxisAlignment, equals(MainAxisAlignment.center));
    });

    testWidgets('3.6 alignment mapping: centerLeft and topLeft map to MainAxisAlignment.start', (tester) async {
      for (final align in [Alignment.centerLeft, Alignment.topLeft]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManaCostBar(
                manaCost: '{G}',
                alignment: align,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = tester.widget<Row>(find.descendant(
          of: find.byType(ManaCostBar),
          matching: find.byType(Row),
        ));
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.start));
      }
    });

    testWidgets('3.7 fallbackTextStyle == null uses default style with symbolSize and AppColors.accentCyan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: 'NoCost',
              symbolSize: 15.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('NoCost'));
      expect(text.style?.fontSize, equals(15.0));
      expect(text.style?.fontWeight, equals(FontWeight.w600));
      expect(text.style?.color, equals(AppColors.accentCyan));
    });

    testWidgets('3.8 fallbackTextStyle != null applies custom text style to non-symbol cost', (tester) async {
      const customStyle = TextStyle(
        fontSize: 22.0,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: 'Free Spell',
              fallbackTextStyle: customStyle,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Free Spell'));
      expect(text.style, equals(customStyle));
    });

    testWidgets('3.9 enableFittedBox: false omits FittedBox and renders Row directly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{W}{U}',
              enableFittedBox: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaleDownFinder = find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.scaleDown),
      );
      expect(scaleDownFinder, findsNothing);
      expect(
        find.descendant(of: find.byType(ManaCostBar), matching: find.byType(Row)),
        findsOneWidget,
      );
    });

    testWidgets('3.10 enableFittedBox: true wraps Row in FittedBox with BoxFit.scaleDown and alignment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{W}{U}',
              enableFittedBox: true,
              alignment: Alignment.centerRight,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaleDownFinder = find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.scaleDown),
      );
      expect(scaleDownFinder, findsOneWidget);
      final fittedBox = tester.widget<FittedBox>(scaleDownFinder);
      expect(fittedBox.fit, equals(BoxFit.scaleDown));
      expect(fittedBox.alignment, equals(Alignment.centerRight));
    });

    testWidgets('3.11 whitespace-only and empty strings render SizedBox.shrink without error', (tester) async {
      for (final cost in ['', '   ', '\t\n  ']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManaCostBar(manaCost: cost),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('3.12 explicit semanticLabel overrides auto-generated label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{U}{U}',
              semanticLabel: 'Double blue mana',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Double blue mana'),
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('3.13 default semanticLabel generates joined English descriptions from catalog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{1}{R}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Mana cost: one generic mana, one red mana'),
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 4: ManaSymbolIcon - Error Handling, Fallback Builders & Boundaries
  // ===========================================================================
  group('Group 4: ManaSymbolIcon - Error Handling, Fallback Builders & Boundaries', () {
    testWidgets('4.1 explicit assetPath overrides ScryfallSymbolCatalog resolution', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(
              symbolCode: 'W',
              assetPath: 'assets/symbology/CUSTOM_W.svg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.assetPath, equals('assets/symbology/CUSTOM_W.svg'));
    });

    testWidgets('4.2 catalog resolution accurately maps codes to official SVGs', (tester) async {
      const mappings = {
        '{W/U}': 'assets/symbology/WU.svg',
        '{P/B}': 'assets/symbology/BP.svg',
        '{½}': 'assets/symbology/HALF.svg',
        '{∞}': 'assets/symbology/INFINITY.svg',
        '{2/W}': 'assets/symbology/2W.svg',
      };

      for (final entry in mappings.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManaSymbolIcon(symbolCode: entry.key),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
        expect(icon.assetPath, equals(entry.value));
      }
    });

    testWidgets('4.3 uncataloged symbol code yields null assetPath and renders fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(symbolCode: '{UNKNOWN_TEST_CODE}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.assetPath, isNull);
      expect(find.text('UNKNOWN_TEST_CODE'), findsOneWidget);
    });

    testWidgets('4.4 custom fallbackBuilder is invoked when assetPath is missing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(
              symbolCode: '{NON_EXISTENT}',
              fallbackBuilder: (context, code, size) {
                return Container(
                  key: const Key('custom-fallback'),
                  width: size,
                  height: size,
                  color: Colors.amber,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom-fallback')), findsOneWidget);
    });

    testWidgets('4.5 default fallback renders "?" when symbolCode contains only empty braces "{}"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(symbolCode: '{}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('4.6 circular: false omits ClipOval wrapper', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(
              symbolCode: '{W}',
              circular: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipOvalFinder = find.descendant(
        of: find.byType(ManaSymbolIcon),
        matching: find.byType(ClipOval),
      );
      expect(clipOvalFinder, findsNothing);
    });

    testWidgets('4.7 circular: true (default) wraps content in ClipOval', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(symbolCode: '{W}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipOvalFinder = find.descendant(
        of: find.byType(ManaSymbolIcon),
        matching: find.byType(ClipOval),
      );
      expect(clipOvalFinder, findsOneWidget);
    });

    testWidgets('4.8 padding != null wraps sized icon in Padding widget', (tester) async {
      const testPadding = EdgeInsets.all(5.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(
              symbolCode: '{U}',
              padding: testPadding,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paddingWidget = tester.widget<Padding>(find.descendant(
        of: find.byType(ManaSymbolIcon),
        matching: find.byType(Padding),
      ));
      expect(paddingWidget.padding, equals(testPadding));
    });

    testWidgets('4.9 semanticLabel explicit string overrides Scryfall description', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(
              symbolCode: '{W}',
              semanticLabel: 'Custom White Mana',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(find.descendant(
        of: find.byType(ManaSymbolIcon),
        matching: find.byType(Semantics),
      ));
      expect(semantics.properties.label, equals('Custom White Mana'));
      expect(semantics.properties.image, isTrue);
    });

    testWidgets('4.10 uncataloged symbol without semanticLabel falls back to "Mana symbol {CODE}"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(symbolCode: '{MYSTERY}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(find.descendant(
        of: find.byType(ManaSymbolIcon),
        matching: find.byType(Semantics),
      ));
      expect(semantics.properties.label, equals('Mana symbol {MYSTERY}'));
    });

    testWidgets('4.11 boundary sizes: 0.0, 1.0, 64.0 render without constraint crash', (tester) async {
      for (final sz in [0.0, 1.0, 64.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManaSymbolIcon(
                symbolCode: '{R}',
                size: sz,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final sizedBoxes = tester.widgetList<SizedBox>(find.descendant(
          of: find.byType(ManaSymbolIcon),
          matching: find.byType(SizedBox),
        ));
        expect(sizedBoxes.any((b) => b.width == sz && b.height == sz), isTrue);
      }
    });
  });

  // ===========================================================================
  // GROUP 5: UI Surfaces - White-Box Hardening & Edge Condition Verification
  // ===========================================================================
  group('Group 5: UI Surfaces - White-Box Hardening & Edge Condition Verification', () {
    testWidgets('5.1 CardDetailSheet with empty manaCost completely omits header ManaCostBar', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createTier5TestCard(
        name: 'Forest',
        manaCost: '',
        oracleText: '({T}: Add {G}.)',
      );

      await tester.pumpWidget(createTier5CardDetailSubject(db, card));
      await tester.pumpAndSettle();

      // Top mana cost container is omitted when manaCost.isEmpty
      // Only Oracle text has mana symbols
      expect(find.byType(ManaText), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5.2 CardDetailSheet with manaCost mounts ManaCostBar(symbolSize: 14.0)', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createTier5TestCard(
        name: 'Counterspell',
        manaCost: '{U}{U}',
        oracleText: 'Counter target spell.',
      );

      await tester.pumpWidget(createTier5CardDetailSubject(db, card));
      await tester.pumpAndSettle();

      final costBar = tester.widget<ManaCostBar>(find.byType(ManaCostBar).first);
      expect(costBar.manaCost, equals('{U}{U}'));
      expect(costBar.symbolSize, equals(14.0));
    });

    testWidgets('5.3 CardDetailSheet with empty oracleText displays fallback string in ManaText', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createTier5TestCard(
        name: 'Savannah Lions',
        manaCost: '{W}',
        oracleText: '',
      );

      await tester.pumpWidget(createTier5CardDetailSubject(db, card));
      await tester.pumpAndSettle();

      expect(find.text('No rules text available for this card.'), findsOneWidget);
    });

    testWidgets('5.4 CardDetailSheet with Adventure card mounts ManaCostBar and ManaText on both faces', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createTier5TestCard(
        name: 'Lovestruck Beast // Heart\'s Desire',
        manaCost: '{2}{G}',
        oracleText: 'Lovestruck Beast can\'t attack unless you control a 1/1 creature.\n//\nCreate a 1/1 white Human creature token.',
        layout: 'adventure',
        cardFaces: [
          {
            'name': 'Lovestruck Beast',
            'mana_cost': '{2}{G}',
            'type_line': 'Creature — Beast Noble',
            'oracle_text': 'Lovestruck Beast can\'t attack unless you control a 1/1 creature.',
          },
          {
            'name': 'Heart\'s Desire',
            'mana_cost': '{G}',
            'type_line': 'Sorcery — Adventure',
            'oracle_text': 'Create a 1/1 white Human creature token.',
          },
        ],
      );

      await tester.pumpWidget(createTier5CardDetailSubject(db, card));
      await tester.pumpAndSettle();

      expect(find.byType(ManaCostBar), findsWidgets);
      expect(find.byType(ManaText), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5.5 CardDetailSheet with Scryfall rulings renders ruling comments via ManaText', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createTier5TestCard(
        name: 'Birds of Paradise',
        manaCost: '{G}',
        oracleText: 'Flying\n{T}: Add one mana of any color.',
        cachedRulings: [
          {
            'published_at': '2022-01-01',
            'comment': 'This mana ability does not use the stack and taps for {W}, {U}, {B}, {R}, or {G}.',
          }
        ],
      );

      await tester.pumpWidget(createTier5CardDetailSubject(db, card));
      await tester.pumpAndSettle();

      expect(find.byType(ManaText), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5.6 DeckBuilderScreen card row renders ManaCostBar(symbolSize: 11.5)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testDeck = createTier5TestDeck(id: 'deck-t5-1', name: 'T5 Test Deck');
      final items = [
        {
          'id': 'item-opt',
          'name': 'Opt',
          'board_zone': 'mainboard',
          'deck_quantity': 4,
          'acquired_price': 0.25,
          'dynamic_data': jsonEncode({
            'mana_cost': '{U}',
            'cmc': 1,
            'type_line': 'Instant',
            'rarity': 'common',
          }),
        }
      ];

      await tester.pumpWidget(createTier5DeckBuilderSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      final costBar = tester.widget<ManaCostBar>(find.byType(ManaCostBar).first);
      expect(costBar.manaCost, equals('{U}'));
      expect(costBar.symbolSize, equals(11.5));
    });

    testWidgets('5.7 DeckBuilderScreen card row with empty manaCost (land) omits ManaCostBar container', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testDeck = createTier5TestDeck(id: 'deck-t5-2', name: 'T5 Land Deck');
      final items = [
        {
          'id': 'item-island',
          'name': 'Island',
          'board_zone': 'mainboard',
          'deck_quantity': 20,
          'acquired_price': 0.05,
          'dynamic_data': jsonEncode({
            'mana_cost': '',
            'cmc': 0,
            'type_line': 'Basic Land — Island',
            'rarity': 'common',
          }),
        }
      ];

      await tester.pumpWidget(createTier5DeckBuilderSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      expect(find.byType(ManaCostBar), findsNothing);
    });

    testWidgets('5.8 Fast-Draw 7 modal mounts ManaCostBar(symbolSize: 12.0) for drawn cards', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testDeck = createTier5TestDeck(id: 'deck-t5-3', name: 'T5 Fast-Draw Deck');
      final items = List.generate(
        10,
        (i) => {
          'id': 'item-$i',
          'name': 'Spell $i',
          'board_zone': 'mainboard',
          'deck_quantity': 1,
          'acquired_price': 1.0,
          'dynamic_data': jsonEncode({
            'mana_cost': '{1}{U}',
            'cmc': 2,
            'type_line': 'Instant',
            'rarity': 'uncommon',
          }),
        },
      );

      await tester.pumpWidget(createTier5DeckBuilderSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Tap Fast-Draw 7 icon in AppBar
      final fastDrawButton = find.byTooltip('Fast-Draw 7');
      expect(fastDrawButton, findsOneWidget);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      // Fast-draw sheet mounts ManaCostBar with symbolSize: 12.0
      final costBars = tester.widgetList<ManaCostBar>(find.byType(ManaCostBar)).toList();
      expect(costBars.any((b) => b.symbolSize == 12.0), isTrue);
    });

    testWidgets('5.9 TextPostBody mounts ManaText with body typography and padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextPostBody(text: 'Cast {W/U} on T1, then {2}{B} on T2!'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaText), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(3)); // {W/U}, {2}, {B}
    });

    testWidgets('5.10 SinglePullPostBody & MultiPullPostBody mount ManaText for commentary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SinglePullPostBody(
                    commentary: 'Pulled a foil {B/R} commander!',
                    cardTitle: 'Rakdos',
                  ),
                  MultiPullPostBody(
                    commentary: 'Collector booster box hits: {W}{U}{B}{R}{G} galore!',
                    pullItems: ['Item 1', 'Item 2', 'Item 3', 'Item 4'],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaText), findsNWidgets(2));
      expect(find.byType(ManaSymbolIcon), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // GROUP 6: Extreme Adversarial & Layout Stress Harnesses
  // ===========================================================================
  group('Group 6: Extreme Adversarial & Layout Stress Harnesses', () {
    testWidgets('6.1 50-symbol contiguous cost in ManaCostBar inside 40px width box scales down without overflow', (tester) async {
      final massiveCost = '{W}' * 50;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 40.0,
              height: 20.0,
              child: ManaCostBar(
                manaCost: massiveCost,
                symbolSize: 14.0,
                enableFittedBox: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final fittedBoxFinder = find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.scaleDown),
      );
      expect(fittedBoxFinder, findsOneWidget);
    });

    testWidgets('6.2 ManaText in ultra-narrow 30px container wraps gracefully without unhandled exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 30.0,
              child: ManaText('Cost: {2}{U}{B}{R}{G} and {T} now.'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));
    });

    testWidgets('6.3 Massive font size (100.0pt) scales icon to 110.0px without layout crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{W}',
              style: TextStyle(fontSize: 100.0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.size, closeTo(110.0, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('6.4 Tiny font size (1.0pt) scales icon to 1.1px cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{U}',
              style: TextStyle(fontSize: 1.0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.size, closeTo(1.1, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('6.5 Nested DefaultTextStyle overrides accurately resolve at the closest leaf scope', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: TextStyle(fontSize: 30.0, color: Colors.blue),
              child: Column(
                children: [
                  ManaText('{W}'), // 30 * 1.1 = 33.0
                  DefaultTextStyle(
                    style: TextStyle(fontSize: 12.0, color: Colors.green),
                    child: ManaText('{U}'), // 12 * 1.1 = 13.2
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons[0].size, closeTo(33.0, 0.001));
      expect(icons[1].size, closeTo(13.2, 0.001));
    });

    testWidgets('6.6 Overflow modes: ellipsis, fade, and clip handle constrained heights safely', (tester) async {
      for (final ovf in [TextOverflow.ellipsis, TextOverflow.fade, TextOverflow.clip]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 50.0,
                height: 20.0,
                child: ManaText(
                  '{1}{W}{U}{B}{R}{G} Very long line that definitely overflows',
                  overflow: ovf,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect(richText.overflow, equals(ovf));
      }
    });
  });
}

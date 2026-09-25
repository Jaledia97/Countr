// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Stress Test Suite for CardDetailSheet, ManaText, and ManaSymbolSpan.

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
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

  VaultItem createCardWithData({
    required String name,
    required String manaCost,
    required String oracleText,
    String? layout,
    List<Map<String, dynamic>>? cardFaces,
    List<Map<String, dynamic>>? cachedRulings,
    String? rulings,
    String? typeLine,
  }) {
    final dataMap = <String, dynamic>{
      'mana_cost': manaCost,
      'oracle_text': oracleText,
    };
    if (layout != null) dataMap['layout'] = layout;
    if (cardFaces != null) dataMap['card_faces'] = cardFaces;
    if (cachedRulings != null) dataMap['cached_rulings'] = cachedRulings;
    if (rulings != null) dataMap['rulings'] = rulings;
    if (typeLine != null) dataMap['type_line'] = typeLine;

    return VaultItem(
      id: 'stress-${name.toLowerCase().replaceAll(' ', '-').replaceAll('//', '-')}',
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'ADVERSARIAL',
      imageUrl: 'https://example.com/adversarial.jpg',
      acquiredPrice: 15.0,
      acquiredDate: DateTime(2024, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      currentMarketPrice: 25.0,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode(dataMap),
    );
  }

  Widget createSubject(
    VaultItem card, {
    Size size = const Size(320, 2400),
    TextScaler textScaler = const TextScaler.linear(1.0),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: textScaler,
          ),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: CardDetailSheet(
                item: card,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Adversarial Test 1: ManaSymbolSpan toPlainText() Extraction Rigor', () {
    const baseStyle = TextStyle(fontSize: 14.0);

    test('isolated ManaSymbolSpan computeToPlainText preserves bracketed notation', () {
      final spanT = ManaSymbolSpan(
        child: const SizedBox.shrink(),
        rawSymbol: 'T',
      );
      final spanGU = ManaSymbolSpan(
        child: const SizedBox.shrink(),
        rawSymbol: 'G/U',
      );
      final span2W = ManaSymbolSpan(
        child: const SizedBox.shrink(),
        rawSymbol: '2/W',
      );
      final spanHalf = ManaSymbolSpan(
        child: const SizedBox.shrink(),
        rawSymbol: '½',
      );
      final spanInf = ManaSymbolSpan(
        child: const SizedBox.shrink(),
        rawSymbol: '∞',
      );
      final spanBraced = ManaSymbolSpan(
        child: const SizedBox.shrink(),
        rawSymbol: '{B/P}',
      );

      // Default includePlaceholders = true
      expect(spanT.toPlainText(), equals('{T}'));
      expect(spanGU.toPlainText(), equals('{G/U}'));
      expect(span2W.toPlainText(), equals('{2/W}'));
      expect(spanHalf.toPlainText(), equals('{½}'));
      expect(spanInf.toPlainText(), equals('{∞}'));
      expect(spanBraced.toPlainText(), equals('{B/P}'));

      // When includePlaceholders is false, placeholders are omitted
      expect(spanT.toPlainText(includePlaceholders: false), equals(''));
      expect(spanGU.toPlainText(includePlaceholders: false), equals(''));
    });

    test('toPlainText() on parsed InlineSpan tree preserves original symbols perfectly', () {
      const source = 'Tap {T}: Add {G/U} or {W}. Pay {2/B} and {½}, then gain {∞} life.';
      final spans = ManaTextParser.parse(text: source, baseStyle: baseStyle);
      final rootSpan = TextSpan(children: spans, style: baseStyle);

      final extracted = rootSpan.toPlainText();
      expect(extracted, equals(source));
    });

    test('toPlainText() on mixed string with unclosed braces and unknown tokens', () {
      const source = '{2 and tap {InvalidToken} for {½} mana or pay {999999}.';
      final spans = ManaTextParser.parse(text: source, baseStyle: baseStyle);
      final rootSpan = TextSpan(children: spans, style: baseStyle);

      final extracted = rootSpan.toPlainText();
      expect(extracted, equals(source));
    });

    test('toPlainText() with empty braces and adjacent symbols', () {
      const source = '}{}{}{W}{U}{B}{R}{G}{T}{Q}{E}{S}{W/U/P}';
      final spans = ManaTextParser.parse(text: source, baseStyle: baseStyle);
      final rootSpan = TextSpan(children: spans, style: baseStyle);

      final extracted = rootSpan.toPlainText();
      expect(extracted, equals(source));
    });

    testWidgets('find.textContaining locates bracketed symbols rendered via ManaText', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('Activate {T}: Add {G/U} and {C}.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('{T}: Add {G/U}'), findsOneWidget);
      expect(find.textContaining('and {C}.'), findsOneWidget);
    });
  });

  group('Adversarial Test 2: CardDetailSheet Narrow Viewport (320px) & Extreme Font Scaling', () {
    testWidgets('320px viewport with 2.5x font scaling and massive 15-symbol mana cost has 0 overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final massiveCostCard = createCardWithData(
        name: 'The Ultimate Arch-Elemental',
        manaCost: '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}{2}{C}{S}{X}{Y}',
        oracleText: 'When The Ultimate Arch-Elemental enters the battlefield, you win the game.',
        typeLine: 'Legendary Creature — Elemental God Avatar',
      );

      await tester.pumpWidget(
        createSubject(
          massiveCostCard,
          size: const Size(320, 2400),
          textScaler: const TextScaler.linear(2.5),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaCostBar), findsWidgets);
      expect(find.byType(ManaText), findsWidgets);
    });

    testWidgets('320px viewport with 3.0x font scaling and massive rules text wall has 0 overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // A 1000+ character rules text resembling Ice Cauldron / Dance of the Dead
      const massiveRulesText =
          '{X}, {T}: Put a charge counter on this card and exile a nonland card from your hand. '
          'You may cast that card for as long as it remains exiled. '
          'Note the type and amount of mana spent to pay this ability\'s activation cost. '
          'Activate only as a sorcery.\n'
          '{T}, Remove a charge counter from this card: Add {W}{U}{B}{R}{G}. '
          'Spend this mana only to cast the card exiled with this permanent. '
          'If mana of type {C} or {S} was spent, draw a card. '
          'Whenever you pay {2/W}, {2/U}, {2/B}, {2/R}, or {2/G}, put a +1/+1 counter on target creature.\n'
          '{½}: This card gains flying and trample until end of turn. '
          '{∞}: You may search your library for any card and put it into your hand.';

      final wallCard = createCardWithData(
        name: 'Temporal Paradox Matrix',
        manaCost: '{4}{W}{U}{B}',
        oracleText: massiveRulesText,
        typeLine: 'Legendary Artifact — Contraption',
      );

      await tester.pumpWidget(
        createSubject(
          wallCard,
          size: const Size(320, 2400),
          textScaler: const TextScaler.linear(3.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaText), findsWidgets);
      // Verify text finder succeeds via ManaSymbolSpan.computeToPlainText
      expect(find.textContaining('Add {W}{U}{B}{R}{G}'), findsOneWidget);
    });

    testWidgets('320px viewport with 3.0x font scaling on deep nested abilities and unclosed braces', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const adversarialOracleText =
          'Cast {2 and tap {InvalidToken} for {½} mana.\n'
          '{T}: {T}: {T}: Untap target permanent. {Q}: Tap target permanent.\n'
          'Pay {W/U/P} and {C/P}. Then pay {H} and {E}{E}{E}. '
          'If {NotASymbol} is not paid, sacrifice this creature.\n'
          'Unclosed brace at the end: {2 and {W';

      final adversarialCard = createCardWithData(
        name: 'Chaos Engine Malfunction',
        manaCost: '{3}{R}{R}',
        oracleText: adversarialOracleText,
      );

      await tester.pumpWidget(
        createSubject(
          adversarialCard,
          size: const Size(320, 2400),
          textScaler: const TextScaler.linear(3.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Cast {2 and tap {InvalidToken}'), findsOneWidget);
      expect(find.textContaining('Unclosed brace at the end: {2 and {W'), findsOneWidget);
    });
  });

  group('Adversarial Test 3: Adventure Cards Under Extreme Scaling & Malformed Braces', () {
    testWidgets('320px viewport with 1.0x font scaling on dual adventure faces has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final adventureCard = createCardWithData(
        name: 'Realm-Cloaked Giant // Cast Off',
        manaCost: '{5}{W}{W}',
        oracleText: 'Vigilance // Destroy all non-Giant creatures.',
        layout: 'adventure',
        cardFaces: [
          {
            'name': 'Realm-Cloaked Giant',
            'mana_cost': '{5}{W}{W}{W}',
            'type_line': 'Creature — Giant',
            'power': '7',
            'toughness': '7',
            'oracle_text': 'Vigilance\n{T}: Add {W}{W} or spend {½} mana. {UnclosedFace0',
          },
          {
            'name': 'Cast Off',
            'mana_cost': '{2}{W}{W}',
            'type_line': 'Sorcery — Adventure',
            'oracle_text': 'Destroy all non-Giant creatures. If {FakeToken} was spent, add {C}. {UnclosedFace1',
          },
        ],
      );

      FlutterErrorDetails? errorDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };

      await tester.pumpWidget(
        createSubject(
          adventureCard,
          size: const Size(320, 2400),
          textScaler: const TextScaler.linear(1.0),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(errorDetails, isNull);
      expect(find.byType(ManaCostBar), findsWidgets);
      expect(find.byType(ManaText), findsWidgets);
    });

    testWidgets(
        'REMEDIATED: 320px viewport with extreme scaling (1.5x-3.0x) has zero RenderFlex overflows in Adventure divider banner',
        (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final adventureCard = createCardWithData(
        name: 'Realm-Cloaked Giant // Cast Off',
        manaCost: '{5}{W}{W}',
        oracleText: 'Vigilance // Destroy all non-Giant creatures.',
        layout: 'adventure',
        cardFaces: [
          {
            'name': 'Realm-Cloaked Giant',
            'mana_cost': '{5}{W}{W}{W}',
            'type_line': 'Creature — Giant',
            'power': '7',
            'toughness': '7',
            'oracle_text': 'Vigilance\n{T}: Add {W}{W} or spend {½} mana. {UnclosedFace0',
          },
          {
            'name': 'Cast Off',
            'mana_cost': '{2}{W}{W}',
            'type_line': 'Sorcery — Adventure',
            'oracle_text': 'Destroy all non-Giant creatures. If {FakeToken} was spent, add {C}. {UnclosedFace1',
          },
        ],
      );

      // Verify that scales 1.5, 2.0, 2.5, 3.0 produce zero RenderFlex overflows after remediation
      final testScales = [1.5, 2.0, 2.5, 3.0];

      for (final scale in testScales) {
        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtError = details;
        };

        await tester.pumpWidget(
          createSubject(
            adventureCard,
            size: const Size(320, 2400),
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldHandler;

        expect(caughtError, isNull, reason: 'Expected zero overflow at scale $scale but got: ${caughtError?.summary}');

        // Tear down widget tree so next iteration tests a clean RenderObject tree
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets('320px viewport with massive mana cost in adventure faces at 1.0x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final adventureCard = createCardWithData(
        name: 'Colossal Adventure Giant // Mighty Quest',
        manaCost: '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
        oracleText: 'Vigilance // Search your library.',
        layout: 'adventure',
        cardFaces: [
          {
            'name': 'Colossal Adventure Giant, Sovereign of the Ancient Reaches',
            'mana_cost': '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
            'type_line': 'Legendary Creature — Giant Noble Avatar',
            'power': '10',
            'toughness': '10',
            'oracle_text': 'Trample\n{T}: Add {W}{U}{B}{R}{G}.',
          },
          {
            'name': 'Mighty Quest Beyond the Far Horizons of Eternity',
            'mana_cost': '{5}{W}{U}{B}{R}{G}',
            'type_line': 'Sorcery — Adventure',
            'oracle_text': 'Search your library for three cards and put them into your hand.',
          },
        ],
      );

      FlutterErrorDetails? errorDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };

      await tester.pumpWidget(
        createSubject(
          adventureCard,
          size: const Size(320, 2400),
          textScaler: const TextScaler.linear(1.0),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(errorDetails, isNull, reason: 'RenderFlex overflow in adventure face header: ${errorDetails?.summary}');
    });
  });

  group('Adversarial Test 4: Cached Scryfall Rulings Under 3.0x Font Scaling & Symbol Chaos', () {
    testWidgets('rulings with unicode half-mana, unknown tokens, and unclosed braces render cleanly at 3.0x scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cardWithAdversarialRulings = createCardWithData(
        name: 'Urza, Academy Headmaster',
        manaCost: '{1}{W}{U}{B}{R}{G}',
        oracleText: '+1: Head to AskUrza.com and click +1.\n-1: Head to AskUrza.com and click -1.\n-6: Head to AskUrza.com and click -6.',
        cachedRulings: [
          {
            'published_at': '2017-12-08',
            'comment':
                'If an ability asks for {½}, you may pay half a white mana {HW} or half a red mana {HR}. '
                'Unclosed tokens like {1 and tap do not prevent activation.',
          },
          {
            'published_at': '2018-01-19',
            'comment':
                'Symbols {P}, {CHAOS}, {PW}, {TK}, and {A} function as official game counters. '
                '{InvalidTokenHere} and {1000000} are handled without disruption.',
          },
          {
            'published_at': '2020-04-17',
            'comment':
                'Contiguous cost payment: {W/U}{U/B}{B/R}{R/G}{G/W}{2/W}{2/U}{2/B}{2/R}{2/G}. '
                'Phyrexian hybrids: {G/U/P}{W/B/P}.',
          },
        ],
      );

      await tester.pumpWidget(
        createSubject(
          cardWithAdversarialRulings,
          size: const Size(320, 2400),
          textScaler: const TextScaler.linear(3.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaText), findsWidgets);
      expect(find.textContaining('If an ability asks for {½}'), findsOneWidget);
      expect(find.textContaining('Phyrexian hybrids: {G/U/P}{W/B/P}.'), findsOneWidget);
    });

    testWidgets('offline rules text clarification with unclosed braces at 2.5x font scale renders cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cardWithOfflineRules = createCardWithData(
        name: 'Offline Anomaly',
        manaCost: '{C}{C}',
        oracleText: '{T}: Add {C}.',
        rulings: 'Offline Clarification: When tapping {T}, note that {2 and tap {InvalidToken} does not crash the UI.',
      );

      await tester.pumpWidget(
        createSubject(
          cardWithOfflineRules,
          size: const Size(320, 2400),
          textScaler: const TextScaler.linear(2.5),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Offline Clarification: When tapping {T}'), findsOneWidget);
    });
  });
}

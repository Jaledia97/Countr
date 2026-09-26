// Copyright (c) 2026 Countr. All rights reserved.
// Widget test suite verifying ManaCostBar and ManaText integration in CardDetailSheet.

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
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
  }) {
      final dataMap = <String, dynamic>{
        'mana_cost': manaCost,
        'oracle_text': oracleText,
      };
      if (layout != null) dataMap['layout'] = layout;
      if (cardFaces != null) dataMap['card_faces'] = cardFaces;
      if (cachedRulings != null) dataMap['cached_rulings'] = cachedRulings;

      return VaultItem(
        id: 'card-${name.toLowerCase().replaceAll(' ', '-').replaceAll('//', '-')}',
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'TEST',
        imageUrl: 'https://example.com/card.jpg',
        acquiredPrice: 10.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false, isDeleted: false,
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode(dataMap),
      );
    }

  Widget createSubject(VaultItem card, {Size size = const Size(800, 2400)}) {
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

  group('CardDetailSheet - M3 Mana Symbology Integration', () {
    testWidgets('renders top-level ManaCostBar with mana icons for WUBRG card', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createCardWithData(
        name: 'Omnath, Locus of All',
        manaCost: '{W}{U}{B}{R}{G}',
        oracleText: 'At the beginning of your precombat main phase, add {3}.',
      );

      await tester.pumpWidget(createSubject(card));
      await tester.pumpAndSettle();

      // Verify ManaCostBar is present in header
      expect(find.byType(ManaCostBar), findsWidgets);

      final topCostBar = find.descendant(
        of: find.byType(ManaCostBar),
        matching: find.byType(ManaSymbolIcon),
      );
      expect(topCostBar, findsWidgets);

      final icons = tester.widgetList<ManaSymbolIcon>(topCostBar).toList();
      final assetPaths = icons.map((i) => i.assetPath).toList();
      expect(assetPaths, contains('assets/symbology/W.svg'));
      expect(assetPaths, contains('assets/symbology/U.svg'));
      expect(assetPaths, contains('assets/symbology/B.svg'));
      expect(assetPaths, contains('assets/symbology/R.svg'));
      expect(assetPaths, contains('assets/symbology/G.svg'));
    });

    testWidgets('renders ManaText with tap and colored mana symbols in Oracle rules section', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createCardWithData(
        name: 'Birds of Paradise',
        manaCost: '{G}',
        oracleText: 'Flying\n{T}: Add one mana of any color.',
      );

      await tester.pumpWidget(createSubject(card));
      await tester.pumpAndSettle();

      final oracleManaTexts = find.byType(ManaText);
      expect(oracleManaTexts, findsWidgets);

      // Verify tap icon rendered inside Oracle ManaText
      final oracleIcons = find.descendant(
        of: oracleManaTexts,
        matching: find.byType(ManaSymbolIcon),
      );
      expect(oracleIcons, findsOneWidget);

      final icon = tester.widget<ManaSymbolIcon>(oracleIcons.first);
      expect(icon.assetPath, equals('assets/symbology/T.svg'));
    });

    testWidgets('renders ManaCostBar and ManaText on Adventure card faces', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final adventureCard = createCardWithData(
        name: 'Brazen Borrower // Petty Theft',
        manaCost: '{1}{U}{U}',
        oracleText: 'Flash\nFlying // Return target nonland permanent to hand.',
        layout: 'adventure',
        cardFaces: [
          {
            'name': 'Brazen Borrower',
            'mana_cost': '{1}{U}{U}',
            'oracle_text': 'Flash\nFlying',
          },
          {
            'name': 'Petty Theft',
            'mana_cost': '{1}{U}',
            'oracle_text': 'Instant — Adventure\nReturn target nonland permanent an opponent controls to its owner\'s hand.',
          },
        ],
      );

      await tester.pumpWidget(createSubject(adventureCard));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaCostBar), findsWidgets);
      expect(find.byType(ManaText), findsWidgets);
    });

    testWidgets('renders ManaText for Scryfall ruling comments containing symbols', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cardWithRuling = createCardWithData(
        name: 'Sol Ring',
        manaCost: '{1}',
        oracleText: '{T}: Add {C}{C}.',
        cachedRulings: [
          {
            'published_at': '2024-01-01',
            'comment': '{C} represents colorless mana. You cannot pay {W} with {C}.',
          },
        ],
      );

      await tester.pumpWidget(createSubject(cardWithRuling));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('represents colorless mana'), findsWidgets);
    });

    testWidgets('narrow viewport (320px) with 2.0x font scaling has zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final extremeCard = createCardWithData(
        name: 'Progenitus',
        manaCost: '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
        oracleText: 'Protection from everything. If Progenitus would be put into a graveyard from anywhere, reveal Progenitus and shuffle it into its owner\'s library instead.',
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 1800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: createSubject(extremeCard, size: const Size(320, 1800)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

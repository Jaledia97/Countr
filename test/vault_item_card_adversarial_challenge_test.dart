import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultItem createTestItem({
    String id = 'test-card-1',
    String name = 'Test Card',
    String collectionType = 'mtg',
    String setOrSeries = 'Alpha',
    double acquiredPrice = 10.0,
    double currentMarketPrice = 25.0,
    int quantity = 1,
    String condition = 'NM',
    bool isGraded = false,
    String? dynamicData,
    Map<String, dynamic>? dynamicDataMap,
  }) {
    final dynString = dynamicData ??
        (dynamicDataMap != null ? jsonEncode(dynamicDataMap) : '{}');
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: '',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: dynString,
    );
  }

  group('Stress Test 1: Empty, Corrupt, and Malformed dynamicData Inputs', () {
    final malformedPayloads = <String, String>{
      'empty string': '',
      'whitespace string': '   ',
      'literal null': 'null',
      'literal number': '12345',
      'literal boolean': 'true',
      'literal array': '[1, 2, "three"]',
      'truncated JSON': '{"mana_cost": "{2}{U}", "power":',
      'completely invalid JSON': '<<not_json>>',
      'map with null values': '{"mana_cost": null, "power": null, "toughness": null, "keywords": null}',
      'map with numeric power/toughness': '{"mana_cost": 3, "power": 4, "toughness": 5}',
      'map with non-list keywords': '{"keywords": "Flying, Trample"}',
      'map with invalid elements in keywords list': '{"keywords": [null, 123, true, {}, []]}',
    };

    for (final entry in malformedPayloads.entries) {
      testWidgets('Handles ${entry.key} without crashing in Investor Mode',
          (WidgetTester tester) async {
        final item = createTestItem(dynamicData: entry.value);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VaultItemCard(
                item: item,
                persona: UserPersona.investor,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Investor Mode crashed on payload: ${entry.key}');
        expect(find.text('LIVE TMV'), findsOneWidget);
        expect(find.text('\$25.00'), findsOneWidget);
      });

      testWidgets('Handles ${entry.key} without crashing in Player Mode',
          (WidgetTester tester) async {
        final item = createTestItem(dynamicData: entry.value);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VaultItemCard(
                item: item,
                persona: UserPersona.player,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Player Mode crashed on payload: ${entry.key}');
        expect(find.text('GAME UTILITY'), findsOneWidget);
        // Financial deltas must never appear in Player mode
        expect(find.text('LIVE TMV'), findsNothing);
        expect(find.text('ACQUIRED'), findsNothing);
      });
    }
  });

  group('Stress Test 2: Unusual Power / Toughness Formats', () {
    testWidgets('Renders variable star/star format (* / *)', (WidgetTester tester) async {
      final item = createTestItem(
        dynamicDataMap: {
          'mana_cost': '{1}{G}',
          'power': '*',
          'toughness': '*',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(item: item, persona: UserPersona.player),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('⚔️ * / 🛡️ *'), findsOneWidget);
    });

    testWidgets('Renders dynamic addition format (1+* / *)', (WidgetTester tester) async {
      final item = createTestItem(
        dynamicDataMap: {
          'mana_cost': '{2}{W}',
          'power': '1+*',
          'toughness': '*',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(item: item, persona: UserPersona.player),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('⚔️ 1+* / 🛡️ *'), findsOneWidget);
    });

    testWidgets('Renders extreme numeric stats (9999 / 9999)', (WidgetTester tester) async {
      final item = createTestItem(
        dynamicDataMap: {
          'mana_cost': '{10}',
          'power': '9999',
          'toughness': '9999',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(item: item, persona: UserPersona.player),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('⚔️ 9999 / 🛡️ 9999'), findsOneWidget);
    });

    testWidgets('Handles null, empty, and asymmetric power/toughness safely',
        (WidgetTester tester) async {
      // 1. Both empty strings
      final emptyPT = createTestItem(
        id: 'empty-pt',
        dynamicDataMap: {'power': '', 'toughness': ''},
      );
      // 2. Power empty string, toughness valid
      final emptyP = createTestItem(
        id: 'empty-p',
        dynamicDataMap: {'power': '', 'toughness': '4'},
      );
      // 3. Power valid, toughness empty string
      final emptyT = createTestItem(
        id: 'empty-t',
        dynamicDataMap: {'power': '4', 'toughness': ''},
      );
      // 4. Power null, toughness valid
      final nullP = createTestItem(
        id: 'null-p',
        dynamicDataMap: {'toughness': '5'},
      );
      // 5. Power valid, toughness null
      final nullT = createTestItem(
        id: 'null-t',
        dynamicDataMap: {'power': '5'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  VaultItemCard(item: emptyPT, persona: UserPersona.player),
                  VaultItemCard(item: emptyP, persona: UserPersona.player),
                  VaultItemCard(item: emptyT, persona: UserPersona.player),
                  VaultItemCard(item: nullP, persona: UserPersona.player),
                  VaultItemCard(item: nullT, persona: UserPersona.player),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // emptyPT, emptyP, nullP, nullT do NOT render a valid combat badge
      expect(find.text('⚔️  / 🛡️ '), findsNothing);
      expect(find.text('⚔️  / 🛡️ 4'), findsNothing);
    });
  });

  group('Stress Test 3: Cards with 10+ Keywords and Wrap Layout', () {
    testWidgets('Wraps 12 canonical MTG keywords without overflow across screen sizes',
        (WidgetTester tester) async {
      // Standard iPhone width
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final multiKeywordCard = createTestItem(
        name: 'The Ultimate Keyword Chimera',
        dynamicDataMap: {
          'mana_cost': '{W}{U}{B}{R}{G}',
          'power': '10',
          'toughness': '10',
          'keywords': [
            'Flying',
            'Vigilance',
            'Trample',
            'Haste',
            'Lifelink',
            'Deathtouch',
            'First Strike',
            'Double Strike',
            'Reach',
            'Menace',
            'Ward',
            'Hexproof',
          ],
        },
      );

      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VaultItemCard(
                item: multiKeywordCard,
                persona: UserPersona.player,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (caughtDetails != null) {
        // ignore: avoid_print
        print('CAUGHT DETAILS:\n${caughtDetails!.toString()}');
      }
      expect(caughtDetails, isNull);

      // Verify all 12 keyword chips rendered
      final expectedKeywords = [
        'Flying',
        'Vigilance',
        'Trample',
        'Haste',
        'Lifelink',
        'Deathtouch',
        'First Strike',
        'Double Strike',
        'Reach',
        'Menace',
        'Ward',
        'Hexproof',
      ];
      for (final kw in expectedKeywords) {
        expect(find.text(kw), findsOneWidget, reason: 'Keyword chip $kw not found');
      }

      // Verify Wrap widget is used for keyword layout
      expect(find.byType(Wrap), findsWidgets);
    });

    testWidgets('Extracts and deduplicates keywords from oracle_text and keywords list simultaneously',
        (WidgetTester tester) async {
      final combinedCard = createTestItem(
        name: 'Zetalpa, Primal Dawn',
        dynamicDataMap: {
          'mana_cost': '{6}{W}{W}',
          'power': '4',
          'toughness': '8',
          'keywords': ['Flying', 'Double Strike'],
          'oracle_text':
              'Flying, double strike, vigilance, trample, indestructible.\nWhenever Zetalpa attacks, gain lifelink.',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: combinedCard,
              persona: UserPersona.player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Flying'), findsOneWidget);
      expect(find.text('Double Strike'), findsOneWidget);
      expect(find.text('Vigilance'), findsOneWidget);
      expect(find.text('Trample'), findsOneWidget);
      expect(find.text('Lifelink'), findsOneWidget);
    });
  });

  group('Stress Test 4: Non-MTG Cards in Player Mode', () {
    testWidgets('Pokémon card with HP and Stage renders stats in Player mode',
        (WidgetTester tester) async {
      final pokemonItem = createTestItem(
        id: 'pkm-mewtwo',
        collectionType: 'pokemon',
        name: 'Mewtwo VSTAR',
        setOrSeries: 'Pokémon GO',
        currentMarketPrice: 42.0,
        acquiredPrice: 18.0,
        dynamicDataMap: {
          'hp': '280',
          'stage': 'VSTAR',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: pokemonItem,
              persona: UserPersona.player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('HP 280 • VSTAR'), findsOneWidget);
      expect(find.text('GAME UTILITY'), findsOneWidget);
      // Completely suppresses financial stats
      expect(find.text('ACQUIRED'), findsNothing);
      expect(find.text('LIVE TMV'), findsNothing);
      expect(find.text('\$18.00'), findsNothing);
      expect(find.text('\$42.00'), findsNothing);
    });

    testWidgets('Pokémon card with only HP renders cleanly without stage',
        (WidgetTester tester) async {
      final basicPkm = createTestItem(
        id: 'pkm-pikachu',
        collectionType: 'pokemon',
        name: 'Pikachu',
        setOrSeries: 'Base Set',
        dynamicDataMap: {
          'hp': '60',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: basicPkm,
              persona: UserPersona.player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('HP 60'), findsOneWidget);
    });

    testWidgets('Lorcana card renders gracefully in Player mode',
        (WidgetTester tester) async {
      final lorcanaItem = createTestItem(
        id: 'lorcana-elsa',
        collectionType: 'lorcana',
        name: 'Elsa - Spirit of Winter',
        setOrSeries: 'The First Chapter',
        acquiredPrice: 25.0,
        currentMarketPrice: 65.0,
        dynamicDataMap: {
          'ink_cost': '8',
          'lore': '2',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: lorcanaItem,
              persona: UserPersona.player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Has no mana/pt/hp, so renders category utility fallback
      expect(find.text('LORCANA UTILITY'), findsOneWidget);
      expect(find.text('GAME UTILITY'), findsOneWidget);
      expect(find.text('LIVE TMV'), findsNothing);
    });

    testWidgets('Sports card renders cleanly in Player mode with no financial leaks',
        (WidgetTester tester) async {
      final sportsCard = createTestItem(
        id: 'sports-mahomes',
        collectionType: 'sports_card',
        name: 'Patrick Mahomes II',
        setOrSeries: '2017 Panini Prizm',
        acquiredPrice: 500.0,
        currentMarketPrice: 1800.0,
        dynamicDataMap: {
          'sport': 'Football',
          'team': 'Kansas City Chiefs',
          'is_rookie': true,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: sportsCard,
              persona: UserPersona.player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SPORTS_CARD UTILITY'), findsOneWidget);
      expect(find.text('GAME UTILITY'), findsOneWidget);
      expect(find.text('LIVE TMV'), findsNothing);
      expect(find.text('\$500.00'), findsNothing);
      expect(find.text('\$1800.00'), findsNothing);
    });
  });

  group('Stress Test 5: Zero-Scope Environments & Missing ProviderScope', () {
    testWidgets('VaultItemCard pumps directly without ProviderScope without throwing',
        (WidgetTester tester) async {
      final item = createTestItem(
        name: 'Black Lotus',
        acquiredPrice: 5000.0,
        currentMarketPrice: 15000.0,
      );

      // Absolutely zero Riverpod scopes in the tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no FlutterError: No ProviderScope found
      expect(tester.takeException(), isNull);
      // Defaults to Investor Mode
      expect(find.text('ACQUIRED'), findsOneWidget);
      expect(find.text('LIVE TMV'), findsOneWidget);
      expect(find.text('\$5000.00'), findsOneWidget);
      expect(find.text('\$15000.00'), findsOneWidget);
    });

    testWidgets('Explicit persona: UserPersona.player in zero-scope environment works cleanly',
        (WidgetTester tester) async {
      final item = createTestItem(
        name: 'Lightning Bolt',
        dynamicDataMap: {
          'mana_cost': '{R}',
          'oracle_text': 'Deal 3 damage to any target.',
        },
      );

      // Zero-scope with explicit player persona
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: item,
              persona: UserPersona.player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('{R}'), findsOneWidget);
      expect(find.text('GAME UTILITY'), findsOneWidget);
      expect(find.text('LIVE TMV'), findsNothing);
    });

    testWidgets('Multiple polymorphic cards in zero-scope ListView render without error',
        (WidgetTester tester) async {
      final items = [
        createTestItem(id: '1', collectionType: 'mtg', name: 'Mox Ruby'),
        createTestItem(id: '2', collectionType: 'pokemon', name: 'Blastoise'),
        createTestItem(id: '3', collectionType: 'sports_card', name: 'Michael Jordan'),
        createTestItem(id: '4', collectionType: 'comic', name: 'Spider-Man #1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: items.map((it) => VaultItemCard(item: it)).toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(VaultItemCard), findsNWidgets(4));
    });
  });

  group('Stress Test 6: Narrow Screen Layout Resilience', () {
    testWidgets('Player Mode with long mana cost and combat stats does not overflow on 360px screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final multiColorItem = createTestItem(
        name: 'Progenitus',
        dynamicDataMap: {
          'mana_cost': '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
          'power': '10',
          'toughness': '10',
          'keywords': ['Protection'],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VaultItemCard(
                item: multiColorItem,
                persona: UserPersona.player,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check if overflow occurred
      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Overflow occurred on 360px screen: $exception');
      expect(find.text('{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}'), findsOneWidget);
      expect(find.text('⚔️ 10 / 🛡️ 10'), findsOneWidget);
    });
  });
}

// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Challenger stress harness targeting Adventure divider banner under extreme constraints.

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
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

  VaultItem createAdventureCard({
    required String name,
    required String manaCost,
    required String oracleText,
    List<Map<String, dynamic>>? cardFaces,
  }) {
    final dataMap = <String, dynamic>{
      'mana_cost': manaCost,
      'oracle_text': oracleText,
      'layout': 'adventure',
    };
    if (cardFaces != null) dataMap['card_faces'] = cardFaces;

    return VaultItem(
      id: 'adv-${name.toLowerCase().replaceAll(' ', '-').replaceAll('//', '-')}',
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'ELD',
      imageUrl: 'https://example.com/adventure.jpg',
      acquiredPrice: 5.0,
      acquiredDate: DateTime(2024, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      currentMarketPrice: 8.0,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode(dataMap),
    );
  }

  Widget createSubject(
    VaultItem card, {
    required double width,
    required double height,
    required double fontScale,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(fontScale),
          ),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: height,
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

  void checkAdventureDividerRenderFlex(WidgetTester tester) {
    // Find the text 'ADVENTURE SPELL'
    final textFinder = find.text('ADVENTURE SPELL');
    expect(textFinder, findsOneWidget);

    // Find the parent Row containing the divider banner (icon + text + expanded lines)
    final rowElements = find.byWidgetPredicate((w) => w is Row).evaluate();
    RenderFlex? dividerBannerRowRenderFlex;

    for (final element in rowElements) {
      final widget = element.widget as Row;
      // Look for the row containing Expanded children and Flexible
      final hasExpanded = widget.children.any((c) => c is Expanded);
      final hasFlexible = widget.children.any((c) => c is Flexible);
      if (hasExpanded && hasFlexible) {
        dividerBannerRowRenderFlex = element.renderObject as RenderFlex?;
        break;
      }
    }

    expect(dividerBannerRowRenderFlex, isNotNull, reason: 'Divider banner Row RenderFlex not found');
    expect(
      dividerBannerRowRenderFlex!.size.width <= dividerBannerRowRenderFlex.constraints.maxWidth,
      isTrue,
      reason: 'Divider banner row width (${dividerBannerRowRenderFlex.size.width}) exceeds maxWidth (${dividerBannerRowRenderFlex.constraints.maxWidth})',
    );
  }

  group('Adventure Divider Empirical Challenge: Font Scale Matrix on 320px Viewport', () {
    final cardFacesStandard = [
      {
        'name': 'Realm-Cloaked Giant',
        'mana_cost': '{5}{W}{W}',
        'type_line': 'Creature — Giant',
        'power': '7',
        'toughness': '7',
        'oracle_text': 'Vigilance',
      },
      {
        'name': 'Cast Off',
        'mana_cost': '{2}{W}{W}',
        'type_line': 'Sorcery — Adventure',
        'oracle_text': 'Destroy all non-Giant creatures.',
      },
    ];

    final standardAdventureCard = createAdventureCard(
      name: 'Realm-Cloaked Giant // Cast Off',
      manaCost: '{5}{W}{W}',
      oracleText: 'Vigilance // Destroy all non-Giant creatures.',
      cardFaces: cardFacesStandard,
    );

    for (final scale in [1.5, 2.0, 2.5, 3.0]) {
      testWidgets('320px viewport at font scale ${scale}x produces 0 RenderFlex overflows and renders divider', (tester) async {
        tester.view.physicalSize = const Size(320, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtError = details;
        };

        await tester.pumpWidget(
          createSubject(
            standardAdventureCard,
            width: 320,
            height: 2400,
            fontScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldHandler;

        expect(caughtError, isNull, reason: 'Caught Flutter error at ${scale}x: ${caughtError?.summary}');
        expect(find.text('ADVENTURE SPELL'), findsOneWidget);
        expect(find.byIcon(Icons.auto_stories), findsOneWidget);

        // Verify the Adventure Divider specifically
        checkAdventureDividerRenderFlex(tester);
      });
    }

    testWidgets('Fall-back adventure card (no card_faces in dynamicData, split by //) at 3.0x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fallbackAdventureCard = createAdventureCard(
        name: 'Bonecrusher Giant // Stomp',
        manaCost: '{2}{R}',
        oracleText: 'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage to that spell\'s controller. // Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.',
        cardFaces: null, // Forces fallback parser in _buildAdventureOracleContentForItem
      );

      FlutterErrorDetails? caughtError;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtError = details;
      };

      await tester.pumpWidget(
        createSubject(
          fallbackAdventureCard,
          width: 320,
          height: 2400,
          fontScale: 3.0,
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(caughtError, isNull, reason: 'Fallback adventure threw error at 3.0x: ${caughtError?.summary}');
      expect(find.text('ADVENTURE SPELL'), findsOneWidget);
      checkAdventureDividerRenderFlex(tester);
    });

    testWidgets('Boundary analysis: determine minimum viewport width threshold for Adventure divider', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // We test progressively narrower viewports: 300, 280, 260, 240, 220, 200, 180, 160
      final widthsToTest = [300.0, 280.0, 260.0, 240.0, 220.0, 200.0];

      for (final w in widthsToTest) {
        tester.view.physicalSize = Size(w, 2400);

        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtError = details;
        };

        await tester.pumpWidget(
          createSubject(
            standardAdventureCard,
            width: w,
            height: 2400,
            fontScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldHandler;

        expect(caughtError, isNull, reason: 'Failed at viewport width $w at 2.0x font scale: ${caughtError?.summary}');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Adventure Divider standalone isolation test under 1.5x, 2.0x, 2.5x, 3.0x, 4.0x, 5.0x', (tester) async {
      // Test the exact Adventure divider widget in isolation across extreme font scalers
      for (final scale in [1.5, 2.0, 2.5, 3.0, 4.0, 5.0]) {
        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtError = details;
        };

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 100),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 252, // Exact available width inside CardDetailSheet on 320px viewport
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.cyan.withValues(alpha: 0.3),
                            ),
                          ),
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.cyan.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_stories, size: 13, color: Colors.cyan),
                                    SizedBox(width: 6),
                                    Text(
                                      'ADVENTURE SPELL',
                                      style: TextStyle(
                                        color: Colors.cyan,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.cyan.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldHandler;

        expect(caughtError, isNull, reason: 'Standalone divider overflow at ${scale}x: ${caughtError?.summary}');
        expect(find.text('ADVENTURE SPELL'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  });
}

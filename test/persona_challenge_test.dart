import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper factory for test items
  VaultItem createTestItem({
    String id = 'card-1',
    String name = 'Test Card',
    String collectionType = 'mtg',
    double acquiredPrice = 20.0,
    double currentMarketPrice = 50.0,
    int quantity = 1,
    String condition = 'NM',
    bool isGraded = false,
    Map<String, dynamic>? dynamicDataMap,
    String? rawDynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'Test Set',
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
      dynamicData: rawDynamicData ?? (dynamicDataMap != null ? jsonEncode(dynamicDataMap) : '{}'),
    );
  }

  group('Empirical Challenge 1: Rapid Toggling Stress & Animation Harness', () {
    testWidgets('Rapidly toggle between Investor and Player 50 times mid-animation without assertion or overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MorphingCommandCenter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final investorFinder = find.byKey(const Key('persona_toggle_investor'));
      final playerFinder = find.byKey(const Key('persona_toggle_player'));

      expect(investorFinder, findsOneWidget);
      expect(playerFinder, findsOneWidget);
      expect(container.read(userPersonaProvider), UserPersona.investor);

      // Perform 50 rapid toggle iterations with random/short micro-frame pumps (1ms to 20ms)
      // deliberately interrupting the 200ms AnimatedContainer curves mid-flight.
      for (int i = 0; i < 50; i++) {
        if (i % 2 == 0) {
          await tester.tap(playerFinder);
          // Micro pump interrupting the transition animation
          await tester.pump(const Duration(milliseconds: 10));
          expect(container.read(userPersonaProvider), UserPersona.player);
        } else {
          await tester.tap(investorFinder);
          // Micro pump interrupting the transition animation
          await tester.pump(const Duration(milliseconds: 15));
          expect(container.read(userPersonaProvider), UserPersona.investor);
        }

        // Verify zero uncaught Flutter framework or render tree exceptions
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown during rapid toggle at iteration $i');
      }

      // Settle animations
      await tester.pumpAndSettle();

      // Final state after 50 iterations (0-49, 49 is odd -> investor)
      expect(container.read(userPersonaProvider), UserPersona.investor);
      expect(find.text('INVESTOR MODE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // One final toggle to player and settle
      await tester.tap(playerFinder);
      await tester.pumpAndSettle();
      expect(container.read(userPersonaProvider), UserPersona.player);
      expect(find.text('PLAYER MODE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping currently active segment repeatedly is idempotent and throws no errors',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MorphingCommandCenter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final investorFinder = find.byKey(const Key('persona_toggle_investor'));
      final playerFinder = find.byKey(const Key('persona_toggle_player'));

      // Tap investor 10 times while already investor
      for (int i = 0; i < 10; i++) {
        await tester.tap(investorFinder);
        await tester.pump(const Duration(milliseconds: 5));
        expect(container.read(userPersonaProvider), UserPersona.investor);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      // Tap player 10 times consecutively
      for (int i = 0; i < 10; i++) {
        await tester.tap(playerFinder);
        await tester.pump(const Duration(milliseconds: 5));
        expect(container.read(userPersonaProvider), UserPersona.player);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text('PLAYER MODE'), findsOneWidget);
    });
  });

  group('Empirical Challenge 2: Live Widget Tree Reconstruction via Drawer Modal', () {
    testWidgets('Toggling persona in opened Drawer modal immediately reconstructs underlying VaultItemCards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mtgCreature = createTestItem(
        id: 'mtg-sheoldred',
        name: 'Sheoldred, the Apocalypse',
        acquiredPrice: 40.0,
        currentMarketPrice: 85.0,
        dynamicDataMap: {
          'mana_cost': '{2}{B}{B}',
          'type_line': 'Legendary Creature — Phyrexian Praetor',
          'power': '4',
          'toughness': '5',
          'oracle_text': 'Deathtouch\nWhenever you draw a card, you gain 2 life.',
          'keywords': ['Deathtouch'],
        },
      );

      final mtgPlaneswalker = createTestItem(
        id: 'mtg-liliana',
        name: 'Liliana of the Veil',
        acquiredPrice: 30.0,
        currentMarketPrice: 22.0,
        dynamicDataMap: {
          'mana_cost': '{1}{B}{B}',
          'type_line': 'Legendary Planeswalker — Liliana',
          'loyalty': '3',
          'oracle_text': '+1: Each player discards a card.',
        },
      );

      final pokemonCard = createTestItem(
        id: 'pkm-charizard',
        collectionType: 'pokemon',
        name: 'Charizard ex',
        acquiredPrice: 15.0,
        currentMarketPrice: 45.0,
        dynamicDataMap: {
          'hp': '330',
          'stage': 'Stage 2',
        },
      );

      // Build a realistic live app screen with an open-drawer action button and Vault cards
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Live Vault Screen'),
                  actions: [
                    IconButton(
                      key: const Key('open_command_center_btn'),
                      icon: const Icon(Icons.menu),
                      onPressed: () => MorphingCommandCenter.show(context),
                    ),
                  ],
                ),
                body: ListView(
                  children: [
                    VaultItemCard(item: mtgCreature),
                    VaultItemCard(item: mtgPlaneswalker),
                    VaultItemCard(item: pokemonCard),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State: Investor Mode on all cards
      expect(container.read(userPersonaProvider), UserPersona.investor);
      expect(find.text('ACQUIRED'), findsNWidgets(3));
      expect(find.text('LIVE TMV'), findsNWidgets(3));
      expect(find.text('\$40.00'), findsOneWidget);
      expect(find.text('\$85.00'), findsOneWidget);
      expect(find.text('+112.5% (+\$45.00)'), findsOneWidget);
      expect(find.text('\$30.00'), findsOneWidget);
      expect(find.text('\$22.00'), findsOneWidget);
      expect(find.text('-26.7% (-\$8.00)'), findsOneWidget);
      // Mechanics must be absent
      expect(find.text('{2}{B}{B}'), findsNothing);
      expect(find.text('⚔️ 4 / 🛡️ 5'), findsNothing);
      expect(find.text('Deathtouch'), findsNothing);
      expect(find.text('Loyalty: 3'), findsNothing);
      expect(find.text('HP 330 • Stage 2'), findsNothing);

      // 2. Open MorphingCommandCenter modal
      await tester.tap(find.byKey(const Key('open_command_center_btn')));
      await tester.pumpAndSettle();

      // Drawer dialog is now open
      expect(find.byType(MorphingCommandCenter), findsOneWidget);
      expect(find.text('COMMAND CENTER'), findsOneWidget);

      // 3. Tap Player toggle inside the open drawer dialog
      await tester.tap(find.byKey(const Key('persona_toggle_player')));
      await tester.pump(); // Pump frame for state dispatch
      await tester.pumpAndSettle();

      // 4. Verify Riverpod state updated
      expect(container.read(userPersonaProvider), UserPersona.player);

      // 5. Close drawer dialog via close icon
      await tester.tap(find.byTooltip('Close Menu'));
      await tester.pumpAndSettle();
      expect(find.byType(MorphingCommandCenter), findsNothing);

      // 6. Verify underlying VaultItemCards immediately reconstructed with Player mechanics
      expect(find.text('GAME UTILITY'), findsNWidgets(3));
      expect(find.text('{2}{B}{B}'), findsOneWidget);
      expect(find.text('⚔️ 4 / 🛡️ 5'), findsOneWidget);
      expect(find.text('Deathtouch'), findsOneWidget);
      expect(find.text('Loyalty: 3'), findsOneWidget);
      expect(find.text('HP 330 • Stage 2'), findsOneWidget);

      // Verify zero financial deltas or prices in Player Mode
      expect(find.text('ACQUIRED'), findsNothing);
      expect(find.text('LIVE TMV'), findsNothing);
      expect(find.text('\$40.00'), findsNothing);
      expect(find.text('\$85.00'), findsNothing);
      expect(find.text('\$30.00'), findsNothing);
      expect(find.text('\$22.00'), findsNothing);
      expect(find.text('\$15.00'), findsNothing);
      expect(find.text('\$45.00'), findsNothing);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
      expect(find.byIcon(Icons.trending_down_rounded), findsNothing);

      // 7. Re-open drawer dialog and switch back to Investor Mode
      await tester.tap(find.byKey(const Key('open_command_center_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('persona_toggle_investor')));
      await tester.pumpAndSettle();
      expect(container.read(userPersonaProvider), UserPersona.investor);

      await tester.tap(find.byTooltip('Close Menu'));
      await tester.pumpAndSettle();

      // 8. Verify cards immediately reconstructed back to Investor Mode
      expect(find.text('ACQUIRED'), findsNWidgets(3));
      expect(find.text('LIVE TMV'), findsNWidgets(3));
      expect(find.text('\$40.00'), findsOneWidget);
      expect(find.text('\$85.00'), findsOneWidget);
      expect(find.text('{2}{B}{B}'), findsNothing);
      expect(find.text('⚔️ 4 / 🛡️ 5'), findsNothing);
      expect(find.text('GAME UTILITY'), findsNothing);
    });

    testWidgets('Live tree toggling loop (20 cycles with drawer open)',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final item = createTestItem(
        dynamicDataMap: {
          'mana_cost': '{1}{W}',
          'power': '2',
          'toughness': '2',
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const SizedBox(
                    height: 400,
                    child: MorphingCommandCenter(),
                  ),
                  Expanded(
                    child: VaultItemCard(item: item),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final investorFinder = find.byKey(const Key('persona_toggle_investor'));
      final playerFinder = find.byKey(const Key('persona_toggle_player'));

      for (int i = 0; i < 20; i++) {
        await tester.tap(playerFinder);
        await tester.pumpAndSettle();
        expect(find.text('⚔️ 2 / 🛡️ 2'), findsOneWidget);
        expect(find.text('LIVE TMV'), findsNothing);

        await tester.tap(investorFinder);
        await tester.pumpAndSettle();
        expect(find.text('LIVE TMV'), findsOneWidget);
        expect(find.text('⚔️ 2 / 🛡️ 2'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('Empirical Challenge 3: Responsive Layout Constraints & Overflow Resistance', () {
    testWidgets('MorphingCommandCenter does not overflow on narrow screens (320px width)',
        (WidgetTester tester) async {
      // iPhone SE (1st gen) width
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MorphingCommandCenter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Toggle to player and settle on narrow screen
      await tester.tap(find.byKey(const Key('persona_toggle_player')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('MorphingCommandCenter does not overflow on landscape/short screens (700x380)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(700, 380);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MorphingCommandCenter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('VaultItemCard does not overflow on narrow 300px constraint with dense data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(300, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final denseItem = createTestItem(
        name: 'Extremely Long Name That Spans Multiple Lines For Layout Stress Testing',
        acquiredPrice: 123456.78,
        currentMarketPrice: 987654.32,
        dynamicDataMap: {
          'mana_cost': '{3}{W}{U}{B}{R}{G}',
          'power': '15',
          'toughness': '15',
          'keywords': [
            'Flying',
            'Vigilance',
            'Trample',
            'Lifelink',
            'Deathtouch',
            'First Strike',
            'Indestructible',
            'Hexproof',
          ],
        },
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    VaultItemCard(item: denseItem),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Investor Mode overflow
      expect(tester.takeException(), isNull);

      // Switch to Player Mode
      container.read(userPersonaProvider.notifier).state = UserPersona.player;
      await tester.pumpAndSettle();

      // Check Player Mode overflow with wrap chips
      expect(tester.takeException(), isNull);
      expect(find.text('Hexproof'), findsOneWidget);
    });
  });

  group('Empirical Challenge 4: Edge Cases & Data Malformation Resilience', () {
    testWidgets('VaultItemCard handles corrupted dynamicData JSON gracefully in both modes',
        (WidgetTester tester) async {
      final malformedItem = createTestItem(
        rawDynamicData: '{corrupted_not_valid_json: 123',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemCard(item: malformedItem),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Investor Mode: renders fine
      expect(find.text('LIVE TMV'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switch to Player Mode: should not crash, falls back to generic utility row
      container.read(userPersonaProvider.notifier).state = UserPersona.player;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('MTG UTILITY'), findsOneWidget);
      expect(find.text('GAME UTILITY'), findsOneWidget);
    });

    testWidgets('VaultItemCard handles zero acquired price and negative financial delta gracefully',
        (WidgetTester tester) async {
      // Zero acquired price: test division by zero guard
      final zeroAcquiredItem = createTestItem(
        acquiredPrice: 0.0,
        currentMarketPrice: 25.0,
      );

      // Negative acquired price: strange edge case
      final negativeAcquiredItem = createTestItem(
        id: 'card-neg',
        acquiredPrice: -10.0,
        currentMarketPrice: 5.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VaultItemCard(item: zeroAcquiredItem, persona: UserPersona.investor),
                VaultItemCard(item: negativeAcquiredItem, persona: UserPersona.investor),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // pct is 0.0 when acquiredPrice <= 0
      expect(find.text('+0.0% (+\$25.00)'), findsOneWidget);
    });

    testWidgets('VaultItemCard handles quantity 0 (Catalog item) in both Investor and Player modes',
        (WidgetTester tester) async {
      final unownedItem = createTestItem(
        quantity: 0,
        acquiredPrice: 0.0,
        currentMarketPrice: 100.0,
        dynamicDataMap: {
          'mana_cost': '{X}{X}{U}',
          'oracle_text': 'Draw X cards.',
        },
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemCard(item: unownedItem),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Investor mode renders catalog tag
      expect(find.text('CATALOG / UNOWNED'), findsOneWidget);
      expect(find.text('MARKET VALUE'), findsOneWidget);
      expect(find.text('\$100.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switch to Player Mode: renders mana cost '{X}{X}{U}'
      container.read(userPersonaProvider.notifier).state = UserPersona.player;
      await tester.pumpAndSettle();

      expect(find.text('{X}{X}{U}'), findsOneWidget);
      expect(find.text('CATALOG / UNOWNED'), findsNothing);
      expect(find.text('MARKET VALUE'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

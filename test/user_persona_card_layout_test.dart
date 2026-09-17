import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  group('Global Persona State & userPersonaProvider', () {
    test('default persona is UserPersona.investor', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(userPersonaProvider), UserPersona.investor);
    });

    test('userPersonaProvider can be toggled to player and back to investor', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(userPersonaProvider), UserPersona.investor);

      container.read(userPersonaProvider.notifier).state = UserPersona.player;
      expect(container.read(userPersonaProvider), UserPersona.player);

      container.read(userPersonaProvider.notifier).state = UserPersona.investor;
      expect(container.read(userPersonaProvider), UserPersona.investor);
    });
  });

  group('MorphingCommandCenter Persona Segmented Toggle', () {
    testWidgets('toggles between Investor and Player modes via touch targets',
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

      // Verify initial state
      expect(find.byKey(const Key('persona_toggle_investor')), findsOneWidget);
      expect(find.byKey(const Key('persona_toggle_player')), findsOneWidget);
      expect(find.text('INVESTOR MODE'), findsOneWidget);
      expect(container.read(userPersonaProvider), UserPersona.investor);

      // Tap Player segment
      await tester.tap(find.byKey(const Key('persona_toggle_player')));
      await tester.pumpAndSettle();

      // Verify Player state
      expect(container.read(userPersonaProvider), UserPersona.player);
      expect(find.text('PLAYER MODE'), findsOneWidget);

      // Tap Investor segment
      await tester.tap(find.byKey(const Key('persona_toggle_investor')));
      await tester.pumpAndSettle();

      // Verify Investor state restored
      expect(container.read(userPersonaProvider), UserPersona.investor);
      expect(find.text('INVESTOR MODE'), findsOneWidget);
    });
  });

  group('VaultItemCard Dynamic Dual-Persona Layout', () {
    late VaultItem mtgCombatItem;
    late VaultItem mtgPlaneswalkerItem;
    late VaultItem mtgLossItem;

    setUp(() {
      mtgCombatItem = VaultItem(
        id: 'mtg-atraxa-1',
        collectionType: 'mtg',
        name: "Atraxa, Praetors' Voice",
        setOrSeries: 'Commander 2016',
        imageUrl: '',
        acquiredPrice: 20.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 50.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'mana_cost': '{G}{W}{U}{B}',
          'type_line': 'Legendary Creature — Phyrexian Angel',
          'power': '4',
          'toughness': '4',
          'oracle_text':
              'Flying, vigilance, deathtouch, lifelink.\nAt the beginning of your end step, proliferate.',
          'keywords': ['Flying', 'Vigilance', 'Deathtouch', 'Lifelink'],
        }),
      );

      mtgPlaneswalkerItem = VaultItem(
        id: 'mtg-jace-1',
        collectionType: 'mtg',
        name: 'Jace, the Mind Sculptor',
        setOrSeries: 'Worldwake',
        imageUrl: '',
        acquiredPrice: 80.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'LP',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 120.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'mana_cost': '{2}{U}{U}',
          'type_line': 'Legendary Planeswalker — Jace',
          'loyalty': '3',
          'oracle_text':
              '+2: Look at the top card of target player\'s library.',
          'keywords': [],
        }),
      );

      mtgLossItem = VaultItem(
        id: 'mtg-loss-1',
        collectionType: 'mtg',
        name: 'Bulk Rare',
        setOrSeries: 'Modern Horizons',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 2,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 6.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({}),
      );
    });

    testWidgets('Investor Mode displays market price, acquired price, and delta badge',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VaultItemCard(
                  item: mtgCombatItem,
                  persona: UserPersona.investor,
                ),
                VaultItemCard(
                  item: mtgLossItem,
                  persona: UserPersona.investor,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify headers
      expect(find.text('ACQUIRED'), findsNWidgets(2));
      expect(find.text('LIVE TMV'), findsNWidgets(2));

      // Verify profit item values: Acquired $20.00, TMV $50.00, Delta +150.0% (+$30.00)
      expect(find.text('\$20.00'), findsOneWidget);
      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text('+150.0% (+\$30.00)'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);

      final profitText = tester.widget<Text>(find.text('+150.0% (+\$30.00)'));
      expect(profitText.style?.color, AppColors.accentEmerald);

      // Verify loss item values: Acquired $10.00, TMV $6.00, Delta -40.0% (-$8.00 for qty 2)
      expect(find.text('\$10.00'), findsOneWidget);
      expect(find.text('\$6.00'), findsOneWidget);
      expect(find.text('-40.0% (-\$8.00)'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);

      final lossText = tester.widget<Text>(find.text('-40.0% (-\$8.00)'));
      expect(lossText.style?.color, AppColors.accentRose);
    });

    testWidgets(
        'Player Mode displays mana cost, P/T, keyword chips, and completely hides financial deltas',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VaultItemCard(
                  item: mtgCombatItem,
                  persona: UserPersona.player,
                ),
                VaultItemCard(
                  item: mtgPlaneswalkerItem,
                  persona: UserPersona.player,
                ),
              ],
            ),
          ),
        ),
      );

      // 1. Verify Mana Cost badges
      expect(find.text('{G}{W}{U}{B}'), findsOneWidget);
      expect(find.text('{2}{U}{U}'), findsOneWidget);

      // 2. Verify Power / Toughness badge
      expect(find.text('⚔️ 4 / 🛡️ 4'), findsOneWidget);

      // 3. Verify Loyalty badge
      expect(find.text('Loyalty: 3'), findsOneWidget);

      // 4. Verify Keyword Chips
      expect(find.text('Flying'), findsOneWidget);
      expect(find.text('Vigilance'), findsOneWidget);
      expect(find.text('Deathtouch'), findsOneWidget);
      expect(find.text('Lifelink'), findsOneWidget);

      // 5. Verify GAME UTILITY tag
      expect(find.text('GAME UTILITY'), findsNWidgets(2));

      // 6. CRITICAL REGRESSION GUARD: Completely hide financial deltas & gain/loss indicators
      expect(find.text('ACQUIRED'), findsNothing);
      expect(find.text('LIVE TMV'), findsNothing);
      expect(find.text('\$20.00'), findsNothing);
      expect(find.text('\$50.00'), findsNothing);
      expect(find.text('\$80.00'), findsNothing);
      expect(find.text('\$120.00'), findsNothing);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
      expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
      expect(find.textContaining('+150.0%'), findsNothing);
      expect(find.textContaining('(+\$30.00)'), findsNothing);
    });

    testWidgets(
        'VaultItemCard works gracefully without ancestor ProviderScope (defaults to investor)',
        (WidgetTester tester) async {
      // Pump without any ProviderScope or UncontrolledProviderScope
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(item: mtgCombatItem),
          ),
        ),
      );

      // Must not throw FlutterError and must render Investor Mode
      expect(find.text('ACQUIRED'), findsOneWidget);
      expect(find.text('LIVE TMV'), findsOneWidget);
      expect(find.text('\$20.00'), findsOneWidget);
      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text('+150.0% (+\$30.00)'), findsOneWidget);
    });

    testWidgets(
        'VaultItemCard reactively switches layout when userPersonaProvider changes',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemCard(item: mtgCombatItem),
            ),
          ),
        ),
      );

      // Initially Investor Mode
      expect(find.text('ACQUIRED'), findsOneWidget);
      expect(find.text('⚔️ 4 / 🛡️ 4'), findsNothing);

      // Switch to Player Mode
      container.read(userPersonaProvider.notifier).state = UserPersona.player;
      await tester.pumpAndSettle();

      // Now Player Mode
      expect(find.text('ACQUIRED'), findsNothing);
      expect(find.text('⚔️ 4 / 🛡️ 4'), findsOneWidget);
      expect(find.text('Flying'), findsOneWidget);

      // Switch back to Investor Mode
      container.read(userPersonaProvider.notifier).state = UserPersona.investor;
      await tester.pumpAndSettle();

      // Restored Investor Mode
      expect(find.text('ACQUIRED'), findsOneWidget);
      expect(find.text('⚔️ 4 / 🛡️ 4'), findsNothing);
    });
  });
}

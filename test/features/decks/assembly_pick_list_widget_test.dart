import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/assembly_models.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';
import 'package:countr/features/decks/presentation/widgets/assembly_pick_list_dialog.dart';

void main() {
  DeckAssemblyPlan createMockPlan({bool hasDeficit = true}) {
    final solRing = AssemblyPickItem(
      dviId: 'dvi-1',
      vaultItemId: 'item-1',
      cardName: 'Sol Ring',
      setCode: 'C21',
      boardZone: BoardZone.mainboard,
      requiredQuantity: 1,
      availableQuantity: 1,
      pullQuantity: 1,
      deficitQuantity: 0,
      locationName: 'Binder Alpha',
    );

    final demonicTutor = AssemblyPickItem(
      dviId: 'dvi-2',
      vaultItemId: 'item-2',
      cardName: 'Demonic Tutor',
      setCode: 'UMA',
      boardZone: BoardZone.mainboard,
      requiredQuantity: 1,
      availableQuantity: 1,
      pullQuantity: 1,
      deficitQuantity: 0,
      locationName: 'Binder Alpha',
    );

    final manaCrypt = AssemblyPickItem(
      dviId: 'dvi-3',
      vaultItemId: 'item-3',
      cardName: 'Mana Crypt',
      setCode: '2XM',
      boardZone: BoardZone.mainboard,
      requiredQuantity: 1,
      availableQuantity: 0,
      pullQuantity: 0,
      deficitQuantity: hasDeficit ? 1 : 0,
      locationName: 'Unsorted Vault',
    );

    final items = [solRing, demonicTutor, if (hasDeficit) manaCrypt];
    final itemsByLocation = {
      'Binder Alpha': [solRing, demonicTutor],
    };
    final deficitItems = hasDeficit ? [manaCrypt] : <AssemblyPickItem>[];

    return DeckAssemblyPlan(
      deckId: 'deck-123',
      deckName: 'Urza Commander Deck',
      items: items,
      itemsByLocation: itemsByLocation,
      deficitItems: deficitItems,
    );
  }

  Widget createSubject({
    required DeckAssemblyPlan plan,
    VoidCallback? onRegisterConfirmed,
    VoidCallback? onUnregistered,
  }) {
    final mockDeck = Deck(
      id: plan.deckId,
      name: plan.deckName,
      format: 'Commander',
      wins: 0,
      losses: 0,
      draws: 0,
      createdAt: DateTime.now(),
      tcgDomain: 'mtg',
      isRegistered: false,
      isAssembled: false,
      isCompetitive: false, isDeleted: false,
    );

    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AssemblyPickListDialog(
                  deck: mockDeck,
                  precomputedPlan: plan,
                  onRegistrationChanged: (registered) {
                    if (registered) {
                      onRegisterConfirmed?.call();
                    } else {
                      onUnregistered?.call();
                    }
                  },
                ),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  group('AssemblyPickListDialog Widget Tests', () {
    testWidgets('Renders on narrow screen (320px) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final plan = createMockPlan();
      await tester.pumpWidget(createSubject(plan: plan));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      if (err != null) {
        debugPrint('TEST_EXCEPTION: $err');
      }
      expect(err, isNull);
      expect(find.text('Deck Assembly Pick-List'), findsOneWidget);
      expect(find.text('Urza Commander Deck'), findsOneWidget);
    });

    testWidgets('Displays metrics, checklist items, and supports Check All toggle', (tester) async {
      final plan = createMockPlan();
      await tester.pumpWidget(createSubject(plan: plan));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify metrics summary
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Deficit'), findsOneWidget);
      expect(find.text('Pulled'), findsOneWidget);

      // Verify binder location header
      expect(find.text('Binder Alpha'), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('Demonic Tutor'), findsOneWidget);

      // Tap Check All for Binder Alpha
      final checkAllFinder = find.byKey(const Key('check_all_Binder Alpha'));
      expect(checkAllFinder, findsOneWidget);
      await tester.tap(checkAllFinder);
      await tester.pumpAndSettle();

      // Verify items are now pulled
      expect(plan.itemsByLocation['Binder Alpha']!.every((i) => i.isPulled), isTrue);
    });

    testWidgets('Warns user with deficit amber banner and prompts proxy confirmation', (tester) async {
      bool registerCalled = false;
      final plan = createMockPlan(hasDeficit: true);

      await tester.pumpWidget(createSubject(
        plan: plan,
        onRegisterConfirmed: () => registerCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify amber deficit warning banner is displayed
      expect(find.text('1 Card Deficit'), findsOneWidget);
      expect(find.text('Mana Crypt (1x missing)'), findsOneWidget);

      // Tap Register Deck button
      final registerButton = find.byKey(const Key('assembly_register_deck_button'));
      expect(registerButton, findsOneWidget);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears
      expect(find.text('Missing Cards Fallback'), findsOneWidget);
      expect(find.textContaining('Register with 1 Proxies'), findsOneWidget);

      // Confirm proxy registration
      final confirmProxyButton = find.byKey(const Key('confirm_register_with_proxies_button'));
      expect(confirmProxyButton, findsOneWidget);
      await tester.tap(confirmProxyButton);
      await tester.pumpAndSettle();

      expect(registerCalled, isTrue);
    });
  });
}

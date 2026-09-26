import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/widgets/deck_gear_section.dart';

void main() {
  testWidgets('DeckGearSection renders inputs and toggles token checklist items', (tester) async {
    const deckId = 'test-deck-1';
    final cardItem = VaultItem(
      id: 'v1',
      name: 'Smothering Tithe',
      setOrSeries: 'RNA',
      imageUrl: '',
      quantity: 1,
      collectionType: 'mtg',
      acquiredPrice: 10,
      acquiredDate: DateTime.now(),
      lastPriceUpdate: DateTime.now(),
      currentMarketPrice: 20,
      isGraded: false,
      condition: 'NM',
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      dynamicData: '{"oracle_text": "Whenever an opponent draws a card, that player may pay {2}. If the player doesn\'t, you create a Treasure token."}',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeckGearSection(
                deckId: deckId,
                deckItems: [cardItem],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify sleeve and box inputs exist
    expect(find.byKey(const Key('deck_gear_sleeve_brand_input')), findsOneWidget);
    expect(find.byKey(const Key('deck_gear_sleeve_color_input')), findsOneWidget);
    expect(find.byKey(const Key('deck_gear_box_model_input')), findsOneWidget);

    // Verify auto-generated token checklist contains 'Treasure'
    expect(find.text('Treasure'), findsOneWidget);
    final checkboxFinder = find.byKey(const Key('token_checklist_item_Treasure'));
    expect(checkboxFinder, findsOneWidget);

    // Toggle checklist checkbox
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    // Verify item is checked (packed counter updates to 1/1)
    expect(find.text('1/1 Packed'), findsOneWidget);
  });
}

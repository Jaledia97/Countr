import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/database/app_database.dart';
import '../../deck_test_helpers.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/decks/presentation/widgets/deck_gear_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final testDeck = createTestDeck(
    id: 'deck-edgar-markov',
    name: 'Edgar Markov Aristocrats',
    format: 'MTG Commander',
    createdAt: DateTime(2023, 1, 1),
    wins: 10,
    losses: 4,
    draws: 0,
  );

  Widget createSubject({required Deck deck}) {
    final mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
        deckItemsProvider(deck.id).overrideWith(
          (ref) => Stream.value(MockDeckData.getDeckItems(deck.id)),
        ),
      ],
      child: MaterialApp(
        home: DeckBuilderScreen(deck: deck),
      ),
    );
  }

  group('DeckBuilderScreen Card Tile Tap & CardDetailSheet Deck Scope Tests', () {
    testWidgets('tapping card tile launches CardDetailSheet with deck scope and deck gear', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Verify card tile is visible in the deck
      final cardFinder = find.text('Edgar Markov');
      expect(cardFinder, findsOneWidget);

      // CardDetailSheet is not open yet
      expect(find.byType(CardDetailSheet), findsNothing);

      // Tap on the card tile to expand, then tap Full Details
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Details'));
      await tester.pumpAndSettle();

      // CardDetailSheet should now be presented
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.byKey(const Key('card_detail_segmented_control')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_tab_details')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_tab_values')), findsOneWidget);

      // Drag up on the sheet to reveal DeckGearSection
      await tester.drag(find.byType(PageView), const Offset(0, -1000), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify deck scope renders DeckGearSection
      expect(find.byType(DeckGearSection), findsOneWidget);
      expect(find.byKey(const Key('deck_gear_sleeve_brand_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_gear_box_model_input')), findsOneWidget);

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      expect(find.text('Market Valuation'), findsOneWidget);

      // Close the bottom sheet
      final closeButton = find.byTooltip('Close');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Verify bottom sheet is dismissed
      expect(find.byType(CardDetailSheet), findsNothing);
      expect(find.text('Edgar Markov'), findsOneWidget);
    });
  });
}

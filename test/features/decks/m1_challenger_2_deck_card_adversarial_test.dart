import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/domain/models/my_decks_search_result.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_deck_card.dart';

DeckSummary _createSummary({
  required String id,
  required String name,
  String format = 'MTG Commander',
  String tcgDomain = 'mtg',
  bool isRegistered = false,
  bool isCompetitive = false,
  String? commanderArtCrop,
  String? commanderImageUrl,
  String? commanderName,
  List<String> colorIdentity = const ['U', 'B', 'R'],
  int cardCount = 100,
  int targetCardCount = 100,
  double completeness = 1.0,
  String assemblyStatus = 'Assembled',
}) {
  final deck = Deck(
    id: id,
    name: name,
    format: format,
    wins: 0,
    losses: 0,
    draws: 0,
    createdAt: DateTime.now(),
    tcgDomain: tcgDomain,
    isRegistered: isRegistered,
    isAssembled: isRegistered,
    isCompetitive: isCompetitive,
    isCloned: false,
    isDeleted: false,
  );

  return DeckSummary(
    id: id,
    name: name,
    format: format,
    tcgDomain: tcgDomain,
    isRegistered: isRegistered,
    isCompetitive: isCompetitive,
    createdAt: deck.createdAt,
    commanderArtCrop: commanderArtCrop,
    commanderImageUrl: commanderImageUrl,
    commanderName: commanderName,
    colorIdentity: colorIdentity,
    cardCount: cardCount,
    targetCardCount: targetCardCount,
    completeness: completeness,
    assemblyStatus: assemblyStatus,
    deck: deck,
  );
}

Widget _wrap(
  Widget child, {
  double width = 400,
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Challenger M1.2: Adversarial Interaction & Responsiveness Verification', () {
    // =========================================================================
    // GROUP 1: Interaction Invariants & Gesture Disjointness
    // =========================================================================
    group('1. Interaction Invariants & Gesture Disjointness', () {
      testWidgets('1.1 Tapping deck tile invokes onTap when isSelectionMode is false',
          (tester) async {
        int tapCount = 0;
        final deck = _createSummary(id: 'tap-1', name: 'Atraxa Superfriends');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            isSelectionMode: false,
            onTap: () => tapCount++,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key('deck_item_${deck.id}')));
        await tester.pumpAndSettle();

        expect(tapCount, equals(1));
      });

      testWidgets('1.2 Tapping cover art, title, or status pill invokes card onTap',
          (tester) async {
        int tapCount = 0;
        final deck = _createSummary(
          id: 'tap-regions',
          name: 'Omnath Landfall',
          commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/o/m/omnath.jpg',
        );

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            onTap: () => tapCount++,
          ),
        ));
        await tester.pumpAndSettle();

        // 1. Tap cover art (contained within InkWell)
        await tester.tap(find.byType(CountrCachedImage), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tapCount, equals(1));

        // 2. Tap deck name
        await tester.tap(find.text(deck.name));
        await tester.pumpAndSettle();
        expect(tapCount, equals(2));

        // 3. Tap assembly status pill
        await tester.tap(find.byKey(Key('deck_assembly_status_${deck.id}')));
        await tester.pumpAndSettle();
        expect(tapCount, equals(3));
      });

      testWidgets('1.3 Tapping 3-dot overflow menu opens popup and DOES NOT invoke onTap',
          (tester) async {
        int tapCount = 0;
        final deck = _createSummary(id: 'menu-tap', name: 'Muldrotha Graveyard');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            onTap: () => tapCount++,
          ),
        ));
        await tester.pumpAndSettle();

        final menuFinder = find.byKey(Key('deck_card_menu_${deck.id}'));
        expect(menuFinder, findsOneWidget);

        await tester.tap(menuFinder);
        await tester.pumpAndSettle();

        // Card onTap must NOT have been called
        expect(tapCount, equals(0));

        // Popup menu item must be visible
        expect(find.byKey(Key('deck_menu_share_explore_${deck.id}')), findsOneWidget);
      });

      testWidgets('1.4 Selecting Share to Explore triggers onShareToExplore and not onTap',
          (tester) async {
        int tapCount = 0;
        DeckSummary? sharedDeck;
        final deck = _createSummary(id: 'share-deck', name: 'Krenko Mob Boss');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            onTap: () => tapCount++,
            onShareToExplore: (d) => sharedDeck = d,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key('deck_card_menu_${deck.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key('deck_menu_share_explore_${deck.id}')));
        await tester.pumpAndSettle();

        expect(tapCount, equals(0));
        expect(sharedDeck?.id, equals(deck.id));
      });

      testWidgets('1.5 Gracefully handles null onShareToExplore and null onTap callbacks without throwing',
          (tester) async {
        final deck = _createSummary(id: 'null-callbacks', name: 'Null Callbacks Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            onTap: null,
            onShareToExplore: null,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap card
        await tester.tap(find.byKey(Key('deck_item_${deck.id}')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Open menu and tap share
        await tester.tap(find.byKey(Key('deck_card_menu_${deck.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('deck_menu_share_explore_${deck.id}')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('1.6 Long pressing deck tile invokes onLongPress callback',
          (tester) async {
        int longPressCount = 0;
        final deck = _createSummary(id: 'long-press', name: 'Long Press Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            onLongPress: () => longPressCount++,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.byKey(Key('deck_item_${deck.id}')));
        await tester.pumpAndSettle();

        expect(longPressCount, equals(1));
      });

      testWidgets('1.7 In selection mode, tapping card tile invokes onSelectedChanged and NOT onTap',
          (tester) async {
        int tapCount = 0;
        bool? updatedSelection;
        final deck = _createSummary(id: 'select-mode-tap', name: 'Select Mode Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            isSelectionMode: true,
            isSelected: false,
            onTap: () => tapCount++,
            onSelectedChanged: (val) => updatedSelection = val,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key('deck_item_${deck.id}')));
        await tester.pumpAndSettle();

        expect(tapCount, equals(0));
        expect(updatedSelection, isTrue);
      });

      testWidgets('1.8 In selection mode, tapping checkbox directly toggles selection',
          (tester) async {
        bool? updatedSelection;
        final deck = _createSummary(id: 'checkbox-direct', name: 'Checkbox Direct Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            isSelectionMode: true,
            isSelected: true,
            onSelectedChanged: (val) => updatedSelection = val,
          ),
        ));
        await tester.pumpAndSettle();

        final checkboxFinder = find.byKey(Key('deck_checkbox_${deck.id}'));
        expect(checkboxFinder, findsOneWidget);

        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        expect(updatedSelection, isFalse);
      });

      testWidgets('1.9 In selection mode, tapping 3-dot menu DOES NOT toggle selection',
          (tester) async {
        bool? updatedSelection;
        final deck = _createSummary(id: 'menu-in-select-mode', name: 'Menu Select Mode Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            isSelectionMode: true,
            isSelected: false,
            onSelectedChanged: (val) => updatedSelection = val,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key('deck_card_menu_${deck.id}')));
        await tester.pumpAndSettle();

        expect(updatedSelection, isNull);
        expect(find.byKey(Key('deck_menu_share_explore_${deck.id}')), findsOneWidget);
      });
    });

    // =========================================================================
    // GROUP 2: Key Preservation & Contract Verification
    // =========================================================================
    group('2. Key Preservation & Contract Verification', () {
      testWidgets('2.1 All contract keys exist in standard deck configuration',
          (tester) async {
        final deck = _createSummary(
          id: 'keys-deck-1',
          name: 'Key Verification Deck',
          commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/u/r/urza.jpg',
        );
        final match = MyDeckCardMatch(
          deck: deck,
          matchingCardName: 'Urza\'s Mine',
          cardQuantity: 4,
        );

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            isSelectionMode: true,
            cardMatch: match,
          ),
        ));
        await tester.pumpAndSettle();

        // 1. deck_item_${deck.id}
        expect(find.byKey(Key('deck_item_${deck.id}')), findsOneWidget);

        // 2. deck_checkbox_${deck.id}
        expect(find.byKey(Key('deck_checkbox_${deck.id}')), findsOneWidget);

        // 3. deck_assembly_status_${deck.id}
        expect(find.byKey(Key('deck_assembly_status_${deck.id}')), findsOneWidget);

        // 4. deck_card_match_chip_${deck.id}
        expect(find.byKey(Key('deck_card_match_chip_${deck.id}')), findsOneWidget);

        // 5. deck_card_menu_${deck.id}
        expect(find.byKey(Key('deck_card_menu_${deck.id}')), findsOneWidget);

        // 6. CountrCachedImage cacheKey
        final cachedImageFinder = find.byType(CountrCachedImage);
        expect(cachedImageFinder, findsOneWidget);
        final CountrCachedImage img = tester.widget<CountrCachedImage>(cachedImageFinder);
        expect(img.cacheKey, equals('deck_cover_${deck.id}'));
      });

      testWidgets('2.2 deck_checkbox is absent when isSelectionMode is false',
          (tester) async {
        final deck = _createSummary(id: 'no-select-mode', name: 'No Select Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(deck: deck, isSelectionMode: false),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('deck_checkbox_${deck.id}')), findsNothing);
      });

      testWidgets('2.3 deck_card_match_chip is absent when cardMatch is null',
          (tester) async {
        final deck = _createSummary(id: 'no-match-chip', name: 'No Match Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(deck: deck, cardMatch: null),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('deck_card_match_chip_${deck.id}')), findsNothing);
      });
    });

    // =========================================================================
    // GROUP 3: Narrow Viewport (300px & 320px) Stress & Extreme Text Scaling (1.5x, 2.0x)
    // =========================================================================
    group('3. Narrow Viewport (300px & 320px) Stress & Extreme Text Scaling', () {
      final stressDeck = _createSummary(
        id: 'stress-narrow',
        name: 'The Ur-Dragon Dragon Tribal Commander Supreme Mega Ramp Value Explosion Extra Extra Words',
        format: 'Custom Highlander Tournament Rules 2026',
        colorIdentity: ['W', 'U', 'B', 'R', 'G'],
        cardCount: 9999,
        targetCardCount: 9999,
        assemblyStatus: 'Assembled',
      );
      final stressMatch = MyDeckCardMatch(
        deck: stressDeck,
        matchingCardName: 'Scion of the Ur-Dragon Legendary Dragon Avatar',
        cardQuantity: 99,
      );

      testWidgets('3.1 300px width at 1.0x text scale with all stress elements -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(
              deck: stressDeck,
              cardMatch: stressMatch,
            ),
            width: 300,
            textScale: 1.0,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
        expect(find.byKey(Key('deck_item_${stressDeck.id}')), findsOneWidget);
        expect(find.byKey(Key('deck_assembly_status_${stressDeck.id}')), findsOneWidget);
        expect(find.byKey(Key('deck_card_match_chip_${stressDeck.id}')), findsOneWidget);
      });

      testWidgets('3.2 300px width at 1.5x text scale with all stress elements -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(
              deck: stressDeck,
              cardMatch: stressMatch,
            ),
            width: 300,
            textScale: 1.5,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
      });

      testWidgets('3.3 300px width at 2.0x extreme text scale with all stress elements -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(
              deck: stressDeck,
              cardMatch: stressMatch,
            ),
            width: 300,
            textScale: 2.0,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
      });

      testWidgets('3.4 300px width at 2.0x text scale WITH selection mode active (Checkbox) -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(
              deck: stressDeck,
              isSelectionMode: true,
              isSelected: true,
              cardMatch: stressMatch,
            ),
            width: 300,
            textScale: 2.0,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
        expect(find.byKey(Key('deck_checkbox_${stressDeck.id}')), findsOneWidget);
      });

      testWidgets('3.5 320px viewport at 1.5x text scale with all stress elements -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(
              deck: stressDeck,
              cardMatch: stressMatch,
            ),
            width: 320,
            textScale: 1.5,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
      });

      testWidgets('3.6 320px viewport at 2.0x extreme text scale with all stress elements -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(
              deck: stressDeck,
              cardMatch: stressMatch,
            ),
            width: 320,
            textScale: 2.0,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
      });

      testWidgets('3.7 Touch targets: At 300px + 2.0x text scale, 3-dot menu and checkbox remain tappable',
          (tester) async {
        bool? selected;
        final deck = _createSummary(id: 'touch-target', name: 'Touch Target Deck');

        await tester.pumpWidget(_wrap(
          MyDeckCard(
            deck: deck,
            isSelectionMode: true,
            isSelected: false,
            onSelectedChanged: (val) => selected = val,
          ),
          width: 300,
          textScale: 2.0,
        ));
        await tester.pumpAndSettle();

        // Checkbox tap
        await tester.tap(find.byKey(Key('deck_checkbox_${deck.id}')));
        await tester.pumpAndSettle();
        expect(selected, isTrue);

        // Menu tap
        await tester.tap(find.byKey(Key('deck_card_menu_${deck.id}')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('deck_menu_share_explore_${deck.id}')), findsOneWidget);
      });
    });

    // =========================================================================
    // GROUP 4: Wide Viewports (600px & 800px) Layout Stress & Text Scaling
    // =========================================================================
    group('4. Wide Viewports (600px & 800px) Layout Stress & Text Scaling', () {
      final wideDeck = _createSummary(
        id: 'wide-deck',
        name: 'Golos, Tireless Pilgrim Maze\'s End Guildgates Landfall Infinite Deck',
        format: 'Commander / EDH',
        colorIdentity: ['W', 'U', 'B', 'R', 'G'],
      );

      testWidgets('4.1 600px viewport at 1.0x text scale -> zero RenderFlex overflow and full width title',
          (tester) async {
        await tester.pumpWidget(_wrap(
          MyDeckCard(deck: wideDeck),
          width: 600,
          textScale: 1.0,
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('deck_item_${wideDeck.id}')), findsOneWidget);
        final titleFinder = find.text(wideDeck.name);
        expect(titleFinder, findsOneWidget);

        final RenderBox titleBox = tester.renderObject(titleFinder);
        // On 600px container: 600 - padding (28) - art (44) - spacing (14) - menu (~24) - spacing (4) ~ 486px
        expect(titleBox.size.width, greaterThan(450));
      });

      testWidgets('4.2 600px viewport at 2.0x text scale -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(deck: wideDeck),
            width: 600,
            textScale: 2.0,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
      });

      testWidgets('4.3 800px desktop viewport at 2.0x text scale -> zero RenderFlex overflow',
          (tester) async {
        final caughtErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrap(
            MyDeckCard(deck: wideDeck),
            width: 800,
            textScale: 2.0,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = originalOnError;
        }

        final overflows = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
        expect(overflows, isEmpty);
      });
    });

    // =========================================================================
    // GROUP 5: Visual Invariants, Percentage Absence & Unknown Status Fallback
    // =========================================================================
    group('5. Visual Invariants, Percentage Absence & Fallbacks', () {
      testWidgets('5.1 Percentage pill is absent across 0%, 25%, 50%, 75%, 100% completeness',
          (tester) async {
        final decks = [
          _createSummary(id: 'd-0', name: 'Deck Zero', completeness: 0.0, cardCount: 0),
          _createSummary(id: 'd-25', name: 'Deck Quarter', completeness: 0.25, cardCount: 25),
          _createSummary(id: 'd-50', name: 'Deck Half', completeness: 0.50, cardCount: 50),
          _createSummary(id: 'd-75', name: 'Deck Three Quarters', completeness: 0.75, cardCount: 75),
          _createSummary(id: 'd-100', name: 'Deck Full Complete', completeness: 1.0, cardCount: 100),
        ];

        await tester.pumpWidget(_wrap(
          SingleChildScrollView(
            child: Column(
              children: decks.map((d) => MyDeckCard(deck: d)).toList(),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('0%'), findsNothing);
        expect(find.text('25%'), findsNothing);
        expect(find.text('50%'), findsNothing);
        expect(find.text('75%'), findsNothing);
        expect(find.text('100%'), findsNothing);
        expect(find.textContaining('%'), findsNothing);
      });

      testWidgets('5.2 Unknown or custom assembly status falls back gracefully to Draft styling without exception',
          (tester) async {
        final customStatusDeck = _createSummary(
          id: 'custom-status',
          name: 'Custom Status Deck',
          assemblyStatus: 'CustomNonStandardStatus',
        );

        await tester.pumpWidget(_wrap(MyDeckCard(deck: customStatusDeck)));
        await tester.pumpAndSettle();

        final statusPillFinder = find.byKey(Key('deck_assembly_status_${customStatusDeck.id}'));
        expect(statusPillFinder, findsOneWidget);
        expect(find.descendant(of: statusPillFinder, matching: find.text('CustomNonStandardStatus')), findsOneWidget);
        expect(find.descendant(of: statusPillFinder, matching: find.byIcon(Icons.edit_note_rounded)), findsOneWidget);
      });

      testWidgets('5.3 Empty and null artwork strings render fallback box with 44x56 and style_rounded icon',
          (tester) async {
        final emptyArtDeck = _createSummary(
          id: 'empty-art',
          name: 'Empty Art Deck',
          commanderArtCrop: '',
          commanderImageUrl: '',
        );

        await tester.pumpWidget(_wrap(MyDeckCard(deck: emptyArtDeck)));
        await tester.pumpAndSettle();

        expect(find.byType(CountrCachedImage), findsNothing);
        expect(find.byIcon(Icons.style_rounded), findsOneWidget);

        final RenderBox fallbackBox = tester.renderObject(
          find.ancestor(of: find.byIcon(Icons.style_rounded), matching: find.byType(Container)).first,
        );
        expect(fallbackBox.size.width, equals(44.0));
        expect(fallbackBox.size.height, equals(56.0));
      });
    });
  });
}

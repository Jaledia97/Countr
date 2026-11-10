import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/domain/models/my_decks_search_result.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_deck_card.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';

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

Widget _wrap(Widget child, {double width = 400}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('MyDeckCard Layout & Refactor Verification', () {
    testWidgets('1. Percentage pill (100% / completeness) is completely removed',
        (tester) async {
      final assembledDeck = _createSummary(
        id: 'deck-1',
        name: 'Urza Thopter Combo',
        isRegistered: true,
        completeness: 1.0,
        assemblyStatus: 'Assembled',
      );
      final draftDeck = _createSummary(
        id: 'deck-2',
        name: 'Incomplete Draft Deck',
        isRegistered: false,
        completeness: 0.75,
        cardCount: 75,
        targetCardCount: 100,
        assemblyStatus: 'Draft',
      );

      await tester.pumpWidget(_wrap(Column(
        children: [
          MyDeckCard(deck: assembledDeck),
          MyDeckCard(deck: draftDeck),
        ],
      )));
      await tester.pumpAndSettle();

      // Assert neither 100% nor 75% badges appear
      expect(find.text('100%'), findsNothing);
      expect(find.text('75%'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('2. Deck name has full horizontal width with maxLines: 2 and ellipsis',
        (tester) async {
      final longNamedDeck = _createSummary(
        id: 'deck-long-name',
        name: 'Omnath, Locus of Creation Four-Color Landfall Value Extravaganza with Extra Land Drops',
      );

      await tester.pumpWidget(_wrap(MyDeckCard(deck: longNamedDeck)));
      await tester.pumpAndSettle();

      final titleFinder = find.text(longNamedDeck.name);
      expect(titleFinder, findsOneWidget);

      final Text titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.maxLines, equals(2));
      expect(titleWidget.overflow, equals(TextOverflow.ellipsis));
      expect(titleWidget.style?.fontSize, equals(14));

      // Title should NOT be inside a Row with the status pill
      final parentRowOfTitle = find.ancestor(of: titleFinder, matching: find.byType(Row));
      final statusPill = find.byKey(Key('deck_assembly_status_${longNamedDeck.id}'));
      // The status pill should not be a descendant of any row that contains the title directly
      for (final rowElement in parentRowOfTitle.evaluate()) {
        final rowWidget = rowElement.widget as Row;
        // Make sure this row is the top-level card row, NOT a title+status row
        final hasStatusPill = find.descendant(
          of: find.byWidget(rowWidget),
          matching: statusPill,
        ).evaluate().isNotEmpty;
        if (hasStatusPill) {
          // If a row has both, it must be the main card outer row (Row with card art, content, menu)
          expect(find.descendant(of: find.byWidget(rowWidget), matching: find.byType(PopupMenuButton<String>)), findsOneWidget);
        }
      }
    });

    testWidgets('3. Relocated assembly status badge is in secondary metadata row inside Flexible FittedBox',
        (tester) async {
      final deck = _createSummary(
        id: 'deck-status-row',
        name: 'Gisa and Geralf Zombies',
        format: 'MTG Commander',
        cardCount: 100,
        targetCardCount: 100,
        assemblyStatus: 'Assembled',
      );

      await tester.pumpWidget(_wrap(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      final statusPillKey = Key('deck_assembly_status_${deck.id}');
      final statusFinder = find.byKey(statusPillKey);
      expect(statusFinder, findsOneWidget);

      // Verify wrapped in FittedBox with scaleDown and centerLeft
      final fittedBoxFinder = find.ancestor(of: statusFinder, matching: find.byType(FittedBox));
      expect(fittedBoxFinder, findsOneWidget);
      final FittedBox fittedBox = tester.widget<FittedBox>(fittedBoxFinder);
      expect(fittedBox.fit, equals(BoxFit.scaleDown));
      expect(fittedBox.alignment, equals(Alignment.centerLeft));

      // Verify wrapped in Flexible
      final flexibleFinder = find.ancestor(of: fittedBoxFinder, matching: find.byType(Flexible));
      expect(flexibleFinder, findsOneWidget);

      // Verify co-located in the same Row with format and card count
      final secondaryRowFinder = find.ancestor(of: flexibleFinder, matching: find.byType(Row)).first;
      expect(secondaryRowFinder, findsOneWidget);

      final formatCardCountFinder = find.descendant(
        of: secondaryRowFinder,
        matching: find.text('MTG Commander • 100/100'),
      );
      expect(formatCardCountFinder, findsOneWidget);
    });

    testWidgets('4. Assembly status badges render correct labels, icons, and keys for all statuses',
        (tester) async {
      final assembledDeck = _createSummary(
        id: 'assembled-1',
        name: 'Assembled Deck',
        isRegistered: true,
        assemblyStatus: 'Assembled',
      );
      final readyDeck = _createSummary(
        id: 'ready-1',
        name: 'Ready Deck',
        isRegistered: false,
        cardCount: 100,
        targetCardCount: 100,
        assemblyStatus: 'Ready',
      );
      final draftDeck = _createSummary(
        id: 'draft-1',
        name: 'Draft Deck',
        isRegistered: false,
        cardCount: 60,
        targetCardCount: 100,
        assemblyStatus: 'Draft',
      );

      await tester.pumpWidget(_wrap(Column(
        children: [
          MyDeckCard(deck: assembledDeck),
          MyDeckCard(deck: readyDeck),
          MyDeckCard(deck: draftDeck),
        ],
      )));
      await tester.pumpAndSettle();

      // Assembled
      final assembledKeyFinder = find.byKey(const Key('deck_assembly_status_assembled-1'));
      expect(assembledKeyFinder, findsOneWidget);
      expect(find.descendant(of: assembledKeyFinder, matching: find.text('Assembled')), findsOneWidget);
      expect(find.descendant(of: assembledKeyFinder, matching: find.byIcon(Icons.verified_rounded)), findsOneWidget);

      // Ready
      final readyKeyFinder = find.byKey(const Key('deck_assembly_status_ready-1'));
      expect(readyKeyFinder, findsOneWidget);
      expect(find.descendant(of: readyKeyFinder, matching: find.text('Ready')), findsOneWidget);
      expect(find.descendant(of: readyKeyFinder, matching: find.byIcon(Icons.check_circle_outline_rounded)), findsOneWidget);

      // Draft
      final draftKeyFinder = find.byKey(const Key('deck_assembly_status_draft-1'));
      expect(draftKeyFinder, findsOneWidget);
      expect(find.descendant(of: draftKeyFinder, matching: find.text('Draft')), findsOneWidget);
      expect(find.descendant(of: draftKeyFinder, matching: find.byIcon(Icons.edit_note_rounded)), findsOneWidget);
    });

    testWidgets('5. CountrCachedImage passes explicit width: 44, height: 56, and fit: BoxFit.cover',
        (tester) async {
      final deckWithArt = _createSummary(
        id: 'art-deck-1',
        name: 'Atraxa Superfriends',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/a/t/atraxa.jpg',
        commanderName: 'Atraxa, Praetors\' Voice',
      );

      await tester.pumpWidget(_wrap(MyDeckCard(deck: deckWithArt)));
      await tester.pumpAndSettle();

      final cachedImageFinder = find.byType(CountrCachedImage);
      expect(cachedImageFinder, findsOneWidget);

      final CountrCachedImage imageWidget = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(imageWidget.width, equals(44.0));
      expect(imageWidget.height, equals(56.0));
      expect(imageWidget.fit, equals(BoxFit.cover));
      expect(imageWidget.cacheKey, equals('deck_cover_art-deck-1'));
      expect(imageWidget.imageUrl, equals(deckWithArt.commanderArtCrop));
    });

    testWidgets('6. Fallback art container renders with 44x56 when art URL is null or empty',
        (tester) async {
      final deckNoArt = _createSummary(
        id: 'no-art-deck',
        name: 'Deck Without Art',
        commanderArtCrop: null,
        commanderImageUrl: null,
      );

      await tester.pumpWidget(_wrap(MyDeckCard(deck: deckNoArt)));
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsNothing);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);

      final fallbackContainerFinder = find.ancestor(
        of: find.byIcon(Icons.style_rounded),
        matching: find.byType(Container),
      ).first;
      final Container container = tester.widget<Container>(fallbackContainerFinder);
      expect(container.constraints?.hasTightWidth == true || container.margin == null, isTrue);
      final RenderBox renderBox = tester.renderObject(fallbackContainerFinder);
      expect(renderBox.size.width, equals(44.0));
      expect(renderBox.size.height, equals(56.0));
    });

    testWidgets('7. Search match chip (deck_card_match_chip) renders cleanly when cardMatch is provided',
        (tester) async {
      final deck = _createSummary(
        id: 'deck-search-match',
        name: 'Esper Control',
      );
      final match = MyDeckCardMatch(
        deck: deck,
        matchingCardName: 'Force of Will',
        cardQuantity: 4,
      );

      await tester.pumpWidget(_wrap(MyDeckCard(
        deck: deck,
        cardMatch: match,
      )));
      await tester.pumpAndSettle();

      final matchChipFinder = find.byKey(Key('deck_card_match_chip_${deck.id}'));
      expect(matchChipFinder, findsOneWidget);
      expect(find.text('Contains: Force of Will (x4)'), findsOneWidget);
      expect(find.byIcon(Icons.style_outlined), findsOneWidget);
    });

    testWidgets('8. Multi-selection mode displays checkbox and responds to selection changes',
        (tester) async {
      final deck = _createSummary(
        id: 'deck-selection',
        name: 'Goblins Aggro',
      );
      bool? selectedState;

      await tester.pumpWidget(_wrap(MyDeckCard(
        deck: deck,
        isSelectionMode: true,
        isSelected: false,
        onSelectedChanged: (val) => selectedState = val,
      )));
      await tester.pumpAndSettle();

      final checkboxFinder = find.byKey(Key('deck_checkbox_${deck.id}'));
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      expect(selectedState, isTrue);
    });

    testWidgets('9. Overflow popup menu triggers Share to Explore callback',
        (tester) async {
      final deck = _createSummary(
        id: 'deck-menu',
        name: 'Merfolk Tribal',
      );
      DeckSummary? sharedDeck;

      await tester.pumpWidget(_wrap(MyDeckCard(
        deck: deck,
        onShareToExplore: (d) => sharedDeck = d,
      )));
      await tester.pumpAndSettle();

      final menuButton = find.byKey(Key('deck_card_menu_${deck.id}'));
      expect(menuButton, findsOneWidget);

      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      final shareOption = find.byKey(Key('deck_menu_share_explore_${deck.id}'));
      expect(shareOption, findsOneWidget);

      await tester.tap(shareOption);
      await tester.pumpAndSettle();
      expect(sharedDeck?.id, equals('deck-menu'));
    });

    testWidgets('10. MTG color pips render via ManaCostBar', (tester) async {
      final deck = _createSummary(
        id: 'deck-pips',
        name: 'Jund Sacrifice',
        colorIdentity: ['B', 'R', 'G'],
      );

      await tester.pumpWidget(_wrap(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      expect(find.byType(ManaCostBar), findsOneWidget);
    });

    testWidgets('11. Zero RenderFlex overflow on narrow 300px constraint with extreme text',
        (tester) async {
      final extremeDeck = _createSummary(
        id: 'deck-extreme',
        name: 'Extremely Long Deck Name Designed to Stress Test Ellipsis and Wrapping Across Narrow Viewports',
        format: 'Extremely Detailed Custom Tournament Rules MTG Commander Format',
        cardCount: 250,
        targetCardCount: 250,
        assemblyStatus: 'Assembled',
      );
      final match = MyDeckCardMatch(
        deck: extremeDeck,
        matchingCardName: 'Supercalifragilisticexpialidocious Ultra Rare Card Name',
        cardQuantity: 99,
      );

      await tester.pumpWidget(_wrap(
        MyDeckCard(
          deck: extremeDeck,
          cardMatch: match,
        ),
        width: 300,
      ));
      await tester.pumpAndSettle();

      // No exception thrown and widgets render
      expect(find.byKey(Key('deck_item_${extremeDeck.id}')), findsOneWidget);
      expect(find.byKey(Key('deck_assembly_status_${extremeDeck.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

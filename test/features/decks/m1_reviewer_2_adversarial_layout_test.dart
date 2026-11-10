import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/domain/models/my_decks_search_result.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_deck_card.dart';

DeckSummary _buildAdversarialDeck({
  required String id,
  required String name,
  String format = 'MTG Commander',
  String tcgDomain = 'mtg',
  bool isRegistered = false,
  bool isCompetitive = false,
  String? commanderArtCrop,
  String? commanderImageUrl,
  String? commanderName,
  List<String> colorIdentity = const ['W', 'U', 'B', 'R', 'G'],
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

Widget _wrapSubject(
  Widget child, {
  double width = 360,
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: MediaQuery(
          data: const MediaQueryData().copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: SizedBox(
            width: width,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Adversarial Critic Stress Tests: MyDeckCard (R1)', () {
    testWidgets('ADV-1: Ultra-narrow viewport (240px) with long unbroken text and custom format produces zero overflow',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-narrow-1',
        name: 'SupercalifragilisticexpialidociousLongUnbrokenWordWithoutSpacesDeckNameThatCouldForceHorizontalBlowout',
        format: 'CustomHyperExtendedLongFormatNameWithDozensOfCharacters',
        cardCount: 150,
        targetCardCount: 150,
        assemblyStatus: 'Assembled',
      );

      final caughtErrors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(_wrapSubject(MyDeckCard(deck: deck), width: 240));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed')), isEmpty);
      expect(find.byKey(Key('deck_item_${deck.id}')), findsOneWidget);
      expect(find.byKey(Key('deck_assembly_status_${deck.id}')), findsOneWidget);
    });

    testWidgets('ADV-2: Extreme text scaling (2.5x font scale) on 300px constraint produces zero overflow',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-scale-2',
        name: 'Massive Font Scale Test Deck Name Spanning Multiple Lines',
        format: 'Commander Format',
        cardCount: 100,
        targetCardCount: 100,
        assemblyStatus: 'Ready',
      );

      final caughtErrors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(_wrapSubject(
          MyDeckCard(deck: deck),
          width: 300,
          textScale: 2.5,
        ));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed')), isEmpty);
      expect(find.byKey(Key('deck_item_${deck.id}')), findsOneWidget);
    });

    testWidgets('ADV-3: Missing cover art, null commanderName, and empty imageUrl falls back cleanly to 44x56 fallback art',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-no-art-3',
        name: 'Orphan Deck Without Art',
        commanderArtCrop: null,
        commanderImageUrl: null,
        commanderName: null,
      );

      await tester.pumpWidget(_wrapSubject(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsNothing);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);

      final containerFinder = find.ancestor(
        of: find.byIcon(Icons.style_rounded),
        matching: find.byType(Container),
      ).first;
      final renderBox = tester.renderObject(containerFinder) as RenderBox;
      expect(renderBox.size.width, equals(44.0));
      expect(renderBox.size.height, equals(56.0));
    });

    testWidgets('ADV-4: Empty string URLs ("") fall back gracefully to fallback art',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-empty-art-4',
        name: 'Empty String Art Deck',
        commanderArtCrop: '',
        commanderImageUrl: '',
      );

      await tester.pumpWidget(_wrapSubject(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsNothing);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);
    });

    testWidgets('ADV-5: Unknown/arbitrary assemblyStatus safely defaults to draft badge without crash',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-unknown-status-5',
        name: 'Unknown Status Deck',
        assemblyStatus: 'UnderConstruction',
      );

      await tester.pumpWidget(_wrapSubject(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      final statusKey = Key('deck_assembly_status_${deck.id}');
      expect(find.byKey(statusKey), findsOneWidget);
      expect(find.descendant(of: find.byKey(statusKey), matching: find.text('UnderConstruction')), findsOneWidget);
      expect(find.descendant(of: find.byKey(statusKey), matching: find.byIcon(Icons.edit_note_rounded)), findsOneWidget);
    });

    testWidgets('ADV-6: Selection mode + long search match chip + narrow screen (280px) produces zero overflow',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-select-chip-6',
        name: 'Selection & Match Search Deck',
        assemblyStatus: 'Draft',
      );
      final match = MyDeckCardMatch(
        deck: deck,
        matchingCardName: 'Extremely Long Card Name That Might Wrap Or Overflow Inside The Match Chip',
        cardQuantity: 4,
      );

      final caughtErrors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(_wrapSubject(
          MyDeckCard(
            deck: deck,
            isSelectionMode: true,
            isSelected: true,
            cardMatch: match,
          ),
          width: 280,
        ));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed')), isEmpty);
      expect(find.byKey(Key('deck_checkbox_${deck.id}')), findsOneWidget);
      expect(find.byKey(Key('deck_card_match_chip_${deck.id}')), findsOneWidget);
    });

    testWidgets('ADV-7: Integrity check: No percentage pill or "%" text exists in the widget tree',
        (tester) async {
      final decks = [
        _buildAdversarialDeck(id: 'deck-100', name: 'Deck 100', completeness: 1.0, isRegistered: true),
        _buildAdversarialDeck(id: 'deck-50', name: 'Deck 50', completeness: 0.5, isRegistered: false),
        _buildAdversarialDeck(id: 'deck-0', name: 'Deck 0', completeness: 0.0, isRegistered: false),
      ];

      await tester.pumpWidget(_wrapSubject(
        Column(children: decks.map((d) => MyDeckCard(deck: d)).toList()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsNothing);
      expect(find.text('50%'), findsNothing);
      expect(find.text('0%'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('ADV-8: Title row strictly allocates full width without competing with status badge in same row',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-title-8',
        name: 'Full Width Title Deck',
      );

      await tester.pumpWidget(_wrapSubject(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      final titleFinder = find.text('Full Width Title Deck');
      expect(titleFinder, findsOneWidget);

      final statusFinder = find.byKey(Key('deck_assembly_status_${deck.id}'));
      expect(statusFinder, findsOneWidget);

      final titleRenderBox = tester.renderObject(titleFinder) as RenderBox;
      final statusRenderBox = tester.renderObject(statusFinder) as RenderBox;

      // Status pill MUST be vertically below title (not on the same horizontal row)
      final titleBottom = titleRenderBox.localToGlobal(Offset.zero).dy + titleRenderBox.size.height;
      final statusTop = statusRenderBox.localToGlobal(Offset.zero).dy;
      expect(statusTop, greaterThanOrEqualTo(titleBottom),
          reason: 'Status badge must be positioned below the title in the secondary row');
    });

    testWidgets('ADV-9: Cover art thumbnail passes exact 44x56 and BoxFit.cover to CountrCachedImage',
        (tester) async {
      final deck = _buildAdversarialDeck(
        id: 'adv-cover-9',
        name: 'Cover Sizing Deck',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/u/r/urza.jpg',
      );

      await tester.pumpWidget(_wrapSubject(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      final cachedImageFinder = find.byType(CountrCachedImage);
      expect(cachedImageFinder, findsOneWidget);
      final CountrCachedImage imageWidget = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(imageWidget.width, equals(44.0));
      expect(imageWidget.height, equals(56.0));
      expect(imageWidget.fit, equals(BoxFit.cover));
    });
  });
}

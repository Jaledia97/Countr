import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/domain/models/my_decks_search_result.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_deck_card.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';

DeckSummary _buildDeck({
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

Widget _wrapInTestApp(
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
  group('Milestone 1 Challenger Suite: MyDeckCard Empirical Stress Tests', () {
    // ------------------------------------------------------------------------
    // Group 1: Percentage Pill Deletion Invariant Across Continuous Parameter Space
    // ------------------------------------------------------------------------
    testWidgets('CHAL-1.1: Parameter sweep across completeness and registration states reveals zero percentage text',
        (tester) async {
      final testCases = <Map<String, dynamic>>[
        {'completeness': 0.0, 'isRegistered': false, 'status': 'Draft'},
        {'completeness': 0.0001, 'isRegistered': false, 'status': 'Draft'},
        {'completeness': 0.42, 'isRegistered': false, 'status': 'Draft'},
        {'completeness': 0.50, 'isRegistered': false, 'status': 'Ready'},
        {'completeness': 0.75, 'isRegistered': false, 'status': 'Ready'},
        {'completeness': 0.9999, 'isRegistered': false, 'status': 'Ready'},
        {'completeness': 1.0, 'isRegistered': false, 'status': 'Ready'},
        {'completeness': 1.0, 'isRegistered': true, 'status': 'Assembled'},
        {'completeness': 1.5, 'isRegistered': true, 'status': 'Assembled'},
        {'completeness': -0.5, 'isRegistered': false, 'status': 'Draft'},
        {'completeness': double.nan, 'isRegistered': false, 'status': 'Draft'},
        {'completeness': double.infinity, 'isRegistered': true, 'status': 'Assembled'},
      ];

      for (int i = 0; i < testCases.length; i++) {
        final tc = testCases[i];
        final deck = _buildDeck(
          id: 'chal-pill-$i',
          name: 'Deck $i (${tc['completeness']})',
          completeness: (tc['completeness'] as num).toDouble(),
          isRegistered: tc['isRegistered'] as bool,
          assemblyStatus: tc['status'] as String,
        );

        await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck)));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('%'),
          findsNothing,
          reason: 'Deck $i with completeness ${tc['completeness']} should have zero % text in widget tree',
        );
      }
    });

    testWidgets('CHAL-1.2: Menu and title row have no residual percentage pill containers',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-pill-structure',
        name: 'Urza High Lord',
        completeness: 1.0,
        isRegistered: true,
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsNothing);
      expect(find.text('100 %'), findsNothing);

      // Verify that between the Expanded Column and PopupMenuButton there is only a SizedBox(width: 4)
      final columnFinder = find.byType(Column).first;
      final popupMenuFinder = find.byType(PopupMenuButton<String>);
      expect(columnFinder, findsOneWidget);
      expect(popupMenuFinder, findsOneWidget);

      final rowOfCardFinder = find.ancestor(of: popupMenuFinder, matching: find.byType(Row)).first;
      final Row rowWidget = tester.widget<Row>(rowOfCardFinder);
      expect(rowWidget.children.length, equals(5)); // Art, SizedBox, Expanded(Column), SizedBox, PopupMenuButton
    });

    // ------------------------------------------------------------------------
    // Group 2: Title Row Full Width, Wrapping & Truncation Invariants
    // ------------------------------------------------------------------------
    testWidgets('CHAL-2.1: Very long deck title wraps up to 2 lines with ellipsis and font size 14',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-title-wrap',
        name: 'Nicol Bolas, the Ravager / Nicol Bolas, the Arisen Grixis Reanimator Control and Superfriends Value Engine',
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck), width: 340));
      await tester.pumpAndSettle();

      final titleFinder = find.text(deck.name);
      expect(titleFinder, findsOneWidget);

      final Text titleText = tester.widget<Text>(titleFinder);
      expect(titleText.maxLines, equals(2));
      expect(titleText.overflow, equals(TextOverflow.ellipsis));
      expect(titleText.style?.fontSize, equals(14));

      // Assert title's immediate parent is the Column, NOT a Row
      final parentOfTitle = find.ancestor(of: titleFinder, matching: find.byType(Column)).first;
      expect(parentOfTitle, findsOneWidget);
    });

    testWidgets('CHAL-2.2: Extreme unbroken word without spaces does not cause RenderFlex overflow',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-title-unbroken',
        name: 'SupercalifragilisticexpialidociousUnbrokenStringWithoutAnyWhitespaceCharactersThatCouldInduceOverflow',
      );

      final caughtErrors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck), width: 250));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed')), isEmpty);
      expect(find.text(deck.name), findsOneWidget);
    });

    testWidgets('CHAL-2.3: Multiline title with explicit newlines renders cleanly within 2 maxLines',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-title-newlines',
        name: 'Line 1 Title\nLine 2 Title\nLine 3 Title\nLine 4 Title',
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      final titleFinder = find.text(deck.name);
      expect(titleFinder, findsOneWidget);
      final Text text = tester.widget<Text>(titleFinder);
      expect(text.maxLines, equals(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CHAL-2.4: Unicode, CJK, and emoji deck titles render without overflow',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-title-unicode',
        name: '🔥💀⚡️ 全知全能のドラゴン / Nicol Bolas 🏆 ドラゴン・コンボ 🐉✨',
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck), width: 280));
      await tester.pumpAndSettle();

      expect(find.text(deck.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ------------------------------------------------------------------------
    // Group 3: Relocated Status Badge & Secondary Row Overflow Stress Harness
    // ------------------------------------------------------------------------
    testWidgets('CHAL-3.1: Viewport squeeze stress harness from 360px down to 180px produces ZERO overflows',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-squeeze',
        name: 'Commander Deck With Extensive Title Squeeze Test',
        format: 'Custom High-Power Casual Commander Ruleset',
        cardCount: 200,
        targetCardCount: 200,
        assemblyStatus: 'Assembled',
      );

      final widths = [360.0, 320.0, 300.0, 280.0, 260.0, 240.0, 220.0, 200.0, 180.0];

      for (final w in widths) {
        final caughtErrors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck), width: w));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = oldOnError;
        }

        expect(
          caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed')),
          isEmpty,
          reason: 'Viewport width $w produced RenderFlex overflow',
        );
        expect(find.byKey(Key('deck_assembly_status_${deck.id}')), findsOneWidget);
      }
    });

    testWidgets('CHAL-3.2: Aggressive font scaling up to 3.0x on narrow 280px constraint produces ZERO overflows',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-font-scale',
        name: 'Font Scaling Stress Deck Name',
        format: 'MTG Commander',
        cardCount: 100,
        targetCardCount: 100,
        assemblyStatus: 'Ready',
      );

      final scales = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0];

      for (final s in scales) {
        final caughtErrors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) => caughtErrors.add(details);

        try {
          await tester.pumpWidget(_wrapInTestApp(
            MyDeckCard(deck: deck),
            width: 280,
            textScale: s,
          ));
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = oldOnError;
        }

        expect(
          caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed')),
          isEmpty,
          reason: 'Font scale $s produced RenderFlex overflow on 280px width',
        );
      }
    });

    testWidgets('CHAL-3.3: Selection Mode + Match Chip + 5-Color Mana Pips on narrow 260px produces ZERO overflows',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-full-density',
        name: 'Jodah, Archmage Eternal All-Card Super Density Test',
        format: 'MTG Commander',
        colorIdentity: ['W', 'U', 'B', 'R', 'G'],
        assemblyStatus: 'Draft',
      );
      final match = MyDeckCardMatch(
        deck: deck,
        matchingCardName: 'Omniscience With Enormous Name Extravaganza',
        cardQuantity: 4,
      );

      final caughtErrors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(_wrapInTestApp(
          MyDeckCard(
            deck: deck,
            isSelectionMode: true,
            isSelected: true,
            cardMatch: match,
          ),
          width: 260,
        ));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed')), isEmpty);
      expect(find.byKey(Key('deck_checkbox_${deck.id}')), findsOneWidget);
      expect(find.byKey(Key('deck_card_match_chip_${deck.id}')), findsOneWidget);
      expect(find.byType(ManaCostBar), findsOneWidget);
    });

    testWidgets('CHAL-3.4: Spatial verification: Status badge is physically in secondary row below title and beside format',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-spatial-test',
        name: 'Spatial Deck',
        format: 'MTG Commander',
        cardCount: 100,
        targetCardCount: 100,
        assemblyStatus: 'Assembled',
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck), width: 380));
      await tester.pumpAndSettle();

      final titleBox = tester.renderObject(find.text('Spatial Deck')) as RenderBox;
      final statusBox = tester.renderObject(find.byKey(Key('deck_assembly_status_${deck.id}'))) as RenderBox;
      final formatBox = tester.renderObject(find.text('MTG Commander • 100/100')) as RenderBox;

      final titlePos = titleBox.localToGlobal(Offset.zero);
      final statusPos = statusBox.localToGlobal(Offset.zero);
      final formatPos = formatBox.localToGlobal(Offset.zero);

      // Status must be vertically below title
      expect(statusPos.dy, greaterThanOrEqualTo(titlePos.dy + titleBox.size.height - 1.0));

      // Both status and format must share the exact same secondary Row
      final statusRow = find.ancestor(
        of: find.byKey(Key('deck_assembly_status_${deck.id}')),
        matching: find.byType(Row),
      ).first;
      final formatInRowFinder = find.descendant(
        of: statusRow,
        matching: find.text('MTG Commander • 100/100'),
      );
      expect(formatInRowFinder, findsOneWidget);

      final rowBox = tester.renderObject(statusRow) as RenderBox;
      final rowPos = rowBox.localToGlobal(Offset.zero);
      expect(rowPos.dy, greaterThanOrEqualTo(titlePos.dy + titleBox.size.height - 1.0));
      expect(statusPos.dy, greaterThanOrEqualTo(rowPos.dy - 1.0));
      expect(formatPos.dy, greaterThanOrEqualTo(rowPos.dy - 1.0));

      // Status must be horizontally to the right of format text
      expect(statusPos.dx, greaterThan(formatPos.dx));
    });

    // ------------------------------------------------------------------------
    // Group 4: Thumbnail Dimensions & Aspect Fit Invariants
    // ------------------------------------------------------------------------
    testWidgets('CHAL-4.1: CountrCachedImage receives explicit width 44, height 56, and BoxFit.cover with crop art',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-art-crop',
        name: 'Urza Deck',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/u/r/urza.jpg',
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      final imageFinder = find.byType(CountrCachedImage);
      expect(imageFinder, findsOneWidget);

      final CountrCachedImage image = tester.widget<CountrCachedImage>(imageFinder);
      expect(image.width, equals(44.0));
      expect(image.height, equals(56.0));
      expect(image.fit, equals(BoxFit.cover));
      expect(image.imageUrl, equals(deck.commanderArtCrop));
    });

    testWidgets('CHAL-4.2: Fallback art container renders with exactly 44x56 when art URL is null',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-null-art',
        name: 'No Art Deck',
        commanderArtCrop: null,
        commanderImageUrl: null,
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsNothing);
      final iconFinder = find.byIcon(Icons.style_rounded);
      expect(iconFinder, findsOneWidget);

      final containerFinder = find.ancestor(of: iconFinder, matching: find.byType(Container)).first;
      final RenderBox box = tester.renderObject(containerFinder) as RenderBox;
      expect(box.size.width, equals(44.0));
      expect(box.size.height, equals(56.0));
    });

    testWidgets('CHAL-4.3: Whitespace art URL does not crash or throw unhandled exceptions',
        (tester) async {
      final deck = _buildDeck(
        id: 'chal-space-art',
        name: 'Whitespace Art Deck',
        commanderArtCrop: '   ',
        commanderImageUrl: null,
      );

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(deck: deck)));
      await tester.pumpAndSettle();

      // Should render without throwing an unhandled exception
      expect(tester.takeException(), isNull);
    });

    // ------------------------------------------------------------------------
    // Group 5: Interactive Behaviors & Callback Integrity
    // ------------------------------------------------------------------------
    testWidgets('CHAL-5.1: Card tap and long press trigger respective callbacks in non-selection mode',
        (tester) async {
      final deck = _buildDeck(id: 'chal-actions', name: 'Actions Deck');
      bool tapped = false;
      bool longPressed = false;

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(
        deck: deck,
        onTap: () => tapped = true,
        onLongPress: () => longPressed = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('deck_item_${deck.id}')));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      await tester.longPress(find.byKey(Key('deck_item_${deck.id}')));
      await tester.pumpAndSettle();
      expect(longPressed, isTrue);
    });

    testWidgets('CHAL-5.2: In selection mode, tapping anywhere on card invokes onSelectedChanged',
        (tester) async {
      final deck = _buildDeck(id: 'chal-select-card', name: 'Select Card Deck');
      bool? selectedState;

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(
        deck: deck,
        isSelectionMode: true,
        isSelected: false,
        onSelectedChanged: (val) => selectedState = val,
      )));
      await tester.pumpAndSettle();

      // Tap card body
      await tester.tap(find.byKey(Key('deck_item_${deck.id}')));
      await tester.pumpAndSettle();
      expect(selectedState, isTrue);
    });

    testWidgets('CHAL-5.3: 3-dot overflow menu opens and invokes onShareToExplore with deck payload',
        (tester) async {
      final deck = _buildDeck(id: 'chal-share-deck', name: 'Share Deck');
      DeckSummary? sharedDeck;

      await tester.pumpWidget(_wrapInTestApp(MyDeckCard(
        deck: deck,
        onShareToExplore: (d) => sharedDeck = d,
      )));
      await tester.pumpAndSettle();

      final menuFinder = find.byKey(Key('deck_card_menu_${deck.id}'));
      expect(menuFinder, findsOneWidget);

      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      final shareOption = find.byKey(Key('deck_menu_share_explore_${deck.id}'));
      expect(shareOption, findsOneWidget);

      await tester.tap(shareOption);
      await tester.pumpAndSettle();

      expect(sharedDeck, isNotNull);
      expect(sharedDeck!.id, equals(deck.id));
    });
  });
}

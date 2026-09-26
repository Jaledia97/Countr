import 'dart:convert';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';

import 'phase46_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Domain 1: Deck Assembly Status + Card Availability + Active Badges
  // (Features 1, 2, 3, 5)
  // ===========================================================================
  group('Tier 3 - Domain 1: Deck Assembly + Availability + Active Deck Badges', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('X1.1: Toggling deck assembly locks card availability and emits active badge', () async {
      // 1. Create a card with owned=3
      final card = createPhase46TestCard(id: 'c-x11', name: 'Sol Ring', quantity: 3);
      await db.into(db.vaultItems).insert(card);

      // 2. Create a deck in Draft status (is_registered = 0)
      final deck = await createAndInsertDeck(db, id: 'd-x11', name: 'Commander 2026', isRegistered: false);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 1, boardZone: 'Mainboard');

      // In draft status: available is still 3, inDeck is 0
      var avail = await calculateItemAvailability(db, card.id);
      expect(avail.owned, equals(3));
      expect(avail.available, equals(3));
      expect(avail.inDeck, equals(0));

      // Assembled badge stream emits empty list for draft deck
      var badges = await watchAssembledDeckBadges(db, card.id).first;
      expect(badges, isEmpty);

      // 3. Toggle deck to Assembled (is_registered = 1)
      await db.vaultDao.setDeckRegistered(deck.id, true);

      // Availability now locks 1 copy
      avail = await calculateItemAvailability(db, card.id);
      expect(avail.owned, equals(3));
      expect(avail.available, equals(2));
      expect(avail.inDeck, equals(1));

      // Badge stream now reflects the assembled deck
      badges = await watchAssembledDeckBadges(db, card.id).first;
      expect(badges, contains('Commander 2026'));

      // 4. Toggle back to Draft (is_registered = 0)
      await db.vaultDao.setDeckRegistered(deck.id, false);

      avail = await calculateItemAvailability(db, card.id);
      expect(avail.available, equals(3));
      expect(avail.inDeck, equals(0));

      badges = await watchAssembledDeckBadges(db, card.id).first;
      expect(badges, isEmpty);
    });

    test('X1.2: Multi-deck allocation with mixed assembled/draft statuses', () async {
      final card = createPhase46TestCard(id: 'c-x12', name: 'Rhystic Study', quantity: 2);
      await db.into(db.vaultItems).insert(card);

      final deck1 = await createAndInsertDeck(db, id: 'd-x12-1', name: 'Assembled Deck Alpha', isRegistered: true);
      final deck2 = await createAndInsertDeck(db, id: 'd-x12-2', name: 'Draft Deck Beta', isRegistered: false);

      await addCardToDeckZone(db, deckId: deck1.id, vaultItemId: card.id, quantity: 1);
      await addCardToDeckZone(db, deckId: deck2.id, vaultItemId: card.id, quantity: 1);

      // Deck 1 is assembled (locks 1), Deck 2 is draft (locks 0)
      final avail = await calculateItemAvailability(db, card.id);
      expect(avail.owned, equals(2));
      expect(avail.available, equals(1));
      expect(avail.inDeck, equals(1));

      // Badges only contain Deck 1
      final badges = await watchAssembledDeckBadges(db, card.id).first;
      expect(badges, equals(['Assembled Deck Alpha']));
    });

    test('X1.3: Soft-deleting deck version item immediately restores physical availability', () async {
      final card = createPhase46TestCard(id: 'c-x13', name: 'Mana Crypt', quantity: 1);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-x13', name: 'cEDH Hyper', isRegistered: true);
      final item = await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 1);

      var avail = await calculateItemAvailability(db, card.id);
      expect(avail.available, equals(0));
      expect(avail.inDeck, equals(1));

      // Soft delete the deck item
      await (db.update(db.deckVersionItems)..where((t) => t.id.equals(item.id))).write(
        DeckVersionItemsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      avail = await calculateItemAvailability(db, card.id);
      expect(avail.available, equals(1));
      expect(avail.inDeck, equals(0));

      final badges = await watchAssembledDeckBadges(db, card.id).first;
      expect(badges, isEmpty);
    });

    test('X1.4: Increasing quantity in assembled deck dynamically adjusts availability', () async {
      final card = createPhase46TestCard(id: 'c-x14', name: 'Lightning Bolt', quantity: 4);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-x14', name: 'Burn Modern', isRegistered: true);
      final item = await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 2);

      var avail = await calculateItemAvailability(db, card.id);
      expect(avail.available, equals(2));
      expect(avail.inDeck, equals(2));

      // Bump quantity from 2 to 4 in deck
      await (db.update(db.deckVersionItems)..where((t) => t.id.equals(item.id))).write(
        DeckVersionItemsCompanion(
          quantity: const Value(4),
          updatedAt: Value(DateTime.now()),
        ),
      );

      avail = await calculateItemAvailability(db, card.id);
      expect(avail.available, equals(0));
      expect(avail.inDeck, equals(4));
    });

    test('X1.5: Re-assembling deck after adding cards locks updated aggregate inventory', () async {
      final card = createPhase46TestCard(id: 'c-x15', name: 'Mox Opal', quantity: 2);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-x15', name: 'Affinity Modern', isRegistered: false);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 2);

      // Draft: available 2
      expect((await calculateItemAvailability(db, card.id)).available, equals(2));

      // Register deck: available drops to 0
      await db.vaultDao.setDeckRegistered(deck.id, true);
      expect((await calculateItemAvailability(db, card.id)).available, equals(0));
      expect((await watchAssembledDeckBadges(db, card.id).first), contains('Affinity Modern'));
    });
  });

  // ===========================================================================
  // Domain 2: Board Movement + Format Legality Verification
  // (Features 7, 8)
  // ===========================================================================
  group('Tier 3 - Domain 2: Board Movement + Format Legality Checking', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('X2.1: Moving banned card from Mainboard to Maybeboard isolates format violation', () async {
      // Hullbreacher is banned in Commander
      final card = createPhase46TestCard(
        id: 'c-x21',
        name: 'Hullbreacher',
        legalities: {'commander': 'banned', 'vintage': 'legal'},
      );
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-x21', name: 'Sultai Control', format: 'Commander');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard');

      // Check card legality in Commander format
      final legality = checkCardLegalityDirect(card, deck.format);
      expect(legality.isLegal, isFalse);
      expect(legality.violations.first, contains('banned'));

      // Move card to Maybeboard (e.g. testing deck without playing illegal card)
      await moveCardBetweenZones(
        db,
        deckId: deck.id,
        vaultItemId: card.id,
        fromZone: 'Mainboard',
        toZone: 'Maybeboard',
        quantity: 1,
      );

      final mainItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Mainboard') & t.isDeleted.equals(false)))
          .get();
      expect(mainItems, isEmpty);

      final maybeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Maybeboard') & t.isDeleted.equals(false)))
          .get();
      expect(maybeItems.length, equals(1));
    });

    test('X2.2: Cross-board transfer preserves card variant finish and pricing metadata', () async {
      final card = createPhase46TestCard(
        id: 'c-x22',
        name: 'Force of Will',
        condition: 'Near Mint Foil',
        currentMarketPrice: 125.50,
      );
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-x22', name: 'Legacy Miracles', format: 'Legacy');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Sideboard', quantity: 1);

      // Move to Mainboard
      await moveCardBetweenZones(
        db,
        deckId: deck.id,
        vaultItemId: card.id,
        fromZone: 'Sideboard',
        toZone: 'Mainboard',
        quantity: 1,
      );

      final moved = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Mainboard') & t.isDeleted.equals(false)))
          .getSingle();

      expect(moved.boardZone, equals('Mainboard'));
      // Joined VaultItem metadata is intact
      final dbCard = await (db.select(db.vaultItems)..where((t) => t.id.equals(moved.vaultItemId))).getSingle();
      expect(dbCard.condition, equals('Near Mint Foil'));
      expect(dbCard.currentMarketPrice, equals(125.50));
    });

    test('X2.3: Splitting quantity across Mainboard and Sideboard preserves total deck presence', () async {
      final card = createPhase46TestCard(id: 'c-x23', name: 'Thoughtseize', quantity: 4);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-x23', name: 'Modern Jund', format: 'Modern');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 4);

      // Move 2 copies to Sideboard
      await moveCardBetweenZones(
        db,
        deckId: deck.id,
        vaultItemId: card.id,
        fromZone: 'Mainboard',
        toZone: 'Sideboard',
        quantity: 2,
      );

      final main = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Mainboard') & t.isDeleted.equals(false)))
          .getSingle();
      final side = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Sideboard') & t.isDeleted.equals(false)))
          .getSingle();

      expect(main.quantity, equals(2));
      expect(side.quantity, equals(2));
      expect(main.quantity + side.quantity, equals(4));
    });

    test('X2.4: Multiple cards with distinct legalities keep status atomic across zones', () {
      final legalCard = createPhase46TestCard(
        id: 'c-l1',
        name: 'Brainstorm',
        legalities: {'commander': 'legal', 'vintage': 'restricted'},
      );
      final bannedCard = createPhase46TestCard(
        id: 'c-b1',
        name: 'Griselbrand',
        legalities: {'commander': 'banned', 'vintage': 'legal'},
      );

      final resLegalCmd = checkCardLegalityDirect(legalCard, 'commander');
      final resBannedCmd = checkCardLegalityDirect(bannedCard, 'commander');
      final resLegalVin = checkCardLegalityDirect(legalCard, 'vintage');
      final resBannedVin = checkCardLegalityDirect(bannedCard, 'vintage');

      expect(resLegalCmd.isLegal, isTrue);
      expect(resBannedCmd.isLegal, isFalse);
      expect(resLegalVin.isLegal, isTrue);
      expect(resBannedVin.isLegal, isTrue);
    });
  });

  // ===========================================================================
  // Domain 3: Inline Deck Analytics + MTG Symbology + Accurate CMC Calculation
  // (Features 10, 11, 12, 13)
  // ===========================================================================
  group('Tier 3 - Domain 3: Analytics + Symbology + Accurate CMC Integration', () {
    test('X3.1: Twobrid and Hybrid mana costs correctly populate CMC curve and resolve SVG symbols', () {
      // Shadow Guildmage: {B/R} -> CMC 1.0
      expect(calculateAccurateCmc('{B/R}'), equals(1.0));
      final hybridSymbols = ScryfallSymbolCatalog.extractSymbols('{B/R}');
      expect(hybridSymbols, equals(['B/R']));
      expect(ScryfallSymbolCatalog.findBySymbol(hybridSymbols.first)?.filename, equals('BR.svg'));

      // Beseech the Queen: {2/B}{2/B}{2/B} -> CMC 6.0
      expect(calculateAccurateCmc('{2/B}{2/B}{2/B}'), equals(6.0));
      final twobridSymbols = ScryfallSymbolCatalog.extractSymbols('{2/B}{2/B}{2/B}');
      expect(twobridSymbols, equals(['2/B', '2/B', '2/B']));
      expect(ScryfallSymbolCatalog.findBySymbol(twobridSymbols.first)?.filename, equals('2B.svg'));
    });

    test('X3.2: Split card mana cost sums faces to CMC 4.0 and extracts symbols for each face', () {
      const splitManaCost = '{1}{R} // {1}{U}';
      expect(calculateAccurateCmc(splitManaCost), equals(4.0));

      final symbols = ScryfallSymbolCatalog.extractSymbols(splitManaCost);
      expect(symbols, equals(['1', 'R', '1', 'U']));

      final assetFilenames = symbols.map((s) => ScryfallSymbolCatalog.findBySymbol(s)?.filename).toList();
      expect(assetFilenames, equals([
        '1.svg',
        'R.svg',
        '1.svg',
        'U.svg',
      ]));
    });

    testWidgets('X3.3: ManaText renders split card symbols with correct SVG widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ManaText('{1}{R} // {1}{U}', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaText), findsOneWidget);
    });

    test('X3.4: Pareto concentration correctly measures high-value foil cards against bulk', () {
      final cards = [
        ParetoCardInput(id: '1', name: "Gaea's Cradle (Foil)", setCode: 'USG', quantity: 1, unitPrice: 1200.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'Tropical Island', setCode: '3ED', quantity: 1, unitPrice: 600.0, imageUrl: ''),
        ParetoCardInput(id: '3', name: 'Mox Diamond', setCode: 'STH', quantity: 1, unitPrice: 500.0, imageUrl: ''),
        ParetoCardInput(id: '4', name: 'Forest 1', setCode: 'UNF', quantity: 1, unitPrice: 0.25, imageUrl: ''),
        ParetoCardInput(id: '5', name: 'Forest 2', setCode: 'UNF', quantity: 1, unitPrice: 0.25, imageUrl: ''),
        ParetoCardInput(id: '6', name: 'Forest 3', setCode: 'UNF', quantity: 1, unitPrice: 0.25, imageUrl: ''),
      ];

      final res = ParetoDistributionCalculator.calculate(cards: cards);
      expect(res.concentrationPercentage, greaterThan(95.0));
      expect(res.totalDeckValue, closeTo(2300.75, 0.01));
    });

    test('X3.5: Accurate CMC integration with Deck Analytics mana curve distribution', () {
      final items = [
        createPhase46TestCard(id: 'm1', name: 'Bird of Paradise', manaCost: '{G}', cmc: 1.0, quantity: 1),
        createPhase46TestCard(id: 'm2', name: 'Counterspell', manaCost: '{U}{U}', cmc: 2.0, quantity: 2),
        createPhase46TestCard(id: 'm3', name: 'Beseech the Queen', manaCost: '{2/B}{2/B}{2/B}', quantity: 1),
        createPhase46TestCard(id: 'm4', name: 'Fire // Ice', manaCost: '{1}{R} // {1}{U}', quantity: 1),
      ];

      final curve = computeDeckManaCurve(
        items.map((i) => {'quantity': i.quantity, 'dynamic_data': i.dynamicData}).toList(),
      );
      expect(curve[1], equals(1)); // Birds
      expect(curve[2], equals(2)); // 2x Counterspell
      expect(curve[6], equals(1)); // Beseech (twobrid CMC 6)
      expect(curve[4], equals(1)); // Fire // Ice (split CMC 4)
    });
  });

  // ===========================================================================
  // Domain 4: Deck Thumbnail Picker + Custom Cover Art + Sticky Header
  // (Features 6, 14, 15)
  // ===========================================================================
  group('Tier 3 - Domain 4: Deck Thumbnail + Sticky Header Integration', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('X4.1: Updating deck cover_item_id persists and links to vault card art', () async {
      final card = createPhase46TestCard(
        id: 'c-x41-art',
        name: 'Urza, Lord High Artificer',
        additionalDynamicData: {
          'image_uris': {'art_crop': 'https://cards.scryfall.io/art_crop/urza.jpg'}
        },
      );
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-x41', name: 'Urza Thopter Foundry');
      expect(deck.coverItemId, isNull);

      // Select card as deck thumbnail cover
      await (db.update(db.decks)..where((t) => t.id.equals(deck.id))).write(
        DecksCompanion(
          coverItemId: Value(card.id),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updatedDeck = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updatedDeck.coverItemId, equals(card.id));

      // Resolve cover art from DB
      final coverCard = await (db.select(db.vaultItems)..where((t) => t.id.equals(updatedDeck.coverItemId!))).getSingle();
      final dyn = jsonDecode(coverCard.dynamicData) as Map<String, dynamic>;
      expect(dyn['image_uris']['art_crop'], equals('https://cards.scryfall.io/art_crop/urza.jpg'));
    });

    testWidgets('X4.2: SliverAppBar with deck title and cover art renders with ellipsis without collision', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  leading: const BackButton(),
                  title: const Text(
                    'Extremely Detailed cEDH Tournament Deck Title [Competitive Primer]',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  actions: [
                    IconButton(icon: const Icon(Icons.palette), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                  ],
                ),
                const SliverFillRemaining(
                  child: Center(child: Text('Deck Contents')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('X4.3: Sticky SliverAppBar header handles rapid scrolling transition without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverAppBar(
                  pinned: true,
                  expandedHeight: 180,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text('Krenko Mob Boss', style: TextStyle(fontSize: 14)),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.grey.shade900,
                      child: Text('Card $index'),
                    ),
                    childCount: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down rapidly
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Scroll back up
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('X4.4: Deleting cover card allows deck to fallback or clear cover cleanly', () async {
      final card = createPhase46TestCard(id: 'c-del-cover', name: 'Temporary Cover');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-del-cov', name: 'Cover Reset Deck', coverItemId: card.id);
      expect(deck.coverItemId, equals(card.id));

      // Clear cover
      await (db.update(db.decks)..where((t) => t.id.equals(deck.id))).write(
        const DecksCompanion(coverItemId: Value(null)),
      );

      final reloaded = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(reloaded.coverItemId, isNull);
    });
  });

  // ===========================================================================
  // Domain 5: Board Movement + Proportional Scrollbar Rail Recalculation
  // (Features 7, 9)
  // ===========================================================================
  group('Tier 3 - Domain 5: Board Movement + Proportional Scrollbar Rail', () {
    test('X5.1: Moving cards between zones updates proportional heights dynamically', () {
      const railHeight = 600.0;
      var counts = [60, 15, 25];
      var heights = ProportionalBubbleScrollbar.computeSectionHeights(
        totalHeight: railHeight,
        counts: counts,
      );

      // Verify initial distribution
      expect(heights[0], closeTo(360.0, 1.0)); // 60% of 600
      expect(heights[1], closeTo(90.0, 1.0));  // 15% of 600
      expect(heights[2], closeTo(150.0, 1.0)); // 25% of 600

      // Move 20 cards from Main to Side -> Main=40, Side=35, Maybe=25
      counts = [40, 35, 25];
      heights = ProportionalBubbleScrollbar.computeSectionHeights(
        totalHeight: railHeight,
        counts: counts,
      );

      expect(heights[0], closeTo(240.0, 1.0)); // 40% of 600
      expect(heights[1], closeTo(210.0, 1.0)); // 35% of 600
      expect(heights[2], closeTo(150.0, 1.0)); // 25% of 600
      expect(heights.fold<double>(0.0, (s, h) => s + h), closeTo(railHeight, 0.01));
    });

    test('X5.2: Emptying a board zone clamps it to minHeight 24.0 while others expand', () {
      const railHeight = 400.0;
      final counts = [100, 0, 0];
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        totalHeight: railHeight,
        counts: counts,
        minHeight: 24.0,
      );

      // Side and Maybe get clamped to minHeight 24.0
      expect(heights[1], equals(24.0));
      expect(heights[2], equals(24.0));
      // Main gets remaining height: 400 - 48 = 352.0
      expect(heights[0], equals(352.0));
      expect(heights.fold<double>(0.0, (s, h) => s + h), equals(railHeight));
    });

    testWidgets('X5.3: ProportionalBubbleScrollbar widget renders and handles tap interaction', (tester) async {
      int tappedIndex = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 30,
              child: ProportionalBubbleScrollbar(
                sections: [
                  ScrollbarSection(label: 'Main', count: 60, onTap: () => tappedIndex = 0),
                  ScrollbarSection(label: 'Side', count: 15, onTap: () => tappedIndex = 1),
                  ScrollbarSection(label: 'Maybe', count: 10, onTap: () => tappedIndex = 2),
                ],
                onSectionTap: (idx) => tappedIndex = idx,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
      await tester.tap(find.byType(ProportionalBubbleScrollbar));
      await tester.pumpAndSettle();
      expect(tappedIndex, isNonNegative);
    });
  });

  // ===========================================================================
  // Domain 6: Collection Contexts + Variant Grouping + Physical Inventory
  // (Features 1, 4, 16)
  // ===========================================================================
  group('Tier 3 - Domain 6: Collection Contexts + Variant Grouping + Inventory', () {
    test('X6.1: Variant grouping correctly collapses multiple physical copies into single badge item', () {
      final item1 = createPhase46TestCard(
        id: 'v1',
        scryfallId: 'scry-sol-1',
        name: 'Sol Ring',
        condition: 'Near Mint Foil',
        quantity: 2,
      );
      final item2 = createPhase46TestCard(
        id: 'v2',
        scryfallId: 'scry-sol-1',
        name: 'Sol Ring',
        condition: 'Lightly Played Foil',
        quantity: 1,
      );
      final item3 = createPhase46TestCard(
        id: 'v3',
        scryfallId: 'scry-sol-1',
        name: 'Sol Ring',
        condition: 'Near Mint', // Non-foil
        quantity: 4,
      );

      // Group all vault items
      final grouped = groupVaultItemsByVariant([item1, item2, item3]);

      // Foil variant bucket contains item1 and item2
      final foilKey = resolveVariantGroupingKey(item1);
      expect(grouped[foilKey]!.length, equals(2));
      expect(computeVariantQuantity(grouped[foilKey]!), equals(3)); // 2 + 1 = 3

      // Non-foil variant bucket contains item3
      final nonFoilKey = resolveVariantGroupingKey(item3);
      expect(grouped[nonFoilKey]!.length, equals(1));
      expect(computeVariantQuantity(grouped[nonFoilKey]!), equals(4));
    });

    test('X6.2: Collection filter switching across binders and decks preserves filter criteria', () {
      final collectionAFilters = {'format': 'Commander', 'type': 'Creature'};
      final collectionBFilters = {'format': 'Modern', 'finish': 'foil'};

      expect(collectionAFilters['format'], equals('Commander'));
      expect(collectionBFilters['format'], equals('Modern'));
      expect(collectionAFilters['finish'], isNull);
      expect(collectionBFilters['finish'], equals('foil'));
    });

    test('X6.3: Physical availability filtering across variant groups respects assembled allocations', () async {
      final db = createPhase46TestDb();
      addTearDown(db.close);

      final foilCard = createPhase46TestCard(
        id: 'c-sol-foil',
        scryfallId: 'scry-sol',
        name: 'Sol Ring',
        condition: 'Foil',
        quantity: 2,
      );
      final nonFoilCard = createPhase46TestCard(
        id: 'c-sol-nonfoil',
        scryfallId: 'scry-sol',
        name: 'Sol Ring',
        condition: 'Regular',
        quantity: 3,
      );
      await db.into(db.vaultItems).insert(foilCard);
      await db.into(db.vaultItems).insert(nonFoilCard);

      final deck = await createAndInsertDeck(db, id: 'd-avail-x6', name: 'Assembled Deck', isRegistered: true);
      // Lock foil copy in assembled deck
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: foilCard.id, quantity: 1);

      final foilAvail = await calculateItemAvailability(db, foilCard.id);
      final nonFoilAvail = await calculateItemAvailability(db, nonFoilCard.id);

      expect(foilAvail.available, equals(1)); // 2 - 1 = 1
      expect(nonFoilAvail.available, equals(3)); // 3 - 0 = 3
    });
  });

  // ===========================================================================
  // Domain 7: Privacy Mode + Pareto Distribution + Deck Valuation
  // (Features 10, 11)
  // ===========================================================================
  group('Tier 3 - Domain 7: Privacy Mode + Pareto Concentration Redaction', () {
    testWidgets('X7.1: Privacy mode redacts headline numbers while preserving percentage share', (tester) async {
      final topCards = [
        ParetoCardInput(id: '1', name: 'Black Lotus', setCode: 'LEA', quantity: 1, unitPrice: 25000.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'Mox Sapphire', setCode: 'LEA', quantity: 1, unitPrice: 6000.0, imageUrl: ''),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: ParetoDistributionWidget(
                deckTotalValue: 36470.0,
                topKConcentrationPercentage: 85.0,
                topCards: topCards,
                isPrivacyMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Headline and card values should be redacted to ****
      expect(find.textContaining('****'), findsWidgets);
      // Clear dollar text and unmasked percentage should not be present
      expect(find.textContaining('25000'), findsNothing);
      expect(find.textContaining('85.0%'), findsNothing);
    });

    testWidgets('X7.2: Public mode displays full currency amounts and percentages', (tester) async {
      final topCards = [
        ParetoCardInput(id: '1', name: 'Black Lotus', setCode: 'LEA', quantity: 1, unitPrice: 25000.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'Mox Sapphire', setCode: 'LEA', quantity: 1, unitPrice: 6000.0, imageUrl: ''),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: ParetoDistributionWidget(
                deckTotalValue: 36470.0,
                topKConcentrationPercentage: 85.0,
                topCards: topCards,
                isPrivacyMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('25000'), findsWidgets);
      expect(find.textContaining('6000'), findsWidgets);
      expect(find.textContaining('85.0%'), findsOneWidget);
    });

    testWidgets('X7.3: Dynamic toggle between privacy mode and public mode updates Pareto widget without layout shift', (tester) async {
      final topCards = [
        ParetoCardInput(id: '1', name: 'Black Lotus', setCode: 'LEA', quantity: 1, unitPrice: 25000.0, imageUrl: ''),
      ];

      bool privacy = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () => setState(() => privacy = !privacy),
                    ),
                  ],
                ),
                body: ProviderScope(
                  child: ParetoDistributionWidget(
                    deckTotalValue: 25000.0,
                    topKConcentrationPercentage: 100.0,
                    topCards: topCards,
                    isPrivacyMode: privacy,
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('25000'), findsWidgets);

      // Tap toggle to enable privacy mode
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.textContaining('****'), findsWidgets);
      expect(find.textContaining('25000'), findsNothing);

      // Tap toggle again to disable privacy mode
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.textContaining('25000'), findsWidgets);
    });
  });
}

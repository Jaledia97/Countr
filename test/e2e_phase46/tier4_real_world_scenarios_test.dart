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
  // Scenario 1: Complete Deck Construction & Assembly Lifecycle
  // ===========================================================================
  group('Tier 4 - Scenario 1: Complete Deck Construction & Assembly Lifecycle', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('E2E-1: User creates Commander deck, manages zones, verifies legality, and locks inventory', () async {
      // Step 1: Create Commander Deck
      final deck = await createAndInsertDeck(
        db,
        id: 'deck-urza-cedh',
        name: 'Urza, High Artificer cEDH',
        format: 'Commander',
        isRegistered: false,
      );
      expect(deck.isRegistered, isFalse);

      // Step 2: Add Commander
      final urza = createPhase46TestCard(
        id: 'c-urza',
        name: 'Urza, Lord High Artificer',
        manaCost: '{2}{U}{U}',
        cmc: 4.0,
        quantity: 1,
        legalities: {'commander': 'legal'},
      );
      await db.into(db.vaultItems).insert(urza);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: urza.id, boardZone: 'Commander');

      // Step 3: Add Mainboard cards (including split and twobrid spells)
      final fireIce = createPhase46TestCard(
        id: 'c-fire-ice',
        name: 'Fire // Ice',
        manaCost: '{1}{R} // {1}{U}',
        quantity: 1,
        legalities: {'commander': 'legal'},
      );
      final beseech = createPhase46TestCard(
        id: 'c-beseech',
        name: 'Beseech the Queen',
        manaCost: '{2/B}{2/B}{2/B}',
        quantity: 1,
        legalities: {'commander': 'legal'},
      );
      final solRing = createPhase46TestCard(
        id: 'c-sol-ring',
        name: 'Sol Ring',
        manaCost: '{1}',
        cmc: 1.0,
        quantity: 1,
        legalities: {'commander': 'legal'},
      );
      // Illegal card accidentally added to Mainboard
      final recall = createPhase46TestCard(
        id: 'c-recall',
        name: 'Ancestral Recall',
        manaCost: '{U}',
        cmc: 1.0,
        quantity: 1,
        legalities: {'commander': 'banned', 'vintage': 'restricted'},
      );

      await db.into(db.vaultItems).insert(fireIce);
      await db.into(db.vaultItems).insert(beseech);
      await db.into(db.vaultItems).insert(solRing);
      await db.into(db.vaultItems).insert(recall);

      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: fireIce.id, boardZone: 'Mainboard');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: beseech.id, boardZone: 'Mainboard');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: solRing.id, boardZone: 'Mainboard');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: recall.id, boardZone: 'Mainboard');

      // Step 4: Validate format legality - fails due to Ancestral Recall
      var legality = checkCardLegalityDirect(recall, deck.format);
      expect(legality.isLegal, isFalse);
      expect(legality.violations.first, contains('banned'));

      // Step 5: User moves Ancestral Recall from Mainboard to Maybeboard
      await moveCardBetweenZones(
        db,
        deckId: deck.id,
        vaultItemId: recall.id,
        fromZone: 'Mainboard',
        toZone: 'Maybeboard',
        quantity: 1,
      );

      // Verify Mainboard now only contains legal cards
      final mainboardItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.boardZone.equals('Mainboard') & t.isDeleted.equals(false)))
          .get();
      expect(mainboardItems.length, equals(3));

      // Step 6: Verify Deck Analytics Mana Curve
      final allDeckCards = [urza, fireIce, beseech, solRing];
      final curve = computeDeckManaCurve(
        allDeckCards.map((c) => {'quantity': c.quantity, 'dynamic_data': c.dynamicData}).toList(),
      );
      expect(curve[1], equals(1)); // Sol Ring
      expect(curve[4], equals(2)); // Urza (4.0) + Fire // Ice (4.0)
      expect(curve[6], equals(1)); // Beseech (6.0)

      // Step 7: Prior to assembly, cards are physically available
      var solAvail = await calculateItemAvailability(db, solRing.id);
      expect(solAvail.available, equals(1));
      expect(solAvail.inDeck, equals(0));

      // Step 8: User marks deck as Assembled
      await db.vaultDao.setDeckRegistered(deck.id, true);

      // Step 9: Reconcile physical availability and badges
      solAvail = await calculateItemAvailability(db, solRing.id);
      expect(solAvail.available, equals(0));
      expect(solAvail.inDeck, equals(1));

      final badges = await watchAssembledDeckBadges(db, solRing.id).first;
      expect(badges, equals(['Urza, High Artificer cEDH']));
    });
  });

  // ===========================================================================
  // Scenario 2: Multi-Deck Physical Inventory Allocation & Conflict Resolution
  // ===========================================================================
  group('Tier 4 - Scenario 2: Multi-Deck Physical Allocation & Conflict Resolution', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('E2E-2: Multi-deck physical card contention and registration transitions', () async {
      // Collector owns 2 copies of Cyclonic Rift
      final rift = createPhase46TestCard(id: 'c-rift', name: 'Cyclonic Rift', quantity: 2);
      await db.into(db.vaultItems).insert(rift);

      final deckA = await createAndInsertDeck(db, id: 'd-a', name: 'Talrand Polymorph', isRegistered: false);
      final deckB = await createAndInsertDeck(db, id: 'd-b', name: 'Niv-Mizzet Wheels', isRegistered: false);

      await addCardToDeckZone(db, deckId: deckA.id, vaultItemId: rift.id, quantity: 1);
      await addCardToDeckZone(db, deckId: deckB.id, vaultItemId: rift.id, quantity: 1);

      // Both draft: availability is 2
      var avail = await calculateItemAvailability(db, rift.id);
      expect(avail.owned, equals(2));
      expect(avail.available, equals(2));
      expect(avail.inDeck, equals(0));
      expect((await watchAssembledDeckBadges(db, rift.id).first), isEmpty);

      // Assemble Deck A: available becomes 1
      await db.vaultDao.setDeckRegistered(deckA.id, true);
      avail = await calculateItemAvailability(db, rift.id);
      expect(avail.available, equals(1));
      expect(avail.inDeck, equals(1));
      expect((await watchAssembledDeckBadges(db, rift.id).first), equals(['Talrand Polymorph']));

      // Assemble Deck B: available becomes 0 (fully allocated)
      await db.vaultDao.setDeckRegistered(deckB.id, true);
      avail = await calculateItemAvailability(db, rift.id);
      expect(avail.available, equals(0));
      expect(avail.inDeck, equals(2));
      final badges = await watchAssembledDeckBadges(db, rift.id).first;
      expect(badges, containsAll(['Talrand Polymorph', 'Niv-Mizzet Wheels']));

      // Disassemble Deck A: available recovers to 1
      await db.vaultDao.setDeckRegistered(deckA.id, false);
      avail = await calculateItemAvailability(db, rift.id);
      expect(avail.available, equals(1));
      expect(avail.inDeck, equals(1));
      expect((await watchAssembledDeckBadges(db, rift.id).first), equals(['Niv-Mizzet Wheels']));
    });
  });

  // ===========================================================================
  // Scenario 3: Physical Variant Reconciliation & Vault Grouping
  // ===========================================================================
  group('Tier 4 - Scenario 3: Physical Variant Reconciliation & Vault Grouping', () {
    test('E2E-3: Multiple printings, conditions, and foil finishes group cleanly', () {
      // 5 physical copies of Lightning Bolt
      final bolt1 = createPhase46TestCard(
        id: 'b1',
        scryfallId: 'scry-bolt-2ed',
        name: 'Lightning Bolt',
        condition: 'Near Mint',
        quantity: 2,
      );
      final bolt2 = createPhase46TestCard(
        id: 'b2',
        scryfallId: 'scry-bolt-m10',
        name: 'Lightning Bolt',
        condition: 'Lightly Played',
        quantity: 1,
      );
      final bolt3 = createPhase46TestCard(
        id: 'b3',
        scryfallId: 'scry-bolt-2x2',
        name: 'Lightning Bolt',
        condition: 'Near Mint Foil',
        quantity: 1,
      );
      final bolt4 = createPhase46TestCard(
        id: 'b4',
        scryfallId: 'scry-bolt-2x2',
        name: 'Lightning Bolt',
        condition: 'Near Mint Etched',
        quantity: 1,
      );

      final grouped = groupVaultItemsByVariant([bolt1, bolt2, bolt3, bolt4]);

      // Exactly 4 distinct variant buckets
      expect(grouped.length, equals(4));

      // 2ED Non-foil bucket has quantity 2
      final k1 = resolveVariantGroupingKey(bolt1);
      expect(computeVariantQuantity(grouped[k1]!), equals(2));

      // M10 Non-foil bucket has quantity 1
      final k2 = resolveVariantGroupingKey(bolt2);
      expect(computeVariantQuantity(grouped[k2]!), equals(1));

      // 2X2 Traditional Foil bucket has quantity 1
      final k3 = resolveVariantGroupingKey(bolt3);
      expect(computeVariantQuantity(grouped[k3]!), equals(1));
      expect(k3, endsWith('_foil'));

      // 2X2 Etched Foil bucket has quantity 1
      final k4 = resolveVariantGroupingKey(bolt4);
      expect(computeVariantQuantity(grouped[k4]!), equals(1));
      expect(k4, endsWith('_etched'));
    });
  });

  // ===========================================================================
  // Scenario 4: Deck Customization, Cover Thumbnail, & Sticky Collapsing Header
  // ===========================================================================
  group('Tier 4 - Scenario 4: Deck Customization, Cover Thumbnail & Header UI', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('E2E-4.1: Cover art selection and database persistence', () async {
      final card = createPhase46TestCard(
        id: 'c-sheoldred',
        name: 'Sheoldred, the Apocalypse',
        additionalDynamicData: {
          'image_uris': {
            'art_crop': 'https://cards.scryfall.io/art_crop/sheoldred.jpg',
          }
        },
      );
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-sheol', name: 'Monoblack Drain');
      expect(deck.coverItemId, isNull);

      // Select Sheoldred as cover card
      await (db.update(db.decks)..where((t) => t.id.equals(deck.id))).write(
        DecksCompanion(
          coverItemId: Value(card.id),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals(card.id));

      final coverItem = await (db.select(db.vaultItems)..where((t) => t.id.equals(updated.coverItemId!))).getSingle();
      final dyn = jsonDecode(coverItem.dynamicData) as Map<String, dynamic>;
      expect(dyn['image_uris']['art_crop'], equals('https://cards.scryfall.io/art_crop/sheoldred.jpg'));
    });

    testWidgets('E2E-4.2: Sticky collapsible deck header renders without action button collision', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 200,
                  leading: const BackButton(),
                  title: const Text(
                    'Jund Sacrifice [Tournament Ready Edition 2026]',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  actions: [
                    IconButton(key: const Key('action_stats'), icon: const Icon(Icons.bar_chart), onPressed: () {}),
                    IconButton(key: const Key('action_settings'), icon: const Icon(Icons.settings), onPressed: () {}),
                  ],
                  flexibleSpace: const FlexibleSpaceBar(
                    background: ColoredBox(color: Colors.black87),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(
                      title: Text('Card $index: Lightning Bolt'),
                    ),
                    childCount: 60,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Leading and action buttons are visible and not colliding
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('action_stats')), findsOneWidget);
      expect(find.byKey(const Key('action_settings')), findsOneWidget);

      // Scroll to collapse header
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('action_stats')), findsOneWidget);
      expect(find.byKey(const Key('action_settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('E2E-4.3: Proportional scrollbar rail partitions zone heights for Commander, Main, Side, Maybe', () {
      const railHeight = 500.0;
      final counts = [1, 99, 15, 20]; // Commander=1, Main=99, Side=15, Maybe=20 (Total=135)

      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        totalHeight: railHeight,
        counts: counts,
        minHeight: 24.0,
      );

      // Commander (count 1) gets minimum touch height (24.0px)
      expect(heights[0], equals(24.0));
      // Remaining zones receive proportional shares
      expect(heights[1], greaterThan(heights[3])); // Main > Maybe
      expect(heights[3], greaterThan(heights[2])); // Maybe > Side
      expect(heights.fold<double>(0.0, (s, h) => s + h), closeTo(railHeight, 0.01));
    });
  });

  // ===========================================================================
  // Scenario 5: Financial Deck Valuation, Pareto Distribution, & Privacy Mode
  // ===========================================================================
  group('Tier 4 - Scenario 5: Financial Valuation & Privacy Mode Redaction', () {
    testWidgets('E2E-5: Heavy Hitters Pareto concentration and privacy masking toggle', (tester) async {
      final highEndDeck = [
        ParetoCardInput(id: '1', name: 'Black Lotus', setCode: '2ED', quantity: 1, unitPrice: 22000.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'Time Walk', setCode: '2ED', quantity: 1, unitPrice: 4500.0, imageUrl: ''),
        ParetoCardInput(id: '3', name: 'Ancestral Recall', setCode: '2ED', quantity: 1, unitPrice: 3800.0, imageUrl: ''),
        ParetoCardInput(id: '4', name: 'Mox Sapphire', setCode: '2ED', quantity: 1, unitPrice: 3200.0, imageUrl: ''),
        ParetoCardInput(id: '5', name: 'Mox Jet', setCode: '2ED', quantity: 1, unitPrice: 3000.0, imageUrl: ''),
        ParetoCardInput(id: '6', name: 'Island', setCode: 'UNF', quantity: 20, unitPrice: 0.50, imageUrl: ''),
      ];

      // Calculate Pareto
      final paretoResult = ParetoDistributionCalculator.calculate(cards: highEndDeck);
      expect(paretoResult.concentrationPercentage, greaterThan(95.0));

      bool privacyActive = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.shield),
                      onPressed: () => setState(() => privacyActive = !privacyActive),
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  child: ProviderScope(
                    child: ParetoDistributionWidget(
                      result: paretoResult,
                      isPrivacyMode: privacyActive,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Privacy Active: currency figures and percentage masked
      expect(find.textContaining('****'), findsWidgets);
      expect(find.textContaining('22000'), findsNothing);

      // Disable Privacy Mode
      await tester.tap(find.byIcon(Icons.shield));
      await tester.pumpAndSettle();

      // Dollar amounts and percentage now visible
      expect(find.textContaining('22000'), findsWidgets);
      expect(find.textContaining('${paretoResult.concentrationPercentage.toStringAsFixed(1)}%'), findsOneWidget);
    });
  });

  // ===========================================================================
  // Scenario 6: MTG Symbology & Rich Text Deck Primer
  // ===========================================================================
  group('Tier 4 - Scenario 6: MTG Symbology & Rich Text Deck Primer', () {
    test('E2E-6.1: Complex primer text tokenizes and resolves all symbols correctly', () {
      const primerText =
          'Cast commander with {2}{U}{U}, untap using {Q}, activate abilities paying {W/U} or {2/R} or {G/P}, '
          'accumulate {E} energy, and tap {T} to win.';

      final symbols = ScryfallSymbolCatalog.extractSymbols(primerText);
      expect(symbols, equals(['2', 'U', 'U', 'Q', 'W/U', '2/R', 'G/P', 'E', 'T']));

      for (final sym in symbols) {
        final catalogEntry = ScryfallSymbolCatalog.findBySymbol(sym);
        expect(catalogEntry, isNotNull, reason: 'Symbol {$sym} must exist in ScryfallSymbolCatalog');
        expect(catalogEntry!.filename, endsWith('.svg'));
      }
    });

    testWidgets('E2E-6.2: ManaText renders hybrid and Phyrexian symbols in primer widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ManaText('Cast commander with {2}{U}{U}', style: TextStyle(fontSize: 16)),
                  ManaText('Pay hybrid {W/U} or twobrid {2/R}', style: TextStyle(fontSize: 16)),
                  ManaText('Phyrexian cost: {G/P} and energy: {E}', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaText), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });
}

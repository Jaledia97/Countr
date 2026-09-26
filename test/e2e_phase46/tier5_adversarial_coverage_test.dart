import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart' as drift hide Column, isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/decks/domain/legality_enforcer.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/values/presentation/widgets/value_concentration_pie_chart.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

import 'phase46_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 5 - ADVERSARIAL COVERAGE HARDENING (R1 - R4)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Group 1: Adversarial Challenge — R1: Vault Grouping & Availability Engine Integrity
  // ---------------------------------------------------------------------------
  group('Tier 5 - Group 1: Vault Grouping & Availability Engine Integrity', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('ADV-1.1: Truncated, malformed, non-JSON, and nested dynamicData handling in resolveVariantGroupingKey', () {
      // 1. Truncated JSON
      final cardTruncated = createPhase46TestCard(
        id: 'c-trunc',
        name: 'Corrupted Card 1',
        scryfallId: 'scry-trunc',
      );
      final cardWithBadJson = cardTruncated.copyWith(dynamicData: '{"scryfall_id": "scry-trunc", "finish":');
      final key1 = resolveVariantGroupingKey(cardWithBadJson);
      expect(key1, equals('c-trunc_nonfoil'));

      // 2. Completely non-JSON string
      final cardNonJson = cardTruncated.copyWith(dynamicData: '<<<NOT_JSON_DATA>>>');
      final key2 = resolveVariantGroupingKey(cardNonJson);
      expect(key2, equals('c-trunc_nonfoil'));

      // 3. DynamicData with integer finish
      final cardIntFinish = cardTruncated.copyWith(dynamicData: '{"scryfall_id": "scry-num", "finish": 12345}');
      final key3 = resolveVariantGroupingKey(cardIntFinish);
      expect(key3, equals('scry-num_12345'));

      // 4. DynamicData with empty finishes array
      final cardEmptyFinishes = cardTruncated.copyWith(dynamicData: '{"scryfall_id": "scry-empty", "finishes": []}');
      final key4 = resolveVariantGroupingKey(cardEmptyFinishes);
      expect(key4, equals('scry-empty_nonfoil'));

      // 5. DynamicData with weird Unicode whitespace and uppercase
      final cardUnicode = cardTruncated.copyWith(
        dynamicData: jsonEncode({
          'scryfall_id': '  UUID-1234-ABCD  ',
          'finish': '  FOIL\n\t',
        }),
      );
      final key5 = resolveVariantGroupingKey(cardUnicode);
      expect(key5, equals('UUID-1234-ABCD_foil'));
    });

    test('ADV-1.2: Massive grouping partition & conservation law (500 items across finishes)', () {
      final items = <VaultItem>[];
      const scryId = 'scryfall-shared-id-500';
      int expectedFoilQty = 0;
      int expectedNonfoilQty = 0;
      int expectedEtchedQty = 0;

      for (int i = 0; i < 500; i++) {
        final finish = (i % 3 == 0) ? 'foil' : (i % 3 == 1 ? 'nonfoil' : 'etched');
        final qty = (i % 5) + 1;
        if (finish == 'foil') expectedFoilQty += qty;
        if (finish == 'nonfoil') expectedNonfoilQty += qty;
        if (finish == 'etched') expectedEtchedQty += qty;

        items.add(
          createPhase46TestCard(
            id: 'c-$i',
            name: 'Shared Card #$i',
            scryfallId: scryId,
            finish: finish,
            quantity: qty,
          ),
        );
      }

      final grouped = groupVaultItemsByVariant(items);
      // Strictly 3 variant partition buckets
      expect(grouped.length, equals(3));
      expect(grouped.containsKey('${scryId}_foil'), isTrue);
      expect(grouped.containsKey('${scryId}_nonfoil'), isTrue);
      expect(grouped.containsKey('${scryId}_etched'), isTrue);

      // Quantities must conserve perfectly
      final totalFoil = computeVariantQuantity(grouped['${scryId}_foil']!);
      final totalNonfoil = computeVariantQuantity(grouped['${scryId}_nonfoil']!);
      final totalEtched = computeVariantQuantity(grouped['${scryId}_etched']!);

      expect(totalFoil, equals(expectedFoilQty));
      expect(totalNonfoil, equals(expectedNonfoilQty));
      expect(totalEtched, equals(expectedEtchedQty));

      final grandTotal = totalFoil + totalNonfoil + totalEtched;
      final expectedGrandTotal = items.fold<int>(0, (sum, it) => sum + it.quantity);
      expect(grandTotal, equals(expectedGrandTotal));
    });

    test('ADV-1.3: Complex multi-deck allocation & soft-delete isolation', () async {
      // Create Vault card with owned=10
      final card = createPhase46TestCard(id: 'c-multi-alloc', name: 'Mox Diamond', quantity: 10);
      await db.into(db.vaultItems).insert(card);

      // 1. Deck 1: Assembled (is_registered=1, is_assembled=1), 2 copies -> MUST lock 2
      final d1 = await createAndInsertDeck(db, id: 'd-1', name: 'Real Assembled Deck', isRegistered: true);
      await addCardToDeckZone(db, deckId: d1.id, vaultItemId: card.id, quantity: 2, boardZone: 'Mainboard');

      // 2. Deck 2: Draft (is_registered=0), 3 copies -> MUST NOT lock
      final d2 = await createAndInsertDeck(db, id: 'd-2', name: 'Draft Deck', isRegistered: false);
      await addCardToDeckZone(db, deckId: d2.id, vaultItemId: card.id, quantity: 3, boardZone: 'Mainboard');

      // 3. Deck 3: Assembled (is_registered=1), but deck soft-deleted (is_deleted=1), 4 copies -> MUST NOT lock
      final d3 = await createAndInsertDeck(db, id: 'd-3', name: 'Deleted Assembled Deck', isRegistered: true);
      await addCardToDeckZone(db, deckId: d3.id, vaultItemId: card.id, quantity: 4, boardZone: 'Mainboard');
      await (db.update(db.decks)..where((t) => t.id.equals(d3.id))).write(
        const DecksCompanion(isDeleted: drift.Value(true)),
      );

      // 4. Deck 4: Active assembled deck, but deck_version_item soft-deleted, 2 copies -> MUST NOT lock
      final d4 = await createAndInsertDeck(db, id: 'd-4', name: 'Active Deck with deleted item', isRegistered: true);
      final dvi4 = await addCardToDeckZone(db, deckId: d4.id, vaultItemId: card.id, quantity: 2, boardZone: 'Mainboard');
      await (db.update(db.deckVersionItems)..where((t) => t.id.equals(dvi4.id))).write(
        const DeckVersionItemsCompanion(isDeleted: drift.Value(true)),
      );

      // 5. Deck 5: Active assembled deck, but proxy copy (is_proxy=1), 5 copies -> MUST NOT lock
      final d5 = await createAndInsertDeck(db, id: 'd-5', name: 'Proxy Assembled Deck', isRegistered: true);
      await addCardToDeckZone(db, deckId: d5.id, vaultItemId: card.id, quantity: 5, boardZone: 'Mainboard', isProxy: true);

      // Verify availability via calculateItemAvailability helper
      final avail = await calculateItemAvailability(db, card.id);
      expect(avail.owned, equals(10));
      expect(avail.inDeck, equals(2));
      expect(avail.available, equals(8));

      // Verify availability directly via VaultDao.watchAllCardAvailability
      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final daoAvail = availMap[card.id];
      expect(daoAvail, isNotNull);
      expect(daoAvail!.owned, equals(10));
      expect(daoAvail.inDeck, equals(2));
      expect(daoAvail.available, equals(8));

      // Verify badges: Only Deck 1 appears
      final badges = await watchAssembledDeckBadges(db, card.id).first;
      expect(badges, equals(['Real Assembled Deck']));
    });

    test('ADV-1.4: Over-allocation clamp prevents negative available counts', () async {
      final card = createPhase46TestCard(id: 'c-overalloc', name: 'Black Lotus', quantity: 1);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-over', name: 'Overallocated Deck', isRegistered: true);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 99999, boardZone: 'Mainboard');

      final avail = await calculateItemAvailability(db, card.id);
      expect(avail.owned, equals(1));
      expect(avail.inDeck, equals(99999));
      expect(avail.available, equals(0)); // strictly clamped to 0, not -99998
    });

    test('ADV-1.5: Assembled badge stream reactivity on rapid assembly toggle', () async {
      final card = createPhase46TestCard(id: 'c-toggle-race', name: 'Chrome Mox', quantity: 2);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-toggle-race', name: 'Flipping Deck', isRegistered: false);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 1, boardZone: 'Mainboard');

      final badgeStream = watchAssembledDeckBadges(db, card.id);

      // Initial: draft -> []
      expect(await badgeStream.first, isEmpty);

      // Flip 1: Assembled -> ['Flipping Deck']
      await db.vaultDao.setDeckRegistered(deck.id, true);
      expect(await badgeStream.first, equals(['Flipping Deck']));

      // Flip 2: Disassembled -> []
      await db.vaultDao.setDeckRegistered(deck.id, false);
      expect(await badgeStream.first, isEmpty);

      // Flip 3: Assembled -> ['Flipping Deck']
      await db.vaultDao.setDeckRegistered(deck.id, true);
      expect(await badgeStream.first, equals(['Flipping Deck']));

      // Flip 4: Disassembled -> []
      await db.vaultDao.setDeckRegistered(deck.id, false);
      expect(await badgeStream.first, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: Adversarial Challenge — R2: Deck Builder, Boards & Legality Engine
  // ---------------------------------------------------------------------------
  group('Tier 5 - Group 2: Deck Builder, Boards & Legality Engine', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('ADV-2.1: Adversarial board movement parameter attacks on moveDeckItemBoard', () async {
      final card = createPhase46TestCard(id: 'c-move-atk', name: 'Mana Vault', quantity: 4);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-move-atk', name: 'Board Attack Deck', isRegistered: false);
      final dvi = await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 4, boardZone: 'Mainboard');

      // 1. Move to same board: no-op
      await db.vaultDao.moveDeckItemBoard(deck.id, dvi.id, 'Mainboard', 2);
      var rows = await (db.select(db.deckVersionItems)..where((t) => t.id.equals(dvi.id))).get();
      expect(rows.first.boardZone, equals('Mainboard'));
      expect(rows.first.quantity, equals(4));

      // 2. Move with non-standard casing and alias: 'sIdEbOaRd'
      await db.vaultDao.moveDeckItemBoard(deck.id, dvi.id, 'sIdEbOaRd', 1);
      // Source should be decremented to 3
      rows = await (db.select(db.deckVersionItems)..where((t) => t.id.equals(dvi.id))).get();
      expect(rows.first.quantity, equals(3));
      // Target should have 1 in Sideboard
      var sbRows = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Sideboard') & t.isDeleted.equals(false)))
          .get();
      expect(sbRows.length, equals(1));
      expect(sbRows.first.quantity, equals(1));

      // 3. Move excess quantity (request 999 when only 3 remain) -> moves all remaining
      await db.vaultDao.moveDeckItemBoard(deck.id, dvi.id, 'Sideboard', 999);
      // Source item exhausted: soft-deleted
      rows = await (db.select(db.deckVersionItems)..where((t) => t.id.equals(dvi.id))).get();
      expect(rows.first.isDeleted, isTrue);

      // Target item consolidated: 1 + 3 = 4
      sbRows = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Sideboard') & t.isDeleted.equals(false)))
          .get();
      expect(sbRows.length, equals(1));
      expect(sbRows.first.quantity, equals(4));

      // 4. Verify SyncQueue invariants logged
      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('deck_version_item')))
          .get();
      expect(syncEntries.isNotEmpty, isTrue);
      final operations = syncEntries.map((e) => e.operation).toSet();
      expect(operations.contains('UPDATE') || operations.contains('DELETE'), isTrue);
    });

    test('ADV-2.2: Board move isolation between proxy and non-proxy rows', () async {
      final card = createPhase46TestCard(id: 'c-proxy-iso', name: 'Underground Sea', quantity: 2);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-proxy-iso', name: 'Proxy Iso Deck', isRegistered: false);
      final realDvi = await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 2, boardZone: 'Mainboard', isProxy: false);
      final proxyDvi = await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 2, boardZone: 'Mainboard', isProxy: true);

      // Move 1 real card to Sideboard
      await db.vaultDao.moveDeckItemBoard(deck.id, realDvi.id, 'Sideboard', 1);

      // Proxy row must remain untouched in Mainboard with quantity 2
      final proxyCheck = await (db.select(db.deckVersionItems)..where((t) => t.id.equals(proxyDvi.id))).getSingle();
      expect(proxyCheck.boardZone, equals('Mainboard'));
      expect(proxyCheck.quantity, equals(2));
      expect(proxyCheck.isProxy, isTrue);

      // Real row in Mainboard decremented to 1
      final realCheck = await (db.select(db.deckVersionItems)..where((t) => t.id.equals(realDvi.id))).getSingle();
      expect(realCheck.boardZone, equals('Mainboard'));
      expect(realCheck.quantity, equals(1));
      expect(realCheck.isProxy, isFalse);

      // New real row in Sideboard with quantity 1
      final sideRows = await (db.select(db.deckVersionItems)
            ..where((t) => t.vaultItemId.equals(card.id) & t.boardZone.equals('Sideboard') & t.isDeleted.equals(false)))
          .get();
      expect(sideRows.length, equals(1));
      expect(sideRows.first.isProxy, isFalse);
      expect(sideRows.first.quantity, equals(1));
    });

    test('ADV-2.3: Format legality engine input fuzzing with CardLegality.evaluate', () {
      // 1. Extreme format casing & spaces
      const legalitiesJson = '{"legalities": {"commander": "banned", "vintage": "restricted", "modern": "legal", "pauper": "not_legal"}}';
      final legCmd = CardLegality.evaluate(legalitiesJson, '  cOMmAnDeR  ');
      expect(legCmd.status, equals(LegalityStatus.banned));
      expect(legCmd.isBanned, isTrue);
      expect(legCmd.hasWarning, isTrue);
      expect(legCmd.badgeLabel, equals('BANNED'));

      // 2. EDH alias normalization
      final legEdh = CardLegality.evaluate(legalitiesJson, 'EDH');
      expect(legEdh.status, equals(LegalityStatus.banned));

      // 3. Vintage restricted status
      final legVin = CardLegality.evaluate(legalitiesJson, 'vintage');
      expect(legVin.status, equals(LegalityStatus.restricted));
      expect(legVin.isRestricted, isTrue);
      expect(legVin.hasWarning, isTrue); // In MTG, restricted status produces a warning indicator
      expect(legVin.badgeLabel, equals('RESTRICTED'));

      // 4. Modern legal status
      final legMod = CardLegality.evaluate(legalitiesJson, 'Modern');
      expect(legMod.status, equals(LegalityStatus.legal));
      expect(legMod.isLegal, isTrue);
      expect(legMod.hasWarning, isFalse);

      // 5. Pauper not_legal status
      final legPauper = CardLegality.evaluate(legalitiesJson, 'pauper');
      expect(legPauper.status, equals(LegalityStatus.notLegal));
      expect(legPauper.isNotLegal, isTrue);
      expect(legPauper.hasWarning, isTrue);

      // 6. Unknown / unlisted format in json -> notLegal
      final legStandard = CardLegality.evaluate(legalitiesJson, 'standard');
      expect(legStandard.status, equals(LegalityStatus.notLegal));

      // 7. Non-JSON corrupted string -> unknown
      final legCorrupted = CardLegality.evaluate('<<<NOT_A_JSON>>>', 'commander');
      expect(legCorrupted.status, equals(LegalityStatus.unknown));
      expect(legCorrupted.badgeLabel, equals('UNKNOWN'));

      // 8. Null input -> unknown
      final legNull = CardLegality.evaluate(null, 'commander');
      expect(legNull.status, equals(LegalityStatus.unknown));

      // 9. Empty map -> unknown
      final legEmpty = CardLegality.evaluate(<String, dynamic>{}, 'commander');
      expect(legEmpty.status, equals(LegalityStatus.unknown));
    });

    test('ADV-2.4: Deck thumbnail picker resilience with null, missing, or soft-deleted cover items', () async {
      final deck = await createAndInsertDeck(db, id: 'd-thumb-atk', name: 'Thumbnail Test', coverItemId: null);
      expect(deck.coverItemId, isNull);

      // Update cover to non-existent UUID
      await (db.update(db.decks)..where((t) => t.id.equals(deck.id))).write(
        const DecksCompanion(coverItemId: drift.Value('non-existent-uuid-9999')),
      );
      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals('non-existent-uuid-9999'));

      // Querying deck details handles non-existent cover without crash
      final versionItems = await db.vaultDao.watchDeckItems(deck.id).first;
      expect(versionItems, isEmpty);
    });

    test('ADV-2.5: Proportional scrollbar rail partition math stress on computeSectionHeights', () {
      // 1. Zero or negative height returns empty
      expect(ProportionalBubbleScrollbar.computeSectionHeights(counts: [10, 20], totalHeight: 0), isEmpty);
      expect(ProportionalBubbleScrollbar.computeSectionHeights(counts: [10, 20], totalHeight: -100), isEmpty);

      // 2. Empty counts returns empty
      expect(ProportionalBubbleScrollbar.computeSectionHeights(counts: [], totalHeight: 500), isEmpty);

      // 3. Constrained height guard (e.g. 50 sections on 100px screen)
      final counts50 = List.filled(50, 2);
      final heights50 = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: counts50,
        totalHeight: 100.0,
        minHeight: 24.0,
      );
      expect(heights50.length, equals(50));
      // All sections divide rail equally: 100 / 50 = 2.0
      for (final h in heights50) {
        expect(h, closeTo(2.0, 0.001));
      }
      expect(heights50.reduce((a, b) => a + b), closeTo(100.0, 0.001));

      // 4. Extreme ratio: 1 section has 1,000,000 cards, 4 sections have 0 cards
      final heightsExtreme = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [1000000, 0, 0, 0, 0],
        totalHeight: 500.0,
        minHeight: 24.0,
      );
      expect(heightsExtreme.length, equals(5));
      // The 4 zero-count sections must receive minimum clamp 24.0
      for (int i = 1; i < 5; i++) {
        expect(heightsExtreme[i], equals(24.0));
      }
      // The huge section receives remainder: 500 - (4 * 24) = 404.0
      expect(heightsExtreme[0], closeTo(404.0, 0.001));
      // Total sum strictly equals totalHeight
      expect(heightsExtreme.reduce((a, b) => a + b), closeTo(500.0, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: Adversarial Challenge — R3: Deck Analytics, Symbology & Mana Math
  // ---------------------------------------------------------------------------
  group('Tier 5 - Group 3: Deck Analytics, Symbology & Mana Math', () {
    test('ADV-3.1: Exotic MTG mana cost parsing & CMC oracle verification', () {
      // 1. Split card notation
      expect(calculateAccurateCmc('{1}{R} // {1}{U}'), equals(4.0));
      expect(calculateAccurateCmc('{2}{W} // {3}{B}'), equals(7.0));

      // 2. Twobrid notation under MTG CR 202.3e ({2/W} = 2.0)
      expect(calculateAccurateCmc('{2/W}{2/U}{2/B}{2/R}{2/G}'), equals(10.0));
      expect(calculateAccurateCmc('{2/W}{W}'), equals(3.0));

      // 3. Phyrexian mana symbols
      expect(calculateAccurateCmc('{W/P}{U/P}{B/P}{R/P}{G/P}'), equals(5.0));

      // 4. Hybrid mana symbols
      expect(calculateAccurateCmc('{W/U}{B/R}{G/W}'), equals(3.0));

      // 5. Variable mana {X} (X is 0 in deck/hand)
      expect(calculateAccurateCmc('{X}{X}{R}'), equals(1.0));
      expect(calculateAccurateCmc('{X}{3}{U}{U}'), equals(5.0));

      // 6. Zero mana cost
      expect(calculateAccurateCmc('{0}'), equals(0.0));

      // 7. Large generic cost
      expect(calculateAccurateCmc('{16}'), equals(16.0));

      // 8. Empty / null cost
      expect(calculateAccurateCmc(''), equals(0.0));
      expect(calculateAccurateCmc(null), equals(0.0));
    });

    test('ADV-3.2: Multi-face layout canonical CMC resolution with resolveCardCmc', () {
      // 1. Adventure card (CR 716.4: CMC of main permanent face)
      final adventureCard = {
        'layout': 'adventure',
        'card_faces': [
          {'name': 'Bonecrusher Giant', 'mana_cost': '{2}{R}', 'cmc': 3.0},
          {'name': 'Stomp', 'mana_cost': '{1}{R}', 'cmc': 2.0},
        ],
        'cmc': 3.0,
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(adventureCard), equals(3.0));

      // 2. Modal DFC (CR 712.8a: CMC of front face)
      final mdfcCard = {
        'layout': 'modal_dfc',
        'card_faces': [
          {'name': 'Sea Gate Restoration', 'mana_cost': '{4}{U}{U}{U}', 'cmc': 7.0},
          {'name': 'Sea Gate, Reborn', 'mana_cost': '', 'cmc': 0.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(mdfcCard), equals(7.0));

      // 3. Transform card (CR 712.8a: CMC of front face)
      final transformCard = {
        'layout': 'transform',
        'card_faces': [
          {'name': 'Delver of Secrets', 'mana_cost': '{U}', 'cmc': 1.0},
          {'name': 'Insectile Aberration', 'mana_cost': '', 'cmc': 0.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(transformCard), equals(1.0));

      // 4. Split / Aftermath card (CR 709.4: sum of both faces)
      final aftermathCard = {
        'layout': 'aftermath',
        'card_faces': [
          {'name': 'Destined', 'mana_cost': '{1}{B}', 'cmc': 2.0},
          {'name': 'Lead', 'mana_cost': '{3}{G}', 'cmc': 4.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(aftermathCard), equals(6.0));

      // 5. Card with no CMC field but valid mana_cost string fallback
      final noCmcCard = {
        'name': 'Dark Ritual',
        'mana_cost': '{B}',
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(noCmcCard), equals(1.0));
    });

    test('ADV-3.3: Symbology text parser edge cases with ManaTextParser.parse', () {
      const style = TextStyle(fontSize: 14.0);

      // 1. 100 consecutive mana symbols
      final heavyCost = '{W}' * 100;
      final spans1 = ManaTextParser.parse(text: heavyCost, baseStyle: style);
      expect(spans1.length, equals(100));
      expect(spans1.every((s) => s is WidgetSpan), isTrue);

      // 2. Unmatched braces
      final spans2 = ManaTextParser.parse(text: 'Pay {2 and {W} mana', baseStyle: style);
      // 'Pay {2 and ' is TextSpan, '{W}' is WidgetSpan, ' mana' is TextSpan
      expect(spans2.length, equals(3));
      expect(spans2[0], isA<TextSpan>());
      expect((spans2[0] as TextSpan).text, equals('Pay {2 and '));
      expect(spans2[1], isA<WidgetSpan>());
      expect(spans2[2], isA<TextSpan>());
      expect((spans2[2] as TextSpan).text, equals(' mana'));

      // 3. Unrecognized symbol codes pass through as plain text
      final spans3 = ManaTextParser.parse(text: '{NotASymbol} and {W}', baseStyle: style);
      expect(spans3.any((s) => s is TextSpan && s.text!.contains('{NotASymbol}')), isTrue);

      // 4. Empty text
      final spans4 = ManaTextParser.parse(text: '', baseStyle: style);
      expect(spans4, isEmpty);
    });

    test('ADV-3.4: Pareto value concentration boundary conditions and privacy masking', () {
      // 1. Zero total deck value (all free cards)
      final zeroCards = [
        const ParetoCardInput(id: 'c1', name: 'Plains', quantity: 4, unitPrice: 0.0),
        const ParetoCardInput(id: 'c2', name: 'Island', quantity: 4, unitPrice: 0.0),
      ];
      final resZero = ParetoDistributionCalculator.calculate(cards: zeroCards);
      expect(resZero.totalDeckValue, equals(0.0));
      expect(resZero.concentrationPercentage, equals(0.0));
      expect(resZero.getHeadline(), contains('0.0%'));

      // 2. Single card deck -> 100.0%
      final singleCard = [
        const ParetoCardInput(id: 'c-lotus', name: 'Black Lotus', quantity: 1, unitPrice: 50000.0),
      ];
      final resSingle = ParetoDistributionCalculator.calculate(cards: singleCard);
      expect(resSingle.totalDeckValue, equals(50000.0));
      expect(resSingle.concentrationPercentage, equals(100.0));
      expect(resSingle.getHeadline(), contains('The top card represents 100.0%'));

      // 3. 100 cards with identical $1.00 price: Top 5 represent exactly 5.0%
      final uniformCards = List.generate(
        100,
        (i) => ParetoCardInput(id: 'c-$i', name: 'Card #$i', quantity: 1, unitPrice: 1.0),
      );
      final resUniform = ParetoDistributionCalculator.calculate(cards: uniformCards);
      expect(resUniform.totalDeckValue, equals(100.0));
      expect(resUniform.topCards.length, equals(5));
      expect(resUniform.concentrationPercentage, equals(5.0));

      // 4. Privacy masking in headline
      expect(resUniform.getHeadline(isPrivacyMode: true), contains('represent **** of this deck\'s total value'));
    });

    testWidgets('ADV-3.5: ValueConcentrationPieChart polar hit-testing geometry & center deselect', (tester) async {
      int? selectedSliceIndex = 0;

      final slices = [
        const PieSliceData(
          id: 's1',
          name: 'Card A',
          value: 70.0,
          percentage: 70.0,
          color: Colors.amber,
        ),
        const PieSliceData(
          id: 's2',
          name: 'Card B',
          value: 30.0,
          percentage: 30.0,
          color: Colors.cyan,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueConcentrationPieChart(
                slices: slices,
                totalDeckValue: 100.0,
                topK: 2,
                concentrationPercentage: 100.0,
                selectedIndex: selectedSliceIndex,
                onSliceSelected: (idx) {
                  selectedSliceIndex = idx;
                },
                size: 200.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap directly in the center hole (radius < innerRadius)
      // The chart is 200x200 centered in the viewport
      final chartFinder = find.byType(ValueConcentrationPieChart);
      final chartCenter = tester.getCenter(chartFinder);

      await tester.tapAt(chartCenter);
      await tester.pumpAndSettle();

      // Tapping center hole deselects (index becomes null)
      expect(selectedSliceIndex, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: Adversarial Challenge — R4: UI Stability, Presentation & Layout Hardening
  // ---------------------------------------------------------------------------
  group('Tier 5 - Group 4: UI Stability, Presentation & Layout Hardening', () {
    testWidgets('ADV-4.1: SliverAppBar title collision stress with extreme text payloads', (tester) async {
      // 300-character deck title with emojis and special characters
      const extremeTitle = '👑 URZA HIGH ARTIFICER — [cEDH 2026] ⚡️ 🔥 💀 🌳 ☀️ '
          'Supercalifragilisticexpialidocious Infinite Mana Combo Deck with extremely long subtitle '
          'and redundant text intended to overflow any standard unconstrained header line 🏆';

      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  leading: const BackButton(),
                  actions: [
                    IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
                  ],
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                      final double delta = (settings != null) ? (settings.maxExtent - settings.minExtent) : 124.0;
                      final double t = (settings != null && delta > 0)
                          ? (1.0 - (settings.currentExtent - settings.minExtent) / delta).clamp(0.0, 1.0)
                          : 0.0;
                      final double leftPadding = Tween<double>(begin: 16.0, end: 56.0).transform(t);
                      final double rightPadding = Tween<double>(begin: 16.0, end: 144.0).transform(t);
                      final double availableWidth = constraints.maxWidth - leftPadding - rightPadding;

                      return FlexibleSpaceBar(
                        titlePadding: EdgeInsets.only(left: leftPadding, right: rightPadding, bottom: 14.0),
                        title: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: math.max(60.0, availableWidth)),
                          child: const Text(
                            extremeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(title: Text('Deck Card #$index')),
                    childCount: 50,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll up to collapse the SliverAppBar completely
      scrollController.jumpTo(200.0);
      await tester.pumpAndSettle();

      // Ensure zero overflow errors occurred during full collapse
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-4.2: Ultra-narrow viewport (300x500) & 2.5x font scale zero-overflow layout test', (tester) async {
      tester.view.physicalSize = const Size(300, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final result = ParetoDistributionCalculator.calculate(
        cards: [
          const ParetoCardInput(id: 'c1', name: 'The One Ring', setCode: 'LTR', quantity: 1, unitPrice: 120.0),
          const ParetoCardInput(id: 'c2', name: 'Sol Ring', setCode: 'CMM', quantity: 1, unitPrice: 2.5),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(300, 500),
              textScaler: TextScaler.linear(2.5),
            ),
            child: ProviderScope(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ParetoDistributionWidget(
                    result: result,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must render without any RenderFlex overflow exceptions
      expect(tester.takeException(), isNull);
      expect(find.byType(ParetoDistributionWidget), findsOneWidget);
    });

    testWidgets('ADV-4.3: Context-aware filter state switching between MTG and Non-MTG games', (tester) async {
      late AppDatabase db;
      db = createPhase46TestDb();
      addTearDown(() => db.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(() => container.dispose());

      // 1. Initial MTG Context: MTG filter pills must be visible
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: VaultScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MTG pills are present
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_mana_value')), findsOneWidget);

      // 2. Dynamically switch context to Pokemon TCG: MTG filter pills must reactively disappear
      container.read(activeGameContextProvider.notifier).state = 'Pokemon TCG';
      await tester.pumpAndSettle();

      // MTG pills are suppressed in non-MTG context
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_mana_value')), findsNothing);
    });

    testWidgets('ADV-4.4: ProportionalBubbleScrollbar fast drag scrub without unhandled gesture collisions', (tester) async {
      final scrollController = ScrollController();
      final sections = [
        ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
        ScrollbarSection(label: 'Creatures', count: 20, onTap: () {}),
        ScrollbarSection(label: 'Spells', count: 30, onTap: () {}),
        ScrollbarSection(label: 'Lands', count: 35, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ListView.builder(
                  controller: scrollController,
                  itemCount: 86,
                  itemBuilder: (context, index) => SizedBox(height: 50, child: Text('Card $index')),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: ProportionalBubbleScrollbar(
                    sections: sections,
                    controller: scrollController,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollbarFinder = find.byType(ProportionalBubbleScrollbar);
      expect(scrollbarFinder, findsOneWidget);

      // Execute aggressive drag up and down
      await tester.drag(scrollbarFinder, const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(scrollbarFinder, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

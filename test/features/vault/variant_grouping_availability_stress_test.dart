// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Adversarial Stress Test Suite for Phase 4.6 Milestone 1:
// Variant Grouping Engine, Availability Calculation Engine, Soft-Delete & Proxy Invariants.

import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultItem makeVaultItem({
    required String id,
    required String name,
    String setOrSeries = 'LTR',
    int quantity = 1,
    String condition = 'Near Mint',
    String? scryfallId,
    String? oracleId,
    String? finish,
    List<dynamic>? finishes,
    String? treatment,
    String? collectorNumber,
    String? setCode,
    String? primaryBinderId,
    String imageUrl = '',
    bool isDeleted = false,
    DateTime? acquiredDate,
  }) {
    final now = acquiredDate ?? DateTime.now();
    final dynamicMap = <String, dynamic>{};
    if (scryfallId != null) dynamicMap['scryfall_id'] = scryfallId;
    if (oracleId != null) dynamicMap['oracle_id'] = oracleId;
    if (finish != null) dynamicMap['finish'] = finish;
    if (finishes != null) dynamicMap['finishes'] = finishes;
    if (treatment != null) dynamicMap['treatment'] = treatment;
    if (collectorNumber != null) dynamicMap['collector_number'] = collectorNumber;
    if (setCode != null) dynamicMap['set'] = setCode;

    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: imageUrl,
      acquiredPrice: 1.0,
      acquiredDate: now,
      quantity: quantity,
      condition: condition,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      currentMarketPrice: 1.0,
      lastPriceUpdate: now,
      dynamicData: jsonEncode(dynamicMap),
      isDeleted: isDeleted,
      primaryBinderId: primaryBinderId,
    );
  }

  // ===========================================================================
  // SECTION 1: ADVERSARIAL FINISH & METADATA NORMALIZATION
  // ===========================================================================
  group('Section 1: Adversarial Finish & Metadata Normalization', () {
    test('Handles malformed or corrupt JSON in dynamicData gracefully', () {
      final now = DateTime.now();
      final corrupted = VaultItem(
        id: 'corrupt-item-1',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: 'LEA',
        imageUrl: '',
        acquiredPrice: 50000.0,
        acquiredDate: now,
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 50000.0,
        lastPriceUpdate: now,
        dynamicData: '{unclosed-json-corrupt:',
        isDeleted: false,
      );

      // Must not throw, falls back safely to item.id and 'nonfoil'
      final printingId = VaultVariantHelper.resolvePrintingId(corrupted);
      expect(printingId, equals('corrupt-item-1'));

      final finish = VaultVariantHelper.resolveFinish(corrupted);
      expect(finish, equals('nonfoil'));

      final key = VaultVariantHelper.computeVariantKey(corrupted);
      expect(key, equals('mtg_corrupt-item-1_nonfoil'));

      final abstractKey = VaultVariantHelper.resolveAbstractCardKey(corrupted);
      expect(abstractKey, equals('mtg_black lotus'));
    });

    test('Normalizes various casing and whitespace variations of finishes', () {
      final cases = [
        ('  foil  ', 'foil'),
        ('FOIL', 'foil'),
        ('Etched', 'etched'),
        ('ETCHED FOIL', 'etched foil'),
        ('nonfoil', 'nonfoil'),
        ('Non-Foil', 'non-foil'),
      ];

      for (final (input, expected) in cases) {
        final item = makeVaultItem(
          id: 'finish-test-$input',
          name: 'Lightning Bolt',
          scryfallId: 'scry-bolt',
          finish: input,
        );
        expect(
          VaultVariantHelper.resolveFinish(item),
          equals(expected),
          reason: 'Finish "$input" should resolve to "$expected"',
        );
      }
    });

    test('Infers finish from finishes array, treatment string, or condition string fallback', () {
      // 1. Array fallback
      final itemArray = makeVaultItem(
        id: 'item-arr',
        name: 'Mox Diamond',
        scryfallId: 'scry-mox',
        finishes: ['foil', 'nonfoil'],
      );
      expect(VaultVariantHelper.resolveFinish(itemArray), equals('foil'));

      // 2. Treatment fallback
      final itemTreatmentFoil = makeVaultItem(
        id: 'item-treat-1',
        name: 'Sol Ring',
        scryfallId: 'scry-treat-1',
        treatment: 'textured rainbow foil',
      );
      expect(VaultVariantHelper.resolveFinish(itemTreatmentFoil), equals('foil'));

      final itemTreatmentEtched = makeVaultItem(
        id: 'item-treat-2',
        name: 'Sol Ring',
        scryfallId: 'scry-treat-2',
        treatment: 'showcase etched retro',
      );
      expect(VaultVariantHelper.resolveFinish(itemTreatmentEtched), equals('etched'));

      // 3. Condition string fallback when dynamicData has no finish
      final itemCondFoil = makeVaultItem(
        id: 'item-cond-foil',
        name: 'Birds of Paradise',
        condition: 'Near Mint - Foil',
      );
      expect(VaultVariantHelper.resolveFinish(itemCondFoil), equals('foil'));

      final itemCondEtched = makeVaultItem(
        id: 'item-cond-etched',
        name: 'Birds of Paradise',
        condition: 'Lightly Played (Etched)',
      );
      expect(VaultVariantHelper.resolveFinish(itemCondEtched), equals('etched'));
    });

    test('Specialty finishes (surge, galaxy, confetti) are preserved as distinct finish buckets', () {
      final surge = makeVaultItem(
        id: 'item-surge',
        name: 'The One Ring',
        scryfallId: 'scry-ring',
        finish: 'surge',
      );
      final galaxy = makeVaultItem(
        id: 'item-galaxy',
        name: 'The One Ring',
        scryfallId: 'scry-ring',
        finish: 'galaxy',
      );
      final nonfoil = makeVaultItem(
        id: 'item-nonfoil',
        name: 'The One Ring',
        scryfallId: 'scry-ring',
        finish: 'nonfoil',
      );

      final keySurge = VaultVariantHelper.computeVariantKey(surge);
      final keyGalaxy = VaultVariantHelper.computeVariantKey(galaxy);
      final keyNonfoil = VaultVariantHelper.computeVariantKey(nonfoil);

      expect(keySurge, equals('mtg_scry-ring_surge'));
      expect(keyGalaxy, equals('mtg_scry-ring_galaxy'));
      expect(keyNonfoil, equals('mtg_scry-ring_nonfoil'));
      expect(keySurge, isNot(equals(keyGalaxy)));
      expect(keyGalaxy, isNot(equals(keyNonfoil)));
    });
  });

  // ===========================================================================
  // SECTION 2: PRINTING ID RESOLUTION & MULTI-ART SETS (NAZGÛL ORACLE)
  // ===========================================================================
  group('Section 2: Printing ID Resolution & Multi-Art Sets', () {
    test('Nazgûl Oracle: 9 distinct card arts in same set are grouped into 9 distinct variant buckets', () {
      // Nazgûl has 9 printings in LTR, each with distinct scryfall_id and collector_number (100, 332..339),
      // sharing the identical oracle_id.
      final oracleId = 'oracle-nazgul-unique';
      final nazgulVariants = <VaultItem>[];

      for (int i = 0; i < 9; i++) {
        final collectorNum = (i == 0) ? '100' : '${331 + i}';
        nazgulVariants.add(
          makeVaultItem(
            id: 'nazgul-item-$i',
            name: 'Nazgûl',
            setOrSeries: 'LTR',
            scryfallId: 'scry-nazgul-$collectorNum',
            oracleId: oracleId,
            collectorNumber: collectorNum,
            setCode: 'ltr',
            finish: (i % 2 == 0) ? 'foil' : 'nonfoil',
            quantity: 1,
          ),
        );
      }

      final result = VaultVariantHelper.groupVaultItemsByVariant(nazgulVariants);

      // Must produce exactly 9 distinct items
      expect(result.items.length, equals(9));
      // All 9 must belong to the same multi-variant card key
      expect(result.multiVariantCardKeys.contains('mtg_$oracleId'), isTrue);
      // Ensure all 9 variant keys are unique
      final keys = result.items.map(VaultVariantHelper.computeVariantKey).toSet();
      expect(keys.length, equals(9));
    });

    test('Printing ID fallback without scryfall_id uses name_set_collectorNumber', () {
      final item = makeVaultItem(
        id: 'no-scryfall-id',
        name: 'Dark Ritual',
        setOrSeries: 'EMA',
        setCode: 'ema',
        collectorNumber: '82',
        finish: 'nonfoil',
      );

      final printingId = VaultVariantHelper.resolvePrintingId(item);
      expect(printingId, equals('dark ritual_ema_82'));
    });

    test('Empty input list returns empty result without throwing', () {
      final result = VaultVariantHelper.groupVaultItemsByVariant([]);
      expect(result.items.isEmpty, isTrue);
      expect(result.variantToUnderlyingIds.isEmpty, isTrue);
      expect(result.multiVariantCardKeys.isEmpty, isTrue);
    });
  });

  // ===========================================================================
  // SECTION 3: VARIANT GROUPING SCALE & MONTE CARLO FUZZING
  // ===========================================================================
  group('Section 3: Variant Grouping Scale & Monte Carlo Fuzzing', () {
    test('1,000 items scale stress test preserves quantities, invariants, and performance', () {
      final rng = Random(42);
      final rawItems = <VaultItem>[];
      final cardNames = List.generate(50, (i) => 'Staple Card #$i');
      final finishes = ['nonfoil', 'foil', 'etched', 'surge'];

      int expectedTotalQuantity = 0;

      // Generate 1,000 items across 50 cards with multiple printings and finishes
      for (int i = 0; i < 1000; i++) {
        final cardIndex = rng.nextInt(cardNames.length);
        final cardName = cardNames[cardIndex];
        final printingNum = rng.nextInt(3) + 1; // 1, 2, or 3 printings per card
        final finish = finishes[rng.nextInt(finishes.length)];
        final quantity = rng.nextInt(5) + 1; // 1 to 5 copies
        expectedTotalQuantity += quantity;

        final scryId = 'scry_${cardName.replaceAll(' ', '_')}_p$printingNum';
        final oracleId = 'oracle_${cardName.replaceAll(' ', '_')}';

        rawItems.add(
          makeVaultItem(
            id: 'raw_item_$i',
            name: cardName,
            scryfallId: scryId,
            oracleId: oracleId,
            finish: finish,
            quantity: quantity,
            imageUrl: (rng.nextBool()) ? 'https://cards.scryfall.io/art_$i.jpg' : '',
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      final result = VaultVariantHelper.groupVaultItemsByVariant(rawItems);
      stopwatch.stop();

      // Invariant 1: Performance (< 250ms for 1000 items)
      expect(stopwatch.elapsedMilliseconds, lessThan(250),
          reason: 'Consolidation of 1000 items took ${stopwatch.elapsedMilliseconds}ms');

      // Invariant 2: Quantity Conservation (Sum of consolidated quantities == sum of raw quantities)
      final consolidatedTotalQuantity =
          result.items.fold<int>(0, (sum, item) => sum + item.quantity);
      expect(consolidatedTotalQuantity, equals(expectedTotalQuantity));

      // Invariant 3: Uniqueness of variant keys in output
      final outputKeys = result.items.map(VaultVariantHelper.computeVariantKey).toList();
      expect(outputKeys.length, equals(outputKeys.toSet().length));

      // Invariant 4: All raw IDs accounted for in variantToUnderlyingIds
      final allUnderlyingIds = <String>{};
      for (final ids in result.variantToUnderlyingIds.values) {
        allUnderlyingIds.addAll(ids);
      }
      expect(allUnderlyingIds.length, equals(rawItems.length));

      // Invariant 5: Idempotency (Re-grouping consolidated items produces identical output)
      final reGrouped = VaultVariantHelper.groupVaultItemsByVariant(result.items);
      expect(reGrouped.items.length, equals(result.items.length));
      final reGroupedKeys = reGrouped.items.map(VaultVariantHelper.computeVariantKey).toList();
      expect(reGroupedKeys, equals(outputKeys));
    });

    test('Selects the best representative item with image and richest dynamicData', () {
      final poorItem = makeVaultItem(
        id: 'poor-1',
        name: 'Sol Ring',
        scryfallId: 'scry-sol',
        finish: 'foil',
        quantity: 1,
        imageUrl: '',
      );
      final richItem = makeVaultItem(
        id: 'rich-2',
        name: 'Sol Ring',
        scryfallId: 'scry-sol',
        finish: 'foil',
        quantity: 2,
        imageUrl: 'https://cards.scryfall.io/sol_ring.jpg',
      );

      // Even if poorItem comes first
      final result = VaultVariantHelper.groupVaultItemsByVariant([poorItem, richItem]);
      expect(result.items.length, equals(1));
      final representative = result.items.first;
      expect(representative.id, equals('rich-2'));
      expect(representative.imageUrl, equals('https://cards.scryfall.io/sol_ring.jpg'));
      expect(representative.quantity, equals(3));
    });
  });

  // ===========================================================================
  // SECTION 4: AVAILABILITY ENGINE OVER-ALLOCATION & CLAMPING INVARIANTS
  // ===========================================================================
  group('Section 4: Availability Engine Over-Allocation & Clamping Invariants', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Formula never yields negative available quantity under extreme over-allocation', () async {
      final now = DateTime.now();
      const cardId = 'card-limited-edition';
      // User owns only 2 copies physically
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'The One Ring',
          setOrSeries: 'LTR',
          imageUrl: 'https://cards.scryfall.io/one_ring.jpg',
          quantity: const Value(2),
          condition: 'Near Mint',
          acquiredPrice: 50.0,
          acquiredDate: now,
          currentMarketPrice: 60.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Create 5 different assembled decks allocating 4 copies each (Total in-deck = 20 copies!)
      for (int i = 1; i <= 5; i++) {
        final deckId = 'deck-assembled-$i';
        final versionId = 'version-$i';
        await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: deckId,
            name: 'Overallocated Deck #$i',
            format: 'Commander',
            createdAt: now,
            isAssembled: const Value(true),
            isRegistered: const Value(true),
          ),
        );
        await db.into(db.deckVersions).insert(
          DeckVersionsCompanion.insert(
            id: versionId,
            deckId: deckId,
            versionNumber: 1,
            isActive: const Value(true),
            createdAt: now,
          ),
        );
        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi-$i',
            versionId: versionId,
            vaultItemId: cardId,
            boardZone: 'Mainboard',
            quantity: const Value(4),
            isProxy: const Value(false),
          ),
        );
      }

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map[cardId]!;

      // Invariant: Owned = 2, In Deck = 20, Available = 0 (MUST NOT BE -18)
      expect(avail.owned, equals(2));
      expect(avail.inDeck, equals(20));
      expect(avail.available, equals(0));
      expect(avail.available, isNot(isNegative));

      // Now progressively disassemble decks one by one and verify dynamic recovery
      // Disassemble deck 1, 2, 3, 4 (removes 16 allocated copies -> inDeck becomes 4, still > owned 2)
      for (int i = 1; i <= 4; i++) {
        await db.vaultDao.setDeckAssembled('deck-assembled-$i', false);
      }
      var updated = (await db.vaultDao.watchAllCardAvailability().first)[cardId]!;
      expect(updated.inDeck, equals(4));
      expect(updated.available, equals(0));

      // Disassemble deck 5 (removes final 4 copies -> inDeck becomes 0)
      await db.vaultDao.setDeckAssembled('deck-assembled-5', false);
      updated = (await db.vaultDao.watchAllCardAvailability().first)[cardId]!;
      expect(updated.inDeck, equals(0));
      expect(updated.available, equals(2)); // Available fully restored to owned!
    });

    test('Zero owned quantity card in deck yields Owned: 0, InDeck: X, Available: 0', () async {
      final now = DateTime.now();
      const cardId = 'card-zero-owned';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Zero Staple',
          setOrSeries: 'M11',
          imageUrl: '',
          quantity: const Value(0),
          condition: 'Near Mint',
          acquiredPrice: 0.0,
          acquiredDate: now,
          currentMarketPrice: 0.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-assembled-zero',
          name: 'Zero Deck',
          format: 'Modern',
          createdAt: now,
          isAssembled: const Value(true),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-zero',
          deckId: 'deck-assembled-zero',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-zero',
          versionId: 'ver-zero',
          vaultItemId: cardId,
          boardZone: 'Mainboard',
          quantity: const Value(2),
          isProxy: const Value(false),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map[cardId]!;
      expect(avail.owned, equals(0));
      expect(avail.inDeck, equals(2));
      expect(avail.available, equals(0));
    });
  });

  // ===========================================================================
  // SECTION 5: SOFT-DELETES & ENTITY ISOLATION INVARIANTS
  // ===========================================================================
  group('Section 5: Soft-Deletes & Entity Isolation Invariants', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Soft-deleted decks NEVER lock card availability and NEVER show active deck badges', () async {
      final now = DateTime.now();
      const cardId = 'card-soft-del-test';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Force of Will',
          setOrSeries: 'ALL',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 70.0,
          acquiredDate: now,
          currentMarketPrice: 70.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Create an assembled deck but soft-deleted (isDeleted = true)
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-deleted',
          name: 'Old Legacy Deck',
          format: 'Legacy',
          createdAt: now,
          isAssembled: const Value(true),
          isRegistered: const Value(true),
          isDeleted: const Value(true), // SOFT-DELETED
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-del',
          deckId: 'deck-deleted',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-del',
          versionId: 'ver-del',
          vaultItemId: cardId,
          boardZone: 'Mainboard',
          quantity: const Value(4),
          isProxy: const Value(false),
          isDeleted: const Value(false),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map[cardId]!;
      // Deleted deck must NOT reserve physical copies!
      expect(avail.owned, equals(4));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(4));

      // Active badges query must NOT include deleted deck
      final activeDecks = await db.vaultDao.watchCardActiveDecks(cardId).first;
      expect(activeDecks.isEmpty, isTrue);

      final allActive = await db.vaultDao.watchAllCardActiveDecks().first;
      expect(allActive.containsKey(cardId), isFalse);
    });

    test('Soft-deleted deck versions and deck version items do NOT lock availability', () async {
      final now = DateTime.now();
      const cardId = 'card-dv-del-test';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Counterspell',
          setOrSeries: 'EMA',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 1.0,
          acquiredDate: now,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-active-dvi-del',
          name: 'Active Deck',
          format: 'Modern',
          createdAt: now,
          isAssembled: const Value(true),
          isRegistered: const Value(true),
          isDeleted: const Value(false),
        ),
      );

      // Deck version 1 is soft-deleted
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-soft-del',
          deckId: 'deck-active-dvi-del',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
          isDeleted: const Value(true), // SOFT DELETED VERSION
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-v1',
          versionId: 'ver-soft-del',
          vaultItemId: cardId,
          boardZone: 'Mainboard',
          quantity: const Value(2),
          isProxy: const Value(false),
        ),
      );

      // Deck version 2 is active, but item itself is soft-deleted
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-active',
          deckId: 'deck-active-dvi-del',
          versionNumber: 2,
          isActive: const Value(true),
          createdAt: now,
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-soft-del-item',
          versionId: 'ver-active',
          vaultItemId: cardId,
          boardZone: 'Mainboard',
          quantity: const Value(2),
          isProxy: const Value(false),
          isDeleted: const Value(true), // SOFT DELETED ITEM
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map[cardId]!;
      expect(avail.owned, equals(4));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(4));
    });

    test('Inactive deck version (is_active = 0) does not lock availability', () async {
      final now = DateTime.now();
      const cardId = 'card-inactive-ver';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Cyclonic Rift',
          setOrSeries: 'RTR',
          imageUrl: '',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 35.0,
          acquiredDate: now,
          currentMarketPrice: 35.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-inactive-version-test',
          name: 'Commander Deck',
          format: 'Commander',
          createdAt: now,
          isAssembled: const Value(true),
          isRegistered: const Value(true),
        ),
      );
      // Inactive version (historical snapshot)
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-inactive',
          deckId: 'deck-inactive-version-test',
          versionNumber: 1,
          isActive: const Value(false), // INACTIVE VERSION
          createdAt: now,
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-inactive',
          versionId: 'ver-inactive',
          vaultItemId: cardId,
          boardZone: 'Mainboard',
          quantity: const Value(1),
          isProxy: const Value(false),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map[cardId]!;
      expect(avail.owned, equals(1));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(1));
    });

    test('Soft-deleted VaultItems are excluded from watchAllCardAvailability', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-deleted-vault-item',
          collectionType: 'mtg',
          name: 'Deleted Card',
          setOrSeries: 'LEA',
          imageUrl: '',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 10.0,
          acquiredDate: now,
          currentMarketPrice: 10.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          isDeleted: const Value(true), // DELETED
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      expect(map.containsKey('card-deleted-vault-item'), isFalse);
    });
  });

  // ===========================================================================
  // SECTION 6: PROXY CARDS ISOLATION INVARIANTS
  // ===========================================================================
  group('Section 6: Proxy Cards Isolation Invariants', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Mixing real and proxy allocations strictly tracks only physical cards', () async {
      final now = DateTime.now();
      const cardId = 'card-dual-land';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Underground Sea',
          setOrSeries: '3ED',
          imageUrl: '',
          quantity: const Value(2), // 2 physical copies
          condition: 'Near Mint',
          acquiredPrice: 700.0,
          acquiredDate: now,
          currentMarketPrice: 700.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Deck 1 (Assembled): 1 real copy, 3 proxy copies
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-1',
          name: 'CEDH Deck 1',
          format: 'Commander',
          createdAt: now,
          isAssembled: const Value(true),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-1',
          deckId: 'deck-1',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-real-1',
          versionId: 'ver-1',
          vaultItemId: cardId,
          boardZone: 'Mainboard',
          quantity: const Value(1),
          isProxy: const Value(false),
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-proxy-1',
          versionId: 'ver-1',
          vaultItemId: cardId,
          boardZone: 'Sideboard',
          quantity: const Value(3),
          isProxy: const Value(true),
        ),
      );

      // Deck 2 (Assembled): 10 proxy copies ONLY
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-2',
          name: 'Casual Proxy Deck',
          format: 'Commander',
          createdAt: now,
          isAssembled: const Value(true),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-2',
          deckId: 'deck-2',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-proxy-2',
          versionId: 'ver-2',
          vaultItemId: cardId,
          boardZone: 'Mainboard',
          quantity: const Value(10),
          isProxy: const Value(true),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map[cardId]!;

      // Invariant: Owned = 2, In Deck = 1 (only the real copy in Deck 1), Available = 1
      expect(avail.owned, equals(2));
      expect(avail.inDeck, equals(1));
      expect(avail.available, equals(1));

      // Active badges query should only return CEDH Deck 1, NOT Casual Proxy Deck
      final activeDecks = await db.vaultDao.watchCardActiveDecks(cardId).first;
      expect(activeDecks, contains('CEDH Deck 1'));
      expect(activeDecks.contains('Casual Proxy Deck'), isFalse);
    });
  });

  // ===========================================================================
  // SECTION 7: CONCURRENCY, RAPID STATE TOGGLES & RACE CONDITIONS
  // ===========================================================================
  group('Section 7: Concurrency, Rapid State Toggles & Race Conditions', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Rapid consecutive deck assembly toggles maintain consistent availability and sync queue', () async {
      final now = DateTime.now();
      const cardId = 'card-rapid-toggle';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Rhystic Study',
          setOrSeries: 'PCY',
          imageUrl: '',
          quantity: const Value(3),
          condition: 'Near Mint',
          acquiredPrice: 30.0,
          acquiredDate: now,
          currentMarketPrice: 30.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final deck = await db.vaultDao.createDeck('Rapid Deck', format: 'Commander');
      await db.vaultDao.addCardToDeck(deck.id, cardId, quantity: 2);

      // Perform 30 rapid state toggles
      for (int i = 0; i < 30; i++) {
        final shouldAssemble = i % 2 == 0;
        await db.vaultDao.setDeckAssembled(deck.id, shouldAssemble);
      }

      // Final state should be Disassembled (i=29 -> 29%2 != 0 -> false)
      final finalMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = finalMap[cardId]!;
      expect(avail.owned, equals(3));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(3));

      // Now set to true
      await db.vaultDao.setDeckAssembled(deck.id, true);
      final assembledMap = await db.vaultDao.watchAllCardAvailability().first;
      final assembledAvail = assembledMap[cardId]!;
      expect(assembledAvail.owned, equals(3));
      expect(assembledAvail.inDeck, equals(2));
      expect(assembledAvail.available, equals(1));

      // Check SyncQueue has recorded updates cleanly
      final syncRecords = await db.select(db.syncQueue).get();
      expect(syncRecords.where((s) => s.entityId == deck.id && s.operation == 'UPDATE').length, greaterThan(25));
    });

    test('Concurrent card additions to multiple assembled decks', () async {
      final now = DateTime.now();
      const cardId = 'card-concurrent-add';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Swords to Plowshares',
          setOrSeries: 'ICE',
          imageUrl: '',
          quantity: const Value(10),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final deck1 = await db.vaultDao.createDeck('Deck Alpha', isRegistered: true);
      final deck2 = await db.vaultDao.createDeck('Deck Beta', isRegistered: true);
      final deck3 = await db.vaultDao.createDeck('Deck Gamma', isRegistered: true);

      // Add cards in parallel
      await Future.wait([
        db.vaultDao.addCardToDeck(deck1.id, cardId, quantity: 2),
        db.vaultDao.addCardToDeck(deck2.id, cardId, quantity: 3),
        db.vaultDao.addCardToDeck(deck3.id, cardId, quantity: 1),
      ]);

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map[cardId]!;
      // Total in-deck must be 2 + 3 + 1 = 6
      expect(avail.owned, equals(10));
      expect(avail.inDeck, equals(6));
      expect(avail.available, equals(4));
    });
  });

  // ===========================================================================
  // SECTION 8: DATABASE CONSOLIDATION STRESS & FINISH ISOLATION
  // ===========================================================================
  group('Section 8: Database Consolidation Stress & Finish Isolation', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Consolidation strictly merges matching (scryfall_id, finish) and keeps differing finishes separate', () async {
      final now = DateTime.now();
      final olderDate = now.subtract(const Duration(days: 30));

      // Row 1: Sol Ring Foil (Primary - has primaryBinderId)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'sol-foil-1',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: 'https://cards.scryfall.io/sol_foil.jpg',
          quantity: const Value(2),
          condition: 'Near Mint',
          acquiredPrice: 5.0,
          acquiredDate: now,
          currentMarketPrice: 5.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('binder-edh'),
          dynamicData: jsonEncode({'scryfall_id': 'scry-sol-c21', 'finish': 'foil'}),
        ),
      );

      // Row 2: Sol Ring Foil (Duplicate)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'sol-foil-2',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: '',
          quantity: const Value(3),
          condition: 'Near Mint',
          acquiredPrice: 5.0,
          acquiredDate: olderDate,
          currentMarketPrice: 5.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({'scryfall_id': 'scry-sol-c21', 'finish': 'foil'}),
        ),
      );

      // Row 3: Sol Ring Nonfoil (Duplicate A)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'sol-nonfoil-1',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: '',
          quantity: const Value(1),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: olderDate,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({'scryfall_id': 'scry-sol-c21', 'finish': 'nonfoil'}),
        ),
      );

      // Row 4: Sol Ring Nonfoil (Duplicate B)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'sol-nonfoil-2',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: 'https://cards.scryfall.io/sol_nonfoil.jpg',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({'scryfall_id': 'scry-sol-c21', 'finish': 'nonfoil'}),
        ),
      );

      // Assign deck version item to the duplicate foil row
      final deck = await db.vaultDao.createDeck('Sol Ring Deck', isRegistered: true);
      final activeVersion = (await db.vaultDao.watchDeckVersions(deck.id).first).first;
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-sol-dup-foil',
          versionId: activeVersion.id,
          vaultItemId: 'sol-foil-2', // pointing to duplicate foil
          boardZone: 'Mainboard',
          quantity: const Value(1),
          isProxy: const Value(false),
        ),
      );

      // Execute consolidation
      final consolidatedCount = await db.vaultDao.consolidateDuplicateVaultItems();
      expect(consolidatedCount, equals(2)); // 1 duplicate foil + 1 duplicate nonfoil merged

      // Check Foil: Primary sol-foil-1 should survive with quantity 2 + 3 = 5
      final foilSurvivor = await (db.select(db.vaultItems)..where((t) => t.id.equals('sol-foil-1'))).getSingle();
      expect(foilSurvivor.quantity, equals(5));
      expect(foilSurvivor.isDeleted, isFalse);

      final foilSoftDeleted = await (db.select(db.vaultItems)..where((t) => t.id.equals('sol-foil-2'))).getSingle();
      expect(foilSoftDeleted.isDeleted, isTrue);

      // Check Nonfoil: Merged to quantity 1 + 4 = 5
      final nonfoilActive = await (db.select(db.vaultItems)
            ..where((t) => t.name.equals('Sol Ring') & t.isDeleted.equals(false)))
          .get();
      // Should have exactly 2 active Sol Ring records (1 foil, 1 nonfoil)
      expect(nonfoilActive.length, equals(2));

      // Verify DeckVersionItem was remapped from 'sol-foil-2' to 'sol-foil-1'
      final remappedDvi = await (db.select(db.deckVersionItems)
            ..where((t) => t.id.equals('dvi-sol-dup-foil')))
          .getSingle();
      expect(remappedDvi.vaultItemId, equals('sol-foil-1'));

      // Invariant: Idempotence (Calling a second time merges 0 rows)
      final secondRunCount = await db.vaultDao.consolidateDuplicateVaultItems();
      expect(secondRunCount, equals(0));
    });
  });

  // ===========================================================================
  // SECTION 9: PRESENTATION WIDGET STRESS & EXTREME QUANTITIES
  // ===========================================================================
  group('Section 9: Presentation Widget Stress & Extreme Quantities', () {
    testWidgets('VaultItemTile renders extreme quantities without RenderFlex overflow', (tester) async {
      final extremeItem = makeVaultItem(
        id: 'extreme-tile-1',
        name: 'Basic Island',
        quantity: 999999,
        scryfallId: 'scry-island',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardAvailabilityProvider.overrideWith(
              (ref) => Stream.value({
                'extreme-tile-1': const CardAvailability(
                  owned: 999999,
                  available: 888888,
                  inDeck: 111111,
                ),
              }),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemTile(
                item: extremeItem,
                hasMultipleVariants: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Owned: 999999'), findsOneWidget);
      expect(find.text('Available: 888888'), findsOneWidget);
      expect(find.text('In Deck: 111111'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('VaultItemCard renders availability breakdown without RenderFlex overflow', (tester) async {
      final cardItem = makeVaultItem(
        id: 'standard-card-1',
        name: 'Basic Island',
        quantity: 4,
        scryfallId: 'scry-island',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardAvailabilityProvider.overrideWith(
              (ref) => Stream.value({
                'standard-card-1': const CardAvailability(
                  owned: 4,
                  available: 3,
                  inDeck: 1,
                ),
              }),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1080, 2400)),
              child: Scaffold(
                body: VaultItemCard(
                  item: cardItem,
                  hasMultipleVariants: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Owned: 4'), findsOneWidget);
      expect(find.text('Available: 3'), findsOneWidget);
      expect(find.text('In Deck: 1'), findsOneWidget);
      final error = tester.takeException();
      if (error is FlutterError) {
        debugPrint('CAPTURED ERROR:\n${error.toStringDeep()}');
      }
      expect(error, isNull);
    });

    testWidgets('VaultItemCard renders 100x bulk lands under standard device dimensions without overflow', (tester) async {
      final bulkItem = makeVaultItem(
        id: 'bulk-card-1',
        name: 'Basic Island',
        quantity: 100,
        scryfallId: 'scry-island',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardAvailabilityProvider.overrideWith(
              (ref) => Stream.value({
                'bulk-card-1': const CardAvailability(
                  owned: 100,
                  available: 60,
                  inDeck: 40,
                ),
              }),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1080, 2400)),
              child: Scaffold(
                body: VaultItemCard(
                  item: bulkItem,
                  hasMultipleVariants: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Owned: 100'), findsOneWidget);
      expect(find.text('Available: 60'), findsOneWidget);
      expect(find.text('In Deck: 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid stream emissions in provider are reflected without widget crashes', (tester) async {
      final item = makeVaultItem(id: 'osc-item', name: 'Oscillating Card', quantity: 10);
      final streamController = ValueNotifier<CardAvailability>(
        const CardAvailability(owned: 10, available: 10, inDeck: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardAvailabilityProvider.overrideWith(
              (ref) => Stream.periodic(
                const Duration(milliseconds: 5),
                (i) => {
                  'osc-item': CardAvailability(
                    owned: 10,
                    available: 10 - (i % 10),
                    inDeck: i % 10,
                  ),
                },
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemTile(
                item: item,
                hasMultipleVariants: false,
              ),
            ),
          ),
        ),
      );

      // Pump several frames rapidly
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      streamController.dispose();
    });
  });
}

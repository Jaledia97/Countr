import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Precon Hydration & Seeding Service Tests', () {
    // =========================================================================
    // GROUP 1: Schema Mapping & Parent-Child Relationships
    // =========================================================================
    group('Drift Schema Mapping Invariants', () {
      test('Seeds all 12 precons into decks, deck_versions, deck_version_items, and vault_items', () async {
        expect(await PreconHydrationService.isHistoricalPreconSeeded(db), isFalse);

        await PreconHydrationService.seedHistoricalPrecons(db);

        expect(await PreconHydrationService.isHistoricalPreconSeeded(db), isTrue);

        // 1. Verify Decks Table (Precons)
        final preconDecks = await (db.select(db.decks)
              ..where((t) => t.id.like('precon-%')))
            .get();
        expect(preconDecks.length, equals(12), reason: 'Expected exactly 12 seeded precon decks');

        for (final deck in preconDecks) {
          expect(deck.id.startsWith('precon-'), isTrue);
          expect(deck.tcgDomain, equals('mtg'), reason: 'tcgDomain must be mtg');
          expect(deck.isRegistered, isTrue, reason: 'isRegistered must be true for precons');
          expect(deck.isAssembled, isFalse, reason: 'isAssembled must be false');
          expect(deck.isCompetitive, isFalse, reason: 'isCompetitive must be false');
          expect(deck.isCloned, isFalse, reason: 'isCloned must be false');
          expect(deck.isDeleted, isFalse, reason: 'isDeleted must be false');
        }

        // 2. Verify DeckVersions Table (Precons)
        final preconVersions = await (db.select(db.deckVersions)
              ..where((t) => t.id.like('precon-%')))
            .get();
        expect(preconVersions.length, equals(12), reason: 'Each precon deck must have exactly 1 active version');

        for (final version in preconVersions) {
          expect(version.versionNumber, equals(1));
          expect(version.isActive, isTrue);
          expect(version.isDeleted, isFalse);
        }

        // 3. Specific Deck Verification: Draconic Domination
        final c17 = preconDecks.firstWhere((d) => d.id == 'precon-c17-draconic-domination');
        expect(c17.name, equals('Draconic Domination'));
        expect(c17.format, equals('Commander'));
        expect(c17.coverItemId, equals('7e78b70b-0c67-4f14-8ad7-c9f8e3f59743'),
            reason: 'coverItemId must be set to the commander scryfallId');

        // Check Deck Version Items for C17
        final c17Items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals('${c17.id}-v1')))
            .get();

        expect(c17Items.isNotEmpty, isTrue);
        final totalCardsInC17 = c17Items.fold<int>(0, (sum, item) => sum + item.quantity);
        expect(totalCardsInC17, equals(100), reason: 'Commander precon must total 100 cards');

        // Check commander item
        final cmdrItem = c17Items.firstWhere((i) => i.boardZone == 'Commander');
        expect(cmdrItem.vaultItemId, equals('7e78b70b-0c67-4f14-8ad7-c9f8e3f59743'));
        expect(cmdrItem.quantity, equals(1));
        expect(cmdrItem.isProxy, isTrue, reason: 'Precon cards must be marked as proxy');
      });

      test('Maintains foreign key integrity across decks -> versions -> items -> vault_items', () async {
        await PreconHydrationService.seedHistoricalPrecons(db);

        // Verify all deck_versions reference valid deck IDs
        final invalidVersions = await db.customSelect('''
          SELECT dv.id 
          FROM deck_versions dv 
          LEFT JOIN decks d ON d.id = dv.deck_id 
          WHERE d.id IS NULL;
        ''').get();
        expect(invalidVersions.isEmpty, isTrue, reason: 'All deck versions must have valid parent decks');

        // Verify all deck_version_items reference valid deck_versions
        final orphanItemsByVersion = await db.customSelect('''
          SELECT dvi.id 
          FROM deck_version_items dvi 
          LEFT JOIN deck_versions dv ON dv.id = dvi.version_id 
          WHERE dv.id IS NULL;
        ''').get();
        expect(orphanItemsByVersion.isEmpty, isTrue,
            reason: 'All deck version items must have valid parent versions');

        // Verify all deck_version_items reference valid vault_items
        final orphanItemsByVault = await db.customSelect('''
          SELECT dvi.id 
          FROM deck_version_items dvi 
          LEFT JOIN vault_items vi ON vi.id = dvi.vault_item_id 
          WHERE vi.id IS NULL;
        ''').get();
        expect(orphanItemsByVault.isEmpty, isTrue,
            reason: 'All deck version items must have valid parent vault_items');
      });
    });

    // =========================================================================
    // GROUP 2: Catalog Synthesis & Inventory Invariant (Owned = Available + Allocated)
    // =========================================================================
    group('Catalog Synthesis & Inventory Invariant', () {
      test('Synthesized reference cards have quantity = 0 and do not inflate owned card totals', () async {
        // Track pre-existing items and owned totals
        final initialItems = await db.select(db.vaultItems).get();
        final initialCardIds = initialItems.map((i) => i.id).toSet();
        final initialOwned = await db.customSelect('''
          SELECT CAST(COALESCE(SUM(quantity), 0) AS INTEGER) as total_owned 
          FROM vault_items 
          WHERE quantity > 0 AND is_deleted = 0;
        ''').getSingle();
        final initialTotal = initialOwned.read<int>('total_owned');

        // Seed precons
        await PreconHydrationService.seedHistoricalPrecons(db);

        // Verify synthesized reference items in vault_items have quantity = 0 and acquiredPrice = 0.0
        final newlySynthesized = await (db.select(db.vaultItems)
              ..where((t) => t.id.isNotIn(initialCardIds)))
            .get();
        expect(newlySynthesized.isNotEmpty, isTrue);

        for (final item in newlySynthesized) {
          expect(item.quantity, equals(0),
              reason: 'Synthesized catalog reference card must have quantity = 0');
          expect(item.acquiredPrice, equals(0.0),
              reason: 'Synthesized catalog reference card must have acquiredPrice = 0.0');
        }

        // Owned total query must remain strictly unchanged
        final postSeedOwned = await db.customSelect('''
          SELECT CAST(COALESCE(SUM(quantity), 0) AS INTEGER) as total_owned 
          FROM vault_items 
          WHERE quantity > 0 AND is_deleted = 0;
        ''').getSingle();
        expect(postSeedOwned.read<int>('total_owned'), equals(initialTotal),
            reason: 'Seeding precons must not alter total owned cards');

        // Invariant check: Owned (0) = Available (0) + Allocated (0)
        final availabilityRows = await db.customSelect('''
          SELECT 
            vi.id,
            vi.quantity AS owned,
            COALESCE(alloc.total_allocated, 0) AS allocated,
            MAX(0, vi.quantity - COALESCE(alloc.total_allocated, 0)) AS available
          FROM vault_items vi
          LEFT JOIN (
            SELECT dvi.vault_item_id, SUM(dvi.quantity) AS total_allocated
            FROM deck_version_items dvi
            INNER JOIN deck_versions dv ON dv.id = dvi.version_id
            INNER JOIN decks d ON d.id = dv.deck_id
            WHERE dv.is_active = 1
              AND dvi.is_proxy = 0
              AND (d.is_assembled = 1 OR d.is_registered = 1)
              AND dvi.is_deleted = 0
              AND dv.is_deleted = 0
              AND d.is_deleted = 0
            GROUP BY dvi.vault_item_id
          ) alloc ON alloc.vault_item_id = vi.id
          WHERE vi.is_deleted = 0;
        ''').get();

        final newlySynthesizedIds = newlySynthesized.map((i) => i.id).toSet();
        for (final row in availabilityRows) {
          final id = row.read<String>('id');
          final owned = row.read<int>('owned');
          final allocated = row.read<int>('allocated');
          final available = row.read<int>('available');

          if (newlySynthesizedIds.contains(id)) {
            expect(owned, equals(0));
            expect(allocated, equals(0),
                reason: 'Allocated must be 0 because all precon cards are proxies (is_proxy = 1)');
            expect(available, equals(0));
            expect(owned, equals(available + allocated),
                reason: 'Core inventory invariant Owned = Available + Allocated must hold');
          }
        }
      });

      test('Pre-existing user owned card inventory is preserved upon precon seeding', () async {
        // User already owns a physical Sol Ring (quantity: 4, acquiredPrice: 2.50)
        final solRingId = 'aa626895-d166-4a49-8c67-6228383f98c8';
        final now = DateTime.now();

        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: solRingId,
                collectionType: 'mtg',
                name: 'Sol Ring',
                setOrSeries: 'C17',
                imageUrl: 'https://cards.scryfall.io/normal/front/a/a/sol-ring.jpg',
                acquiredPrice: 2.50,
                acquiredDate: now,
                quantity: const Value(4), // User owns 4 copies!
                condition: 'NM',
                currentMarketPrice: 2.50,
                lastPriceUpdate: now,
                dynamicData: '{"name":"Sol Ring","mana_cost":"{1}"}',
                isDeleted: const Value(false),
                updatedAt: Value(now),
              ),
            );

        // Seed precons (which contains Sol Ring in multiple Commander decks)
        await PreconHydrationService.seedHistoricalPrecons(db);

        // Verify user's owned Sol Ring was NOT overwritten with quantity = 0!
        final solRing = await (db.select(db.vaultItems)
              ..where((t) => t.id.equals(solRingId)))
            .getSingle();

        expect(solRing.quantity, equals(4),
            reason: 'User owned physical quantity must not be overwritten by precon seed');
        expect(solRing.acquiredPrice, equals(2.50),
            reason: 'User purchase price must not be overwritten by precon seed');

        // Check availability: Since precon entries are proxies (is_proxy = true),
        // they must NOT allocate the user's physical Sol Rings!
        final allocRow = await db.customSelect('''
          SELECT 
            vi.quantity AS owned,
            COALESCE(alloc.total_allocated, 0) AS allocated,
            MAX(0, vi.quantity - COALESCE(alloc.total_allocated, 0)) AS available
          FROM vault_items vi
          LEFT JOIN (
            SELECT dvi.vault_item_id, SUM(dvi.quantity) AS total_allocated
            FROM deck_version_items dvi
            INNER JOIN deck_versions dv ON dv.id = dvi.version_id
            INNER JOIN decks d ON d.id = dv.deck_id
            WHERE dv.is_active = 1
              AND dvi.is_proxy = 0
              AND (d.is_assembled = 1 OR d.is_registered = 1)
              AND dvi.is_deleted = 0
              AND dv.is_deleted = 0
              AND d.is_deleted = 0
            GROUP BY dvi.vault_item_id
          ) alloc ON alloc.vault_item_id = vi.id
          WHERE vi.id = ?;
        ''', variables: [Variable.withString(solRingId)]).getSingle();

        expect(allocRow.read<int>('owned'), equals(4));
        expect(allocRow.read<int>('allocated'), equals(0),
            reason: 'Precon Sol Rings are marked is_proxy = true, so allocated must remain 0');
        expect(allocRow.read<int>('available'), equals(4),
            reason: 'Available physical copies must remain 4');
      });
    });

    // =========================================================================
    // GROUP 3: Idempotency & Repeated Seeding
    // =========================================================================
    group('Atomic Idempotency & Repeat Protection', () {
      test('Sequential repeated default seeding (force: false) is an immediate no-op', () async {
        // Run 1: seeds catalog
        await PreconHydrationService.seedHistoricalPrecons(db, force: false);
        final initialRow =
            await db.customSelect("SELECT COUNT(*) as c FROM decks WHERE id LIKE 'precon-%';").getSingle();
        expect(initialRow.read<int>('c'), equals(12));

        // Runs 2-5: should skip immediately
        for (int i = 2; i <= 5; i++) {
          await PreconHydrationService.seedHistoricalPrecons(db, force: false);
          final deckCount =
              (await db.customSelect("SELECT COUNT(*) as c FROM decks WHERE id LIKE 'precon-%';").getSingle())
                  .read<int>('c');
          expect(deckCount, equals(12),
              reason: 'Run $i with force: false must not change deck count');
        }
      });

      test('Sequential 5x forced seeding (force: true) produces exactly 0 duplicate rows', () async {
        for (int iteration = 1; iteration <= 5; iteration++) {
          await PreconHydrationService.seedHistoricalPrecons(db, force: true);

          final deckCount =
              (await db.customSelect("SELECT COUNT(*) as c FROM decks WHERE id LIKE 'precon-%';").getSingle())
                  .read<int>('c');
          expect(deckCount, equals(12),
              reason: 'Iteration $iteration must have exactly 12 decks');
        }

        // 1. Verify 0 duplicate deck IDs
        final dupDecks = await db.customSelect('''
          SELECT id, COUNT(*) as c 
          FROM decks 
          GROUP BY id 
          HAVING c > 1;
        ''').get();
        expect(dupDecks.isEmpty, isTrue, reason: 'Zero duplicate deck IDs allowed');

        // 2. Verify 0 duplicate version IDs
        final dupVersions = await db.customSelect('''
          SELECT id, COUNT(*) as c 
          FROM deck_versions 
          GROUP BY id 
          HAVING c > 1;
        ''').get();
        expect(dupVersions.isEmpty, isTrue, reason: 'Zero duplicate version IDs allowed');

        // 3. Verify 0 duplicate item IDs
        final dupItems = await db.customSelect('''
          SELECT id, COUNT(*) as c 
          FROM deck_version_items 
          GROUP BY id 
          HAVING c > 1;
        ''').get();
        expect(dupItems.isEmpty, isTrue, reason: 'Zero duplicate deck_version_items IDs allowed');

        // 4. Verify 0 duplicate vault_item IDs
        final dupVault = await db.customSelect('''
          SELECT id, COUNT(*) as c 
          FROM vault_items 
          GROUP BY id 
          HAVING c > 1;
        ''').get();
        expect(dupVault.isEmpty, isTrue, reason: 'Zero duplicate vault_items IDs allowed');
      });
    });

    // =========================================================================
    // GROUP 4: Background Isolate Operations
    // =========================================================================
    group('Background Isolate Operations', () {
      test('parseJsonInIsolate and parseBytesInIsolate execute successfully off main thread', () async {
        const sampleJson = '''
        [
          {
            "id": "precon-iso-test",
            "name": "Isolate Test Deck",
            "format": "Commander",
            "cards": [
              {
                "name": "Command Tower",
                "scryfall_id": "tower-uuid",
                "count": 1,
                "board_zone": "Mainboard"
              }
            ]
          }
        ]
        ''';

        final dtos = await PreconHydrationService.parseJsonInIsolate(sampleJson);
        expect(dtos.length, equals(1));
        expect(dtos.first.name, equals('Isolate Test Deck'));
        expect(dtos.first.mainboardCards.first.name, equals('Command Tower'));
      });
    });
  });
}

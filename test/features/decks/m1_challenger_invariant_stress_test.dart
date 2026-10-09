import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    // Enable PRAGMA foreign_keys = ON to strictly enforce relational constraints
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    // Clear initial starter items in reverse foreign key order so tests start with a clean user state
    await db.delete(db.deckVersionItems).go();
    await db.delete(db.deckVersions).go();
    await db.delete(db.decks).go();
    await db.delete(db.vaultItems).go();
  });

  tearDown(() async {
    await db.close();
  });

  group('M1 Challenger Adversarial Stress Tests', () {
    // =========================================================================
    // SUITE 1: ADVERSARIAL INVARIANT STRESS TESTS (Owned = Available + Allocated)
    // =========================================================================
    group('Suite 1: Inventory Invariant & Vault Totals Preservation', () {
      test(
        '1.1 Clean User State: watchVaultTotals reports 0 cards owned and \$0.00 value after seeding all 12 precons',
        () async {
          // Pre-seed check
          final preTotals = await db.vaultDao.watchVaultTotals().first;
          expect(preTotals.totalCount, equals(0));
          expect(preTotals.totalMarketValue, equals(0.0));
          expect(preTotals.totalCostBasis, equals(0.0));

          // Seed all 12 precons
          await PreconHydrationService.seedHistoricalPrecons(db);

          // Post-seed check - global totals
          final postTotals = await db.vaultDao.watchVaultTotals().first;
          expect(
            postTotals.totalCount,
            equals(0),
            reason: 'Seeding precons must not inflate owned card count for a clean user',
          );
          expect(
            postTotals.totalMarketValue,
            equals(0.0),
            reason: 'Total market value must remain \$0.00 for unowned catalog reference cards',
          );
          expect(
            postTotals.totalCostBasis,
            equals(0.0),
            reason: 'Total cost basis must remain \$0.00 for unowned catalog reference cards',
          );

          // Post-seed check - MTG scoped totals
          final mtgTotals =
              await db.vaultDao.watchVaultTotals(collectionType: 'mtg').first;
          expect(mtgTotals.totalCount, equals(0));
          expect(mtgTotals.totalMarketValue, equals(0.0));
          expect(mtgTotals.totalCostBasis, equals(0.0));
        },
      );

      test(
        '1.2 Exhaustive Invariant Scan: Owned = Available + Allocated holds across every single card in vault_items',
        () async {
          await PreconHydrationService.seedHistoricalPrecons(db);

          // Query every single item synthesized in vault_items
          final allItems = await db.select(db.vaultItems).get();
          expect(
            allItems.length,
            greaterThanOrEqualTo(150),
            reason: 'Expected 150+ unique cards across 12 MTG preconstructed decks',
          );

          for (final item in allItems) {
            final owned = item.quantity;
            expect(
              owned,
              equals(0),
              reason: 'Synthesized card ${item.name} (${item.id}) must have quantity = 0',
            );
            expect(
              item.acquiredPrice,
              equals(0.0),
              reason: 'Synthesized card ${item.name} (${item.id}) must have acquiredPrice = 0.0',
            );

            // Compute allocated quantity directly from deck_version_items
            final allocRow = await db.customSelect(
              '''
              SELECT CAST(COALESCE(SUM(dvi.quantity), 0) AS INTEGER) AS total_allocated
              FROM deck_version_items dvi
              INNER JOIN deck_versions dv ON dv.id = dvi.version_id
              INNER JOIN decks d ON d.id = dv.deck_id
              WHERE dv.is_active = 1
                AND dvi.is_proxy = 0
                AND (d.is_assembled = 1 OR d.is_registered = 1)
                AND dvi.is_deleted = 0
                AND dv.is_deleted = 0
                AND d.is_deleted = 0
                AND dvi.vault_item_id = ?;
              ''',
              variables: [Variable.withString(item.id)],
            ).getSingle();
            final allocated = allocRow.read<int>('total_allocated');
            expect(
              allocated,
              equals(0),
              reason: 'Precon item ${item.name} is proxy, so allocated must be 0',
            );

            // Check availability via VaultDao
            final available = await db.vaultDao.getAvailableQuantity(item.id);
            expect(
              available,
              equals(0),
              reason: 'Available quantity for unowned card ${item.name} must be 0',
            );

            // Core Invariant
            expect(
              owned,
              equals(available + allocated),
              reason: 'Invariant Owned ($owned) = Available ($available) + Allocated ($allocated) failed for ${item.name}',
            );
          }
        },
      );

      test(
        '1.3 Pre-existing owned cards (e.g. 3 copies of Sol Ring) retain exact quantity, availability, and attributes after precon seeding',
        () async {
          final now = DateTime.now();
          const solRingId = 'aa626895-d166-4a49-8c67-6228383f98c8';
          const urDragonId = '7e78b70b-0c67-4f14-8ad7-c9f8e3f59743';
          const customLotusId = 'custom-user-black-lotus';

          // Inject pre-existing cards:
          // 1. 3 copies of Sol Ring (present in multiple Commander precons)
          await db.into(db.vaultItems).insert(
                VaultItemsCompanion.insert(
                  id: solRingId,
                  collectionType: 'mtg',
                  name: 'Sol Ring',
                  setOrSeries: 'Commander 2017',
                  imageUrl: 'https://cards.scryfall.io/normal/front/a/a/sol-ring-custom.jpg',
                  acquiredPrice: 3.50,
                  acquiredDate: now.subtract(const Duration(days: 30)),
                  quantity: const Value(3),
                  condition: 'SP',
                  currentMarketPrice: 2.75,
                  lastPriceUpdate: now,
                  dynamicData: '{"name":"Sol Ring","mana_cost":"{1}"}',
                  isDeleted: const Value(false),
                  updatedAt: Value(now),
                ),
              );

          // 2. 1 copy of The Ur-Dragon (commander of C17 Draconic Domination)
          await db.into(db.vaultItems).insert(
                VaultItemsCompanion.insert(
                  id: urDragonId,
                  collectionType: 'mtg',
                  name: 'The Ur-Dragon',
                  setOrSeries: 'Commander 2017',
                  imageUrl: 'https://cards.scryfall.io/normal/front/7/e/ur-dragon-custom.jpg',
                  acquiredPrice: 55.00,
                  acquiredDate: now.subtract(const Duration(days: 60)),
                  quantity: const Value(1),
                  condition: 'NM',
                  currentMarketPrice: 65.00,
                  lastPriceUpdate: now,
                  dynamicData: '{"name":"The Ur-Dragon","cmc":9.0}',
                  isDeleted: const Value(false),
                  updatedAt: Value(now),
                ),
              );

          // 3. 4 copies of Black Lotus (unrelated to precons)
          await db.into(db.vaultItems).insert(
                VaultItemsCompanion.insert(
                  id: customLotusId,
                  collectionType: 'mtg',
                  name: 'Black Lotus',
                  setOrSeries: 'Vintage',
                  imageUrl: 'https://cards.scryfall.io/normal/front/b/l/lotus.jpg',
                  acquiredPrice: 10000.00,
                  acquiredDate: now.subtract(const Duration(days: 100)),
                  quantity: const Value(4),
                  condition: 'EX',
                  currentMarketPrice: 12000.00,
                  lastPriceUpdate: now,
                  dynamicData: '{"name":"Black Lotus","cmc":0.0}',
                  isDeleted: const Value(false),
                  updatedAt: Value(now),
                ),
              );

          // Pre-seed totals verification (3 + 1 + 4 = 8 owned cards)
          final preTotals = await db.vaultDao.watchVaultTotals().first;
          expect(preTotals.totalCount, equals(8));
          expect(preTotals.uniqueCount, equals(3));
          expect(
            preTotals.totalCostBasis,
            closeTo(3 * 3.50 + 1 * 55.00 + 4 * 10000.00, 0.01),
          );

          // Now seed all 12 precons
          await PreconHydrationService.seedHistoricalPrecons(db);

          // Verify Sol Ring integrity
          final solRing = await (db.select(db.vaultItems)
                ..where((t) => t.id.equals(solRingId)))
              .getSingle();
          expect(solRing.quantity, equals(3),
              reason: 'Owned Sol Ring count must remain strictly 3');
          expect(solRing.acquiredPrice, equals(3.50),
              reason: 'Sol Ring acquiredPrice must remain unchanged');
          expect(solRing.condition, equals('SP'),
              reason: 'Sol Ring condition must remain SP');

          final solRingAvail = await db.vaultDao.getAvailableQuantity(solRingId);
          expect(solRingAvail, equals(3),
              reason: 'Available Sol Ring count must remain strictly 3');

          // Verify The Ur-Dragon integrity
          final urDragon = await (db.select(db.vaultItems)
                ..where((t) => t.id.equals(urDragonId)))
              .getSingle();
          expect(urDragon.quantity, equals(1),
              reason: 'Owned The Ur-Dragon count must remain strictly 1');
          expect(urDragon.acquiredPrice, equals(55.00),
              reason: 'The Ur-Dragon acquiredPrice must remain unchanged');

          final urDragonAvail = await db.vaultDao.getAvailableQuantity(urDragonId);
          expect(urDragonAvail, equals(1),
              reason: 'Available The Ur-Dragon count must remain strictly 1');

          // Verify Black Lotus integrity
          final lotus = await (db.select(db.vaultItems)
                ..where((t) => t.id.equals(customLotusId)))
              .getSingle();
          expect(lotus.quantity, equals(4));
          final lotusAvail = await db.vaultDao.getAvailableQuantity(customLotusId);
          expect(lotusAvail, equals(4));

          // Post-seed totals check: exactly the 8 pre-existing cards, 0 phantom additions
          final postTotals = await db.vaultDao.watchVaultTotals().first;
          expect(
            postTotals.totalCount,
            equals(8),
            reason: 'watchVaultTotals totalCount must still be exactly 8',
          );
          expect(
            postTotals.uniqueCount,
            equals(3),
            reason: 'watchVaultTotals uniqueCount must still be exactly 3',
          );
        },
      );

      test(
        '1.4 Hybrid Physical Allocation: Personal deck allocating 2 Sol Rings leaves 1 available while precons remain proxy',
        () async {
          final now = DateTime.now();
          const solRingId = 'aa626895-d166-4a49-8c67-6228383f98c8';

          // User owns 3 Sol Rings
          await db.into(db.vaultItems).insert(
                VaultItemsCompanion.insert(
                  id: solRingId,
                  collectionType: 'mtg',
                  name: 'Sol Ring',
                  setOrSeries: 'Commander 2017',
                  imageUrl: 'https://cards.scryfall.io/normal/front/a/a/sol-ring.jpg',
                  acquiredPrice: 3.00,
                  acquiredDate: now,
                  quantity: const Value(3),
                  condition: 'NM',
                  currentMarketPrice: 2.75,
                  lastPriceUpdate: now,
                  dynamicData: '{"name":"Sol Ring"}',
                  isDeleted: const Value(false),
                  updatedAt: Value(now),
                ),
              );

          // Seed precons
          await PreconHydrationService.seedHistoricalPrecons(db);

          // Before user allocates: Owned = 3, Available = 3, Allocated = 0
          expect(await db.vaultDao.getAvailableQuantity(solRingId), equals(3));

          // User creates a personal assembled deck allocating 2 physical Sol Rings (isProxy = false)
          const personalDeckId = 'deck-my-personal-edh';
          const personalVersionId = 'deck-my-personal-edh-v1';

          await db.into(db.decks).insert(
                DecksCompanion.insert(
                  id: personalDeckId,
                  name: 'My Personal EDH',
                  format: 'Commander',
                  tcgDomain: const Value('mtg'),
                  isRegistered: const Value(true),
                  isAssembled: const Value(true),
                  createdAt: now,
                  updatedAt: Value(now),
                ),
              );

          await db.into(db.deckVersions).insert(
                DeckVersionsCompanion.insert(
                  id: personalVersionId,
                  deckId: personalDeckId,
                  versionNumber: 1,
                  isActive: const Value(true),
                  createdAt: now,
                  updatedAt: Value(now),
                ),
              );

          await db.into(db.deckVersionItems).insert(
                DeckVersionItemsCompanion.insert(
                  id: 'personal-item-sol-ring-1',
                  versionId: personalVersionId,
                  vaultItemId: solRingId,
                  quantity: const Value(2),
                  boardZone: 'Mainboard',
                  isProxy: const Value(false), // PHYSICAL ALLOCATION
                  updatedAt: Value(now),
                ),
              );

          // Verify updated state:
          // Owned = 3
          // Allocated = 2 (from personal deck, precon proxies add 0)
          // Available = 1 (3 - 2 = 1)
          final solRingItem = await (db.select(db.vaultItems)
                ..where((t) => t.id.equals(solRingId)))
              .getSingle();
          final owned = solRingItem.quantity;
          final available = await db.vaultDao.getAvailableQuantity(solRingId);

          final allocRow = await db.customSelect(
            '''
            SELECT CAST(COALESCE(SUM(dvi.quantity), 0) AS INTEGER) AS total_allocated
            FROM deck_version_items dvi
            INNER JOIN deck_versions dv ON dv.id = dvi.version_id
            INNER JOIN decks d ON d.id = dv.deck_id
            WHERE dv.is_active = 1
              AND dvi.is_proxy = 0
              AND (d.is_assembled = 1 OR d.is_registered = 1)
              AND dvi.is_deleted = 0
              AND dv.is_deleted = 0
              AND d.is_deleted = 0
              AND dvi.vault_item_id = ?;
            ''',
            variables: [Variable.withString(solRingId)],
          ).getSingle();
          final allocated = allocRow.read<int>('total_allocated');

          expect(owned, equals(3));
          expect(allocated, equals(2));
          expect(available, equals(1));
          expect(
            owned,
            equals(available + allocated),
            reason: 'Invariant Owned (3) = Available (1) + Allocated (2) must hold exactly',
          );
        },
      );
    });

    // =========================================================================
    // SUITE 2: ADVERSARIAL IDEMPOTENCY STRESS TESTS (10x Sequential Seeding)
    // =========================================================================
    group('Suite 2: 10x Rapid Sequential Seeding & Idempotency', () {
      test(
        '2.1 10x rapid sequential default seeding (force: false) produces 0 collisions and exits cleanly',
        () async {
          // Iteration 1: Initial hydration
          await PreconHydrationService.seedHistoricalPrecons(db, force: false);
          expect(await PreconHydrationService.isHistoricalPreconSeeded(db), isTrue);

          final baselineDecks = await (db.select(db.decks)
                ..where((t) => t.id.like('precon-%')))
              .get();
          expect(baselineDecks.length, equals(12));

          final baselineVersions = await (db.select(db.deckVersions)
                ..where((t) => t.id.like('precon-%')))
              .get();
          expect(baselineVersions.length, equals(12));

          final baselineItems = await (db.select(db.deckVersionItems)
                ..where((t) => t.versionId.like('precon-%')))
              .get();
          final baselineVaultItems = await db.select(db.vaultItems).get();

          // Iterations 2 to 10: rapid successive calls
          for (int run = 2; run <= 10; run++) {
            final sw = Stopwatch()..start();
            await PreconHydrationService.seedHistoricalPrecons(db, force: false);
            sw.stop();

            // Default seeding check should be lightning-fast (< 50ms)
            expect(sw.elapsedMilliseconds, lessThan(100),
                reason: 'Run $run with force: false should fast-path return');

            final deckCount = (await db.customSelect(
              "SELECT COUNT(*) as c FROM decks WHERE id LIKE 'precon-%';",
            ).getSingle()).read<int>('c');
            expect(deckCount, equals(12), reason: 'Run $run must not alter deck count');
          }

          // Verify exact row counts after 10 runs
          final finalVersions = await (db.select(db.deckVersions)
                ..where((t) => t.id.like('precon-%')))
              .get();
          expect(finalVersions.length, equals(baselineVersions.length));

          final finalItems = await (db.select(db.deckVersionItems)
                ..where((t) => t.versionId.like('precon-%')))
              .get();
          expect(finalItems.length, equals(baselineItems.length));

          final finalVaultItems = await db.select(db.vaultItems).get();
          expect(finalVaultItems.length, equals(baselineVaultItems.length));
        },
      );

      test(
        '2.2 10x rapid sequential forced seeding (force: true) produces 0 primary key collisions and 0 duplicate rows',
        () async {
          // Perform 10 consecutive forced seeding operations
          for (int iteration = 1; iteration <= 10; iteration++) {
            await PreconHydrationService.seedHistoricalPrecons(db, force: true);

            final deckCount = (await db.customSelect(
              "SELECT COUNT(*) as c FROM decks WHERE id LIKE 'precon-%';",
            ).getSingle()).read<int>('c');
            expect(
              deckCount,
              equals(12),
              reason: 'Iteration $iteration with force: true must have exactly 12 decks',
            );
          }

          // Check 1: Duplicate check for decks
          final dupDecks = await db.customSelect('''
            SELECT id, COUNT(*) as c 
            FROM decks 
            GROUP BY id 
            HAVING c > 1;
          ''').get();
          expect(dupDecks.isEmpty, isTrue,
              reason: 'Duplicate check on decks returned rows: $dupDecks');

          // Check 2: Duplicate check for deck_versions
          final dupVersions = await db.customSelect('''
            SELECT id, COUNT(*) as c 
            FROM deck_versions 
            GROUP BY id 
            HAVING c > 1;
          ''').get();
          expect(dupVersions.isEmpty, isTrue,
              reason: 'Duplicate check on deck_versions returned rows: $dupVersions');

          // Check 3: Duplicate check for deck_version_items
          final dupItems = await db.customSelect('''
            SELECT id, COUNT(*) as c 
            FROM deck_version_items 
            GROUP BY id 
            HAVING c > 1;
          ''').get();
          expect(dupItems.isEmpty, isTrue,
              reason: 'Duplicate check on deck_version_items returned rows: $dupItems');

          // Check 4: Duplicate check for vault_items
          final dupVault = await db.customSelect('''
            SELECT id, COUNT(*) as c 
            FROM vault_items 
            GROUP BY id 
            HAVING c > 1;
          ''').get();
          expect(dupVault.isEmpty, isTrue,
              reason: 'Duplicate check on vault_items returned rows: $dupVault');

          // Check 5: Verify foreign keys after 10 forced runs
          final orphanItems = await db.customSelect('''
            SELECT dvi.id 
            FROM deck_version_items dvi
            LEFT JOIN deck_versions dv ON dv.id = dvi.version_id
            LEFT JOIN vault_items vi ON vi.id = dvi.vault_item_id
            WHERE dv.id IS NULL OR vi.id IS NULL;
          ''').get();
          expect(orphanItems.isEmpty, isTrue,
              reason: 'Zero orphan deck_version_items allowed after 10 forced runs');
        },
      );

      test(
        '2.3 Concurrent burst seeding (10 simultaneous calls) gracefully handled without deadlock or corruption',
        () async {
          // Launch 10 simultaneous calls in parallel
          final futures = List.generate(
            10,
            (i) => PreconHydrationService.seedHistoricalPrecons(
              db,
              force: i == 0,
            ),
          );

          await Future.wait(futures);

          // Verify database ended in a consistent state
          expect(await PreconHydrationService.isHistoricalPreconSeeded(db), isTrue);

          final deckCount = (await db.customSelect(
            "SELECT COUNT(*) as c FROM decks WHERE id LIKE 'precon-%';",
          ).getSingle()).read<int>('c');
          expect(deckCount, equals(12));

          // Verify zero duplicates
          final dupDecks = await db.customSelect('''
            SELECT id, COUNT(*) as c FROM decks GROUP BY id HAVING c > 1;
          ''').get();
          expect(dupDecks.isEmpty, isTrue);
        },
      );
    });

    // =========================================================================
    // SUITE 3: DATABASE INTEGRITY & RELATIONAL PRAGMA VERIFICATION
    // =========================================================================
    group('Suite 3: SQLite Database Integrity & PRAGMA Checks', () {
      test(
        '3.1 PRAGMA foreign_key_check returns 0 violations after full precon seeding',
        () async {
          await PreconHydrationService.seedHistoricalPrecons(db);

          // Run SQLite native foreign key integrity check
          final fkViolations =
              await db.customSelect('PRAGMA foreign_key_check;').get();

          expect(
            fkViolations.isEmpty,
            isTrue,
            reason: 'PRAGMA foreign_key_check reported violations: $fkViolations',
          );
        },
      );

      test(
        '3.2 Precon structure & zone compliance across all 12 decks',
        () async {
          await PreconHydrationService.seedHistoricalPrecons(db);

          final preconDecks = await (db.select(db.decks)
                ..where((t) => t.id.like('precon-%')))
              .get();
          expect(preconDecks.length, equals(12));

          for (final deck in preconDecks) {
            // Version check
            final versions = await (db.select(db.deckVersions)
                  ..where((t) => t.deckId.equals(deck.id)))
                .get();
            expect(versions.length, equals(1));
            final version = versions.first;
            expect(version.isActive, isTrue);

            // Item check
            final items = await (db.select(db.deckVersionItems)
                  ..where((t) => t.versionId.equals(version.id)))
                .get();
            expect(items.isNotEmpty, isTrue);

            // All items must be marked isProxy = true
            for (final item in items) {
              expect(item.isProxy, isTrue,
                  reason: 'Every precon card item must be marked isProxy = true');
              expect(item.quantity, greaterThan(0),
                  reason: 'Card item quantity must be positive');
            }

            final totalCards =
                items.fold<int>(0, (sum, item) => sum + item.quantity);

            // Verify specific format constraints
            if (deck.format == 'Commander') {
              expect(totalCards, greaterThanOrEqualTo(100),
                  reason: 'Commander deck ${deck.name} must total at least 100 cards');
              expect(deck.coverItemId, isNotNull,
                  reason: 'Commander deck ${deck.name} must specify coverItemId');

              final commanders =
                  items.where((i) => i.boardZone == 'Commander').toList();
              expect(commanders.isNotEmpty, isTrue,
                  reason: 'Commander deck ${deck.name} must have a Commander zone card');
            } else if (deck.format == 'Challenger') {
              expect(totalCards, greaterThanOrEqualTo(60),
                  reason: 'Challenger deck ${deck.name} must total at least 60 cards');
              final mainCount = items
                  .where((i) => i.boardZone == 'Mainboard')
                  .fold<int>(0, (s, i) => s + i.quantity);
              final sideCount = items
                  .where((i) => i.boardZone == 'Sideboard')
                  .fold<int>(0, (s, i) => s + i.quantity);
              expect(mainCount, greaterThanOrEqualTo(50));
              expect(sideCount, greaterThan(0),
                  reason: 'Challenger decks must include sideboard cards');
            } else {
              expect(totalCards, greaterThanOrEqualTo(60),
                  reason: '${deck.format} ${deck.name} must total at least 60 cards');
            }
          }
        },
      );
    });
  });
}

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_totals.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

VaultItemsCompanion createTestItem({
  required String id,
  required String collectionType,
  required String name,
  int quantity = 1,
  double marketPrice = 10.0,
  double costBasis = 5.0,
  String? binderId,
}) {
  return VaultItemsCompanion.insert(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: 'Stress Set',
    imageUrl: 'https://example.com/$id.png',
    acquiredPrice: costBasis,
    acquiredDate: DateTime(2026, 1, 1),
    quantity: drift.Value(quantity),
    condition: 'NM',
    currentMarketPrice: marketPrice,
    lastPriceUpdate: DateTime(2026, 1, 1),
    dynamicData: '{}',
    primaryBinderId:
        binderId != null ? drift.Value(binderId) : const drift.Value.absent(),
  );
}

void main() {
  late AppDatabase db;
  late VaultDao dao;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial Stress Test: Rapid Mutations & Stream Concurrency', () {
    test('50 rapid consecutive inserts emit accurate settled totals without stream drop', () async {
      final emittedValues = <VaultTotals>[];
      final subscription = dao.watchVaultTotals().listen(emittedValues.add);

      // Initial emission from seed (4 items, $438.75 market, $189.50 cost)
      await pumpEventQueue(times: 20);
      expect(emittedValues.isNotEmpty, isTrue);
      final initialSeedCount = emittedValues.first.totalCount;
      expect(initialSeedCount, 4);

      const count = 50;
      double addedMarket = 0.0;
      double addedCost = 0.0;

      for (int i = 1; i <= count; i++) {
        final price = 10.0 + i;
        final cost = 5.0 + i;
        addedMarket += price * 2; // quantity = 2
        addedCost += cost * 2;

        await db.into(db.vaultItems).insert(
              createTestItem(
                id: 'rapid-insert-$i',
                collectionType: 'mtg',
                name: 'Rapid Card $i',
                quantity: 2,
                marketPrice: price,
                costBasis: cost,
              ),
            );
      }

      await pumpEventQueue(times: 50);

      final latest = emittedValues.last;
      final expectedCount = 4 + (count * 2);
      final expectedMarket = 438.75 + addedMarket;
      final expectedCost = 189.50 + addedCost;

      expect(latest.totalCount, equals(expectedCount));
      expect(latest.totalMarketValue, closeTo(expectedMarket, 0.001));
      expect(latest.totalCostBasis, closeTo(expectedCost, 0.001));

      // Direct one-shot query verification
      final oneShot = await dao.getVaultTotals();
      expect(oneShot.totalCount, equals(expectedCount));
      expect(oneShot.totalMarketValue, closeTo(expectedMarket, 0.001));
      expect(oneShot.totalCostBasis, closeTo(expectedCost, 0.001));

      await subscription.cancel();
    });

    test('50 rapid updates correctly recalculate totals and re-emit without stale state', () async {
      // Seed 50 items first
      const count = 50;
      for (int i = 1; i <= count; i++) {
        await db.into(db.vaultItems).insert(
              createTestItem(
                id: 'update-target-$i',
                collectionType: 'pokemon',
                name: 'Target Card $i',
                quantity: 1,
                marketPrice: 5.0,
                costBasis: 2.0,
              ),
            );
      }

      final emittedValues = <VaultTotals>[];
      final subscription = dao.watchVaultTotals().listen(emittedValues.add);
      await pumpEventQueue(times: 20);

      // Rapidly update all 50 items: quantity 1 -> 5, marketPrice 5.0 -> 25.0
      for (int i = 1; i <= count; i++) {
        await (db.update(db.vaultItems)..where((t) => t.id.equals('update-target-$i'))).write(
          const VaultItemsCompanion(
            quantity: drift.Value(5),
            currentMarketPrice: drift.Value(25.0),
          ),
        );
      }

      await pumpEventQueue(times: 50);

      final latest = emittedValues.last;
      // 4 seed items + 50 items * 5 quantity = 4 + 250 = 254
      expect(latest.totalCount, equals(254));
      // Seed market: 438.75; 50 * (5 * 25.0) = 6250.0
      expect(latest.totalMarketValue, closeTo(438.75 + 6250.0, 0.001));
      // Seed cost: 189.50; 50 * (5 * 2.0) = 500.0
      expect(latest.totalCostBasis, closeTo(189.50 + 500.0, 0.001));

      await subscription.cancel();
    });

    test('50 rapid deletes settle cleanly to baseline seed totals', () async {
      for (int i = 1; i <= 50; i++) {
        await db.into(db.vaultItems).insert(
              createTestItem(
                id: 'delete-target-$i',
                collectionType: 'comic',
                name: 'Comic $i',
                quantity: 1,
                marketPrice: 20.0,
                costBasis: 10.0,
              ),
            );
      }

      final emittedValues = <VaultTotals>[];
      final subscription = dao.watchVaultTotals().listen(emittedValues.add);
      await pumpEventQueue(times: 20);

      // Rapidly delete all 50 inserted items
      for (int i = 1; i <= 50; i++) {
        await (db.delete(db.vaultItems)..where((t) => t.id.equals('delete-target-$i'))).go();
      }

      await pumpEventQueue(times: 50);

      final latest = emittedValues.last;
      expect(latest.totalCount, equals(4));
      expect(latest.totalMarketValue, closeTo(438.75, 0.001));
      expect(latest.totalCostBasis, closeTo(189.50, 0.001));

      await subscription.cancel();
    });

    test('Concurrent interleaved mutations via Future.wait do not deadlock or drop updates', () async {
      final emittedValues = <VaultTotals>[];
      final subscription = dao.watchVaultTotals().listen(emittedValues.add);
      await pumpEventQueue(times: 10);

      // Launch 30 concurrent operations (10 inserts, 10 updates, 10 deletes)
      // Pre-insert 10 items for updates and 10 items for deletes
      for (int i = 1; i <= 10; i++) {
        await db.into(db.vaultItems).insert(
              createTestItem(
                id: 'pre-update-$i',
                collectionType: 'mtg',
                name: 'Pre Update $i',
                quantity: 1,
                marketPrice: 10.0,
                costBasis: 5.0,
              ),
            );
        await db.into(db.vaultItems).insert(
              createTestItem(
                id: 'pre-delete-$i',
                collectionType: 'mtg',
                name: 'Pre Delete $i',
                quantity: 1,
                marketPrice: 10.0,
                costBasis: 5.0,
              ),
            );
      }

      final futures = <Future>[];
      for (int i = 1; i <= 10; i++) {
        futures.add(
          db.into(db.vaultItems).insert(
                createTestItem(
                  id: 'concurrent-insert-$i',
                  collectionType: 'mtg',
                  name: 'Concurrent Insert $i',
                  quantity: 2,
                  marketPrice: 15.0,
                  costBasis: 7.0,
                ),
              ),
        );
        futures.add(
          (db.update(db.vaultItems)..where((t) => t.id.equals('pre-update-$i'))).write(
            const VaultItemsCompanion(
              quantity: drift.Value(3),
              currentMarketPrice: drift.Value(20.0),
            ),
          ),
        );
        futures.add(
          (db.delete(db.vaultItems)..where((t) => t.id.equals('pre-delete-$i'))).go(),
        );
      }

      await Future.wait(futures);
      await pumpEventQueue(times: 50);

      final oneShot = await dao.getVaultTotals();
      final latestStreamed = emittedValues.last;

      expect(latestStreamed.totalCount, equals(oneShot.totalCount));
      expect(latestStreamed.totalMarketValue, closeTo(oneShot.totalMarketValue, 0.001));
      expect(latestStreamed.totalCostBasis, closeTo(oneShot.totalCostBasis, 0.001));
      expect(latestStreamed.totalProfitLoss, closeTo(oneShot.totalProfitLoss, 0.001));
      expect(latestStreamed.profitLossPercentage, closeTo(oneShot.profitLossPercentage, 0.001));

      await subscription.cancel();
    });

    test('Batch insertion of 100 items emits exact aggregates', () async {
      await db.batch((batch) {
        for (int i = 1; i <= 100; i++) {
          batch.insert(
            db.vaultItems,
            createTestItem(
              id: 'batch-item-$i',
              collectionType: 'sports_card',
              name: 'Card $i',
              quantity: 1,
              marketPrice: 1.0,
              costBasis: 0.5,
            ),
          );
        }
      });

      final totals = await dao.watchVaultTotals().first;
      expect(totals.totalCount, equals(104));
      expect(totals.totalMarketValue, closeTo(438.75 + 100.0, 0.001));
      expect(totals.totalCostBasis, closeTo(189.50 + 50.0, 0.001));
    });
  });

  group('Adversarial Stress Test: Extreme Values & Boundary Mathematics', () {
    test('Handles 1,000,000 quantity without 32-bit integer or double overflow', () async {
      await db.into(db.vaultItems).insert(
            createTestItem(
              id: 'huge-quantity-item',
              collectionType: 'mtg',
              name: 'Tokens of Infinity',
              quantity: 1000000,
              marketPrice: 2.50,
              costBasis: 1.50,
            ),
          );

      final totals = await dao.watchVaultTotals().first;
      expect(totals.totalCount, equals(1000004));
      expect(totals.totalMarketValue, closeTo(438.75 + (1000000 * 2.50), 0.01));
      expect(totals.totalCostBasis, closeTo(189.50 + (1000000 * 1.50), 0.01));
      expect(totals.totalProfitLoss, closeTo(totals.totalMarketValue - totals.totalCostBasis, 0.01));
      expect(totals.profitLossPercentage, closeTo(((totals.totalMarketValue - totals.totalCostBasis) / totals.totalCostBasis) * 100, 0.01));
    });

    test('Handles 100,000,000 extreme bulk quantity as 64-bit int', () async {
      await db.into(db.vaultItems).insert(
            createTestItem(
              id: 'bulk-infinite',
              collectionType: 'pokemon',
              name: 'Bulk Energy Cards',
              quantity: 100000000,
              marketPrice: 0.01,
              costBasis: 0.005,
            ),
          );

      final totals = await dao.watchVaultTotals().first;
      expect(totals.totalCount, equals(100000004));
      expect(totals.totalMarketValue, closeTo(438.75 + (100000000 * 0.01), 0.01));
    });

    test('Precision accuracy with sub-cent fractional prices', () async {
      await db.into(db.vaultItems).insert(
            createTestItem(
              id: 'penny-cards',
              collectionType: 'mtg',
              name: 'Micro Commons',
              quantity: 80000,
              marketPrice: 0.000125, // 80,000 * 0.000125 = 10.0
              costBasis: 0.00005,   // 80,000 * 0.00005 = 4.0
            ),
          );

      final totals = await dao.watchVaultTotals(collectionType: 'mtg').first;
      // Seed MTG: qty 1, market 45.50, cost 15.00
      expect(totals.totalCount, equals(80001));
      expect(totals.totalMarketValue, closeTo(45.50 + 10.0, 0.0001));
      expect(totals.totalCostBasis, closeTo(15.00 + 4.0, 0.0001));
    });

    test('Zero cost basis does NOT cause division by zero (no NaN or Infinity)', () async {
      // Clear database to test pure zero cost basis scenario
      await (db.delete(db.vaultItems)).go();

      await db.into(db.vaultItems).insert(
            createTestItem(
              id: 'free-gift-card',
              collectionType: 'mtg',
              name: 'Promo Gift Card',
              quantity: 5,
              marketPrice: 200.0,
              costBasis: 0.0, // Free acquisition
            ),
          );

      final totals = await dao.watchVaultTotals().first;
      expect(totals.totalCount, equals(5));
      expect(totals.totalMarketValue, equals(1000.0));
      expect(totals.totalCostBasis, equals(0.0));
      expect(totals.totalProfitLoss, equals(1000.0));
      expect(totals.profitLossPercentage, equals(0.0));
      expect(totals.profitLossPercentage.isNaN, isFalse);
      expect(totals.profitLossPercentage.isInfinite, isFalse);
      expect(totals.isProfitable, isTrue);
    });

    test('Empty database yields structured zero totals without throwing StateError', () async {
      // Wipe all vault items
      await (db.delete(db.vaultItems)).go();

      final totals = await dao.watchVaultTotals().first;
      expect(totals.totalCount, equals(0));
      expect(totals.totalMarketValue, equals(0.0));
      expect(totals.totalCostBasis, equals(0.0));
      expect(totals.totalProfitLoss, equals(0.0));
      expect(totals.profitLossPercentage, equals(0.0));
      expect(totals.isProfitable, isTrue);

      final oneShot = await dao.getVaultTotals();
      expect(oneShot.totalCount, equals(0));
      expect(oneShot.totalMarketValue, equals(0.0));
      expect(oneShot.totalCostBasis, equals(0.0));
    });

    test('Negative cost basis does not result in invalid profit percentage', () async {
      await (db.delete(db.vaultItems)).go();

      await db.into(db.vaultItems).insert(
            createTestItem(
              id: 'rebate-card',
              collectionType: 'mtg',
              name: 'Rebate Promo',
              quantity: 1,
              marketPrice: 50.0,
              costBasis: -10.0, // Rebate cash-back
            ),
          );

      final totals = await dao.watchVaultTotals().first;
      expect(totals.totalCount, equals(1));
      expect(totals.totalMarketValue, equals(50.0));
      expect(totals.totalCostBasis, equals(-10.0));
      expect(totals.totalProfitLoss, equals(60.0));
      // When costBasis <= 0, profitLossPercentage must be 0.0 safely
      expect(totals.profitLossPercentage, equals(0.0));
      expect(totals.isProfitable, isTrue);
    });
  });

  group('Adversarial Stress Test: Binder Mobility & INBOX Segregation', () {
    test('Moving item between binders updates scoped binder totals and preserves macro totals', () async {
      // Create Binder A and Binder B
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-alpha',
              name: 'Alpha Binder',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-beta',
              name: 'Beta Binder',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );

      // Insert item into Binder A
      await db.into(db.vaultItems).insert(
            createTestItem(
              id: 'moving-card',
              collectionType: 'mtg',
              name: 'Black Lotus',
              quantity: 2,
              marketPrice: 5000.0,
              costBasis: 2000.0,
              binderId: 'binder-alpha',
            ),
          );

      final alphaEmissions = <VaultTotals>[];
      final betaEmissions = <VaultTotals>[];
      final macroEmissions = <VaultTotals>[];

      final subA = dao.watchVaultTotals(binderId: 'binder-alpha').listen(alphaEmissions.add);
      final subB = dao.watchVaultTotals(binderId: 'binder-beta').listen(betaEmissions.add);
      final subMacro = dao.watchVaultTotals().listen(macroEmissions.add);

      await pumpEventQueue(times: 20);

      expect(alphaEmissions.last.totalCount, equals(2));
      expect(alphaEmissions.last.totalMarketValue, equals(10000.0));
      expect(betaEmissions.last.totalCount, equals(0));
      expect(betaEmissions.last.totalMarketValue, equals(0.0));
      final initialMacroCount = macroEmissions.last.totalCount;

      // Transfer item from Alpha to Beta
      await (db.update(db.vaultItems)..where((t) => t.id.equals('moving-card'))).write(
        const VaultItemsCompanion(
          primaryBinderId: drift.Value('binder-beta'),
        ),
      );

      await pumpEventQueue(times: 30);

      // Binder Alpha should now be empty
      expect(alphaEmissions.last.totalCount, equals(0));
      expect(alphaEmissions.last.totalMarketValue, equals(0.0));

      // Binder Beta should have the item
      expect(betaEmissions.last.totalCount, equals(2));
      expect(betaEmissions.last.totalMarketValue, equals(10000.0));

      // Macro view total count and total market value should remain completely stable!
      expect(macroEmissions.last.totalCount, equals(initialMacroCount));

      await subA.cancel();
      await subB.cancel();
      await subMacro.cancel();
    });

    test('INBOX holding area lifecycle: excluded from macro, queryable directly, and integrated on promote', () async {
      final macroEmissions = <VaultTotals>[];
      final inboxEmissions = <VaultTotals>[];

      final subMacro = dao.watchVaultTotals().listen(macroEmissions.add);
      final subInbox = dao.watchVaultTotals(binderId: 'INBOX').listen(inboxEmissions.add);

      await pumpEventQueue(times: 20);
      final initialMacroCount = macroEmissions.last.totalCount;

      // Stage 3 scanned items into INBOX
      for (int i = 1; i <= 3; i++) {
        await db.into(db.vaultItems).insert(
              createTestItem(
                id: 'inbox-scanned-$i',
                collectionType: 'pokemon',
                name: 'Scanned Card $i',
                quantity: 1,
                marketPrice: 50.0,
                costBasis: 25.0,
                binderId: 'INBOX',
              ),
            );
      }

      await pumpEventQueue(times: 30);

      // Macro totals must NOT include INBOX items
      expect(macroEmissions.last.totalCount, equals(initialMacroCount));

      // Scoped INBOX query must accurately report all 3 items
      expect(inboxEmissions.last.totalCount, equals(3));
      expect(inboxEmissions.last.totalMarketValue, equals(150.0));
      expect(inboxEmissions.last.totalCostBasis, equals(75.0));

      // Promote one item from INBOX to main vault (primaryBinderId = null)
      await (db.update(db.vaultItems)..where((t) => t.id.equals('inbox-scanned-1'))).write(
        const VaultItemsCompanion(
          primaryBinderId: drift.Value(null),
        ),
      );

      await pumpEventQueue(times: 30);

      // INBOX should decrement to 2
      expect(inboxEmissions.last.totalCount, equals(2));
      expect(inboxEmissions.last.totalMarketValue, equals(100.0));

      // Macro totals must now increase by 1
      expect(macroEmissions.last.totalCount, equals(initialMacroCount + 1));

      await subMacro.cancel();
      await subInbox.cancel();
    });
  });

  group('Adversarial Stress Test: Collection Types & Case Insensitivity', () {
    test('Normalizes various casing, whitespace, and aliases for MTG', () async {
      final baseMtg = await dao.watchVaultTotals(collectionType: 'mtg').first;

      final variations = [
        'MTG',
        'Mtg',
        '  mtg  ',
        'Magic: The Gathering',
        'MAGIC: THE GATHERING',
        'magic: the gathering',
        'Magic',
        'MAGIC',
      ];

      for (final variant in variations) {
        final variantTotals = await dao.watchVaultTotals(collectionType: variant).first;
        expect(variantTotals.totalCount, equals(baseMtg.totalCount),
            reason: 'Failed for variant: "$variant"');
        expect(variantTotals.totalMarketValue, closeTo(baseMtg.totalMarketValue, 0.001),
            reason: 'Failed for variant: "$variant"');
      }
    });

    test('Normalizes various casing and diacritics for Pokémon', () async {
      final basePokemon = await dao.watchVaultTotals(collectionType: 'pokemon').first;

      final variations = [
        'POKEMON',
        'Pokemon',
        'Pokémon',
        'POKÉMON',
        'pokémon',
        '  Pokémon  ',
      ];

      for (final variant in variations) {
        final variantTotals = await dao.watchVaultTotals(collectionType: variant).first;
        expect(variantTotals.totalCount, equals(basePokemon.totalCount),
            reason: 'Failed for variant: "$variant"');
        expect(variantTotals.totalMarketValue, closeTo(basePokemon.totalMarketValue, 0.001),
            reason: 'Failed for variant: "$variant"');
      }
    });

    test('Normalizes All Collections / My Vault aliases to macro view', () async {
      final macroTotals = await dao.watchVaultTotals().first;

      final allAliases = [
        'all',
        'ALL',
        'All Collections',
        'ALL COLLECTIONS',
        'My Vault',
        'my vault',
        'MY VAULT',
        'all vault',
        '  all  ',
      ];

      for (final alias in allAliases) {
        final aliasTotals = await dao.watchVaultTotals(collectionType: alias).first;
        expect(aliasTotals.totalCount, equals(macroTotals.totalCount),
            reason: 'Failed for alias: "$alias"');
        expect(aliasTotals.totalMarketValue, closeTo(macroTotals.totalMarketValue, 0.001),
            reason: 'Failed for alias: "$alias"');
      }
    });

    test('Mutations in one collection do not contaminate totals of another collection', () async {
      final initialPokemonTotals = await dao.watchVaultTotals(collectionType: 'pokemon').first;
      final initialComicTotals = await dao.watchVaultTotals(collectionType: 'comic').first;

      // Insert 20 MTG items
      for (int i = 1; i <= 20; i++) {
        await db.into(db.vaultItems).insert(
              createTestItem(
                id: 'isolate-mtg-$i',
                collectionType: 'mtg',
                name: 'MTG Isolate $i',
                quantity: 5,
                marketPrice: 100.0,
                costBasis: 50.0,
              ),
            );
      }

      final updatedPokemonTotals = await dao.watchVaultTotals(collectionType: 'pokemon').first;
      final updatedComicTotals = await dao.watchVaultTotals(collectionType: 'comic').first;

      expect(updatedPokemonTotals.totalCount, equals(initialPokemonTotals.totalCount));
      expect(updatedPokemonTotals.totalMarketValue, equals(initialPokemonTotals.totalMarketValue));
      expect(updatedComicTotals.totalCount, equals(initialComicTotals.totalCount));
      expect(updatedComicTotals.totalMarketValue, equals(initialComicTotals.totalMarketValue));

      final updatedMtgTotals = await dao.watchVaultTotals(collectionType: 'mtg').first;
      expect(updatedMtgTotals.totalCount, equals(1 + (20 * 5)));
    });
  });

  group('Adversarial Stress Test: Provider Layer & UI Decoupling', () {
    test('vaultTotalsProvider reactively cascades across rapid game switching', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
      );
      addTearDown(container.dispose);

      // 1. Initial All Collections view
      container.read(activeGameContextProvider.notifier).state = 'All Collections';
      await pumpEventQueue();
      var totals = await container.read(vaultTotalsProvider.future);
      expect(totals.totalCount, equals(4));

      // 2. Switch to MTG
      container.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';
      await pumpEventQueue();
      totals = await container.read(vaultTotalsProvider.future);
      expect(totals.totalCount, equals(1));

      // 3. Switch to Pokemon
      container.read(activeGameContextProvider.notifier).state = 'Pokémon';
      await pumpEventQueue();
      totals = await container.read(vaultTotalsProvider.future);
      expect(totals.totalCount, equals(1));

      // 4. Switch to Comic
      container.read(activeGameContextProvider.notifier).state = 'Comic Books';
      await pumpEventQueue();
      totals = await container.read(vaultTotalsProvider.future);
      expect(totals.totalCount, equals(1));

      // 5. Switch to Sports
      container.read(activeGameContextProvider.notifier).state = 'Sports Cards';
      await pumpEventQueue();
      totals = await container.read(vaultTotalsProvider.future);
      expect(totals.totalCount, equals(1));
    });

    test('vaultPortfolioSummaryProvider falls back gracefully during uninitialized state', () async {
      final emptyDb = AppDatabase(NativeDatabase.memory());
      final emptyDao = emptyDb.vaultDao;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(emptyDb),
          vaultDaoProvider.overrideWithValue(emptyDao),
        ],
      );
      addTearDown(() {
        container.dispose();
        emptyDb.close();
      });

      final summary = container.read(vaultPortfolioSummaryProvider);
      expect(summary.totalItemCount, equals(0));
      expect(summary.totalMarketValue, equals(0.0));
      expect(summary.totalCostBasis, equals(0.0));
      expect(summary.isProfitable, isTrue);
    });
  });
}

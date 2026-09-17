import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_totals.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('VaultDao.watchVaultTotals Unit & Scoping Tests', () {
    test('Calculates initial seed totals correctly for all collections (macro view)', () async {
      final totals = await dao.watchVaultTotals().first;

      // Seeded:
      // 1. MTG: The One Ring (qty 1, market 45.50, cost 15.00)
      // 2. Pokemon: Charizard ex (qty 1, market 3.25, cost 4.50)
      // 3. Comic: Ultimate Fallout #4 (qty 1, market 210.00, cost 150.00)
      // 4. Sports: T.J. Watt (qty 1, market 180.00, cost 20.00)
      // Total count = 4
      // Total market = 45.50 + 3.25 + 210.00 + 180.00 = 438.75
      // Total cost = 15.00 + 4.50 + 150.00 + 20.00 = 189.50
      // Delta = 438.75 - 189.50 = 249.25
      // Profit % = (249.25 / 189.50) * 100 = 131.5303...
      expect(totals.totalCount, 4);
      expect(totals.totalMarketValue, closeTo(438.75, 0.001));
      expect(totals.totalCostBasis, closeTo(189.50, 0.001));
      expect(totals.totalProfitLoss, closeTo(249.25, 0.001));
      expect(totals.profitLossPercentage, closeTo(131.53, 0.01));
      expect(totals.isProfitable, isTrue);
    });

    test('Scopes totals strictly to MTG collection', () async {
      final totals = await dao.watchVaultTotals(collectionType: 'Magic: The Gathering').first;

      // MTG only: The One Ring (qty 1, market 45.50, cost 15.00)
      expect(totals.totalCount, 1);
      expect(totals.totalMarketValue, closeTo(45.50, 0.001));
      expect(totals.totalCostBasis, closeTo(15.00, 0.001));
      expect(totals.totalProfitLoss, closeTo(30.50, 0.001));
      expect(totals.profitLossPercentage, closeTo(203.33, 0.01));
      expect(totals.isProfitable, isTrue);
    });

    test('Scopes totals strictly to Pokémon collection', () async {
      final totals = await dao.watchVaultTotals(collectionType: 'Pokémon').first;

      // Pokémon only: Charizard ex (qty 1, market 3.25, cost 4.50)
      expect(totals.totalCount, 1);
      expect(totals.totalMarketValue, closeTo(3.25, 0.001));
      expect(totals.totalCostBasis, closeTo(4.50, 0.001));
      expect(totals.totalProfitLoss, closeTo(-1.25, 0.001));
      expect(totals.profitLossPercentage, closeTo(-27.77, 0.01));
      expect(totals.isProfitable, isFalse);
    });

    test('Scopes totals strictly to Binder ID when provided', () async {
      // Create a binder and assign an item to it
      final binder = VaultBindersCompanion.insert(
        id: 'binder-mtg-mythics',
        name: 'MTG Mythics',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      );
      await db.into(db.vaultBinders).insert(binder);

      await (db.update(db.vaultItems)..where((t) => t.id.equals('item-mtg-one-ring'))).write(
        const VaultItemsCompanion(
          primaryBinderId: drift.Value('binder-mtg-mythics'),
        ),
      );

      final binderTotals = await dao.watchVaultTotals(binderId: 'binder-mtg-mythics').first;
      expect(binderTotals.totalCount, 1);
      expect(binderTotals.totalMarketValue, closeTo(45.50, 0.001));

      final emptyBinderTotals = await dao.watchVaultTotals(binderId: 'non-existent-binder').first;
      expect(emptyBinderTotals.totalCount, 0);
      expect(emptyBinderTotals.totalMarketValue, 0.0);
    });

    test('Excludes INBOX items from macro totals when binderId is null', () async {
      // Move Pokémon item to INBOX
      await (db.update(db.vaultItems)..where((t) => t.id.equals('item-pokemon-charizard'))).write(
        const VaultItemsCompanion(
          primaryBinderId: drift.Value('INBOX'),
        ),
      );

      final totals = await dao.watchVaultTotals().first;
      // Should now have 3 items instead of 4
      expect(totals.totalCount, 3);
      expect(totals.totalMarketValue, closeTo(438.75 - 3.25, 0.001));
    });

    test('Ignores unowned reference items (quantity == 0)', () async {
      // Add a catalog reference item with quantity 0
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'catalog-ref-card',
          collectionType: 'mtg',
          name: 'Black Lotus Reference',
          setOrSeries: 'Alpha',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 20000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      final mtgTotals = await dao.watchVaultTotals(collectionType: 'mtg').first;
      expect(mtgTotals.totalCount, 1);
      expect(mtgTotals.totalMarketValue, closeTo(45.50, 0.001));
    });
  });

  group('VaultDao.watchVaultTotals Reactive Updates', () {
    test('Live stream re-emits when new item is inserted, updated, and deleted', () async {
      final emittedTotals = <VaultTotals>[];
      final subscription = dao.watchVaultTotals(collectionType: 'mtg').listen(emittedTotals.add);

      await pumpEventQueue();
      expect(emittedTotals.length, 1);
      expect(emittedTotals.first.totalCount, 1);

      // 1. Insert a new MTG card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-mtg-mox-pearl',
          collectionType: 'mtg',
          name: 'Mox Pearl',
          setOrSeries: 'Beta',
          imageUrl: '',
          acquiredPrice: 100.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(2),
          condition: 'LP',
          currentMarketPrice: 500.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      await pumpEventQueue();
      expect(emittedTotals.length, 2);
      expect(emittedTotals.last.totalCount, 3); // 1 One Ring + 2 Mox Pearls
      expect(emittedTotals.last.totalMarketValue, closeTo(45.50 + 1000.0, 0.001));

      // 2. Update quantity and price
      await (db.update(db.vaultItems)..where((t) => t.id.equals('item-mtg-mox-pearl'))).write(
        const VaultItemsCompanion(
          quantity: drift.Value(3),
          currentMarketPrice: drift.Value(600.0),
        ),
      );

      await pumpEventQueue();
      expect(emittedTotals.length, 3);
      expect(emittedTotals.last.totalCount, 4); // 1 One Ring + 3 Mox Pearls
      expect(emittedTotals.last.totalMarketValue, closeTo(45.50 + 1800.0, 0.001));

      // 3. Delete the item
      await (db.delete(db.vaultItems)..where((t) => t.id.equals('item-mtg-mox-pearl'))).go();

      await pumpEventQueue();
      expect(emittedTotals.length, 4);
      expect(emittedTotals.last.totalCount, 1);
      expect(emittedTotals.last.totalMarketValue, closeTo(45.50, 0.001));

      await subscription.cancel();
    });
  });

  group('Riverpod vaultTotalsProvider & vaultPortfolioSummaryProvider', () {
    test('vaultTotalsProvider emits live totals and vaultPortfolioSummaryProvider derives correctly', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      // Read initial summary
      final asyncTotals = await container.read(vaultTotalsProvider.future);
      expect(asyncTotals.totalCount, 1);
      expect(asyncTotals.totalMarketValue, closeTo(45.50, 0.001));

      final summary = container.read(vaultPortfolioSummaryProvider);
      expect(summary.totalItemCount, 1);
      expect(summary.totalMarketValue, closeTo(45.50, 0.001));

      // Switch context to Pokemon
      container.read(activeGameContextProvider.notifier).state = 'Pokémon';
      await pumpEventQueue();

      final pokemonTotals = await container.read(vaultTotalsProvider.future);
      expect(pokemonTotals.totalCount, 1);
      expect(pokemonTotals.totalMarketValue, closeTo(3.25, 0.001));

      final pokemonSummary = container.read(vaultPortfolioSummaryProvider);
      expect(pokemonSummary.totalItemCount, 1);
      expect(pokemonSummary.totalMarketValue, closeTo(3.25, 0.001));
    });
  });
}

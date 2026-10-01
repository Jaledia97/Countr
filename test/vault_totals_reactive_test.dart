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
      // 2. MTG: Sol Ring (Retro Artifact) (qty 1, market 2.50, cost 2.00)
      // 3. MTG: Black Lotus (qty 1, market 25000.00, cost 12000.00)
      // 4. MTG: Lightning Bolt (qty 4, market 14.00, cost 10.00)
      // 5. MTG: Edgar Markov (qty 1, market 85.00, cost 0.00)
      // 6. Pokemon: Charizard ex (qty 1, market 3.25, cost 4.50)
      // 7. Comic: Ultimate Fallout #4 (qty 1, market 210.00, cost 150.00)
      // 8. Sports: T.J. Watt (qty 1, market 180.00, cost 20.00)
      // Total count = 11
      // Total market = 25540.25
      // Total cost = 12201.50
      // Delta = 13338.75
      // Profit % = (13338.75 / 12201.50) * 100 = 109.3205...
      expect(totals.totalCount, 11);
      expect(totals.totalMarketValue, closeTo(25540.25, 0.001));
      expect(totals.totalCostBasis, closeTo(12201.50, 0.001));
      expect(totals.totalProfitLoss, closeTo(13338.75, 0.001));
      expect(totals.profitLossPercentage, closeTo(109.32, 0.01));
      expect(totals.isProfitable, isTrue);
    });

    test('Scopes totals strictly to MTG collection', () async {
      final totals = await dao.watchVaultTotals(collectionType: 'Magic: The Gathering').first;

      // MTG only: The One Ring, Sol Ring, Black Lotus, Lightning Bolt (4x), Edgar Markov
      // Total count = 8
      // Total market = 25147.00
      // Total cost = 12027.00
      // Delta = 13120.00
      // Profit % = (13120.00 / 12027.00) * 100 = 109.087...
      expect(totals.totalCount, 8);
      expect(totals.totalMarketValue, closeTo(25147.00, 0.001));
      expect(totals.totalCostBasis, closeTo(12027.00, 0.001));
      expect(totals.totalProfitLoss, closeTo(13120.00, 0.001));
      expect(totals.profitLossPercentage, closeTo(109.09, 0.01));
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
      // Should now have 10 items instead of 11 (Charizard moved to INBOX)
      expect(totals.totalCount, 10);
      expect(totals.totalMarketValue, closeTo(25540.25 - 3.25, 0.001));
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
      expect(mtgTotals.totalCount, 8);
      expect(mtgTotals.totalMarketValue, closeTo(25147.00, 0.001));
    });
  });

  group('VaultDao.watchVaultTotals Reactive Updates', () {
    test('Live stream re-emits when new item is inserted, updated, and deleted', () async {
      final emittedTotals = <VaultTotals>[];
      final subscription = dao.watchVaultTotals(collectionType: 'mtg').listen(emittedTotals.add);

      await pumpEventQueue();
      expect(emittedTotals.length, 1);
      expect(emittedTotals.first.totalCount, 8);

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
      expect(emittedTotals.last.totalCount, 10); // 8 baseline + 2 Mox Pearls
      expect(emittedTotals.last.totalMarketValue, closeTo(25147.00 + 1000.0, 0.001));

      // 2. Update quantity and price
      await (db.update(db.vaultItems)..where((t) => t.id.equals('item-mtg-mox-pearl'))).write(
        const VaultItemsCompanion(
          quantity: drift.Value(3),
          currentMarketPrice: drift.Value(600.0),
        ),
      );

      await pumpEventQueue();
      expect(emittedTotals.length, 3);
      expect(emittedTotals.last.totalCount, 11); // 8 baseline + 3 Mox Pearls
      expect(emittedTotals.last.totalMarketValue, closeTo(25147.00 + 1800.0, 0.001));

      // 3. Delete the item
      await (db.delete(db.vaultItems)..where((t) => t.id.equals('item-mtg-mox-pearl'))).go();

      await pumpEventQueue();
      expect(emittedTotals.length, 4);
      expect(emittedTotals.last.totalCount, 8);
      expect(emittedTotals.last.totalMarketValue, closeTo(25147.00, 0.001));

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
      expect(asyncTotals.totalCount, 8);
      expect(asyncTotals.totalMarketValue, closeTo(25147.00, 0.001));

      final summary = container.read(vaultPortfolioSummaryProvider);
      expect(summary.totalItemCount, 8);
      expect(summary.totalMarketValue, closeTo(25147.00, 0.001));

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

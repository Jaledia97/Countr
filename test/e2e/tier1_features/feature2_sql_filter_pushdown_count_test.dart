import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import '../helpers/e2e_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = createE2ETestDatabase();
    dao = db.vaultDao;
    await seedStandardM1Catalog(dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tier 1 - Feature 2: SQL Filter Pushdown & True SELECT COUNT(*)', () {
    test('F2.1: getFilteredItemCount returns total candidate count independent of pagination limit', () async {
      // Catalog has 10 MTG cards seeded (excluding pokemon Pikachu)
      final totalCount = await dao.getFilteredItemCount('mtg', onlyOwned: false);
      expect(totalCount, equals(10));

      // Fetch with an artificial small limit of 2 items
      final paginatedPage1 = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        limit: 2,
        offset: 0,
      );

      expect(paginatedPage1.length, equals(2));
      // Total count query must remain 10, completely independent of the paginated 2-card slice!
      expect(totalCount, equals(10));
    });

    test('F2.2: getFilteredItemCount with onlyOwned = true counts strictly owned cards', () async {
      // 5 owned cards seeded in MTG (Mox, Sol Ring, Bolt, BoP, Demonic Tutor, Ozolith = 6 owned)
      final ownedCount = await dao.getFilteredItemCount('mtg', onlyOwned: true);
      final ownedCards = await dao.getItemsByCollection('mtg', onlyOwned: true);

      expect(ownedCount, equals(ownedCards.length));
      for (final c in ownedCards) {
        expect(c.quantity, greaterThan(0));
      }
    });

    test('F2.3: getFilteredItemCount with search query counts only matching rows', () async {
      // Search for "Lotus" -> Black Lotus (1 card)
      final lotusCount = await dao.getFilteredItemCount(
        'mtg',
        onlyOwned: false,
        searchQuery: 'Lotus',
      );
      final lotusItems = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'Lotus',
      );

      expect(lotusCount, equals(1));
      expect(lotusItems.length, equals(1));
      expect(lotusItems.first.name, equals('Black Lotus'));
    });

    test('F2.4: watchFilteredItemCount stream reactively updates on card insertion and deletion', () async {
      final initialCount = await dao.getFilteredItemCount('mtg', onlyOwned: false);
      expect(initialCount, equals(10));

      final counts = <int>[];
      final subscription = dao.watchFilteredItemCount('mtg', onlyOwned: false).listen(counts.add);

      // Wait for initial emission
      await Future.delayed(const Duration(milliseconds: 50));
      expect(counts.last, equals(10));

      // Insert a new card
      final newCard = createE2ETestCard(
        id: 'c-giant-growth',
        name: 'Giant Growth',
        setOrSeries: 'Magic 2010',
        setCode: 'm10',
        rarity: 'common',
        cmc: 1,
        typeLine: 'Instant',
        colors: ['G'],
        quantity: 1,
      );
      await insertTestCards(dao, [newCard]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(counts.last, equals(11));

      // Delete the inserted card
      await (dao.delete(dao.vaultItems)..where((t) => t.id.equals('c-giant-growth'))).go();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(counts.last, equals(10));

      await subscription.cancel();
    });

    test('F2.5: Filter state with active criteria counts exactly matching records', () async {
      // Filter for Rare cards
      final filter = const MtgFilterState(
        rarities: {'rare'},
      );

      final filteredCount = await dao.getFilteredItemCount(
        'mtg',
        onlyOwned: false,
        mtgFilter: filter,
      );

      final filteredItems = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        mtgFilter: filter,
      );

      expect(filteredCount, equals(filteredItems.length));
      expect(filteredCount, greaterThan(0));
      for (final item in filteredItems) {
        expect(item.dynamicData.toLowerCase(), contains('"rarity":"rare"'));
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
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

  group('Tier 1 - Feature 7: All Cards to Binder Atomic Upsert', () {
    test('F7.1: Adding unowned catalog card (quantity == 0) to binder atomically promotes quantity to 1', () async {
      // Black Lotus is initially unowned: quantity = 0, primaryBinderId = null
      final before = (await dao.getItemById('c-lotus'))!;
      expect(before.quantity, equals(0));
      expect(before.primaryBinderId, isNull);

      // Assign to 'edh-staples' binder
      final updated = await dao.assignItemsToBinder(['c-lotus'], 'edh-staples');
      expect(updated, equals(1));

      final after = (await dao.getItemById('c-lotus'))!;
      expect(after.quantity, equals(1), reason: 'Unowned card must be promoted to quantity = 1');
      expect(after.primaryBinderId, equals('edh-staples'));
      expect(after.isDeleted, isFalse);
    });

    test('F7.2: Promoted card populates acquisition financials from current market price', () async {
      final before = (await dao.getItemById('c-counterspell'))!;
      expect(before.quantity, equals(0));
      expect(before.currentMarketPrice, equals(2.5));

      // Promote into 'trade-binder'
      await dao.assignItemsToBinder(['c-counterspell'], 'trade-binder');

      final after = (await dao.getItemById('c-counterspell'))!;
      expect(after.quantity, equals(1));
      expect(after.acquiredPrice, equals(2.5), reason: 'Acquired price should inherit market price on promotion');
      expect(after.purchasePrice, equals(2.5));
      expect(after.protectionStatus, equals('Sleeved'));
      expect(after.primaryBinderId, equals('trade-binder'));
    });

    test('F7.3: Assigning already owned card preserves original acquisition cost and date', () async {
      final before = (await dao.getItemById('c-bolt'))!;
      expect(before.quantity, equals(4));
      final originalAcquiredPrice = before.acquiredPrice;
      final originalAcquiredDate = before.acquiredDate;

      // Assign Bolt to 'trade-binder'
      await dao.assignItemsToBinder(['c-bolt'], 'trade-binder');

      final after = (await dao.getItemById('c-bolt'))!;
      expect(after.quantity, equals(4), reason: 'Owned card quantity should not change when assigned to binder');
      expect(after.primaryBinderId, equals('trade-binder'));
      expect(after.acquiredPrice, equals(originalAcquiredPrice));
      expect(after.acquiredDate, equals(originalAcquiredDate));
    });

    test('F7.4: Promoted card immediately emits into watchItemsByBinder stream', () async {
      final binderStream = dao.watchItemsByBinder('power-nine');
      final initialItems = await binderStream.first;
      final initialCount = initialItems.length;

      // Add Black Lotus (unowned) to 'power-nine' binder
      await dao.assignItemsToBinder(['c-lotus'], 'power-nine');

      final updatedItems = await binderStream.first;
      expect(updatedItems.length, equals(initialCount + 1));
      expect(updatedItems.any((c) => c.id == 'c-lotus'), isTrue);

      final lotus = updatedItems.firstWhere((c) => c.id == 'c-lotus');
      expect(lotus.quantity, equals(1));
      expect(lotus.primaryBinderId, equals('power-nine'));
    });

    test('F7.5: Bulk assigning mixed owned and unowned cards executes atomically in a single transaction', () async {
      // Mixed list:
      // - c-wrath (unowned, qty 0)
      // - c-bop (owned, qty 1)
      // - c-sol-ring (owned, qty 2)
      final ids = ['c-wrath', 'c-bop', 'c-sol-ring'];

      final count = await dao.assignItemsToBinder(ids, 'trade-binder');
      expect(count, equals(3));

      final wrath = (await dao.getItemById('c-wrath'))!;
      expect(wrath.quantity, equals(1));
      expect(wrath.primaryBinderId, equals('trade-binder'));

      final bop = (await dao.getItemById('c-bop'))!;
      expect(bop.quantity, equals(1));
      expect(bop.primaryBinderId, equals('trade-binder'));

      final solRing = (await dao.getItemById('c-sol-ring'))!;
      expect(solRing.quantity, equals(2));
      expect(solRing.primaryBinderId, equals('trade-binder'));

      // All 3 should be listed in trade-binder
      final binderCards = await dao.getItemsByBinder('trade-binder');
      expect(binderCards.map((c) => c.id), containsAll(ids));
    });
  });
}

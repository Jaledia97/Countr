import 'package:drift/drift.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';

part 'vault_dao.g.dart';

/// Data Access Object for VaultItems with polymorphic queries and seeding.
@DriftAccessor(tables: [VaultItems])
class VaultDao extends DatabaseAccessor<AppDatabase> with _$VaultDaoMixin {
  VaultDao(super.db);

  /// Streams items filtered by collection type.
  /// If collectionType is 'All Collections' or 'all', returns all records.
  Stream<List<VaultItem>> watchItemsByCollection(String collectionType) {
    final normalized = _normalizeCollectionType(collectionType);
    if (normalized == 'all') {
      return (select(vaultItems)
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.acquiredDate,
                    mode: OrderingMode.desc,
                  )
            ]))
          .watch();
    }
    return (select(vaultItems)
          ..where((t) => t.collectionType.equals(normalized))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.acquiredDate,
                  mode: OrderingMode.desc,
                )
          ]))
        .watch();
  }

  /// Normalizes display collection titles to internal collection types.
  String _normalizeCollectionType(String type) {
    final lower = type.toLowerCase().trim();
    if (lower == 'all collections' ||
        lower == 'all' ||
        lower == 'my vault' ||
        lower == 'all vault') {
      return 'all';
    }
    if (lower.contains('magic') || lower == 'mtg') {
      return 'mtg';
    }
    if (lower.contains('pokémon') || lower.contains('pokemon')) {
      return 'pokemon';
    }
    if (lower.contains('comic')) {
      return 'comic';
    }
    if (lower.contains('sport')) {
      return 'sports_card';
    }
    return lower;
  }

  /// Seeds the 4 hyper-detailed mock records if the ledger is empty.
  Future<void> seedDatabase() async {
    final existing = await select(vaultItems).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();

    await batch((b) {
      b.insertAll(vaultItems, [
        // 1. MTG: The One Ring
        VaultItemsCompanion.insert(
          id: 'item-mtg-one-ring',
          collectionType: 'mtg',
          name: 'The One Ring (Serialized #007/100)',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          imageUrl:
              'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 15.00,
          acquiredDate: now.subtract(const Duration(days: 45)),
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          personalNotes: const Value(
              'Pulled from collector booster at TBS Comics. Flawless surface.'),
          currentMarketPrice: 45.50,
          lastPriceUpdate: now,
          dynamicData:
              '{"mana": "2UB", "type": "Creature", "power": 3, "toughness": 2}',
        ),

        // 2. Pokémon: Charizard ex
        VaultItemsCompanion.insert(
          id: 'item-pokemon-charizard',
          collectionType: 'pokemon',
          name: 'Charizard ex',
          setOrSeries: 'Scarlet & Violet: 151',
          imageUrl:
              'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 4.50,
          acquiredDate: now.subtract(const Duration(days: 60)),
          quantity: const Value(1),
          condition: 'LP',
          isGraded: const Value(false),
          personalNotes: const Value(
              'Minor corner wear on rear. Stored in double sleeve.'),
          currentMarketPrice: 3.25,
          lastPriceUpdate: now,
          dynamicData: '{"hp": 120, "stage": "Basic"}',
        ),

        // 3. Comic Book: Ultimate Fallout #4
        VaultItemsCompanion.insert(
          id: 'item-comic-fallout-4',
          collectionType: 'comic',
          name: 'Ultimate Fallout #4 (1st Miles Morales)',
          setOrSeries: 'Marvel Comics • 1st Print 2011',
          imageUrl:
              'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 150.00,
          acquiredDate: now.subtract(const Duration(days: 180)),
          quantity: const Value(1),
          condition: 'CGC 9.8',
          isGraded: const Value(true),
          personalNotes: const Value(
              'Graded CGC 9.8 with pristine white pages. Holy grail issue.'),
          currentMarketPrice: 210.00,
          lastPriceUpdate: now,
          dynamicData: '{"issue": 1, "publisher": "Marvel"}',
        ),

        // 4. Sports Card: T.J. Watt Prizm Silver Rookie
        VaultItemsCompanion.insert(
          id: 'item-sports-watt-rookie',
          collectionType: 'sports_card',
          name: 'T.J. Watt Prizm Silver Rookie',
          setOrSeries: '2017 Panini Prizm Football',
          imageUrl:
              'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 20.00,
          acquiredDate: now.subtract(const Duration(days: 365)),
          quantity: const Value(1),
          condition: 'PSA 10',
          isGraded: const Value(true),
          personalNotes:
              const Value('Gem Mint 10 rookie card. True investment hold.'),
          currentMarketPrice: 180.00,
          lastPriceUpdate: now,
          dynamicData:
              '{"sport": "Football", "team": "Steelers", "is_rookie": true}',
        ),
      ]);
    });
  }

  /// Inserts a new vault item.
  Future<int> insertItem(VaultItemsCompanion item) =>
      into(vaultItems).insert(item);

  /// Deletes all items (used for test resets).
  Future<int> clearAllItems() => delete(vaultItems).go();
}

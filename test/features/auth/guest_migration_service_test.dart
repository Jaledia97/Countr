import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/guest_migration_service.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ProviderContainer container;
  late GuestMigrationService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.delete(db.vaultItems).go();
    await db.delete(db.vaultBinders).go();
    await db.delete(db.decks).go();
    await db.delete(db.exploreDeckVotes).go();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    service = container.read(guestMigrationServiceProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  VaultItemsCompanion createTestCard({
    required String id,
    required String name,
    required String userId,
    String primaryBinderId = '',
  }) {
    final now = DateTime.now();
    return VaultItemsCompanion.insert(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'M20',
      imageUrl: '',
      acquiredPrice: 5.0,
      acquiredDate: now,
      condition: 'NM',
      currentMarketPrice: 5.0,
      lastPriceUpdate: now,
      dynamicData: '{}',
      userId: drift.Value(userId),
      primaryBinderId: drift.Value(primaryBinderId),
    );
  }

  group('GuestMigrationService Tests', () {
    test('migrateGuestData migrates items, binders, decks, and votes using registeredUserId', () async {
      final now = DateTime.now();

      // 1. Seed guest data
      await db.into(db.vaultItems).insert(createTestCard(
            id: 'v_guest_1',
            name: 'Black Lotus',
            userId: 'guest',
            primaryBinderId: 'system_looking_for_guest',
          ));
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
            id: 'b_guest_1',
            name: 'Guest Binder',
            collectionType: 'mtg',
            createdAt: now,
            userId: const drift.Value('guest'),
            isSystemBinder: const drift.Value(false),
          ));
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: 'd_guest_1',
            name: 'Guest Deck',
            format: 'Commander',
            createdAt: now,
            userId: const drift.Value('guest'),
          ));
      await db.into(db.exploreDeckVotes).insert(ExploreDeckVotesCompanion.insert(
            id: 'vote_guest_1',
            userId: const drift.Value('guest'),
            exploreDeckId: 'ed_1',
            vote: const drift.Value(1),
            updatedAt: now,
          ));

      // 2. Perform migration using registeredUserId
      final summary = await service.migrateGuestData(
        registeredUserId: 'user_registered_42',
        isBusiness: false,
      );

      expect(summary.isSuccess, isTrue);
      expect(summary.migratedVaultItems, equals(1));
      expect(summary.migratedBinders, equals(1));
      expect(summary.migratedDecks, equals(1));
      expect(summary.migratedVotes, equals(1));

      // Verify DB rows updated
      final updatedItem = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_guest_1')))
          .getSingle();
      expect(updatedItem.userId, equals('user_registered_42'));
      expect(updatedItem.primaryBinderId,
          equals('system_looking_for_user_registered_42'));

      final updatedBinder = await (db.select(db.vaultBinders)
            ..where((t) => t.id.equals('b_guest_1')))
          .getSingle();
      expect(updatedBinder.userId, equals('user_registered_42'));

      final updatedDeck = await (db.select(db.decks)
            ..where((t) => t.id.equals('d_guest_1')))
          .getSingle();
      expect(updatedDeck.userId, equals('user_registered_42'));
    });

    test('migrateGuestData supports custom guestUserId and database override', () async {
      final customDb = AppDatabase(NativeDatabase.memory());
      addTearDown(() => customDb.close());
      await customDb.delete(customDb.vaultItems).go();

      final now = DateTime.now();
      await customDb.into(customDb.vaultItems).insert(VaultItemsCompanion.insert(
            id: 'v_custom_1',
            collectionType: 'mtg',
            name: 'Mox Sapphire',
            setOrSeries: 'LEA',
            imageUrl: '',
            acquiredPrice: 50.0,
            acquiredDate: now,
            condition: 'NM',
            currentMarketPrice: 50.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
            userId: const drift.Value('custom_guest_session_99'),
          ));

      final summary = await service.migrateGuestData(
        newUserId: 'user_target_1',
        guestUserId: 'custom_guest_session_99',
        database: customDb,
      );

      expect(summary.isSuccess, isTrue);
      expect(summary.migratedVaultItems, equals(1));

      final item = await (customDb.select(customDb.vaultItems)
            ..where((t) => t.id.equals('v_custom_1')))
          .getSingle();
      expect(item.userId, equals('user_target_1'));
    });

    test('migrateGuestData for business re-anchors to store inventory and buylist', () async {
      await db.into(db.vaultItems).insert(createTestCard(
            id: 'v_store_1',
            name: 'Sol Ring',
            userId: 'guest',
            primaryBinderId: 'system_looking_for_guest',
          ));
      await db.into(db.vaultItems).insert(createTestCard(
            id: 'v_store_2',
            name: 'Arcane Signet',
            userId: 'guest',
            primaryBinderId: 'system_trade_block_guest',
          ));

      final summary = await service.migrateGuestData(
        newUserId: 'store_owner_100',
        isBusiness: true,
      );

      expect(summary.isSuccess, isTrue);
      expect(summary.migratedVaultItems, equals(2));

      final item1 = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_store_1')))
          .getSingle();
      expect(item1.primaryBinderId,
          equals('system_store_inventory_store_owner_100'));

      final item2 = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_store_2')))
          .getSingle();
      expect(item2.primaryBinderId,
          equals('system_store_buylist_store_owner_100'));
    });

    test('B18.5: Guest migration with 0 guest items completes successfully with zero counts', () async {
      final summary = await service.migrateGuestData(
        newUserId: 'user_empty_guest',
        isBusiness: false,
      );

      expect(summary.isSuccess, isTrue);
      expect(summary.migratedVaultItems, equals(0));
      expect(summary.migratedBinders, equals(0));
      expect(summary.migratedDecks, equals(0));
      expect(summary.migratedVotes, equals(0));
    });

    test('purgeGuestData purges only guest items while preserving registered user items', () async {
      final now = DateTime.now();

      // Seed guest items
      await db.into(db.vaultItems).insert(createTestCard(
            id: 'v_guest',
            name: 'Guest Card',
            userId: 'guest',
          ));
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: 'd_guest',
            name: 'Guest Deck',
            format: 'Standard',
            createdAt: now,
            userId: const drift.Value('guest'),
          ));

      // Seed registered user items
      await db.into(db.vaultItems).insert(createTestCard(
            id: 'v_registered',
            name: 'Registered Card',
            userId: 'registered_user_1',
          ));
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: 'd_registered',
            name: 'Registered Deck',
            format: 'Modern',
            createdAt: now,
            userId: const drift.Value('registered_user_1'),
          ));

      // Purge guest data
      await service.purgeGuestData();

      // Verify guest rows are gone
      final guestCards = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_guest')))
          .get();
      expect(guestCards, isEmpty);

      final guestDecks = await (db.select(db.decks)
            ..where((t) => t.id.equals('d_guest')))
          .get();
      expect(guestDecks, isEmpty);

      // Verify registered rows remain intact
      final regCards = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_registered')))
          .get();
      expect(regCards.length, equals(1));

      final regDecks = await (db.select(db.decks)
            ..where((t) => t.id.equals('d_registered')))
          .get();
      expect(regDecks.length, equals(1));
    });
  });
}

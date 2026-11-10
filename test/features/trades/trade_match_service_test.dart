import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/services/trade_match_service.dart';

void main() {
  late AppDatabase db;
  late TradeMatchService service;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = TradeMatchService(db);

    // Seed User Profiles
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-alice',
        username: '@alice_mtg',
        displayName: 'Alice Trader',
        collectionVisibility: const Value('public'),
        createdAt: now,
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-bob',
        username: '@bob_collector',
        displayName: 'Bob Collector',
        collectionVisibility: const Value('public'),
        createdAt: now,
      ),
    );

    // Create System Binders for Alice
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_looking_for_user-alice',
        name: 'Looking For',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('looking_for'),
        userId: const Value('user-alice'),
        createdAt: now,
      ),
    );
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_user-alice',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: const Value('user-alice'),
        createdAt: now,
      ),
    );

    // Create System Binders for Bob
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_looking_for_user-bob',
        name: 'Looking For',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('looking_for'),
        userId: const Value('user-bob'),
        createdAt: now,
      ),
    );
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_user-bob',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: const Value('user-bob'),
        createdAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TradeMatchService Cross-Referencing Tests', () {
    test('matches card by oracle_id across different printings', () async {
      // Alice is Looking For Sol Ring (Commander 2020 printing)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-sol-ring',
          name: 'Sol Ring',
          setOrSeries: 'C20',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({
            'oracle_id': '43d46380-4ec0-4a81-9b16-e5c707d885a0',
            'scryfall_id': 'sol-c20-scryfall',
          }),
        ),
      );

      // Bob has Sol Ring (Double Masters 2022 printing) in his Trade Binder
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-sol-ring',
          name: 'Sol Ring (Borderless)',
          setOrSeries: '2X2',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 15.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 15.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({
            'oracle_id': '43d46380-4ec0-4a81-9b16-e5c707d885a0',
            'scryfall_id': 'sol-2x2-scryfall',
          }),
        ),
      );

      final matches = await service.watchMatchesForUser('user-alice').first;
      expect(matches, hasLength(1));
      expect(matches.first.matchType, equals('oracle_id'));
      expect(matches.first.partnerUser.id, equals('user-bob'));
      expect(matches.first.matchingTradeCard.id, equals('bob-tb-sol-ring'));
      expect(matches.first.lookingForCard.id, equals('alice-lf-sol-ring'));
    });

    test('matches card by scryfall_id', () async {
      // Alice is Looking For Mana Crypt
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-mana-crypt',
          name: 'Mana Crypt',
          setOrSeries: '2XM',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 180.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 180.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({
            'scryfall_id': 'mana-crypt-scryfall-id-123',
          }),
        ),
      );

      // Bob has identical Mana Crypt printing in Trade Binder
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-mana-crypt',
          name: 'Mana Crypt Special',
          setOrSeries: '2XM',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 180.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 180.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({
            'scryfall_id': 'mana-crypt-scryfall-id-123',
          }),
        ),
      );

      final matches = await service.watchMatchesForUser('user-alice').first;
      expect(matches, hasLength(1));
      expect(matches.first.matchType, equals('scryfall_id'));
      expect(matches.first.matchingTradeCard.id, equals('bob-tb-mana-crypt'));
    });

    test('matches card by case-insensitive name fallback', () async {
      // Alice is Looking For "rhystic study" (lowercase, no scryfall/oracle id)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-rhystic',
          name: 'rhystic study',
          setOrSeries: 'Prophecy',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 40.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 40.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: '{}',
        ),
      );

      // Bob has "Rhystic Study" in Trade Binder
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-rhystic',
          name: 'Rhystic Study',
          setOrSeries: 'Prophecy',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 40.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 40.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: '{}',
        ),
      );

      final matches = await service.watchMatchesForUser('user-alice').first;
      expect(matches, hasLength(1));
      expect(matches.first.matchType, equals('name'));
      expect(matches.first.matchingTradeCard.id, equals('bob-tb-rhystic'));
    });

    test('detects mutual trade match when both users want cards from each other', () async {
      // Alice wants Sol Ring (Bob has it)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-sol-ring-mut',
          name: 'Sol Ring',
          setOrSeries: 'C20',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-sol-ring'}),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-sol-ring-mut',
          name: 'Sol Ring',
          setOrSeries: '2X2',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-sol-ring'}),
        ),
      );

      // Bob wants Demonic Tutor (Alice has it in her trade binder!)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-lf-demonic-tutor',
          name: 'Demonic Tutor',
          setOrSeries: 'UMA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 40.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 40.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-demonic-tutor'}),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-tb-demonic-tutor',
          name: 'Demonic Tutor',
          setOrSeries: 'UMA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 40.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 40.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-demonic-tutor'}),
        ),
      );

      final aliceMatches = await service.watchMatchesForUser('user-alice').first;
      expect(aliceMatches, hasLength(1));
      expect(aliceMatches.first.isMutual, isTrue);

      final reverseMatches = await service.findReverseMatchesForUser('user-alice');
      expect(reverseMatches, hasLength(1));
      expect(reverseMatches.first.partnerUser.id, equals('user-bob'));
      expect(reverseMatches.first.matchingTradeCard.name, equals('Demonic Tutor'));
    });

    test('ignores cards not in trade binder, traded, deleted, or self cards', () async {
      // Alice is Looking For Smothering Tithe
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-smothering',
          name: 'Smothering Tithe',
          setOrSeries: 'RNA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 20.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 20.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-smothering-tithe'}),
        ),
      );

      // 1. Bob has Smothering Tithe but it was marked traded (isTraded = true)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-traded-card',
          name: 'Smothering Tithe',
          setOrSeries: 'RNA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 20.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 20.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          isTraded: const Value(true),
          dynamicData: jsonEncode({'oracle_id': 'oracle-smothering-tithe'}),
        ),
      );

      // 2. Alice's own card in her own Trade Binder (should never match herself)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-tb-self-card',
          name: 'Smothering Tithe',
          setOrSeries: 'RNA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 20.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 20.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-smothering-tithe'}),
        ),
      );

      final matches = await service.watchMatchesForUser('user-alice').first;
      expect(matches, isEmpty);
    });

    test('generateMatchNotification generates valid trade_match notification adhering to self-notification safety', () async {
      // Setup a match
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-lotus',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1000.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 1000.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-black-lotus'}),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-lotus',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1000.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 1000.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-black-lotus'}),
        ),
      );

      final matches = await service.watchMatchesForUser('user-alice').first;
      expect(matches, hasLength(1));

      final match = matches.first;
      final notif = await service.generateMatchNotification(match, recipientUserId: 'user-alice');

      expect(notif, isNotNull);
      // Verify self-notification safety: actorId is partner Bob, userId is recipient Alice
      expect(notif!.userId, equals('user-alice'));
      expect(notif.actorId, equals('user-bob'));
      expect(notif.actorUsername, equals('@bob_collector'));
      expect(notif.type, equals('trade_match'));
      expect(notif.targetEntityId, equals('bob-tb-lotus'));
      expect(notif.targetEntityType, equals('trade_match'));
      expect(notif.body, contains('Black Lotus'));
      expect(notif.body, contains('in their Trade Binder'));

      // Test idempotence
      final notif2 = await service.generateMatchNotification(match, recipientUserId: 'user-alice');
      expect(notif2!.id, equals(notif.id));
    });
  });
}

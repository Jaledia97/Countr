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
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> createTestUser(String userId, String username, {String visibility = 'public'}) async {
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: userId,
        username: username,
        displayName: 'User $username',
        collectionVisibility: Value(visibility),
        createdAt: now,
      ),
    );
    // Create system looking_for binder
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_looking_for_$userId',
        name: 'Looking For',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('looking_for'),
        userId: Value(userId),
        createdAt: now,
      ),
    );
    // Create system trade_block binder
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_$userId',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: Value(userId),
        createdAt: now,
      ),
    );
  }

  group('M1 Challenger: TradeMatchService Adversarial Stress Tests', () {
    test('Split cards, double-faced cards (//), and whitespace/case variations match correctly', () async {
      await createTestUser('user-alice', '@alice');
      await createTestUser('user-bob', '@bob');

      // 1. Split Card: Alice is looking for front-face name "Delver of Secrets"
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-delver',
          name: 'Delver of Secrets',
          setOrSeries: 'ISD',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1.5,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: '{}',
        ),
      );

      // Bob has full DFC name "Delver of Secrets // Insectile Aberration" in Trade Binder
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-delver',
          name: 'Delver of Secrets // Insectile Aberration',
          setOrSeries: 'ISD',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1.5,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: '{}',
        ),
      );

      // 2. Untrimmed whitespace and chaotic case: "   wEaR // tEaR   " vs "Wear"
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-wear',
          name: '  wear  ',
          setOrSeries: 'DGM',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 0.5,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 0.5,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-wear',
          name: 'Wear // Tear',
          setOrSeries: 'DGM',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 0.5,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 0.5,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: '{}',
        ),
      );

      final matches = await service.watchMatchesForUser('user-alice').first;
      expect(matches.length, equals(2));

      final delverMatch = matches.firstWhere((m) => m.lookingForCard.id == 'alice-lf-delver');
      expect(delverMatch.matchingTradeCard.id, equals('bob-tb-delver'));
      expect(delverMatch.matchType, equals('name'));

      final wearMatch = matches.firstWhere((m) => m.lookingForCard.id == 'alice-lf-wear');
      expect(wearMatch.matchingTradeCard.id, equals('bob-tb-wear'));
      expect(wearMatch.matchType, equals('name'));
    });

    test('Strict exclusion: quantity <= 0, isTraded, isDeleted, wrong binder, and self-cards', () async {
      await createTestUser('user-alice', '@alice');
      await createTestUser('user-bob', '@bob');

      // Alice is looking for Black Lotus
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
          dynamicData: jsonEncode({'oracle_id': 'oracle-lotus'}),
        ),
      );

      // Create a non-system custom binder for Bob (e.g. personal collection)
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'bob-custom-binder',
          name: 'My Prized Personal Collection',
          collectionType: 'mtg',
          isSystemBinder: const Value(false),
          userId: const Value('user-bob'),
          createdAt: now,
        ),
      );

      // Bob's items that MUST NOT match:
      // Case 1: In custom binder (NOT Trade Block)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-lotus-custom-binder',
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
          primaryBinderId: const Value('bob-custom-binder'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-lotus'}),
        ),
      );

      // Case 2: In Trade Block but quantity = 0
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-lotus-zero-qty',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1000.0,
          acquiredDate: now,
          quantity: const Value(0),
          condition: 'Near Mint',
          currentMarketPrice: 1000.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-lotus'}),
        ),
      );

      // Case 3: In Trade Block but quantity = -1
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-lotus-neg-qty',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1000.0,
          acquiredDate: now,
          quantity: const Value(-1),
          condition: 'Near Mint',
          currentMarketPrice: 1000.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-bob'),
          userId: const Value('user-bob'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-lotus'}),
        ),
      );

      // Case 4: In Trade Block but isTraded = true
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-lotus-traded',
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
          isTraded: const Value(true),
          dynamicData: jsonEncode({'oracle_id': 'oracle-lotus'}),
        ),
      );

      // Case 5: In Trade Block but isDeleted = true
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-lotus-deleted',
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
          isDeleted: const Value(true),
          dynamicData: jsonEncode({'oracle_id': 'oracle-lotus'}),
        ),
      );

      // Case 6: Alice's own card in her own Trade Block
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lotus-own',
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
          primaryBinderId: const Value('system_trade_block_user-alice'),
          userId: const Value('user-alice'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-lotus'}),
        ),
      );

      // Verify watchMatchesForUser returns EMPTY
      final matches = await service.watchMatchesForUser('user-alice').first;
      expect(matches, isEmpty, reason: 'All 6 invalid card states must be strictly excluded');
    });

    test('12-User Multi-User Scaling & Mutual Match Matrix', () async {
      const userCount = 12;
      for (int i = 0; i < userCount; i++) {
        await createTestUser('u_$i', '@user_$i');
      }

      // Card Pool of 6 cards
      final cardPool = [
        {'name': 'Mox Diamond', 'oracle': 'oracle-mox-diamond', 'price': 600.0},
        {'name': 'Gaea\'s Cradle', 'oracle': 'oracle-gaeas-cradle', 'price': 900.0},
        {'name': 'Lion\'s Eye Diamond', 'oracle': 'oracle-led', 'price': 500.0},
        {'name': 'Survival of the Fittest', 'oracle': 'oracle-survival', 'price': 250.0},
        {'name': 'Wheel of Fortune', 'oracle': 'oracle-wheel', 'price': 300.0},
        {'name': 'Mana Vault', 'oracle': 'oracle-mana-vault', 'price': 80.0},
      ];

      // Setup structured mutual and non-mutual matches:
      // u_0 and u_1: Mutual trade
      //   u_0 wants cardPool[0] (Mox Diamond), u_1 has it in Trade Binder
      //   u_1 wants cardPool[1] (Gaea's Cradle), u_0 has it in Trade Binder
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'u0_lf_mox',
          name: cardPool[0]['name'] as String,
          setOrSeries: 'ST',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: cardPool[0]['price'] as double,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: cardPool[0]['price'] as double,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_u_0'),
          userId: const Value('u_0'),
          dynamicData: jsonEncode({'oracle_id': cardPool[0]['oracle']}),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'u1_tb_mox',
          name: cardPool[0]['name'] as String,
          setOrSeries: 'ST',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: cardPool[0]['price'] as double,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: cardPool[0]['price'] as double,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_u_1'),
          userId: const Value('u_1'),
          dynamicData: jsonEncode({'oracle_id': cardPool[0]['oracle']}),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'u1_lf_cradle',
          name: cardPool[1]['name'] as String,
          setOrSeries: 'USG',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: cardPool[1]['price'] as double,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: cardPool[1]['price'] as double,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_u_1'),
          userId: const Value('u_1'),
          dynamicData: jsonEncode({'oracle_id': cardPool[1]['oracle']}),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'u0_tb_cradle',
          name: cardPool[1]['name'] as String,
          setOrSeries: 'USG',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: cardPool[1]['price'] as double,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: cardPool[1]['price'] as double,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_u_0'),
          userId: const Value('u_0'),
          dynamicData: jsonEncode({'oracle_id': cardPool[1]['oracle']}),
        ),
      );

      // u_0 also wants cardPool[2] (LED), which u_2 has in trade binder (Non-mutual, u_0 has nothing u_2 wants)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'u0_lf_led',
          name: cardPool[2]['name'] as String,
          setOrSeries: 'MIR',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: cardPool[2]['price'] as double,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: cardPool[2]['price'] as double,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_u_0'),
          userId: const Value('u_0'),
          dynamicData: jsonEncode({'oracle_id': cardPool[2]['oracle']}),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'u2_tb_led',
          name: cardPool[2]['name'] as String,
          setOrSeries: 'MIR',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: cardPool[2]['price'] as double,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: cardPool[2]['price'] as double,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_u_2'),
          userId: const Value('u_2'),
          dynamicData: jsonEncode({'oracle_id': cardPool[2]['oracle']}),
        ),
      );

      // Verify matches for u_0:
      // Expect 2 matches:
      // 1. Mox Diamond from u_1 (isMutual = true)
      // 2. LED from u_2 (isMutual = false)
      final u0Matches = await service.watchMatchesForUser('u_0').first;
      expect(u0Matches.length, equals(2));

      final moxMatch = u0Matches.firstWhere((m) => m.matchingTradeCard.id == 'u1_tb_mox');
      expect(moxMatch.partnerUser.id, equals('u_1'));
      expect(moxMatch.isMutual, isTrue, reason: 'u_0 and u_1 match is mutual');

      final ledMatch = u0Matches.firstWhere((m) => m.matchingTradeCard.id == 'u2_tb_led');
      expect(ledMatch.partnerUser.id, equals('u_2'));
      expect(ledMatch.isMutual, isFalse, reason: 'u_0 and u_2 match is one-way');

      // Verify reverse matches for u_0 (what others want that u_0 has):
      // Should find u_1 wants Gaea's Cradle from u_0!
      final reverseMatches = await service.findReverseMatchesForUser('u_0');
      expect(reverseMatches.length, equals(1));
      expect(reverseMatches.first.partnerUser.id, equals('u_1'));
      expect(reverseMatches.first.matchingTradeCard.id, equals('u0_tb_cradle'));
    });

    test('generateMatchNotification idempotency and self-notification safety under repetition', () async {
      await createTestUser('user-buyer', '@buyer');
      await createTestUser('user-seller', '@seller');

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'buyer-lf-underground-sea',
          name: 'Underground Sea',
          setOrSeries: '3ED',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 750.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 750.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_looking_for_user-buyer'),
          userId: const Value('user-buyer'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-underground-sea'}),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'seller-tb-underground-sea',
          name: 'Underground Sea',
          setOrSeries: '3ED',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 750.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 750.0,
          lastPriceUpdate: now,
          primaryBinderId: const Value('system_trade_block_user-seller'),
          userId: const Value('user-seller'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-underground-sea'}),
        ),
      );

      final matches = await service.watchMatchesForUser('user-buyer').first;
      expect(matches.length, equals(1));
      final match = matches.first;

      // Call generateMatchNotification 5 times concurrently / repeatedly
      for (int i = 0; i < 5; i++) {
        final notif = await service.generateMatchNotification(match, recipientUserId: 'user-buyer');
        expect(notif, isNotNull);
        expect(notif!.userId, equals('user-buyer'));
        expect(notif.actorId, equals('user-seller'));
        expect(notif.actorId, isNot(equals(notif.userId)), reason: 'Strict self-notification invariant');
      }

      // Assert exactly 1 notification row exists in DB
      final totalNotifs = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-buyer') & t.type.equals('trade_match')))
          .get();
      expect(totalNotifs.length, equals(1));

      // Assert unread count for user-buyer is 1
      final unreadCount = await db.inboxDao.watchUnreadNotificationCount('user-buyer').first;
      expect(unreadCount, equals(1));

      // Assert seller's unread count is 0 (seller is actor, not recipient)
      final sellerUnread = await db.inboxDao.watchUnreadNotificationCount('user-seller').first;
      expect(sellerUnread, equals(0));
    });
  });
}

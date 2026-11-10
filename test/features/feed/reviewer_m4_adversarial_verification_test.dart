// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial verification test suite by reviewer_m4_retry_2

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/daos/inbox_dao.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SocialSeedService seedService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    seedService = SocialSeedService(db);
    await seedService.seedSocialData();
  });

  tearDown(() async {
    await db.close();
  });

  group('Reviewer M4 Adversarial Audit: Conversation ID Canonicalization', () {
    test('InboxDao.getConversationId is strictly order-invariant and contains no stray prefixes', () {
      final conv1 = InboxDao.getConversationId('user-alpha', 'user-beta');
      final conv2 = InboxDao.getConversationId('user-beta', 'user-alpha');
      expect(conv1, equals('user-alpha_user-beta'));
      expect(conv2, equals('user-alpha_user-beta'));
      expect(conv1.startsWith('conv_'), isFalse);

      final convSame = InboxDao.getConversationId('same-id', 'same-id');
      expect(convSame, equals('same-id_same-id'));
      expect(convSame.startsWith('conv_'), isFalse);
    });
  });

  group('Reviewer M4 Adversarial Audit: executeTradeTransfer & Concurrency Guard', () {
    test('executeTradeTransfer alias delegates cleanly to respondToTradeProposal', () async {
      // Find pending trade proposal
      final trade = await (db.select(db.tradeProposals)
            ..where((t) => t.status.equals('pending')))
          .getSingle();

      // Call executeTradeTransfer alias
      await db.inboxDao.executeTradeTransfer(
        trade.id,
        currentUserId: trade.receiverId,
      );

      // Verify proposal is accepted and transferred
      final updatedProposal = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(trade.id)))
          .getSingle();
      expect(updatedProposal.status, equals('accepted'));
      expect(updatedProposal.isTransferred, isTrue);

      // Verify cards transferred into respective trade block binders
      final cardDockside = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-card-dockside-extortionist')))
          .getSingle();
      expect(cardDockside.userId, equals(trade.receiverId));
      expect(cardDockside.primaryBinderId, equals('system_trade_block_${trade.receiverId}'));
      expect(cardDockside.isTraded, isTrue);

      final cardSolRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-sol-ring')))
          .getSingle();
      expect(cardSolRing.userId, equals(trade.proposerId));
      expect(cardSolRing.primaryBinderId, equals('system_trade_block_${trade.proposerId}'));
      expect(cardSolRing.isTraded, isTrue);
    });

    test('Trade concurrency guard blocks replay attempts and duplicate transfers', () async {
      final trade = await (db.select(db.tradeProposals)
            ..where((t) => t.status.equals('pending')))
          .getSingle();

      // Accept trade first time
      await db.inboxDao.respondToTradeProposal(
        trade.id,
        accept: true,
        transferCards: true,
        currentUserId: trade.receiverId,
      );

      // Verify accepted
      final accepted = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(trade.id)))
          .getSingle();
      expect(accepted.status, equals('accepted'));

      // Count confirmation messages in chat
      final convId = InboxDao.getConversationId(trade.proposerId, trade.receiverId);
      final initialMessages = await (db.select(db.messages)
            ..where((t) => t.conversationId.equals(convId)))
          .get();
      final initialMessageCount = initialMessages.length;

      // Replay attack: try declining the already accepted trade
      await db.inboxDao.respondToTradeProposal(
        trade.id,
        accept: false,
        transferCards: false,
        currentUserId: trade.receiverId,
      );

      // Proposal status remains accepted
      final replay1 = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(trade.id)))
          .getSingle();
      expect(replay1.status, equals('accepted'));

      // Replay attack 2: try accepting again
      await db.inboxDao.respondToTradeProposal(
        trade.id,
        accept: true,
        transferCards: true,
        currentUserId: trade.receiverId,
      );

      // Messages count should not increase (no duplicate messages posted)
      final postReplayMessages = await (db.select(db.messages)
            ..where((t) => t.conversationId.equals(convId)))
          .get();
      expect(postReplayMessages.length, equals(initialMessageCount));
    });

    test('Trade transfer creates default trade block binders if not yet provisioned', () async {
      // Create users without trade block binders
      const newUser1 = 'user-unprovisioned-1';
      const newUser2 = 'user-unprovisioned-2';

      // Insert test cards owned by user1 and user2
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'test-card-1',
          name: 'Test Card 1',
          setOrSeries: 'Set 1',
          collectionType: 'mtg',
          condition: 'Near Mint',
          imageUrl: 'https://example.com/card1.jpg',
          dynamicData: '{}',
          acquiredDate: now,
          acquiredPrice: 10.0,
          currentMarketPrice: 10.0,
          lastPriceUpdate: now,
          userId: const drift.Value(newUser1),
          primaryBinderId: const drift.Value('old-binder-1'),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'test-card-2',
          name: 'Test Card 2',
          setOrSeries: 'Set 2',
          collectionType: 'mtg',
          condition: 'Near Mint',
          imageUrl: 'https://example.com/card2.jpg',
          dynamicData: '{}',
          acquiredDate: now,
          acquiredPrice: 10.0,
          currentMarketPrice: 10.0,
          lastPriceUpdate: now,
          userId: const drift.Value(newUser2),
          primaryBinderId: const drift.Value('old-binder-2'),
        ),
      );

      // Create proposal between unprovisioned users
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: newUser1,
        receiverId: newUser2,
        offeredCardIds: ['test-card-1'],
        requestedCardIds: ['test-card-2'],
      );

      // Execute trade transfer
      await db.inboxDao.executeTradeTransfer(
        proposal.id,
        currentUserId: newUser2,
      );

      // Check card 1 is transferred to newUser2's auto-provisioned trade block binder
      final card1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('test-card-1'))).getSingle();
      expect(card1.userId, equals(newUser2));
      expect(card1.primaryBinderId, equals('system_trade_block_$newUser2'));
      expect(card1.isTraded, isTrue);

      // Check card 2 is transferred to newUser1's auto-provisioned trade block binder
      final card2 = await (db.select(db.vaultItems)..where((t) => t.id.equals('test-card-2'))).getSingle();
      expect(card2.userId, equals(newUser1));
      expect(card2.primaryBinderId, equals('system_trade_block_$newUser1'));
      expect(card2.isTraded, isTrue);

      // Verify the binders now genuinely exist in vaultBinders table
      final binder1 = await (db.select(db.vaultBinders)..where((b) => b.id.equals('system_trade_block_$newUser1'))).getSingleOrNull();
      final binder2 = await (db.select(db.vaultBinders)..where((b) => b.id.equals('system_trade_block_$newUser2'))).getSingleOrNull();
      expect(binder1, isNotNull);
      expect(binder1?.systemBinderType, equals('trade_block'));
      expect(binder2, isNotNull);
      expect(binder2?.systemBinderType, equals('trade_block'));
    });
  });
}

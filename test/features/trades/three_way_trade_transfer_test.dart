import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/daos/inbox_dao.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'trade_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final userA = createTestUser(id: 'user-a', username: 'alice', displayName: 'Alice');
  final userB = createTestUser(id: 'user-b', username: 'bob', displayName: 'Bob');
  final userC = createTestUser(id: 'user-c', username: 'charlie', displayName: 'Charlie');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.userProfiles).insert(userA);
    await db.into(db.userProfiles).insert(userB);
    await db.into(db.userProfiles).insert(userC);
  });

  tearDown(() async {
    await db.close();
  });

  group('Atomic 3-Way Trade Card Transfer Engine in InboxDao', () {
    test('Executes atomic 3-way trade card transfers across Alice -> Bob, Bob -> Charlie, Charlie -> Alice', () async {
      // 1. Seed initial cards in each user's vault
      final cardA = createTestCard(
        id: 'card-a-1',
        name: 'Mox Sapphire',
        currentMarketPrice: 100.0,
        userId: userA.id,
      );
      final cardB = createTestCard(
        id: 'card-b-1',
        name: 'Black Lotus',
        currentMarketPrice: 100.0,
        userId: userB.id,
      );
      final cardC = createTestCard(
        id: 'card-c-1',
        name: 'Time Walk',
        currentMarketPrice: 100.0,
        userId: userC.id,
      );

      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);
      await db.into(db.vaultItems).insert(cardC);

      // 2. Build 3-way transfers:
      // Alice -> Bob: cardA
      // Bob -> Charlie: cardB
      // Charlie -> Alice: cardC
      final transferAtoB = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferBtoC = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userC.id);
      final transferCtoA = createTestTransfer(card: cardC, senderId: userC.id, recipientId: userA.id);

      final pA = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 100.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 100.0, receivingTotalValue: 100.0);
      final pC = TradeParticipant(user: userC, sendingTotalValue: 100.0, receivingTotalValue: 100.0);
      final fairness = TradeFairnessResult.evaluate([pA, pB, pC]);

      // 3. Propose 3-way trade via InboxDao
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        thirdParticipantId: userC.id,
        isThreeWay: true,
        cardTransfersJson: TradeCardTransfer.listToJson([
          transferAtoB,
          transferBtoC,
          transferCtoA,
        ]),
        fairnessSummaryJson: fairness.toJsonString(),
        offeredCardIds: [cardA.id],
        requestedCardIds: [cardB.id, cardC.id],
        offeredTotalValue: 100.0,
        requestedTotalValue: 200.0,
        note: 'Pod trade: A->B, B->C, C->A',
      );

      expect(proposal.isThreeWay, isTrue);
      expect(proposal.thirdParticipantId, equals(userC.id));
      expect(proposal.status, equals('pending'));

      // 4. Verify notifications and chat messages sent to BOTH Bob and Charlie
      final notifsBob = await db.inboxDao.watchNotifications(userB.id).first;
      expect(notifsBob.any((n) => n.targetEntityId == proposal.id), isTrue);

      final notifsCharlie = await db.inboxDao.watchNotifications(userC.id).first;
      expect(notifsCharlie.any((n) => n.targetEntityId == proposal.id), isTrue);

      // Verify chat messages created for Bob and Charlie
      final msgsBob = await db.inboxDao.watchMessages(
        InboxDao.getConversationId(userA.id, userB.id),
      ).first;
      expect(msgsBob.any((m) => m.attachmentType == 'trade_proposal'), isTrue);

      final msgsCharlie = await db.inboxDao.watchMessages(
        InboxDao.getConversationId(userA.id, userC.id),
      ).first;
      expect(msgsCharlie.any((m) => m.attachmentType == 'trade_proposal'), isTrue);

      // 5. Accept and execute 3-way trade transfer
      await db.inboxDao.executeTradeTransfer(
        proposal.id,
        currentUserId: userB.id,
      );

      // 6. Verify proposal status is 'accepted'
      final updatedProposal = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(proposal.id)))
          .getSingle();
      expect(updatedProposal.status, equals('accepted'));

      // 7. Verify atomic card reassignments in SQLite:
      // Card A should belong to User B in system_trade_block_user-b
      final updatedCardA = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals(cardA.id)))
          .getSingle();
      expect(updatedCardA.userId, equals(userB.id));
      expect(updatedCardA.primaryBinderId, equals('system_trade_block_${userB.id}'));
      expect(updatedCardA.isTraded, isTrue);

      // Card B should belong to User C in system_trade_block_user-c
      final updatedCardB = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals(cardB.id)))
          .getSingle();
      expect(updatedCardB.userId, equals(userC.id));
      expect(updatedCardB.primaryBinderId, equals('system_trade_block_${userC.id}'));
      expect(updatedCardB.isTraded, isTrue);

      // Card C should belong to User A in system_trade_block_user-a
      final updatedCardC = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals(cardC.id)))
          .getSingle();
      expect(updatedCardC.userId, equals(userA.id));
      expect(updatedCardC.primaryBinderId, equals('system_trade_block_${userA.id}'));
      expect(updatedCardC.isTraded, isTrue);

      // 8. Verify confirmation messages were delivered to both Alice and Charlie
      final updatedMsgsBobAlice = await db.inboxDao.watchMessages(
        InboxDao.getConversationId(userB.id, userA.id),
      ).first;
      expect(
        updatedMsgsBobAlice.any((m) => m.messageText.contains('Trade accepted')),
        isTrue,
      );

      final updatedMsgsBobCharlie = await db.inboxDao.watchMessages(
        InboxDao.getConversationId(userB.id, userC.id),
      ).first;
      expect(
        updatedMsgsBobCharlie.any((m) => m.messageText.contains('Trade accepted')),
        isTrue,
      );
    });

    test('Declining 3-way trade marks proposal as declined without transferring cards', () async {
      final cardA = createTestCard(id: 'card-a-2', name: 'Card A2', userId: userA.id);
      final cardB = createTestCard(id: 'card-b-2', name: 'Card B2', userId: userB.id);
      final cardC = createTestCard(id: 'card-c-2', name: 'Card C2', userId: userC.id);

      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);
      await db.into(db.vaultItems).insert(cardC);

      final transferAtoB = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferBtoC = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userC.id);
      final transferCtoA = createTestTransfer(card: cardC, senderId: userC.id, recipientId: userA.id);

      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        thirdParticipantId: userC.id,
        isThreeWay: true,
        cardTransfersJson: TradeCardTransfer.listToJson([
          transferAtoB,
          transferBtoC,
          transferCtoA,
        ]),
        offeredCardIds: [cardA.id],
        requestedCardIds: [cardB.id, cardC.id],
        offeredTotalValue: 50.0,
        requestedTotalValue: 50.0,
      );

      // Decline trade
      await db.inboxDao.respondToTradeProposal(
        proposal.id,
        accept: false,
        transferCards: false,
        currentUserId: userB.id,
      );

      final declined = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(proposal.id)))
          .getSingle();
      expect(declined.status, equals('declined'));

      // Verify card ownership has NOT changed
      final cardAAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA.id))).getSingle();
      final cardBAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardB.id))).getSingle();
      final cardCAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardC.id))).getSingle();

      expect(cardAAfter.userId, equals(userA.id));
      expect(cardBAfter.userId, equals(userB.id));
      expect(cardCAfter.userId, equals(userC.id));
    });
  });
}

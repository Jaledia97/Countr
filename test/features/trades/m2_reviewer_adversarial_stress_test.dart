import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'trade_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Critic: Mathematical Invariants & Edge Cases', () {
    final userA = createTestUser(id: 'user-a', username: 'alice', displayName: 'Alice');
    final userB = createTestUser(id: 'user-b', username: 'bob', displayName: 'Bob');

    test('Zero totals: 0 / 0 does not produce NaN, infinity, or exception', () {
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 0.0,
        receivingTotalValue: 0.0,
      );
      expect(pA.netDelta, equals(0.0));
      expect(pA.absoluteDollarGap, equals(0.0));
      expect(pA.percentageDelta, equals(0.0));
      expect(pA.percentageDelta.isNaN, isFalse);
      expect(pA.percentageDelta.isInfinite, isFalse);
      expect(pA.hasLargeValueGap, isFalse);

      final fairness = TradeFairnessResult.evaluate([pA]);
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.maxGapPercent, equals(0.0));
      expect(fairness.maxDollarGap, equals(0.0));
      expect(fairness.isLargeGap, isFalse);
    });

    test('One-sided trade: sending \$100, receiving \$0 -> 100% gap, Red tier, large gap', () {
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 100.0,
        receivingTotalValue: 0.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 0.0,
        receivingTotalValue: 100.0,
      );

      expect(pA.netDelta, equals(-100.0));
      expect(pA.absoluteDollarGap, equals(100.0));
      expect(pA.percentageDelta, equals(100.0));
      expect(pA.hasLargeValueGap, isTrue);

      expect(pB.netDelta, equals(100.0));
      expect(pB.absoluteDollarGap, equals(100.0));
      expect(pB.percentageDelta, equals(100.0));
      expect(pB.hasLargeValueGap, isTrue);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.lopsided));
      expect(fairness.maxGapPercent, equals(100.0));
      expect(fairness.maxDollarGap, equals(100.0));
      expect(fairness.isLargeGap, isTrue);
    });

    test('Exact boundary tests for Fairness Tiers: 10.0%, 10.01%, 25.0%, 25.01%', () {
      // 10.0% boundary: sending $100, receiving $90 (gap $10 / $100 = 10.0%)
      final p10 = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 90.0);
      final f10 = TradeFairnessResult.evaluate([p10]);
      expect(f10.tier, equals(TradeFairnessTier.fair), reason: '<= 10.0% must be Fair');

      // 10.01% boundary: sending $100, receiving $89.99 (gap $10.01 / $100 = 10.01%)
      final p10Plus = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 89.99);
      final f10Plus = TradeFairnessResult.evaluate([p10Plus]);
      expect(f10Plus.tier, equals(TradeFairnessTier.moderate), reason: '> 10.0% must be Moderate');

      // 25.0% boundary: sending $100, receiving $75 (gap $25 / $100 = 25.0%)
      final p25 = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 75.0);
      final f25 = TradeFairnessResult.evaluate([p25]);
      expect(f25.tier, equals(TradeFairnessTier.moderate), reason: '<= 25.0% must be Moderate');

      // 25.01% boundary: sending $100, receiving $74.99 (gap $25.01 / $100 = 25.01%)
      final p25Plus = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 74.99);
      final f25Plus = TradeFairnessResult.evaluate([p25Plus]);
      expect(f25Plus.tier, equals(TradeFairnessTier.lopsided), reason: '> 25.0% must be Lopsided');
    });

    test('Exact boundary tests for Safeguard Trigger: \$9.99 vs \$10.00 and 14.99% vs 15.0%', () {
      // Sub-thresholds: $9.99 gap and 9.99% (sending $100, receiving $90.01)
      final pBelow = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 90.01);
      final fBelow = TradeFairnessResult.evaluate([pBelow]);
      expect(fBelow.maxDollarGap, closeTo(9.99, 0.001));
      expect(fBelow.maxGapPercent, closeTo(9.99, 0.001));
      expect(fBelow.isLargeGap, isFalse);

      // Exactly $10.00 dollar gap (sending $200, receiving $190: 5% gap, but $10.00 dollar gap)
      final pDollar10 = TradeParticipant(user: userA, sendingTotalValue: 200.0, receivingTotalValue: 190.0);
      final fDollar10 = TradeFairnessResult.evaluate([pDollar10]);
      expect(fDollar10.maxDollarGap, equals(10.0));
      expect(fDollar10.maxGapPercent, equals(5.0));
      expect(fDollar10.isLargeGap, isTrue, reason: 'Dollar gap >= \$10.00 must trigger safeguard');

      // Exactly 15.0% percent gap (sending $20, receiving $17: $3 gap, but 15.0% percent gap)
      final pPct15 = TradeParticipant(user: userA, sendingTotalValue: 20.0, receivingTotalValue: 17.0);
      final fPct15 = TradeFairnessResult.evaluate([pPct15]);
      expect(fPct15.maxDollarGap, equals(3.0));
      expect(fPct15.maxGapPercent, equals(15.0));
      expect(fPct15.isLargeGap, isTrue, reason: 'Percent gap >= 15.0% must trigger safeguard');
    });

    test('Extreme values: high-roller card (\$2,500,000 Black Lotus) calculations', () {
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 2500000.0,
        receivingTotalValue: 2490000.0, // $10,000 difference, but only 0.4% gap
      );
      final fairness = TradeFairnessResult.evaluate([pA]);
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.maxDollarGap, equals(10000.0));
      // Even though percentage is small (0.4%), dollar difference is >= $10.00 -> large gap triggers
      expect(fairness.isLargeGap, isTrue);
    });

    test('Serialization and deserialization roundtrip for TradeCardTransfer and TradeFairnessResult', () {
      final transfer = TradeCardTransfer(
        cardId: 'card-alpha-1',
        senderId: 'user-a',
        recipientId: 'user-b',
        marketPrice: 99.95,
        finish: 'etched',
        cardName: 'Mox Opal',
        setName: 'Scars of Mirrodin',
        collectorNumber: '213',
        imageUrl: 'https://cards.scryfall.io/large/front/a/1.jpg',
        cardSnapshot: {'key': 'value', 'nested': 123},
      );

      final jsonMap = transfer.toJson();
      final roundtrip = TradeCardTransfer.fromJson(jsonMap);

      expect(roundtrip.cardId, equals(transfer.cardId));
      expect(roundtrip.senderId, equals(transfer.senderId));
      expect(roundtrip.recipientId, equals(transfer.recipientId));
      expect(roundtrip.marketPrice, equals(transfer.marketPrice));
      expect(roundtrip.finish, equals(transfer.finish));
      expect(roundtrip.cardName, equals(transfer.cardName));
      expect(roundtrip.setName, equals(transfer.setName));
      expect(roundtrip.collectorNumber, equals(transfer.collectorNumber));
      expect(roundtrip.imageUrl, equals(transfer.imageUrl));
      expect(roundtrip.cardSnapshot['key'], equals('value'));

      // List serialization
      final listJson = TradeCardTransfer.listToJson([transfer]);
      final listParsed = TradeCardTransfer.listFromJson(listJson);
      expect(listParsed.length, equals(1));
      expect(listParsed.first.cardId, equals('card-alpha-1'));

      // Empty / malformed string resilience
      expect(TradeCardTransfer.listFromJson(null), isEmpty);
      expect(TradeCardTransfer.listFromJson(''), isEmpty);
      expect(TradeCardTransfer.listFromJson('{not_a_list}'), isEmpty);

      // Fairness roundtrip
      final fairness = TradeFairnessResult(
        tier: TradeFairnessTier.moderate,
        maxGapPercent: 18.5,
        maxDollarGap: 22.0,
        isLargeGap: true,
        participantPercentGaps: {'user-a': 18.5},
        participantDollarGaps: {'user-a': 22.0},
      );
      final fJson = fairness.toJsonString();
      final fParsed = TradeFairnessResult.tryParse(fJson)!;
      expect(fParsed.tier, equals(TradeFairnessTier.moderate));
      expect(fParsed.maxGapPercent, equals(18.5));
      expect(fParsed.maxDollarGap, equals(22.0));
      expect(fParsed.isLargeGap, isTrue);
      expect(fParsed.participantPercentGaps['user-a'], equals(18.5));

      // Null / invalid fairness parsing resilience
      expect(TradeFairnessResult.tryParse(null), isNull);
      expect(TradeFairnessResult.tryParse(''), isNull);
      expect(TradeFairnessResult.tryParse('invalid_json'), isNull);
    });
  });

  group('Adversarial Critic: Concurrency & State Machine Hardening', () {
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

    test('Double response prevention: Cannot accept a trade proposal that has already been accepted', () async {
      final cardA = createTestCard(id: 'c1', name: 'Card 1', userId: userA.id, currentMarketPrice: 20.0);
      final cardB = createTestCard(id: 'c2', name: 'Card 2', userId: userB.id, currentMarketPrice: 20.0);
      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      final transferAtoB = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferBtoA = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        offeredCardIds: [cardA.id],
        requestedCardIds: [cardB.id],
        offeredTotalValue: 20.0,
        requestedTotalValue: 20.0,
        cardTransfersJson: TradeCardTransfer.listToJson([transferAtoB, transferBtoA]),
      );

      // First response: Accept
      await db.inboxDao.respondToTradeProposal(
        proposal.id,
        accept: true,
        transferCards: true,
        currentUserId: userB.id,
      );

      final accepted = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposal.id))).getSingle();
      expect(accepted.status, equals('accepted'));

      // Second response attempt: Decline (must be a no-op because status is already accepted)
      await db.inboxDao.respondToTradeProposal(
        proposal.id,
        accept: false,
        transferCards: false,
        currentUserId: userB.id,
      );

      final stillAccepted = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposal.id))).getSingle();
      expect(stillAccepted.status, equals('accepted'), reason: 'State machine must reject transition once terminal');
    });

    test('Pre-existing vs newly auto-provisioned system trade block binders', () async {
      // User B already has a system trade block binder
      const existingBinderId = 'custom_trade_block_user-b';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: existingBinderId,
          name: 'My Special Trade Binder',
          collectionType: 'mtg',
          isSystemBinder: const Value(true),
          systemBinderType: const Value('trade_block'),
          userId: Value(userB.id),
          createdAt: DateTime.now(),
        ),
      );

      // User C does NOT have any binder yet
      final bindersCBefore = await (db.select(db.vaultBinders)..where((b) => b.userId.equals(userC.id))).get();
      expect(bindersCBefore, isEmpty);

      final cardA = createTestCard(id: 'c-alpha', name: 'Card Alpha', userId: userA.id, currentMarketPrice: 50.0);
      final cardB = createTestCard(id: 'c-beta', name: 'Card Beta', userId: userB.id, currentMarketPrice: 50.0);
      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      // Route cardA to User B (has existing binder), cardB to User C (needs auto-provisioned binder)
      final transferAtoB = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferBtoC = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userC.id);

      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        thirdParticipantId: userC.id,
        isThreeWay: true,
        offeredCardIds: [cardA.id],
        requestedCardIds: [cardB.id],
        offeredTotalValue: 50.0,
        requestedTotalValue: 50.0,
        cardTransfersJson: TradeCardTransfer.listToJson([transferAtoB, transferBtoC]),
      );

      // Execute transfer
      await db.inboxDao.executeTradeTransfer(proposal.id, currentUserId: userB.id);

      // Card Alpha should be assigned to User B's existing binder
      final transferredA = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA.id))).getSingle();
      expect(transferredA.userId, equals(userB.id));
      expect(transferredA.primaryBinderId, equals(existingBinderId));

      // Card Beta should be assigned to User C's auto-provisioned binder
      final transferredB = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardB.id))).getSingle();
      expect(transferredB.userId, equals(userC.id));
      expect(transferredB.primaryBinderId, equals('system_trade_block_${userC.id}'));

      // Check that User C now has a system trade block binder created
      final bindersCAfter = await (db.select(db.vaultBinders)..where((b) => b.userId.equals(userC.id))).get();
      expect(bindersCAfter.length, equals(1));
      expect(bindersCAfter.first.systemBinderType, equals('trade_block'));
    });
  });
}

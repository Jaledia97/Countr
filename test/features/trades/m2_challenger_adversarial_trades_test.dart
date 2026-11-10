import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/dialogs/large_value_difference_dialog.dart';
import 'package:countr/features/trades/presentation/widgets/sticky_trade_value_meter.dart';
import 'package:countr/features/trades/presentation/widgets/trade_fairness_gauge.dart';
import 'trade_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final userA = createTestUser(id: 'user-a', username: 'alice', displayName: 'Alice');
  final userB = createTestUser(id: 'user-b', username: 'bob', displayName: 'Bob');
  final userC = createTestUser(id: 'user-c', username: 'charlie', displayName: 'Charlie');
  final userD = createTestUser(id: 'user-d', username: 'david', displayName: 'David');

  // =========================================================================
  // SUITE 1: Tier Boundary Precision & Mathematical Oracles
  // =========================================================================
  group('Suite 1: Tier Boundary Precision & Mathematical Oracles', () {
    test(r'1.1: Exact 10.00% gap threshold evaluates to Green (Fair)', () {
      // Alice sends $100.00, receives $90.00 (gap = $10.00, exactly 10.00%)
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 100.0,
        receivingTotalValue: 90.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 90.0,
        receivingTotalValue: 100.0,
      );

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.tier.color, equals(AppColors.accentEmerald));
      expect(fairness.maxGapPercent, closeTo(10.0, 0.0001));
    });

    test(r'1.2: 10.01% boundary evaluates to Amber (Moderate)', () {
      // Alice sends $100.00, receives $89.99 (gap = $10.01, 10.01%)
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 100.0,
        receivingTotalValue: 89.99,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 89.99,
        receivingTotalValue: 100.0,
      );

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.moderate));
      expect(fairness.tier.color, equals(AppColors.accentAmber));
      expect(fairness.maxGapPercent, closeTo(10.01, 0.001));
    });

    test(r'1.3: Exact 25.00% boundary evaluates to Amber (Moderate)', () {
      // Alice sends $100.00, receives $75.00 (gap = $25.00, exactly 25.00%)
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 100.0,
        receivingTotalValue: 75.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 75.0,
        receivingTotalValue: 100.0,
      );

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.moderate));
      expect(fairness.maxGapPercent, closeTo(25.0, 0.0001));
    });

    test(r'1.4: 25.01% boundary evaluates to Red (Lopsided)', () {
      // Alice sends $100.00, receives $74.99 (gap = $25.01, 25.01%)
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 100.0,
        receivingTotalValue: 74.99,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 74.99,
        receivingTotalValue: 100.0,
      );

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.lopsided));
      expect(fairness.tier.color, equals(AppColors.accentRose));
      expect(fairness.maxGapPercent, closeTo(25.01, 0.001));
    });

    test(r'1.5: Empty trade (0 sending, 0 receiving) evaluates to Green (Fair) with zero gap', () {
      final pA = TradeParticipant(user: userA, sendingTotalValue: 0.0, receivingTotalValue: 0.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 0.0, receivingTotalValue: 0.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.maxGapPercent, equals(0.0));
      expect(fairness.maxDollarGap, equals(0.0));
      expect(fairness.isLargeGap, isFalse);
    });

    test(r'1.6: One-way gift (A gives $50, B gives $0) evaluates to Red (Lopsided) at 100.0%', () {
      final pA = TradeParticipant(user: userA, sendingTotalValue: 50.0, receivingTotalValue: 0.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 0.0, receivingTotalValue: 50.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.lopsided));
      expect(fairness.maxGapPercent, equals(100.0));
      expect(fairness.maxDollarGap, equals(50.0));
      expect(fairness.isLargeGap, isTrue);
    });
  });

  // =========================================================================
  // SUITE 2: Large Value Difference Safeguard Trigger Invariants ($10 / 15%)
  // =========================================================================
  group('Suite 2: Large Value Difference Safeguard Trigger Invariants', () {
    test(r'2.1: Sub-threshold trade ($9.99 gap & 9.99% gap) passes through without safeguard', () {
      // Alice gives $100.00, receives $90.01 (gap = $9.99, 9.99%)
      // Both dollar < 10.0 and percent < 15.0 -> isLargeGap must be false
      final pA = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 90.01);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 90.01, receivingTotalValue: 100.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.isLargeGap, isFalse);
      expect(pA.hasLargeValueGap, isFalse);
      expect(pB.hasLargeValueGap, isFalse);
    });

    test(r'2.2: Exact $10.00 dollar gap triggers safeguard even when tier is Fair (10.00%)', () {
      // Alice gives $100.00, receives $90.00 (gap = $10.00, 10.00%)
      // 10.00% is Green tier (Fair), BUT $10.00 >= $10.00 dollar rule triggers safeguard!
      final pA = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 90.00);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 90.00, receivingTotalValue: 100.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.maxDollarGap, equals(10.00));
      expect(fairness.isLargeGap, isTrue);
      expect(pA.hasLargeValueGap, isTrue);
    });

    test(r'2.3: Exact 15.00% gap triggers safeguard even when dollar gap is only $1.50', () {
      // Alice gives $10.00, receives $8.50 (gap = $1.50, exactly 15.00%)
      // Dollar gap ($1.50) is well below $10.00, but 15.00% >= 15.0% triggers safeguard!
      final pA = TradeParticipant(user: userA, sendingTotalValue: 10.0, receivingTotalValue: 8.50);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 8.50, receivingTotalValue: 10.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.maxDollarGap, equals(1.50));
      expect(fairness.maxGapPercent, closeTo(15.0, 0.0001));
      expect(fairness.isLargeGap, isTrue);
      expect(pA.hasLargeValueGap, isTrue);
    });

    test(r'2.4: 14.90% gap below $10 does NOT trigger safeguard', () {
      // Alice gives $10.00, receives $8.51 (gap = $1.49, 14.90%)
      final pA = TradeParticipant(user: userA, sendingTotalValue: 10.0, receivingTotalValue: 8.51);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 8.51, receivingTotalValue: 10.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.maxDollarGap, closeTo(1.49, 0.001));
      expect(fairness.maxGapPercent, closeTo(14.90, 0.01));
      expect(fairness.isLargeGap, isFalse);
      expect(pA.hasLargeValueGap, isFalse);
    });

    test(r'2.5: Low dollar trade ($1.00 vs $0.85, 15.00% gap) triggers percentage safeguard', () {
      final pA = TradeParticipant(user: userA, sendingTotalValue: 1.0, receivingTotalValue: 0.85);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 0.85, receivingTotalValue: 1.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.maxDollarGap, closeTo(0.15, 0.001));
      expect(fairness.maxGapPercent, closeTo(15.0, 0.001));
      expect(fairness.isLargeGap, isTrue);
    });

    test(r'2.6: Zero-volume trade ($0 vs $0) does NOT trigger safeguard', () {
      final pA = TradeParticipant(user: userA, sendingTotalValue: 0.0, receivingTotalValue: 0.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 0.0, receivingTotalValue: 0.0);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.isLargeGap, isFalse);
    });
  });

  // =========================================================================
  // SUITE 3: 3-Way Pod Trade Topologies & Dynamic Routing
  // =========================================================================
  group('Suite 3: 3-Way Pod Trade Topologies & Dynamic Routing', () {
    late TradeProposalController controller;

    setUp(() {
      controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
          initialThirdPartner: userC,
        ),
      );
    });

    test(r'3.1: Cyclic 3-Way Pod (A->B $100, B->C $100, C->A $100) produces zero net delta for all', () {
      final cardA = createTestCard(id: 'c-a', name: 'Card A', currentMarketPrice: 100.0, userId: userA.id);
      final cardB = createTestCard(id: 'c-b', name: 'Card B', currentMarketPrice: 100.0, userId: userB.id);
      final cardC = createTestCard(id: 'c-c', name: 'Card C', currentMarketPrice: 100.0, userId: userC.id);

      controller.addSendingCard(userA.id, cardA); // Default: Bob
      controller.addSendingCard(userB.id, cardB); // Default: Alice
      controller.addSendingCard(userC.id, cardC); // Default: Alice

      // Re-route Bob's card to Charlie (B -> C)
      controller.updateCardRecipient(cardId: 'c-b', newRecipientId: userC.id);

      // Now: A->B, B->C, C->A
      final state = controller.state;
      final pA = state.getParticipant(userA.id)!;
      final pB = state.getParticipant(userB.id)!;
      final pC = state.getParticipant(userC.id)!;

      expect(pA.sendingTotalValue, equals(100.0));
      expect(pA.receivingTotalValue, equals(100.0));
      expect(pA.netDelta, equals(0.0));
      expect(pA.percentageDelta, equals(0.0));

      expect(pB.sendingTotalValue, equals(100.0));
      expect(pB.receivingTotalValue, equals(100.0));
      expect(pB.netDelta, equals(0.0));

      expect(pC.sendingTotalValue, equals(100.0));
      expect(pC.receivingTotalValue, equals(100.0));
      expect(pC.netDelta, equals(0.0));

      expect(state.fairness.tier, equals(TradeFairnessTier.fair));
      expect(state.fairness.maxGapPercent, equals(0.0));
      expect(state.fairness.maxDollarGap, equals(0.0));
      expect(state.fairness.isLargeGap, isFalse);
      expect(state.totalMarketVolume, equals(300.0));
    });

    test(r'3.2: Reverse Cyclic 3-Way Pod (A->C $75, C->B $75, B->A $75) produces zero net delta', () {
      final cardA = createTestCard(id: 'c-a2', name: 'Card A2', currentMarketPrice: 75.0, userId: userA.id);
      final cardB = createTestCard(id: 'c-b2', name: 'Card B2', currentMarketPrice: 75.0, userId: userB.id);
      final cardC = createTestCard(id: 'c-c2', name: 'Card C2', currentMarketPrice: 75.0, userId: userC.id);

      controller.addSendingCard(userA.id, cardA);
      controller.addSendingCard(userB.id, cardB);
      controller.addSendingCard(userC.id, cardC);

      // Re-route A to Charlie (A -> C)
      controller.updateCardRecipient(cardId: 'c-a2', newRecipientId: userC.id);
      // Re-route C to Bob (C -> B)
      controller.updateCardRecipient(cardId: 'c-c2', newRecipientId: userB.id);
      // B defaults to Alice (B -> A)

      final state = controller.state;
      expect(state.getParticipant(userA.id)!.netDelta, equals(0.0));
      expect(state.getParticipant(userB.id)!.netDelta, equals(0.0));
      expect(state.getParticipant(userC.id)!.netDelta, equals(0.0));
      expect(state.fairness.tier, equals(TradeFairnessTier.fair));
      expect(state.fairness.isLargeGap, isFalse);
    });

    test(r'3.3: Star Topology Hub Outbound (A->B $50 & A->C $50, B & C give $0) evaluates to Lopsided', () {
      final cardA1 = createTestCard(id: 'c-a-star1', name: 'A Star 1', currentMarketPrice: 50.0, userId: userA.id);
      final cardA2 = createTestCard(id: 'c-a-star2', name: 'A Star 2', currentMarketPrice: 50.0, userId: userA.id);

      controller.addSendingCard(userA.id, cardA1); // to Bob
      controller.addSendingCard(userA.id, cardA2); // to Bob initially
      controller.updateCardRecipient(cardId: 'c-a-star2', newRecipientId: userC.id); // to Charlie

      final state = controller.state;
      final pA = state.getParticipant(userA.id)!;
      final pB = state.getParticipant(userB.id)!;
      final pC = state.getParticipant(userC.id)!;

      // Alice sends $100, receives $0 -> net -$100, 100% gap
      expect(pA.sendingTotalValue, equals(100.0));
      expect(pA.receivingTotalValue, equals(0.0));
      expect(pA.netDelta, equals(-100.0));
      expect(pA.percentageDelta, equals(100.0));

      // Bob sends $0, receives $50 -> net +$50, 100% gap
      expect(pB.sendingTotalValue, equals(0.0));
      expect(pB.receivingTotalValue, equals(50.0));
      expect(pB.netDelta, equals(50.0));

      // Charlie sends $0, receives $50 -> net +$50, 100% gap
      expect(pC.sendingTotalValue, equals(0.0));
      expect(pC.receivingTotalValue, equals(50.0));
      expect(pC.netDelta, equals(50.0));

      expect(state.fairness.tier, equals(TradeFairnessTier.lopsided));
      expect(state.fairness.isLargeGap, isTrue);
    });

    test(r'3.4: Balanced Star Hub (A sends $50 to B, $50 to C; B sends $50 to A; C sends $50 to A)', () {
      final cardA1 = createTestCard(id: 'c-a1', name: 'Card A1', currentMarketPrice: 50.0, userId: userA.id);
      final cardA2 = createTestCard(id: 'c-a2', name: 'Card A2', currentMarketPrice: 50.0, userId: userA.id);
      final cardB = createTestCard(id: 'c-b', name: 'Card B', currentMarketPrice: 50.0, userId: userB.id);
      final cardC = createTestCard(id: 'c-c', name: 'Card C', currentMarketPrice: 50.0, userId: userC.id);

      controller.addSendingCard(userA.id, cardA1); // to Bob
      controller.addSendingCard(userA.id, cardA2); // to Bob
      controller.updateCardRecipient(cardId: 'c-a2', newRecipientId: userC.id); // to Charlie

      controller.addSendingCard(userB.id, cardB); // to Alice
      controller.addSendingCard(userC.id, cardC); // to Alice

      final state = controller.state;
      // All 3 participants have net delta of $0.00
      expect(state.getParticipant(userA.id)!.netDelta, equals(0.0));
      expect(state.getParticipant(userB.id)!.netDelta, equals(0.0));
      expect(state.getParticipant(userC.id)!.netDelta, equals(0.0));

      expect(state.fairness.tier, equals(TradeFairnessTier.fair));
      expect(state.fairness.maxGapPercent, equals(0.0));
      expect(state.fairness.isLargeGap, isFalse);
    });

    test(r'3.5: Bystander 3rd Participant in Pod (Alice <-> Bob trade $60, Charlie has 0 cards)', () {
      final cardA = createTestCard(id: 'c-a', name: 'Card A', currentMarketPrice: 60.0, userId: userA.id);
      final cardB = createTestCard(id: 'c-b', name: 'Card B', currentMarketPrice: 60.0, userId: userB.id);

      controller.addSendingCard(userA.id, cardA); // Alice -> Bob
      controller.addSendingCard(userB.id, cardB); // Bob -> Alice
      // Charlie has 0 cards sending, 0 receiving

      final state = controller.state;
      final pC = state.getParticipant(userC.id)!;
      expect(pC.sendingTotalValue, equals(0.0));
      expect(pC.receivingTotalValue, equals(0.0));
      expect(pC.percentageDelta, equals(0.0));
      expect(pC.absoluteDollarGap, equals(0.0));
      expect(pC.hasLargeValueGap, isFalse);

      expect(state.fairness.tier, equals(TradeFairnessTier.fair));
      expect(state.fairness.isLargeGap, isFalse);
    });

    test(r'3.6: Complex multi-card pass-through mesh with 5 cards across 3 users', () {
      // Alice -> Bob: Card 1 ($20)
      // Alice -> Charlie: Card 2 ($30)
      // Bob -> Alice: Card 3 ($50)
      // Charlie -> Bob: Card 4 ($40)
      // Bob -> Charlie: Card 5 ($10)
      final c1 = createTestCard(id: 'c1', name: 'Card 1', currentMarketPrice: 20.0, userId: userA.id);
      final c2 = createTestCard(id: 'c2', name: 'Card 2', currentMarketPrice: 30.0, userId: userA.id);
      final c3 = createTestCard(id: 'c3', name: 'Card 3', currentMarketPrice: 50.0, userId: userB.id);
      final c4 = createTestCard(id: 'c4', name: 'Card 4', currentMarketPrice: 40.0, userId: userC.id);
      final c5 = createTestCard(id: 'c5', name: 'Card 5', currentMarketPrice: 10.0, userId: userB.id);

      controller.addSendingCard(userA.id, c1); // A->B
      controller.addSendingCard(userA.id, c2); // A->B initially
      controller.updateCardRecipient(cardId: 'c2', newRecipientId: userC.id); // A->C

      controller.addSendingCard(userB.id, c3); // B->A
      controller.addSendingCard(userB.id, c5); // B->A initially
      controller.updateCardRecipient(cardId: 'c5', newRecipientId: userC.id); // B->C

      controller.addSendingCard(userC.id, c4); // C->A initially
      controller.updateCardRecipient(cardId: 'c4', newRecipientId: userB.id); // C->B

      final state = controller.state;
      final pA = state.getParticipant(userA.id)!;
      final pB = state.getParticipant(userB.id)!;
      final pC = state.getParticipant(userC.id)!;

      // Alice gives $20 + $30 = $50. Receives c3 ($50). Net $0.
      expect(pA.sendingTotalValue, equals(50.0));
      expect(pA.receivingTotalValue, equals(50.0));
      expect(pA.netDelta, equals(0.0));

      // Bob gives $50 + $10 = $60. Receives c1 ($20) + c4 ($40) = $60. Net $0.
      expect(pB.sendingTotalValue, equals(60.0));
      expect(pB.receivingTotalValue, equals(60.0));
      expect(pB.netDelta, equals(0.0));

      // Charlie gives $40. Receives c2 ($30) + c5 ($10) = $40. Net $0.
      expect(pC.sendingTotalValue, equals(40.0));
      expect(pC.receivingTotalValue, equals(40.0));
      expect(pC.netDelta, equals(0.0));

      expect(state.fairness.tier, equals(TradeFairnessTier.fair));
      expect(state.fairness.maxGapPercent, equals(0.0));
      expect(state.fairness.isLargeGap, isFalse);
    });

    test(r'3.7: Participant removing ALL cards in 3-way trade updates dynamically without crash', () {
      final cA1 = createTestCard(id: 'ca1', name: 'Card A1', currentMarketPrice: 25.0, userId: userA.id);
      final cA2 = createTestCard(id: 'ca2', name: 'Card A2', currentMarketPrice: 25.0, userId: userA.id);
      final cB = createTestCard(id: 'cb', name: 'Card B', currentMarketPrice: 50.0, userId: userB.id);

      controller.addSendingCard(userA.id, cA1);
      controller.addSendingCard(userA.id, cA2);
      controller.addSendingCard(userB.id, cB);

      expect(controller.state.getParticipant(userA.id)!.sendingCards.length, equals(2));
      expect(controller.state.getParticipant(userA.id)!.sendingTotalValue, equals(50.0));

      // Alice removes first card
      controller.removeSendingCard(userA.id, 'ca1');
      expect(controller.state.getParticipant(userA.id)!.sendingCards.length, equals(1));
      expect(controller.state.getParticipant(userA.id)!.sendingTotalValue, equals(25.0));

      // Alice removes second card (now 0 cards sending)
      controller.removeSendingCard(userA.id, 'ca2');
      final pA = controller.state.getParticipant(userA.id)!;
      expect(pA.sendingCards, isEmpty);
      expect(pA.sendingTotalValue, equals(0.0));
      expect(pA.receivingTotalValue, equals(50.0)); // still receiving cB
      expect(pA.netDelta, equals(50.0));
      expect(pA.percentageDelta, equals(100.0));
      expect(controller.state.fairness.tier, equals(TradeFairnessTier.lopsided));
    });
  });

  // =========================================================================
  // SUITE 4: Partner Addition / Removal Lifecycle & Transfer Rerouting
  // =========================================================================
  group('Suite 4: Partner Addition / Removal Lifecycle & Transfer Rerouting', () {
    test(r'4.1: Enforces strictly max 3 participants ceiling and prevents duplicate additions', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
        ),
      );

      expect(controller.state.participants.length, equals(2));
      expect(controller.state.canAddThirdPartner, isTrue);

      // Add 3rd partner
      controller.addThirdParticipant(userC);
      expect(controller.state.participants.length, equals(3));
      expect(controller.state.canAddThirdPartner, isFalse);

      // Attempt to add 4th partner (David) -> must be ignored
      controller.addThirdParticipant(userD);
      expect(controller.state.participants.length, equals(3));
      expect(controller.state.participants.any((p) => p.id == userD.id), isFalse);

      // Attempt to add duplicate existing partner -> must be ignored
      controller.addThirdParticipant(userA);
      controller.addThirdParticipant(userB);
      expect(controller.state.participants.length, equals(3));
    });

    test(r'4.2: Calling removeThirdParticipant when only 2 exist is safe no-op', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
        ),
      );

      controller.removeThirdParticipant();
      expect(controller.state.participants.length, equals(2));
      expect(controller.state.isThreeWay, isFalse);
    });

    test(r'4.3: Removing 3rd partner drops their cards AND reroutes incoming cards destined to 3rd partner', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
          initialThirdPartner: userC,
        ),
      );

      final cardA = createTestCard(id: 'c-a', name: 'Card A', currentMarketPrice: 40.0, userId: userA.id);
      final cardB = createTestCard(id: 'c-b', name: 'Card B', currentMarketPrice: 40.0, userId: userB.id);
      final cardC = createTestCard(id: 'c-c', name: 'Card C', currentMarketPrice: 40.0, userId: userC.id);

      controller.addSendingCard(userA.id, cardA);
      controller.addSendingCard(userB.id, cardB);
      controller.addSendingCard(userC.id, cardC);

      // Alice routes to Charlie
      controller.updateCardRecipient(cardId: 'c-a', newRecipientId: userC.id);
      // Bob routes to Charlie
      controller.updateCardRecipient(cardId: 'c-b', newRecipientId: userC.id);

      expect(controller.state.transfers.length, equals(3));
      expect(controller.state.getParticipant(userC.id)!.receivingTotalValue, equals(80.0));

      // Remove Charlie from trade
      controller.removeThirdParticipant();

      final state = controller.state;
      expect(state.participants.length, equals(2));
      expect(state.isThreeWay, isFalse);
      expect(state.canAddThirdPartner, isTrue);

      // Charlie's card (c-c) must be dropped
      expect(state.transfers.any((t) => t.cardId == 'c-c'), isFalse);

      // Alice's card (c-a) previously routed to Charlie must now be rerouted to Bob
      final tA = state.transfers.firstWhere((t) => t.cardId == 'c-a');
      expect(tA.recipientId, equals(userB.id));

      // Bob's card (c-b) previously routed to Charlie must now be rerouted to Alice
      final tB = state.transfers.firstWhere((t) => t.cardId == 'c-b');
      expect(tB.recipientId, equals(userA.id));

      // Net deltas for 2-way trade
      expect(state.getParticipant(userA.id)!.netDelta, equals(0.0));
      expect(state.getParticipant(userB.id)!.netDelta, equals(0.0));
      expect(state.fairness.tier, equals(TradeFairnessTier.fair));
    });

    test(r'4.4: Adding 3rd participant back after removal restores clean state', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
          initialThirdPartner: userC,
        ),
      );

      controller.removeThirdParticipant();
      expect(controller.state.participants.length, equals(2));

      controller.addThirdParticipant(userC);
      expect(controller.state.participants.length, equals(3));
      expect(controller.state.isThreeWay, isTrue);
      expect(controller.state.participants[2].id, equals(userC.id));
      expect(controller.state.participants[2].sendingCards, isEmpty);
    });
  });

  // =========================================================================
  // SUITE 5: Concurrency, Rapid Toggling & Race Conditions
  // =========================================================================
  group('Suite 5: Concurrency, Rapid Toggling & Race Conditions', () {
    test(r'5.1: 50x rapid recipient toggles between Bob and Charlie preserves exact state integrity', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
          initialThirdPartner: userC,
        ),
      );

      final card = createTestCard(id: 'rapid-card', name: 'Rapid Card', currentMarketPrice: 88.0, userId: userA.id);
      controller.addSendingCard(userA.id, card);

      // Rapidly toggle recipient between Bob and Charlie 50 times
      for (int i = 0; i < 50; i++) {
        final targetRecipient = (i % 2 == 0) ? userC.id : userB.id;
        controller.updateCardRecipient(cardId: 'rapid-card', newRecipientId: targetRecipient);
      }

      // After 50 iterations (0-49), index 49 is odd -> userB.id
      final state = controller.state;
      expect(state.transfers.length, equals(1));
      expect(state.transfers.first.recipientId, equals(userB.id));
      expect(state.totalMarketVolume, equals(88.0));
      expect(state.getParticipant(userB.id)!.receivingTotalValue, equals(88.0));
      expect(state.getParticipant(userC.id)!.receivingTotalValue, equals(0.0));
    });

    test(r'5.2: Multi-card shuffle across 3 participants converges to correct totals', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
          initialThirdPartner: userC,
        ),
      );

      final cardsA = List.generate(3, (i) => createTestCard(id: 'ca_$i', name: 'Card A$i', currentMarketPrice: 10.0 * (i + 1), userId: userA.id));
      final cardsB = List.generate(3, (i) => createTestCard(id: 'cb_$i', name: 'Card B$i', currentMarketPrice: 15.0 * (i + 1), userId: userB.id));
      final cardsC = List.generate(3, (i) => createTestCard(id: 'cc_$i', name: 'Card C$i', currentMarketPrice: 20.0 * (i + 1), userId: userC.id));

      for (final c in cardsA) {
        controller.addSendingCard(userA.id, c);
      }
      for (final c in cardsB) {
        controller.addSendingCard(userB.id, c);
      }
      for (final c in cardsC) {
        controller.addSendingCard(userC.id, c);
      }

      expect(controller.state.transfers.length, equals(9));

      // Reroute specific cards
      controller.updateCardRecipient(cardId: 'ca_0', newRecipientId: userC.id);
      controller.updateCardRecipient(cardId: 'ca_1', newRecipientId: userB.id);
      controller.updateCardRecipient(cardId: 'ca_2', newRecipientId: userC.id);

      controller.updateCardRecipient(cardId: 'cb_0', newRecipientId: userA.id);
      controller.updateCardRecipient(cardId: 'cb_1', newRecipientId: userC.id);
      controller.updateCardRecipient(cardId: 'cb_2', newRecipientId: userA.id);

      controller.updateCardRecipient(cardId: 'cc_0', newRecipientId: userB.id);
      controller.updateCardRecipient(cardId: 'cc_1', newRecipientId: userA.id);
      controller.updateCardRecipient(cardId: 'cc_2', newRecipientId: userB.id);

      final state = controller.state;
      // Check total volume: cardsA (10+20+30=60) + cardsB (15+30+45=90) + cardsC (20+40+60=120) = 270.0
      expect(state.totalMarketVolume, equals(270.0));

      // Verify recipient calculations:
      // Alice receives: cb_0 (15) + cb_2 (45) + cc_1 (40) = 100.0
      expect(state.getParticipant(userA.id)!.receivingTotalValue, equals(100.0));

      // Bob receives: ca_1 (20) + cc_0 (20) + cc_2 (60) = 100.0
      expect(state.getParticipant(userB.id)!.receivingTotalValue, equals(100.0));

      // Charlie receives: ca_0 (10) + ca_2 (30) + cb_1 (30) = 70.0
      expect(state.getParticipant(userC.id)!.receivingTotalValue, equals(70.0));

      // Sum of receiving values must equal total market volume
      final receivingSum = state.participants.fold<double>(0.0, (sum, p) => sum + p.receivingTotalValue);
      expect(receivingSum, equals(270.0));
    });

    test(r'5.3: Removing non-existent card or updating non-existent card does not corrupt state', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
        ),
      );

      // Safe no-ops
      controller.removeSendingCard(userA.id, 'ghost-card');
      controller.updateCardRecipient(cardId: 'ghost-card', newRecipientId: userB.id);
      expect(controller.state.transfers, isEmpty);
    });

    test(r'5.4: Adding duplicate card ID to same participant is safely deduplicated', () {
      final controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
        ),
      );

      final card = createTestCard(id: 'card-dup', name: 'Dup Card', currentMarketPrice: 20.0, userId: userA.id);
      controller.addSendingCard(userA.id, card);
      controller.addSendingCard(userA.id, card); // Duplicate call

      expect(controller.state.getParticipant(userA.id)!.sendingCards.length, equals(1));
      expect(controller.state.transfers.length, equals(1));
      expect(controller.state.totalMarketVolume, equals(20.0));
    });
  });

  // =========================================================================
  // SUITE 6: Atomic SQLite Multi-Participant Transfer Engine (InboxDao)
  // =========================================================================
  group('Suite 6: Atomic SQLite Multi-Participant Transfer Engine', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.into(db.userProfiles).insert(userA);
      await db.into(db.userProfiles).insert(userB);
      await db.into(db.userProfiles).insert(userC);
    });

    tearDown(() async {
      await db.close();
    });

    test(r'6.1: Full 3-Way Cyclic transfer atomically reassigns ownership and auto-provisions trade block binders', () async {
      final cardA = createTestCard(id: 'vault-a', name: 'Card A', currentMarketPrice: 100.0, userId: userA.id);
      final cardB = createTestCard(id: 'vault-b', name: 'Card B', currentMarketPrice: 100.0, userId: userB.id);
      final cardC = createTestCard(id: 'vault-c', name: 'Card C', currentMarketPrice: 100.0, userId: userC.id);

      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);
      await db.into(db.vaultItems).insert(cardC);

      // Transfers: A -> B, B -> C, C -> A
      final tA = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final tB = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userC.id);
      final tC = createTestTransfer(card: cardC, senderId: userC.id, recipientId: userA.id);

      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        thirdParticipantId: userC.id,
        isThreeWay: true,
        cardTransfersJson: TradeCardTransfer.listToJson([tA, tB, tC]),
        offeredCardIds: [cardA.id],
        requestedCardIds: [cardB.id, cardC.id],
        offeredTotalValue: 100.0,
        requestedTotalValue: 200.0,
      );

      // Execute transfer
      await db.inboxDao.executeTradeTransfer(proposal.id, currentUserId: userB.id);

      // Card A should belong to user B in system_trade_block_user-b
      final updatedA = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA.id))).getSingle();
      expect(updatedA.userId, equals(userB.id));
      expect(updatedA.primaryBinderId, equals('system_trade_block_${userB.id}'));
      expect(updatedA.isTraded, isTrue);

      // Card B should belong to user C in system_trade_block_user-c
      final updatedB = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardB.id))).getSingle();
      expect(updatedB.userId, equals(userC.id));
      expect(updatedB.primaryBinderId, equals('system_trade_block_${userC.id}'));
      expect(updatedB.isTraded, isTrue);

      // Card C should belong to user A in system_trade_block_user-a
      final updatedC = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardC.id))).getSingle();
      expect(updatedC.userId, equals(userA.id));
      expect(updatedC.primaryBinderId, equals('system_trade_block_${userA.id}'));
      expect(updatedC.isTraded, isTrue);

      // Check auto-provisioned binders exist
      final binders = await db.select(db.vaultBinders).get();
      expect(binders.any((b) => b.id == 'system_trade_block_${userA.id}'), isTrue);
      expect(binders.any((b) => b.id == 'system_trade_block_${userB.id}'), isTrue);
      expect(binders.any((b) => b.id == 'system_trade_block_${userC.id}'), isTrue);
    });

    test(r'6.2: Re-trading already traded card executes cleanly in a secondary trade', () async {
      // Trade 1: Alice -> Bob
      final card = createTestCard(id: 'chain-card', name: 'Lotus Petal', currentMarketPrice: 20.0, userId: userA.id);
      await db.into(db.vaultItems).insert(card);

      final t1 = createTestTransfer(card: card, senderId: userA.id, recipientId: userB.id);
      final prop1 = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        cardTransfersJson: TradeCardTransfer.listToJson([t1]),
        offeredCardIds: [card.id],
        requestedCardIds: [],
        offeredTotalValue: 20.0,
      );
      await db.inboxDao.executeTradeTransfer(prop1.id, currentUserId: userB.id);

      final afterTrade1 = await (db.select(db.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      expect(afterTrade1.userId, equals(userB.id));

      // Trade 2: Bob -> Charlie (card already has isTraded = true)
      final t2 = createTestTransfer(card: afterTrade1, senderId: userB.id, recipientId: userC.id);
      final prop2 = await db.inboxDao.createTradeProposal(
        proposerId: userB.id,
        receiverId: userC.id,
        cardTransfersJson: TradeCardTransfer.listToJson([t2]),
        offeredCardIds: [card.id],
        requestedCardIds: [],
        offeredTotalValue: 20.0,
      );
      await db.inboxDao.executeTradeTransfer(prop2.id, currentUserId: userC.id);

      final afterTrade2 = await (db.select(db.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      expect(afterTrade2.userId, equals(userC.id));
      expect(afterTrade2.primaryBinderId, equals('system_trade_block_${userC.id}'));
    });

    test(r'6.3: Double-acceptance guard prevents re-executing transfers', () async {
      final card = createTestCard(id: 'once-card', name: 'Single Use Card', currentMarketPrice: 50.0, userId: userA.id);
      await db.into(db.vaultItems).insert(card);

      final t = createTestTransfer(card: card, senderId: userA.id, recipientId: userB.id);
      final prop = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        cardTransfersJson: TradeCardTransfer.listToJson([t]),
        offeredCardIds: [card.id],
        requestedCardIds: [],
        offeredTotalValue: 50.0,
      );

      // Accept once
      await db.inboxDao.executeTradeTransfer(prop.id, currentUserId: userB.id);

      // Try accepting again -> must safely return without error or duplicate handling
      await db.inboxDao.executeTradeTransfer(prop.id, currentUserId: userB.id);

      final check = await (db.select(db.tradeProposals)..where((t) => t.id.equals(prop.id))).getSingle();
      expect(check.status, equals('accepted'));
    });

    test(r'6.4: Deleted / missing card in transfer payload does not crash transaction', () async {
      // Alice trades card1 and card2, but card2 is deleted before trade acceptance
      final card1 = createTestCard(id: 'survivor-card', name: 'Survivor', currentMarketPrice: 30.0, userId: userA.id);
      await db.into(db.vaultItems).insert(card1);

      final t1 = createTestTransfer(card: card1, senderId: userA.id, recipientId: userB.id);
      final t2 = TradeCardTransfer(
        cardId: 'deleted-card-xyz',
        senderId: userA.id,
        recipientId: userB.id,
        marketPrice: 30.0,
        finish: 'non_foil',
        cardName: 'Ghost Card',
      );

      final prop = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        cardTransfersJson: TradeCardTransfer.listToJson([t1, t2]),
        offeredCardIds: [card1.id, 'deleted-card-xyz'],
        requestedCardIds: [],
        offeredTotalValue: 60.0,
      );

      // Execute transfer: should succeed for card1 and silently skip ghost card
      await db.inboxDao.executeTradeTransfer(prop.id, currentUserId: userB.id);

      final updated1 = await (db.select(db.vaultItems)..where((t) => t.id.equals(card1.id))).getSingle();
      expect(updated1.userId, equals(userB.id));
    });
  });

  // =========================================================================
  // SUITE 7: UI & Widget Integration Safeguards
  // =========================================================================
  group('Suite 7: UI & Widget Integration Safeguards', () {
    testWidgets(r'7.1: StickyTradeValueMeter renders without overflow on narrow 320px viewport with 3 participants', (tester) async {
      // iPhone SE / narrow viewport
      await tester.binding.setSurfaceSize(const Size(320, 700));

      final pA = TradeParticipant(
        user: createTestUser(id: 'a', username: 'alice_super_long_name_here', displayName: 'Alice Very Long Name'),
        sendingTotalValue: 9999.99,
        receivingTotalValue: 8888.88,
      );
      final pB = TradeParticipant(
        user: createTestUser(id: 'b', username: 'bob_extremely_long_name_here', displayName: 'Bob Long Name'),
        sendingTotalValue: 5555.55,
        receivingTotalValue: 6666.66,
      );
      final pC = TradeParticipant(
        user: createTestUser(id: 'c', username: 'charlie_extra_long_name', displayName: 'Charlie Name'),
        sendingTotalValue: 1234.56,
        receivingTotalValue: 1234.56,
      );

      final fairness = TradeFairnessResult.evaluate([pA, pB, pC]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StickyTradeValueMeter(
                participants: [pA, pB, pC],
                fairness: fairness,
                compact: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
      expect(find.byKey(const Key('trade_fairness_gauge')), findsOneWidget);
      expect(find.byKey(const Key('value_meter_participant_net_a')), findsOneWidget);
      expect(find.byKey(const Key('value_meter_participant_net_b')), findsOneWidget);
      expect(find.byKey(const Key('value_meter_participant_net_c')), findsOneWidget);

      // Verify zero Flutter errors or RenderFlex overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets(r'7.2: TradeFairnessGauge clamps needle properly under extreme gap values (0%, 25%, 500%)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 300));

      // Test 0% gap
      const fairZero = TradeFairnessResult(
        tier: TradeFairnessTier.fair,
        maxGapPercent: 0.0,
        maxDollarGap: 0.0,
        isLargeGap: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TradeFairnessGauge(fairness: fairZero),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('FAIR (0.0% gap)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test extreme 500% gap (needle must clamp to 1.0 without overflowing)
      const extremeGap = TradeFairnessResult(
        tier: TradeFairnessTier.lopsided,
        maxGapPercent: 500.0,
        maxDollarGap: 5000.0,
        isLargeGap: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TradeFairnessGauge(fairness: extremeGap),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('LOPSIDED (500.0% gap)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(r'7.3: LargeValueDifferenceDialog dismisses on Review Trade (returns false) and proceeds on Proceed Anyway (returns true)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));

      bool? dialogResult;

      Widget buildHostWidget() {
        return MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const Key('trigger_dialog_button'),
                  onPressed: () async {
                    dialogResult = await LargeValueDifferenceDialog.checkAndConfirm(
                      context: context,
                      dollarGap: 25.50,
                      percentGap: 30.0,
                    );
                  },
                  child: const Text('Check'),
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHostWidget());
      await tester.pumpAndSettle();

      // Trigger dialog
      await tester.tap(find.byKey(const Key('trigger_dialog_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.textContaining(r'$25.50 (30.0%) value gap'), findsOneWidget);

      // Tap [Review Trade] -> returns false
      await tester.tap(find.byKey(const Key('review_trade_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(dialogResult, isFalse);

      // Trigger dialog again
      await tester.tap(find.byKey(const Key('trigger_dialog_button')));
      await tester.pumpAndSettle();

      // Tap [Proceed Anyway] -> returns true
      await tester.tap(find.byKey(const Key('proceed_anyway_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(dialogResult, isTrue);
    });

    testWidgets(r'7.4: LargeValueDifferenceDialog passes through immediately without modal when gaps are safe', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const Key('trigger_safe_button'),
                  onPressed: () async {
                    dialogResult = await LargeValueDifferenceDialog.checkAndConfirm(
                      context: context,
                      dollarGap: 9.99,
                      percentGap: 14.99,
                    );
                  },
                  child: const Text('Check Safe'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_safe_button')));
      await tester.pumpAndSettle();

      // No modal should be opened, should return true immediately
      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(dialogResult, isTrue);
    });
  });
}

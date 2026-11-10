import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'trade_test_helpers.dart';

void main() {
  group('TradeProposalController State Management', () {
    final userA = createTestUser(id: 'user-a', username: 'alice', displayName: 'Alice');
    final userB = createTestUser(id: 'user-b', username: 'bob', displayName: 'Bob');
    final userC = createTestUser(id: 'user-c', username: 'charlie', displayName: 'Charlie');
    final userD = createTestUser(id: 'user-d', username: 'david', displayName: 'David');

    late TradeProposalController controller;

    setUp(() {
      controller = TradeProposalController(
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
        ),
      );
    });

    test('Initializes with 2 participants and zero totals', () {
      final state = controller.state;
      expect(state.participants.length, equals(2));
      expect(state.isThreeWay, isFalse);
      expect(state.canAddThirdPartner, isTrue);
      expect(state.participants[0].id, equals('user-a'));
      expect(state.participants[1].id, equals('user-b'));
      expect(state.totalMarketVolume, equals(0.0));
      expect(state.hasAnyCards, isFalse);
    });

    test('Adds 3rd partner and enforces max 3 participants', () {
      expect(controller.state.canAddThirdPartner, isTrue);

      controller.addThirdParticipant(userC);
      expect(controller.state.participants.length, equals(3));
      expect(controller.state.isThreeWay, isTrue);
      expect(controller.state.canAddThirdPartner, isFalse);
      expect(controller.state.participants[2].id, equals('user-c'));

      // Attempt to add a 4th participant (must be rejected)
      controller.addThirdParticipant(userD);
      expect(controller.state.participants.length, equals(3));

      // Attempt to add duplicate participant (must be rejected)
      controller.addThirdParticipant(userB);
      expect(controller.state.participants.length, equals(3));
    });

    test('Adding cards updates sending and receiving values dynamically', () {
      final cardA = createTestCard(
        id: 'card-a1',
        name: 'Black Lotus',
        currentMarketPrice: 100.0,
        userId: userA.id,
      );
      final cardB = createTestCard(
        id: 'card-b1',
        name: 'Mox Ruby',
        currentMarketPrice: 80.0,
        userId: userB.id,
      );

      controller.addSendingCard(userA.id, cardA);
      controller.addSendingCard(userB.id, cardB);

      final state = controller.state;
      expect(state.hasAnyCards, isTrue);
      expect(state.totalMarketVolume, equals(180.0));

      final partA = state.getParticipant(userA.id)!;
      final partB = state.getParticipant(userB.id)!;

      // Alice sends $100, receives $80
      expect(partA.sendingTotalValue, equals(100.0));
      expect(partA.receivingTotalValue, equals(80.0));
      expect(partA.netDelta, equals(-20.0));

      // Bob sends $80, receives $100
      expect(partB.sendingTotalValue, equals(80.0));
      expect(partB.receivingTotalValue, equals(100.0));
      expect(partB.netDelta, equals(20.0));

      // Percentage gap: |80 - 100| / 100 = 20.0% -> Amber (moderate)
      expect(state.fairness.tier, equals(TradeFairnessTier.moderate));
      expect(state.fairness.isLargeGap, isTrue);
    });

    test('3-way trade card routing via updateCardRecipient updates receiving totals', () {
      controller.addThirdParticipant(userC);

      final cardA1 = createTestCard(
        id: 'card-a1',
        name: 'Underground Sea',
        currentMarketPrice: 60.0,
        userId: userA.id,
      );
      final cardB1 = createTestCard(
        id: 'card-b1',
        name: 'Volcanic Island',
        currentMarketPrice: 60.0,
        userId: userB.id,
      );
      final cardC1 = createTestCard(
        id: 'card-c1',
        name: 'Tropical Island',
        currentMarketPrice: 60.0,
        userId: userC.id,
      );

      controller.addSendingCard(userA.id, cardA1); // Default recipient is Bob (first other)
      controller.addSendingCard(userB.id, cardB1); // Default recipient is Alice
      controller.addSendingCard(userC.id, cardC1); // Default recipient is Alice

      // Re-route cardA1 to Charlie instead of Bob
      controller.updateCardRecipient(
        cardId: 'card-a1',
        newRecipientId: userC.id,
      );

      // Re-route cardB1 to Charlie
      controller.updateCardRecipient(
        cardId: 'card-b1',
        newRecipientId: userC.id,
      );

      final state = controller.state;
      final pA = state.getParticipant(userA.id)!;
      final pB = state.getParticipant(userB.id)!;
      final pC = state.getParticipant(userC.id)!;

      // Alice: sends $60 (cardA1), receives $60 (cardC1 from Charlie) -> net 0.0
      expect(pA.sendingTotalValue, equals(60.0));
      expect(pA.receivingTotalValue, equals(60.0));
      expect(pA.netDelta, equals(0.0));

      // Bob: sends $60 (cardB1), receives $0 -> net -60.0
      expect(pB.sendingTotalValue, equals(60.0));
      expect(pB.receivingTotalValue, equals(0.0));
      expect(pB.netDelta, equals(-60.0));

      // Charlie: sends $60 (cardC1), receives $120 (cardA1 + cardB1) -> net +60.0
      expect(pC.sendingTotalValue, equals(60.0));
      expect(pC.receivingTotalValue, equals(120.0));
      expect(pC.netDelta, equals(60.0));

      // Check receiving cards list on Charlie
      expect(pC.receivingTransfers.length, equals(2));
      expect(pC.receivingTransfers.any((t) => t.cardId == 'card-a1'), isTrue);
      expect(pC.receivingTransfers.any((t) => t.cardId == 'card-b1'), isTrue);
    });

    test('Removing 3rd partner automatically reroutes transfers and restores 2-way state', () {
      controller.addThirdParticipant(userC);

      final cardA = createTestCard(id: 'card-a', name: 'Card A', currentMarketPrice: 30.0);
      final cardC = createTestCard(id: 'card-c', name: 'Card C', currentMarketPrice: 40.0);

      controller.addSendingCard(userA.id, cardA);
      controller.addSendingCard(userC.id, cardC);

      // Route cardA to Charlie
      controller.updateCardRecipient(cardId: 'card-a', newRecipientId: userC.id);

      expect(controller.state.isThreeWay, isTrue);
      expect(controller.state.transfers.length, equals(2));

      // Remove Charlie
      controller.removeThirdParticipant();

      final state = controller.state;
      expect(state.isThreeWay, isFalse);
      expect(state.participants.length, equals(2));
      expect(state.canAddThirdPartner, isTrue);

      // Card C from Charlie should be gone
      expect(state.transfers.any((t) => t.cardId == 'card-c'), isFalse);

      // Card A should now be rerouted to Bob
      final transferA = state.transfers.firstWhere((t) => t.cardId == 'card-a');
      expect(transferA.recipientId, equals(userB.id));
    });

    test('Removing sending card updates transfers and fairness correctly', () {
      final cardA1 = createTestCard(id: 'card-a1', name: 'Card 1', currentMarketPrice: 50.0);
      final cardA2 = createTestCard(id: 'card-a2', name: 'Card 2', currentMarketPrice: 50.0);

      controller.addSendingCard(userA.id, cardA1);
      controller.addSendingCard(userA.id, cardA2);
      expect(controller.state.getParticipant(userA.id)!.sendingTotalValue, equals(100.0));

      controller.removeSendingCard(userA.id, 'card-a1');
      expect(controller.state.getParticipant(userA.id)!.sendingTotalValue, equals(50.0));
      expect(controller.state.transfers.length, equals(1));
      expect(controller.state.transfers.first.cardId, equals('card-a2'));
    });
  });
}

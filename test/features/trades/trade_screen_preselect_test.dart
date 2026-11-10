import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'trade_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final userA = createTestUser(id: 'user-a', username: 'alice', displayName: 'Alice');
  final userB = createTestUser(id: 'user-b', username: 'bob', displayName: 'Bob');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTradeScreen(TradeProposalParams params) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        inboxDaoProvider.overrideWithValue(db.inboxDao),
      ],
      child: MaterialApp(
        home: TradeScreen(params: params),
      ),
    );
  }

  group('TradeScreen Pre-Selection & Value Calculation Tests', () {
    test('TradeProposalParams with initialPartnerCard stages card and creates transfer in controller initial state', () {
      final preselectedCard = createTestCard(
        id: 'card-ragavan',
        name: 'Ragavan, Nimble Pilferer',
        currentMarketPrice: 45.0,
        userId: userB.id,
      );

      final params = TradeProposalParams(
        currentUser: userA,
        partnerProfile: userB,
        initialPartnerCard: preselectedCard,
      );

      final controller = TradeProposalController(params);
      final state = controller.state;

      // 1. Verify partner's pod has Ragavan staged
      final partnerParticipant = state.participants.firstWhere((p) => p.user.id == userB.id);
      expect(partnerParticipant.sendingCards, hasLength(1));
      expect(partnerParticipant.sendingCards.first.id, equals('card-ragavan'));
      expect(partnerParticipant.sendingTotalValue, equals(45.0));

      // 2. Verify current user starts with 0 cards
      final currentParticipant = state.participants.firstWhere((p) => p.user.id == userA.id);
      expect(currentParticipant.sendingCards, isEmpty);
      expect(currentParticipant.sendingTotalValue, equals(0.0));

      // 3. Verify transfer is automatically generated from partner to current user
      expect(state.transfers, hasLength(1));
      final transfer = state.transfers.first;
      expect(transfer.cardId, equals('card-ragavan'));
      expect(transfer.senderId, equals(userB.id));
      expect(transfer.recipientId, equals(userA.id));

      // 4. Verify fairness result is calculated
      expect(state.fairness, isNotNull);
      expect(state.fairness.participantDollarGaps[userB.id], isNotNull);
    });

    testWidgets('TradeScreen displays staged initialPartnerCard in partner pod and calculates StickyTradeValueMeter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final preselectedCard = createTestCard(
        id: 'card-rhystic-study',
        name: 'Rhystic Study',
        currentMarketPrice: 35.0,
        userId: userB.id,
      );

      final params = TradeProposalParams(
        currentUser: userA,
        partnerProfile: userB,
        initialPartnerCard: preselectedCard,
      );

      await tester.pumpWidget(buildTradeScreen(params));
      await tester.pumpAndSettle();

      // Verify TradeScreen rendered
      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);

      // Verify the staged card chip appears in partner's pod
      // Verify the staged card appears in partner's sending section and current user's receiving section
      expect(find.descendant(of: find.byKey(Key('trade_participant_pod_${userB.id}')), matching: find.text('Rhystic Study')), findsOneWidget);
      expect(find.descendant(of: find.byKey(Key('trade_participant_pod_${userA.id}')), matching: find.text('Rhystic Study')), findsOneWidget);

      // Verify StickyTradeValueMeter reflects the card value ($35.00)
      expect(find.textContaining('35.00'), findsWidgets);
    });

    testWidgets('Adding current user card dynamically updates StickyTradeValueMeter and balances trade', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final preselectedCard = createTestCard(
        id: 'card-dockside',
        name: 'Dockside Extortionist',
        currentMarketPrice: 70.0,
        userId: userB.id,
      );

      final params = TradeProposalParams(
        currentUser: userA,
        partnerProfile: userB,
        initialPartnerCard: preselectedCard,
      );

      final controller = TradeProposalController(params);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            inboxDaoProvider.overrideWithValue(db.inboxDao),
            tradeProposalControllerProvider(params).overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: TradeScreen(params: params),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially partner is offering $70, user offering $0
      expect(find.textContaining('70.00'), findsWidgets);

      // Add user card worth $70
      final userCard = createTestCard(
        id: 'card-mana-drain',
        name: 'Mana Drain',
        currentMarketPrice: 70.0,
        userId: userA.id,
      );
      controller.addSendingCard(userA.id, userCard);
      await tester.pumpAndSettle();

      // Both pods now show $70.00 and trade is marked FAIR
      expect(find.byKey(const Key('trade_sending_card_card-mana-drain')), findsOneWidget);
      expect(find.textContaining('FAIR'), findsWidgets);
    });
  });
}

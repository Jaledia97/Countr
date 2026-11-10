import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/presentation/widgets/embedded_trade_offer_card.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'trade_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final userA = createTestUser(id: 'user-a', username: 'alice', displayName: 'Alice');
  final userB = createTestUser(id: 'user-b', username: 'bob', displayName: 'Bob');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.userProfiles).insert(userA);
    await db.into(db.userProfiles).insert(userB);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildEmbeddedCard(String proposalId, {required String currentUserId}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        inboxDaoProvider.overrideWithValue(db.inboxDao),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: EmbeddedTradeOfferCard(
                proposalId: proposalId,
                currentUserId: currentUserId,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('EmbeddedTradeOfferCard in DM Chat', () {
    testWidgets('Renders status badge, fairness gauge, and action buttons for recipient', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      // Create a fair trade proposal
      final cardA = createTestCard(id: 'card-a', name: 'Force of Will', currentMarketPrice: 50.0);
      final cardB = createTestCard(id: 'card-b', name: 'Mana Drain', currentMarketPrice: 50.0);

      final transferA = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferB = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      final pA = TradeParticipant(user: userA, sendingTotalValue: 50.0, receivingTotalValue: 50.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 50.0, receivingTotalValue: 50.0);
      final fairness = TradeFairnessResult.evaluate([pA, pB]);

      const proposalId = 'prop-fair-1';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA.id]),
              requestedCardIdsJson: jsonEncode([cardB.id]),
              offeredTotalValue: const Value(50.0),
              requestedTotalValue: const Value(50.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferA, transferB])),
              fairnessSummaryJson: Value(fairness.toJsonString()),
            ),
          );

      await tester.pumpWidget(buildEmbeddedCard(proposalId, currentUserId: userB.id));
      await tester.pumpAndSettle();

      // Card container rendered
      expect(find.byKey(const Key('embedded_trade_offer_card_prop-fair-1')), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.textContaining('FAIR'), findsOneWidget);
      expect(find.text('Force of Will'), findsOneWidget);
      expect(find.text('Mana Drain'), findsOneWidget);

      // Recipient (Bob) sees action buttons
      expect(find.byKey(const Key('accept_trade_button')), findsOneWidget);
      expect(find.byKey(const Key('decline_trade_button')), findsOneWidget);
    });

    testWidgets('Tapping Accept on balanced trade opens confirm dialog directly (no large gap dialog)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final cardA = createTestCard(id: 'card-a', name: 'Card A', currentMarketPrice: 40.0);
      final cardB = createTestCard(id: 'card-b', name: 'Card B', currentMarketPrice: 40.0);
      final transferA = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferB = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      final pA = TradeParticipant(user: userA, sendingTotalValue: 40.0, receivingTotalValue: 40.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 40.0, receivingTotalValue: 40.0);
      final fairness = TradeFairnessResult.evaluate([pA, pB]);

      const proposalId = 'prop-fair-2';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA.id]),
              requestedCardIdsJson: jsonEncode([cardB.id]),
              offeredTotalValue: const Value(40.0),
              requestedTotalValue: const Value(40.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferA, transferB])),
              fairnessSummaryJson: Value(fairness.toJsonString()),
            ),
          );

      await tester.pumpWidget(buildEmbeddedCard(proposalId, currentUserId: userB.id));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accept_trade_button')));
      await tester.pumpAndSettle();

      // Safeguard warning dialog should NOT appear
      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);

      // Confirm dialog should appear
      expect(find.text('Confirm Trade'), findsOneWidget);
      expect(find.byKey(const Key('trade_transfer_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('confirm_accept_trade_button')), findsOneWidget);
    });

    testWidgets('Tapping Accept on lopsided trade intercepts with LargeValueDifferenceDialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      // Alice offers $10, asks for $80 (diff $70, 87.5% gap)
      final cardA = createTestCard(id: 'card-a', name: 'Cheap Card', currentMarketPrice: 10.0);
      final cardB = createTestCard(id: 'card-b', name: 'Expensive Card', currentMarketPrice: 80.0);
      final transferA = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferB = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      final pA = TradeParticipant(user: userA, sendingTotalValue: 10.0, receivingTotalValue: 80.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 80.0, receivingTotalValue: 10.0);
      final fairness = TradeFairnessResult.evaluate([pA, pB]);

      const proposalId = 'prop-lopsided-1';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA.id]),
              requestedCardIdsJson: jsonEncode([cardB.id]),
              offeredTotalValue: const Value(10.0),
              requestedTotalValue: const Value(80.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferA, transferB])),
              fairnessSummaryJson: Value(fairness.toJsonString()),
            ),
          );

      await tester.pumpWidget(buildEmbeddedCard(proposalId, currentUserId: userB.id));
      await tester.pumpAndSettle();

      // Tap Accept
      await tester.tap(find.byKey(const Key('accept_trade_button')));
      await tester.pumpAndSettle();

      // Safeguard warning dialog MUST appear
      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.text('Large Value Difference Detected'), findsOneWidget);

      // Review Trade dismisses and does not open confirm dialog
      await tester.tap(find.byKey(const Key('review_trade_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(find.text('Confirm Trade'), findsNothing);
    });

    testWidgets('Tapping Decline updates proposal status to declined', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      const proposalId = 'prop-decline-1';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: '[]',
              requestedCardIdsJson: '[]',
              offeredTotalValue: const Value(20.0),
              requestedTotalValue: const Value(20.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
            ),
          );

      await tester.pumpWidget(buildEmbeddedCard(proposalId, currentUserId: userB.id));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('decline_trade_button')));
      await tester.pumpAndSettle();

      final updated = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(proposalId)))
          .getSingle();
      expect(updated.status, equals('declined'));
    });
  });
}

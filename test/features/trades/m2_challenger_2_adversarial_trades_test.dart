// Copyright (c) 2026 Countr. All rights reserved.
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/daos/inbox_dao.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/feed/presentation/screens/chat_conversation_screen.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/dialogs/large_value_difference_dialog.dart';
import 'package:countr/features/trades/presentation/widgets/embedded_trade_offer_card.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
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

  Widget buildDialogHost({required Future<bool> Function(BuildContext) onTrigger}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('trigger_safeguard_button'),
              onPressed: () => onTrigger(context),
              child: const Text('Trigger Safeguard'),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildEmbeddedCardHost(String proposalId, {required String currentUserId}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        inboxDaoProvider.overrideWithValue(db.inboxDao),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
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

  Widget buildChatConversationHost({
    required String conversationId,
    required String currentUserId,
    required String contactId,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        inboxDaoProvider.overrideWithValue(db.inboxDao),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
      ],
      child: MaterialApp(
        home: ChatConversationScreen(
          conversationId: conversationId,
          contactId: contactId,
        ),
      ),
    );
  }

  // =========================================================================
  // Part 1: LargeValueDifferenceDialog & Mathematical Boundary Conditions
  // =========================================================================
  group('Adversarial 1: LargeValueDifferenceDialog Mathematical Boundary Conditions', () {
    testWidgets('Exact Dollar Threshold: \$9.99 bypasses immediately, \$10.00 triggers safeguard', (tester) async {
      bool? result999;
      // 1. Below threshold: $9.99 gap & 12.0% gap
      await tester.pumpWidget(
        buildDialogHost(
          onTrigger: (ctx) async {
            result999 = await LargeValueDifferenceDialog.checkAndConfirm(
              context: ctx,
              dollarGap: 9.99,
              percentGap: 12.0,
            );
            return result999!;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('trigger_safeguard_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(result999, isTrue);

      // 2. Exactly at threshold: $10.00 gap & 12.0% gap
      bool? result1000;
      await tester.pumpWidget(
        buildDialogHost(
          onTrigger: (ctx) async {
            result1000 = await LargeValueDifferenceDialog.checkAndConfirm(
              context: ctx,
              dollarGap: 10.00,
              percentGap: 12.0,
            );
            return result1000!;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('trigger_safeguard_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.textContaining('\$10.00'), findsOneWidget);
      expect(find.textContaining('12.0%'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byKey(const Key('review_trade_button')));
      await tester.pumpAndSettle();
      expect(result1000, isFalse);
    });

    testWidgets('Exact Percentage Threshold: 14.99% bypasses immediately, 15.00% triggers safeguard', (tester) async {
      bool? result1499;
      // 1. Below percentage threshold: $4.00 gap & 14.99% gap
      await tester.pumpWidget(
        buildDialogHost(
          onTrigger: (ctx) async {
            result1499 = await LargeValueDifferenceDialog.checkAndConfirm(
              context: ctx,
              dollarGap: 4.00,
              percentGap: 14.99,
            );
            return result1499!;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('trigger_safeguard_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(result1499, isTrue);

      // 2. Exactly at percentage threshold: $4.00 gap & 15.00% gap
      bool? result1500;
      await tester.pumpWidget(
        buildDialogHost(
          onTrigger: (ctx) async {
            result1500 = await LargeValueDifferenceDialog.checkAndConfirm(
              context: ctx,
              dollarGap: 4.00,
              percentGap: 15.00,
            );
            return result1500!;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('trigger_safeguard_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.textContaining('15.0%'), findsOneWidget);

      // Proceed anyway
      await tester.tap(find.byKey(const Key('proceed_anyway_button')));
      await tester.pumpAndSettle();
      expect(result1500, isTrue);
    });

    testWidgets('Zero and Empty Trade: \$0.00 gap and 0.0% passes through without modal', (tester) async {
      bool? resultZero;
      await tester.pumpWidget(
        buildDialogHost(
          onTrigger: (ctx) async {
            resultZero = await LargeValueDifferenceDialog.checkAndConfirm(
              context: ctx,
              dollarGap: 0.0,
              percentGap: 0.0,
            );
            return resultZero!;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('trigger_safeguard_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(resultZero, isTrue);
    });

    testWidgets('Extreme Value Gap: \$999,999.00 and 100.0% renders properly without crash', (tester) async {
      bool? resultExtreme;
      await tester.pumpWidget(
        buildDialogHost(
          onTrigger: (ctx) async {
            resultExtreme = await LargeValueDifferenceDialog.checkAndConfirm(
              context: ctx,
              dollarGap: 999999.0,
              percentGap: 100.0,
            );
            return resultExtreme!;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('trigger_safeguard_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.textContaining('\$999999.00 (100.0%)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review_trade_button')));
      await tester.pumpAndSettle();
      expect(resultExtreme, isFalse);
    });

    testWidgets('TradeProposalController.submitProposal respects safeguard intercept and Review Trade aborts', (tester) async {
      final params = TradeProposalParams(currentUser: userA, partnerProfile: userB);
      final controller = TradeProposalController(params);

      // Add lopsided card ($25 vs $0)
      final cardA = createTestCard(id: 'card-a-safeguard', name: 'Lotus Petal', currentMarketPrice: 25.0);
      controller.addSendingCard(userA.id, cardA);

      TradeProposalRecord? submittedRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  key: const Key('submit_proposal_test_btn'),
                  onPressed: () async {
                    submittedRecord = await controller.submitProposal(
                      context: ctx,
                      inboxDao: db.inboxDao,
                      currentUserId: userA.id,
                    );
                  },
                  child: const Text('Submit'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap submit
      await tester.tap(find.byKey(const Key('submit_proposal_test_btn')));
      await tester.pumpAndSettle();

      // Safeguard dialog appears
      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);

      // Tap [Review Trade]
      await tester.tap(find.byKey(const Key('review_trade_button')));
      await tester.pumpAndSettle();

      // Dialog dismissed, submittedRecord is null, nothing inserted into database
      expect(submittedRecord, isNull);
      final count = await (db.select(db.tradeProposals)).get();
      expect(count.isEmpty, isTrue);
      expect(controller.state.isSubmitting, isFalse);

      // Now tap submit again, and choose [Proceed Anyway]
      await tester.tap(find.byKey(const Key('submit_proposal_test_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('proceed_anyway_button')));
      await tester.pumpAndSettle();

      // Proposal is successfully created in SQLite
      expect(submittedRecord, isNotNull);
      expect(submittedRecord!.proposerId, equals(userA.id));
      expect(submittedRecord!.status, equals('pending'));
      final stored = await (db.select(db.tradeProposals)).get();
      expect(stored.length, equals(1));
    });
  });

  // =========================================================================
  // Part 2: EmbeddedTradeOfferCard State Transitions & DM Chat Interactions
  // =========================================================================
  group('Adversarial 2: EmbeddedTradeOfferCard State Transitions & DM Chat Interactions', () {
    testWidgets('Full State Lifecycle: PENDING -> DECLINED transitions status and disables actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final cardA = createTestCard(id: 'card-a-decl', name: 'Sol Ring', currentMarketPrice: 15.0);
      final cardB = createTestCard(id: 'card-b-decl', name: 'Arcane Signet', currentMarketPrice: 15.0);
      final transferA = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferB = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      final pA = TradeParticipant(user: userA, sendingTotalValue: 15.0, receivingTotalValue: 15.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 15.0, receivingTotalValue: 15.0);
      final fairness = TradeFairnessResult.evaluate([pA, pB]);

      const proposalId = 'prop-lifecycle-decl';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA.id]),
              requestedCardIdsJson: jsonEncode([cardB.id]),
              offeredTotalValue: const Value(15.0),
              requestedTotalValue: const Value(15.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferA, transferB])),
              fairnessSummaryJson: Value(fairness.toJsonString()),
            ),
          );

      await tester.pumpWidget(buildEmbeddedCardHost(proposalId, currentUserId: userB.id));
      await tester.pumpAndSettle();

      // Initial state: PENDING
      expect(find.byKey(const Key('embedded_trade_status_prop-lifecycle-decl')), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.byKey(const Key('accept_trade_button')), findsOneWidget);
      expect(find.byKey(const Key('decline_trade_button')), findsOneWidget);

      // Tap Decline
      await tester.tap(find.byKey(const Key('decline_trade_button')));
      await tester.pumpAndSettle();

      // Updated state: DECLINED
      expect(find.text('DECLINED'), findsOneWidget);
      expect(find.byKey(const Key('accept_trade_button')), findsNothing);
      expect(find.byKey(const Key('decline_trade_button')), findsNothing);

      // Verify chat decline message was sent to Alice
      final msgs = await (db.select(db.messages)
            ..where((t) => t.recipientId.equals(userA.id)))
          .get();
      expect(msgs.any((m) => m.messageText.contains('Trade proposal was declined')), isTrue);
    });

    testWidgets('Proposer View Isolation: Alice (proposer) sees card but NEVER action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      const proposalId = 'prop-proposer-isolation';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: '[]',
              requestedCardIdsJson: '[]',
              offeredTotalValue: const Value(30.0),
              requestedTotalValue: const Value(30.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
            ),
          );

      // Render as userA (Alice - the proposer)
      await tester.pumpWidget(buildEmbeddedCardHost(proposalId, currentUserId: userA.id));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('embedded_trade_offer_card_prop-proposer-isolation')), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);

      // Proposer must NEVER see Accept or Decline buttons
      expect(find.byKey(const Key('accept_trade_button')), findsNothing);
      expect(find.byKey(const Key('decline_trade_button')), findsNothing);
    });

    testWidgets('Accept Trade on Lopsided Proposal: Full flow through safeguard and confirm modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final cardA = createTestCard(id: 'card-a-lop', name: 'Expensive Card', currentMarketPrice: 100.0);
      final cardB = createTestCard(id: 'card-b-lop', name: 'Cheap Card', currentMarketPrice: 10.0);
      final transferA = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferB = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      final pA = TradeParticipant(user: userA, sendingTotalValue: 100.0, receivingTotalValue: 10.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 10.0, receivingTotalValue: 100.0);
      final fairness = TradeFairnessResult.evaluate([pA, pB]);

      const proposalId = 'prop-lopsided-accept';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA.id]),
              requestedCardIdsJson: jsonEncode([cardB.id]),
              offeredTotalValue: const Value(100.0),
              requestedTotalValue: const Value(10.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferA, transferB])),
              fairnessSummaryJson: Value(fairness.toJsonString()),
            ),
          );

      await tester.pumpWidget(buildEmbeddedCardHost(proposalId, currentUserId: userB.id));
      await tester.pumpAndSettle();

      // 1. Tap Accept Trade
      await tester.tap(find.byKey(const Key('accept_trade_button')));
      await tester.pumpAndSettle();

      // Safeguard modal appears
      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);

      // Tap Proceed Anyway
      await tester.tap(find.byKey(const Key('proceed_anyway_button')));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Confirm Trade'), findsOneWidget);
      expect(find.byKey(const Key('trade_transfer_checkbox')), findsOneWidget);

      // Tap Confirm & Accept
      await tester.tap(find.byKey(const Key('confirm_accept_trade_button')));
      await tester.pumpAndSettle();

      // Verify proposal is accepted
      final updated = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(updated.status, equals('accepted'));
      expect(updated.isTransferred, isTrue);

      // Verify UI switches to ACCEPTED state and buttons disappear
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(find.byKey(const Key('accept_trade_button')), findsNothing);
      expect(find.byKey(const Key('decline_trade_button')), findsNothing);
    });

    testWidgets('Live Chat Integration: ChatConversationScreen renders embedded card and accepts inline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final conversationId = InboxDao.getConversationId(userA.id, userB.id);

      // 1. Insert ordinary chat message
      await db.inboxDao.sendMessage(
        senderId: userA.id,
        recipientId: userB.id,
        messageText: 'Hey Bob, check out this trade proposal!',
      );

      // 2. Insert trade proposal with attachment
      final cardA = createTestCard(id: 'card-chat-a', name: 'Snapcaster Mage', currentMarketPrice: 20.0);
      final cardB = createTestCard(id: 'card-chat-b', name: 'Lightning Bolt', currentMarketPrice: 20.0);
      final transferA = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferB = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      final pA = TradeParticipant(user: userA, sendingTotalValue: 20.0, receivingTotalValue: 20.0);
      final pB = TradeParticipant(user: userB, sendingTotalValue: 20.0, receivingTotalValue: 20.0);
      final fairness = TradeFairnessResult.evaluate([pA, pB]);

      const proposalId = 'prop-chat-inline-1';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA.id]),
              requestedCardIdsJson: jsonEncode([cardB.id]),
              offeredTotalValue: const Value(20.0),
              requestedTotalValue: const Value(20.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferA, transferB])),
              fairnessSummaryJson: Value(fairness.toJsonString()),
            ),
          );

      await db.inboxDao.sendMessage(
        senderId: userA.id,
        recipientId: userB.id,
        messageText: 'Proposed a trade with you!',
        attachmentType: 'trade_proposal',
        attachmentTradeProposalId: proposalId,
      );

      // 3. Render ChatConversationScreen as Bob
      await tester.pumpWidget(
        buildChatConversationHost(
          conversationId: conversationId,
          currentUserId: userB.id,
          contactId: userA.id,
        ),
      );
      await tester.pumpAndSettle();

      // Remediation M6 It2: _ActiveTradeProposalBanner renders with zero RenderFlex overflows
      final dynamic layoutError = tester.takeException();
      expect(layoutError, isNull, reason: 'Must not overflow on standard mobile viewports');

      // Both messages exist
      expect(find.text('Hey Bob, check out this trade proposal!'), findsOneWidget);
      expect(find.text('Proposed a trade with you!'), findsOneWidget);

      // Embedded trade offer card is rendered inside the chat bubble
      expect(find.byKey(const Key('embedded_trade_offer_card_prop-chat-inline-1')), findsOneWidget);
      expect(find.text('Snapcaster Mage'), findsOneWidget);
      expect(find.text('Lightning Bolt'), findsOneWidget);

      // Bob accepts trade directly within chat
      expect(find.byKey(const Key('accept_trade_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('accept_trade_button')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Trade'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_accept_trade_button')));
      await tester.pumpAndSettle();

      // Status inside the embedded trade offer card updates reactively to ACCEPTED
      expect(
        find.descendant(
          of: find.byKey(const Key('embedded_trade_offer_card_prop-chat-inline-1')),
          matching: find.text('ACCEPTED'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accept_trade_button')), findsNothing);

      // Chat receives the system confirmation message
      expect(find.textContaining('Trade accepted!'), findsWidgets);
    });
  });

  // =========================================================================
  // Part 3: Atomic SQLite Card Transfer Rollback & Isolation in 3-Way Trades
  // =========================================================================
  group('Adversarial 3: Atomic 3-Way SQLite Card Transfer Rollback & Isolation', () {
    test('Multi-Card 3-Way Pod Transfer: All cards routed cleanly with system trade block provisioning', () async {
      // Alice sends Card A1 to Bob, Card A2 to Charlie
      // Bob sends Card B1 to Charlie
      // Charlie sends Card C1 to Alice
      final cardA1 = createTestCard(id: 'c-a1', name: 'Card A1', currentMarketPrice: 40.0, userId: userA.id);
      final cardA2 = createTestCard(id: 'c-a2', name: 'Card A2', currentMarketPrice: 60.0, userId: userA.id);
      final cardB1 = createTestCard(id: 'c-b1', name: 'Card B1', currentMarketPrice: 50.0, userId: userB.id);
      final cardC1 = createTestCard(id: 'c-c1', name: 'Card C1', currentMarketPrice: 100.0, userId: userC.id);

      await db.into(db.vaultItems).insert(cardA1);
      await db.into(db.vaultItems).insert(cardA2);
      await db.into(db.vaultItems).insert(cardB1);
      await db.into(db.vaultItems).insert(cardC1);

      final transferA1toB = createTestTransfer(card: cardA1, senderId: userA.id, recipientId: userB.id);
      final transferA2toC = createTestTransfer(card: cardA2, senderId: userA.id, recipientId: userC.id);
      final transferB1toC = createTestTransfer(card: cardB1, senderId: userB.id, recipientId: userC.id);
      final transferC1toA = createTestTransfer(card: cardC1, senderId: userC.id, recipientId: userA.id);

      final transfers = [transferA1toB, transferA2toC, transferB1toC, transferC1toA];

      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: userA.id,
        receiverId: userB.id,
        thirdParticipantId: userC.id,
        isThreeWay: true,
        cardTransfersJson: TradeCardTransfer.listToJson(transfers),
        offeredCardIds: [cardA1.id, cardA2.id],
        requestedCardIds: [cardB1.id, cardC1.id],
        offeredTotalValue: 100.0,
        requestedTotalValue: 150.0,
        note: '3-way pod trade',
      );

      // Execute transfer
      await db.inboxDao.respondToTradeProposal(
        proposal.id,
        accept: true,
        transferCards: true,
        currentUserId: userB.id,
      );

      // Verify each card's ownership and binder in SQLite:
      final a1After = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA1.id))).getSingle();
      expect(a1After.userId, equals(userB.id));
      expect(a1After.primaryBinderId, equals('system_trade_block_${userB.id}'));
      expect(a1After.isTraded, isTrue);

      final a2After = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA2.id))).getSingle();
      expect(a2After.userId, equals(userC.id));
      expect(a2After.primaryBinderId, equals('system_trade_block_${userC.id}'));
      expect(a2After.isTraded, isTrue);

      final b1After = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardB1.id))).getSingle();
      expect(b1After.userId, equals(userC.id));
      expect(b1After.primaryBinderId, equals('system_trade_block_${userC.id}'));
      expect(b1After.isTraded, isTrue);

      final c1After = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardC1.id))).getSingle();
      expect(c1After.userId, equals(userA.id));
      expect(c1After.primaryBinderId, equals('system_trade_block_${userA.id}'));
      expect(c1After.isTraded, isTrue);

      // Verify system trade block binders were provisioned for all 3 participants
      final binderA = await (db.select(db.vaultBinders)..where((b) => b.id.equals('system_trade_block_${userA.id}'))).getSingle();
      expect(binderA.isSystemBinder, isTrue);
      expect(binderA.systemBinderType, equals('trade_block'));

      final binderB = await (db.select(db.vaultBinders)..where((b) => b.id.equals('system_trade_block_${userB.id}'))).getSingle();
      expect(binderB.isSystemBinder, isTrue);
      expect(binderB.systemBinderType, equals('trade_block'));

      final binderC = await (db.select(db.vaultBinders)..where((b) => b.id.equals('system_trade_block_${userC.id}'))).getSingle();
      expect(binderC.isSystemBinder, isTrue);
      expect(binderC.systemBinderType, equals('trade_block'));
    });

    test('Atomic Rollback on Corrupted JSON: malformed cardTransfersJson throws and rolls back SQLite cleanly', () async {
      final cardA = createTestCard(id: 'c-fail-a', name: 'Card Fail A', userId: userA.id);
      final cardB = createTestCard(id: 'c-fail-b', name: 'Card Fail B', userId: userB.id);
      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      const proposalId = 'prop-corrupt-json';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: '[]',
              requestedCardIdsJson: '[]',
              offeredTotalValue: const Value(50.0),
              requestedTotalValue: const Value(50.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              // Malformed JSON that triggers FormatException inside transaction
              cardTransfersJson: const Value('{THIS_IS_CORRUPT_JSON: true,'),
            ),
          );

      // Attempting to respond should rethrow FormatException from jsonDecode
      expect(
        () => db.inboxDao.respondToTradeProposal(
          proposalId,
          accept: true,
          transferCards: true,
          currentUserId: userB.id,
        ),
        throwsA(isA<FormatException>()),
      );

      // TRANSACTION MUST BE COMPLETELY ROLLED BACK:
      // 1. Proposal status must remain 'pending'
      final proposalAfter = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(proposalAfter.status, equals('pending'));
      expect(proposalAfter.isTransferred, isFalse);

      // 2. Card ownership must remain unchanged
      final cardAAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA.id))).getSingle();
      expect(cardAAfter.userId, equals(userA.id));
      expect(cardAAfter.isTraded, isFalse);

      final cardBAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardB.id))).getSingle();
      expect(cardBAfter.userId, equals(userB.id));
      expect(cardBAfter.isTraded, isFalse);
    });

    test('Double-Acceptance Idempotency Guard: second respond call is ignored without error or duplicate transfer', () async {
      final cardA = createTestCard(id: 'c-double-a', name: 'Double A', userId: userA.id);
      final cardB = createTestCard(id: 'c-double-b', name: 'Double B', userId: userB.id);
      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      final transferAtoB = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferBtoA = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      const proposalId = 'prop-double-accept';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA.id]),
              requestedCardIdsJson: jsonEncode([cardB.id]),
              offeredTotalValue: const Value(25.0),
              requestedTotalValue: const Value(25.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferAtoB, transferBtoA])),
            ),
          );

      // First accept call
      await db.inboxDao.respondToTradeProposal(
        proposalId,
        accept: true,
        transferCards: true,
        currentUserId: userB.id,
      );

      final proposalFirst = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(proposalFirst.status, equals('accepted'));

      // Count messages
      final msgsAfterFirst = await (db.select(db.messages)).get();
      final msgCountFirst = msgsAfterFirst.length;

      // Second accept call (simulating rapid double-tap or concurrent request)
      await db.inboxDao.respondToTradeProposal(
        proposalId,
        accept: true,
        transferCards: true,
        currentUserId: userB.id,
      );

      // Proposal status is still accepted
      final proposalSecond = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(proposalSecond.status, equals('accepted'));

      // No duplicate messages were emitted
      final msgsAfterSecond = await (db.select(db.messages)).get();
      expect(msgsAfterSecond.length, equals(msgCountFirst));
    });

    test('Deleted Card Graceful Handling: trade accepts cleanly even if a card was removed prior to acceptance', () async {
      // Alice offers cardA1, Bob offers cardB1
      final cardA1 = createTestCard(id: 'c-del-a1', name: 'Card A1', userId: userA.id);
      await db.into(db.vaultItems).insert(cardA1);
      // cardB1 is deliberately NOT inserted into vaultItems (represents deleted/missing card)

      final fakeCardB = createTestCard(id: 'c-del-b-missing', name: 'Deleted Card', userId: userB.id);
      final transferAtoB = createTestTransfer(card: cardA1, senderId: userA.id, recipientId: userB.id);
      final transferBtoA = createTestTransfer(card: fakeCardB, senderId: userB.id, recipientId: userA.id);

      const proposalId = 'prop-missing-card';
      await db.into(db.tradeProposals).insert(
            TradeProposalsCompanion.insert(
              id: proposalId,
              proposerId: userA.id,
              receiverId: userB.id,
              offeredCardIdsJson: jsonEncode([cardA1.id]),
              requestedCardIdsJson: jsonEncode([fakeCardB.id]),
              offeredTotalValue: const Value(10.0),
              requestedTotalValue: const Value(10.0),
              status: const Value('pending'),
              createdAt: Value(DateTime.now()),
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferAtoB, transferBtoA])),
            ),
          );

      // Execute transfer - should not crash
      await db.inboxDao.respondToTradeProposal(
        proposalId,
        accept: true,
        transferCards: true,
        currentUserId: userB.id,
      );

      // Status accepted
      final updated = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(updated.status, equals('accepted'));

      // Valid cardA1 transferred successfully to Bob
      final cardAAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA1.id))).getSingle();
      expect(cardAAfter.userId, equals(userB.id));
      expect(cardAAfter.isTraded, isTrue);
    });

    test('Manual Transfer Flag: accept: true with transferCards: false marks accepted without modifying vault items', () async {
      final cardA = createTestCard(id: 'c-manual-a', name: 'Manual A', userId: userA.id);
      final cardB = createTestCard(id: 'c-manual-b', name: 'Manual B', userId: userB.id);
      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      final transferAtoB = createTestTransfer(card: cardA, senderId: userA.id, recipientId: userB.id);
      final transferBtoA = createTestTransfer(card: cardB, senderId: userB.id, recipientId: userA.id);

      const proposalId = 'prop-manual-transfer';
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
              cardTransfersJson: Value(TradeCardTransfer.listToJson([transferAtoB, transferBtoA])),
            ),
          );

      // Accept with transferCards = false
      await db.inboxDao.respondToTradeProposal(
        proposalId,
        accept: true,
        transferCards: false,
        currentUserId: userB.id,
      );

      final proposalAfter = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(proposalAfter.status, equals('accepted'));
      expect(proposalAfter.isTransferred, isFalse);

      // Card ownership in vaultItems is UNTOUCHED
      final cardAAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardA.id))).getSingle();
      expect(cardAAfter.userId, equals(userA.id));
      expect(cardAAfter.isTraded, isFalse);

      final cardBAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardB.id))).getSingle();
      expect(cardBAfter.userId, equals(userB.id));
      expect(cardBAfter.isTraded, isFalse);

      // Confirmation message mentions manual inventory transfer
      final msgs = await (db.select(db.messages)
            ..where((t) => t.recipientId.equals(userA.id)))
          .get();
      expect(msgs.any((m) => m.messageText.contains('Manual inventory transfer chosen')), isTrue);
    });
  });
}

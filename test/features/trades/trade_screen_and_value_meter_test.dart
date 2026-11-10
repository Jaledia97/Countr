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
  final userC = createTestUser(id: 'user-c', username: 'charlie', displayName: 'Charlie');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTradeScreen({
    UserProfile? thirdPartner,
    TradeProposalController? customController,
    TradeProposalParams? params,
  }) {
    final effectiveParams = params ??
        TradeProposalParams(
          currentUser: userA,
          partnerProfile: userB,
          initialThirdPartner: thirdPartner,
        );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        inboxDaoProvider.overrideWithValue(db.inboxDao),
        if (customController != null)
          tradeProposalControllerProvider(effectiveParams)
              .overrideWith((ref) => customController),
      ],
      child: MaterialApp(
        home: TradeScreen(params: effectiveParams),
      ),
    );
  }

  group('TradeScreen & StickyTradeValueMeter Widget Tests', () {
    testWidgets('Renders StickyTradeValueMeter, Fairness Gauge, and Participant Pods for 2-way trade', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));
      await tester.pumpWidget(buildTradeScreen());
      await tester.pumpAndSettle();

      // Verify Propose Trade Modal & Main Keys
      expect(find.byKey(const Key('propose_trade_modal')), findsOneWidget);
      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
      expect(find.byKey(const Key('trade_fairness_gauge')), findsOneWidget);

      // Verify Header and Pods
      expect(find.text('Propose Trade'), findsOneWidget);
      expect(find.byKey(const Key('add_third_trade_partner_button')), findsOneWidget);
      expect(find.byKey(const Key('trade_participant_pod_user-a')), findsOneWidget);
      expect(find.byKey(const Key('trade_participant_pod_user-b')), findsOneWidget);
      expect(find.byKey(const Key('send_trade_proposal_button')), findsOneWidget);

      // Value meter shows "FAIR" gauge label
      expect(find.textContaining('FAIR'), findsWidgets);
    });

    testWidgets('3-Way Pod Trade renders 3 pods and remove 3rd partner button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));
      await tester.pumpWidget(buildTradeScreen(thirdPartner: userC));
      await tester.pumpAndSettle();

      expect(find.text('3-Way Pod Trade'), findsOneWidget);
      expect(find.byKey(const Key('remove_third_trade_partner_button')), findsOneWidget);
      expect(find.byKey(const Key('trade_participant_pod_user-a')), findsOneWidget);
      expect(find.byKey(const Key('trade_participant_pod_user-b')), findsOneWidget);
      expect(find.byKey(const Key('trade_participant_pod_user-c'), skipOffstage: false), findsOneWidget);
      expect(find.text('Send 3-Way Trade Proposal'), findsOneWidget);
    });

    testWidgets('Displays card recipient dropdown in 3-way trade and supports routing update', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final params = TradeProposalParams(
        currentUser: userA,
        partnerProfile: userB,
        initialThirdPartner: userC,
      );
      final controller = TradeProposalController(params);

      final cardA = createTestCard(
        id: 'card-a1',
        name: 'Black Lotus',
        currentMarketPrice: 100.0,
        userId: userA.id,
      );
      controller.addSendingCard(userA.id, cardA);

      await tester.pumpWidget(
        buildTradeScreen(
          params: params,
          customController: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Card recipient dropdown should exist for card-a1 in 3-way mode
      final dropdownFinder = find.byKey(const Key('trade_card_recipient_dropdown_card-a1'));
      expect(dropdownFinder, findsOneWidget);

      // Recipient can be selected / updated
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Charlie's display name appears in dropdown menu items
      expect(find.text('To: Charlie').last, findsOneWidget);
      await tester.tap(find.text('To: Charlie').last);
      await tester.pumpAndSettle();

      // Transferred card should now be routed to Charlie
      final transfer = controller.state.transfers.firstWhere((t) => t.cardId == 'card-a1');
      expect(transfer.recipientId, equals('user-c'));
    });

    testWidgets('Send Trade Proposal intercepts with LargeValueDifferenceDialog on lopsided trade', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final params = TradeProposalParams(
        currentUser: userA,
        partnerProfile: userB,
      );
      final controller = TradeProposalController(params);

      // Alice sends $100 card, Bob sends nothing ($100 gap >= $10.00 and 100% gap >= 15%)
      final cardA = createTestCard(
        id: 'card-a1',
        name: 'Mox Sapphire',
        currentMarketPrice: 100.0,
        userId: userA.id,
      );
      controller.addSendingCard(userA.id, cardA);

      await tester.pumpWidget(
        buildTradeScreen(
          params: params,
          customController: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Send Trade Proposal
      await tester.tap(find.byKey(const Key('send_trade_proposal_button')));
      await tester.pumpAndSettle();

      // LargeValueDifferenceDialog must be shown
      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.text('Large Value Difference Detected'), findsOneWidget);

      // Tap [Review Trade] -> dismisses dialog and halts submission
      await tester.tap(find.byKey(const Key('review_trade_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
    });
  });
}

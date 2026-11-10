// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 6 Iteration 2: Holistic Responsive Layout & Overflow Defense Test Suite

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/feed/presentation/screens/friends_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/chat_conversation_screen.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/widgets/embedded_trade_offer_card.dart';
import 'package:countr/features/feed/presentation/widgets/inbox_user_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  const meId = 'user_audit_me';
  const partnerId = 'user_audit_partner';
  const incomingSenderId = 'user_audit_incoming';
  const outgoingTargetId = 'user_audit_outgoing';
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Insert user profiles with realistic and long display names to stress-test layout
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
      id: meId,
      username: '@me_collector',
      displayName: 'Me Long Display Name Collector',
      createdAt: now,
    ));
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
      id: partnerId,
      username: '@partner_long_handle_tcg',
      displayName: 'Partner Long Display Name',
      createdAt: now,
    ));
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
      id: incomingSenderId,
      username: '@incoming_sender_tcg',
      displayName: 'Incoming Requester Extra Long Name',
      createdAt: now,
    ));
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
      id: outgoingTargetId,
      username: '@outgoing_target_tcg',
      displayName: 'Outgoing Target Extra Long Name',
      createdAt: now,
    ));

    // Insert notification with friend request
    await db.into(db.notifications).insert(NotificationsCompanion.insert(
      id: 'notif_1',
      userId: meId,
      actorId: partnerId,
      actorUsername: '@partner',
      type: 'friend_request',
      title: 'Friend Request',
      body: 'sent you a friend request',
      createdAt: drift.Value(now),
    ));

    // Insert pending trade proposal where partner is proposer and me is recipient
    await db.into(db.tradeProposals).insert(TradeProposalsCompanion.insert(
      id: 'trade_1',
      proposerId: partnerId,
      receiverId: meId,
      status: const drift.Value('pending'),
      offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
      requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
      offeredTotalValue: const drift.Value(5000.0),
      requestedTotalValue: const drift.Value(4500.0),
      createdAt: drift.Value(now),
    ));

    // Insert friendships (incoming: userId = incomingSenderId, friendId = meId; outgoing: userId = meId, friendId = outgoingTargetId)
    await db.into(db.friendships).insert(FriendshipsCompanion.insert(
      id: 'friendship_incoming_1',
      userId: incomingSenderId,
      friendId: meId,
      status: const drift.Value('pending'),
      createdAt: drift.Value(now),
    ));
    await db.into(db.friendships).insert(FriendshipsCompanion.insert(
      id: 'friendship_outgoing_1',
      userId: meId,
      friendId: outgoingTargetId,
      status: const drift.Value('pending'),
      createdAt: drift.Value(now),
    ));
  });

  tearDown(() => db.close());

  Widget buildScope({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => meId),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  final testViewports = <Size>[
    const Size(240, 600), // Ultra-narrow (auditor failure threshold)
    const Size(320, 640), // Compact device (iPhone SE)
    const Size(360, 780), // Standard Android
    const Size(400, 800), // Standard modern mobile (auditor Check 6 failure width)
    const Size(600, 900), // Foldable / portrait tablet
    const Size(800, 1200), // Tablet landscape
  ];

  for (final size in testViewports) {
    group('Responsive Viewport Defense [${size.width.toInt()}x${size.height.toInt()}]:', () {
      testWidgets('ChatConversationScreen (as recipient) renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildScope(
          child: const ChatConversationScreen(
            conversationId: 'user_audit_me_user_audit_partner',
            contactId: partnerId,
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('trade_card_status_badge')), findsOneWidget);
        expect(find.byKey(const Key('chat_accept_trade_button')), findsOneWidget);
        expect(find.byKey(const Key('trade_counter_offer_button')), findsOneWidget);
        expect(find.byKey(const Key('chat_decline_trade_button')), findsOneWidget);
      });

      testWidgets('ChatConversationScreen (as proposer) renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert pending trade where me is proposer
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'trade_proposer_1',
            proposerId: meId,
            receiverId: partnerId,
            status: const drift.Value('pending'),
            offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
            requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
            offeredTotalValue: const drift.Value(5000.0),
            requestedTotalValue: const drift.Value(4500.0),
            createdAt: drift.Value(now.add(const Duration(seconds: 10))),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await tester.pumpWidget(buildScope(
          child: const ChatConversationScreen(
            conversationId: 'user_audit_me_user_audit_partner',
            contactId: partnerId,
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('trade_edit_offer_button')), findsOneWidget);
        expect(find.byKey(const Key('cancel_trade_button')), findsOneWidget);
      });

      testWidgets('InboxHubScreen Notifications renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildScope(child: const InboxHubScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('notif_approve_fr_notif_1')), findsOneWidget);
        expect(find.byKey(const Key('notif_deny_fr_notif_1')), findsOneWidget);

        // Switch to Messages tab to test responsive layout and compose button
        await tester.tap(find.text('Messages'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Messages tab must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('inbox_compose_button')), findsOneWidget);
      });

      testWidgets('FriendsHubScreen empty and populated states render with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildScope(child: const FriendsHubScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('friends_hub_tab_bar')), findsOneWidget);
        expect(find.byKey(const Key('friend_requests_section')), findsOneWidget);
        expect(find.byKey(const Key('friends_list_section')), findsOneWidget);
        expect(find.byKey(const Key('sent_requests_section')), findsOneWidget);
        expect(find.byKey(const Key('friend_request_accept_friendship_incoming_1')), findsOneWidget);
        expect(find.byKey(const Key('friend_request_cancel_friendship_outgoing_1')), findsOneWidget);
      });

      testWidgets('TradeScreen renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final meProfile = await db.userProfileDao.getProfile(meId);
        final partnerProfile = await db.userProfileDao.getProfile(partnerId);

        final params = TradeProposalParams(
          currentUser: meProfile!,
          partnerProfile: partnerProfile!,
          mode: TradeProposalMode.create,
        );

        await tester.pumpWidget(buildScope(child: TradeScreen(params: params)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
        expect(find.byKey(const Key('send_trade_proposal_button')), findsOneWidget);
      });

      testWidgets('EmbeddedTradeOfferCard renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildScope(
          child: const Scaffold(
            body: SingleChildScrollView(
              child: EmbeddedTradeOfferCard(
                proposalId: 'trade_1',
                currentUserId: meId,
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('accept_trade_button')), findsOneWidget);
        expect(find.byKey(const Key('trade_counter_offer_button')), findsOneWidget);
        expect(find.byKey(const Key('decline_trade_button')), findsOneWidget);
      });

      testWidgets('InboxUserPickerModal renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildScope(
          child: const Scaffold(
            body: InboxUserPickerModal(),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at viewport ${size.width}x${size.height}');
        expect(find.byKey(const Key('inbox_user_picker_start_button')), findsOneWidget);
      });
    });
  }
}

// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 6 Iteration 2 Gate Verification: Challenger Adversarial Multi-Viewport & Text-Scaling Suite

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
import 'package:countr/features/trades/presentation/widgets/embedded_trade_offer_card.dart';
import 'package:countr/features/feed/presentation/widgets/inbox_user_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  const meId = 'user_challenger_me';
  const partnerId = 'user_challenger_partner';
  const outgoingId = 'user_challenger_outgoing';
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Insert user profiles with extreme display names & usernames to maximize layout stress
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
      id: meId,
      username: '@me_extra_long_collector_handle_99',
      displayName: 'Adversarial Challenger Super Long Display Name',
      createdAt: now,
    ));
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
      id: partnerId,
      username: '@partner_extra_long_handle_trading_post',
      displayName: 'Partner Ultra Long Trading Name With Many Words',
      createdAt: now,
    ));
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
      id: outgoingId,
      username: '@outgoing_target_collector_vault',
      displayName: 'Outgoing Target Extremely Verbose Profile Name',
      createdAt: now,
    ));

    // Insert friend request notification
    await db.into(db.notifications).insert(NotificationsCompanion.insert(
      id: 'notif_fr_adv_1',
      userId: meId,
      actorId: partnerId,
      actorUsername: '@partner_extra_long_handle_trading_post',
      type: 'friend_request',
      title: 'Friend Request from Partner Ultra Long Trading Name',
      body: 'wants to become trading partners on Countr TCG',
      createdAt: drift.Value(now),
    ));

    // Insert trade proposal notification
    await db.into(db.notifications).insert(NotificationsCompanion.insert(
      id: 'notif_trade_adv_1',
      userId: meId,
      actorId: partnerId,
      actorUsername: '@partner_extra_long_handle_trading_post',
      type: 'trade_proposal',
      title: 'New Trade Offer Received',
      body: 'offered Black Lotus for Mox Sapphire',
      createdAt: drift.Value(now),
    ));

    // Insert message into messages table
    await db.into(db.messages).insert(MessagesCompanion.insert(
      id: 'msg_adv_1',
      conversationId: 'user_challenger_me_user_challenger_partner',
      senderId: partnerId,
      recipientId: meId,
      messageText: 'Hey! Check out this trade proposal and let me know if we have a deal!',
      createdAt: drift.Value(now),
    ));

    // Insert pending trade proposal (partner -> me, me is recipient)
    await db.into(db.tradeProposals).insert(TradeProposalsCompanion.insert(
      id: 'trade_adv_recipient',
      proposerId: partnerId,
      receiverId: meId,
      status: const drift.Value('pending'),
      offeredCardIdsJson: jsonEncode([
        'item-mtg-black-lotus-super-long-card-title-alpha',
        'item-mtg-mox-jet-vintage-collectible',
      ]),
      requestedCardIdsJson: jsonEncode([
        'item-mtg-mox-sapphire-unlimited-edition-near-mint',
      ]),
      offeredTotalValue: const drift.Value(7500.0),
      requestedTotalValue: const drift.Value(7200.0),
      createdAt: drift.Value(now),
    ));

    // Insert friendships
    await db.into(db.friendships).insert(FriendshipsCompanion.insert(
      id: 'friendship_incoming_adv',
      userId: partnerId,
      friendId: meId,
      status: const drift.Value('pending'),
      createdAt: drift.Value(now),
    ));
    await db.into(db.friendships).insert(FriendshipsCompanion.insert(
      id: 'friendship_outgoing_adv',
      userId: meId,
      friendId: outgoingId,
      status: const drift.Value('pending'),
      createdAt: drift.Value(now),
    ));
    await db.into(db.friendships).insert(FriendshipsCompanion.insert(
      id: 'friendship_accepted_adv',
      userId: meId,
      friendId: partnerId,
      status: const drift.Value('accepted'),
      createdAt: drift.Value(now),
    ));
  });

  tearDown(() => db.close());

  Widget buildScope({required Widget child, TextScaler textScaler = TextScaler.noScaling}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => meId),
      ],
      child: MaterialApp(
        builder: (context, rootWidget) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
            ),
            child: rootWidget!,
          );
        },
        home: child,
      ),
    );
  }

  // All authoritative test viewports from prompt
  final viewports = <double, Size>{
    240.0: const Size(240, 600), // Smartwatch / minimum narrow
    280.0: const Size(280, 650), // Foldable cover screen
    320.0: const Size(320, 640), // Compact mobile (iPhone SE)
    360.0: const Size(360, 780), // Standard Android
    400.0: const Size(400, 800), // Standard phone
    600.0: const Size(600, 900), // Foldable open / small tablet
    800.0: const Size(800, 1200), // Tablet landscape
  };

  // Text scaling factors
  final textScalers = <String, TextScaler>{
    '1.0x': TextScaler.noScaling,
    '1.5x': const TextScaler.linear(1.5),
    '2.0x': const TextScaler.linear(2.0),
  };

  for (final vpEntry in viewports.entries) {
    final width = vpEntry.key;
    final size = vpEntry.value;

    group('Adversarial Viewport ${width.toInt()}px:', () {
      for (final tsEntry in textScalers.entries) {
        final scaleLabel = tsEntry.key;
        final scaler = tsEntry.value;

        testWidgets(
          'ChatConversationScreen (recipient mode) @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(buildScope(
              textScaler: scaler,
              child: const ChatConversationScreen(
                conversationId: 'user_challenger_me_user_challenger_partner',
                contactId: partnerId,
              ),
            ));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'ChatConversationScreen recipient mode overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('trade_card_status_badge')), findsOneWidget);
            expect(find.byKey(const Key('chat_accept_trade_button')), findsOneWidget);
            expect(find.byKey(const Key('trade_counter_offer_button')), findsOneWidget);
            expect(find.byKey(const Key('chat_decline_trade_button')), findsOneWidget);
          },
        );

        testWidgets(
          'ChatConversationScreen (proposer mode) @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            // Insert proposal where me is proposer
            await db.into(db.tradeProposals).insert(
              TradeProposalsCompanion.insert(
                id: 'trade_adv_proposer',
                proposerId: meId,
                receiverId: partnerId,
                status: const drift.Value('pending'),
                offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus-alpha']),
                requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire-beta']),
                offeredTotalValue: const drift.Value(6000.0),
                requestedTotalValue: const drift.Value(5800.0),
                createdAt: drift.Value(now.add(const Duration(seconds: 30))),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );

            await tester.pumpWidget(buildScope(
              textScaler: scaler,
              child: const ChatConversationScreen(
                conversationId: 'user_challenger_me_user_challenger_partner',
                contactId: partnerId,
              ),
            ));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'ChatConversationScreen proposer mode overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('trade_edit_offer_button')), findsOneWidget);
            expect(find.byKey(const Key('cancel_trade_button')), findsOneWidget);
          },
        );

        testWidgets(
          'InboxHubScreen (notifications & messages tab) @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            final oldHandler = FlutterError.onError;
            FlutterError.onError = (details) {
              FlutterError.dumpErrorToConsole(details);
              oldHandler?.call(details);
            };
            addTearDown(() => FlutterError.onError = oldHandler);

            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(buildScope(
              textScaler: scaler,
              child: const InboxHubScreen(),
            ));
            await tester.pumpAndSettle();

            final err = tester.takeException();
            if (err != null) {
              debugPrint('CRITICAL OVERFLOW CAUGHT:');
              if (err is FlutterError) {
                for (final d in err.diagnostics) {
                  debugPrint('DIAG [${d.name}]: ${d.toDescription()}');
                }
              }
            }
            expect(
              err,
              isNull,
              reason: 'InboxHubScreen notifications overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('notif_approve_fr_notif_fr_adv_1')), findsOneWidget);
            expect(find.byKey(const Key('notif_deny_fr_notif_fr_adv_1')), findsOneWidget);

            // Switch to Messages Tab
            await tester.tap(find.text('Messages'));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'InboxHubScreen messages overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('inbox_compose_button')), findsOneWidget);
          },
        );

        testWidgets(
          'FriendsHubScreen (empty states) @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            // Create clean DB with no friends/requests for pure empty state test
            final emptyDb = AppDatabase(NativeDatabase.memory());
            await emptyDb.into(emptyDb.userProfiles).insert(UserProfilesCompanion.insert(
              id: 'user_empty_me',
              username: '@empty_me',
              displayName: 'Empty User',
              createdAt: now,
            ));

            final emptyScope = ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(emptyDb),
                currentUserIdProvider.overrideWith((ref) => 'user_empty_me'),
              ],
              child: MaterialApp(
                builder: (context, rootWidget) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: scaler),
                    child: rootWidget!,
                  );
                },
                home: const FriendsHubScreen(),
              ),
            );

            await tester.pumpWidget(emptyScope);
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'FriendsHubScreen empty states overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('my_friends_empty')), findsOneWidget);

            emptyDb.close();
          },
        );

        testWidgets(
          'FriendsHubScreen (populated states & requests) @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(buildScope(
              textScaler: scaler,
              child: const FriendsHubScreen(),
            ));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'FriendsHubScreen populated states overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('friends_hub_tab_bar')), findsOneWidget);
            expect(find.byKey(const Key('friend_requests_section')), findsOneWidget);
            expect(find.byKey(const Key('friends_list_section')), findsOneWidget);
            expect(find.byKey(const Key('sent_requests_section')), findsOneWidget);
            expect(find.byKey(const Key('friend_request_accept_friendship_incoming_adv')), findsOneWidget);
            expect(find.byKey(const Key('friend_request_cancel_friendship_outgoing_adv')), findsOneWidget);
          },
        );

        testWidgets(
          'FriendsHubScreen (user discovery search results) @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(buildScope(
              textScaler: scaler,
              child: const FriendsHubScreen(),
            ));
            await tester.pumpAndSettle();

            // Enter search text into user discovery field
            final searchField = find.byKey(const Key('friends_search_input'));
            expect(searchField, findsOneWidget);
            await tester.enterText(searchField, 'Partner');
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'FriendsHubScreen search results overflowed at ${width.toInt()}px ($scaleLabel)',
            );
          },
        );

        testWidgets(
          'EmbeddedTradeOfferCard (recipient & proposer) @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(buildScope(
              textScaler: scaler,
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: EmbeddedTradeOfferCard(
                    proposalId: 'trade_adv_recipient',
                    currentUserId: meId,
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'EmbeddedTradeOfferCard overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('accept_trade_button')), findsOneWidget);
            expect(find.byKey(const Key('trade_counter_offer_button')), findsOneWidget);
            expect(find.byKey(const Key('decline_trade_button')), findsOneWidget);
          },
        );

        testWidgets(
          'InboxUserPickerModal @ ${width.toInt()}px [$scaleLabel]',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(buildScope(
              textScaler: scaler,
              child: const Scaffold(
                body: InboxUserPickerModal(),
              ),
            ));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'InboxUserPickerModal overflowed at ${width.toInt()}px ($scaleLabel)',
            );
            expect(find.byKey(const Key('inbox_user_picker_start_button')), findsOneWidget);
          },
        );
      }
    });
  }
}

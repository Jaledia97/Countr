import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-current-me',
        username: '@collector_me',
        displayName: 'My Profile',
        accountType: const Value('individual'),
        createdAt: DateTime.now(),
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-partner',
        username: '@partner',
        displayName: 'Partner User',
        accountType: const Value('individual'),
        createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
      ],
      child: const MaterialApp(
        home: FeedScreen(),
      ),
    );
  }

  testWidgets('feed_bell_red_dot badge never illuminates for self-actions and only lights up for incoming notifications', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Initial State: Clear any seeded notifications & messages so initial unread state is 0
    await db.delete(db.notifications).go();
    await db.delete(db.messages).go();
    await tester.pumpAndSettle();

    final bellFinder = find.byKey(const Key('feed_bell_red_dot'));
    expect(bellFinder, findsOneWidget);
    var badge = tester.widget<Badge>(bellFinder);
    expect(badge.isLabelVisible, isFalse);

    // 2. Outgoing Trade Proposal: Proposing trade does NOT light up red dot for initiator
    await db.inboxDao.createTradeProposal(
      proposerId: 'user-current-me',
      receiverId: 'user-partner',
      offeredCardIds: ['c1'],
      requestedCardIds: ['c2'],
      offeredTotalValue: 25.0,
      requestedTotalValue: 25.0,
    );
    await tester.pumpAndSettle();

    badge = tester.widget<Badge>(bellFinder);
    expect(badge.isLabelVisible, isFalse);

    // 3. Outgoing Friend Request: Sending friend request does NOT light up red dot for initiator
    await db.friendsDao.sendFriendRequest('user-current-me', 'user-partner');
    await tester.pumpAndSettle();

    badge = tester.widget<Badge>(bellFinder);
    expect(badge.isLabelVisible, isFalse);

    // 4. Rogue / Legacy Self-Notification: userId == actorId == user-current-me is filtered out
    await db.into(db.notifications).insert(
      NotificationsCompanion.insert(
        id: 'rogue_self_notif',
        userId: 'user-current-me',
        actorId: 'user-current-me',
        actorUsername: '@collector_me',
        type: 'post_like',
        title: 'You liked a post',
        body: 'self action',
        isRead: const Value(false),
        createdAt: Value(DateTime.now()),
      ),
    );
    await tester.pumpAndSettle();

    badge = tester.widget<Badge>(bellFinder);
    expect(badge.isLabelVisible, isFalse);

    // 5. Incoming Notification: Partner sends a friend request / notification to current user
    await db.into(db.notifications).insert(
      NotificationsCompanion.insert(
        id: 'incoming_partner_notif',
        userId: 'user-current-me',
        actorId: 'user-partner',
        actorUsername: '@partner',
        type: 'trade_proposal',
        title: 'New Trade Offer',
        body: 'sent you a trade proposal',
        isRead: const Value(false),
        createdAt: Value(DateTime.now()),
      ),
    );
    await tester.pumpAndSettle();

    // Red dot must now illuminate!
    badge = tester.widget<Badge>(bellFinder);
    expect(badge.isLabelVisible, isTrue);

    // 6. Marking read clears the red dot
    await db.inboxDao.markAllNotificationsAsRead('user-current-me');
    await tester.pumpAndSettle();

    badge = tester.widget<Badge>(bellFinder);
    expect(badge.isLabelVisible, isFalse);
  });
}

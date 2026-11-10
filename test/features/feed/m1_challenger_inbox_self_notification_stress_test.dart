import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('M1 Challenger: Inbox Self-Notification Adversarial Stress Tests', () {
    test('10-User Concurrent Cross-Fire: unread counts and watch streams strictly exclude self-notifications', () async {
      const userCount = 10;
      final userIds = List.generate(userCount, (i) => 'user-stress-$i');

      // Seed 10 profiles
      for (final uid in userIds) {
        await db.userProfileDao.upsertProfile(
          UserProfilesCompanion.insert(
            id: uid,
            username: '@$uid',
            displayName: 'User $uid',
            accountType: const Value('individual'),
            createdAt: DateTime.now(),
          ),
        );
      }

      final now = DateTime.now();

      // For every user i:
      // 1. Send trade proposal to user (i + 1) % 10 (genuine incoming for recipient)
      // 2. Attempt self trade proposal (should be guarded)
      // 3. Send friend request to user (i + 2) % 10 (genuine incoming)
      // 4. Attempt self friend request (should be guarded)
      // 5. Inject legacy rogue self-notifications of various types (post_like, deck_upvote, mention, milestone)
      for (int i = 0; i < userCount; i++) {
        final currentUserId = userIds[i];
        final nextUserId = userIds[(i + 1) % userCount];
        final thirdUserId = userIds[(i + 2) % userCount];

        // 1. Genuine outgoing trade proposal
        await db.inboxDao.createTradeProposal(
          proposerId: currentUserId,
          receiverId: nextUserId,
          offeredCardIds: ['c_${currentUserId}_1'],
          requestedCardIds: ['c_${nextUserId}_1'],
          offeredTotalValue: 10.0 + i,
          requestedTotalValue: 12.0 + i,
        );

        // 2. Outgoing trade proposal to self (defense-in-depth test)
        await db.inboxDao.createTradeProposal(
          proposerId: currentUserId,
          receiverId: currentUserId,
          offeredCardIds: ['c_self'],
          requestedCardIds: ['c_self_req'],
          offeredTotalValue: 5.0,
          requestedTotalValue: 5.0,
        );

        // 3. Genuine friend request
        await db.friendsDao.sendFriendRequest(currentUserId, thirdUserId);

        // 4. Self friend request
        await db.friendsDao.sendFriendRequest(currentUserId, currentUserId);

        // 5. Inject raw self-notifications with actorId == currentUserId
        for (final notifType in ['post_like', 'post_comment', 'deck_upvote', 'mention', 'milestone', 'trade_match']) {
          await db.into(db.notifications).insert(
            NotificationsCompanion.insert(
              id: 'raw_self_${notifType}_$currentUserId',
              userId: currentUserId,
              actorId: currentUserId,
              actorUsername: '@$currentUserId',
              type: notifType,
              title: 'Self Action $notifType',
              body: 'You performed $notifType on yourself',
              isRead: const Value(false),
              createdAt: Value(now.add(Duration(seconds: i))),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }

      // Assertions across all 10 users
      for (int i = 0; i < userCount; i++) {
        final uid = userIds[i];

        // Each user should have received:
        // - Exactly 1 trade proposal (from user (i - 1 + 10) % 10)
        // - Exactly 1 friend request (from user (i - 2 + 10) % 10)
        // Total incoming unread notifications = 2!
        // Despite having 6 rogue self-notifications and 2 self-actions attempted!
        final unreadCount = await db.inboxDao.watchUnreadNotificationCount(uid).first;
        expect(
          unreadCount,
          equals(2),
          reason: '$uid unread count must strictly be 2 (1 incoming trade + 1 incoming friend request), ignoring all self-notifications',
        );

        // Stream of all notifications must contain 0 items where actorId == uid
        final allNotifs = await db.inboxDao.watchNotifications(uid).first;
        expect(
          allNotifs.every((n) => n.actorId != uid),
          isTrue,
          reason: '$uid watchNotifications must not contain any notification where actorId == $uid',
        );
        expect(allNotifs.length, equals(2));

        // Test each filter mode:
        final requestsNotifs = await db.inboxDao.watchNotifications(uid, filter: 'requests').first;
        expect(requestsNotifs.length, equals(1));
        expect(requestsNotifs.first.type, equals('friend_request'));
        expect(requestsNotifs.first.actorId, isNot(equals(uid)));

        final tradesNotifs = await db.inboxDao.watchNotifications(uid, filter: 'trades').first;
        expect(tradesNotifs.length, equals(1));
        expect(tradesNotifs.first.type, equals('trade_proposal'));
        expect(tradesNotifs.first.actorId, isNot(equals(uid)));

        final activityNotifs = await db.inboxDao.watchNotifications(uid, filter: 'activity').first;
        expect(activityNotifs, isEmpty, reason: 'All activity notifications in this test were self-notifications and must be filtered out');
      }
    });

    test('markAllNotificationsAsRead isolates target user and never affects other users or mutates self-notifications', () async {
      final now = DateTime.now();

      // Seed 3 users
      for (final uid in ['user-A', 'user-B', 'user-C']) {
        await db.userProfileDao.upsertProfile(
          UserProfilesCompanion.insert(
            id: uid,
            username: '@$uid',
            displayName: 'User $uid',
            createdAt: now,
          ),
        );
      }

      // User A receives 3 notifications from User B
      for (int i = 0; i < 3; i++) {
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: 'notif_b_to_a_$i',
            userId: 'user-A',
            actorId: 'user-B',
            actorUsername: '@user-B',
            type: 'trade_proposal',
            title: 'Trade $i',
            body: 'Offer',
            isRead: const Value(false),
            createdAt: Value(now.add(Duration(minutes: i))),
          ),
        );
      }

      // User A also has a rogue self-notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_a_self',
          userId: 'user-A',
          actorId: 'user-A',
          actorUsername: '@user-A',
          type: 'post_like',
          title: 'Self Like',
          body: 'Liked own post',
          isRead: const Value(false),
          createdAt: Value(now),
        ),
      );

      // User B receives 4 notifications from User C
      for (int i = 0; i < 4; i++) {
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: 'notif_c_to_b_$i',
            userId: 'user-B',
            actorId: 'user-C',
            actorUsername: '@user-C',
            type: 'friend_request',
            title: 'Friend $i',
            body: 'Friend req',
            isRead: const Value(false),
            createdAt: Value(now.add(Duration(minutes: i))),
          ),
        );
      }

      // User C receives 5 notifications from User A
      for (int i = 0; i < 5; i++) {
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: 'notif_a_to_c_$i',
            userId: 'user-C',
            actorId: 'user-A',
            actorUsername: '@user-A',
            type: 'mention',
            title: 'Mention $i',
            body: 'Mentioned you',
            isRead: const Value(false),
            createdAt: Value(now.add(Duration(minutes: i))),
          ),
        );
      }

      // Verify initial unread counts
      expect(await db.inboxDao.watchUnreadNotificationCount('user-A').first, equals(3));
      expect(await db.inboxDao.watchUnreadNotificationCount('user-B').first, equals(4));
      expect(await db.inboxDao.watchUnreadNotificationCount('user-C').first, equals(5));

      // User A marks all notifications as read
      await db.inboxDao.markAllNotificationsAsRead('user-A');

      // User A unread count must become 0
      expect(await db.inboxDao.watchUnreadNotificationCount('user-A').first, equals(0));

      // User B and User C unread counts MUST remain completely unchanged!
      expect(await db.inboxDao.watchUnreadNotificationCount('user-B').first, equals(4));
      expect(await db.inboxDao.watchUnreadNotificationCount('user-C').first, equals(5));

      // Self-notification of User A must NOT be marked read by markAllNotificationsAsRead
      // because markAllNotificationsAsRead filters by `t.actorId.equals(userId).not()`
      final selfNotif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_a_self'))).getSingle();
      expect(selfNotif.isRead, isFalse);
    });

    test('soft-deleted notifications (isDeleted = true) are ignored by unread count and watch streams', () async {
      final now = DateTime.now();

      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: 'user-alice',
          username: '@alice',
          displayName: 'Alice',
          createdAt: now,
        ),
      );

      // Add 2 active unread notifications
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'active_1',
          userId: 'user-alice',
          actorId: 'user-bob',
          actorUsername: '@bob',
          type: 'trade_proposal',
          title: 'Active 1',
          body: 'Hello',
          isRead: const Value(false),
          isDeleted: const Value(false),
          createdAt: Value(now),
        ),
      );
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'active_2',
          userId: 'user-alice',
          actorId: 'user-bob',
          actorUsername: '@bob',
          type: 'friend_request',
          title: 'Active 2',
          body: 'Hello',
          isRead: const Value(false),
          isDeleted: const Value(false),
          createdAt: Value(now.add(const Duration(seconds: 1))),
        ),
      );

      // Add 3 deleted unread notifications
      for (int i = 0; i < 3; i++) {
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: 'deleted_$i',
            userId: 'user-alice',
            actorId: 'user-bob',
            actorUsername: '@bob',
            type: 'post_like',
            title: 'Deleted $i',
            body: 'Gone',
            isRead: const Value(false),
            isDeleted: const Value(true),
            createdAt: Value(now.add(Duration(seconds: 2 + i))),
          ),
        );
      }

      // Add deleted self-notifications
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'deleted_self',
          userId: 'user-alice',
          actorId: 'user-alice',
          actorUsername: '@alice',
          type: 'post_like',
          title: 'Deleted Self',
          body: 'Gone',
          isRead: const Value(false),
          isDeleted: const Value(true),
          createdAt: Value(now.add(const Duration(seconds: 10))),
        ),
      );

      final count = await db.inboxDao.watchUnreadNotificationCount('user-alice').first;
      expect(count, equals(2));

      final list = await db.inboxDao.watchNotifications('user-alice').first;
      expect(list.length, equals(2));
      expect(list.any((n) => n.isDeleted), isFalse);
    });

    test('getSmartInboxInitialIndex handles edge conditions: deleted messages, self-notifs, empty inbox', () async {
      // 1. Completely empty inbox -> returns 0 (Notifications tab default)
      final emptyIndex = await db.inboxDao.getSmartInboxInitialIndex('user-unknown');
      expect(emptyIndex, equals(0));

      final now = DateTime.now();

      // 2. Incoming notification at T=10, deleted message at T=20
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_t10',
          userId: 'user-target',
          actorId: 'user-other',
          actorUsername: '@other',
          type: 'friend_request',
          title: 'Req',
          body: 'Req',
          isDeleted: const Value(false),
          createdAt: Value(now.add(const Duration(minutes: 10))),
        ),
      );

      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_deleted_t20',
          conversationId: 'user-other_user-target',
          senderId: 'user-other',
          recipientId: 'user-target',
          messageText: 'Deleted message',
          isDeleted: const Value(true),
          createdAt: Value(now.add(const Duration(minutes: 20))),
        ),
      );

      // Because message is deleted, notif at T=10 is newer than any active message -> returns 0
      final idxAfterDeletedMsg = await db.inboxDao.getSmartInboxInitialIndex('user-target');
      expect(idxAfterDeletedMsg, equals(0));

      // 3. Now insert active message at T=25 -> should switch to Messages tab (index 1)
      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_active_t25',
          conversationId: 'user-other_user-target',
          senderId: 'user-other',
          recipientId: 'user-target',
          messageText: 'Active newer message',
          isDeleted: const Value(false),
          createdAt: Value(now.add(const Duration(minutes: 25))),
        ),
      );

      final idxAfterActiveMsg = await db.inboxDao.getSmartInboxInitialIndex('user-target');
      expect(idxAfterActiveMsg, equals(1));

      // 4. Now user-target performs a self action at T=30 (e.g. self-notification injected)
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_self_t30',
          userId: 'user-target',
          actorId: 'user-target',
          actorUsername: '@target',
          type: 'deck_upvote',
          title: 'Self upvote',
          body: 'Upvoted own deck',
          isDeleted: const Value(false),
          createdAt: Value(now.add(const Duration(minutes: 30))),
        ),
      );

      // Self-notification at T=30 MUST BE IGNORED!
      // Active message at T=25 is still newer than incoming notif at T=10 -> should STILL return 1!
      final idxAfterSelfNotif = await db.inboxDao.getSmartInboxInitialIndex('user-target');
      expect(idxAfterSelfNotif, equals(1));
    });
  });
}

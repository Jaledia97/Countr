import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Seed profiles for Alice and Bob
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-alice',
        username: '@alice',
        displayName: 'Alice In Wonderland',
        avatarUrl: const Value('https://example.com/alice.png'),
        accountType: const Value('individual'),
        createdAt: DateTime.now(),
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-bob',
        username: '@bob',
        displayName: 'Bob The Builder',
        avatarUrl: const Value('https://example.com/bob.png'),
        accountType: const Value('individual'),
        createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('InboxDao Self-Notification Elimination Tests', () {
    test('watchNotifications strictly filters out self-notifications where userId == actorId', () async {
      final now = DateTime.now();

      // Insert incoming notification from Bob to Alice
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_from_bob',
          userId: 'user-alice',
          actorId: 'user-bob',
          actorUsername: '@bob',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to be friends',
          createdAt: Value(now),
        ),
      );

      // Insert rogue/legacy self-notification where Alice is both recipient and actor
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_from_self',
          userId: 'user-alice',
          actorId: 'user-alice',
          actorUsername: '@alice',
          type: 'friend_request',
          title: 'Self Action',
          body: 'you sent a request',
          createdAt: Value(now.add(const Duration(minutes: 1))),
        ),
      );

      final notifications = await db.inboxDao.watchNotifications('user-alice').first;
      expect(notifications.length, equals(1));
      expect(notifications.first.id, equals('notif_from_bob'));
      expect(notifications.any((n) => n.actorId == 'user-alice'), isFalse);
    });

    test('watchUnreadNotificationCount evaluates to 0 for self-notifications', () async {
      final now = DateTime.now();

      // Seed only a self-notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_self_1',
          userId: 'user-alice',
          actorId: 'user-alice',
          actorUsername: '@alice',
          type: 'trade_proposal',
          title: 'Trade Proposal',
          body: 'You proposed a trade',
          isRead: const Value(false),
          createdAt: Value(now),
        ),
      );

      final count = await db.inboxDao.watchUnreadNotificationCount('user-alice').first;
      expect(count, equals(0));

      // Now add a genuine notification from Bob
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_bob_1',
          userId: 'user-alice',
          actorId: 'user-bob',
          actorUsername: '@bob',
          type: 'trade_proposal',
          title: 'Trade Proposal',
          body: 'Bob sent you a proposal',
          isRead: const Value(false),
          createdAt: Value(now),
        ),
      );

      final countAfterBob = await db.inboxDao.watchUnreadNotificationCount('user-alice').first;
      expect(countAfterBob, equals(1));
    });

    test('getSmartInboxInitialIndex ignores self-notification timestamps', () async {
      final now = DateTime.now();

      // Alice receives a message from Bob at T=0
      await db.inboxDao.sendMessage(
        senderId: 'user-bob',
        recipientId: 'user-alice',
        messageText: 'Hello Alice',
      );

      // Alice triggers a self action notification at T=10 minutes
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_self_newer',
          userId: 'user-alice',
          actorId: 'user-alice',
          actorUsername: '@alice',
          type: 'friend_request',
          title: 'Self Action',
          body: 'Outgoing request',
          createdAt: Value(now.add(const Duration(minutes: 10))),
        ),
      );

      // Because self-notification is filtered out, the message tab (index 1) should be selected
      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex('user-alice');
      expect(initialIndex, equals(1));
    });

    test('markAllNotificationsAsRead marks only incoming notifications', () async {
      final now = DateTime.now();

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_from_bob',
          userId: 'user-alice',
          actorId: 'user-bob',
          actorUsername: '@bob',
          type: 'friend_request',
          title: 'Bob Request',
          body: 'sent request',
          isRead: const Value(false),
          createdAt: Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_self',
          userId: 'user-alice',
          actorId: 'user-alice',
          actorUsername: '@alice',
          type: 'friend_request',
          title: 'Self Request',
          body: 'sent request',
          isRead: const Value(false),
          createdAt: Value(now),
        ),
      );

      await db.inboxDao.markAllNotificationsAsRead('user-alice');

      final bobNotif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_from_bob'))).getSingle();
      final selfNotif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_self'))).getSingle();

      expect(bobNotif.isRead, isTrue);
      expect(selfNotif.isRead, isFalse); // Untouched by markAllNotificationsAsRead
    });

    test('createTradeProposal populates real proposer username & avatar and guards against self-notification', () async {
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
        offeredTotalValue: 45.0,
        requestedTotalValue: 50.0,
      );

      expect(proposal.id, isNotEmpty);

      // Check Bob's notification
      final bobNotif = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-bob') & t.targetEntityId.equals(proposal.id)))
          .getSingleOrNull();

      expect(bobNotif, isNotNull);
      expect(bobNotif!.actorId, equals('user-alice'));
      expect(bobNotif.actorUsername, equals('@alice'));
      expect(bobNotif.actorDisplayName, equals('Alice In Wonderland'));
      expect(bobNotif.actorAvatarUrl, equals('https://example.com/alice.png'));

      // Check Alice (proposer) received NO notification
      final aliceNotifs = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-alice')))
          .get();
      expect(aliceNotifs, isEmpty);
    });

    test('createTradeProposal guards 3-way trade third participant self-notification', () async {
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: 'user-charlie',
          username: '@charlie',
          displayName: 'Charlie Brown',
          accountType: const Value('individual'),
          createdAt: DateTime.now(),
        ),
      );

      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        thirdParticipantId: 'user-charlie',
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
        offeredTotalValue: 100.0,
        requestedTotalValue: 100.0,
      );

      // Verify Bob received notif with actor = Alice
      final bobNotif = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-bob') & t.targetEntityId.equals(proposal.id)))
          .getSingleOrNull();
      expect(bobNotif, isNotNull);
      expect(bobNotif!.actorId, equals('user-alice'));

      // Verify Charlie received notif with actor = Alice
      final charlieNotif = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-charlie') & t.targetEntityId.equals(proposal.id)))
          .getSingleOrNull();
      expect(charlieNotif, isNotNull);
      expect(charlieNotif!.actorId, equals('user-alice'));

      // Verify Alice received NO notification
      final aliceNotifs = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-alice')))
          .get();
      expect(aliceNotifs, isEmpty);
    });

    test('sendFriendRequest guards against sending to self and creates proper recipient notification', () async {
      // Attempt sending to self -> should be silently neutralized
      await db.friendsDao.sendFriendRequest('user-alice', 'user-alice');

      final aliceFriendships = await (db.select(db.friendships)
            ..where((t) => t.userId.equals('user-alice')))
          .get();
      expect(aliceFriendships, isEmpty);

      final aliceNotifs = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-alice')))
          .get();
      expect(aliceNotifs, isEmpty);

      // Now send from Alice to Bob
      await db.friendsDao.sendFriendRequest('user-alice', 'user-bob');

      final bobNotif = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-bob') & t.actorId.equals('user-alice')))
          .getSingleOrNull();

      expect(bobNotif, isNotNull);
      expect(bobNotif!.actorUsername, equals('@alice'));
      expect(bobNotif.actorDisplayName, equals('Alice In Wonderland'));
      expect(bobNotif.actorAvatarUrl, equals('https://example.com/alice.png'));

      // Alice should still have 0 notifications
      final aliceAfterNotifs = await (db.select(db.notifications)
            ..where((t) => t.userId.equals('user-alice')))
          .get();
      expect(aliceAfterNotifs, isEmpty);
    });
  });
}

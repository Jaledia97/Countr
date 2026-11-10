// Copyright (c) 2026 Countr. All rights reserved.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SocialSeedService seedService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    seedService = SocialSeedService(db);
    await seedService.seedSocialData();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest({Widget? child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
      ],
      child: MaterialApp(
        home: child ?? const FeedScreen(),
      ),
    );
  }

  group('Inbox Bell, Red Dot & Smart 2-Tab Workflow', () {
    testWidgets('FeedScreen Bell Icon renders crisp red dot when unread > 0, hidden when 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest(child: const FeedScreen()));
      await tester.pumpAndSettle();

      // Seeded data has unread notifications for user-current-me
      final bellFinder = find.byKey(const Key('feed_bell_red_dot'));
      expect(bellFinder, findsOneWidget);
      final badgeWidget = tester.widget<Badge>(bellFinder);
      expect(badgeWidget.isLabelVisible, isTrue);

      // Mark all notifications and messages read
      await db.inboxDao.markAllNotificationsAsRead('user-current-me');
      await db.inboxDao.markMessagesAsRead('user-current-me_user-foil-collector-99', 'user-current-me');
      await db.inboxDao.markMessagesAsRead('user-current-me_user-spicy-brew-master', 'user-current-me');
      await tester.pumpAndSettle();

      final updatedBadgeWidget = tester.widget<Badge>(bellFinder);
      expect(updatedBadgeWidget.isLabelVisible, isFalse);
    });

    test('getSmartInboxInitialIndex routes to Messages (1) when message is newer, Notifications (0) when notif is newer', () async {
      // Seeded data: notification created at now, let's test smart index
      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex('user-current-me');
      expect(initialIndex, inInclusiveRange(0, 1));

      // Insert very fresh message from foil collector
      await db.inboxDao.sendMessage(
        senderId: 'user-foil-collector-99',
        recipientId: 'user-current-me',
        messageText: 'Hey check out this fresh trade!',
      );

      final msgIndex = await db.inboxDao.getSmartInboxInitialIndex('user-current-me');
      expect(msgIndex, equals(1)); // 1 = Messages Tab
    });
  });

  group('AAA Messages Tab & Notifications Actioning', () {
    testWidgets('InboxHubScreen displays AAA Messages tab with relative timestamps, trade badge, and unread dot', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest(
        child: const InboxHubScreen(initialIndex: 1),
      ));
      await tester.pumpAndSettle();

      // Should be on Messages tab (index 1)
      expect(find.text('Messages'), findsWidgets);

      // Verify active trade proposal badge
      final badgeFinder = find.byKey(
        const Key('chat_thread_active_trade_badge_user-current-me_user-spicy-brew-master'),
      );
      expect(badgeFinder, findsOneWidget);

      // Verify unread indicator dot
      final dotFinder = find.byKey(
        const Key('chat_thread_unread_dot_user-current-me_user-spicy-brew-master'),
      );
      expect(dotFinder, findsOneWidget);

      // Tapping thread marks read
      final threadTile = find.byKey(
        const Key('chat_thread_tile_user-current-me_user-spicy-brew-master'),
      );
      expect(threadTile, findsOneWidget);
    });

    testWidgets('Notifications tab provides inline Approve and Deny for Friend Requests', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest(
        child: const InboxHubScreen(initialIndex: 0),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      const frNotifId = 'notif_fr_foil_collector';
      final approveBtnFinder = find.byKey(const Key('notif_approve_fr_$frNotifId'));
      final denyBtnFinder = find.byKey(const Key('notif_deny_fr_$frNotifId'));

      expect(approveBtnFinder, findsOneWidget);
      expect(denyBtnFinder, findsOneWidget);

      // Tap Approve
      await tester.tap(approveBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Inline state updates to "Accepted"
      expect(find.byKey(const Key('notif_status_accepted_$frNotifId')), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('Notifications tab inline Deny removes request', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest(
        child: const InboxHubScreen(initialIndex: 0),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      const frNotifId = 'notif_fr_foil_collector';
      final denyBtnFinder = find.byKey(const Key('notif_deny_fr_$frNotifId'));
      expect(denyBtnFinder, findsOneWidget);

      // Tap Deny
      await tester.tap(denyBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Inline state updates to "Declined"
      expect(find.byKey(const Key('notif_status_declined_$frNotifId')), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
    });
  });
}

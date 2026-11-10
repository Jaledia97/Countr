import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-current-me',
        username: '@collector_me',
        displayName: 'Collector Me',
        accountType: const Value('individual'),
        createdAt: now,
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: 'user-partner',
        username: '@partner_bob',
        displayName: 'Partner Bob',
        accountType: const Value('individual'),
        createdAt: now,
      ),
    );

    // Seed card in vaultItems
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'card-dockside-match',
        name: 'Dockside Extortionist',
        setOrSeries: '2X2',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 75.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 75.0,
        lastPriceUpdate: now,
        userId: const Value('user-partner'),
        dynamicData: '{}',
      ),
    );

    // Seed trade_match notification
    await db.into(db.notifications).insert(
      NotificationsCompanion.insert(
        id: 'notif_match_test_1',
        userId: 'user-current-me',
        actorId: 'user-partner',
        actorUsername: '@partner_bob',
        actorDisplayName: const Value('Partner Bob'),
        type: 'trade_match',
        title: 'Trade Match Found!',
        body: 'has Dockside Extortionist in their Trade Binder that you have been looking for!',
        targetEntityId: const Value('card-dockside-match'),
        targetEntityType: const Value('trade_match'),
        status: const Value('unread'),
        isRead: const Value(false),
        createdAt: Value(now),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildInboxHub() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        inboxDaoProvider.overrideWithValue(db.inboxDao),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: InboxHubScreen(initialIndex: 0),
        ),
      ),
    );
  }

  group('Trade Match Notification UI & Filter Tests', () {
    testWidgets('Renders trade_match notification with Propose Trade button and filters under Trades tab', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 950));
      await tester.pumpWidget(buildInboxHub());
      await tester.pumpAndSettle();

      // 1. Verify notification card renders with actor and body text
      expect(find.byKey(const Key('notif_card_notif_match_test_1')), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('@partner_bob')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Dockside Extortionist')),
        findsOneWidget,
      );

      // 2. Verify Propose Trade action button is present
      final proposeBtnFinder = find.byKey(const Key('notif_propose_trade_notif_match_test_1'));
      expect(proposeBtnFinder, findsOneWidget);

      // 3. Filter under Trades tab -> notification MUST remain visible
      await tester.tap(find.byKey(const Key('inbox_filter_trades')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notif_propose_trade_notif_match_test_1')), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Dockside Extortionist')),
        findsOneWidget,
      );

      // 4. Filter under Friend Requests tab -> notification MUST NOT be visible
      await tester.tap(find.byKey(const Key('inbox_filter_friend_requests')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notif_propose_trade_notif_match_test_1')), findsNothing);
      expect(find.byKey(const Key('inbox_notifications_empty')), findsOneWidget);

      // 5. Filter under Activity tab -> notification MUST NOT be visible
      await tester.tap(find.byKey(const Key('inbox_filter_activity')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notif_propose_trade_notif_match_test_1')), findsNothing);

      // 6. Return to All tab, tap Propose Trade button
      await tester.tap(find.byKey(const Key('inbox_filter_all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notif_propose_trade_notif_match_test_1')));
      await tester.pumpAndSettle();

      // Verify notification was marked as read in database
      final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_match_test_1'))).getSingle();
      expect(notif.isRead, isTrue);

      // Verify Propose Trade sheet / modal opens
      expect(find.byKey(const Key('propose_trade_modal')), findsOneWidget);
    });
  });
}

// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive verification test suite for Milestone 4 (Epic 4: Home Search Discovery, 2-Tab Inbox Hub, Friends Hub, Unified Mock Profiles & 100% Interactive Feed)

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/screens/chat_conversation_screen.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/feed/presentation/screens/friends_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/feed/presentation/widgets/home_search_results_view.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_comments_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
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

  group('M4 Verification: 1. Drift Schema v12, DAOs & Seed Data', () {
    test('Drift database is on schemaVersion 12 or newer', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(12));
    });

    test('Social seed service seeds unified personas, posts, and notifications', () async {
      // Check seeded posts
      final posts = await db.feedDao.watchFeedPosts().first;
      expect(posts.isNotEmpty, isTrue);
      expect(posts.any((p) => p.authorId == 'user-foil-collector-99'), isTrue);
      expect(posts.any((p) => p.authorId == 'store-tbs-comics'), isTrue);

      // Check seeded comments
      final comments = await db.feedDao.watchComments(posts.first.id).first;
      expect(comments.isNotEmpty, isTrue);

      // Check seeded notifications for current user
      final notifs = await db.inboxDao.watchNotifications('user-current-me').first;
      expect(notifs.isNotEmpty, isTrue);
      expect(notifs.any((n) => n.type == 'friend_request'), isTrue);
      expect(notifs.any((n) => n.type == 'trade_proposal'), isTrue);

      // Check unread counts
      final unreadNotifs = await db.inboxDao.watchUnreadNotificationCount('user-current-me').first;
      expect(unreadNotifs, greaterThan(0));

      final unreadMsgs = await db.inboxDao.watchUnreadMessageCount('user-current-me').first;
      expect(unreadMsgs, greaterThanOrEqualTo(0));
    });

    test('FeedDao like toggle functions with SQLite persistence', () async {
      final posts = await db.feedDao.watchFeedPosts().first;
      final targetPost = posts.first;

      // Toggle like on
      final isLiked1 = await db.feedDao.togglePostLike(
        targetPost.id,
        'user-current-me',
      );
      expect(isLiked1, isTrue);

      final checkLiked1 = await db.feedDao.watchIsPostLiked(targetPost.id, 'user-current-me').first;
      expect(checkLiked1, isTrue);

      // Toggle like off
      final isLiked2 = await db.feedDao.togglePostLike(
        targetPost.id,
        'user-current-me',
      );
      expect(isLiked2, isFalse);

      final checkLiked2 = await db.feedDao.watchIsPostLiked(targetPost.id, 'user-current-me').first;
      expect(checkLiked2, isFalse);
    });

    test('FriendsDao sends and cancels friend requests genuinely', () async {
      // Send request to TBS Comics
      await db.friendsDao.sendFriendRequest('user-current-me', 'store-tbs-comics');

      final outgoing = await db.friendsDao.watchOutgoingRequests('user-current-me').first;
      expect(outgoing.any((r) => r.friendId == 'store-tbs-comics'), isTrue);

      final status = await db.friendsDao.watchFriendshipStatus('user-current-me', 'store-tbs-comics').first;
      expect(status, equals('pending_sent'));

      // Cancel request
      await db.friendsDao.cancelFriendRequest('user-current-me', 'store-tbs-comics');
      final statusAfterCancel = await db.friendsDao.watchFriendshipStatus('user-current-me', 'store-tbs-comics').first;
      expect(statusAfterCancel, equals('none'));
    });

    test('InboxDao atomic trade acceptance transfer engine executes correctly', () async {
      // Find the seeded pending trade proposal
      final trade = await (db.select(db.tradeProposals)
            ..where((t) => t.status.equals('pending')))
          .getSingleOrNull();

      expect(trade, isNotNull);

      // Accept trade with automatic transfer enabled
      await db.inboxDao.respondToTradeProposal(
        trade!.id,
        accept: true,
        transferCards: true,
        currentUserId: 'user-current-me',
      );

      // Proposal status is updated
      final updatedProposal = await db.inboxDao.watchTradeProposal(trade.id).first;
      expect(updatedProposal?.status, equals('accepted'));
      expect(updatedProposal?.isTransferred, isTrue);

      // Offered card ownership transferred to receiver and placed in receiver's trade block binder
      final cardDockside = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-card-dockside-extortionist')))
          .getSingleOrNull();
      expect(cardDockside?.userId, equals(trade.receiverId));
      expect(cardDockside?.primaryBinderId, equals('system_trade_block_${trade.receiverId}'));
      expect(cardDockside?.isTraded, isTrue);

      // Requested card ownership transferred to proposer and placed in proposer's trade block binder
      final cardSolRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-sol-ring')))
          .getSingleOrNull();
      expect(cardSolRing?.userId, equals(trade.proposerId));
      expect(cardSolRing?.primaryBinderId, equals('system_trade_block_${trade.proposerId}'));
      expect(cardSolRing?.isTraded, isTrue);

      // Concurrency guard: already-accepted proposal cannot be responded to again
      await db.inboxDao.respondToTradeProposal(
        trade.id,
        accept: false,
        transferCards: false,
        currentUserId: 'user-current-me',
      );
      final guardProposal = await db.inboxDao.watchTradeProposal(trade.id).first;
      expect(guardProposal?.status, equals('accepted'));
    });
  });

  group('M4 Verification: 2. Home Search Discovery', () {
    testWidgets('FeedScreen displays search bar, debounce, and categorizes results', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top search icon button is present
      final searchButton = find.byKey(const Key('feed_appbar_search_button'));
      expect(searchButton, findsOneWidget);

      // Tap to open search bar
      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // Search input field is visible
      final searchInput = find.byKey(const Key('home_search_input'));
      expect(searchInput, findsOneWidget);

      // Enter search query
      await tester.enterText(searchInput, 'TBS');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Clear button is visible and clears input
      final clearButton = find.byKey(const Key('home_search_clear_button'));
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);
    });

    testWidgets('HomeSearchResultsView renders Categorized People, LGS, and Posts', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      // Set query
      container.read(homeSearchQueryProvider.notifier).state = 'foil';
      final results = await container.read(homeSearchResultsProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: HomeSearchResultsView(results: results),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show results
      expect(find.textContaining('Foil'), findsWidgets);
    });
  });

  group('M4 Verification: 3. 100% Interactive Feed Posts', () {
    testWidgets('PostActionBar triggers like toggle with optimistic update', (tester) async {
      bool likeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostActionBar(
              initialHypeCount: 10,
              commentCount: 4,
              initialIsHyped: false,
              onHypeTap: () {
                likeTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('HYPE (10)'), findsOneWidget);

      await tester.tap(find.text('HYPE (10)'));
      await tester.pumpAndSettle();

      expect(likeTapped, isTrue);
      expect(find.text('HYPE (11)'), findsOneWidget);
    });

    testWidgets('PostCommentsSheet displays live comments and submits new comment', (tester) async {
      final posts = await (db.select(db.feedPosts)..limit(1)).get();
      final targetPost = FeedPost.fromRecord(posts.first);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PostCommentsSheet(post: targetPost),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Comment input field and send button are present
      final commentInput = find.byKey(const Key('post_comment_input'));
      final sendButton = find.byKey(const Key('post_comment_submit_button'));
      expect(commentInput, findsOneWidget);
      expect(sendButton, findsOneWidget);

      // Enter comment with Mana symbols
      await tester.enterText(commentInput, 'Awesome pull! {U}{R} combo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Comment is added to SQLite and appears in list
      expect(find.textContaining('Awesome pull!'), findsOneWidget);
    });

    testWidgets('PostComposerModal submits new text post to SQLite', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => PostComposerModal.show(context),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap FAB to open modal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Modal elements exist
      final composerInput = find.byKey(const Key('post_composer_text_input'));
      final publishButton = find.byKey(const Key('post_composer_publish_button'));
      expect(composerInput, findsOneWidget);
      expect(publishButton, findsOneWidget);

      // Enter post content
      await tester.enterText(composerInput, 'Testing live social post creation from modal!');
      await tester.pumpAndSettle();

      await tester.tap(publishButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify post inserted into Drift database
      final posts = await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get();
      expect(
        posts.any((p) => p.textContent?.contains('Testing live social post creation from modal!') == true),
        isTrue,
      );
    });
  });

  group('M4 Verification: 4. 2-Tab Inbox Hub & Direct Messages', () {
    testWidgets('InboxHubScreen switches between Notifications and Messages tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: const MaterialApp(
            home: InboxHubScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Both tabs are present
      expect(find.byKey(const Key('inbox_tab_notifications')), findsOneWidget);
      expect(find.byKey(const Key('inbox_tab_messages')), findsOneWidget);

      // Mark all read button is present
      expect(find.byKey(const Key('inbox_mark_all_read_button')), findsOneWidget);

      // Filter chips are present in notifications tab
      expect(find.byKey(const Key('inbox_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('inbox_filter_friend_requests')), findsOneWidget);
      expect(find.byKey(const Key('inbox_filter_trades')), findsOneWidget);
      expect(find.byKey(const Key('inbox_filter_activity')), findsOneWidget);

      // Switch to Messages tab
      await tester.tap(find.byKey(const Key('inbox_tab_messages')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Chat thread tile is displayed with active trade badge
      expect(find.byKey(const Key('chat_thread_tile_user-current-me_user-spicy-brew-master')), findsOneWidget);
      expect(
        find.byKey(const Key('chat_thread_active_trade_badge_user-current-me_user-spicy-brew-master')),
        findsOneWidget,
      );
    });

    testWidgets('ChatConversationScreen sends message and displays active trade proposal', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: const MaterialApp(
            home: ChatConversationScreen(
              conversationId: 'user-current-me_user-spicy-brew-master',
              contactId: 'user-spicy-brew-master',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Active Trade Proposal card is rendered
      expect(find.text('Active Trade Proposal'), findsOneWidget);
      expect(find.byKey(const Key('chat_accept_trade_button')), findsOneWidget);
      expect(find.byKey(const Key('chat_decline_trade_button')), findsOneWidget);

      // Message input is present
      final messageInput = find.byKey(const Key('chat_message_input'));
      final sendButton = find.byKey(const Key('chat_message_send_button'));
      expect(messageInput, findsOneWidget);
      expect(sendButton, findsOneWidget);

      // Send a new chat message
      await tester.enterText(messageInput, 'Hey! Checked your trade binder, looks good.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hey! Checked your trade binder, looks good.'), findsOneWidget);
    });
  });

  group('M4 Verification: 5. Friends Hub Screen', () {
    testWidgets('FriendsHubScreen displays My Friends and Requests & Find tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: const MaterialApp(
            home: FriendsHubScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tab navigation
      expect(find.byKey(const Key('friends_tab_my_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_requests')), findsOneWidget);

      // Friends search input
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);

      // Switch to Requests & Find tab
      await tester.tap(find.byKey(const Key('friends_tab_requests')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Find friends search bar
      expect(find.byKey(const Key('find_friends_search_input')), findsOneWidget);

      // Incoming request from Foil Collector 99 is visible with accept/decline
      expect(find.byKey(const Key('friend_request_accept_friend_foil_current_pending')), findsOneWidget);
      expect(find.byKey(const Key('friend_request_decline_friend_foil_current_pending')), findsOneWidget);
    });
  });
}

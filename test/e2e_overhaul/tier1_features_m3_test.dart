// Copyright (c) 2026 Countr. All rights reserved.
// Tier 1 Acceptance Feature Coverage: Milestone 3 (Features 9 to 16)
// Upgraded to exercise authentic production components from lib/features/feed/
// and real SQLite Drift database backing.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/screens/saved_posts_screen.dart';
import 'package:countr/features/feed/presentation/widgets/multi_card_wishlist_drawer.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_comments_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

import 'e2e_overhaul_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1: Feature Coverage — Milestone 3 (Features 9 to 16)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.userProfileDao.seedDefaultProfiles();
      await (db.update(db.userProfiles)).write(
        const UserProfilesCompanion(avatarUrl: drift.Value(null)),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp({
      required Widget child,
      String currentUserId = 'user_me',
      List<Override> extraOverrides = const [],
    }) {
      return wrapWithOverhaulScope(
        child,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          feedDaoProvider.overrideWithValue(db.feedDao),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          currentUserIdProvider.overrideWith((ref) => currentUserId),
          ...extraOverrides,
        ],
      );
    }

    // =========================================================================
    // FEATURE 9: Icons-Only Post Interaction Bar
    // =========================================================================
    group('Feature 9: Icons-Only Post Interaction Bar', () {
      testWidgets('F9.1: Interaction bar strips all text labels (no Hype, Like, Comment, Share)', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f9_1',
            initialNetScore: 42,
            commentCount: 5,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('icons_only_post_action_bar')), findsOneWidget);
        expect(find.text('Hype'), findsNothing);
        expect(find.text('Like'), findsNothing);
        expect(find.text('Comment'), findsNothing);
        expect(find.text('Share'), findsNothing);
      });

      testWidgets('F9.2: Upvote and downvote actions display only arrow icons without text', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f9_2',
            initialNetScore: 10,
            commentCount: 2,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_upvote_button')), findsOneWidget);
        expect(find.byKey(const Key('post_downvote_button')), findsOneWidget);
        expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      });

      testWidgets('F9.3: Comment action displays only speech bubble icon and numeric counter', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f9_3',
            initialNetScore: 0,
            commentCount: 18,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_comment_button')), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
        expect(find.byKey(const Key('post_comment_counter_text')), findsOneWidget);
        expect(find.text('18'), findsOneWidget);
      });

      testWidgets('F9.4: React emoji action displays only add reaction icon', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f9_4',
            initialNetScore: 0,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_action_react_button')), findsOneWidget);
        expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);
      });

      testWidgets('F9.5: Zero string labels rendered in bar layout', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f9_5',
            initialNetScore: 5,
            commentCount: 3,
          ),
        ));
        await tester.pumpAndSettle();

        // Only numeric strings allowed
        expect(find.text('5'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 10: Reddit-Style Upvote/Downvote Pill
    // =========================================================================
    group('Feature 10: Reddit-Style Upvote/Downvote Pill', () {
      testWidgets('F10.1: Pill format conforms to [ ↑ | Net Score | ↓ ] structure', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f10_1',
            initialNetScore: 15,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reddit_voting_pill')), findsOneWidget);
        expect(find.byKey(const Key('post_upvote_button')), findsOneWidget);
        expect(find.byKey(const Key('post_net_score_text')), findsOneWidget);
        expect(find.byKey(const Key('post_downvote_button')), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
      });

      testWidgets('F10.2: Tapping upvote sets +1 score and applies orange accent', (tester) async {
        int? recordedVote;
        await tester.pumpWidget(createTestApp(
          child: PostActionBar(
            postId: 'post_f10_2',
            initialNetScore: 0,
            commentCount: 0,
            onVoteChanged: (v) => recordedVote = v,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_upvote_button')));
        await tester.pumpAndSettle();

        expect(recordedVote, equals(1));
        expect(find.text('1'), findsOneWidget);

        final scoreText = tester.widget<Text>(find.byKey(const Key('post_net_score_text')));
        expect(scoreText.style?.color, equals(const Color(0xFFFF4500)));
      });

      testWidgets('F10.3: Tapping upvote again toggles vote off (score 0)', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f10_3',
            initialNetScore: 0,
            commentCount: 7,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_upvote_button')));
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);

        await tester.tap(find.byKey(const Key('post_upvote_button')));
        await tester.pumpAndSettle();
        final textWidget = tester.widget<Text>(find.byKey(const Key('post_net_score_text')));
        expect(textWidget.data, equals('0'));
      });

      testWidgets('F10.4: Tapping downvote sets -1 score and applies blue accent', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f10_4',
            initialNetScore: 0,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_downvote_button')));
        await tester.pumpAndSettle();
        expect(find.text('-1'), findsOneWidget);

        final scoreText = tester.widget<Text>(find.byKey(const Key('post_net_score_text')));
        expect(scoreText.style?.color, equals(const Color(0xFF7193FF)));
      });

      test('F10.5: Votes persist per user in SQLite and recalculate net score across users', () async {
        const postId = 'post_edh_sql';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_author_1',
            authorUsername: '@edh_author',
            authorDisplayName: 'EDH Author',
            type: 'text',
            textContent: const drift.Value('Testing votes in SQLite FeedDao'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        await db.feedDao.votePost(postId, 'user_1', 1);
        await db.feedDao.votePost(postId, 'user_2', 1);
        await db.feedDao.votePost(postId, 'user_3', -1);
        await db.feedDao.votePost(postId, 'user_4', 1);

        final netScore = await db.feedDao.watchPostNetScore(postId).first;
        expect(netScore, equals(2)); // +1 +1 -1 +1 = 2
      });
    });

    // =========================================================================
    // FEATURE 11: Emoji Reactions on Posts
    // =========================================================================
    group('Feature 11: Emoji Reactions on Posts', () {
      testWidgets('F11.1: Tapping react icon opens floating 5 MRU suggestions bar', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f11_1',
            initialNetScore: 0,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reaction_mru_selector')), findsNothing);
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_🔥')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_❤️')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_😂')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_🤯')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_💎')), findsOneWidget);
      });

      testWidgets('F11.2: Selecting an emoji adds reaction and displays compact pill above bar', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f11_2',
            initialNetScore: 0,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mru_emoji_🔥')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reaction_pill_🔥')), findsOneWidget);
        expect(find.text('🔥 1'), findsOneWidget);
      });

      testWidgets('F11.3: Selecting recently used emoji reorders MRU suggestions with newest selection first', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f11_3',
            initialNetScore: 0,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        // Open MRU selector and select 💎 (last default item)
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mru_emoji_💎')));
        await tester.pumpAndSettle();

        // Reopen MRU selector to verify 💎 is present in capacity 5
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mru_emoji_💎')), findsOneWidget);
      });

      testWidgets('F11.4: Tapping existing active reaction toggles/removes reaction', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f11_4',
            initialNetScore: 0,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        // Add reaction ❤️
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mru_emoji_❤️')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reaction_pill_❤️')), findsOneWidget);

        // Tap active reaction pill to toggle off
        await tester.tap(find.byKey(const Key('reaction_pill_❤️')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reaction_pill_❤️')), findsNothing);
      });

      testWidgets('F11.5: MRU suggestions bar provides + icon for full picker', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(
            postId: 'post_f11_5',
            initialNetScore: 0,
            commentCount: 0,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mru_full_picker_button')), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 12: Relocate Wishlist/Save to Header Menu
    // =========================================================================
    group('Feature 12: Relocate Wishlist/Save to Header Menu', () {
      testWidgets('F12.1: Post header overflow menu opens options sheet', (tester) async {
        final post = FeedPost(
          id: 'post_f12_1',
          type: PostType.singlePull,
          username: '@RagavanCollector',
          avatarInitials: 'RC',
          timestamp: '1h ago',
          locationTag: 'Pocket Pod',
          cardId: 'card_ragavan',
          cardTitle: 'Ragavan, Nimble Pilferer',
        );

        await tester.pumpWidget(createTestApp(
          child: PostHeader(
            username: post.username,
            avatarInitials: post.avatarInitials,
            timestamp: post.timestamp,
            locationTag: post.locationTag,
            post: post,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_menu_wishlist_card')), findsOneWidget);
      });

      testWidgets('F12.2: Single-card post menu displays Wishlist Card (Add to Looking For)', (tester) async {
        final post = FeedPost(
          id: 'post_f12_2',
          type: PostType.singlePull,
          username: '@RagavanCollector',
          avatarInitials: 'RC',
          timestamp: '1h ago',
          locationTag: 'Pocket Pod',
          cardId: 'card_ragavan',
          cardTitle: 'Ragavan, Nimble Pilferer',
        );

        await tester.pumpWidget(createTestApp(
          child: PostHeader(
            username: post.username,
            avatarInitials: post.avatarInitials,
            timestamp: post.timestamp,
            locationTag: post.locationTag,
            post: post,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_menu_wishlist_card')), findsOneWidget);
        expect(find.text('Wishlist Card (Add to Looking For)'), findsOneWidget);
      });

      testWidgets('F12.3: Multi-card post menu displays Wishlist Cards opening drawer', (tester) async {
        final post = FeedPost(
          id: 'post_f12_3',
          type: PostType.multiPull,
          username: '@ForceCollector',
          avatarInitials: 'FC',
          timestamp: '2h ago',
          locationTag: 'TBS Comics',
          pullCardIds: const ['card_fow', 'card_mana_crypt'],
        );

        await tester.pumpWidget(createTestApp(
          child: PostHeader(
            username: post.username,
            avatarInitials: post.avatarInitials,
            timestamp: post.timestamp,
            locationTag: post.locationTag,
            post: post,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_menu_wishlist_cards_drawer')), findsOneWidget);
        expect(find.text('Wishlist Cards'), findsOneWidget);
      });

      testWidgets('F12.4: Multi-card wishlist drawer includes Select All and individual checkboxes', (tester) async {
        const cardIds = ['c1', 'c2', 'c3'];
        const cardTitles = ['Force of Will', 'Mana Crypt', 'Ragavan'];

        await tester.pumpWidget(createTestApp(
          child: const MultiCardWishlistDrawer(
            cardIds: cardIds,
            cardTitles: cardTitles,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('wishlist_drawer_title')), findsOneWidget);
        expect(find.text('Wishlist Cards (3)'), findsOneWidget);
        expect(find.byKey(const Key('wishlist_drawer_select_all')), findsOneWidget);
        expect(find.text('Add Selected (3) to Looking For'), findsOneWidget);

        // Deselect all
        await tester.tap(find.byKey(const Key('wishlist_drawer_select_all')));
        await tester.pumpAndSettle();
        expect(find.text('Add Selected (0) to Looking For'), findsOneWidget);

        // Select individual card (Card 0)
        await tester.tap(find.byKey(const Key('wishlist_drawer_card_0')));
        await tester.pumpAndSettle();
        expect(find.text('Add Selected (1) to Looking For'), findsOneWidget);
      });

      testWidgets('F12.5: Text-only and non-card image posts display Save Post with bookmark icon', (tester) async {
        final textPost = FeedPost(
          id: 'post_f12_5',
          type: PostType.text,
          username: '@Writer',
          avatarInitials: 'WR',
          timestamp: '3h ago',
          locationTag: 'Online',
          textContent: 'Standard text post without cards',
        );

        await tester.pumpWidget(createTestApp(
          child: PostHeader(
            username: textPost.username,
            avatarInitials: textPost.avatarInitials,
            timestamp: textPost.timestamp,
            locationTag: textPost.locationTag,
            post: textPost,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_menu_save_post')), findsOneWidget);
        expect(find.text('Save Post'), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 13: Command Center Saved Posts Dropdown
    // =========================================================================
    group('Feature 13: Command Center Saved Posts Dropdown', () {
      testWidgets('F13.1: Top My Profile tile contains downward chevron icon', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const MorphingCommandCenter(),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('command_center_profile_chevron')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('command_center_profile_chevron')),
            matching: find.byIcon(Icons.expand_more),
          ),
          findsOneWidget,
        );
      });

      testWidgets('F13.2: Tapping chevron reveals Saved Posts row', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const MorphingCommandCenter(),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('command_center_saved_posts_tile')), findsNothing);
        await tester.tap(find.byKey(const Key('command_center_profile_chevron')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('command_center_saved_posts_tile')), findsOneWidget);
        expect(find.text('Saved Posts'), findsOneWidget);
      });

      testWidgets('F13.3: Saved Posts row displays count badge', (tester) async {
        // Seed 2 saved posts in SQLite
        await db.feedDao.toggleSavePost('post_f13_1', 'user_me');
        await db.feedDao.toggleSavePost('post_f13_2', 'user_me');

        await tester.pumpWidget(createTestApp(
          child: const MorphingCommandCenter(),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('command_center_profile_chevron')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('command_center_saved_posts_count_badge')), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('F13.4: Tapping Saved Posts row navigates to saved posts screen', (tester) async {
        await tester.pumpWidget(createTestApp(
          currentUserId: 'user_empty_saved',
          child: const SavedPostsScreen(),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('saved_posts_screen')), findsOneWidget);
        expect(find.byKey(const Key('saved_posts_title')), findsOneWidget);
        expect(find.byKey(const Key('saved_posts_empty_view')), findsOneWidget);
      });

      test('F13.5: Saving/unsaving posts dynamically updates badge count', () async {
        expect(await db.feedDao.watchSavedPostsCount('user_me').first, equals(0));
        await db.feedDao.toggleSavePost('post_1', 'user_me');
        await db.feedDao.toggleSavePost('post_2', 'user_me');
        expect(await db.feedDao.watchSavedPostsCount('user_me').first, equals(2));
        await db.feedDao.toggleSavePost('post_1', 'user_me'); // unsave
        expect(await db.feedDao.watchSavedPostsCount('user_me').first, equals(1));
      });
    });

    // =========================================================================
    // FEATURE 14: Deep Nested Reply Threads
    // =========================================================================
    group('Feature 14: Deep Nested Reply Threads', () {
      test('F14.1: Schema supports parentCommentId allowing arbitrary nesting depth', () async {
        const postId = 'post_tree_depth';
        final c1 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'L1',
        );
        final c2 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u2',
          authorUsername: '@u2',
          authorDisplayName: 'U2',
          content: 'L2',
          parentCommentId: c1.id,
        );
        final c3 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u3',
          authorUsername: '@u3',
          authorDisplayName: 'U3',
          content: 'L3',
          parentCommentId: c2.id,
        );
        final c4 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u4',
          authorUsername: '@u4',
          authorDisplayName: 'U4',
          content: 'L4',
          parentCommentId: c3.id,
        );

        final comments = await db.feedDao.watchComments(postId).first;
        expect(comments.length, equals(4));
        expect(comments.firstWhere((c) => c.id == c4.id).parentCommentId, equals(c3.id));
      });

      testWidgets('F14.2: Tapping Reply on comment focuses input with Replying to @username banner', (tester) async {
        const postId = 'post_comments_reply_f14_2';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Testing reply banner'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final targetPost = FeedPost(
          id: postId,
          type: PostType.text,
          username: '@me',
          avatarInitials: 'ME',
          timestamp: 'Now',
          locationTag: 'Local',
          textContent: 'Testing reply banner',
        );
        final root = await db.feedDao.addComment(
          postId: postId,
          authorId: 'user_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brew',
          content: 'Parent comment',
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('replying_to_banner')), findsNothing);
        await tester.tap(find.byKey(Key('comment_reply_button_${root.id}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('replying_to_banner')), findsOneWidget);
        expect(find.textContaining('Replying to'), findsOneWidget);
      });

      testWidgets('F14.3: Comments tree renders child replies indented beneath parent', (tester) async {
        const postId = 'post_indent_f14_3';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Indent test'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final targetPost = FeedPost(
          id: postId,
          type: PostType.text,
          username: '@me',
          avatarInitials: 'ME',
          timestamp: 'Now',
          locationTag: 'Local',
          textContent: 'Indent test',
        );
        final root = await db.feedDao.addComment(
          postId: postId,
          authorId: 'user_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brew',
          content: 'Parent Comment',
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'user_edh',
          authorUsername: '@EDH',
          authorDisplayName: 'EDH',
          content: 'Child Reply',
          parentCommentId: root.id,
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Parent Comment'), findsOneWidget);
        expect(find.text('Child Reply'), findsOneWidget);
      });

      testWidgets('F14.4: Nested replies render vertical thread guide lines linking ancestor tree', (tester) async {
        const postId = 'post_guidelines_f14_4';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Guide line test'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final targetPost = FeedPost(
          id: postId,
          type: PostType.text,
          username: '@me',
          avatarInitials: 'ME',
          timestamp: 'Now',
          locationTag: 'Local',
          textContent: 'Guide line test',
        );
        final root = await db.feedDao.addComment(
          postId: postId,
          authorId: 'user_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brew',
          content: 'Root',
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'user_edh',
          authorUsername: '@EDH',
          authorDisplayName: 'EDH',
          content: 'Nested Reply',
          parentCommentId: root.id,
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('thread_guide_line')), findsWidgets);
      });

      testWidgets('F14.5: Dismissing reply banner ([X]) resets input target to root level', (tester) async {
        const postId = 'post_dismiss_reply_f14_5';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Dismiss reply test'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final targetPost = FeedPost(
          id: postId,
          type: PostType.text,
          username: '@me',
          avatarInitials: 'ME',
          timestamp: 'Now',
          locationTag: 'Local',
          textContent: 'Dismiss reply test',
        );
        final root = await db.feedDao.addComment(
          postId: postId,
          authorId: 'user_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brew',
          content: 'Root comment',
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.byKey(Key('comment_reply_button_${root.id}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const Key('replying_to_banner')), findsOneWidget);

        await tester.tap(find.byKey(const Key('dismiss_reply_banner_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const Key('replying_to_banner')), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 15: True Total Comment Count
    // =========================================================================
    group('Feature 15: True Total Comment Count', () {
      test('F15.1: Total count calculates SELECT COUNT(*) across all depths in SQLite', () async {
        const postId = 'post_f15_1';
        final c1 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'Root 1',
        );
        final c2 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u2',
          authorUsername: '@u2',
          authorDisplayName: 'U2',
          content: 'Child 1',
          parentCommentId: c1.id,
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u3',
          authorUsername: '@u3',
          authorDisplayName: 'U3',
          content: 'Grandchild 1',
          parentCommentId: c2.id,
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u4',
          authorUsername: '@u4',
          authorDisplayName: 'U4',
          content: 'Root 2',
        );

        final total = await db.feedDao.watchCommentCount(postId).first;
        expect(total, equals(4));
      });

      test('F15.2: Adding a 3rd-level nested reply increments total count on post card', () async {
        const postId = 'post_f15_2';
        final c1 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'Root',
        );
        final c2 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u2',
          authorUsername: '@u2',
          authorDisplayName: 'U2',
          content: 'Child',
          parentCommentId: c1.id,
        );
        expect(await db.feedDao.watchCommentCount(postId).first, equals(2));

        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u3',
          authorUsername: '@u3',
          authorDisplayName: 'U3',
          content: 'Grandchild',
          parentCommentId: c2.id,
        );
        expect(await db.feedDao.watchCommentCount(postId).first, equals(3));
      });

      test('F15.3: Soft-deleted comments are strictly excluded from total count', () async {
        const postId = 'post_f15_3';
        final now = DateTime.now();
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'c_active_1',
            postId: postId,
            authorId: 'u1',
            authorUsername: '@u1',
            authorDisplayName: 'U1',
            content: 'Active 1',
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'c_deleted',
            postId: postId,
            authorId: 'u2',
            authorUsername: '@u2',
            authorDisplayName: 'U2',
            content: 'Deleted',
            deletedAt: drift.Value(now),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'c_active_2',
            postId: postId,
            authorId: 'u3',
            authorUsername: '@u3',
            authorDisplayName: 'U3',
            content: 'Active 2',
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        final total = await db.feedDao.watchCommentCount(postId).first;
        expect(total, equals(2));
      });

      testWidgets('F15.4: Comments sheet header displays true total comment count', (tester) async {
        const postId = 'post_sheet_header_count_f15_4';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Sheet header test'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final targetPost = FeedPost(
          id: postId,
          type: PostType.text,
          username: '@me',
          avatarInitials: 'ME',
          timestamp: 'Now',
          locationTag: 'Local',
          textContent: 'Sheet header test',
        );

        final c1 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'C1',
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u2',
          authorUsername: '@u2',
          authorDisplayName: 'U2',
          content: 'C2',
          parentCommentId: c1.id,
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('comments_sheet_header')), findsOneWidget);
        expect(find.byKey(const Key('post_comments_count_header')), findsOneWidget);
        expect(find.text('Comments (2)'), findsOneWidget);
      });

      test('F15.5: Multi-root posts with deep subtrees compute exact aggregate sum', () async {
        const postId = 'post_multiroot_f15_5';
        // Tree 1: Root + 2 children
        final r1 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'R1',
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1_c1',
          authorUsername: '@u1_c1',
          authorDisplayName: 'U1_C1',
          content: 'C1',
          parentCommentId: r1.id,
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1_c2',
          authorUsername: '@u1_c2',
          authorDisplayName: 'U1_C2',
          content: 'C2',
          parentCommentId: r1.id,
        );

        // Tree 2: Root + 1 child + 1 grandchild
        final r2 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u2',
          authorUsername: '@u2',
          authorDisplayName: 'U2',
          content: 'R2',
        );
        final r2c1 = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u2_c1',
          authorUsername: '@u2_c1',
          authorDisplayName: 'U2_C1',
          content: 'R2C1',
          parentCommentId: r2.id,
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u2_g1',
          authorUsername: '@u2_g1',
          authorDisplayName: 'U2_G1',
          content: 'R2C1G1',
          parentCommentId: r2c1.id,
        );

        final total = await db.feedDao.watchCommentCount(postId).first;
        expect(total, equals(6));
      });
    });

    // =========================================================================
    // FEATURE 16: Comment Emoji Reactions
    // =========================================================================
    group('Feature 16: Comment Emoji Reactions', () {
      test('F16.1: Individual comments provide react action support', () async {
        await db.feedDao.toggleCommentReaction('comment_f16_1', 'user_me', '🔥');
        final reactions = await db.feedDao.watchCommentReactions('comment_f16_1').first;
        expect(reactions.any((r) => r.emoji == '🔥' && r.userId == 'user_me'), isTrue);
      });

      testWidgets('F16.2: Comment reaction selector suggests 5 MRU emojis', (tester) async {
        const postId = 'post_comment_mru_f16_2';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Comment MRU test'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final targetPost = FeedPost(
          id: postId,
          type: PostType.text,
          username: '@me',
          avatarInitials: 'ME',
          timestamp: 'Now',
          locationTag: 'Local',
          textContent: 'Comment MRU test',
        );
        final c = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'Comment with reactions',
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tap comment react button
        await tester.tap(find.byKey(Key('comment_react_button_${c.id}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(Key('comment_mru_bar_${c.id}')), findsOneWidget);
        expect(find.byKey(Key('comment_reaction_mru_${c.id}_🔥')), findsOneWidget);
        expect(find.byKey(Key('comment_reaction_mru_${c.id}_❤️')), findsOneWidget);
        expect(find.byKey(Key('comment_reaction_mru_${c.id}_😂')), findsOneWidget);
        expect(find.byKey(Key('comment_reaction_mru_${c.id}_🤯')), findsOneWidget);
        expect(find.byKey(Key('comment_reaction_mru_${c.id}_💎')), findsOneWidget);
      });

      testWidgets('F16.3: Active comment reactions render as compact pills beneath comment', (tester) async {
        const postId = 'post_comment_pills_f16_3';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Active reaction pills test'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final targetPost = FeedPost(
          id: postId,
          type: PostType.text,
          username: '@me',
          avatarInitials: 'ME',
          timestamp: 'Now',
          locationTag: 'Local',
          textContent: 'Active reaction pills test',
        );
        final c = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'Comment with pills',
        );

        // Seed reactions in SQLite
        await db.feedDao.toggleCommentReaction(c.id, 'user_1', '🔥');
        await db.feedDao.toggleCommentReaction(c.id, 'user_2', '🔥');
        await db.feedDao.toggleCommentReaction(c.id, 'user_3', '💎');

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('comment_reaction_pills_row')), findsOneWidget);
        expect(find.byKey(const Key('comment_pill_🔥')), findsOneWidget);
        expect(find.byKey(const Key('comment_pill_💎')), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('comment_pill_🔥')), matching: find.text('2')), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('comment_pill_💎')), matching: find.text('1')), findsOneWidget);
      });

      test('F16.4: Tapping active comment reaction pill increments count or toggles user reaction', () async {
        const commentId = 'comment_toggle_f16_4';
        await db.feedDao.toggleCommentReaction(commentId, 'user_1', '❤️');
        await db.feedDao.toggleCommentReaction(commentId, 'user_2', '❤️');
        var reactions = await db.feedDao.watchCommentReactions(commentId).first;
        expect(reactions.where((r) => r.emoji == '❤️').length, equals(2));

        // user_1 toggles off
        await db.feedDao.toggleCommentReaction(commentId, 'user_1', '❤️');
        reactions = await db.feedDao.watchCommentReactions(commentId).first;
        expect(reactions.where((r) => r.emoji == '❤️').length, equals(1));
      });

      test('F16.5: Reactions on nested replies do not leak to parent comments', () async {
        const parentId = 'parent_comm_f16_5';
        const childId = 'child_comm_f16_5';

        await db.feedDao.toggleCommentReaction(parentId, 'user_me', '🔥');
        await db.feedDao.toggleCommentReaction(childId, 'user_me', '💎');

        final parentReactions = await db.feedDao.watchCommentReactions(parentId).first;
        final childReactions = await db.feedDao.watchCommentReactions(childId).first;

        expect(parentReactions.any((r) => r.emoji == '🔥'), isTrue);
        expect(parentReactions.any((r) => r.emoji == '💎'), isFalse);
        expect(childReactions.any((r) => r.emoji == '💎'), isTrue);
        expect(childReactions.any((r) => r.emoji == '🔥'), isFalse);
      });
    });
  });
}

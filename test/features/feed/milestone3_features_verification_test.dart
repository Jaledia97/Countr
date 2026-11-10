// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive verification test suite for Milestone 3:
// - Feature 9: Icons-Only Post Action Bar
// - Feature 10: Reddit-Style Upvote/Downvote Pill
// - Feature 11: Post Emoji Reactions & 5 MRU Suggestions Bar
// - Feature 12: Post Header '⋮' Menu & MultiCardWishlistDrawer
// - Feature 13: Morphing Command Center Saved Posts Dropdown & SavedPostsScreen
// - Feature 14: Deep Nested Comments Tree & Reply Banner
// - Feature 15: True Total Comment Count across All Nesting Depths
// - Feature 16: Comment Emoji Reactions & Live Profile Sync

import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/domain/models/post_comment.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/screens/saved_posts_screen.dart';
import 'package:countr/features/feed/presentation/widgets/multi_card_wishlist_drawer.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_comments_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SocialSeedService seedService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    await (db.update(db.userProfiles)).write(
      const UserProfilesCompanion(avatarUrl: Value(null)),
    );
    seedService = SocialSeedService(db);
    await seedService.seedSocialData();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithScope({
    required Widget child,
    String currentUserId = 'user-current-me',
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        feedDaoProvider.overrideWithValue(db.feedDao),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Milestone 3 - Feature 9: Icons-Only Post Action Bar', () {
    testWidgets('Strips all text labels and presents clean icon-first action bar', (tester) async {
      await tester.pumpWidget(wrapWithScope(
        child: const PostActionBar(
          postId: 'post-test-1',
          initialNetScore: 42,
          commentCount: 5,
        ),
      ));
      await tester.pumpAndSettle();

      // Verified icons-only bar exists
      expect(find.byKey(const Key('icons_only_post_action_bar')), findsOneWidget);

      // Verify no Title Case textual action labels
      expect(find.text('Hype'), findsNothing);
      expect(find.text('Like'), findsNothing);
      expect(find.text('Comment'), findsNothing);
      expect(find.text('Share'), findsNothing);

      // Verify primary action elements are present
      expect(find.byKey(const Key('post_upvote_button')), findsOneWidget);
      expect(find.byKey(const Key('post_downvote_button')), findsOneWidget);
      expect(find.byKey(const Key('post_net_score_text')), findsOneWidget);
      expect(find.byKey(const Key('post_comment_button')), findsOneWidget);
      expect(find.byKey(const Key('post_comment_counter_text')), findsOneWidget);
      expect(find.byKey(const Key('post_action_react_button')), findsOneWidget);

      // Verify numeric counter is rendered
      expect(find.text('5'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });
  });

  group('Milestone 3 - Feature 10: Reddit-Style Voting Pill', () {
    testWidgets('Toggling upvote applies orange accent and updates score', (tester) async {
      int? changedVote;
      await tester.pumpWidget(wrapWithScope(
        child: PostActionBar(
          postId: 'post-vote-test',
          initialNetScore: 10,
          commentCount: 0,
          onVoteChanged: (v) => changedVote = v,
        ),
      ));
      await tester.pumpAndSettle();

      // Initial state: Net score 10
      expect(find.text('10'), findsOneWidget);

      // Tap Upvote
      await tester.tap(find.byKey(const Key('post_upvote_button')));
      await tester.pumpAndSettle();

      expect(changedVote, equals(1));
      expect(find.text('11'), findsOneWidget);

      // Verify orange accent color on text (0xFFFF4500)
      final scoreText = tester.widget<Text>(find.byKey(const Key('post_net_score_text')));
      expect(scoreText.style?.color, equals(const Color(0xFFFF4500)));

      // Tap Upvote again to toggle off
      await tester.tap(find.byKey(const Key('post_upvote_button')));
      await tester.pumpAndSettle();

      expect(changedVote, equals(0));
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('Toggling downvote applies blue accent and updates score', (tester) async {
      int? changedVote;
      await tester.pumpWidget(wrapWithScope(
        child: PostActionBar(
          postId: 'post-vote-test-2',
          initialNetScore: 5,
          commentCount: 0,
          onVoteChanged: (v) => changedVote = v,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Downvote
      await tester.tap(find.byKey(const Key('post_downvote_button')));
      await tester.pumpAndSettle();

      expect(changedVote, equals(-1));
      expect(find.text('4'), findsOneWidget);

      // Verify blue accent color on text (0xFF7193FF)
      final scoreText = tester.widget<Text>(find.byKey(const Key('post_net_score_text')));
      expect(scoreText.style?.color, equals(const Color(0xFF7193FF)));
    });

    test('FeedDao persists votes and computes net score accurately in SQLite', () async {
      const postId = 'db-vote-post-1';
      final now = DateTime.now();
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-author-1',
          authorUsername: '@author_1',
          authorDisplayName: 'Author One',
          type: 'text',
          textContent: const Value('Testing votes in SQLite'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Vote +1 from user A
      await db.feedDao.votePost(postId, 'user-a', 1);
      var netScore = await db.feedDao.watchPostNetScore(postId).first;
      var userVote = await db.feedDao.getUserPostVote(postId, 'user-a');
      expect(netScore, equals(1));
      expect(userVote, equals(1));

      // Vote +1 from user B
      await db.feedDao.votePost(postId, 'user-b', 1);
      netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(2));

      // Vote -1 from user C
      await db.feedDao.votePost(postId, 'user-c', -1);
      netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(1));

      // User A changes vote from +1 to -1
      await db.feedDao.votePost(postId, 'user-a', -1);
      netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(-1)); // -1 from A, +1 from B, -1 from C = -1
    });
  });

  group('Milestone 3 - Feature 11: Post Emoji Reactions & MRU Suggestions Bar', () {
    testWidgets('Tapping react button reveals 5 MRU suggestions bar with default emojis', (tester) async {
      await tester.pumpWidget(wrapWithScope(
        child: const PostActionBar(
          postId: 'post-mru-test',
          initialNetScore: 0,
          commentCount: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // MRU bar initially hidden
      expect(find.byKey(const Key('reaction_mru_selector')), findsNothing);

      // Tap react button
      await tester.tap(find.byKey(const Key('post_action_react_button')));
      await tester.pumpAndSettle();

      // MRU bar appears
      expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);

      // Default MRU emojis
      expect(find.byKey(const Key('mru_emoji_🔥')), findsOneWidget);
      expect(find.byKey(const Key('mru_emoji_❤️')), findsOneWidget);
      expect(find.byKey(const Key('mru_emoji_😂')), findsOneWidget);
      expect(find.byKey(const Key('mru_emoji_🤯')), findsOneWidget);
      expect(find.byKey(const Key('mru_emoji_💎')), findsOneWidget);
      expect(find.byKey(const Key('mru_full_picker_button')), findsOneWidget);
    });

    testWidgets('Selecting emoji displays active reaction pill and reorders MRU', (tester) async {
      String? selectedEmoji;
      await tester.pumpWidget(wrapWithScope(
        child: PostActionBar(
          postId: 'post-reaction-test',
          initialNetScore: 0,
          commentCount: 0,
          onReactionSelected: (e) => selectedEmoji = e,
        ),
      ));
      await tester.pumpAndSettle();

      // Open MRU bar
      await tester.tap(find.byKey(const Key('post_action_react_button')));
      await tester.pumpAndSettle();

      // Select fire emoji
      await tester.tap(find.byKey(const Key('mru_emoji_🔥')));
      await tester.pumpAndSettle();

      expect(selectedEmoji, equals('🔥'));

      // Active pill appears above bar
      expect(find.byKey(const Key('active_reaction_pills_row')), findsOneWidget);
      expect(find.byKey(const Key('reaction_pill_🔥')), findsOneWidget);
      expect(find.text('🔥 1'), findsOneWidget);

      // Tapping pill again toggles reaction off
      await tester.tap(find.byKey(const Key('reaction_pill_🔥')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reaction_pill_🔥')), findsNothing);
    });
  });

  group('Milestone 3 - Feature 12: Post Header Overflow Menu & MultiCardWishlistDrawer', () {
    testWidgets('Single-card post header menu presents Wishlist Card option', (tester) async {
      final singleCardPost = FeedPost(
        id: 'post-single-card-1',
        type: PostType.singlePull,
        username: '@Collector',
        avatarInitials: 'CO',
        timestamp: '1h ago',
        locationTag: 'Pocket Pod',
        cardId: 'card-black-lotus',
        cardTitle: 'Black Lotus',
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostHeader(
          username: singleCardPost.username,
          avatarInitials: singleCardPost.avatarInitials,
          timestamp: singleCardPost.timestamp,
          locationTag: singleCardPost.locationTag,
          post: singleCardPost,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap overflow menu
      await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post_menu_wishlist_card')), findsOneWidget);
      expect(find.text('Wishlist Card (Add to Looking For)'), findsOneWidget);
    });

    testWidgets('Multi-card post header menu presents Wishlist Cards option', (tester) async {
      final multiCardPost = FeedPost(
        id: 'post-multi-card-1',
        type: PostType.multiPull,
        username: '@PackBreaker',
        avatarInitials: 'PB',
        timestamp: '2h ago',
        locationTag: 'TBS Comics',
        pullCardIds: const ['card-1', 'card-2', 'card-3'],
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostHeader(
          username: multiCardPost.username,
          avatarInitials: multiCardPost.avatarInitials,
          timestamp: multiCardPost.timestamp,
          locationTag: multiCardPost.locationTag,
          post: multiCardPost,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap overflow menu
      await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post_menu_wishlist_cards_drawer')), findsOneWidget);
      expect(find.text('Wishlist Cards'), findsOneWidget);
    });

    testWidgets('Text-only post header menu presents Save Post option', (tester) async {
      final textPost = FeedPost(
        id: 'post-text-only-1',
        type: PostType.text,
        username: '@Storyteller',
        avatarInitials: 'ST',
        timestamp: '3h ago',
        locationTag: 'Local Game Store',
        textContent: 'Great tournament today!',
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostHeader(
          username: textPost.username,
          avatarInitials: textPost.avatarInitials,
          timestamp: textPost.timestamp,
          locationTag: textPost.locationTag,
          post: textPost,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap overflow menu
      await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post_menu_save_post')), findsOneWidget);
      expect(find.text('Save Post'), findsOneWidget);
    });

    testWidgets('MultiCardWishlistDrawer handles Select All and individual card toggles', (tester) async {
      const cardIds = ['c1', 'c2', 'c3'];
      const cardTitles = ['Mox Diamond', 'Lion Eye Diamond', 'Mana Crypt'];

      await tester.pumpWidget(wrapWithScope(
        child: const MultiCardWishlistDrawer(
          cardIds: cardIds,
          cardTitles: cardTitles,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wishlist_drawer_title')), findsOneWidget);
      expect(find.text('Wishlist Cards (3)'), findsOneWidget);

      // Verify Select All checkbox
      expect(find.byKey(const Key('wishlist_drawer_select_all')), findsOneWidget);

      // By default all are selected
      expect(find.text('Add Selected (3) to Looking For'), findsOneWidget);

      // Tap Select All to deselect all
      await tester.tap(find.byKey(const Key('wishlist_drawer_select_all')));
      await tester.pumpAndSettle();

      expect(find.text('Add Selected (0) to Looking For'), findsOneWidget);

      // Tap first card checkbox to select only 1
      await tester.tap(find.byKey(const Key('wishlist_drawer_card_0')));
      await tester.pumpAndSettle();

      expect(find.text('Add Selected (1) to Looking For'), findsOneWidget);
    });
  });

  group('Milestone 3 - Feature 13: Morphing Command Center Saved Posts & SavedPostsScreen', () {
    testWidgets('Profile tile downward chevron reveals Saved Posts row with count badge', (tester) async {
      // Seed 2 saved posts in SQLite
      await db.feedDao.toggleSavePost('post-seed-1', 'user-current-me');
      await db.feedDao.toggleSavePost('post-seed-2', 'user-current-me');

      await tester.pumpWidget(wrapWithScope(
        child: const MorphingCommandCenter(),
      ));
      await tester.pumpAndSettle();

      // Chevron button exists
      expect(find.byKey(const Key('command_center_profile_chevron')), findsOneWidget);

      // Saved posts row is collapsed initially
      expect(find.byKey(const Key('command_center_saved_posts_tile')), findsNothing);

      // Tap chevron to expand
      await tester.tap(find.byKey(const Key('command_center_profile_chevron')));
      await tester.pumpAndSettle();

      // Saved posts tile is revealed
      expect(find.byKey(const Key('command_center_saved_posts_tile')), findsOneWidget);
      expect(find.text('Saved Posts'), findsOneWidget);

      // Count badge displays 2
      expect(find.byKey(const Key('command_center_saved_posts_count_badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('SavedPostsScreen renders empty view when user has no saved posts', (tester) async {
      await tester.pumpWidget(wrapWithScope(
        currentUserId: 'user-with-no-saves',
        child: const SavedPostsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved_posts_screen')), findsOneWidget);
      expect(find.byKey(const Key('saved_posts_title')), findsOneWidget);
      expect(find.byKey(const Key('saved_posts_empty_view')), findsOneWidget);
      expect(find.text('No Saved Posts Yet'), findsOneWidget);
    });
  });

  group('Milestone 3 - Features 14, 15, 16: Nested Comments Tree, True Count & Profile Sync', () {
    test('PostComment model retains parentCommentId faithfully', () {
      final comment = PostComment(
        id: 'child-1',
        postId: 'post-root',
        authorId: 'user-reply',
        authorUsername: '@ReplyUser',
        authorDisplayName: 'Reply User',
        content: 'This is a nested reply',
        createdAt: DateTime.now(),
        parentCommentId: 'parent-root-1',
      );

      expect(comment.parentCommentId, equals('parent-root-1'));

      final copied = comment.copyWith(parentCommentId: 'parent-root-2');
      expect(copied.parentCommentId, equals('parent-root-2'));
    });

    testWidgets('PostCommentsSheet displays vertical guide lines and reply banner', (tester) async {
      const postId = 'post-comments-sheet-tree-test';
      final now = DateTime.now();
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Me',
          type: 'text',
          textContent: const Value('Comments tree test post'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      final targetPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'ME',
        timestamp: 'Just now',
        locationTag: 'Local Store',
        textContent: 'Comments tree test post',
      );

      // Insert root comment and child comment in SQLite
      final rootComment = await db.feedDao.addComment(
        postId: targetPost.id,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Me',
        content: 'Root comment here',
      );
      final childComment = await db.feedDao.addComment(
        postId: targetPost.id,
        authorId: 'user-foil-collector-99',
        authorUsername: '@foil_99',
        authorDisplayName: 'Foil 99',
        content: 'Nested reply here',
        parentCommentId: rootComment.id,
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: targetPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check comments sheet header
      expect(find.byKey(const Key('post_comments_count_header')), findsOneWidget);

      // Vertical thread guide line should be present for child reply
      expect(find.byKey(const Key('thread_guide_line')), findsWidgets);

      // Reply button on child comment
      expect(find.byKey(Key('comment_reply_button_${childComment.id}')), findsOneWidget);

      // Tap reply button
      await tester.tap(find.byKey(Key('comment_reply_button_${childComment.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Replying banner appears
      expect(find.byKey(const Key('replying_to_banner')), findsOneWidget);
      expect(find.textContaining('Replying to'), findsOneWidget);
      expect(find.byKey(const Key('dismiss_reply_banner_button')), findsOneWidget);

      // Dismiss banner
      await tester.tap(find.byKey(const Key('dismiss_reply_banner_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('replying_to_banner')), findsNothing);
    });

    test('True total comment count aggregates root and deeply nested comments across all depths', () async {
      const postId = 'post-deep-tree-test';
      final now = DateTime.now();
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@current_me',
          authorDisplayName: 'Current Me',
          type: 'text',
          textContent: const Value('Testing deep comment counts'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 0 comments
      var count = await db.feedDao.watchCommentCount(postId).first;
      expect(count, equals(0));

      // Level 1: Root comment
      final c1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-a',
        authorUsername: '@user_a',
        authorDisplayName: 'User A',
        content: 'Depth 1',
      );
      count = await db.feedDao.watchCommentCount(postId).first;
      expect(count, equals(1));

      // Level 2: Child comment
      final c2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-b',
        authorUsername: '@user_b',
        authorDisplayName: 'User B',
        content: 'Depth 2',
        parentCommentId: c1.id,
      );
      count = await db.feedDao.watchCommentCount(postId).first;
      expect(count, equals(2));

      // Level 3: Grandchild comment
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-c',
        authorUsername: '@user_c',
        authorDisplayName: 'User C',
        content: 'Depth 3',
        parentCommentId: c2.id,
      );
      count = await db.feedDao.watchCommentCount(postId).first;
      expect(count, equals(3));
    });
  });
}

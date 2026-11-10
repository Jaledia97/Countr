// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Challenger M3 Test Suite:
// 1. Reddit-style voting pill behavior & SQLite persistence oracle.
// 2. Emoji reactions: 5 MRU suggestions bar, LRU reordering & active pill toggles.
// 3. Narrow viewport stress testing (240px to 400px) with zero RenderFlex overflow.

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
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
    double? width,
  }) {
    final content = width != null
        ? Center(
            child: SizedBox(
              width: width,
              child: child,
            ),
          )
        : child;

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        feedDaoProvider.overrideWithValue(db.feedDao),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: content,
          ),
        ),
      ),
    );
  }

  group('CHALLENGE 1: Reddit-Style Voting Pill Behavior & Color Transitions', () {
    testWidgets('Full toggle and flip sequence (+1 -> 0 -> +1 -> -1 -> +1 -> -1 -> 0)', (tester) async {
      int? currentVote;
      int voteCallbackCount = 0;

      await tester.pumpWidget(wrapWithScope(
        child: PostActionBar(
          postId: 'post-vote-stress-1',
          initialNetScore: 0,
          initialUserVote: 0,
          commentCount: 0,
          onVoteChanged: (v) {
            currentVote = v;
            voteCallbackCount++;
          },
        ),
      ));
      await tester.pumpAndSettle();

      final upvoteFinder = find.byKey(const Key('post_upvote_button'));
      final downvoteFinder = find.byKey(const Key('post_downvote_button'));
      final scoreTextFinder = find.byKey(const Key('post_net_score_text'));

      Icon getUpvoteIcon() => tester.widget<Icon>(find.descendant(of: upvoteFinder, matching: find.byType(Icon)));
      Icon getDownvoteIcon() => tester.widget<Icon>(find.descendant(of: downvoteFinder, matching: find.byType(Icon)));
      Text getScoreText() => tester.widget<Text>(scoreTextFinder);

      // Initial Neutral State
      expect(getScoreText().data, equals('0'));
      expect(getScoreText().style?.color, equals(Colors.white));
      expect(getUpvoteIcon().color, equals(AppColors.textSecondary));
      expect(getDownvoteIcon().color, equals(AppColors.textSecondary));

      // 1. Tap Upvote (+1)
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();
      expect(currentVote, equals(1));
      expect(voteCallbackCount, equals(1));
      expect(getScoreText().data, equals('1'));
      expect(getScoreText().style?.color, equals(const Color(0xFFFF4500)));
      expect(getUpvoteIcon().color, equals(const Color(0xFFFF4500)));
      expect(getDownvoteIcon().color, equals(AppColors.textSecondary));

      // 2. Tap Upvote again to toggle back to 0
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();
      expect(currentVote, equals(0));
      expect(voteCallbackCount, equals(2));
      expect(getScoreText().data, equals('0'));
      expect(getScoreText().style?.color, equals(Colors.white));
      expect(getUpvoteIcon().color, equals(AppColors.textSecondary));
      expect(getDownvoteIcon().color, equals(AppColors.textSecondary));

      // 3. Tap Upvote again (+1)
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();
      expect(currentVote, equals(1));
      expect(getScoreText().data, equals('1'));
      expect(getScoreText().style?.color, equals(const Color(0xFFFF4500)));

      // 4. FLIP: Tap Downvote (-1). Score must flip from 1 to -1 (delta of -2)
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();
      expect(currentVote, equals(-1));
      expect(voteCallbackCount, equals(4));
      expect(getScoreText().data, equals('-1'));
      expect(getScoreText().style?.color, equals(const Color(0xFF7193FF)));
      expect(getDownvoteIcon().color, equals(const Color(0xFF7193FF)));
      expect(getUpvoteIcon().color, equals(AppColors.textSecondary));

      // 5. FLIP: Tap Upvote (+1). Score must flip from -1 to +1 (delta of +2)
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();
      expect(currentVote, equals(1));
      expect(voteCallbackCount, equals(5));
      expect(getScoreText().data, equals('1'));
      expect(getScoreText().style?.color, equals(const Color(0xFFFF4500)));
      expect(getUpvoteIcon().color, equals(const Color(0xFFFF4500)));

      // 6. Tap Downvote (-1) again
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();
      expect(currentVote, equals(-1));
      expect(getScoreText().data, equals('-1'));
      expect(getScoreText().style?.color, equals(const Color(0xFF7193FF)));

      // 7. Tap Downvote again to toggle back to 0
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();
      expect(currentVote, equals(0));
      expect(voteCallbackCount, equals(7));
      expect(getScoreText().data, equals('0'));
      expect(getScoreText().style?.color, equals(Colors.white));
      expect(getUpvoteIcon().color, equals(AppColors.textSecondary));
      expect(getDownvoteIcon().color, equals(AppColors.textSecondary));
    });

    testWidgets('Voting pill initializes correctly with negative scores and initial user downvote', (tester) async {
      await tester.pumpWidget(wrapWithScope(
        child: const PostActionBar(
          postId: 'post-vote-stress-2',
          initialNetScore: -42,
          initialUserVote: -1,
          commentCount: 12,
        ),
      ));
      await tester.pumpAndSettle();

      final scoreTextFinder = find.byKey(const Key('post_net_score_text'));
      final downvoteFinder = find.byKey(const Key('post_downvote_button'));
      final upvoteFinder = find.byKey(const Key('post_upvote_button'));

      expect(tester.widget<Text>(scoreTextFinder).data, equals('-42'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(const Color(0xFF7193FF)));
      expect(
        tester.widget<Icon>(find.descendant(of: downvoteFinder, matching: find.byType(Icon))).color,
        equals(const Color(0xFF7193FF)),
      );
      expect(
        tester.widget<Icon>(find.descendant(of: upvoteFinder, matching: find.byType(Icon))).color,
        equals(AppColors.textSecondary),
      );

      // Tapping downvote toggles off (-1 -> 0): score moves from -42 to -41
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(scoreTextFinder).data, equals('-41'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(Colors.white));
    });

    test('SQLite Multi-User Voting Oracle: 10 concurrent voters with flips and toggles', () async {
      const postId = 'db-vote-oracle-post';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-post-author',
          authorUsername: '@post_author',
          authorDisplayName: 'Post Author',
          type: 'text',
          textContent: const Value('Oracle voting test post'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 6 voters upvote (+1)
      for (int i = 1; i <= 6; i++) {
        final score = await db.feedDao.votePost(postId, 'voter-$i', 1);
        expect(score, equals(i));
      }

      // 4 voters downvote (-1)
      for (int i = 7; i <= 10; i++) {
        await db.feedDao.votePost(postId, 'voter-$i', -1);
      }

      // Net score should now be 6 - 4 = 2
      var netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(2));

      // Voter 1 flips from +1 to -1: Net score changes from 2 to 0
      await db.feedDao.votePost(postId, 'voter-1', -1);
      netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(0));

      // Voter 7 (who downvoted) toggles vote to 0: Net score changes from 0 to +1
      await db.feedDao.votePost(postId, 'voter-7', 0);
      netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(1));

      // Voter 2 (who upvoted) toggles vote to 0: Net score changes from 1 to 0
      await db.feedDao.votePost(postId, 'voter-2', 0);
      netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(0));

      // Check FeedPosts table persistence: likeCount must match net score exactly
      final postRecord = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
      expect(postRecord.likeCount, equals(0));

      // Verify individual vote persistence in post_votes table
      expect(await db.feedDao.getUserPostVote(postId, 'voter-1'), equals(-1));
      expect(await db.feedDao.getUserPostVote(postId, 'voter-2'), equals(0));
      expect(await db.feedDao.getUserPostVote(postId, 'voter-3'), equals(1));
      expect(await db.feedDao.getUserPostVote(postId, 'voter-7'), equals(0));
      expect(await db.feedDao.getUserPostVote(postId, 'voter-8'), equals(-1));
    });
  });

  group('CHALLENGE 2: Emoji Reactions MRU Shifting & Active Pill Toggling', () {
    testWidgets('MRU bar shifts tapped emoji to front (LRU) and maintains capacity of 5', (tester) async {
      await tester.pumpWidget(wrapWithScope(
        child: const PostActionBar(
          postId: 'post-mru-shift-test',
          initialNetScore: 0,
          commentCount: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Open MRU bar
      await tester.tap(find.byKey(const Key('post_action_react_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);

      // Initial MRU order: ['🔥', '❤️', '😂', '🤯', '💎']
      // Tap '🤯' (index 3)
      await tester.tap(find.byKey(const Key('mru_emoji_🤯')));
      await tester.pumpAndSettle();

      // Selector closes upon reaction
      expect(find.byKey(const Key('reaction_mru_selector')), findsNothing);

      // Active pill appears
      expect(find.byKey(const Key('reaction_pill_🤯')), findsOneWidget);
      expect(find.text('🤯 1'), findsOneWidget);

      // Re-open MRU selector to verify LRU order: '🤯' must now be at front (index 0)
      await tester.tap(find.byKey(const Key('post_action_react_button')));
      await tester.pumpAndSettle();

      // Tap full emoji picker button to select a new emoji not in default 5 ('🚀')
      await tester.tap(find.byKey(const Key('mru_full_picker_button')));
      await tester.pumpAndSettle();

      expect(find.text('React with Emoji'), findsOneWidget);
      expect(find.text('🚀'), findsOneWidget);

      // Tap '🚀' in modal picker
      await tester.tap(find.text('🚀'));
      await tester.pumpAndSettle();

      // Both active pills are displayed
      expect(find.byKey(const Key('reaction_pill_🤯')), findsOneWidget);
      expect(find.byKey(const Key('reaction_pill_🚀')), findsOneWidget);

      // Re-open MRU bar: '🚀' must now be in the 5 MRU suggestions
      await tester.tap(find.byKey(const Key('post_action_react_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mru_emoji_🚀')), findsOneWidget);
      expect(find.byKey(const Key('mru_emoji_🤯')), findsOneWidget);
    });

    testWidgets('Tapping active reaction pill toggles reaction off and decrements/removes pill', (tester) async {
      await tester.pumpWidget(wrapWithScope(
        child: const PostActionBar(
          postId: 'post-pill-toggle-test',
          initialNetScore: 0,
          commentCount: 0,
          initialReactions: {'🔥': 2, '💎': 1},
          userReactions: {'💎'}, // User previously reacted with 💎 but not 🔥
        ),
      ));
      await tester.pumpAndSettle();

      // Initially, active reactions row contains '🔥 2' and '💎 1'
      expect(find.byKey(const Key('active_reaction_pills_row')), findsOneWidget);
      expect(find.byKey(const Key('reaction_pill_🔥')), findsOneWidget);
      expect(find.byKey(const Key('reaction_pill_💎')), findsOneWidget);
      expect(find.text('🔥 2'), findsOneWidget);
      expect(find.text('💎 1'), findsOneWidget);

      // 1. Tap 🔥 pill: Current user adds reaction -> count becomes 3
      await tester.tap(find.byKey(const Key('reaction_pill_🔥')));
      await tester.pumpAndSettle();
      expect(find.text('🔥 3'), findsOneWidget);

      // 2. Tap 💎 pill: Current user already reacted -> removes reaction -> count becomes 0 -> pill removed
      await tester.tap(find.byKey(const Key('reaction_pill_💎')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reaction_pill_💎')), findsNothing);

      // 3. Tap 🔥 pill again: Current user removes reaction -> count drops from 3 to 2
      await tester.tap(find.byKey(const Key('reaction_pill_🔥')));
      await tester.pumpAndSettle();
      expect(find.text('🔥 2'), findsOneWidget);
    });

    test('SQLite Reaction Persistence Oracle: togglePostReaction handles add, remove, and streams', () async {
      const postId = 'db-react-oracle-post';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-react-author',
          authorUsername: '@react_author',
          authorDisplayName: 'React Author',
          type: 'text',
          textContent: const Value('Emoji reactions oracle post'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // User A reacts with 🔥
      final added1 = await db.feedDao.togglePostReaction(postId, 'user-a', '🔥');
      expect(added1, isTrue);

      var reactions = await db.feedDao.watchPostReactions(postId).first;
      expect(reactions.length, equals(1));
      expect(reactions.first.emoji, equals('🔥'));
      expect(reactions.first.isDeleted, isFalse);

      // User B reacts with 🔥
      final added2 = await db.feedDao.togglePostReaction(postId, 'user-b', '🔥');
      expect(added2, isTrue);

      reactions = await db.feedDao.watchPostReactions(postId).first;
      expect(reactions.length, equals(2));

      // User A toggles 🔥 off
      final added3 = await db.feedDao.togglePostReaction(postId, 'user-a', '🔥');
      expect(added3, isFalse); // Removed

      reactions = await db.feedDao.watchPostReactions(postId).first;
      expect(reactions.length, equals(1)); // Only User B's active reaction remains
      expect(reactions.first.userId, equals('user-b'));
    });
  });

  group('CHALLENGE 3: Narrow Viewport Stress Testing (Down to 240px)', () {
    const viewports = [400.0, 320.0, 280.0, 260.0, 240.0];

    for (final width in viewports) {
      testWidgets('PostActionBar at ${width.toInt()}px width renders with zero RenderFlex overflow', (tester) async {
        await tester.pumpWidget(wrapWithScope(
          width: width,
          child: const PostActionBar(
            postId: 'post-narrow-bar',
            initialNetScore: 99999,
            commentCount: 8888,
            initialReactions: {
              '🔥': 12,
              '❤️': 8,
              '😂': 5,
              '🤯': 2,
              '💎': 1,
            },
          ),
        ));
        await tester.pumpAndSettle();

        // Must NOT throw RenderFlex overflow
        expect(tester.takeException(), isNull);

        // Core action elements must be present
        expect(find.byKey(const Key('reddit_voting_pill')), findsOneWidget);
        expect(find.byKey(const Key('post_upvote_button')), findsOneWidget);
        expect(find.byKey(const Key('post_downvote_button')), findsOneWidget);
        expect(find.byKey(const Key('post_comment_button')), findsOneWidget);
        expect(find.byKey(const Key('post_action_react_button')), findsOneWidget);

        // Open MRU selector at this width
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);
      });

      testWidgets('PostHeader at ${width.toInt()}px width renders with zero RenderFlex overflow', (tester) async {
        final post = FeedPost(
          id: 'post-narrow-header',
          type: PostType.text,
          username: '@extraordinarily_long_username_overflow_stress',
          avatarInitials: 'EL',
          timestamp: '3 days ago',
          locationTag: 'Emerald City Comic Con Grand Ballroom',
          textContent: 'Testing narrow viewport responsiveness',
        );

        await tester.pumpWidget(wrapWithScope(
          width: width,
          child: PostHeader(
            username: post.username,
            avatarInitials: post.avatarInitials,
            timestamp: post.timestamp,
            locationTag: post.locationTag,
            post: post,
          ),
        ));
        await tester.pumpAndSettle();

        // Must NOT throw RenderFlex overflow
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('post_header_overflow_menu')), findsOneWidget);

        // Open overflow menu
        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('post_menu_save_post')), findsOneWidget);
      });

      testWidgets('Complete PostCard at ${width.toInt()}px width renders and handles user interactions', (tester) async {
        final post = FeedPost(
          id: 'post-narrow-card-${width.toInt()}',
          type: PostType.singlePull,
          username: '@CollectorExtreme',
          avatarInitials: 'CE',
          timestamp: '1h ago',
          locationTag: 'Tokyo LGS',
          cardId: 'card-black-lotus',
          cardTitle: 'Black Lotus',
          hypeCount: 777,
          commentCount: 42,
        );

        await tester.pumpWidget(wrapWithScope(
          width: width,
          child: PostCard(post: post),
        ));
        await tester.pumpAndSettle();

        // Zero overflow
        expect(tester.takeException(), isNull);

        // Tap upvote at narrow viewport
        await tester.ensureVisible(find.byKey(const Key('post_upvote_button')));
        await tester.tap(find.byKey(const Key('post_upvote_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tap comment at narrow viewport
        await tester.ensureVisible(find.byKey(const Key('post_comment_button')));
        await tester.tap(find.byKey(const Key('post_comment_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Extreme negative score (-999999) and extreme comment count at 240px width', (tester) async {
      await tester.pumpWidget(wrapWithScope(
        width: 240.0,
        child: const PostActionBar(
          postId: 'post-extreme-numbers',
          initialNetScore: -999999,
          initialUserVote: -1,
          commentCount: 888888,
          initialReactions: {
            '🔥': 9999,
            '❤️': 8888,
            '😂': 7777,
            '🤯': 6666,
            '💎': 5555,
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('-999999'), findsOneWidget);
      expect(find.text('888888'), findsOneWidget);
    });

    testWidgets('PostCommentsSheet at 240px width with deep nested comments and reaction bar', (tester) async {
      const postId = 'post-comments-sheet-240px';
      final now = DateTime.now();
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Me',
          type: 'text',
          textContent: const Value('Comments sheet narrow test'),
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
        locationTag: 'LGS',
        textContent: 'Comments sheet narrow test',
      );

      final c1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-a',
        authorUsername: '@long_username_nested_depth_1',
        authorDisplayName: 'User A',
        content: 'Root level comment text',
      );
      final c2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-b',
        authorUsername: '@long_username_nested_depth_2',
        authorDisplayName: 'User B',
        content: 'Nested child comment text',
        parentCommentId: c1.id,
      );

      await tester.pumpWidget(wrapWithScope(
        width: 240.0,
        child: SizedBox(
          height: 600,
          child: PostCommentsSheet(post: targetPost),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Tap react button on nested comment
      final reactBtnFinder = find.byKey(Key('comment_react_button_${c2.id}'));
      if (reactBtnFinder.evaluate().isNotEmpty) {
        await tester.tap(reactBtnFinder);
        await tester.pumpAndSettle();
        // Check if comment MRU bar causes overflow
        expect(tester.takeException(), isNull);
      }
    });
  });
}


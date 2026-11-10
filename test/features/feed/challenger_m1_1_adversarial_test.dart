// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Empirical Challenge Test Suite for Milestone 1 (F1–F4):
// 1. Verify that `post_comments` rows in SQLite strictly equal `post.commentCount` for every seeded post.
// 2. Verify that adding a comment through `FeedDao.addComment` immediately updates the stream returned by `watchCommentCount(postId)`.
// 3. Verify that `PostHeader` does NOT render the initial bubble letters when `avatarUrl` is populated.
// 4. Verify that `MultiPullPostBody` with 3 cards renders 3 cards in a side-by-side row and tapping any card invokes `CardDetailSheet.show`.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/presentation/widgets/multi_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

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

  Widget wrapWithHarness({
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        activeGameContextProvider.overrideWith((ref) => 'mtg'),
        vaultShowCatalogProvider.overrideWith((ref) => false),
        vaultSearchQueryProvider.overrideWith((ref) => ''),
        vaultPaginationLimitProvider.overrideWith((ref) => 100),
        vaultIsFetchingMoreProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  // ===========================================================================
  // CHALLENGE 1: SQLite post_comments COUNT(*) strictly equals post.commentCount
  // ===========================================================================
  group('CHALLENGE 1: SQLite post_comments strict parity with post.commentCount', () {
    test('every seeded post in feed_posts has SQLite post_comments count strictly equal to post.commentCount', () async {
      final posts = await db.select(db.feedPosts).get();
      expect(posts, isNotEmpty, reason: 'Database must contain seeded feed posts');

      int totalCommentsInFeedPosts = 0;
      int totalCommentsInSQLiteRows = 0;

      for (final post in posts) {
        // Direct SQLite query for post_comments matching post.id and isDeleted == false
        final countCol = db.postComments.id.count();
        final countRow = await (db.selectOnly(db.postComments)
              ..addColumns([countCol])
              ..where(db.postComments.postId.equals(post.id) & db.postComments.isDeleted.equals(false)))
            .getSingle();
        final int actualRowCount = countRow.read(countCol) ?? 0;

        totalCommentsInFeedPosts += post.commentCount;
        totalCommentsInSQLiteRows += actualRowCount;

        expect(
          actualRowCount,
          equals(post.commentCount),
          reason: 'Post "${post.id}" commentCount (${post.commentCount}) MUST strictly equal SQLite row count ($actualRowCount)',
        );
      }

      // Assert total comments across all posts equals 39
      expect(totalCommentsInFeedPosts, equals(39));
      expect(totalCommentsInSQLiteRows, equals(39));
    });

    test('exact expected counts across all 8 seeded posts are satisfied', () async {
      final expectedPostCounts = <String, int>{
        'post-spicy-pull': 3,
        'post-foil-showcase': 8,
        'post-edh-combo-showcase': 4,
        'post-edh-deck-share': 5,
        'post-media-16-9-pod': 2,
        'post-tbs-fnm-event': 12,
        'post-media-1-1-tournament': 3,
        'post-media-4-5-playmat': 2,
      };

      for (final entry in expectedPostCounts.entries) {
        final postId = entry.key;
        final expectedCount = entry.value;

        final count = await db.feedDao.watchCommentCount(postId).first;
        expect(count, equals(expectedCount),
            reason: 'Post $postId must have exactly $expectedCount comments in SQLite');

        final postRow = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
        expect(postRow.commentCount, equals(expectedCount),
            reason: 'Post row in feed_posts must have commentCount $expectedCount');
      }
    });

    test('soft-deleted comment is excluded from watchCommentCount and true count', () async {
      const targetPostId = 'post-spicy-pull';
      final initialCount = await db.feedDao.watchCommentCount(targetPostId).first;
      expect(initialCount, equals(3));

      // Fetch the first comment for this post and soft delete it
      final firstComment = await (db.select(db.postComments)
            ..where((t) => t.postId.equals(targetPostId))
            ..limit(1))
          .getSingle();

      await (db.update(db.postComments)..where((t) => t.id.equals(firstComment.id))).write(
        const PostCommentsCompanion(isDeleted: Value(true)),
      );

      final countAfterSoftDelete = await db.feedDao.watchCommentCount(targetPostId).first;
      expect(countAfterSoftDelete, equals(2),
          reason: 'watchCommentCount must ignore soft-deleted comments');
    });

    test('new post with 0 comments returns 0 from watchCommentCount', () async {
      const zeroPostId = 'post-zero-comments';
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: zeroPostId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Collector Me',
          type: 'text',
          commentCount: const Value(0),
        ),
      );

      final count = await db.feedDao.watchCommentCount(zeroPostId).first;
      expect(count, equals(0));
    });
  });

  // ===========================================================================
  // CHALLENGE 2: FeedDao.addComment immediate stream reactivity & stress
  // ===========================================================================
  group('CHALLENGE 2: FeedDao.addComment immediate stream reactivity', () {
    test('watchCommentCount stream emits new count immediately after addComment', () async {
      const postId = 'post-media-16-9-pod';
      final stream = db.feedDao.watchCommentCount(postId);

      final emissions = <int>[];
      final subscription = stream.listen((count) => emissions.add(count));
      addTearDown(subscription.cancel);

      // Wait for initial value
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions, equals([2]));

      // Add comment 1
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Collector Me',
        content: 'Reactive test comment 1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions.last, equals(3));

      // Add comment 2
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-spicy-brew-master',
        authorUsername: '@SpicyBrewMaster',
        authorDisplayName: 'Spicy Brew Master',
        content: 'Reactive test comment 2',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions.last, equals(4));

      // Verify feed_posts row was synchronized atomically
      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
      expect(post.commentCount, equals(4));
    });

    test('high concurrency stress test: 10 simultaneous addComment calls maintain strict count consistency', () async {
      const postId = 'post-media-4-5-playmat';
      final initialCount = await db.feedDao.watchCommentCount(postId).first;
      expect(initialCount, equals(2));

      // Fire 10 concurrent additions
      await Future.wait(List.generate(10, (i) {
        return db.feedDao.addComment(
          postId: postId,
          authorId: 'user-concurrent-$i',
          authorUsername: '@user_$i',
          authorDisplayName: 'Concurrent User $i',
          content: 'Concurrent stress comment #$i',
        );
      }));

      final finalCount = await db.feedDao.watchCommentCount(postId).first;
      expect(finalCount, equals(12),
          reason: 'Initial 2 + 10 concurrent adds must result in exactly 12');

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
      expect(post.commentCount, equals(12),
          reason: 'feed_posts.commentCount must synchronize to 12');
    });

    test('adversarial payloads: SQL injection, Unicode, emoji, and large text do not break addComment', () async {
      const postId = 'post-spicy-pull';
      const maliciousContent = "'; DROP TABLE post_comments; SELECT * FROM feed_posts WHERE '1'='1 -- 🔥✨🧙‍♂️\n\nLine 2";

      final commentRecord = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Collector Me',
        content: maliciousContent,
      );

      expect(commentRecord.content, equals(maliciousContent));
      final count = await db.feedDao.watchCommentCount(postId).first;
      expect(count, equals(4));

      // Verify table is intact
      final allComments = await db.select(db.postComments).get();
      expect(allComments, isNotEmpty);
    });

    test('cross-post isolation: comments added to postA do not alter watchCommentCount for postB', () async {
      const postA = 'post-edh-combo-showcase';
      const postB = 'post-media-1-1-tournament';

      final initialCountA = await db.feedDao.watchCommentCount(postA).first;
      final initialCountB = await db.feedDao.watchCommentCount(postB).first;

      await db.feedDao.addComment(
        postId: postA,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Collector Me',
        content: 'Comment isolated to Post A',
      );

      final countA = await db.feedDao.watchCommentCount(postA).first;
      final countB = await db.feedDao.watchCommentCount(postB).first;

      expect(countA, equals(initialCountA + 1));
      expect(countB, equals(initialCountB), reason: 'Post B count must remain unchanged');
    });
  });

  // ===========================================================================
  // CHALLENGE 3: PostHeader zero initial bubbles when avatarUrl is populated
  // ===========================================================================
  group('CHALLENGE 3: PostHeader zero initial bubbles when avatarUrl is populated', () {
    testWidgets('PostHeader mounts CountrCachedImage as direct avatar child when avatarUrl is populated', (tester) async {
      const avatarUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400';
      const initials = 'ERF';

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostHeader(
            username: '@EDH_Rec_Fanatic',
            avatarInitials: initials,
            avatarUrl: avatarUrl,
            timestamp: '3h ago',
            locationTag: 'TBS Comics',
          ),
        ),
      ));
      await tester.pump();

      // CountrCachedImage must be mounted inside ClipOval
      final clipOvalFinder = find.byType(ClipOval);
      expect(clipOvalFinder, findsOneWidget);

      final cachedImageFinder = find.descendant(of: clipOvalFinder, matching: find.byType(CountrCachedImage));
      expect(cachedImageFinder, findsOneWidget,
          reason: 'ClipOval child must be CountrCachedImage when avatarUrl is populated');

      final cachedImage = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(cachedImage.imageUrl, equals(avatarUrl));

      // Direct fallback container must NOT be the child of ClipOval
      final clipOvalWidget = tester.widget<ClipOval>(clipOvalFinder);
      expect(clipOvalWidget.child, isA<CountrCachedImage>(),
          reason: 'ClipOval.child must be CountrCachedImage, NOT the fallback Container with initials');
    });

    testWidgets('all 5 seeded profiles in database have valid avatarUrl and mount CountrCachedImage in PostHeader', (tester) async {
      final profiles = await db.select(db.userProfiles).get();
      expect(profiles.length, equals(5));

      for (final profile in profiles) {
        expect(profile.avatarUrl, isNotNull);
        expect(profile.avatarUrl!.isNotEmpty, isTrue);

        final initials = profile.username.replaceAll('@', '').substring(0, 2).toUpperCase();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PostHeader(
              username: profile.username,
              avatarInitials: initials,
              avatarUrl: profile.avatarUrl,
              timestamp: '1h ago',
              locationTag: profile.storeAddress ?? 'Online',
            ),
          ),
        ));
        await tester.pump();

        final clipOvalFinder = find.byType(ClipOval);
        expect(clipOvalFinder, findsOneWidget);
        final clipOvalWidget = tester.widget<ClipOval>(clipOvalFinder);
        expect(clipOvalWidget.child, isA<CountrCachedImage>(),
            reason: 'User ${profile.username} must mount CountrCachedImage in PostHeader');
      }
    });

    testWidgets('PostHeader renders initial letters fallback ONLY when avatarUrl is null or empty', (tester) async {
      // 1. avatarUrl is null
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostHeader(
            username: '@NoAvatarUser',
            avatarInitials: 'NA',
            avatarUrl: null,
            timestamp: '5m ago',
            locationTag: 'Home',
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('NA'), findsOneWidget);
      expect(find.byType(CountrCachedImage), findsNothing);

      // 2. avatarUrl is empty string ""
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostHeader(
            username: '@EmptyAvatarUser',
            avatarInitials: 'EA',
            avatarUrl: '',
            timestamp: '5m ago',
            locationTag: 'Home',
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('EA'), findsOneWidget);
      expect(find.byType(CountrCachedImage), findsNothing);
    });

    testWidgets('PostHeader handles extreme long username and location tag without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600)); // Narrow viewport

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostHeader(
            username: '@SuperExtremelyLongUsernameThatShouldTruncateGracefully123456789',
            avatarInitials: 'SE',
            avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
            timestamp: 'Just now',
            locationTag: 'PULLED AT The Most Incredibly Detailed And Very Long Named Local Game Store In Fort Walton Beach Florida',
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'Must not trigger RenderFlex overflow');
    });
  });

  // ===========================================================================
  // CHALLENGE 4: MultiPullPostBody 3-card side-by-side row & CardDetailSheet.show
  // ===========================================================================
  group('CHALLENGE 4: MultiPullPostBody 3-card row layout & CardDetailSheet.show invocation', () {
    testWidgets('MultiPullPostBody with 3 cards renders 3 cards in a side-by-side row with 63/88 aspect ratio', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(wrapWithHarness(
        child: const MultiPullPostBody(
          commentary: 'EDH Combo showcase: Urza + Isochron Scepter + Dramatic Reversal',
          pullItems: [
            'Urza, Lord High Artificer',
            'Isochron Scepter',
            'Dramatic Reversal',
          ],
          pullCardIds: [
            'item-card-urza-high-artificer',
            'item-card-isochron-scepter',
            'item-card-dramatic-reversal',
          ],
        ),
      ));
      await tester.pump();

      // 1. GridView must NOT be used for 3 cards
      expect(find.byType(GridView), findsNothing,
          reason: '3-card combo must use Row, not GridView');

      // 2. Exactly 3 AspectRatio cards in Row
      final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio)).toList();
      final cardAspectRatios = aspectRatios
          .where((ar) => (ar.aspectRatio - (63.0 / 88.0)).abs() < 0.001)
          .toList();

      expect(cardAspectRatios.length, equals(3),
          reason: 'Must have exactly 3 cards with aspect ratio 63 / 88');

      // 3. Verify side-by-side Row layout
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget);

      final rowWidget = tester.widget<Row>(rowFinder);
      expect(rowWidget.children.length, equals(3));
      for (final child in rowWidget.children) {
        expect(child, isA<Expanded>(),
            reason: 'Each of the 3 cards in the row must be wrapped in Expanded for equal spacing');
      }
    });

    testWidgets('tapping any card in 3-card MultiPullPostBody invokes CardDetailSheet.show and displays CardDetailSheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(wrapWithHarness(
        child: MultiPullPostBody(
          commentary: 'Tap card to open CardDetailSheet',
          pullItems: const [
            'Urza, Lord High Artificer',
            'Isochron Scepter',
            'Dramatic Reversal',
          ],
          pullCardIds: const [
            'item-card-urza-high-artificer',
            'item-card-isochron-scepter',
            'item-card-dramatic-reversal',
          ],
        ),
      ));
      await tester.pump();

      // CardDetailSheet must not be visible initially
      expect(find.byType(CardDetailSheet), findsNothing);

      // --- Tap Card 0 (Urza) ---
      final card0Finder = find.byKey(const Key('multi_pull_card_0_item-card-urza-high-artificer'));
      expect(card0Finder, findsOneWidget);
      await tester.tap(card0Finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // CardDetailSheet must now be opened!
      expect(find.byType(CardDetailSheet), findsOneWidget,
          reason: 'Tapping card 0 must invoke CardDetailSheet.show and display CardDetailSheet');

      // Dismiss the bottom sheet
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigatorState.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CardDetailSheet), findsNothing);

      // --- Tap Card 1 (Isochron Scepter) ---
      final card1Finder = find.byKey(const Key('multi_pull_card_1_item-card-isochron-scepter'));
      expect(card1Finder, findsOneWidget);
      await tester.tap(card1Finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CardDetailSheet), findsOneWidget,
          reason: 'Tapping card 1 must invoke CardDetailSheet.show and display CardDetailSheet');

      navigatorState.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CardDetailSheet), findsNothing);

      // --- Tap Card 2 (Dramatic Reversal) ---
      final card2Finder = find.byKey(const Key('multi_pull_card_2_item-card-dramatic-reversal'));
      expect(card2Finder, findsOneWidget);
      await tester.tap(card2Finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CardDetailSheet), findsOneWidget,
          reason: 'Tapping card 2 must invoke CardDetailSheet.show and display CardDetailSheet');

      navigatorState.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CardDetailSheet), findsNothing);
    });

    testWidgets('onCardTap callback is invoked with exact index and cardId when provided', (tester) async {
      int? tappedIndex;
      String? tappedCardId;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MultiPullPostBody(
            commentary: 'Testing onCardTap callback dispatch',
            pullItems: const [
              'Urza, Lord High Artificer',
              'Isochron Scepter',
              'Dramatic Reversal',
            ],
            pullCardIds: const [
              'item-card-urza-high-artificer',
              'item-card-isochron-scepter',
              'item-card-dramatic-reversal',
            ],
            onCardTap: (index, cardId) {
              tappedIndex = index;
              tappedCardId = cardId;
            },
          ),
        ),
      ));
      await tester.pump();

      // Tap card 0
      await tester.tap(find.byKey(const Key('multi_pull_card_0_item-card-urza-high-artificer')));
      await tester.pump();
      expect(tappedIndex, equals(0));
      expect(tappedCardId, equals('item-card-urza-high-artificer'));

      // Tap card 1
      await tester.tap(find.byKey(const Key('multi_pull_card_1_item-card-isochron-scepter')));
      await tester.pump();
      expect(tappedIndex, equals(1));
      expect(tappedCardId, equals('item-card-isochron-scepter'));

      // Tap card 2
      await tester.tap(find.byKey(const Key('multi_pull_card_2_item-card-dramatic-reversal')));
      await tester.pump();
      expect(tappedIndex, equals(2));
      expect(tappedCardId, equals('item-card-dramatic-reversal'));
    });

    testWidgets('boundary condition: null pullCardIds falls back to default combo card IDs without error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(wrapWithHarness(
        child: const MultiPullPostBody(
          commentary: 'Null pullCardIds boundary test',
          pullItems: ['Urza', 'Scepter', 'Reversal'],
          pullCardIds: null,
        ),
      ));
      await tester.pump();

      // Should default to fallback IDs and not throw
      final card0Finder = find.byKey(const Key('multi_pull_card_0_item-card-urza-high-artificer'));
      expect(card0Finder, findsOneWidget);

      await tester.tap(card0Finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CardDetailSheet), findsOneWidget);
    });

    testWidgets('ADVERSARIAL STRESS FINDING: CountrCachedImage in MultiPullPostBody without IgnorePointer intercepts taps on image error', (tester) async {
      // When pullItems contains image URLs, _isImageUrl is true, mounting CountrCachedImage.
      // In CountrCachedImage, _buildEffectiveErrorWidget wraps in an opaque GestureDetector with onTap: manualRetry.
      // Without IgnorePointer around CountrCachedImage in MultiPullPostBody, the error widget intercepts
      // the tap and prevents _GridCardPlaceholder.onTap from firing!
      bool cardTapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MultiPullPostBody(
            commentary: 'Stress test image URL tap interception',
            pullItems: const [
              'https://cards.scryfall.io/normal/front/9/e/9e7fb3c0-5159-4d1f-8490-ce4c9a60f567.jpg',
              'https://cards.scryfall.io/normal/front/2/a/2aa24fe0-e275-4307-b26c-2a656068a451.jpg',
              'https://cards.scryfall.io/normal/front/d/c/dcb59045-2743-48ae-8063-727e551b1c41.jpg',
            ],
            onCardTap: (index, cardId) {
              cardTapped = true;
            },
          ),
        ),
      ));
      await tester.pump();

      // Tap card 0
      final card0 = find.byKey(const Key('multi_pull_card_0_item-card-urza-high-artificer'));
      expect(card0, findsOneWidget);
      await tester.tap(card0);
      await tester.pump();

      // Verify cardTapped is TRUE: taps on _GridCardPlaceholder successfully trigger the callback
      expect(cardTapped, isTrue,
          reason: 'Tapping on _GridCardPlaceholder successfully fires the tap callback even with image URLs');
    });

    testWidgets('tapping card with image URL invokes CardDetailSheet.show and displays CardDetailSheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(wrapWithHarness(
        child: const MultiPullPostBody(
          commentary: 'Tap card with image URL to open CardDetailSheet',
          pullItems: [
            'https://cards.scryfall.io/normal/front/9/e/9e7fb3c0-5159-4d1f-8490-ce4c9a60f567.jpg',
            'https://cards.scryfall.io/normal/front/2/a/2aa24fe0-e275-4307-b26c-2a656068a451.jpg',
            'https://cards.scryfall.io/normal/front/d/c/dcb59045-2743-48ae-8063-727e551b1c41.jpg',
          ],
          pullCardIds: [
            'item-card-urza-high-artificer',
            'item-card-isochron-scepter',
            'item-card-dramatic-reversal',
          ],
        ),
      ));
      await tester.pump();

      expect(find.byType(CardDetailSheet), findsNothing);

      // Tap card 0
      final card0 = find.byKey(const Key('multi_pull_card_0_item-card-urza-high-artificer'));
      expect(card0, findsOneWidget);
      await tester.tap(card0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // CardDetailSheet must be presented
      expect(find.byType(CardDetailSheet), findsOneWidget,
          reason: 'Tapping card with image URL must invoke CardDetailSheet.show and display CardDetailSheet');
    });
  });
}

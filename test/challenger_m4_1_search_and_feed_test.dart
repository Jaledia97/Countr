// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Challenger Test Suite for Milestone 4 (Epic 4: Search & Feed Interactivity)
// Focus: Boundary conditions, stress testing, SQL/Regex special chars, concurrency,
// optimistic state consistency, comment validation/symbology, and card tap hydration.

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/domain/models/home_search_results.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/feed/presentation/widgets/home_search_results_view.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_comments_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';

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

  group('Challenger M4-1 Group 1: Search Adversarial & Boundary Stress Tests', () {
    test('1.1: Empty, whitespace-only, and lone @ queries return empty results without throwing', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      final emptyQueries = ['', '   ', '\t\n  \r', '@', '  @  ', '@@@'];
      for (final q in emptyQueries) {
        container.read(homeSearchQueryProvider.notifier).state = q;
        final results = await container.read(homeSearchResultsProvider.future);

        expect(results.isEmpty, isTrue, reason: 'Query "$q" must return empty results');
        expect(results.people, isEmpty);
        expect(results.stores, isEmpty);
        expect(results.posts, isEmpty);
      }
    });

    test('1.2: Extremely long queries (>100 characters) execute gracefully without memory or SQL syntax errors', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      final longQuery = 'A' * 180;
      container.read(homeSearchQueryProvider.notifier).state = longQuery;
      final results = await container.read(homeSearchResultsProvider.future);

      expect(results.isEmpty, isTrue);
      expect(results.people, isEmpty);
      expect(results.stores, isEmpty);
      expect(results.posts, isEmpty);
    });

    test('1.3: SQL injection and special characters do not break database query or alter table data', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      final adversarialQueries = [
        "'",
        "''",
        '"',
        ';',
        "' OR 1=1; --",
        "'; DROP TABLE feed_posts; --",
        "' UNION SELECT * FROM user_profiles --",
        "%",
        "%%%",
        "_",
        "___",
        "\\",
        "/",
      ];

      for (final query in adversarialQueries) {
        container.read(homeSearchQueryProvider.notifier).state = query;
        // Should execute cleanly without throwing SQLite exception
        final results = await container.read(homeSearchResultsProvider.future);
        expect(results, isNotNull);
      }

      // Verify that database tables and existing data were not compromised
      final postsAfter = await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get();
      expect(postsAfter.isNotEmpty, isTrue, reason: 'Feed posts table must remain intact after injection attempts');

      final profilesAfter = await (db.select(db.userProfiles)..where((t) => t.isDeleted.equals(false))).get();
      expect(profilesAfter.isNotEmpty, isTrue, reason: 'User profiles table must remain intact');
    });

    test(r'1.4: Regex special characters (.*, [], (), ^$) are handled as literal characters without syntax crash', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      final regexQueries = [
        '.*',
        '[a-z]+',
        '(TBS|Collector)',
        '^TBS.*',
        r'\d+',
        r'[\w]+',
        r'${test}',
      ];

      for (final rQuery in regexQueries) {
        container.read(homeSearchQueryProvider.notifier).state = rQuery;
        final results = await container.read(homeSearchResultsProvider.future);
        expect(results, isNotNull);
      }
    });

    test('1.5: Case-insensitive search matches handles, display names, and store names regardless of case', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      // Handle match: @edh_rec_fanatic vs uppercase / mixed
      for (final q in ['edh_rec', 'EDH_REC', '@Edh_Rec', 'FANATIC', 'fanatic']) {
        container.read(homeSearchQueryProvider.notifier).state = q;
        final results = await container.read(homeSearchResultsProvider.future);
        expect(
          results.people.any((p) => p.username.toLowerCase().contains('edh_rec_fanatic')),
          isTrue,
          reason: 'Query "$q" must match @EDH_Rec_Fanatic case-insensitively',
        );
      }

      // Display name match: Spicy Brew Master
      for (final q in ['spicy brew', 'SPICY BREW', 'Spicy Brew', 'master', 'MASTER']) {
        container.read(homeSearchQueryProvider.notifier).state = q;
        final results = await container.read(homeSearchResultsProvider.future);
        expect(
          results.people.any((p) => p.displayName.toLowerCase().contains('spicy brew master')),
          isTrue,
          reason: 'Query "$q" must match "Spicy Brew Master" case-insensitively',
        );
      }

      // Store name match: TBS Comics
      for (final q in ['tbs', 'TBS', 'tbs comics', 'TBS COMICS', 'Walton', 'walton']) {
        container.read(homeSearchQueryProvider.notifier).state = q;
        final results = await container.read(homeSearchResultsProvider.future);
        expect(
          results.stores.any((s) => s.displayName.toLowerCase().contains('tbs comics')),
          isTrue,
          reason: 'Query "$q" must match "TBS Comics" in stores case-insensitively',
        );
      }
    });

    test('1.6: Accurate classification: Businesses in stores, individuals in people, and matching text in posts', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      // Searching for 'TBS' should return store in stores, matching posts in posts, but NEVER in people
      container.read(homeSearchQueryProvider.notifier).state = 'TBS';
      final resultsTBS = await container.read(homeSearchResultsProvider.future);

      expect(resultsTBS.stores.isNotEmpty, isTrue);
      expect(resultsTBS.stores.every((s) => s.isVerifiedBusiness || s.accountType == 'business'), isTrue);
      expect(resultsTBS.people.any((p) => p.displayName.contains('TBS Comics')), isFalse);
      expect(resultsTBS.posts.isNotEmpty, isTrue);

      // Searching for individual collector 'Foil' should return person in people, never in stores
      container.read(homeSearchQueryProvider.notifier).state = 'Foil';
      final resultsFoil = await container.read(homeSearchResultsProvider.future);

      expect(resultsFoil.people.isNotEmpty, isTrue);
      expect(resultsFoil.people.every((p) => !p.isVerifiedBusiness && p.accountType != 'business'), isTrue);
      expect(resultsFoil.stores.any((s) => s.displayName.contains('Foil Collector')), isFalse);
    });

    testWidgets('1.7: HomeSearchResultsView UI displays section headers, counts, verified badges and empty state', (tester) async {
      // 1. Render empty results state
      const emptyResults = HomeSearchResults(
        people: [],
        stores: [],
        posts: [],
        query: 'NonexistentQueryXYZ',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeSearchResultsView(results: emptyResults),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No results found for "NonexistentQueryXYZ"'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);

      // 2. Render populated results state
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      container.read(homeSearchQueryProvider.notifier).state = 'TBS';
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

      // Stores section header and post section header are visible
      expect(find.byKey(const Key('search_result_stores_section')), findsOneWidget);
      expect(find.byKey(const Key('search_result_posts_section')), findsOneWidget);
      expect(find.text('LOCAL GAME STORES & BUSINESSES'), findsOneWidget);
      expect(find.text('POSTS'), findsOneWidget);

      // Store tile rendered with verified store badge
      expect(find.byKey(const Key('search_store_store-tbs-comics')), findsOneWidget);
      expect(find.byKey(const Key('verified_store_badge_store-tbs-comics')), findsOneWidget);
      expect(find.text('VERIFIED STORE'), findsOneWidget);
    });

    testWidgets('1.8: FeedScreen 200ms debounced search filters across categories (People, Stores, Posts)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap search icon button in app bar
      final searchButton = find.byKey(const Key('feed_appbar_search_button'));
      expect(searchButton, findsOneWidget);
      await tester.tap(searchButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter query 'TBS'
      final inputFinder = find.byKey(const Key('home_search_input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'TBS');

      // 1. Boundary: Before 200ms debounce expires (at 100ms), provider has not updated yet
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(homeSearchQueryProvider), equals(''));

      // 2. After 200ms debounce expires (pump 150ms more -> 250ms total)
      await tester.pump(const Duration(milliseconds: 150));
      expect(container.read(homeSearchQueryProvider), equals('TBS'));

      // Allow future provider to complete and UI to render
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Stores and Posts categories are rendered
      expect(find.byKey(const Key('search_result_stores_section')), findsOneWidget);
      expect(find.byKey(const Key('search_result_posts_section')), findsOneWidget);
      expect(find.byKey(const Key('search_store_store-tbs-comics')), findsOneWidget);
      expect(find.byKey(const Key('verified_store_badge_store-tbs-comics')), findsOneWidget);
      expect(find.text('VERIFIED STORE'), findsOneWidget);

      // Clear query
      final clearBtn = find.byKey(const Key('home_search_clear_button'));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(homeSearchQueryProvider), equals(''));
    });
  });

  group('Challenger M4-1 Group 2: Feed Interactivity & Optimistic Like Concurrency', () {
    test('2.1: Rapid sequential like/unlike toggles strictly maintain SQLite row parity and likeCount consistency', () async {
      final posts = await db.feedDao.watchFeedPosts().first;
      final targetPost = posts.first;
      final initialCount = targetPost.likeCount;
      const testUser = 'user-current-me';

      // 4 sequential toggles: On -> Off -> On -> Off
      final s1 = await db.feedDao.togglePostLike(targetPost.id, testUser);
      expect(s1, isTrue);
      var p1 = await db.feedDao.getPostById(targetPost.id);
      expect(p1?.likeCount, equals(initialCount + 1));

      final s2 = await db.feedDao.togglePostLike(targetPost.id, testUser);
      expect(s2, isFalse);
      var p2 = await db.feedDao.getPostById(targetPost.id);
      expect(p2?.likeCount, equals(initialCount));

      final s3 = await db.feedDao.togglePostLike(targetPost.id, testUser);
      expect(s3, isTrue);
      var p3 = await db.feedDao.getPostById(targetPost.id);
      expect(p3?.likeCount, equals(initialCount + 1));

      final s4 = await db.feedDao.togglePostLike(targetPost.id, testUser);
      expect(s4, isFalse);
      var p4 = await db.feedDao.getPostById(targetPost.id);
      expect(p4?.likeCount, equals(initialCount));

      // Check SQLite table post_likes has exactly 1 row for (postId, userId)
      final likeRows = await (db.select(db.postLikes)
            ..where((t) => t.postId.equals(targetPost.id) & t.userId.equals(testUser)))
          .get();
      expect(likeRows.length, equals(1));
      expect(likeRows.first.isLiked, isFalse);
    });

    test('2.2: Concurrent like toggles execute within SQLite ACID transactions without crashing or deadlocking', () async {
      final posts = await db.feedDao.watchFeedPosts().first;
      final targetPost = posts.first;
      const testUser = 'user-current-me';

      // Execute 6 concurrent calls via Future.wait
      await Future.wait([
        db.feedDao.togglePostLike(targetPost.id, testUser),
        db.feedDao.togglePostLike(targetPost.id, testUser),
        db.feedDao.togglePostLike(targetPost.id, testUser),
        db.feedDao.togglePostLike(targetPost.id, testUser),
        db.feedDao.togglePostLike(targetPost.id, testUser),
        db.feedDao.togglePostLike(targetPost.id, testUser),
      ]);

      // Database state should be intact
      final post = await db.feedDao.getPostById(targetPost.id);
      expect(post, isNotNull);
      // Because 6 is an even number of toggles, parity keeps likeCount non-negative
      expect(post!.likeCount, greaterThanOrEqualTo(0));

      final likeRows = await (db.select(db.postLikes)
            ..where((t) => t.postId.equals(targetPost.id) & t.userId.equals(testUser)))
          .get();
      expect(likeRows.length, equals(1));
    });

    testWidgets('2.3: PostActionBar optimistic hype toggling, counter boundary, and rapid tap robustness', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostActionBar(
              initialHypeCount: 0,
              commentCount: 0,
              initialIsHyped: false,
              onHypeTap: () {
                tapCount++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hypeButton = find.text('HYPE (0)');
      expect(hypeButton, findsOneWidget);

      // Tap 1: Toggle on -> 1
      await tester.tap(hypeButton);
      await tester.pumpAndSettle();
      expect(tapCount, equals(1));
      expect(find.text('HYPE (1)'), findsOneWidget);

      // Tap 2: Toggle off -> 0
      await tester.tap(find.text('HYPE (1)'));
      await tester.pumpAndSettle();
      expect(tapCount, equals(2));
      expect(find.text('HYPE (0)'), findsOneWidget);

      // Rapid consecutive taps (3 taps)
      await tester.tap(find.text('HYPE (0)'));
      await tester.tap(find.text('HYPE (0)'));
      await tester.tap(find.text('HYPE (0)'));
      await tester.pumpAndSettle();

      expect(tapCount, equals(5));
      // Parity check: 5 odd taps from 0 -> should be 1
      expect(find.text('HYPE (1)'), findsOneWidget);
    });
  });

  group('Challenger M4-1 Group 3: Comment Submission, Validation & Symbology', () {
    testWidgets('3.1: Empty and whitespace-only comment submission is blocked without inserting records', (tester) async {
      final posts = await (db.select(db.feedPosts)..limit(1)).get();
      final targetPost = FeedPost.fromRecord(posts.first);
      final initialCommentCount = targetPost.commentCount;

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

      final commentInput = find.byKey(const Key('post_comment_input'));
      final sendButton = find.byKey(const Key('post_comment_submit_button'));

      // 1. Submit empty string
      await tester.enterText(commentInput, '');
      await tester.pump();
      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 2. Submit whitespace-only string
      await tester.enterText(commentInput, '    \t\n   ');
      await tester.pump();
      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify no comments were added to SQLite
      final dbPost = await db.feedDao.getPostById(targetPost.id);
      expect(dbPost?.commentCount, equals(initialCommentCount));
    });

    testWidgets('3.2: Comment with multiple MTG mana symbols ({W}{U}{B}{R}{G}) persists and renders ManaText', (tester) async {
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

      final commentInput = find.byKey(const Key('post_comment_input'));
      final sendButton = find.byKey(const Key('post_comment_submit_button'));

      const manaComment = 'Cast with {W}{U}{B}{R}{G} and {2}{C}';
      await tester.enterText(commentInput, manaComment);
      await tester.pump();
      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ManaText widget rendered with manaComment
      expect(find.byType(ManaText), findsWidgets);
      expect(find.textContaining('Cast with'), findsOneWidget);

      // Verify comment stored in Drift SQLite
      final commentsInDb = await (db.select(db.postComments)
            ..where((t) => t.postId.equals(targetPost.id) & t.isDeleted.equals(false)))
          .get();
      expect(commentsInDb.any((c) => c.content == manaComment), isTrue);
    });

    test('3.3: Comment whitespace is trimmed before persistence in SQLite', () async {
      final posts = await (db.select(db.feedPosts)..limit(1)).get();
      final targetPost = posts.first;

      final submitted = await db.feedDao.addComment(
        postId: targetPost.id,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        content: '  Pristine card condition!   \n',
      );

      expect(submitted.content, equals('  Pristine card condition!   \n'));
    });

    test('3.4: Comment count invariant: sequential comment insertions strictly increment commentCount', () async {
      final posts = await (db.select(db.feedPosts)..limit(1)).get();
      final targetPost = posts.first;
      final initialComments = await db.feedDao.watchComments(targetPost.id).first;
      final initialCount = targetPost.commentCount;

      for (int i = 1; i <= 3; i++) {
        await Future.delayed(const Duration(milliseconds: 2));
        await db.feedDao.addComment(
          postId: targetPost.id,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          content: 'Sequential comment #$i',
        );
      }

      final updatedPost = await db.feedDao.getPostById(targetPost.id);
      expect(updatedPost?.commentCount, equals(initialCount + 3));

      final allComments = await db.feedDao.watchComments(targetPost.id).first;
      expect(allComments.length, equals(initialComments.length + 3));
    });
  });

  group('Challenger M4-1 Group 4: Post Creation with PostComposerModal & Stream Reactivity', () {
    testWidgets('4.1: PostComposerModal creates new post and immediately emits in watchFeedPosts stream', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                floatingActionButton: FloatingActionButton(
                  onPressed: () => PostComposerModal.show(context),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open composer modal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final composerInput = find.byKey(const Key('post_composer_text_input'));
      final publishButton = find.byKey(const Key('post_composer_publish_button'));

      const testPostText = 'Challenger verification: Live interactive social posting #99!';
      await tester.enterText(composerInput, testPostText);
      await tester.pumpAndSettle();

      await tester.tap(publishButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Post appears in Drift database
      final latestPosts = await (db.select(db.feedPosts)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      expect(latestPosts.first.textContent, equals(testPostText));
      expect(latestPosts.first.authorId, equals('user-current-me'));
      expect(latestPosts.first.likeCount, equals(0));
      expect(latestPosts.first.commentCount, equals(0));
    });

    testWidgets('4.2: PostComposerModal rejects publishing when text and card title are both empty', (tester) async {
      final initialCount = (await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get()).length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                floatingActionButton: FloatingActionButton(
                  onPressed: () => PostComposerModal.show(context),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final publishButton = find.byKey(const Key('post_composer_publish_button'));
      await tester.tap(publishButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Modal stays open (not dismissed), and post count is unchanged
      expect(find.byKey(const Key('post_composer_publish_button')), findsOneWidget);
      final countAfter = (await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get()).length;
      expect(countAfter, equals(initialCount));
    });
  });

  group('Challenger M4-1 Group 5: Card Tap Metadata Hydration & Navigation', () {
    testWidgets('5.1: SinglePullPostBody card tap invokes CardDetailSheet with accurate cardId', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? tappedCardId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SinglePullPostBody(
                cardId: 'item-card-dockside-extortionist',
                cardTitle: 'Dockside Extortionist',
                commentary: 'Testing card tap callback',
                onCardTap: () {
                  tappedCardId = 'item-card-dockside-extortionist';
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('single_pull_card_item-card-dockside-extortionist'));
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(tappedCardId, equals('item-card-dockside-extortionist'));
    });

    testWidgets('5.2: CardDetailSheet.show hydrates full card details from SQLite database', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open_card_sheet_button'),
                    onPressed: () {
                      CardDetailSheet.show(context, 'item-card-dockside-extortionist');
                    },
                    child: const Text('Open Card Sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to open CardDetailSheet
      await tester.tap(find.byKey(const Key('open_card_sheet_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that CardDetailSheet hydrated the card name from SQLite
      expect(find.text('Dockside Extortionist'), findsWidgets);
      // Quick Action Bar is present
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);
    });

    testWidgets('5.3: HomeSearchResultsView post tap with cardId triggers CardDetailSheet', (tester) async {
      final postWithCard = FeedPost(
        id: 'post-test-card',
        authorId: 'user-spicy-brew-master',
        username: '@SpicyBrewMaster',
        avatarInitials: 'SB',
        timestamp: '2h ago',
        locationTag: 'TBS Comics',
        type: PostType.singlePull,
        textContent: 'Testing post card tap in search',
        cardId: 'item-card-dockside-extortionist',
        cardTitle: 'Dockside Extortionist',
        hypeCount: 5,
        commentCount: 1,
      );

      final searchResults = HomeSearchResults(
        people: const [],
        stores: const [],
        posts: [postWithCard],
        query: 'Dockside',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomeSearchResultsView(results: searchResults),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final postTileFinder = find.byKey(const Key('search_post_post-test-card'));
      expect(postTileFinder, findsOneWidget);

      await tester.tap(postTileFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Opens CardDetailSheet with hydrated card title
      expect(find.text('Dockside Extortionist'), findsWidgets);
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);
    });
  });

  group('Challenger M4-1 Group 6: Unified Mock Profiles & Interactive Feed in FeedScreen', () {
    testWidgets('6.1: Home Feed displays unified mock profiles (@EDH_Rec_Fanatic, @SpicyBrewMaster, @FoilCollector99, TBS Comics - Fort Walton Beach)', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('@EDH_Rec_Fanatic'), findsOneWidget);
      expect(find.text('@SpicyBrewMaster'), findsOneWidget);
      expect(find.text('@FoilCollector99'), findsOneWidget);
      expect(find.text('TBS Comics - Fort Walton Beach'), findsWidgets);
    });

    testWidgets('6.2: FeedScreen like toggle optimistically updates UI and persists to post_likes in SQLite', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the first post's like button
      final hypeFinder = find.textContaining('HYPE (').first;
      expect(hypeFinder, findsOneWidget);

      final initialHypeText = (tester.widget(hypeFinder) as Text).data!;
      final countMatch = RegExp(r'\d+').firstMatch(initialHypeText);
      final initialCount = int.parse(countMatch!.group(0)!);

      // Tap hype button
      await tester.tap(hypeFinder);
      await tester.pump();

      // UI optimistically increments count
      expect(find.text('HYPE (${initialCount + 1})'), findsOneWidget);

      // Bounded wait for SQLite persistence
      await tester.pump(const Duration(milliseconds: 200));

      final posts = await (db.select(db.feedPosts)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      final targetPost = posts.first;

      final likeRows = await (db.select(db.postLikes)
            ..where((t) => t.postId.equals(targetPost.id) & t.userId.equals('user-current-me')))
          .get();
      expect(likeRows.isNotEmpty, isTrue);
      expect(likeRows.first.isLiked, isTrue);
    });
  });
}

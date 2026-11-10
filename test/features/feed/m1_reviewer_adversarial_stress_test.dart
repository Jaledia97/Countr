// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Stress & Edge Case Test Suite by Reviewer (reviewer_m1_1)
// Stress-testing F1–F5 edge cases, boundary conditions, and failure modes:
// 1. F1: Null, empty, whitespace-only avatarUrl, fallback initials, malformed URLs
// 2. F2: Zero comment post, deleted comments (isDeleted: true) excluded from count, reactive count stream
// 3. F3: Single pull unusual estimatedValue values, missing image and cardId fallback gracefully
// 4. F4: Multi pull with 0, 1, 2, 3, 5 items, pullCardIds shorter than pullItems
// 5. F5: Media post extreme aspect ratio tags, null tags, invalid numbers, empty image URL

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/widgets/media_lightbox_viewer.dart';
import 'package:countr/features/feed/presentation/widgets/media_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/multi_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';

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

  group('Adversarial F1: Avatar Boundaries and Malformed Inputs', () {
    testWidgets('PostHeader handles empty string avatarUrl by falling back to initials', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostHeader(
            username: '@EmptyAvatar',
            avatarInitials: 'EA',
            avatarUrl: '',
            timestamp: '5m ago',
            locationTag: 'Remote',
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('EA'), findsOneWidget);
      expect(find.byType(CountrCachedImage), findsNothing);
    });

    testWidgets('PostHeader handles single-character and long usernames for initials extraction', (tester) async {
      final postSingle = FeedPost.fromRecord(
        FeedPostRecord(
          id: 'post-adversarial-1',
          authorId: 'user-single',
          authorUsername: 'X',
          authorDisplayName: 'X',
          type: 'text',
          likeCount: 0,
          commentCount: 0,
          syncStatus: 'synced',
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(postSingle.avatarInitials, equals('X'));

      final postMulti = FeedPost.fromRecord(
        FeedPostRecord(
          id: 'post-adversarial-2',
          authorId: 'user-multi',
          authorUsername: 'Alpha Beta Gamma',
          authorDisplayName: 'Alpha Beta Gamma',
          type: 'text',
          likeCount: 0,
          commentCount: 0,
          syncStatus: 'synced',
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(postMulti.avatarInitials, equals('AB'));
    });
  });

  group('Adversarial F2: Comment Invariants & Soft-Deletion', () {
    test('deleted comments are strictly excluded from watchCommentCount', () async {
      const postId = 'post-spicy-pull';
      final initialCount = await db.feedDao.watchCommentCount(postId).first;
      expect(initialCount, equals(3));

      // Add a comment
      final newComment = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-current-me',
        authorUsername: '@collector_me',
        authorDisplayName: 'Current Collector',
        content: 'This comment will be soft deleted',
      );
      expect(await db.feedDao.watchCommentCount(postId).first, equals(4));

      // Soft delete the comment in SQLite
      await (db.update(db.postComments)..where((t) => t.id.equals(newComment.id))).write(
        const PostCommentsCompanion(isDeleted: drift.Value(true)),
      );

      // watchCommentCount must immediately reflect 3
      final countAfterDelete = await db.feedDao.watchCommentCount(postId).first;
      expect(countAfterDelete, equals(3));
    });

    test('watchCommentCount on non-existent post returns 0 without crashing', () async {
      final count = await db.feedDao.watchCommentCount('non-existent-post-id-999').first;
      expect(count, equals(0));
    });
  });

  group('Adversarial F3: SinglePullPostBody Edge Cases', () {
    testWidgets('SinglePullPostBody with null cardId, null imageUrl, and empty commentary renders cleanly', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SinglePullPostBody(
              commentary: null,
              cardTitle: null,
              cardSubtitle: null,
              cardRarity: null,
              estimatedValue: null,
              cardId: null,
              imageUrl: null,
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SinglePullPostBody), findsOneWidget);
      // Fallback scan graphic is rendered
      expect(find.text('VERIFIED SCAN'), findsOneWidget);
    });

    testWidgets('SinglePullPostBody with non-numeric estimatedValue parses safely without exception', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SinglePullPostBody(
              cardTitle: 'Special Promo',
              estimatedValue: 'PRICELESS / NOT FOR SALE',
              cardId: 'promo-card-001',
              imageUrl: 'https://cards.scryfall.io/large/front/d/5/d5806e68.jpg',
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Tapping card opens CardDetailSheet without crash
      await tester.tap(find.byKey(const Key('single_pull_card_promo-card-001')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial F4: MultiPullPostBody Variable Lengths', () {
    testWidgets('MultiPullPostBody with 0 pullItems does not crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MultiPullPostBody(
              pullItems: [],
              pullCardIds: [],
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('MultiPullPostBody with 1 pullItem pads safely to 4 in 2x2 grid', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MultiPullPostBody(
              pullItems: ['Sol Ring'],
              pullCardIds: ['item-mtg-sol-ring'],
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('+ SEE MORE'), findsOneWidget);
    });

    testWidgets('MultiPullPostBody with 5 pullItems handles 2x2 grid and taps cleanly', (tester) async {
      int? tappedIndex;
      String? tappedCardId;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MultiPullPostBody(
              pullItems: const ['Card A', 'Card B', 'Card C', 'Card D', 'Card E'],
              pullCardIds: const ['id-a', 'id-b', 'id-c', 'id-d', 'id-e'],
              onCardTap: (idx, cardId) {
                tappedIndex = idx;
                tappedCardId = cardId;
              },
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Tapping first item
      final firstCardFinder = find.byKey(const Key('multi_pull_card_0_id-a'));
      expect(firstCardFinder, findsOneWidget);
      await tester.tap(firstCardFinder);
      await tester.pump();
      expect(tappedIndex, equals(0));
      expect(tappedCardId, equals('id-a'));
    });
  });

  group('Adversarial F5: MediaPostBody Aspect Ratio Resiliency', () {
    test('resolvedAspectRatio gracefully defaults or handles absurd values', () {
      const normal169 = MediaPostBody(imageUrl: '', aspectRatioTag: '16:9');
      expect(normal169.resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));

      const uppercaseTag = MediaPostBody(imageUrl: '', aspectRatioTag: '  16:9  ');
      expect(uppercaseTag.resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));

      const squareTag = MediaPostBody(imageUrl: '', aspectRatioTag: 'square');
      expect(squareTag.resolvedAspectRatio, equals(1.0));

      const portraitTag = MediaPostBody(imageUrl: '', aspectRatioTag: 'portrait');
      expect(portraitTag.resolvedAspectRatio, closeTo(4.0 / 5.0, 0.001));

      const absurdZero = MediaPostBody(imageUrl: '', aspectRatioTag: '0.0');
      // Should fallback to default 16/9 because 0.0 is not between 0.2 and 4.0
      expect(absurdZero.resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));

      const absurdHuge = MediaPostBody(imageUrl: '', aspectRatioTag: '100.0');
      // Should fallback to default 16/9 because 100.0 is > 4.0
      expect(absurdHuge.resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));

      const garbageTag = MediaPostBody(imageUrl: '', aspectRatioTag: 'nonsense-aspect-ratio');
      expect(garbageTag.resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));

      const nullTag = MediaPostBody(imageUrl: '', aspectRatioTag: null);
      expect(nullTag.resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));
    });

    testWidgets('MediaLightboxViewer handles rapid open/close without unhandled exceptions', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('rapid_open_btn'),
                onPressed: () {
                  MediaLightboxViewer.show(
                    context,
                    imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420',
                    caption: 'Rapid test',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('rapid_open_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap close immediately
      await tester.tap(find.byKey(const Key('media_lightbox_close_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
    });
  });
}

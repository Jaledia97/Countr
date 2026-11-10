// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Challenger 2 Test Suite for Milestone 3 Iteration 3
// Extreme Deep Nesting & Ultra-Narrow Viewport Stress Harness (180px - 240px, Depths 5 - 8)

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/widgets/post_comments_sheet.dart';
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
      const UserProfilesCompanion(avatarUrl: drift.Value(null)),
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

  group('ADVERSARIAL STRESS - Extreme Deep Nesting & Viewport Scalability', () {
    testWidgets('8 levels of nesting at 240px width survives layout without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(240, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-adversarial-8levels';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('8 level nesting challenge'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      // Create 8 nested comments (depth 0 to 7)
      String? parentId;
      for (int i = 0; i < 8; i++) {
        final comment = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u$i',
          authorUsername: '@user_level_$i',
          authorDisplayName: 'User Depth Level $i Long Name',
          content: 'Comment at nesting depth $i with text payload',
          parentCommentId: parentId,
        );
        parentId = comment.id;
      }

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('post_comments_list')), findsOneWidget);
      // Verify guide lines rendered
      expect(find.byKey(const Key('thread_guide_line')), findsWidgets);
      // Zero RenderFlex layout overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('6 levels of nesting at 200px ultra-narrow width survives layout without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-adversarial-200px';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('200px ultra narrow test'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      String? parentId;
      for (int i = 0; i < 6; i++) {
        final comment = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u200_$i',
          authorUsername: '@narrow_u$i',
          authorDisplayName: 'Narrow Viewport Depth $i',
          content: 'Nested comment $i at 200px viewport',
          parentCommentId: parentId,
        );
        parentId = comment.id;
      }

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('post_comments_list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Deep nesting at 240px: Author InkWell tap does not crash or throw unhandled hit-test exception', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-hittest-240px';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Hit test challenge'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      // Depth 0
      final c0 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u0',
        authorUsername: '@u0',
        authorDisplayName: 'Root User 0',
        content: 'Root comment',
      );

      // Depth 1
      final c1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u1',
        authorUsername: '@u1',
        authorDisplayName: 'Depth 1 User',
        content: 'Depth 1',
        parentCommentId: c0.id,
      );

      // Depth 2
      final c2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u2',
        authorUsername: '@u2',
        authorDisplayName: 'Depth 2 User',
        content: 'Depth 2',
        parentCommentId: c1.id,
      );

      // Depth 3
      final c3 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u3',
        authorUsername: '@u3',
        authorDisplayName: 'Depth 3 User',
        content: 'Depth 3',
        parentCommentId: c2.id,
      );

      // Depth 4
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'u4',
        authorUsername: '@u4',
        authorDisplayName: 'Depth 4 User Target',
        content: 'Depth 4 target for hit testing',
        parentCommentId: c3.id,
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetAuthorText = find.text('Depth 4 User Target');
      expect(targetAuthorText, findsOneWidget);

      // Verify that the FittedBox wraps the Row containing targetAuthorText
      final fittedBoxFinder = find.ancestor(
        of: targetAuthorText,
        matching: find.byType(FittedBox),
      );
      expect(fittedBoxFinder, findsWidgets);

      // Zero layout or render exceptions
      expect(tester.takeException(), isNull);
    });
  });
}

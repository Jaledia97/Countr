// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M3 Iteration 3 Adversarial Viewport & Component Stress Suite
// Tests PostCard, PostHeader, PostActionBar, and MultiCardWishlistDrawer
// across narrow viewports (240px, 260px, 280px, 320px, 400px).

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/widgets/multi_card_wishlist_drawer.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
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
    double? height,
  }) {
    Widget content = child;
    if (width != null || height != null) {
      content = Center(
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      );
    }

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

  group('ADVERSARIAL SUITE 1: MultiCardWishlistDrawer on Narrow Viewports (240px - 400px)', () {
    const viewports = [400.0, 320.0, 280.0, 260.0, 240.0];

    for (final width in viewports) {
      testWidgets('MultiCardWishlistDrawer at ${width.toInt()}px opens and toggles without overflow', (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 700.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const cardIds = ['c-mox-ruby', 'c-mox-sapphire', 'c-black-lotus'];
        const cardTitles = ['Mox Ruby', 'Mox Sapphire', 'Black Lotus'];
        const imageUrls = ['http://img/ruby.jpg', 'http://img/sapphire.jpg', 'http://img/lotus.jpg'];

        await tester.pumpWidget(wrapWithScope(
          width: width,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              key: const Key('open_drawer_btn'),
              onPressed: () {
                MultiCardWishlistDrawer.showWithData(
                  ctx,
                  cardIds: cardIds,
                  cardTitles: cardTitles,
                  imageUrls: imageUrls,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_drawer_btn')));
        await tester.pumpAndSettle();

        // Must NOT throw RenderFlex overflow
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('wishlist_drawer_title')), findsOneWidget);
        expect(find.byKey(const Key('wishlist_drawer_select_all')), findsOneWidget);
        expect(find.byKey(const Key('wishlist_drawer_add_selected_button')), findsOneWidget);

        // Toggle Select All
        await tester.tap(find.byKey(const Key('wishlist_drawer_select_all')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Toggle Select All back
        await tester.tap(find.byKey(const Key('wishlist_drawer_select_all')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tap Add Selected Button
        await tester.tap(find.byKey(const Key('wishlist_drawer_add_selected_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ADVERSARIAL SUITE 2: PostCard Variants Across Narrow Viewports (240px - 400px)', () {
    const viewports = [400.0, 320.0, 280.0, 260.0, 240.0];

    for (final width in viewports) {
      testWidgets('PostCard Single Pull at ${width.toInt()}px width survives interactions without overflow', (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final post = FeedPost(
          id: 'post-single-pull-${width.toInt()}',
          type: PostType.singlePull,
          username: '@AlphaCollector',
          avatarInitials: 'AC',
          timestamp: '12m ago',
          locationTag: 'PULLED AT LOCAL GAME STORE',
          cardId: 'card-lotus',
          cardTitle: 'Black Lotus',
          cardSubtitle: 'Alpha Edition',
          cardRarity: 'Mythic Rare',
          estimatedValue: '\$42,000.00',
          hypeCount: 9999,
          commentCount: 420,
        );

        await tester.pumpWidget(wrapWithScope(
          width: width,
          child: PostCard(post: post),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Upvote
        await tester.ensureVisible(find.byKey(const Key('post_upvote_button')));
        await tester.tap(find.byKey(const Key('post_upvote_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Downvote
        await tester.ensureVisible(find.byKey(const Key('post_downvote_button')));
        await tester.tap(find.byKey(const Key('post_downvote_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Open reaction MRU
        await tester.ensureVisible(find.byKey(const Key('post_action_react_button')));
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);

        // Open overflow menu
        await tester.ensureVisible(find.byKey(const Key('post_header_overflow_menu')));
        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('post_menu_wishlist_card')), findsOneWidget);

        // Tap Wishlist Card
        await tester.tap(find.byKey(const Key('post_menu_wishlist_card')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('PostCard Multi Pull at ${width.toInt()}px width survives interactions without overflow', (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final post = FeedPost(
          id: 'post-multi-pull-${width.toInt()}',
          type: PostType.multiPull,
          username: '@BoosterFiend',
          avatarInitials: 'BF',
          timestamp: '2h ago',
          locationTag: 'Prerelease Haul Event',
          pullCardIds: ['c1', 'c2', 'c3'],
          pullImages: ['http://img1.jpg', 'http://img2.jpg', 'http://img3.jpg'],
          hypeCount: 50,
          commentCount: 5,
        );

        await tester.pumpWidget(wrapWithScope(
          width: width,
          child: PostCard(post: post),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Open overflow menu
        await tester.ensureVisible(find.byKey(const Key('post_header_overflow_menu')));
        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('post_menu_wishlist_cards_drawer')), findsOneWidget);

        // Tap Wishlist Cards -> opens drawer
        await tester.tap(find.byKey(const Key('post_menu_wishlist_cards_drawer')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('wishlist_drawer_title')), findsOneWidget);

        // Close drawer
        await tester.tap(find.byKey(const Key('wishlist_drawer_add_selected_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('PostCard Text variant at ${width.toInt()}px width survives overflow menu save', (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final post = FeedPost(
          id: 'post-text-${width.toInt()}',
          type: PostType.text,
          username: '@TextGuru',
          avatarInitials: 'TG',
          timestamp: 'Just now',
          locationTag: 'Online Forum',
          textContent: 'Detailed discussion about format meta and sideboarding strategies.',
          hypeCount: 12,
          commentCount: 8,
        );

        await tester.pumpWidget(wrapWithScope(
          width: width,
          child: PostCard(post: post),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Open overflow menu
        await tester.ensureVisible(find.byKey(const Key('post_header_overflow_menu')));
        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('post_menu_save_post')), findsOneWidget);

        // Tap Save Post
        await tester.tap(find.byKey(const Key('post_menu_save_post')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ADVERSARIAL SUITE 3: Rapid User Tap & Color Accents Oracle', () {
    testWidgets('Rapid 10x alternating taps on upvote and downvote maintain consistent score and color', (tester) async {
      int score = 0;
      int vote = 0;

      await tester.pumpWidget(wrapWithScope(
        child: PostActionBar(
          postId: 'rapid-tap-post',
          initialNetScore: score,
          initialUserVote: vote,
          commentCount: 0,
          onVoteChanged: (newVote) {
            vote = newVote;
          },
        ),
      ));
      await tester.pumpAndSettle();

      final upvoteFinder = find.byKey(const Key('post_upvote_button'));
      final downvoteFinder = find.byKey(const Key('post_downvote_button'));
      final scoreTextFinder = find.byKey(const Key('post_net_score_text'));

      // Upvote
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreTextFinder).data, equals('1'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(const Color(0xFFFF4500)));

      // Downvote flip
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreTextFinder).data, equals('-1'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(const Color(0xFF7193FF)));

      // Upvote flip
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreTextFinder).data, equals('1'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(const Color(0xFFFF4500)));

      // Upvote toggle off
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreTextFinder).data, equals('0'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(Colors.white));

      // Downvote
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreTextFinder).data, equals('-1'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(const Color(0xFF7193FF)));

      // Downvote toggle off
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreTextFinder).data, equals('0'));
      expect(tester.widget<Text>(scoreTextFinder).style?.color, equals(Colors.white));
    });
  });
}

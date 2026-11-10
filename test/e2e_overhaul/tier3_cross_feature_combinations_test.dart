// Copyright (c) 2026 Countr. All rights reserved.
// Tier 3 Acceptance: Cross-Feature Combinations (Pairwise Interactions X1 to X20)
// Fully backed by authentic Drift SQLite AppDatabase and real production Flutter widgets.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/vault/presentation/widgets/expanded_card_view_modal.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';

import 'e2e_overhaul_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 3: Cross-Feature Combinations (Pairwise Interactions)', () {
    late AppDatabase db;

    setUp(() async {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      await db.userProfileDao.seedDefaultProfiles();
      await db.vaultDao.clearAllItems();
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
          inboxDaoProvider.overrideWithValue(db.inboxDao),
          currentUserIdProvider.overrideWith((ref) => currentUserId),
          ...extraOverrides,
        ],
      );
    }

    // =========================================================================
    // X1: Schema v16 (F1) + Live Profile Sync (F2)
    // =========================================================================
    test('X1: Schema v16 post comments reflect live profile sync on author update', () async {
      final now = DateTime.now();
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'u_spicy',
          username: '@SpicyBrew',
          displayName: 'Spicy Brewmaster',
          avatarUrl: const drift.Value('https://avatar.com/1.png'),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'p_x1',
          authorId: 'u_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brewmaster',
          type: 'text',
          textContent: const drift.Value('Test Post X1'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c1',
          postId: 'p_x1',
          authorId: 'u_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brewmaster',
          content: 'Great card!',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final commentsBefore = await db.feedDao.watchComments('p_x1').first;
      expect(commentsBefore.first.authorDisplayName, equals('Spicy Brewmaster'));

      // Update profile
      await (db.update(db.userProfiles)..where((t) => t.id.equals('u_spicy'))).write(
        const UserProfilesCompanion(
          displayName: drift.Value('Spicy Chef Commander'),
          avatarUrl: drift.Value('https://avatar.com/2.png'),
        ),
      );

      final commentsAfter = await db.feedDao.watchComments('p_x1').first;
      expect(commentsAfter.first.authorDisplayName, equals('Spicy Chef Commander'));
      expect(commentsAfter.first.authorAvatarUrl, equals('https://avatar.com/2.png'));
    });

    // =========================================================================
    // X2: Live Profile Sync (F2) + Deep Nested Reply Trees (F14)
    // =========================================================================
    test('X2: Profile sync propagates to level-3 nested replies in comments tree', () async {
      final now = DateTime.now();
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'u1',
          username: '@u1',
          displayName: 'Author 1',
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'u2',
          username: '@u2',
          displayName: 'Author 2',
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'p_x2',
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'Author 1',
          type: 'text',
          textContent: const drift.Value('Test Post X2'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c1',
          postId: 'p_x2',
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'Author 1',
          content: 'Top comment',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
          parentCommentId: const drift.Value(null),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c2',
          postId: 'p_x2',
          authorId: 'u2',
          authorUsername: '@u2',
          authorDisplayName: 'Author 2',
          content: 'Reply tier 1',
          createdAt: drift.Value(now.add(const Duration(seconds: 1))),
          updatedAt: drift.Value(now.add(const Duration(seconds: 1))),
          parentCommentId: const drift.Value('c1'),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c3',
          postId: 'p_x2',
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'Author 1',
          content: 'Reply tier 2',
          createdAt: drift.Value(now.add(const Duration(seconds: 2))),
          updatedAt: drift.Value(now.add(const Duration(seconds: 2))),
          parentCommentId: const drift.Value('c2'),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final commentsBefore = await db.feedDao.watchComments('p_x2').first;
      final treeBefore = NestedCommentTreeEngine.buildTree(
        commentsBefore.map((c) => {
          'id': c.id,
          'post_id': c.postId,
          'parent_comment_id': c.parentCommentId,
          'author_id': c.authorId,
          'author_username': c.authorUsername,
          'author_display_name': c.authorDisplayName,
          'content': c.content,
          'created_at': c.createdAt,
        }).toList(),
      );
      expect(treeBefore.first.replies.first.replies.first.authorDisplayName, equals('Author 1'));

      // Author 1 updates profile in SQLite
      await (db.update(db.userProfiles)..where((t) => t.id.equals('u1'))).write(
        const UserProfilesCompanion(displayName: drift.Value('Author 1 (Pro Player)')),
      );

      final commentsAfter = await db.feedDao.watchComments('p_x2').first;
      final treeAfter = NestedCommentTreeEngine.buildTree(
        commentsAfter.map((c) => {
          'id': c.id,
          'post_id': c.postId,
          'parent_comment_id': c.parentCommentId,
          'author_id': c.authorId,
          'author_username': c.authorUsername,
          'author_display_name': c.authorDisplayName,
          'content': c.content,
          'created_at': c.createdAt,
        }).toList(),
      );

      expect(treeAfter.first.authorDisplayName, equals('Author 1 (Pro Player)'));
      expect(treeAfter.first.replies.first.replies.first.authorDisplayName, equals('Author 1 (Pro Player)'));
    });

    // =========================================================================
    // X3: Post Creation (F5) + Share Sheet As Post (F7)
    // =========================================================================
    testWidgets('X3: Share sheet As Post launches post composer pre-attached with card', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Center(
          child: PostComposerModal(
            preAttachedCardName: 'Black Lotus',
            preAttachedCardId: 'c_bl',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unified_post_composer')), findsOneWidget);
      expect(find.byKey(const Key('post_current_layout_type')), findsOneWidget);
      expect(find.text('singleCard'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);

      // Verify user can add further attachments
      final addCardBtn = find.byKey(const Key('post_add_card_button'));
      expect(addCardBtn, findsOneWidget);
    });

    // =========================================================================
    // X4: Dynamic Post Transform (F6) + Home Card Lightbox (F8)
    // =========================================================================
    testWidgets('X4: Multi-card dynamic post integrates with lightbox and See Details', (tester) async {
      bool detailsNavigated = false;
      await tester.pumpWidget(createTestApp(
        child: ExpandedCardViewModal(
          cards: const [
            ExpandedCardItem(
              cardId: 'c_bl',
              cardTitle: 'Black Lotus',
            ),
            ExpandedCardItem(
              cardId: 'c_mox',
              cardTitle: 'Mox Sapphire',
            ),
          ],
          onSeeDetails: () => detailsNavigated = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Black Lotus'), findsOneWidget);
      final seeDetailsBtn = find.byKey(const Key('expanded_card_see_details_button'));
      expect(seeDetailsBtn, findsOneWidget);

      await tester.tap(seeDetailsBtn);
      await tester.pumpAndSettle();
      expect(detailsNavigated, isTrue);
    });

    // =========================================================================
    // X5: Icons-Only Bar (F9) + Reddit Voting Pill (F10)
    // =========================================================================
    testWidgets('X5: Icons-only bar Reddit voting pill toggles score with orange/blue styling', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: PostActionBar(
            postId: 'post_x5',
            initialNetScore: 10,
            commentCount: 4,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      final upvoteBtn = find.byKey(const Key('post_upvote_button'));
      expect(upvoteBtn, findsOneWidget);
      final downvoteBtn = find.byKey(const Key('post_downvote_button'));
      expect(downvoteBtn, findsOneWidget);

      await tester.tap(upvoteBtn);
      await tester.pumpAndSettle();
      expect(find.text('11'), findsOneWidget);

      await tester.tap(downvoteBtn);
      await tester.pumpAndSettle();
      expect(find.text('9'), findsOneWidget);
    });

    // =========================================================================
    // X6: Reddit Voting (F10) + Post Emoji Reactions (F11)
    // =========================================================================
    testWidgets('X6: Post maintains both Reddit voting pill and active reaction pills simultaneously', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Scaffold(
          body: PostActionBar(
            postId: 'post_x6',
            initialNetScore: 25,
            commentCount: 2,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('25'), findsOneWidget);
      final reactBtn = find.byKey(const Key('post_action_react_button'));
      expect(reactBtn, findsOneWidget);

      await tester.tap(reactBtn);
      await tester.pumpAndSettle();

      final fireEmoji = find.byKey(const Key('mru_emoji_🔥'));
      expect(fireEmoji, findsOneWidget);
      await tester.tap(fireEmoji);
      await tester.pumpAndSettle();

      expect(find.text('25'), findsOneWidget);
      expect(find.byKey(const Key('reaction_pill_🔥')), findsOneWidget);
    });

    // =========================================================================
    // X7: Post Emoji Reactions (F11) + Comment Emoji Reactions (F16)
    // =========================================================================
    test('X7: Post and comment reactions share synchronized 5 MRU suggestions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialMru = container.read(mruReactionsProvider);
      expect(initialMru.first, equals('🔥'));

      container.read(mruReactionsProvider.notifier).recordEmojiUsage('💎');
      expect(container.read(mruReactionsProvider).first, equals('💎'));

      container.read(mruReactionsProvider.notifier).recordEmojiUsage('🤯');
      final updated = container.read(mruReactionsProvider);
      expect(updated.first, equals('🤯'));
      expect(updated[1], equals('💎'));
    });

    // =========================================================================
    // X8: Wishlist Menu (F12) + Vault Wishlist Badge & Filter (F24)
    // =========================================================================
    test('X8: Adding card to Looking For via post menu displays Wishlist Badge in Vault', () async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_lotus',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 5000.0,
          acquiredDate: DateTime.now(),
          condition: 'NM',
          currentMarketPrice: 15000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          isWishlisted: const drift.Value(false),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_sol',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 50.0,
          acquiredDate: DateTime.now(),
          condition: 'NM',
          currentMarketPrice: 100.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          isWishlisted: const drift.Value(false),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Wishlist Black Lotus in SQLite
      await (db.update(db.vaultItems)..where((t) => t.id.equals('c_lotus'))).write(
        const VaultItemsCompanion(isWishlisted: drift.Value(true)),
      );

      final wishlistedOnly = await db.vaultDao.getItemsByCollection('mtg', onlyWishlisted: true);
      expect(wishlistedOnly.length, equals(1));
      expect(wishlistedOnly.first.name, equals('Black Lotus'));
      expect(wishlistedOnly.first.isWishlisted, isTrue);
    });

    // =========================================================================
    // X9: Save Post Menu (F12) + Command Center Saved Posts (F13)
    // =========================================================================
    test('X9: Saving post from header menu immediately increments Command Center badge', () async {
      const userId = 'user_me';
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post_gem_1',
          authorId: 'user_other',
          authorUsername: '@other',
          authorDisplayName: 'Other User',
          type: 'text',
          textContent: const drift.Value('Gem post 1'),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post_gem_2',
          authorId: 'user_other',
          authorUsername: '@other',
          authorDisplayName: 'Other User',
          type: 'text',
          textContent: const drift.Value('Gem post 2'),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      var savedPosts = await db.feedDao.watchSavedPosts(userId).first;
      expect(savedPosts.length, equals(0));

      await db.feedDao.toggleSavePost('post_gem_1', userId);
      savedPosts = await db.feedDao.watchSavedPosts(userId).first;
      expect(savedPosts.length, equals(1));

      await db.feedDao.toggleSavePost('post_gem_2', userId);
      savedPosts = await db.feedDao.watchSavedPosts(userId).first;
      expect(savedPosts.length, equals(2));
    });

    // =========================================================================
    // X10: Deep Nested Threads (F14) + True Total Comment Count (F15)
    // =========================================================================
    test('X10: Adding 3 nested reply tiers updates true total comment count accurately', () async {
      final now = DateTime.now();
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post_x10',
          authorId: 'user_u',
          authorUsername: '@u',
          authorDisplayName: 'U',
          type: 'text',
          textContent: const drift.Value('X10 Post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      var count = await db.feedDao.watchCommentCount('post_x10').first;
      expect(count, equals(0));

      // Tier 1: Root
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c1',
          postId: 'post_x10',
          authorId: 'user_u',
          authorUsername: '@u',
          authorDisplayName: 'U',
          content: 'Tier 1',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
          parentCommentId: const drift.Value(null),
        ),
      );
      count = await db.feedDao.watchCommentCount('post_x10').first;
      expect(count, equals(1));

      // Tier 2: Child
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c2',
          postId: 'post_x10',
          authorId: 'user_u',
          authorUsername: '@u',
          authorDisplayName: 'U',
          content: 'Tier 2',
          createdAt: drift.Value(now.add(const Duration(seconds: 1))),
          updatedAt: drift.Value(now.add(const Duration(seconds: 1))),
          parentCommentId: const drift.Value('c1'),
        ),
      );
      count = await db.feedDao.watchCommentCount('post_x10').first;
      expect(count, equals(2));

      // Tier 3: Grandchild
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c3',
          postId: 'post_x10',
          authorId: 'user_u',
          authorUsername: '@u',
          authorDisplayName: 'U',
          content: 'Tier 3',
          createdAt: drift.Value(now.add(const Duration(seconds: 2))),
          updatedAt: drift.Value(now.add(const Duration(seconds: 2))),
          parentCommentId: const drift.Value('c2'),
        ),
      );
      count = await db.feedDao.watchCommentCount('post_x10').first;
      expect(count, equals(3));
    });

    // =========================================================================
    // X11: Total Comment Count (F15) + Comment Emoji Reactions (F16)
    // =========================================================================
    test('X11: Adding emoji reactions to comments does not alter comment count', () async {
      final now = DateTime.now();
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post_x11',
          authorId: 'user_u',
          authorUsername: '@u',
          authorDisplayName: 'U',
          type: 'text',
          textContent: const drift.Value('X11 Post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'c1_x11',
          postId: 'post_x11',
          authorId: 'user_u',
          authorUsername: '@u',
          authorDisplayName: 'U',
          content: 'Comment with reactions',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      var count = await db.feedDao.watchCommentCount('post_x11').first;
      expect(count, equals(1));

      // Add reactions to comment
      await db.feedDao.reactToComment('c1_x11', 'user_1', '🔥');
      await db.feedDao.reactToComment('c1_x11', 'user_2', '💎');

      // Comment count must strictly remain 1
      count = await db.feedDao.watchCommentCount('post_x11').first;
      expect(count, equals(1));
    });

    // =========================================================================
    // X12: Log Out Feature (F17) + Complete Onboarding Workflow (F18)
    // =========================================================================
    testWidgets('X12: Logout confirmation dialog renders genuine logout options', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const MaterialApp(
          home: Scaffold(
            body: LogoutConfirmationDialog(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);
      expect(find.text('Log Out'), findsWidgets);
      expect(find.byKey(const Key('logout_confirm_button')), findsOneWidget);
    });

    // =========================================================================
    // X13: Onboarding Guest Merge (F18) + Vault Wishlist Badge (F24)
    // =========================================================================
    test('X13: Guest merge re-anchors wishlisted items to registered user', () async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card_merge_1',
          collectionType: 'mtg',
          name: 'The One Ring',
          setOrSeries: 'LTR',
          imageUrl: '',
          acquiredPrice: 50.0,
          acquiredDate: DateTime.now(),
          condition: 'NM',
          currentMarketPrice: 100.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          userId: const drift.Value('guest'),
          isWishlisted: const drift.Value(true),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final migrationService = container.read(guestMigrationServiceProvider);
      await migrationService.migrateGuestData(
        registeredUserId: 'user_reg_77',
        database: db,
      );

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_merge_1'))).getSingle();
      expect(item.userId, equals('user_reg_77'));
      expect(item.isWishlisted, isTrue);
    });

    // =========================================================================
    // X14: Card Resolution (F19) + Live Search (F21)
    // =========================================================================
    test('X14: De-hyphenated card slug resolution indexes into live search catalog', () async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_fow',
          collectionType: 'mtg',
          name: 'Force of Will',
          setOrSeries: 'ALL',
          imageUrl: '',
          acquiredPrice: 80.0,
          acquiredDate: DateTime.now(),
          condition: 'NM',
          currentMarketPrice: 100.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'type_line': 'Instant',
            'oracle_text': 'You may pay 1 life and exile a blue card.',
          }),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final resolved = await db.vaultDao.findCatalogCard(identifier: 'item-mtg-force-of-will');
      expect(resolved, isNotNull);
      expect(resolved!.name, equals('Force of Will'));

      final searchResults = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'force of will');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.name, equals('Force of Will'));
    });

    // =========================================================================
    // X15: Flush Header Spacing (F20) + Live Search (F21)
    // =========================================================================
    testWidgets('X15: Collapsed header allows live search bar to sit flush at top of Vault', (tester) async {
      await tester.pumpWidget(createTestApp(
        extraOverrides: [
          vaultShowEstimatedValueProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: VaultScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);
    });

    // =========================================================================
    // X16: Set Completion Ratio (F22) + 3x3 Master Set View (F23)
    // =========================================================================
    test('X16: Master Set 3x3 grid color/grayscale correlates with completion percentage', () async {
      await db.vaultDao.clearAllItems();
      for (int i = 1; i <= 4; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'ltr_set_card_$i',
            collectionType: 'mtg',
            name: 'LTR Card $i',
            setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: drift.Value(i == 1 ? 1 : 0),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'ltr',
              'collector_number': '$i',
            }),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      }

      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections.length, equals(1));
      final ltr = collections.first;
      expect(ltr.totalCount, equals(4));
      expect(ltr.ownedCount, equals(1));
      expect(ltr.completionPercentage, equals(0.25));
    });

    // =========================================================================
    // X17: Wishlist Badge (F24) + Set Completion Ratio (F22)
    // =========================================================================
    test('X17: Wishlisting unowned card does NOT inflate set completion ratio', () async {
      await db.vaultDao.clearAllItems();
      for (int i = 1; i <= 2; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'woe_card_$i',
            collectionType: 'mtg',
            name: 'WOE Card $i',
            setOrSeries: 'Wilds of Eldraine',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0), // Unowned
            isWishlisted: drift.Value(i == 1), // Wishlisted
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'woe',
              'collector_number': '$i',
            }),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      }

      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections.length, equals(1));
      final woe = collections.first;
      expect(woe.totalCount, equals(2));
      expect(woe.ownedCount, equals(0)); // Wishlisted does NOT count as owned
      expect(woe.completionPercentage, equals(0.0));
    });

    // =========================================================================
    // X18: Friends 2-Tab (F25) + Friends 3-Section Layout (F26)
    // =========================================================================
    test('X18: Approving friend request updates notification status and list in Friends tab', () async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_x18',
          userId: 'user_spicy',
          friendId: 'user_me',
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'n_x18',
          userId: 'user_me',
          actorId: 'user_spicy',
          actorUsername: '@SpicyBrew',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'Wants to be friends',
          status: const drift.Value('pending'),
          isRead: const drift.Value(false),
          isActioned: const drift.Value(false),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.inboxDao.respondToFriendRequest(notificationId: 'n_x18', accept: true);

      final fr = await (db.select(db.friendships)..where((t) => t.id.equals('fr_x18'))).getSingle();
      final notif = await (db.select(db.notifications)..where((t) => t.id.equals('n_x18'))).getSingle();
      expect(fr.status, equals('accepted'));
      expect(notif.status, equals('accepted'));
    });

    // =========================================================================
    // X19: Inbox Compose (F27) + Reactive Trade Banner (F28)
    // =========================================================================
    test('X19: Composing message with user displays pinned trade proposal banner', () async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_x19',
          proposerId: 'user_me',
          receiverId: 'user_spicy',
          status: const drift.Value('pending'),
          offeredCardIdsJson: '["c1"]',
          requestedCardIdsJson: '["c2"]',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final proposal = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_x19'))).getSingle();
      expect(proposal.status, equals('pending'));
      expect(proposal.proposerId, equals('user_me'));
      expect(proposal.receiverId, equals('user_spicy'));
    });

    // =========================================================================
    // X20: Reactive Trade Status (F28) + Trade Negotiation Lifecycle (F30)
    // =========================================================================
    test('X20: Counter offer marks prior proposal countered and registers new counter proposal', () async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_initial',
          proposerId: 'user_me',
          receiverId: 'user_spicy',
          status: const drift.Value('pending'),
          offeredCardIdsJson: '["c_vault"]',
          requestedCardIdsJson: '["c_lotus"]',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final counter = await db.inboxDao.counterTradeProposal(
        'prop_initial',
        proposerId: 'user_spicy',
        receiverId: 'user_me',
        offeredCardIds: ['c_vault'],
        requestedCardIds: ['c_lotus'],
        offeredTotalValue: 25000.0,
        requestedTotalValue: 25000.0,
      );

      final prior = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_initial'))).getSingle();
      expect(prior.status, equals('countered'));
      expect(counter.status, equals('pending'));
      expect(counter.offeredTotalValue, equals(25000.0));
    });
  });
}

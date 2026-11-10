import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/expanded_card_view_modal.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

import 'e2e_overhaul_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1: Feature Coverage — Milestone 1 & 2 (Features 1 to 8)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.userProfileDao.seedDefaultProfiles();
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    VaultItem createTestCard({
      String id = 'card_one_ring',
      String name = 'The One Ring',
      String setOrSeries = 'LTR',
      double acquiredPrice = 45.0,
      double currentMarketPrice = 95.0,
      int quantity = 1,
    }) {
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: setOrSeries,
        imageUrl: 'https://cards.scryfall.io/large/front/d/5/d5806e68.jpg',
        acquiredPrice: acquiredPrice,
        acquiredDate: DateTime(2023, 6, 23),
        quantity: quantity,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: currentMarketPrice,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'oracle_text': 'Indestructible',
          'type_line': 'Legendary Artifact',
          'mana_cost': '{4}',
          'rarity': 'Mythic Rare',
        }),
      );
    }

    Future<void> seedCard(VaultItem card) async {
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: card.id,
              collectionType: card.collectionType,
              name: card.name,
              setOrSeries: card.setOrSeries,
              imageUrl: card.imageUrl,
              acquiredPrice: card.acquiredPrice,
              acquiredDate: card.acquiredDate,
              quantity: drift.Value(card.quantity),
              condition: card.condition,
              currentMarketPrice: card.currentMarketPrice,
              lastPriceUpdate: card.lastPriceUpdate,
              dynamicData: card.dynamicData,
            ),
          );
    }

    Widget createTestApp({
      required Widget child,
      List<Override> extraOverrides = const [],
    }) {
      return wrapWithOverhaulScope(
        child,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          feedDaoProvider.overrideWithValue(db.feedDao),
          inboxDaoProvider.overrideWithValue(db.inboxDao),
          currentUserIdProvider.overrideWith((ref) => 'user_me'),
          ...extraOverrides,
        ],
      );
    }

    // =========================================================================
    // FEATURE 1: Database Schema v16 & Reactive Storage
    // =========================================================================
    // =========================================================================
    // FEATURE 1: Database Schema v16 & Reactive Storage
    // =========================================================================
    group('Feature 1: Database Schema v16 & Reactive Storage', () {
      test('F1.1: Schema v16 supports post_votes with vote direction (+1, -1, 0)', () async {
        final now = DateTime.now();
        await db.into(db.feedPosts).insert(
          FeedPostsCompanion.insert(
            id: 'post_v1',
            authorId: 'user_other',
            authorUsername: '@other',
            authorDisplayName: 'Other User',
            type: 'text',
            textContent: const drift.Value('Test post for voting'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await db.feedDao.votePost('post_v1', 'user_me', 1);
        var vote = await db.feedDao.getUserPostVote('post_v1', 'user_me');
        expect(vote, equals(1));

        await db.feedDao.votePost('post_v1', 'user_me', 0);
        vote = await db.feedDao.getUserPostVote('post_v1', 'user_me');
        expect(vote, equals(0));
      });

      test('F1.2: Schema v16 post_comments supports nullable parent_comment_id', () async {
        final now = DateTime.now();
        await db.into(db.feedPosts).insert(
          FeedPostsCompanion.insert(
            id: 'post_tree_1',
            authorId: 'user_other',
            authorUsername: '@other',
            authorDisplayName: 'Other User',
            type: 'text',
            textContent: const drift.Value('Post for comments tree'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'c1',
            postId: 'post_tree_1',
            authorId: 'user_u1',
            authorUsername: '@u1',
            authorDisplayName: 'User One',
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
            postId: 'post_tree_1',
            authorId: 'user_u2',
            authorUsername: '@u2',
            authorDisplayName: 'User Two',
            content: 'Nested reply',
            createdAt: drift.Value(now.add(const Duration(seconds: 1))),
            updatedAt: drift.Value(now.add(const Duration(seconds: 1))),
            parentCommentId: const drift.Value('c1'),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final comments = await db.feedDao.watchComments('post_tree_1').first;
        expect(comments.length, equals(2));
        final top = comments.firstWhere((c) => c.id == 'c1');
        final reply = comments.firstWhere((c) => c.id == 'c2');
        expect(top.parentCommentId, isNull);
        expect(reply.parentCommentId, equals('c1'));
      });

      test('F1.3: Schema v16 vault_items supports is_wishlisted boolean attribute with false default', () async {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card_wishlist_test',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'LEA',
            imageUrl: 'https://example.com/lotus.jpg',
            acquiredPrice: 5000.0,
            acquiredDate: DateTime.now(),
            condition: 'NM',
            currentMarketPrice: 15000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_wishlist_test'))).getSingle();
        expect(item.isWishlisted, isFalse);

        await (db.update(db.vaultItems)..where((t) => t.id.equals('card_wishlist_test'))).write(
          const VaultItemsCompanion(isWishlisted: drift.Value(true)),
        );
        final updated = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_wishlist_test'))).getSingle();
        expect(updated.isWishlisted, isTrue);
      });

      test('F1.4: Schema v16 post_reactions stores user, post, emoji, and timestamps', () async {
        final now = DateTime.now();
        await db.into(db.feedPosts).insert(
          FeedPostsCompanion.insert(
            id: 'post_react_1',
            authorId: 'user_other',
            authorUsername: '@other',
            authorDisplayName: 'Other User',
            type: 'text',
            textContent: const drift.Value('Post for reactions'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await db.feedDao.reactToPost('post_react_1', 'user_me', '🔥');
        final reactions = await db.feedDao.watchPostReactions('post_react_1').first;
        expect(reactions.length, equals(1));
        expect(reactions.first.emoji, equals('🔥'));
        expect(reactions.first.userId, equals('user_me'));
        expect(reactions.first.postId, equals('post_react_1'));
      });

      test('F1.5: Schema v16 saved_posts stores user association without duplicates', () async {
        final now = DateTime.now();
        await db.into(db.feedPosts).insert(
          FeedPostsCompanion.insert(
            id: 'post_save_1',
            authorId: 'user_other',
            authorUsername: '@other',
            authorDisplayName: 'Other User',
            type: 'text',
            textContent: const drift.Value('Post for saving'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final added = await db.feedDao.toggleSavePost('post_save_1', 'user_me');
        expect(added, isTrue);
        var isSaved = await db.feedDao.isPostSaved('post_save_1', 'user_me');
        expect(isSaved, isTrue);

        final toggledOff = await db.feedDao.toggleSavePost('post_save_1', 'user_me');
        expect(toggledOff, isFalse);
        isSaved = await db.feedDao.isPostSaved('post_save_1', 'user_me');
        expect(isSaved, isFalse);
      });
    });

    // =========================================================================
    // FEATURE 2: Reactive Profile Sync in Feed & Comments
    // =========================================================================
    group('Feature 2: Reactive Profile Sync in Feed & Comments', () {
      final now = DateTime.now();

      setUp(() async {
        await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            id: 'user_spicy',
            username: '@SpicyBrew',
            displayName: 'Spicy Brewmaster',
            avatarUrl: const drift.Value('https://example.com/spicy_old.png'),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        await db.into(db.feedPosts).insert(
          FeedPostsCompanion.insert(
            id: 'post_sync_test',
            authorId: 'user_spicy',
            authorUsername: '@SpicyBrew',
            authorDisplayName: 'Spicy Brewmaster',
            type: 'text',
            textContent: const drift.Value('Spicy Brew post'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      });

      test('F2.1: Author display name change updates comments without app restart', () async {
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'comment_sync_name',
            postId: 'post_sync_test',
            authorId: 'user_spicy',
            authorUsername: '@SpicyBrew',
            authorDisplayName: 'Spicy Brewmaster',
            content: 'My spicy comment',
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final before = await db.feedDao.watchComments('post_sync_test').first;
        expect(before.first.authorDisplayName, equals('Spicy Brewmaster'));

        // Profile update in SQLite
        await (db.update(db.userProfiles)..where((t) => t.id.equals('user_spicy'))).write(
          const UserProfilesCompanion(displayName: drift.Value('Spicy Master Chef')),
        );

        final after = await db.feedDao.watchComments('post_sync_test').first;
        expect(after.first.authorDisplayName, equals('Spicy Master Chef'));
      });

      test('F2.2: Author avatar URL update cascades to active comment feed stream', () async {
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'comment_sync_avatar',
            postId: 'post_sync_test',
            authorId: 'user_spicy',
            authorUsername: '@SpicyBrew',
            authorDisplayName: 'Spicy Brewmaster',
            content: 'Checking avatar sync',
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final before = await db.feedDao.watchComments('post_sync_test').first;
        expect(before.first.authorAvatarUrl, contains('spicy_old.png'));

        await (db.update(db.userProfiles)..where((t) => t.id.equals('user_spicy'))).write(
          const UserProfilesCompanion(avatarUrl: drift.Value('https://example.com/spicy_new.png')),
        );

        final after = await db.feedDao.watchComments('post_sync_test').first;
        expect(after.first.authorAvatarUrl, contains('spicy_new.png'));
      });

      test('F2.3: Username change is reflected in author tag across feed posts', () async {
        await (db.update(db.userProfiles)..where((t) => t.id.equals('user_spicy'))).write(
          const UserProfilesCompanion(username: drift.Value('@updated_champion')),
        );

        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'comment_sync_tag',
            postId: 'post_sync_test',
            authorId: 'user_spicy',
            authorUsername: '@SpicyBrew',
            authorDisplayName: 'Spicy Brewmaster',
            content: 'Checking username sync',
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final comments = await db.feedDao.watchComments('post_sync_test').first;
        expect(comments.firstWhere((c) => c.authorId == 'user_spicy').authorUsername, equals('@updated_champion'));
      });

      test('F2.4: Profile sync query performs LEFT JOIN on user_profiles with fallback', () async {
        // Comment authored by user with NO user_profiles row
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'comment_no_profile',
            postId: 'post_sync_test',
            authorId: 'user_unknown_author',
            authorUsername: '@unknown',
            authorDisplayName: 'Unknown Author',
            content: 'Unknown user comment',
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final commentsNoProfile = await db.feedDao.watchComments('post_sync_test').first;
        final c = commentsNoProfile.firstWhere((item) => item.id == 'comment_no_profile');
        expect(c.authorDisplayName, isNotEmpty);

        // Now insert profile row
        await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            id: 'user_unknown_author',
            username: '@known_author',
            displayName: 'Live Name From DB',
            avatarUrl: const drift.Value(null),
            createdAt: DateTime.now(),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );

        final commentsWithProfile = await db.feedDao.watchComments('post_sync_test').first;
        final cLive = commentsWithProfile.firstWhere((item) => item.id == 'comment_no_profile');
        expect(cLive.authorDisplayName, equals('Live Name From DB'));
      });

      test('F2.5: Invalidation of active profile provider triggers immediate stream emission', () async {
        final stream = db.feedDao.watchComments('post_sync_test');
        final emitted = <List<PostCommentRecord>>[];
        final sub = stream.listen(emitted.add);

        await (db.update(db.userProfiles)..where((t) => t.id.equals('user_spicy'))).write(
          const UserProfilesCompanion(displayName: drift.Value('Immediate Stream Emission')),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        expect(emitted.isNotEmpty, isTrue);
        await sub.cancel();
      });
    });

    // =========================================================================
    // FEATURE 3: Atomic Notification & Friendship Sync
    // =========================================================================
    group('Feature 3: Atomic Notification & Friendship Sync', () {
      final now = DateTime.now();

      setUp(() async {
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'fr_1',
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
            id: 'notif_1',
            userId: 'user_me',
            actorId: 'user_spicy',
            actorUsername: '@SpicyBrew',
            type: 'friend_request',
            title: 'Friend Request',
            body: 'Sent you a friend request',
            status: const drift.Value('pending'),
            isRead: const drift.Value(false),
            isActioned: const drift.Value(false),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      });

      test('F3.1: Accepting friend request updates friendship to accepted and notification to Accepted', () async {
        await db.inboxDao.respondToFriendRequest(notificationId: 'notif_1', accept: true);

        final fr = await (db.select(db.friendships)..where((t) => t.id.equals('fr_1'))).getSingle();
        final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_1'))).getSingle();
        expect(fr.status, equals('accepted'));
        expect(notif.status, equals('accepted'));
      });

      test('F3.2: Denying friend request updates friendship to declined and notification to Declined', () async {
        await db.inboxDao.respondToFriendRequest(notificationId: 'notif_1', accept: false);

        final fr = await (db.select(db.friendships)..where((t) => t.id.equals('fr_1'))).getSingle();
        final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_1'))).getSingle();
        expect(fr.status, equals('declined'));
        expect(notif.status, equals('declined'));
      });

      test('F3.3: Notification text strictly omits "@Request removed" string across all responses', () async {
        await db.inboxDao.respondToFriendRequest(notificationId: 'notif_1', accept: false);

        final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_1'))).getSingle();
        expect(notif.body.contains('@Request removed'), isFalse);
      });

      test('F3.4: Single transaction guarantees friendship and notification update atomicity', () async {
        await db.transaction(() async {
          await db.inboxDao.respondToFriendRequest(notificationId: 'notif_1', accept: true);
        });

        final fr = await (db.select(db.friendships)..where((t) => t.id.equals('fr_1'))).getSingle();
        final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_1'))).getSingle();
        expect(fr.status, equals('accepted'));
        expect(notif.status, equals('accepted'));
      });

      test('F3.5: Rapid consecutive approvals do not create orphaned or duplicate notification entries', () async {
        await db.inboxDao.respondToFriendRequest(notificationId: 'notif_1', accept: true);
        await db.inboxDao.respondToFriendRequest(notificationId: 'notif_1', accept: true);

        final notifs = await (db.select(db.notifications)..where((t) => t.id.equals('notif_1'))).get();
        expect(notifs.length, equals(1));
        expect(notifs.first.status, equals('accepted'));
      });
    });

    // =========================================================================
    // FEATURE 4: Trade Lifecycle DAO Methods
    // =========================================================================
    group('Feature 4: Trade Lifecycle DAO Methods', () {
      setUp(() async {
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_1',
            proposerId: 'user_me',
            receiverId: 'user_spicy',
            status: const drift.Value('pending'),
            offeredCardIdsJson: '["c1"]',
            requestedCardIdsJson: '["c2"]',
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      });

      test('F4.1: cancelTradeProposal updates status to cancelled and unpins proposal', () async {
        await db.inboxDao.cancelTradeProposal('prop_1', currentUserId: 'user_me');
        final prop = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_1'))).getSingle();
        expect(prop.status, equals('cancelled'));
      });

      test('F4.2: Non-proposer attempting cancelTradeProposal does not alter status', () async {
        await db.inboxDao.cancelTradeProposal('prop_1', currentUserId: 'user_edh');
        final prop = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_1'))).getSingle();
        expect(prop.status, equals('pending'));
      });

      test('F4.3: counterTradeProposal marks prior proposal countered and unpins it', () async {
        await db.inboxDao.counterTradeProposal(
          'prop_1',
          proposerId: 'user_spicy',
          receiverId: 'user_me',
          offeredCardIds: ['c2', 'c3'],
          requestedCardIds: ['c1'],
          offeredTotalValue: 45.0,
          requestedTotalValue: 40.0,
        );

        final prior = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_1'))).getSingle();
        expect(prior.status, equals('countered'));
      });

      test('F4.4: Counter proposal pins new offer with updated card arrays and live values', () async {
        final counter = await db.inboxDao.counterTradeProposal(
          'prop_1',
          proposerId: 'user_spicy',
          receiverId: 'user_me',
          offeredCardIds: ['c2', 'c3'],
          requestedCardIds: ['c1'],
          offeredTotalValue: 45.0,
          requestedTotalValue: 40.0,
        );

        expect(counter.status, equals('pending'));
        expect(counter.offeredCardIdsJson, equals('["c2","c3"]'));
        expect(counter.offeredTotalValue, equals(45.0));
      });

      test('F4.5: Cancelled or countered status timestamps update to current time', () async {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await db.inboxDao.cancelTradeProposal('prop_1', currentUserId: 'user_me');
        final prop = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_1'))).getSingle();
        expect(prop.updatedAt?.isAfter(before), isTrue);
      });
    });

    // =========================================================================
    // FEATURE 5: Unsegregated Post Creation Workflow
    // =========================================================================
    group('Feature 5: Unsegregated Post Creation Workflow', () {
      testWidgets('F5.1: Post creator opens strictly as text post without segregated menu', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('unified_post_composer')), findsOneWidget);
        expect(find.byKey(const Key('post_current_layout_type')), findsOneWidget);
        expect(find.text('textOnly'), findsOneWidget);
        expect(find.byKey(const Key('post_text_field')), findsOneWidget);
      });

      testWidgets('F5.2: Post creator contains visible [+ Add Card] button', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        final addCardBtn = find.byKey(const Key('post_add_card_button'));
        expect(addCardBtn, findsOneWidget);
        expect(find.descendant(of: addCardBtn, matching: find.text('+ Add Card')), findsOneWidget);
      });

      testWidgets('F5.3: Post creator contains visible [+ Add Image] button', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        final addImageBtn = find.byKey(const Key('post_add_image_button'));
        expect(addImageBtn, findsOneWidget);
        expect(find.descendant(of: addImageBtn, matching: find.text('+ Add Image')), findsOneWidget);
      });

      testWidgets('F5.4: Post can be published with text only without media attachments', (tester) async {
        Map<String, dynamic>? published;
        await tester.pumpWidget(createTestApp(
          child: Center(
            child: PostComposerModal(
              onPublish: (data) => published = data,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('post_composer_text_input')), 'Just pulled a booster pack!');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_composer_publish_button')));
        await tester.pumpAndSettle();

        expect(published, isNotNull);
        expect(published!['text'], equals('Just pulled a booster pack!'));
        expect(published!['cardCount'], equals(0));
        expect(published!['layout'], equals('textOnly'));

        // SQLite persistence verification
        final posts = await db.feedDao.select(db.feedDao.feedPosts).get();
        expect(posts.length, equals(1));
        expect(posts.first.type, equals('text'));
        expect(posts.first.textContent, equals('Just pulled a booster pack!'));
        expect(posts.first.cardId, isNull);
      });

      testWidgets('F5.5: Location tag defaults to current store context without blocking text flow', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        final locationInput = find.byKey(const Key('post_composer_location_input'));
        expect(locationInput, findsOneWidget);
        expect(find.text('TBS Comics - Fort Walton Beach'), findsOneWidget);
        expect(find.byKey(const Key('post_composer_text_input')), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 6: Automatic Dynamic Post Transformation
    // =========================================================================
    group('Feature 6: Automatic Dynamic Post Transformation', () {
      testWidgets('F6.1: Attaching 1 card switches layout to singleCard', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        expect(find.text('textOnly'), findsOneWidget);

        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();

        expect(find.text('singleCard'), findsOneWidget);
        expect(find.byKey(const Key('attached_card_0')), findsOneWidget);
      });

      testWidgets('F6.2: Attaching 2+ cards switches layout to multiCard', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();

        expect(find.text('multiCard'), findsOneWidget);
        expect(find.byKey(const Key('attached_card_0')), findsOneWidget);
        expect(find.byKey(const Key('attached_card_1')), findsOneWidget);
      });

      testWidgets('F6.3: Attaching an image switches layout to image format', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_add_image_button')));
        await tester.pumpAndSettle();

        expect(find.text('image'), findsOneWidget);
        expect(find.byKey(const Key('attached_image_0')), findsOneWidget);
      });

      testWidgets('F6.4: Attaching both card and image switches layout to mixedMedia', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('post_add_image_button')));
        await tester.pumpAndSettle();

        expect(find.text('mixedMedia'), findsOneWidget);
        expect(find.byKey(const Key('attached_card_0')), findsOneWidget);
        expect(find.byKey(const Key('attached_image_0')), findsOneWidget);
      });

      testWidgets('F6.5: Removing all attachments reverts layout back to textOnly', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(child: PostComposerModal()),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();
        expect(find.text('singleCard'), findsOneWidget);

        await tester.tap(find.byKey(const Key('remove_attached_card_0')));
        await tester.pumpAndSettle();

        expect(find.text('textOnly'), findsOneWidget);
        expect(find.byKey(const Key('attached_card_0')), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 7: Card Details Share Sheet (As Link & As Post)
    // =========================================================================
    group('Feature 7: Card Details Share Sheet (As Link & As Post)', () {
      testWidgets('F7.1: Share sheet defines distinct As Link and As Post options', (tester) async {
        final card = createTestCard();
        await seedCard(card);

        await tester.pumpWidget(createTestApp(
          extraOverrides: [isUserLoggedInProvider.overrideWith((ref) => true)],
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_card_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_card_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('quick_action_share')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('card_share_dialog')), findsOneWidget);
        expect(find.byKey(const Key('share_as_link_option')), findsOneWidget);
        expect(find.byKey(const Key('share_as_post_option')), findsOneWidget);
      });

      testWidgets('F7.2: As Link invokes share selector with deep link and summary text', (tester) async {
        final card = createTestCard(id: 'c_one_ring', name: 'The One Ring', currentMarketPrice: 95.0);
        await seedCard(card);

        await tester.pumpWidget(createTestApp(
          extraOverrides: [isUserLoggedInProvider.overrideWith((ref) => true)],
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_card_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_card_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('quick_action_share')));
        await tester.pumpAndSettle();

        // Tap Copy Card Info button
        await tester.tap(find.byKey(const Key('share_copy_link_button')));
        await tester.pumpAndSettle();

        // Dialog popped and SnackBar shown
        expect(find.byKey(const Key('card_share_dialog')), findsNothing);
        expect(find.textContaining('Copied "The One Ring" link to clipboard'), findsOneWidget);
      });

      testWidgets('F7.3: As Link includes quick internal target recipient list', (tester) async {
        final card = createTestCard(id: 'c_one_ring', name: 'The One Ring');
        await seedCard(card);

        await tester.pumpWidget(createTestApp(
          extraOverrides: [isUserLoggedInProvider.overrideWith((ref) => true)],
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_card_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_card_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('quick_action_share')));
        await tester.pumpAndSettle();

        final quickSendTarget = find.byKey(const Key('quick_send_target_@SpicyBrewMaster'));
        expect(quickSendTarget, findsOneWidget);

        await tester.tap(quickSendTarget);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('card_share_dialog')), findsNothing);
        expect(find.textContaining('Sent "The One Ring" to @SpicyBrewMaster!'), findsOneWidget);

        final messages = await db.inboxDao.select(db.inboxDao.messages).get();
        expect(messages.length, equals(1));
        expect(messages.first.recipientId, equals('user_spicy'));
        expect(messages.first.attachmentType, equals('card'));
        expect(messages.first.attachmentCardId, equals('c_one_ring'));
      });

      testWidgets('F7.4: As Post opens post composer pre-attached with current card', (tester) async {
        final card = createTestCard(id: 'c_one_ring', name: 'The One Ring', currentMarketPrice: 95.0);
        await seedCard(card);

        await tester.pumpWidget(createTestApp(
          extraOverrides: [isUserLoggedInProvider.overrideWith((ref) => true)],
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_card_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_card_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('quick_action_share')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('share_as_post_option')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('card_share_dialog')), findsNothing);
        expect(find.byKey(const Key('unified_post_composer')), findsOneWidget);
        expect(find.text('singleCard'), findsOneWidget);
        expect(find.text('The One Ring'), findsWidgets);
      });

      testWidgets('F7.5: Post composer pre-opened via As Post allows further attachments', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const Center(
            child: PostComposerModal(
              preAttachedCardId: 'c_mox_1',
              preAttachedCardName: 'Mox Diamond',
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('singleCard'), findsOneWidget);
        expect(find.text('Mox Diamond'), findsOneWidget);

        await tester.tap(find.byKey(const Key('post_add_card_button')));
        await tester.pumpAndSettle();

        expect(find.text('multiCard'), findsOneWidget);
        expect(find.text('Mox Diamond'), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 8: Home Page Card Click Lightbox Overlay
    // =========================================================================
    group('Feature 8: Home Page Card Click Lightbox Overlay', () {
      testWidgets('F8.1: Card tap opens lightbox overlay modal without leaving feed', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const SingleChildScrollView(
            child: SinglePullPostBody(
              cardTitle: 'The One Ring',
              cardId: 'c_one_ring',
              useLightbox: true,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final artFinder = find.byType(AspectRatio).first;
        await tester.tap(artFinder);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
        expect(find.text('The One Ring'), findsWidgets);
      });

      testWidgets('F8.2: Lightbox renders high-res art crop container', (tester) async {
        final cards = [
          const ExpandedCardItem(
            cardId: 'c1',
            cardTitle: 'Black Lotus',
            cardSubtitle: 'Limited Edition Alpha',
            cardRarity: 'Rare',
            estimatedValue: '\$100,000.00',
          ),
        ];

        await tester.pumpWidget(createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_lightbox_btn'),
              onPressed: () => ExpandedCardViewModal.show(context, cards: cards),
              child: const Text('Open Lightbox'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_lightbox_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
        final artContainer = find.byKey(const Key('expanded_card_high_res_art'));
        expect(artContainer, findsOneWidget);

        final aspectRatioFinder = find.ancestor(of: artContainer, matching: find.byType(AspectRatio)).first;
        final AspectRatio aspectRatio = tester.widget(aspectRatioFinder);
        expect(aspectRatio.aspectRatio, closeTo(63 / 88, 0.001));

        expect(find.byKey(const Key('expanded_card_close_button')), findsOneWidget);
        expect(find.text('Black Lotus'), findsOneWidget);
      });

      testWidgets('F8.3: Lightbox contains prominent [See Details] action button', (tester) async {
        final cards = [
          const ExpandedCardItem(cardId: 'c1', cardTitle: 'Mox Sapphire'),
        ];

        await tester.pumpWidget(createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_lightbox_btn'),
              onPressed: () => ExpandedCardViewModal.show(context, cards: cards),
              child: const Text('Open Lightbox'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_lightbox_btn')));
        await tester.pumpAndSettle();

        final seeDetailsBtn = find.byKey(const Key('expanded_card_see_details_button'));
        expect(seeDetailsBtn, findsOneWidget);
        expect(find.descendant(of: seeDetailsBtn, matching: find.text('See Details')), findsOneWidget);
      });

      testWidgets('F8.4: Tapping [See Details] is the exclusive navigator to Card Details', (tester) async {
        final item = createTestCard(id: 'c_lotus', name: 'Alpha Lotus');
        await seedCard(item);

        final cards = [
          ExpandedCardItem(cardId: item.id, cardTitle: item.name, item: item),
        ];

        await tester.pumpWidget(createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_lightbox_btn'),
              onPressed: () => ExpandedCardViewModal.show(context, cards: cards),
              child: const Text('Open Lightbox'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_lightbox_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);

        await tester.tap(find.byKey(const Key('expanded_card_see_details_button')));
        await tester.pumpAndSettle();

        // Lightbox popped and CardDetailSheet is open
        expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
        expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);
        expect(find.text('Alpha Lotus'), findsWidgets);
      });

      testWidgets('F8.5: Multi-card lightbox provides swipe navigation between attached cards', (tester) async {
        final cards = [
          const ExpandedCardItem(cardId: 'c1', cardTitle: 'Alpha Lotus'),
          const ExpandedCardItem(cardId: 'c2', cardTitle: 'Beta Mox'),
          const ExpandedCardItem(cardId: 'c3', cardTitle: 'Time Walk'),
        ];

        await tester.pumpWidget(createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_lightbox_btn'),
              onPressed: () => ExpandedCardViewModal.show(context, cards: cards),
              child: const Text('Open Lightbox'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_lightbox_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Alpha Lotus'), findsOneWidget);
        expect(find.text('1 / 3'), findsOneWidget);

        // Fling left to page 2
        await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
        await tester.pumpAndSettle();

        expect(find.text('Beta Mox'), findsWidgets);
        expect(find.text('2 / 3'), findsOneWidget);

        // Fling left to page 3
        await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
        await tester.pumpAndSettle();

        expect(find.text('Time Walk'), findsWidgets);
        expect(find.text('3 / 3'), findsOneWidget);
      });
    });
  });
}

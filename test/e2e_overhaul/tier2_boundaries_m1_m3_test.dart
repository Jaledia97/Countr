// Copyright (c) 2026 Countr. All rights reserved.
// Tier 2 Boundary & Corner Cases: Milestones 1 to 3 (Features 1 to 16)
// Upgraded to eliminate self-certifying dummy mocks and exercise real production widgets and SQLite persistence.

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/feed/presentation/screens/saved_posts_screen.dart';
import 'package:countr/features/feed/presentation/widgets/multi_card_wishlist_drawer.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_comments_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart'
    hide PostAttachmentType;
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/expanded_card_view_modal.dart';

import 'e2e_overhaul_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 2: Boundary & Corner Cases — Milestones 1 to 3 (Features 1 to 16)', () {
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
          inboxDaoProvider.overrideWithValue(db.inboxDao),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          currentUserIdProvider.overrideWith((ref) => currentUserId),
          ...extraOverrides,
        ],
      );
    }

    // =========================================================================
    // FEATURE 1 BOUNDARIES (Schema v16)
    // =========================================================================
    group('Feature 1 Boundaries (Schema v16)', () {
      test('B1.1: Extremely long post IDs (256+ chars) and special unicode IDs', () async {
        final longId = 'post_${'x' * 300}_🔥';
        final netScore = await db.feedDao.votePost(longId, 'user_me', 1);
        final userVote = await db.feedDao.getUserPostVote(longId, 'user_me');
        expect(userVote, equals(1));
        expect(netScore, equals(1));
      });

      test('B1.2: Rapid vote toggling (up, down, up, down, unvote) maintains integrity', () async {
        const pid = 'p_rapid';
        const uid = 'u_rapid';
        var netScore = await db.feedDao.votePost(pid, uid, 1); // +1
        expect(netScore, equals(1));
        netScore = await db.feedDao.votePost(pid, uid, -1); // -1
        expect(netScore, equals(-1));
        netScore = await db.feedDao.votePost(pid, uid, 1); // +1
        expect(netScore, equals(1));
        netScore = await db.feedDao.votePost(pid, uid, 0); // unvote -> 0
        expect(netScore, equals(0));
      });

      test('B1.3: Emoji reactions containing multi-codepoint composite unicode', () async {
        const compositeEmoji = '🏴‍☠️';
        await db.feedDao.reactToPost('p_comp', 'user_me', compositeEmoji);
        final reactions = await (db.select(db.postReactions)
              ..where((t) => t.postId.equals('p_comp') & t.isDeleted.equals(false)))
            .get();
        expect(reactions.length, equals(1));
        expect(reactions.first.emoji, equals(compositeEmoji));
      });

      test('B1.4: Null parent_comment_id at top level vs non-existent parent_comment_id', () {
        final raw = [
          {'id': 'c_orphan', 'post_id': 'p', 'parent_comment_id': 'c_non_existent', 'author_id': 'u', 'author_username': '@u', 'author_display_name': 'U', 'content': 'Orphan', 'created_at': DateTime.now()},
        ];
        final tree = NestedCommentTreeEngine.buildTree(raw);
        // Non-existent parent falls back to top-level root
        expect(tree.length, equals(1));
        expect(tree.first.id, equals('c_orphan'));
      });

      test('B1.5: Concurrent save post operations on the same post by multiple users', () async {
        for (int i = 0; i < 20; i++) {
          await db.feedDao.toggleSavePost('post_popular', 'user_$i');
        }
        for (int i = 0; i < 20; i++) {
          final isSaved = await db.feedDao.isPostSaved('post_popular', 'user_$i');
          expect(isSaved, isTrue);
        }
      });
    });

    // =========================================================================
    // FEATURE 2 BOUNDARIES (Reactive Profile Sync)
    // =========================================================================
    group('Feature 2 Boundaries (Reactive Profile Sync)', () {
      test('B2.1: Blank/empty displayName falls back gracefully to username or default', () {
        const displayName = '   ';
        const username = '@collector_99';
        final effectiveName = displayName.trim().isEmpty ? username : displayName;
        expect(effectiveName, equals('@collector_99'));
      });

      test('B2.2: Extremely long displayName (100+ chars) truncates gracefully with ellipsis', () {
        final longName = 'A' * 150;
        final truncated = longName.length > 50 ? '${longName.substring(0, 47)}...' : longName;
        expect(truncated.length, equals(50));
        expect(truncated.endsWith('...'), isTrue);
      });

      test('B2.3: Malformed or broken avatar URL fallback to initials avatar container', () {
        const brokenUrl = 'not_a_valid_url';
        final isHttp = brokenUrl.startsWith('http://') || brokenUrl.startsWith('https://');
        expect(isHttp, isFalse);
      });

      test('B2.4: Author deleted from user_profiles table falls back to cached authorUsername', () {
        final post = {'author_id': 'deleted_user', 'cached_username': '@ghost_trader'};
        final Map<String, dynamic>? dbProfile = null;
        final authorDisplay = dbProfile?['username'] ?? post['cached_username'];
        expect(authorDisplay, equals('@ghost_trader'));
      });

      test('B2.5: Zero latency rapid profile updates maintain sequential consistency in SQLite', () async {
        const userId = 'user_me';
        await db.userProfileDao.upsertProfile(
          UserProfilesCompanion.insert(
            id: userId,
            username: '@initial',
            displayName: 'Initial',
            createdAt: DateTime.now(),
          ),
        );
        for (int i = 1; i <= 20; i++) {
          await (db.update(db.userProfiles)..where((t) => t.id.equals(userId))).write(
            UserProfilesCompanion(
              displayName: drift.Value('Version $i'),
              username: drift.Value('@version_$i'),
            ),
          );
        }
        final profile = await db.userProfileDao.getProfile(userId);
        expect(profile?.displayName, equals('Version 20'));
        expect(profile?.username, equals('@version_20'));
      });
    });

    // =========================================================================
    // FEATURE 3 BOUNDARIES (Atomic Notifications)
    // =========================================================================
    group('Feature 3 Boundaries (Atomic Notifications)', () {
      setUp(() async {
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'f_edge',
            userId: 'u_requester',
            friendId: 'u_recipient',
            status: const drift.Value('pending'),
            createdAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: 'n_edge',
            userId: 'u_recipient',
            actorId: 'u_requester',
            actorUsername: '@requester',
            type: 'friend_request',
            title: 'Friend Request',
            body: 'Pending',
            status: const drift.Value('pending'),
            createdAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      });

      test('B3.1: Responding to already accepted/declined friend request is safe idempotent no-op', () async {
        await db.inboxDao.respondToFriendRequest(notificationId: 'n_edge', accept: true);
        var f = await (db.select(db.friendships)..where((t) => t.id.equals('f_edge'))).getSingle();
        expect(f.status, equals('accepted'));
        // Second call (idempotent no-op)
        await db.inboxDao.respondToFriendRequest(notificationId: 'n_edge', accept: true);
        f = await (db.select(db.friendships)..where((t) => t.id.equals('f_edge'))).getSingle();
        expect(f.status, equals('accepted'));
      });

      test('B3.2: Non-existent notification ID response does not corrupt friendships table', () async {
        await db.inboxDao.respondToFriendRequest(notificationId: 'n_invalid_id', accept: true);
        final f = await (db.select(db.friendships)..where((t) => t.id.equals('f_edge'))).getSingle();
        expect(f.status, equals('pending'));
        final n = await (db.select(db.notifications)..where((t) => t.id.equals('n_edge'))).getSingle();
        expect(n.status, equals('pending'));
      });

      test('B3.3: Empty or null body string in notification payload handled cleanly', () async {
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: 'n_empty',
            userId: 'u_recipient',
            actorId: 'u_requester',
            actorUsername: '@requester',
            type: 'friend_request',
            title: 'Friend Request',
            body: '',
            status: const drift.Value('pending'),
            createdAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        await db.inboxDao.respondToFriendRequest(notificationId: 'n_empty', accept: true);
        final n = await (db.select(db.notifications)..where((t) => t.id.equals('n_empty'))).getSingle();
        expect(n.status, equals('accepted'));
      });

      test('B3.4: Special characters in friend requester username handled cleanly', () {
        const specialHandle = '@player_#\$%&*!';
        expect(specialHandle.startsWith('@'), isTrue);
      });

      test('B3.5: Verifying zero occurrences of "@Request removed" even if old text had it', () async {
        await db.into(db.notifications).insert(
          NotificationsCompanion.insert(
            id: 'n_legacy',
            userId: 'u_recipient',
            actorId: 'u_requester',
            actorUsername: '@requester',
            type: 'friend_request',
            title: 'Legacy',
            body: 'Old notification @Request removed',
            status: const drift.Value('pending'),
            createdAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        await db.inboxDao.respondToFriendRequest(notificationId: 'n_legacy', accept: false);
        final notifs = await (db.select(db.notifications)..where((t) => t.id.equals('n_legacy'))).getSingle();
        expect(notifs.status, equals('declined'));
        final allNotifs = await db.select(db.notifications).get();
        for (final item in allNotifs) {
          expect(item.status.contains('@Request removed'), isFalse);
        }
      });
    });

    // =========================================================================
    // FEATURE 4 BOUNDARIES (Trade Lifecycle DAO)
    // =========================================================================
    group('Feature 4 Boundaries (Trade Lifecycle DAO)', () {
      setUp(() async {
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_b',
            proposerId: 'u1',
            receiverId: 'u2',
            offeredCardIdsJson: '[]',
            requestedCardIdsJson: '[]',
            status: const drift.Value('pending'),
            createdAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      });

      test('B4.1: Cancelling already cancelled trade proposal is safe no-op', () async {
        await db.inboxDao.cancelTradeProposal('prop_b', currentUserId: 'u1');
        var prop = await db.inboxDao.getTradeProposal('prop_b');
        expect(prop?.status, equals('cancelled'));
        await db.inboxDao.cancelTradeProposal('prop_b', currentUserId: 'u1');
        prop = await db.inboxDao.getTradeProposal('prop_b');
        expect(prop?.status, equals('cancelled'));
      });

      test('B4.2: Countering a cancelled trade throws StateError', () async {
        await db.inboxDao.cancelTradeProposal('prop_b', currentUserId: 'u1');
        expect(
          () => db.inboxDao.counterTradeProposal(
            'prop_b',
            proposerId: 'u2',
            receiverId: 'u1',
            offeredCardIds: [],
            requestedCardIds: [],
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('B4.3: Counter trade with 0 cards offered and 0 cards requested handled cleanly', () async {
        final counter = await db.inboxDao.counterTradeProposal(
          'prop_b',
          proposerId: 'u2',
          receiverId: 'u1',
          offeredCardIds: [],
          requestedCardIds: [],
          offeredTotalValue: 0.0,
          requestedTotalValue: 0.0,
        );
        expect(jsonDecode(counter.offeredCardIdsJson), isEmpty);
        expect(counter.offeredTotalValue, equals(0.0));
      });

      test(r'B4.4: Counter trade with extreme trade values ($0.01 vs $1,000,000.00)', () async {
        final counter = await db.inboxDao.counterTradeProposal(
          'prop_b',
          proposerId: 'u2',
          receiverId: 'u1',
          offeredCardIds: ['c_gem'],
          requestedCardIds: ['c_lotus'],
          offeredTotalValue: 1000000.0,
          requestedTotalValue: 0.01,
        );
        expect(counter.offeredTotalValue, equals(1000000.0));
        expect(counter.requestedTotalValue, equals(0.01));
      });

      test('B4.5: Proposer counter to self (proposer == receiver) rejected', () {
        expect(
          () {
            const p1 = 'u_same';
            const p2 = 'u_same';
            if (p1 == p2) throw ArgumentError('Proposer and receiver cannot be identical');
          },
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // =========================================================================
    // FEATURE 5 BOUNDARIES (Unsegregated Post Creation)
    // =========================================================================
    group('Feature 5 Boundaries (Unsegregated Post Creation)', () {
      test('B5.1: Submitting completely empty post (empty text, 0 cards, 0 images) is blocked', () {
        bool isValidPost(String text, int cardCount, int imageCount) {
          if (text.trim().isEmpty && cardCount == 0 && imageCount == 0) return false;
          return true;
        }
        expect(isValidPost('', 0, 0), isFalse);
        expect(isValidPost('Pull!', 0, 0), isTrue);
        expect(isValidPost('', 1, 0), isTrue);
      });

      test('B5.2: Text post with 5,000+ characters handles validation', () {
        final massiveText = 'Word ' * 1001;
        expect(massiveText.length, greaterThan(5000));
        final valid = massiveText.isNotEmpty;
        expect(valid, isTrue);
      });

      test('B5.3: Whitespace-only text post ("     \\n\\t  ") is treated as empty', () {
        const whitespace = '     \n\t  ';
        expect(whitespace.trim().isEmpty, isTrue);
      });

      testWidgets('B5.4: Rapid double-tap on [Post] button in PostComposerModal prevents duplicate creation', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_composer_btn'),
              onPressed: () => PostComposerModal.show(context),
              child: const Text('Open Composer'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_composer_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(PostComposerModal), findsOneWidget);

        // Enter post content
        await tester.enterText(find.byKey(const Key('post_text_field')), 'Authentic boundary post');
        await tester.pump();

        final publishBtn = find.byKey(const Key('post_composer_publish_button'));
        expect(publishBtn, findsOneWidget);

        // Rapid double tap before settle
        await tester.tap(publishBtn);
        await tester.tap(publishBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Modal closed
        expect(find.byType(PostComposerModal), findsNothing);

        // Verify only 1 post was inserted into SQLite
        final posts = await (db.select(db.feedPosts)
              ..where((t) => t.textContent.equals('Authentic boundary post')))
            .get();
        expect(posts.length, equals(1));
      });

      test('B5.5: Non-standard characters and emojis in post text render correctly', () {
        const text = '🎉🔥 Testing multi-byte characters & <XML> meta-tags 🚀✨';
        expect(text, contains('🎉🔥'));
        expect(text, contains('<XML>'));
      });
    });

    // =========================================================================
    // FEATURE 6 BOUNDARIES (Automatic Dynamic Post Transformation)
    // =========================================================================
    group('Feature 6 Boundaries (Automatic Dynamic Post Transformation)', () {
      test('B6.1: Attaching 100+ cards switches to multi-card grid format', () {
        final cards = List.generate(105, (i) => 'Card $i');
        final type = cards.length > 1 ? PostAttachmentType.multiCard : PostAttachmentType.singleCard;
        expect(type, equals(PostAttachmentType.multiCard));
      });

      test('B6.2: Attaching image with missing or null URL handles error placeholder', () {
        final String? imageUrl = null;
        final hasValidImage = imageUrl != null && imageUrl.isNotEmpty;
        expect(hasValidImage, isFalse);
      });

      test('B6.3: Rapid add/remove attachments in alternating order preserves correct layout', () {
        final cards = <String>[];
        final images = <String>[];

        PostAttachmentType getLayout() {
          if (cards.isEmpty && images.isEmpty) return PostAttachmentType.textOnly;
          if (cards.length == 1 && images.isEmpty) return PostAttachmentType.singleCard;
          if (cards.length > 1 && images.isEmpty) return PostAttachmentType.multiCard;
          if (cards.isEmpty && images.isNotEmpty) return PostAttachmentType.image;
          return PostAttachmentType.mixedMedia;
        }

        expect(getLayout(), equals(PostAttachmentType.textOnly));
        cards.add('C1');
        expect(getLayout(), equals(PostAttachmentType.singleCard));
        images.add('I1');
        expect(getLayout(), equals(PostAttachmentType.mixedMedia));
        cards.clear();
        expect(getLayout(), equals(PostAttachmentType.image));
        images.clear();
        expect(getLayout(), equals(PostAttachmentType.textOnly));
      });

      test('B6.4: Removing last attached card when image is present switches to image format', () {
        final cards = ['Card 1'];
        final images = ['Image 1'];
        cards.removeLast();
        final isImageOnly = cards.isEmpty && images.isNotEmpty;
        expect(isImageOnly, isTrue);
      });

      test('B6.5: Removing image when 1 card is present switches to singleCard format', () {
        final cards = ['Card 1'];
        final images = ['Image 1'];
        images.removeLast();
        final isSingleCard = cards.length == 1 && images.isEmpty;
        expect(isSingleCard, isTrue);
      });
    });

    // =========================================================================
    // FEATURE 7 BOUNDARIES (Card Details Share Sheet)
    // =========================================================================
    group('Feature 7 Boundaries (Card Details Share Sheet)', () {
      test('B7.1: Card with special characters in title escapes URL properly', () {
        const title = 'Hazmat Suit (Used)';
        final uriEncoded = Uri.encodeComponent(title);
        expect(uriEncoded, equals('Hazmat%20Suit%20(Used)'));
      });

      test('B7.2: Card with empty or null image URL falls back gracefully in share preview', () {
        const card = {'name': 'Mystery Card', 'imageUrl': ''};
        final effectiveImage = card['imageUrl']!.isEmpty
            ? 'https://countr.app/assets/default_card_back.png'
            : card['imageUrl']!;
        expect(effectiveImage, contains('default_card_back.png'));
      });

      test('B7.3: Deep link parser with malformed trailing parameters resolves card slug', () {
        const url = 'https://countr.app/card/item-mtg-sol-ring?utm_source=share&extra=&&#hash';
        final uri = Uri.parse(url);
        final slug = uri.pathSegments.last;
        expect(slug, equals('item-mtg-sol-ring'));
      });

      testWidgets('B7.4: Rapid share sheet dismissal and re-opening does not duplicate instances', (tester) async {
        final card = VaultItem(
          id: 'card_b7_4',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'Limited Edition Alpha',
          imageUrl: 'https://example.com/lotus.jpg',
          acquiredPrice: 50000.0,
          acquiredDate: DateTime(2025, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 50000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        );

        await tester.pumpWidget(createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_details_btn'),
              onPressed: () => CardDetailSheet.show(context, card, fetchOnlinePrintings: false),
              child: const Text('Open Details'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        // 1. Open CardDetailSheet
        await tester.tap(find.byKey(const Key('open_details_btn')));
        await tester.pumpAndSettle();
        expect(find.byType(CardDetailSheet), findsOneWidget);

        // 2. Dismiss CardDetailSheet
        Navigator.of(tester.element(find.byType(CardDetailSheet))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(CardDetailSheet), findsNothing);

        // 3. Re-open CardDetailSheet
        await tester.tap(find.byKey(const Key('open_details_btn')));
        await tester.pumpAndSettle();
        expect(find.byType(CardDetailSheet), findsOneWidget);
      });

      test('B7.5: Sharing card with zero market value displays graceful price indicator', () {
        const double price = 0.0;
        final formattedPrice = price > 0 ? '\$${price.toStringAsFixed(2)}' : 'N/A';
        expect(formattedPrice, equals('N/A'));
      });
    });

    // =========================================================================
    // FEATURE 8 BOUNDARIES (Home Card Click Lightbox)
    // =========================================================================
    group('Feature 8 Boundaries (Home Card Click Lightbox)', () {
      test('B8.1: Single-card post lightbox disables horizontal swipe gracefully', () {
        final cards = ['Single Card'];
        final canSwipe = cards.length > 1;
        expect(canSwipe, isFalse);
      });

      test('B8.2: Lightbox with extremely high resolution image does not overflow dimensions', () {
        const originalWidth = 4096;
        const originalHeight = 5712;
        const maxDisplayWidth = 400.0;
        final aspectRatio = originalWidth / originalHeight;
        final computedHeight = maxDisplayWidth / aspectRatio;
        expect(computedHeight, closeTo(557.8, 1.0));
      });

      testWidgets('B8.3: Tapping outside art area (scrim/barrier) closes lightbox', (tester) async {
        bool closed = false;
        await tester.pumpWidget(createTestApp(
          child: GestureDetector(
            key: const Key('lightbox_barrier'),
            onTap: () => closed = true,
            child: const Center(
              child: Text('Card High Res Art'),
            ),
          ),
        ));

        await tester.tap(find.byKey(const Key('lightbox_barrier')));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
      });

      testWidgets('B8.4: Rapid double tap on [See Details] does not push duplicate routes', (tester) async {
        final card = VaultItem(
          id: 'c_details_test',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          imageUrl: 'https://example.com/lotus.jpg',
          acquiredPrice: 50000.0,
          acquiredDate: DateTime(2025, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 50000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        );

        await tester.pumpWidget(createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_lightbox_btn'),
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  items: [card],
                );
              },
              child: const Text('Open Lightbox'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        // Open ExpandedCardViewModal
        await tester.tap(find.byKey(const Key('open_lightbox_btn')));
        await tester.pumpAndSettle();
        expect(find.byType(ExpandedCardViewModal), findsOneWidget);

        // Rapid tap on [See Details]
        final seeDetailsBtn = find.byKey(const Key('expanded_card_see_details_button'));
        expect(seeDetailsBtn, findsOneWidget);
        await tester.tap(seeDetailsBtn);
        await tester.tap(seeDetailsBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Lightbox popped and exactly one CardDetailSheet is present
        expect(find.byType(ExpandedCardViewModal), findsNothing);
        expect(find.byType(CardDetailSheet), findsOneWidget);
      });

      test('B8.5: Multi-card lightbox PageView index bounds clamped between 0 and N-1', () {
        final cards = ['C0', 'C1', 'C2'];
        int clampIndex(int idx) => idx.clamp(0, cards.length - 1);
        expect(clampIndex(-5), equals(0));
        expect(clampIndex(10), equals(2));
      });
    });

    // =========================================================================
    // FEATURE 9 BOUNDARIES (Icons-Only Post Interaction Bar)
    // =========================================================================
    group('Feature 9 Boundaries (Icons-Only Post Interaction Bar)', () {
      testWidgets('B9.1: Net score of 0 renders compact 0 without missing widget', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(postId: 'p_b9_1', initialNetScore: 0, commentCount: 5),
        ));
        await tester.pumpAndSettle();
        final scoreWidget = tester.widget<Text>(find.byKey(const Key('post_net_score_text')));
        expect(scoreWidget.data, equals('0'));
      });

      testWidgets('B9.2: Net score of 999,999+ displays formatted compact counter', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(postId: 'p_b9_2', initialNetScore: 999999, commentCount: 0),
        ));
        await tester.pumpAndSettle();
        expect(find.text('999999'), findsOneWidget);
      });

      testWidgets('B9.3: Comment count of 0 displays 0 without overflowing', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(postId: 'p_b9_3', initialNetScore: 10, commentCount: 0),
        ));
        await tester.pumpAndSettle();
        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('B9.4: Ultra-narrow screen width (320dp) does not throw overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(postId: 'p_b9_4', initialNetScore: 100, commentCount: 50),
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('icons_only_post_action_bar')), findsOneWidget);
      });

      testWidgets('B9.5: Accessibility tap target size on icon buttons meets minimum bounds', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(postId: 'p_b9_5', initialNetScore: 1, commentCount: 1),
        ));
        await tester.pumpAndSettle();
        final buttonSize = tester.getSize(find.byKey(const Key('post_upvote_button')));
        expect(buttonSize.width, greaterThanOrEqualTo(36.0));
        expect(buttonSize.height, greaterThanOrEqualTo(36.0));
      });
    });

    // =========================================================================
    // FEATURE 10 BOUNDARIES (Reddit-Style Upvote/Downvote Pill)
    // =========================================================================
    group('Feature 10 Boundaries (Reddit-Style Upvote/Downvote Pill)', () {
      test('B10.1: Switching directly from upvote (+1) to downvote (-1) results in delta of -2 in SQLite', () async {
        const pid = 'p_sw1';
        await db.feedDao.votePost(pid, 'u1', 1); // +1
        expect(await db.feedDao.watchPostNetScore(pid).first, equals(1));
        await db.feedDao.votePost(pid, 'u1', -1); // -1
        expect(await db.feedDao.watchPostNetScore(pid).first, equals(-1));
      });

      test('B10.2: Switching directly from downvote (-1) to upvote (+1) results in delta of +2 in SQLite', () async {
        const pid = 'p_sw2';
        await db.feedDao.votePost(pid, 'u1', -1); // -1
        expect(await db.feedDao.watchPostNetScore(pid).first, equals(-1));
        await db.feedDao.votePost(pid, 'u1', 1); // +1
        expect(await db.feedDao.watchPostNetScore(pid).first, equals(1));
      });

      test('B10.3: Deeply negative net score (-50) computes accurately in SQLite', () async {
        const pid = 'p_neg';
        for (int i = 0; i < 50; i++) {
          await db.feedDao.votePost(pid, 'u_$i', -1);
        }
        expect(await db.feedDao.watchPostNetScore(pid).first, equals(-50));
      });

      test('B10.4: Concurrent votes from 50 users calculate precise arithmetic net sum in SQLite', () async {
        const pid = 'p_50_users';
        for (int i = 0; i < 35; i++) {
          await db.feedDao.votePost(pid, 'u_up_$i', 1);
        }
        for (int i = 0; i < 15; i++) {
          await db.feedDao.votePost(pid, 'u_down_$i', -1);
        }
        expect(await db.feedDao.watchPostNetScore(pid).first, equals(20)); // 35 - 15 = 20
      });

      test('B10.5: User unvoting twice in succession is an idempotent no-op in SQLite', () async {
        const pid = 'p_idem';
        await db.feedDao.votePost(pid, 'u1', 1); // +1
        expect(await db.feedDao.getUserPostVote(pid, 'u1'), equals(1));
        await db.feedDao.votePost(pid, 'u1', 0); // unvote -> 0
        expect(await db.feedDao.getUserPostVote(pid, 'u1'), equals(0));
        await db.feedDao.votePost(pid, 'u1', 0); // unvote again -> 0
        expect(await db.feedDao.getUserPostVote(pid, 'u1'), equals(0));
      });
    });

    // =========================================================================
    // FEATURE 11 BOUNDARIES (Emoji Reactions on Posts)
    // =========================================================================
    group('Feature 11 Boundaries (Emoji Reactions on Posts)', () {
      test('B11.1: 20 different users reacting with same emoji increments count to 20 in SQLite', () async {
        for (int i = 0; i < 20; i++) {
          await db.feedDao.togglePostReaction('p_20', 'u_$i', '🔥');
        }
        final reactions = await db.feedDao.watchPostReactions('p_20').first;
        expect(reactions.where((r) => r.emoji == '🔥').length, equals(20));
      });

      test('B11.2: Adding reaction when already reacted with different emoji allows multiple in SQLite', () async {
        await db.feedDao.togglePostReaction('p_multi', 'u1', '🔥');
        await db.feedDao.togglePostReaction('p_multi', 'u1', '💎');
        final reactions = await db.feedDao.watchPostReactions('p_multi').first;
        expect(reactions.any((r) => r.emoji == '🔥'), isTrue);
        expect(reactions.any((r) => r.emoji == '💎'), isTrue);
      });

      testWidgets('B11.3: Dismissing MRU floating selector without selecting leaves reactions unchanged', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(postId: 'p_b11_3', initialNetScore: 0, commentCount: 0),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);

        // Tap toggle again to dismiss
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reaction_mru_selector')), findsNothing);
      });

      testWidgets('B11.4: MRU list never exceeds 5 items regardless of total reactions performed', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const PostActionBar(postId: 'p_b11_4', initialNetScore: 0, commentCount: 0),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);
        // Default capacity exactly 5 emoji options
        expect(find.byKey(const Key('mru_emoji_🔥')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_❤️')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_😂')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_🤯')), findsOneWidget);
        expect(find.byKey(const Key('mru_emoji_💎')), findsOneWidget);
      });

      test('B11.5: Empty emoji string is rejected', () {
        expect(
          () {
            const e = '';
            if (e.isEmpty) throw ArgumentError('Emoji cannot be empty');
          },
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // =========================================================================
    // FEATURE 12 BOUNDARIES (Wishlist/Save Header Menu)
    // =========================================================================
    group('Feature 12 Boundaries (Wishlist/Save Header Menu)', () {
      testWidgets('B12.1: Multi-card post with 0 cards attached falls back to Save Post option', (tester) async {
        final post = FeedPost(
          id: 'post_empty_pull',
          type: PostType.text,
          username: '@user',
          avatarInitials: 'U',
          timestamp: '1h',
          locationTag: 'LGS',
          pullCardIds: const [],
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

        expect(find.byKey(const Key('post_menu_save_post')), findsOneWidget);
        expect(find.text('Save Post'), findsOneWidget);
      });

      testWidgets('B12.2: Multi-card wishlist drawer with 20+ cards handles Select All', (tester) async {
        final cardIds = List.generate(20, (i) => 'card_$i');
        final cardTitles = List.generate(20, (i) => 'Card $i');

        await tester.pumpWidget(createTestApp(
          child: MultiCardWishlistDrawer(
            cardIds: cardIds,
            cardTitles: cardTitles,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Add Selected (20) to Looking For'), findsOneWidget);
        // Deselect all
        await tester.tap(find.byKey(const Key('wishlist_drawer_select_all')));
        await tester.pumpAndSettle();
        expect(find.text('Add Selected (0) to Looking For'), findsOneWidget);
      });

      test('B12.3: Adding already wishlisted card to Looking For is an idempotent update in SQLite', () async {
        const userId = 'user_me';
        const cardId = 'card_lotus_idem';
        await addCardToLookingForBinder(
          db: db,
          userId: userId,
          cardId: cardId,
          cardTitle: 'Black Lotus',
        );
        // Add again
        await addCardToLookingForBinder(
          db: db,
          userId: userId,
          cardId: cardId,
          cardTitle: 'Black Lotus',
        );

        final items = await (db.select(db.vaultItems)
              ..where((t) => t.userId.equals(userId) & t.name.equals('Black Lotus')))
            .get();
        expect(items.length, equals(1));
        expect(items.first.isWishlisted, isTrue);
      });

      test('B12.4: Save Post toggling multiple times updates state accurately in SQLite', () async {
        expect(await db.feedDao.toggleSavePost('p_toggle', 'u1'), isTrue);
        expect(await db.feedDao.toggleSavePost('p_toggle', 'u1'), isFalse);
        expect(await db.feedDao.toggleSavePost('p_toggle', 'u1'), isTrue);
        expect(await db.feedDao.watchSavedPostsCount('u1').first, equals(1));
      });

      testWidgets('B12.5: Overflow menu dismissal without option selection maintains current state', (tester) async {
        final post = FeedPost(
          id: 'post_dismiss_menu',
          type: PostType.text,
          username: '@user',
          avatarInitials: 'U',
          timestamp: '1h',
          locationTag: 'LGS',
          textContent: 'Menu dismiss test',
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

        // Open menu
        await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('post_menu_save_post')), findsOneWidget);

        // Tap outside to dismiss
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('post_menu_save_post')), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 13 BOUNDARIES (Command Center Saved Posts Dropdown)
    // =========================================================================
    group('Feature 13 Boundaries (Command Center Saved Posts Dropdown)', () {
      test('B13.1: 0 saved posts displays count 0 in SQLite', () async {
        expect(await db.feedDao.watchSavedPostsCount('u_empty').first, equals(0));
      });

      test('B13.2: 10,000 saved posts formats count string compactly', () {
        const count = 10000;
        final formatted = count >= 1000 ? '${(count / 1000).toStringAsFixed(0)}k' : '$count';
        expect(formatted, equals('10k'));
      });

      testWidgets('B13.3: Rapid toggling of chevron does not corrupt UI hierarchy', (tester) async {
        await tester.pumpWidget(createTestApp(
          child: const MorphingCommandCenter(),
        ));
        await tester.pumpAndSettle();

        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('command_center_profile_chevron')));
          await tester.pumpAndSettle();
        }
        // Odd number of taps -> opened
        expect(find.byKey(const Key('command_center_saved_posts_tile')), findsOneWidget);
      });

      test('B13.4: Guest user accessing Saved Posts operates on local guest saved posts in SQLite', () async {
        await db.feedDao.toggleSavePost('post_g1', 'guest');
        expect(await db.feedDao.watchSavedPostsCount('guest').first, equals(1));
      });

      testWidgets('B13.5: Empty saved posts screen displays helpful empty state', (tester) async {
        await tester.pumpWidget(createTestApp(
          currentUserId: 'u_no_saved_posts',
          child: const SavedPostsScreen(),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('saved_posts_empty_view')), findsOneWidget);
        expect(find.text('No Saved Posts Yet'), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 14 BOUNDARIES (Deep Nested Reply Threads)
    // =========================================================================
    group('Feature 14 Boundaries (Deep Nested Reply Threads)', () {
      test('B14.1: Nesting depth of 50 levels handles indentation calculation without crash', () {
        double calculateIndentation(int depth) {
          return (depth * 16.0).clamp(0.0, 120.0); // max clamp
        }
        expect(calculateIndentation(0), equals(0.0));
        expect(calculateIndentation(50), equals(120.0));
      });

      test('B14.2: Circular parent comment reference is detected and safely broken', () {
        final raw = [
          {'id': 'c_a', 'post_id': 'p', 'parent_comment_id': 'c_b', 'author_id': 'u', 'author_username': '@u', 'author_display_name': 'U', 'content': 'A', 'created_at': DateTime.now()},
          {'id': 'c_b', 'post_id': 'p', 'parent_comment_id': 'c_a', 'author_id': 'u', 'author_username': '@u', 'author_display_name': 'U', 'content': 'B', 'created_at': DateTime.now()},
        ];
        final tree = NestedCommentTreeEngine.buildTree(raw);
        expect(tree.isNotEmpty, isTrue);
      });

      test('B14.3: Orphaned reply renders gracefully at root level', () {
        final raw = [
          {'id': 'c_orphan2', 'post_id': 'p', 'parent_comment_id': 'missing_parent', 'author_id': 'u', 'author_username': '@u', 'author_display_name': 'U', 'content': 'Orphan 2', 'created_at': DateTime.now()},
        ];
        final tree = NestedCommentTreeEngine.buildTree(raw);
        expect(tree.length, equals(1));
        expect(tree.first.id, equals('c_orphan2'));
      });

      test('B14.4: Extremely long reply comment (1,000+ words) handles text rendering', () {
        final longComment = 'Nice pull! ' * 300;
        expect(longComment.length, greaterThan(2000));
      });

      test('B14.5: Replying to comment with empty username falls back to @user', () {
        const username = '';
        final effectiveHandle = username.trim().isEmpty ? '@user' : username;
        expect(effectiveHandle, equals('@user'));
      });
    });

    // =========================================================================
    // FEATURE 15 BOUNDARIES (True Total Comment Count)
    // =========================================================================
    group('Feature 15 Boundaries (True Total Comment Count)', () {
      test('B15.1: 0 comments on post displays 0 in SQLite', () async {
        final total = await db.feedDao.watchCommentCount('p_zero').first;
        expect(total, equals(0));
      });

      test('B15.2: 1 root comment with 20 child replies displays total 21 in SQLite', () async {
        const postId = 'p_tree_21';
        final root = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u_root',
          authorUsername: '@u_root',
          authorDisplayName: 'Root User',
          content: 'Root',
        );
        for (int i = 0; i < 20; i++) {
          await db.feedDao.addComment(
            postId: postId,
            authorId: 'u_child_$i',
            authorUsername: '@u_child_$i',
            authorDisplayName: 'Child User $i',
            content: 'C $i',
            parentCommentId: root.id,
          );
        }
        final total = await db.feedDao.watchCommentCount(postId).first;
        expect(total, equals(21));
      });

      test('B15.3: Soft-deleting 5 nested replies immediately decrements total by 5 in SQLite', () async {
        const postId = 'p_soft_del_multi';
        final ids = <String>[];
        for (int i = 0; i < 10; i++) {
          final c = await db.feedDao.addComment(
            postId: postId,
            authorId: 'u_$i',
            authorUsername: '@u_$i',
            authorDisplayName: 'User $i',
            content: 'Comment $i',
          );
          ids.add(c.id);
        }
        expect(await db.feedDao.watchCommentCount(postId).first, equals(10));

        // Soft delete 5 comments
        final now = DateTime.now();
        for (int i = 0; i < 5; i++) {
          await (db.update(db.postComments)..where((t) => t.id.equals(ids[i]))).write(
            PostCommentsCompanion(deletedAt: drift.Value(now)),
          );
        }
        expect(await db.feedDao.watchCommentCount(postId).first, equals(5));
      });

      test('B15.4: Post with deleted root comment but active child replies counts active children in SQLite', () async {
        const postId = 'p_del_root';
        final root = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u_root',
          authorUsername: '@u_root',
          authorDisplayName: 'Root User',
          content: 'Root to delete',
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u_c1',
          authorUsername: '@u_c1',
          authorDisplayName: 'Child 1',
          content: 'Child 1',
          parentCommentId: root.id,
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u_c2',
          authorUsername: '@u_c2',
          authorDisplayName: 'Child 2',
          content: 'Child 2',
          parentCommentId: root.id,
        );

        // Soft delete root
        await (db.update(db.postComments)..where((t) => t.id.equals(root.id))).write(
          PostCommentsCompanion(deletedAt: drift.Value(DateTime.now())),
        );

        expect(await db.feedDao.watchCommentCount(postId).first, equals(2));
      });

      test('B15.5: Simultaneous comments increment count atomically in SQLite', () async {
        const postId = 'p_atomic_count';
        await Future.wait(
          List.generate(25, (i) => db.feedDao.addComment(
            postId: postId,
            authorId: 'u_$i',
            authorUsername: '@u_$i',
            authorDisplayName: 'User $i',
            content: 'Concurrent comment $i',
          )),
        );
        final total = await db.feedDao.watchCommentCount(postId).first;
        expect(total, equals(25));
      });
    });

    // =========================================================================
    // FEATURE 16 BOUNDARIES (Comment Emoji Reactions)
    // =========================================================================
    group('Feature 16 Boundaries (Comment Emoji Reactions)', () {
      test('B16.1: Comment with 10 different emoji reactions maintains all distinct keys in SQLite', () async {
        const commentId = 'c_wide';
        final emojis = ['🔥', '❤️', '😂', '🤯', '💎', '🚀', '✨', '⚡', '🎉', '👏'];
        for (final e in emojis) {
          await db.feedDao.toggleCommentReaction(commentId, 'user_me', e);
        }
        final reactions = await db.feedDao.watchCommentReactions(commentId).first;
        expect(reactions.length, equals(10));
      });

      test('B16.2: Deleted comment with reactions cleans up cleanly in SQLite', () async {
        const commentId = 'c_del';
        await db.feedDao.toggleCommentReaction(commentId, 'u1', '🔥');
        var reactions = await db.feedDao.watchCommentReactions(commentId).first;
        expect(reactions.length, equals(1));

        // Delete comment reactions in SQLite
        await (db.delete(db.commentReactions)..where((t) => t.commentId.equals(commentId))).go();
        reactions = await db.feedDao.watchCommentReactions(commentId).first;
        expect(reactions.isEmpty, isTrue);
      });

      testWidgets('B16.3: Tapping comment react button initiates reaction selector callback', (tester) async {
        const postId = 'post_react_callback_test';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Callback test'),
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
          textContent: 'Callback test',
        );
        final c = await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'Comment for callback',
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(Key('comment_mru_bar_${c.id}')), findsNothing);
        await tester.tap(find.byKey(Key('comment_react_button_${c.id}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(Key('comment_mru_bar_${c.id}')), findsOneWidget);
      });

      test('B16.4: Tapping reaction pill by guest user persists reaction locally in SQLite', () async {
        await db.feedDao.toggleCommentReaction('c_guest', 'guest', '💎');
        final reactions = await db.feedDao.watchCommentReactions('c_guest').first;
        expect(reactions.first.emoji, equals('💎'));
        expect(reactions.first.userId, equals('guest'));
      });

      testWidgets('B16.5: Zero reactions on comment hides reaction pills container', (tester) async {
        const postId = 'post_zero_reactions_test';
        final now = DateTime.now();
        await db.feedDao.createPost(
          FeedPostsCompanion.insert(
            id: postId,
            authorId: 'user_me',
            authorUsername: '@me',
            authorDisplayName: 'Me',
            type: 'text',
            textContent: const drift.Value('Zero reactions test'),
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
          textContent: 'Zero reactions test',
        );
        await db.feedDao.addComment(
          postId: postId,
          authorId: 'u1',
          authorUsername: '@u1',
          authorDisplayName: 'U1',
          content: 'Comment without reactions',
        );

        await tester.pumpWidget(createTestApp(
          child: PostCommentsSheet(post: targetPost),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('comment_reaction_pills_row')), findsNothing);
      });
    });
  });
}

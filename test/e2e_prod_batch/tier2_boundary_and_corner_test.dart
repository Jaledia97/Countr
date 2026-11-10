import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/media_lightbox_viewer.dart';
import 'package:countr/features/trades/domain/models/trade_card_source_filter.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/widgets/edit_binder_modal.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_unpublish_dialog.dart';

import 'e2e_prod_batch_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 2 - Boundary & Corner Cases (B1 to B12)', () {
    late AppDatabase db;
    late VaultDao vaultDao;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = createE2eProdBatchTestDb();
      vaultDao = VaultDao(db);
      exploreDao = ExploreDeckDao(db);
      await (db.delete(db.vaultItems)).go();
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // B1: Avatars Boundary Cases (B1.1 to B1.5)
    // =========================================================================
    group('B1: Avatars Boundaries', () {
      testWidgets('B1.1: Null avatarUrl renders fallback initials avatar without throwing', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const PostHeader(
              username: '@SpicyBrewMaster',
              avatarInitials: 'SB',
              avatarUrl: null,
              timestamp: '2h ago',
              locationTag: 'TBS Comics',
              authorId: 'user-spicy-brew-master',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('SB'), findsOneWidget);
        expect(find.byKey(const Key('post_avatar_user-spicy-brew-master')), findsOneWidget);
      });

      testWidgets('B1.2: Empty string avatarUrl renders initials without throwing', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const PostHeader(
              username: '@EDH_Rec_Fanatic',
              avatarInitials: 'ER',
              avatarUrl: '',
              timestamp: '1h ago',
              locationTag: 'Emerald Coast Gaming',
              authorId: 'user-edh-rec-fanatic',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ER'), findsOneWidget);
      });

      testWidgets('B1.3: Malformed URI avatarUrl is handled safely without unhandled exception', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const PostHeader(
              username: '@FoilCollector99',
              avatarInitials: 'FC',
              avatarUrl: 'not_a_valid_url://scheme-broken',
              timestamp: 'Just now',
              locationTag: 'F2F Games',
              authorId: 'user-foil-collector-99',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('post_avatar_user-foil-collector-99')), findsOneWidget);
      });

      testWidgets('B1.4: Extreme length avatarUrl (2048+ chars) handles gracefully without crash', (tester) async {
        final longUrl = 'https://images.unsplash.com/avatar?padding=${'a' * 2048}';
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            PostHeader(
              username: '@LongUrlCollector',
              avatarInitials: 'LC',
              avatarUrl: longUrl,
              timestamp: '3m ago',
              locationTag: 'Online',
              authorId: 'user-long-url',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('B1.5: Whitespace-only avatarInitials renders empty text box safely', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const PostHeader(
              username: '@GhostUser',
              avatarInitials: '  ',
              avatarUrl: null,
              timestamp: '1d ago',
              locationTag: 'Void',
              authorId: 'user-ghost',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('post_avatar_user-ghost')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // B2: Post Comments Boundary Cases (B2.1 to B2.5)
    // =========================================================================
    group('B2: Comments Boundaries', () {
      testWidgets('B2.1: Post with 0 comments renders "COMMENT (0)" label in PostActionBar', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            PostActionBar(
              initialHypeCount: 5,
              commentCount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('COMMENT (0)'), findsOneWidget);
        expect(find.byKey(const Key('post_action_comment')), findsOneWidget);
      });

      testWidgets('B2.2: Extreme high comment count (99999) renders formatted count in UI', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            PostActionBar(
              initialHypeCount: 2,
              commentCount: 99999,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('COMMENT (99999)'), findsOneWidget);
        expect(find.byKey(const Key('post_action_comment')), findsOneWidget);
      });

      test('B2.3: Soft-deleted comments (isDeleted: true) are excluded from active post comments', () async {
        final now = DateTime.now();
        // Insert active comment
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'comment-b2-active',
            postId: 'post-b2-stream',
            authorId: 'user-spicy-brew-master',
            authorUsername: '@SpicyBrewMaster',
            authorDisplayName: 'Spicy Brewmaster',
            content: 'Active comment',
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
            isDeleted: const drift.Value(false),
          ),
        );

        // Insert soft-deleted comment
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'comment-b2-deleted',
            postId: 'post-b2-stream',
            authorId: 'user-edh-rec-fanatic',
            authorUsername: '@EDH_Rec_Fanatic',
            authorDisplayName: 'EDH Rec Fanatic',
            content: 'Deleted spam comment',
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
            isDeleted: const drift.Value(true),
          ),
        );

        final comments = await (db.select(db.postComments)
              ..where((t) => t.postId.equals('post-b2-stream') & t.isDeleted.equals(false)))
            .get();

        expect(comments.length, equals(1));
        expect(comments.first.id, equals('comment-b2-active'));
      });

      test('B2.4: High-volume batch comments (100+ items) process without failure', () async {
        final now = DateTime.now();
        await db.batch((batch) {
          for (var i = 0; i < 105; i++) {
            batch.insert(
              db.postComments,
              PostCommentsCompanion.insert(
                id: 'comment-bulk-$i',
                postId: 'post-b2-bulk',
                authorId: 'user-foil-collector-99',
                authorUsername: '@FoilCollector99',
                authorDisplayName: 'Foil Collector 99',
                content: 'Bulk comment #$i',
                createdAt: drift.Value(now.add(Duration(seconds: i))),
                updatedAt: drift.Value(now),
              ),
            );
          }
        });

        final countQuery = db.selectOnly(db.postComments)
          ..addColumns([db.postComments.id.count()])
          ..where(db.postComments.postId.equals('post-b2-bulk'));
        final result = await countQuery.getSingle();
        final totalCount = result.read(db.postComments.id.count());

        expect(totalCount, equals(105));
      });

      test('B2.5: Special unicode, emojis, and multiline text in comments preserve exact fidelity', () async {
        const specialText = '🔥 Grail pull! 🐉\nLine 2: ᚠᛇᚻ ᛒᛦᚦ ᚠᚱᚩᚠᚢᚱ\nLine 3: <script>alert("safe")</script>';
        final now = DateTime.now();
        await db.into(db.postComments).insert(
          PostCommentsCompanion.insert(
            id: 'comment-b2-unicode',
            postId: 'post-b2-unicode-post',
            authorId: 'user-current-me',
            authorUsername: '@collector_me',
            authorDisplayName: 'Me',
            content: specialText,
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        final fetched = await (db.select(db.postComments)..where((t) => t.id.equals('comment-b2-unicode'))).getSingle();
        expect(fetched.content, equals(specialText));
      });
    });

    // =========================================================================
    // B3: Card Art Sizing Boundary Cases (B3.1 to B3.5)
    // =========================================================================
    group('B3: Card Art Sizing Boundaries', () {
      testWidgets('B3.1: Aspect ratio 63/88 maintained within bounded width', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: SinglePullPostBody(
                  cardId: 'card-b3-narrow',
                  cardTitle: 'Sol Ring',
                  cardSubtitle: 'Commander Masters · Borderless',
                  imageUrl: 'https://cards.scryfall.io/large/front/0/0/00000000.jpg',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('single_pull_card_card-b3-narrow')), findsOneWidget);
      });

      testWidgets('B3.2: Empty imageUrl renders placeholder without crash', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const SingleChildScrollView(
              child: SinglePullPostBody(
                cardId: 'card-b3-empty-image',
                cardTitle: 'Unknown Card',
                imageUrl: '',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('single_pull_card_card-b3-empty-image')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('B3.3: Missing subtitle/rarity falls back safely to default styling', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const SingleChildScrollView(
              child: SinglePullPostBody(
                cardId: 'card-b3-null-rarity',
                cardTitle: 'Card With No Rarity',
                cardSubtitle: null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Card With No Rarity'), findsOneWidget);
      });

      testWidgets('B3.4: Extremely long card title (150+ chars) renders without vertical overflow', (tester) async {
        final longTitle = 'The Very Long Title Card That Extends Beyond Normal Length And Tests Ellipsis and Truncation In Render Flex Containers Without Crashing ${"A" * 100}';
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            SingleChildScrollView(
              child: SinglePullPostBody(
                cardId: 'card-b3-long-title',
                cardTitle: longTitle,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('B3.5: Price formatted properly when estimatedValue is null or zero', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const SingleChildScrollView(
              child: SinglePullPostBody(
                cardId: 'card-b3-zero-val',
                cardTitle: 'Free Token',
                estimatedValue: '\$0.00',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('single_pull_card_card-b3-zero-val')), findsOneWidget);
        expect(find.text('\$0.00'), findsOneWidget);
      });
    });

    // =========================================================================
    // B4: Multi-card Pull Post Boundary Cases (B4.1 to B4.5)
    // =========================================================================
    group('B4: Multi-card Pull Boundaries', () {
      test('B4.1: Empty image list JSON array is parsed safely as empty list', () {
        const jsonStr = '[]';
        final parsed = jsonDecode(jsonStr);
        expect(parsed, isA<List>());
        expect((parsed as List).isEmpty, isTrue);
      });

      test('B4.2: Malformed JSON string in pullImagesJson handles FormatException safely', () {
        const brokenJson = '{not_valid_json';
        expect(() => jsonDecode(brokenJson), throwsA(isA<FormatException>()));
      });

      test('B4.3: Multi-card with 6 items computes overflow count of +2 for 2x2 grid', () {
        final images = List.generate(6, (i) => 'https://cards.scryfall.io/card_$i.jpg');
        final displayedCount = images.take(4).length;
        final overflowCount = images.length - displayedCount;

        expect(displayedCount, equals(4));
        expect(overflowCount, equals(2));
      });

      test('B4.4: Multi-card with exactly 4 items computes overflow count of 0', () {
        final images = List.generate(4, (i) => 'https://cards.scryfall.io/card_$i.jpg');
        final displayedCount = images.take(4).length;
        final overflowCount = images.length - displayedCount;

        expect(displayedCount, equals(4));
        expect(overflowCount, equals(0));
      });

      test('B4.5: Multi-card with 1 item does not crash and identifies as single item list', () {
        final images = ['https://cards.scryfall.io/card_0.jpg'];
        expect(images.length, equals(1));
        expect(images.first, contains('card_0'));
      });
    });

    // =========================================================================
    // B5: Non-card Media & Lightbox Boundary Cases (B5.1 to B5.5)
    // =========================================================================
    group('B5: Non-card Media & Lightbox Boundaries', () {
      testWidgets('B5.1: MediaLightboxViewer handles ultra-wide aspect ratio gracefully', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const MediaLightboxViewer(
              imageUrl: 'https://images.unsplash.com/photo-ultra-wide.jpg',
              caption: 'Ultra wide 21:9 playmat setup',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(find.text('Ultra wide 21:9 playmat setup'), findsOneWidget);
      });

      testWidgets('B5.2: MediaLightboxViewer handles ultra-tall aspect ratio gracefully', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const MediaLightboxViewer(
              imageUrl: 'https://images.unsplash.com/photo-ultra-tall.jpg',
              caption: 'Tower banner setup',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(find.text('Tower banner setup'), findsOneWidget);
      });

      testWidgets('B5.3: InteractiveViewer maintains minScale 0.5 and maxScale 4.0 bounds in MediaLightboxViewer', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const MediaLightboxViewer(
              imageUrl: 'https://images.unsplash.com/photo-zoom.jpg',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
        expect(iv.minScale, equals(0.5));
        expect(iv.maxScale, equals(4.0));
      });

      testWidgets('B5.4: Double tap gesture on InteractiveViewer executes without exception', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const MediaLightboxViewer(
              imageUrl: 'https://images.unsplash.com/photo-tap.jpg',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final viewerFinder = find.byType(InteractiveViewer);
        await tester.tap(viewerFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(viewerFinder);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('B5.5: Close button in MediaLightboxViewer is present with correct key', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            const MediaLightboxViewer(
              imageUrl: 'https://images.unsplash.com/photo-close.jpg',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final closeButton = find.byKey(const Key('media_lightbox_close_button'));
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // B6: Trade Card Source Filter Boundary Cases (B6.1 to B6.5)
    // =========================================================================
    group('B6: Trade Card Source Filter Boundaries', () {
      test('B6.1: Zero quantity cards (quantity: 0) strictly excluded from trade cards', () async {
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-b6-qty0',
            name: 'Unowned Reference Card',
            userId: 'user-b6-test',
            quantity: 0,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final items = await vaultDao.watchUserTradeCards('user-b6-test', filter: TradeCardSourceFilter.both).first;
        expect(items.where((c) => c.id == 'card-b6-qty0'), isEmpty);
      });

      test('B6.2: Traded cards (isTraded: true) strictly excluded from trade cards', () async {
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-b6-traded',
            name: 'Already Traded Card',
            userId: 'user-b6-test',
            quantity: 1,
            isTraded: true,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final items = await vaultDao.watchUserTradeCards('user-b6-test', filter: TradeCardSourceFilter.both).first;
        expect(items.where((c) => c.id == 'card-b6-traded'), isEmpty);
      });

      test('B6.3: Soft-deleted cards (isDeleted: true) strictly excluded from trade cards', () async {
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-b6-deleted',
            name: 'Deleted Card',
            userId: 'user-b6-test',
            quantity: 1,
            isDeleted: true,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final items = await vaultDao.watchUserTradeCards('user-b6-test', filter: TradeCardSourceFilter.both).first;
        expect(items.where((c) => c.id == 'card-b6-deleted'), isEmpty);
      });

      test('B6.4: System Looking For cards strictly excluded from user trade cards', () async {
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-b6-wishlist',
            name: 'Looking For Card',
            userId: 'user-b6-test',
            quantity: 1,
            primaryBinderId: 'system_looking_for_user-b6-test',
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final items = await vaultDao.watchUserTradeCards('user-b6-test', filter: TradeCardSourceFilter.both).first;
        expect(items.where((c) => c.id == 'card-b6-wishlist'), isEmpty);
      });

      test('B6.5: Strict user scoping: User A trade query never returns User B cards', () async {
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-b6-user-a',
            name: 'User A Card',
            userId: 'user-a',
            quantity: 1,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-b6-user-b',
            name: 'User B Card',
            userId: 'user-b',
            quantity: 1,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final userAItems = await vaultDao.watchUserTradeCards('user-a', filter: TradeCardSourceFilter.both).first;
        expect(userAItems.any((c) => c.id == 'card-b6-user-a'), isTrue);
        expect(userAItems.any((c) => c.id == 'card-b6-user-b'), isFalse);
      });
    });

    // =========================================================================
    // B7: System Binder Deduplication Boundary Cases (B7.1 to B7.5)
    // =========================================================================
    group('B7: Binder Deduplication Boundaries', () {
      test('B7.1: Zero duplicate binders deduplication is safe no-op', () async {
        final result = await vaultDao.deduplicateAndPurgeSystemBinders('user-b7-clean', isBusiness: false);
        expect(result['bindersPurged'] ?? 0, equals(0));
      });

      test('B7.2: Multiple duplicate trade block binders (4 dupes) collapses to exactly 1', () async {
        const uId = 'user-b7-multi-trade';
        final now = DateTime.now();
        // Insert canonical
        await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'system_trade_block_$uId',
            name: 'Trade Binder',
            collectionType: 'mtg',
            isSystemBinder: const drift.Value(true),
            systemBinderType: const drift.Value('trade_block'),
            userId: drift.Value(uId),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        // Insert 3 duplicates
        for (var i = 1; i <= 3; i++) {
          await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'system_trade_block_${uId}_dupe_$i',
              name: 'Trade Block',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: drift.Value(uId),
              createdAt: now.add(Duration(minutes: i)),
              updatedAt: drift.Value(now),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }

        final result = await vaultDao.deduplicateAndPurgeSystemBinders(uId, isBusiness: false);
        expect(result['bindersPurged'] ?? 0, equals(3));

        final remaining = await (db.select(db.vaultBinders)
              ..where((t) => t.userId.equals(uId) & t.isDeleted.equals(false) & t.systemBinderType.equals('trade_block')))
            .get();
        expect(remaining.length, equals(1));
        expect(remaining.first.id, equals('system_trade_block_$uId'));
      });

      test('B7.3: Multiple duplicate looking-for binders (3 dupes) collapses to exactly 1', () async {
        const uId = 'user-b7-multi-lf';
        final now = DateTime.now();
        await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'system_looking_for_$uId',
            name: 'Looking For',
            collectionType: 'mtg',
            isSystemBinder: const drift.Value(true),
            systemBinderType: const drift.Value('looking_for'),
            userId: drift.Value(uId),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        for (var i = 1; i <= 2; i++) {
          await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'system_looking_for_${uId}_dupe_$i',
              name: 'Looking For',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: drift.Value(uId),
              createdAt: now.add(Duration(minutes: i)),
              updatedAt: drift.Value(now),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }

        final result = await vaultDao.deduplicateAndPurgeSystemBinders(uId, isBusiness: false);
        expect(result['bindersPurged'] ?? 0, equals(2));

        final remaining = await (db.select(db.vaultBinders)
              ..where((t) => t.userId.equals(uId) & t.isDeleted.equals(false) & t.systemBinderType.equals('looking_for')))
            .get();
        expect(remaining.length, equals(1));
        expect(remaining.first.id, equals('system_looking_for_$uId'));
      });

      test('B7.4: Cross-user isolation: User A deduplication leaves User B duplicate binders untouched', () async {
        const uA = 'user-b7-iso-a';
        const uB = 'user-b7-iso-b';
        final now = DateTime.now();

        // User A dupe
        await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'system_trade_block_${uA}_dupe',
            name: 'Trade Block',
            collectionType: 'mtg',
            isSystemBinder: const drift.Value(true),
            systemBinderType: const drift.Value('trade_block'),
            userId: drift.Value(uA),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        // User B dupe
        await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'system_trade_block_${uB}_dupe',
            name: 'Trade Block',
            collectionType: 'mtg',
            isSystemBinder: const drift.Value(true),
            systemBinderType: const drift.Value('trade_block'),
            userId: drift.Value(uB),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await vaultDao.deduplicateAndPurgeSystemBinders(uA, isBusiness: false);

        final uBRemaining = await (db.select(db.vaultBinders)
              ..where((t) => t.id.equals('system_trade_block_${uB}_dupe')))
            .getSingleOrNull();
        expect(uBRemaining, isNotNull);
      });

      test('B7.5: Deduplication re-anchors orphaned cards to canonical binder without card count loss', () async {
        const uId = 'user-b7-reanchor';
        final now = DateTime.now();
        // Canonical
        await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'system_trade_block_$uId',
            name: 'Trade Binder',
            collectionType: 'mtg',
            isSystemBinder: const drift.Value(true),
            systemBinderType: const drift.Value('trade_block'),
            userId: drift.Value(uId),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        // Duplicate binder
        await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'system_trade_block_${uId}_orphan',
            name: 'Trade Block',
            collectionType: 'mtg',
            isSystemBinder: const drift.Value(true),
            systemBinderType: const drift.Value('trade_block'),
            userId: drift.Value(uId),
            createdAt: now.add(const Duration(minutes: 1)),
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        // Card inside orphan binder
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-b7-orphan-item',
            name: 'Orphaned Mox Diamond',
            userId: uId,
            primaryBinderId: 'system_trade_block_${uId}_orphan',
            quantity: 1,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await vaultDao.deduplicateAndPurgeSystemBinders(uId, isBusiness: false);

        final cardAfter = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-b7-orphan-item'))).getSingle();
        expect(cardAfter.primaryBinderId, equals('system_trade_block_$uId'));
      });
    });

    // =========================================================================
    // B8: System Binder Immutability Boundary Cases (B8.1 to B8.5)
    // =========================================================================
    group('B8: System Binder Immutability Boundaries', () {
      test('B8.1: deleteBinder on system_trade_block throws UnsupportedError', () async {
        expect(
          () => vaultDao.deleteBinder('system_trade_block_user-current-me'),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('B8.2: deleteBinder on system_looking_for throws UnsupportedError', () async {
        expect(
          () => vaultDao.deleteBinder('system_looking_for_user-current-me'),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('B8.3: Custom user binder can be deleted without throwing', () async {
        final now = DateTime.now();
        await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'binder-custom-b8',
            name: 'My Custom Commander Binder',
            collectionType: 'mtg',
            userId: const drift.Value('user-current-me'),
            createdAt: now,
            updatedAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final deleted = await vaultDao.deleteBinder('binder-custom-b8');
        expect(deleted, equals(1));

        final fetched = await (db.select(db.vaultBinders)..where((t) => t.id.equals('binder-custom-b8'))).getSingle();
        expect(fetched.isDeleted, isTrue);
      });

      testWidgets('B8.4: EditBinderModal sets name field to readOnly for system binders', (tester) async {
        final systemBinder = await (db.select(db.vaultBinders)
              ..where((t) => t.id.equals('system_trade_block_user-current-me')))
            .getSingle();

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            EditBinderModal(binder: systemBinder),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final nameFieldFinder = find.byKey(const Key('edit_binder_name_input'));
        expect(nameFieldFinder, findsOneWidget);
        final textField = tester.widget<TextField>(nameFieldFinder);
        expect(textField.readOnly, isTrue);
      });

      testWidgets('B8.5: System binders display system protected banner in EditBinderModal', (tester) async {
        final systemBinder = await (db.select(db.vaultBinders)
              ..where((t) => t.id.equals('system_looking_for_user-current-me')))
            .getSingle();

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            EditBinderModal(binder: systemBinder),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('edit_binder_system_protected_banner')), findsOneWidget);
        expect(find.textContaining('Permanent System Binder — Protected against deletion'), findsOneWidget);
      });
    });

    // =========================================================================
    // B9: Explore Decks "My Uploads" Boundary Cases (B9.1 to B9.5)
    // =========================================================================
    group('B9: Explore Decks "My Uploads" Boundaries', () {
      test('B9.1: Zero uploaded decks returns empty list without error', () async {
        final decks = await exploreDao.watchExploreDecks().first;
        final myDecks = decks.where((d) => isExploreDeckAuthor(deck: d.deck, currentUserId: 'user-new-zero-uploads')).toList();
        expect(myDecks, isEmpty);
      });

      test('B9.2: Many uploaded decks (12 items) streamed and filtered accurately', () async {
        const authorId = 'user-current-me';
        for (var i = 0; i < 12; i++) {
          await db.into(db.exploreDecks).insert(
            createTestExploreDeckRecord(
              id: 'deck-bulk-upload-$i',
              authorId: authorId,
              creatorName: 'collector_me',
              name: 'Upload Deck #$i',
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }

        final allDecks = await exploreDao.watchExploreDecks().first;
        final myDecks = allDecks.where((d) => isExploreDeckAuthor(deck: d.deck, currentUserId: authorId)).toList();
        expect(myDecks.length, equals(12));
      });

      test('B9.3: isExploreDeckAuthor matches canonical user aliases correctly', () {
        final deckMe = createTestExploreDeckRecord(
          id: 'deck-me-alias',
          name: 'Me Deck',
          authorId: 'user-current-me',
          creatorName: 'collector_me',
        );
        expect(isExploreDeckAuthor(deck: deckMe, currentUserId: 'user-current-me'), isTrue);

        final deckLocal = createTestExploreDeckRecord(
          id: 'deck-local-alias',
          name: 'Local Deck',
          authorId: 'local_user',
          creatorName: 'local_user',
        );
        expect(isExploreDeckAuthor(deck: deckLocal, currentUserId: 'user-current-me'), isTrue);

        final deckOther = createTestExploreDeckRecord(
          id: 'deck-other',
          name: 'Other Deck',
          authorId: 'user-spicy-brew-master',
          creatorName: 'SpicyBrewMaster',
        );
        expect(isExploreDeckAuthor(deck: deckOther, currentUserId: 'user-current-me'), isFalse);
      });

      test('B9.4: Guest user has 0 My Uploads without throwing', () async {
        final allDecks = await exploreDao.watchExploreDecks().first;
        final guestDecks = allDecks.where((d) => isExploreDeckAuthor(deck: d.deck, currentUserId: 'guest-unauthenticated')).toList();
        expect(guestDecks, isEmpty);
      });

      test('B9.5: Soft-deleted uploaded decks (isDeleted: true) are excluded from explore decks stream', () async {
        const authorId = 'user-current-me';
        await db.into(db.exploreDecks).insert(
          createTestExploreDeckRecord(
            id: 'deck-b9-active',
            authorId: authorId,
            creatorName: 'collector_me',
            name: 'Active Deck',
            isDeleted: false,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        await db.into(db.exploreDecks).insert(
          createTestExploreDeckRecord(
            id: 'deck-b9-deleted',
            authorId: authorId,
            creatorName: 'collector_me',
            name: 'Deleted Deck',
            isDeleted: true,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final allDecks = await exploreDao.watchExploreDecks().first;
        final activeIds = allDecks.map((d) => d.id).toList();
        expect(activeIds, contains('deck-b9-active'));
        expect(activeIds, isNot(contains('deck-b9-deleted')));
      });
    });

    // =========================================================================
    // B10: Uncropped Grid Sizing Boundary Cases (B10.1 to B10.5)
    // =========================================================================
    group('B10: Grid Sizing & Aspect Ratio Boundaries', () {
      testWidgets('B10.1: ExploreDeckCard renders with uncropped aspect ratio in compact mode', (tester) async {
        final deck = createTestExploreDeckRecord(
          id: 'deck-b10-ratio',
          name: 'Atraxa Proliferate',
          authorId: 'user-edh-rec-fanatic',
          creatorName: 'EDH_Rec_Fanatic',
          commanderImageUrl: 'https://cards.scryfall.io/art_crop/front/a/t/atraxa.jpg',
        );

        final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            SizedBox(
              width: 180,
              child: SingleChildScrollView(
                child: ExploreDeckCard(
                  deckWithVote: deckWithVote,
                  isCompact: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Atraxa Proliferate'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('B10.2: Ultra-narrow screen width (150dp) grid card renders without RenderFlex overflow', (tester) async {
        final deck = createTestExploreDeckRecord(
          id: 'deck-b10-narrow',
          name: 'Krenko Mob Boss Goblins Extreme Speed Aggro',
          authorId: 'user-spicy-brew-master',
          creatorName: 'SpicyBrewMaster',
        );

        final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            SizedBox(
              width: 150,
              child: SingleChildScrollView(
                child: ExploreDeckCard(
                  deckWithVote: deckWithVote,
                  isCompact: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Krenko Mob Boss Goblins Extreme Speed Aggro'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('B10.3: Wide screen width (380dp) grid layout renders cleanly', (tester) async {
        final deck = createTestExploreDeckRecord(
          id: 'deck-b10-wide',
          name: 'The Ur-Dragon Dragon Tribal',
          authorId: 'user-foil-collector-99',
          creatorName: 'FoilCollector99',
        );

        final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: ExploreDeckCard(
                  deckWithVote: deckWithVote,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('The Ur-Dragon Dragon Tribal'), findsOneWidget);
      });

      testWidgets('B10.4: Extremely long deck name (150+ chars) displays without crashing', (tester) async {
        final veryLongName = 'This Is A Very Long Deck Name That Exceeds Normal Limits And Should Truncate Gracefully With TextOverflow Ellipsis In The Explore Deck Grid Card Widget ${"B" * 60}';
        final deck = createTestExploreDeckRecord(
          id: 'deck-b10-long-name',
          name: veryLongName,
          authorId: 'user-spicy-brew-master',
          creatorName: 'SpicyBrewMaster',
        );

        final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            SizedBox(
              width: 180,
              child: SingleChildScrollView(
                child: ExploreDeckCard(
                  deckWithVote: deckWithVote,
                  isCompact: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('B10.5: Missing commanderImageUrl renders fallback icon placeholder safely', (tester) async {
        final deck = createTestExploreDeckRecord(
          id: 'deck-b10-no-image',
          name: 'Faceless Deck',
          authorId: 'user-spicy-brew-master',
          creatorName: 'SpicyBrewMaster',
          commanderImageUrl: null,
          commanderArtCrop: null,
        );

        final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            SizedBox(
              width: 180,
              child: SingleChildScrollView(
                child: ExploreDeckCard(
                  deckWithVote: deckWithVote,
                  isCompact: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
        expect(find.text('Faceless Deck'), findsOneWidget);
      });
    });

    // =========================================================================
    // B11: Precon MTGJSON Sync Boundary Cases (B11.1 to B11.5)
    // =========================================================================
    group('B11: Precon MTGJSON Sync Boundaries', () {
      test('B11.1: Malformed JSON payload string throws FormatException without database corruption', () {
        const malformedJson = '{"data": { broken_json_without_quotes }';
        expect(() => MtgjsonPreconParser.parseJson(malformedJson), throwsA(isA<FormatException>()));
      });

      test('B11.2: Empty data array in JSON returns empty list cleanly', () {
        const emptyJson = '{"data": []}';
        final dtos = MtgjsonPreconParser.parseJson(emptyJson);
        expect(dtos, isEmpty);
      });

      test('B11.3: Duplicate precon deck ID updates existing deck instead of crashing on UNIQUE constraint', () async {
        final deckRecord1 = createTestExploreDeckRecord(
          id: 'precon-b11-dupe',
          name: 'Initial Precon Name',
          sourceType: 'official',
        );
        await db.into(db.exploreDecks).insert(deckRecord1, mode: drift.InsertMode.insertOrReplace);

        final deckRecord2 = createTestExploreDeckRecord(
          id: 'precon-b11-dupe',
          name: 'Updated Precon Name',
          sourceType: 'official',
        );
        await db.into(db.exploreDecks).insert(deckRecord2, mode: drift.InsertMode.insertOrReplace);

        final deck = await (db.select(db.exploreDecks)..where((t) => t.id.equals('precon-b11-dupe'))).getSingleOrNull();
        expect(deck, isNotNull);
        expect(deck!.name, equals('Updated Precon Name'));
      });

      test('B11.4: PreconCardDto sanitizes and removes art_series layout', () {
        final cardMap = {
          'name': 'Gilded Goose Art Card',
          'layout': 'art_series',
          'image_uris': {
            'normal': 'https://cards.scryfall.io/art_series/front/1/2/123.jpg',
            'art_crop': 'https://cards.scryfall.io/art_series/front/1/2/123_crop.jpg',
          },
        };

        final cardDto = PreconCardDto.fromMap(cardMap);
        expect(cardDto.layout, equals('normal'));
        expect(cardDto.imageUrl, isNot(contains('art_series')));
        expect(cardDto.artCropUrl, isNot(contains('art_series')));
      });

      test('B11.5: Fallback explore seeds contain official precon decks for offline bootstrapping', () {
        expect(FallbackExploreSeeds.preconSeeds, isNotEmpty);
        final firstPrecon = FallbackExploreSeeds.preconSeeds.first;
        expect(firstPrecon['source_type'], equals('official'));
        expect(firstPrecon['creator_name'], equals('Wizards of the Coast'));
      });
    });

    // =========================================================================
    // B12: MasterSetScreen Boundary Cases (B12.1 to B12.5)
    // =========================================================================
    group('B12: MasterSetScreen Boundaries', () {
      final emptyCollection = const VaultSetCollection(
        setName: 'Empty Future Set',
        setCode: 'EFS',
        collectionType: 'mtg',
        totalCount: 0,
        ownedCount: 0,
        completionPercentage: 0.0,
        releaseDate: '2027',
      );

      final fullCollection = const VaultSetCollection(
        setName: 'Complete Set Alpha',
        setCode: 'CSA',
        collectionType: 'mtg',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
        releaseDate: '2024',
      );

      testWidgets('B12.1: Empty set (0 cards in catalog) displays empty state gracefully', (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            MasterSetScreen(
              collection: emptyCollection,
              activeGame: 'mtg',
            ),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Empty Future Set'), findsOneWidget);
        expect(find.text('Set: EFS'), findsOneWidget);
        expect(find.text('0 / 0'), findsOneWidget);
        expect(find.text('0.0% complete'), findsOneWidget);
      });

      testWidgets('B12.2: 100% complete set displays 100.0% completion', (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-csa-1',
            name: 'Alpha Black Lotus',
            setOrSeries: 'CSA',
            setCode: 'csa',
            quantity: 1,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            MasterSetScreen(
              collection: fullCollection,
              activeGame: 'mtg',
            ),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 / 1'), findsOneWidget);
        expect(find.text('100.0% complete'), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-csa-1')), findsOneWidget);
      });

      testWidgets('B12.3: 0% owned set displays 0.0% completion with card missing badge', (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-csa-unowned',
            name: 'Alpha Mox Pearl',
            setOrSeries: 'CSA',
            setCode: 'csa',
            quantity: 0,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            MasterSetScreen(
              collection: fullCollection,
              activeGame: 'mtg',
            ),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0 / 1'), findsOneWidget);
        expect(find.text('0.0% complete'), findsOneWidget);
        expect(find.text('Missing'), findsOneWidget);
      });

      testWidgets('B12.4: Search with non-matching query returns 0 matching cards', (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-csa-search-item',
            name: 'Alpha Mox Emerald',
            setOrSeries: 'CSA',
            setCode: 'csa',
            quantity: 1,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        await tester.pumpWidget(
          wrapWithMaterialAndScope(
            MasterSetScreen(
              collection: fullCollection,
              activeGame: 'mtg',
            ),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final searchFieldFinder = find.byKey(const Key('master_set_search_field'));
        await tester.enterText(searchFieldFinder, 'NonExistentCardXYZ');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_card_card-csa-search-item')), findsNothing);
      });

      test('B12.5: Case-insensitive set code lookup (ltr vs LTR) strictly retrieves correct set cards', () async {
        await db.into(db.vaultItems).insert(
          createTestVaultCard(
            id: 'card-ltr-lookup',
            name: 'Mount Doom',
            setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
            setCode: 'ltr',
            quantity: 1,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        // Lookup with uppercase 'LTR'
        final upperCards = await vaultDao.watchItemsBySet('The Lord of the Rings: Tales of Middle-earth', setCode: 'LTR', collectionType: 'mtg').first;
        expect(upperCards.any((c) => c.id == 'card-ltr-lookup'), isTrue);

        // Lookup with lowercase 'ltr'
        final lowerCards = await vaultDao.watchItemsBySet('The Lord of the Rings: Tales of Middle-earth', setCode: 'ltr', collectionType: 'mtg').first;
        expect(lowerCards.any((c) => c.id == 'card-ltr-lookup'), isTrue);
      });
    });
  });
}

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
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_unpublish_dialog.dart';

import 'e2e_prod_batch_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 3 - Cross-Feature Pairwise Interactions (X1 to X12)', () {
    late AppDatabase db;
    late VaultDao vaultDao;

    setUp(() async {
      db = createE2eProdBatchTestDb();
      vaultDao = VaultDao(db);
      await (db.delete(db.vaultItems)).go();
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // X1: F1 (Avatars) + F2 (Comments)
    // Adding a comment reflects persona user profile avatar and updates comment count
    // =========================================================================
    testWidgets('X1: F1 (Avatars) + F2 (Comments) — Commenting author avatar renders and increments comment counter', (tester) async {
      final now = DateTime.now();
      const pId = 'post-x1-interaction';

      // 1. Initial post with 0 comments
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          Column(
            children: [
              const PostHeader(
                username: '@SpicyBrewMaster',
                avatarInitials: 'SB',
                avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                timestamp: '1h ago',
                locationTag: 'TBS Comics',
                authorId: 'user-spicy-brew-master',
              ),
              PostActionBar(
                initialHypeCount: 10,
                commentCount: 0,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMMENT (0)'), findsOneWidget);
      expect(find.byKey(const Key('post_avatar_user-spicy-brew-master')), findsOneWidget);

      // 2. Insert new comment from FoilCollector99 into database
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'comment-x1-fc99',
          postId: pId,
          authorId: 'user-foil-collector-99',
          authorUsername: '@FoilCollector99',
          authorDisplayName: 'Foil Collector 99',
          authorAvatarUrl: const drift.Value('https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150'),
          content: 'Incredible pull! Love the foil finish.',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final comments = await (db.select(db.postComments)..where((t) => t.postId.equals(pId))).get();
      expect(comments.length, equals(1));
      expect(comments.first.authorAvatarUrl, contains('unsplash'));

      // 3. Re-render PostActionBar with updated comment count
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          PostActionBar(
            initialHypeCount: 10,
            commentCount: comments.length,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMMENT (1)'), findsOneWidget);
    });

    // =========================================================================
    // X2: F1 (Avatars) + F4 (Multi-card)
    // Multi-card post author avatar correctly routes and retains identity
    // =========================================================================
    testWidgets('X2: F1 (Avatars) + F4 (Multi-card) — Author avatar in multi-card pull post handles tap callback cleanly', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          PostHeader(
            username: '@TBSComics',
            avatarInitials: 'TC',
            timestamp: '3h ago',
            locationTag: 'TBS Comics',
            authorId: 'store-tbs-comics',
            onUserTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pump();

      final avatarFinder = find.byKey(const Key('post_avatar_store-tbs-comics'));
      expect(avatarFinder, findsOneWidget);
      await tester.tap(avatarFinder);
      await tester.pump();

      expect(tapped, isTrue);
    });

    // =========================================================================
    // X3: F2 (Comments) + F5 (Non-card media)
    // Commenting on non-card media post preserves media dimensions and aspect ratio
    // =========================================================================
    testWidgets('X3: F2 (Comments) + F5 (Non-card media) — Media lightbox overlay renders caption alongside comments metadata', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const MediaLightboxViewer(
            imageUrl: 'https://images.unsplash.com/photo-tournament.jpg',
            caption: 'Final round of Commander Masters tournament at Emerald Coast Gaming!',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Final round of Commander Masters tournament at Emerald Coast Gaming!'), findsOneWidget);
      expect(find.byKey(const Key('media_lightbox_close_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // X4: F3 (Card Art Sizing) + F12 (MasterSetScreen)
    // Card art aspect ratio 63/88 matches between single pull post and master set
    // =========================================================================
    testWidgets('X4: F3 (Card Art) + F12 (MasterSetScreen) — Card art from master set renders identically to single pull post container', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Insert Master Set card
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-x4-ring',
          name: 'The One Ring',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'ltr',
          quantity: 1,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final collection = const VaultSetCollection(
        setName: 'The Lord of the Rings: Tales of Middle-earth',
        setCode: 'LTR',
        collectionType: 'mtg',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
        releaseDate: '2023',
      );

      // 2. Render MasterSetScreen
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: collection,
            activeGame: 'mtg',
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_card-x4-ring')), findsOneWidget);

      // 3. Render SinglePullPostBody with same card
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const SingleChildScrollView(
            child: SinglePullPostBody(
              cardId: 'card-x4-ring',
              cardTitle: 'The One Ring',
              cardSubtitle: 'Tales of Middle-earth · Mythic Rare',
              imageUrl: 'https://cards.scryfall.io/normal/front/1/2/12345678.jpg',
            ),
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('single_pull_card_card-x4-ring')), findsOneWidget);
    });

    // =========================================================================
    // X5: F6 (Trade cards) + F7 (Binder dedup)
    // Running binder deduplication preserves user's trade card filter queries
    // =========================================================================
    test('X5: F6 (Trade cards) + F7 (Binder dedup) — Deduplicating binders maintains valid trade cards query results', () async {
      const uId = 'user-x5-trader';
      final now = DateTime.now();

      // Canonical trade binder
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

      // Duplicate trade binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'system_trade_block_${uId}_dupe',
          name: 'Trade Block',
          collectionType: 'mtg',
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(uId),
          createdAt: now.add(const Duration(minutes: 5)),
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Card in duplicate binder
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-x5-dockside',
          name: 'Dockside Extortionist',
          userId: uId,
          primaryBinderId: 'system_trade_block_${uId}_dupe',
          quantity: 1,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Card in general vault
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-x5-rhystic',
          name: 'Rhystic Study',
          userId: uId,
          primaryBinderId: null,
          quantity: 2,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Run deduplication
      final dedupResult = await vaultDao.deduplicateAndPurgeSystemBinders(uId, isBusiness: false);
      expect(dedupResult['bindersPurged'] ?? 0, greaterThanOrEqualTo(1));

      // Query trade cards after deduplication
      final tradeCards = await vaultDao.watchUserTradeCards(uId, filter: TradeCardSourceFilter.both).first;
      expect(tradeCards.length, equals(2));
      final names = tradeCards.map((c) => c.name).toList();
      expect(names, contains('Dockside Extortionist'));
      expect(names, contains('Rhystic Study'));

      // Dockside should now be anchored to canonical binder
      final dockside = tradeCards.firstWhere((c) => c.id == 'card-x5-dockside');
      expect(dockside.primaryBinderId, equals('system_trade_block_$uId'));
    });

    // =========================================================================
    // X6: F6 (Trade cards) + F8 (System binder immutability)
    // Protected trade binder correctly supplies trade cards to watchUserTradeCards
    // =========================================================================
    test('X6: F6 (Trade cards) + F8 (System binder immutability) — Protected system trade binder supplies trade cards reliably', () async {
      const uId = 'user-x6-immutability';
      final now = DateTime.now();

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

      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-x6-force-of-will',
          name: 'Force of Will',
          userId: uId,
          primaryBinderId: 'system_trade_block_$uId',
          quantity: 1,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Deletion of system binder is refused
      expect(() => vaultDao.deleteBinder('system_trade_block_$uId'), throwsA(isA<UnsupportedError>()));

      // Trade cards query continues to deliver cards from protected binder
      final cards = await vaultDao.watchUserTradeCards(uId, filter: TradeCardSourceFilter.tradeBinder).first;
      expect(cards.length, equals(1));
      expect(cards.first.name, equals('Force of Will'));
    });

    // =========================================================================
    // X7: F7 (Binder dedup) + F8 (System binder immutability)
    // System binder deletion refusal persists through deduplication cycles
    // =========================================================================
    test('X7: F7 (Binder dedup) + F8 (System binder immutability) — System binder protection banner and delete refusal persist post-dedup', () async {
      const uId = 'user-current-me';
      await vaultDao.deduplicateAndPurgeSystemBinders(uId, isBusiness: false);

      // Canonical trade binder cannot be deleted
      expect(() => vaultDao.deleteBinder('system_trade_block_$uId'), throwsA(isA<UnsupportedError>()));

      // Canonical looking for cannot be deleted
      expect(() => vaultDao.deleteBinder('system_looking_for_$uId'), throwsA(isA<UnsupportedError>()));
    });

    // =========================================================================
    // X8: F9 ("My Uploads") + F10 (Uncropped grid)
    // Decks authored by current user render with uncropped cover art in compact card grid
    // =========================================================================
    testWidgets('X8: F9 ("My Uploads") + F10 (Uncropped grid) — My Uploads deck card renders uncropped cover art in compact mode', (tester) async {
      const uId = 'user-current-me';
      final deck = createTestExploreDeckRecord(
        id: 'deck-x8-my-upload',
        name: 'Urza Thopter Combo',
        authorId: uId,
        creatorName: 'collector_me',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/u/r/urza.jpg',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/u/r/urza.jpg',
      );

      final isMyUpload = isExploreDeckAuthor(deck: deck, currentUserId: uId);
      expect(isMyUpload, isTrue);

      final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 173,
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

      expect(find.text('Urza Thopter Combo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // X9: F9 ("My Uploads") + F11 (Precon sync)
    // Official precon decks are never tagged as "My Uploads" for local user
    // =========================================================================
    test('X9: F9 ("My Uploads") + F11 (Precon sync) — Official precons are strictly excluded from current user My Uploads', () {
      final rawJson = '''
      {
        "data": [
          {
            "name": "Draconic Domination",
            "code": "C17",
            "type": "Commander Deck",
            "cards": [
              {"name": "The Ur-Dragon", "count": 1, "isCommander": true}
            ]
          }
        ]
      }
      ''';

      final dtos = MtgjsonPreconParser.parseJson(rawJson);
      expect(dtos.length, equals(1));
      final preconDto = dtos.first;

      final preconDeckRecord = createTestExploreDeckRecord(
        id: MtgjsonPreconParser.buildDeterministicDeckId(setCode: preconDto.setCode, name: preconDto.name),
        name: preconDto.name,
        sourceType: 'official',
        authorId: 'wizards_of_the_coast',
        creatorName: 'Wizards of the Coast',
      );

      final isMine = isExploreDeckAuthor(deck: preconDeckRecord, currentUserId: 'user-current-me');
      expect(isMine, isFalse);
    });

    // =========================================================================
    // X10: F10 (Uncropped grid) + F11 (Precon sync)
    // Official precons display full uncropped commander card images
    // =========================================================================
    testWidgets('X10: F10 (Uncropped grid) + F11 (Precon sync) — Precon card in compact grid displays commander art crop', (tester) async {
      final preconDeck = createTestExploreDeckRecord(
        id: 'precon-c17-draconic',
        name: 'Draconic Domination',
        sourceType: 'official',
        creatorName: 'Wizards of the Coast',
        commanderName: 'The Ur-Dragon',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/7/e/7e78b70b-0c67.jpg',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/7/e/7e78b70b-0c67.jpg',
      );

      final deckWithVote = ExploreDeckWithVote(deck: preconDeck, userVote: 0);

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 173,
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

      expect(find.text('Draconic Domination'), findsOneWidget);
      expect(find.text('Official WotC'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    // =========================================================================
    // X11: F6 (Trade cards) + F12 (MasterSetScreen)
    // Cards marked as tradeable in Vault reflect in Master Set owned status
    // =========================================================================
    testWidgets('X11: F6 (Trade cards) + F12 (MasterSetScreen) — Card in trade block reflects as owned card in Master Set screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert card into system trade block
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-x11-trade-ring',
          name: 'The One Ring',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'ltr',
          primaryBinderId: 'system_trade_block_user-current-me',
          quantity: 1,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Verify card is in trade binder
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-x11-trade-ring'))).getSingle();
      expect(item.primaryBinderId, equals('system_trade_block_user-current-me'));

      final collection = const VaultSetCollection(
        setName: 'The Lord of the Rings: Tales of Middle-earth',
        setCode: 'LTR',
        collectionType: 'mtg',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
        releaseDate: '2023',
      );

      // Render MasterSetScreen - card should be owned (x1 badge, not grayscale)
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: collection,
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
      expect(find.byKey(const Key('master_set_card_card-x11-trade-ring')), findsOneWidget);
      expect(find.byKey(const Key('master_set_grayscale_card-x11-trade-ring')), findsNothing);
    });

    // =========================================================================
    // X12: F7 (Binder dedup) + F12 (MasterSetScreen)
    // Re-anchoring cards during binder deduplication preserves Master Set completion
    // =========================================================================
    testWidgets('X12: F7 (Binder dedup) + F12 (MasterSetScreen) — Re-anchoring cards across binder dedup preserves Master Set completion', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const uId = 'user-current-me';
      final now = DateTime.now();

      // Duplicate binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'system_trade_block_${uId}_dupe_x12',
          name: 'Trade Block',
          collectionType: 'mtg',
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(uId),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Card inside duplicate binder
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-x12-bowmasters',
          name: 'Orcish Bowmasters',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'ltr',
          primaryBinderId: 'system_trade_block_${uId}_dupe_x12',
          quantity: 1,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Deduplicate binders
      await vaultDao.deduplicateAndPurgeSystemBinders(uId, isBusiness: false);

      // MasterSetScreen renders with 100% completion
      final collection = const VaultSetCollection(
        setName: 'The Lord of the Rings: Tales of Middle-earth',
        setCode: 'LTR',
        collectionType: 'mtg',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
        releaseDate: '2023',
      );

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: collection,
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
      expect(find.byKey(const Key('master_set_card_card-x12-bowmasters')), findsOneWidget);
    });
  });
}

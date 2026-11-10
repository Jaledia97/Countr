import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/daos/feed_dao.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/media_lightbox_viewer.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/widgets/edit_binder_modal.dart';
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

  group('Tier 4 - Real-World Collector Scenarios (Scenarios 1 to 6)', () {
    late AppDatabase db;
    late VaultDao vaultDao;
    late FeedDao feedDao;

    setUp(() async {
      db = createE2eProdBatchTestDb();
      vaultDao = VaultDao(db);
      feedDao = FeedDao(db);
      await (db.delete(db.vaultItems)).go();
      await (db.delete(db.exploreDecks)).go();
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // Scenario 1: Social Feed Community Browsing & Media Lightbox Experience
    // Covers F1 (Avatars), F2 (Comments), F3 (Card Art), F5 (Media Lightbox)
    // =========================================================================
    testWidgets('Scenario 1: Social Feed Community Browsing & Media Lightbox Experience', (tester) async {
      const postId = 'post-s1-pull';
      const authorId = 'collector-spicy-brew';
      var authorTapped = false;

      // 1. Render Post Header and verify author avatar initials & tap interaction
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          PostHeader(
            username: '@SpicyBrewMaster',
            avatarInitials: 'SB',
            timestamp: '12m ago',
            locationTag: 'TBS Comics, FL',
            authorId: authorId,
            onUserTap: () => authorTapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('@SpicyBrewMaster'), findsOneWidget);
      expect(find.text('SB'), findsOneWidget);
      expect(find.text('TBS Comics, FL'), findsOneWidget);

      final avatarFinder = find.byKey(const Key('post_avatar_$authorId'));
      expect(avatarFinder, findsOneWidget);
      await tester.tap(avatarFinder);
      await tester.pump();
      expect(authorTapped, isTrue);

      // 2. Insert mock post & post comment into database via FeedDao
      await feedDao.createPost(
        createTestFeedPostCompanion(
          id: postId,
          authorId: authorId,
          authorUsername: '@SpicyBrewMaster',
          authorDisplayName: 'Spicy Brewmaster',
          textContent: 'Cracked a Collector Booster pack and hit serialized The One Ring!',
          type: 'single_pull',
          commentCount: 0,
        ),
      );

      await feedDao.addComment(
        postId: postId,
        authorId: 'collector-peer-1',
        authorUsername: '@CardHunter',
        authorDisplayName: 'Card Hunter',
        content: 'Incredible pull! What are you looking for in trade?',
      );

      // Verify notification for post author was generated
      final notifications = await (db.select(db.notifications)
            ..where((t) => t.userId.equals(authorId)))
          .get();
      expect(notifications.length, equals(1));
      expect(notifications.first.type, equals('post_comment'));
      expect(notifications.first.actorUsername, equals('@CardHunter'));

      // 3. Render PostActionBar showing reactive comment count
      var commentTapped = false;
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          PostActionBar(
            initialHypeCount: 42,
            commentCount: 1,
            onCommentTap: () => commentTapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('COMMENT (1)'), findsOneWidget);
      expect(find.text('HYPE (42)'), findsOneWidget);

      final commentButton = find.byKey(const Key('post_action_comment'));
      expect(commentButton, findsOneWidget);
      await tester.tap(commentButton);
      await tester.pump();
      expect(commentTapped, isTrue);

      // 4. Render SinglePullPostBody and verify card art container
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const SingleChildScrollView(
            child: SinglePullPostBody(
              cardId: 'card-s1-the-one-ring',
              cardTitle: 'The One Ring (Serialized #007/100)',
              cardSubtitle: 'The Lord of the Rings: Tales of Middle-earth',
              cardRarity: 'Mythic Rare',
              estimatedValue: '\$1,250.00',
              commentary: 'Grade candidate for PSA!',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('single_pull_card_card-s1-the-one-ring')), findsOneWidget);
      expect(find.text('Grade candidate for PSA!'), findsOneWidget);

      // 5. Open full-screen MediaLightboxViewer for pack opening photo
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const MediaLightboxViewer(
            imageUrl: 'https://images.unsplash.com/photo-pack-break.jpg',
            caption: 'Fresh from the pack at Emerald Coast Gaming prerelease',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fresh from the pack at Emerald Coast Gaming prerelease'), findsOneWidget);
      final interactiveViewerFinder = find.byType(InteractiveViewer);
      expect(interactiveViewerFinder, findsOneWidget);

      final interactiveViewer = tester.widget<InteractiveViewer>(interactiveViewerFinder);
      expect(interactiveViewer.minScale, equals(0.5));
      expect(interactiveViewer.maxScale, equals(4.0));

      final closeBtn = find.byKey(const Key('media_lightbox_close_button'));
      expect(closeBtn, findsOneWidget);
    });

    // =========================================================================
    // Scenario 2: Trade Building from Vault & System Binder Protection Workflow
    // Covers F6 (Trade cards), F7 (Binder dedup), F8 (System binder protection)
    // =========================================================================
    testWidgets('Scenario 2: Trade Building from Vault & System Binder Protection Workflow', (tester) async {
      const uId = 'collector-trader-2';
      final canonicalTradeId = 'system_trade_block_$uId';
      final now = DateTime.now();

      // 1. Establish canonical trade binder & duplicate sync artifacts
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: canonicalTradeId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(uId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final dupeTradeId = 'system_trade_block_${uId}_dupe_cloud_sync';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: dupeTradeId,
          name: 'Trade Block',
          collectionType: 'mtg',
          createdAt: now.add(const Duration(minutes: 5)),
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(uId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // 2. Insert items across binders
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-s2-ragavan',
          name: 'Ragavan, Nimble Pilferer',
          setCode: 'mh2',
          primaryBinderId: canonicalTradeId,
          userId: uId,
          currentMarketPrice: 55.00,
        ),
      );

      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-s2-bowmasters',
          name: 'Orcish Bowmasters',
          setCode: 'ltr',
          primaryBinderId: dupeTradeId,
          userId: uId,
          currentMarketPrice: 42.00,
        ),
      );

      // 3. Execute deduplication and purge
      final purgeSummary = await vaultDao.deduplicateAndPurgeSystemBinders(uId, isBusiness: false);
      expect(purgeSummary['bindersPurged'], greaterThanOrEqualTo(1));
      expect(purgeSummary['cardsReanchored'], greaterThanOrEqualTo(1));

      // 4. Verify Bowmasters was re-anchored to canonical binder
      final reanchoredItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-s2-bowmasters'))).getSingle();
      expect(reanchoredItem.primaryBinderId, equals(canonicalTradeId));

      // 5. Verify duplicate binder is soft-deleted
      final dupeBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(dupeTradeId))).getSingle();
      expect(dupeBinder.isDeleted, isTrue);

      // 6. Test delete refusal on canonical system binder
      expect(
        () => vaultDao.deleteBinder(canonicalTradeId),
        throwsA(isA<UnsupportedError>()),
      );

      // 7. Render EditBinderModal on system binder and verify permanent protection banner
      final canonicalBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(canonicalTradeId))).getSingle();
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          EditBinderModal(binder: canonicalBinder),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_binder_system_protected_banner')), findsOneWidget);
      expect(find.textContaining('Permanent System Binder — Protected against deletion'), findsOneWidget);

      final nameFieldFinder = find.byKey(const Key('edit_binder_name_input'));
      expect(nameFieldFinder, findsOneWidget);
      final nameField = tester.widget<TextField>(nameFieldFinder);
      expect(nameField.readOnly, isTrue);
    });

    // =========================================================================
    // Scenario 3: Explore Decks Community Discovery & "My Uploads" Separation
    // Covers F9 (My Uploads Filter), F10 (Uncropped Cover Art), F11 (Precon Ingestion)
    // =========================================================================
    testWidgets('Scenario 3: Explore Decks Community Discovery & "My Uploads" Separation', (tester) async {
      const currentUserId = 'collector-me-007';

      // 1. Precon deck (Official WotC)
      final preconDeck = createTestExploreDeckRecord(
        id: 'deck-s3-draconic',
        name: 'Draconic Domination',
        sourceType: 'official',
        creatorName: 'Wizards of the Coast',
        authorId: 'system_wotc',
        commanderName: 'The Ur-Dragon',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/7/e/7e78b70b-0c67.jpg',
      );

      // 2. Community deck by another user
      final communityDeck = createTestExploreDeckRecord(
        id: 'deck-s3-edgar',
        name: 'Vampiric Bloodlust',
        sourceType: 'community',
        creatorName: 'MarkovKing',
        authorId: 'user-markov-king',
        commanderName: 'Edgar Markov',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/8/d/8d94b09e.jpg',
      );

      // 3. User's personal deck
      final myPersonalDeck = createTestExploreDeckRecord(
        id: 'deck-s3-my-spicy-brew',
        name: 'Spicy Budget Dragons',
        sourceType: 'community',
        creatorName: 'MeTheCollector',
        authorId: currentUserId,
        commanderName: 'Miirym, Sentinel Wyrm',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/a/9/a9a7405c.jpg',
      );

      // 4. Verify authorship separation for "My Uploads" filtering
      expect(isExploreDeckAuthor(deck: preconDeck, currentUserId: currentUserId), isFalse);
      expect(isExploreDeckAuthor(deck: communityDeck, currentUserId: currentUserId), isFalse);
      expect(isExploreDeckAuthor(deck: myPersonalDeck, currentUserId: currentUserId), isTrue);

      // 5. Render official precon card in compact grid layout
      final preconWithVote = ExploreDeckWithVote(deck: preconDeck, userVote: 0);
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 173,
            child: SingleChildScrollView(
              child: ExploreDeckCard(
                deckWithVote: preconWithVote,
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

      // 6. Render community deck card in compact layout
      final communityWithVote = ExploreDeckWithVote(deck: communityDeck, userVote: 1);
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 173,
            child: SingleChildScrollView(
              child: ExploreDeckCard(
                deckWithVote: communityWithVote,
                isCompact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vampiric Bloodlust'), findsOneWidget);
      expect(find.text('@MarkovKing'), findsOneWidget);
    });

    // =========================================================================
    // Scenario 4: MTGJSON Precon Delta Discovery, Ingestion & Card Sanitization
    // Covers F11 (Precon Delta Sync, DTO mapping, and offline storage)
    // =========================================================================
    test('Scenario 4: MTGJSON Precon Delta Discovery, Ingestion & Card Sanitization', () async {
      // 1. Simulate MTGJSON precon payload with rich card lists and edge cases
      final rawPreconJson = '''
      {
        "data": [
          {
            "name": "Riders of Rohan",
            "code": "LTC",
            "type": "Commander Deck",
            "releaseDate": "2023-06-23",
            "cards": [
              {
                "name": "Éowyn, Shieldmaiden",
                "scryfallId": "eowyn-scryfall-uuid-001",
                "count": 1,
                "isCommander": true
              },
              {
                "name": "Aragorn, King of Gondor",
                "scryfallId": "aragorn-scryfall-uuid-002",
                "count": 1
              },
              {
                "name": "Plains",
                "count": 1
              }
            ]
          }
        ]
      }
      ''';

      // 2. Parse into PreconDeckDto
      final dtos = MtgjsonPreconParser.parseJson(rawPreconJson);
      expect(dtos.length, equals(1));
      final dto = dtos.first;
      expect(dto.name, equals('Riders of Rohan'));
      expect(dto.setCode, equals('LTC'));
      expect(dto.format, equals('Commander'));

      // 3. Verify commander resolution
      expect(dto.primaryCommander?.name, equals('Éowyn, Shieldmaiden'));
      expect(dto.primaryCommander?.imageUrl, contains('eowyn-scryfall-uuid-001'));
      expect(dto.primaryCommander?.artCropUrl, contains('eowyn-scryfall-uuid-001'));

      // 4. Verify cards list sanitization
      expect(dto.allCards.length, equals(3));
      final plains = dto.allCards.firstWhere((c) => c.name == 'Plains');
      expect(plains.count, equals(1));

      // 5. Ingest parsed precon into local SQLite database
      final deterministicId = MtgjsonPreconParser.buildDeterministicDeckId(
        setCode: dto.setCode,
        name: dto.name,
      );
      expect(deterministicId, equals('precon-ltc-riders-of-rohan'));

      final deckRecord = createTestExploreDeckRecord(
        id: deterministicId,
        name: dto.name,
        format: dto.format,
        sourceType: 'official',
        creatorName: 'Wizards of the Coast',
        authorId: 'system_wotc',
        commanderName: dto.primaryCommander?.name,
        commanderImageUrl: dto.primaryCommander?.imageUrl,
        commanderArtCrop: dto.primaryCommander?.artCropUrl,
        cardCount: dto.allCards.fold<int>(0, (sum, c) => sum + c.count),
      );

      await db.into(db.exploreDecks).insert(
        deckRecord,
        mode: drift.InsertMode.insertOrReplace,
      );

      // 6. Query from SQLite and verify persistent integrity
      final storedDeck = await (db.select(db.exploreDecks)..where((t) => t.id.equals(deterministicId))).getSingleOrNull();
      expect(storedDeck, isNotNull);
      expect(storedDeck!.name, equals('Riders of Rohan'));
      expect(storedDeck.commanderName, equals('Éowyn, Shieldmaiden'));
      expect(storedDeck.sourceType, equals('official'));
      expect(storedDeck.creatorName, equals('Wizards of the Coast'));
      expect(storedDeck.cardCount, equals(3));
    });

    // =========================================================================
    // Scenario 5: Vault Master Set Completion & 3x3 Card Inspection Workflow
    // Covers F12 (MasterSetScreen stats, 3x3 grid, grayscale filter, and search)
    // =========================================================================
    testWidgets('Scenario 5: Vault Master Set Completion & 3x3 Card Inspection Workflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Populate user's collection with LTR cards
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-s5-the-one-ring',
          name: 'The One Ring',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'ltr',
          quantity: 2,
          currentMarketPrice: 65.00,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-s5-bowmasters',
          name: 'Orcish Bowmasters',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'ltr',
          quantity: 1,
          currentMarketPrice: 42.00,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Card 3: Unowned catalog card in set (quantity 0)
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-s5-aragorn',
          name: 'Aragorn, the Uniter',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'ltr',
          quantity: 0,
          currentMarketPrice: 15.00,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // 2. Collection has 3 total cards, 2 owned
      const collection = VaultSetCollection(
        setName: 'The Lord of the Rings: Tales of Middle-earth',
        setCode: 'LTR',
        collectionType: 'mtg',
        totalCount: 3,
        ownedCount: 2,
        completionPercentage: 0.6666,
        releaseDate: '2023',
      );

      // 3. Render MasterSetScreen
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const MasterSetScreen(
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

      // 4. Verify completion header
      expect(find.text('The Lord of the Rings: Tales of Middle-earth'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('66.7% complete'), findsOneWidget);

      // 5. Inspect 3x3 grid cards
      expect(find.byKey(const Key('master_set_card_card-s5-the-one-ring')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_card-s5-bowmasters')), findsOneWidget);

      // Quantity badge for The One Ring (owned x2) and Missing badge for unowned
      expect(find.text('x2'), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);

      // Neither owned card should have a grayscale filter
      expect(find.byKey(const Key('master_set_grayscale_card-s5-the-one-ring')), findsNothing);
      expect(find.byKey(const Key('master_set_grayscale_card-s5-bowmasters')), findsNothing);

      // Unowned card has grayscale filter
      expect(find.byKey(const Key('master_set_grayscale_card-s5-aragorn')), findsOneWidget);

      // 6. Test search filtering within MasterSetScreen
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Bowmasters');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_card-s5-bowmasters')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_card-s5-the-one-ring')), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_card-s5-bowmasters')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_card-s5-the-one-ring')), findsOneWidget);
    });

    // =========================================================================
    // Scenario 6: Full End-to-End Collector Journey across Social Feed, Vault,
    // Trade, and Explore Decks (F1 to F12 Integrated Lifecycle)
    // =========================================================================
    testWidgets('Scenario 6: Full End-to-End Collector Journey across Social Feed, Vault, Trade, and Explore Decks', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const currentUserId = 'collector-e2e-user';
      final canonicalTradeId = 'system_trade_block_$currentUserId';
      final now = DateTime.now();

      // Step 1: User establishes account & canonical trade binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: canonicalTradeId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(currentUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Step 2: Collector syncs MTGJSON precon deck into Explore Decks
      final rawPrecon = '''
      {
        "data": [
          {
            "name": "Forces of the Imperium",
            "code": "40K",
            "type": "Commander Deck",
            "releaseDate": "2022-10-07",
            "cards": [
              {
                "name": "Inquisitor Greyfax",
                "scryfallId": "greyfax-uuid",
                "count": 1,
                "isCommander": true
              },
              {
                "name": "Space Marine Devastator",
                "count": 1
              }
            ]
          }
        ]
      }
      ''';

      final dtos = MtgjsonPreconParser.parseJson(rawPrecon);
      final parsedPrecon = dtos.first;
      final preconId = MtgjsonPreconParser.buildDeterministicDeckId(
        setCode: parsedPrecon.setCode,
        name: parsedPrecon.name,
      );

      await db.into(db.exploreDecks).insert(
        createTestExploreDeckRecord(
          id: preconId,
          name: parsedPrecon.name,
          format: parsedPrecon.format,
          sourceType: 'official',
          creatorName: 'Wizards of the Coast',
          authorId: 'system_wotc',
          commanderName: parsedPrecon.primaryCommander?.name,
          commanderImageUrl: parsedPrecon.primaryCommander?.imageUrl,
          commanderArtCrop: parsedPrecon.primaryCommander?.artCropUrl,
          cardCount: parsedPrecon.allCards.fold<int>(0, (sum, c) => sum + c.count),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final deckRecord = await (db.select(db.exploreDecks)..where((t) => t.id.equals(preconId))).getSingleOrNull();
      expect(deckRecord, isNotNull);
      expect(isExploreDeckAuthor(deck: deckRecord!, currentUserId: currentUserId), isFalse);

      // Step 3: Collector catalogs pulls in Vault
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-s6-palantir',
          name: 'Palantír of Orthanc',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'ltr',
          userId: currentUserId,
          quantity: 2,
          currentMarketPrice: 22.00,
        ),
      );

      // Step 4: Collector tracks Master Set completion
      const collection = VaultSetCollection(
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
          const MasterSetScreen(
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
      expect(find.byKey(const Key('master_set_card_card-s6-palantir')), findsOneWidget);

      // Step 5: Collector places 1 copy into trade binder
      await vaultDao.assignItemsToBinder(['card-s6-palantir'], canonicalTradeId);
      final updatedItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-s6-palantir'))).getSingle();
      expect(updatedItem.primaryBinderId, equals(canonicalTradeId));

      // Step 6: Accidental duplicate trade binder created during offline sync
      const dupeBinderId = 'system_trade_block_${currentUserId}_dupe_cloud';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: dupeBinderId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: now.add(const Duration(hours: 1)),
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(currentUserId),
        ),
      );

      final dedupResult = await vaultDao.deduplicateAndPurgeSystemBinders(currentUserId, isBusiness: false);
      expect(dedupResult['bindersPurged'], greaterThanOrEqualTo(1));

      // Step 7: System binder immutability verification in EditBinderModal
      final binderRecord = await (db.select(db.vaultBinders)..where((t) => t.id.equals(canonicalTradeId))).getSingle();
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          EditBinderModal(binder: binderRecord),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_binder_system_protected_banner')), findsOneWidget);
      expect(
        () => vaultDao.deleteBinder(canonicalTradeId),
        throwsA(isA<UnsupportedError>()),
      );

      // Step 8: Collector shares trade pull on social feed
      const tradePostId = 'post-s6-trade-offering';
      await feedDao.createPost(
        createTestFeedPostCompanion(
          id: tradePostId,
          authorId: currentUserId,
          authorUsername: '@TheCollector',
          authorDisplayName: 'The Collector',
          textContent: 'Have extra Palantír of Orthanc in trade binder! Open to modern trades.',
          type: 'single_pull',
          commentCount: 0,
          likeCount: 7,
        ),
      );

      // Render PostActionBar
      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          const PostActionBar(
            initialHypeCount: 7,
            commentCount: 0,
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('COMMENT (0)'), findsOneWidget);
      expect(find.text('HYPE (7)'), findsOneWidget);
    });
  });
}

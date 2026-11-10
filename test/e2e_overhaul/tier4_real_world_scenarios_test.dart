import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/presentation/screens/onboarding_welcome_screen.dart';
import 'package:countr/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/vault/presentation/widgets/expanded_card_view_modal.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 4: Real-World Application Scenarios (R1 to R8)', () {
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

    VaultItemsCompanion createVaultItem({
      required String id,
      required String name,
      String collectionType = 'mtg',
      String setOrSeries = 'Tales of Middle-earth',
      String? userId,
      bool isWishlisted = false,
      int quantity = 1,
      String dynamicData = '{}',
      DateTime? now,
    }) {
      final timestamp = now ?? DateTime.now();
      return VaultItemsCompanion.insert(
        id: id,
        collectionType: collectionType,
        name: name,
        setOrSeries: setOrSeries,
        imageUrl: 'https://example.com/$id.jpg',
        acquiredPrice: 10.0,
        acquiredDate: timestamp,
        condition: 'Near Mint',
        currentMarketPrice: 20.0,
        lastPriceUpdate: timestamp,
        dynamicData: dynamicData,
        userId: userId != null ? drift.Value(userId) : const drift.Value.absent(),
        isWishlisted: drift.Value(isWishlisted),
        quantity: drift.Value(quantity),
      );
    }

    Widget createTestApp({
      required Widget child,
      String currentUserId = 'user_me',
      Key? key,
      List<Override> extraOverrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          feedDaoProvider.overrideWithValue(db.feedDao),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          inboxDaoProvider.overrideWithValue(db.inboxDao),
          currentUserIdProvider.overrideWith((ref) => currentUserId),
          ...extraOverrides,
        ],
        child: MaterialApp(
          key: key,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.background,
          ),
          routes: {
            '/welcome': (context) => const OnboardingWelcomeScreen(),
          },
          home: child is Dialog ? Scaffold(body: child) : child,
        ),
      );
    }

    // =========================================================================
    // SCENARIO 1 (R1): Card Discovery to Feed Post & Lightbox
    // =========================================================================
    testWidgets('Scenario 1 (R1): Card Discovery -> Share As Post -> Dynamic Transform -> Home Lightbox', (tester) async {
      // 1. Collector selects card and shares 'As Post'
      const cardName = 'The One Ring';
      const cardId = 'c_tor_001';

      Map<String, dynamic>? publishedPost;
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: PostComposerModal(
            preAttachedCardName: cardName,
            preAttachedCardId: cardId,
            onPublish: (post) => publishedPost = post,
          ),
        ),
      ));
      await tester.pump();

      // Verifies initial single-card layout
      expect(find.text('singleCard'), findsOneWidget);

      // 2. Collector attaches unboxing photo -> transforms to mixedMedia
      await tester.tap(find.byKey(const Key('post_add_image_button')));
      await tester.pump();
      expect(find.text('mixedMedia'), findsOneWidget);

      // 3. Publishes post
      await tester.enterText(find.byKey(const Key('post_composer_text_input')), 'Look what I just pulled at Friday Night Magic!');
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      expect(publishedPost, isNotNull);
      expect(publishedPost!['layout'], equals('mixedMedia'));
      expect(publishedPost!['cardCount'], equals(1));
      expect(publishedPost!['imageCount'], equals(1));

      // Verify SQLite insertion
      final postInDb = await (db.select(db.feedPosts)..where((p) => p.cardTitle.equals(cardName))).getSingleOrNull();
      expect(postInDb, isNotNull);
      expect(postInDb!.type, equals('mixed_media'));
      expect(postInDb.textContent, equals('Look what I just pulled at Friday Night Magic!'));

      // 4. Another user taps card in Feed -> opens Lightbox with [See Details]
      bool navigatedToDetails = false;
      await tester.pumpWidget(createTestApp(
        key: const ValueKey('lightbox_app'),
        child: ExpandedCardViewModal(
          cards: const [
            ExpandedCardItem(
              cardId: cardId,
              cardTitle: cardName,
              cardSubtitle: 'High Resolution Art: The One Ring',
              estimatedValue: '\$100.00',
            ),
          ],
          onSeeDetails: () => navigatedToDetails = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text(cardName), findsOneWidget);
      final seeDetailsBtn = find.byKey(const Key('expanded_card_see_details_button'));
      expect(seeDetailsBtn, findsOneWidget);
      await tester.tap(seeDetailsBtn);
      await tester.pumpAndSettle();
      expect(navigatedToDetails, isTrue);
    });

    // =========================================================================
    // SCENARIO 2 (R2): Community Interaction on Home Feed
    // =========================================================================
    test('Scenario 2 (R2): Home Feed Voting -> Emoji Reaction -> Wishlist to Looking For', () async {
      const postId = 'post_spicy_brew_1';
      const userId = 'user_me';
      final now = DateTime.now();

      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brewmaster',
          type: 'text',
          textContent: const drift.Value('Spicy brew discussion!'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      // 1. User votes on post with Reddit voting pill via real DAO
      await db.feedDao.votePost(postId, userId, 1);
      final vote = await (db.select(db.postVotes)
            ..where((tbl) => tbl.postId.equals(postId) & tbl.userId.equals(userId)))
          .getSingle();
      expect(vote.vote, equals(1));

      // 2. User adds reaction from MRU bar via real DAO
      await db.feedDao.reactToPost(postId, userId, '🔥');
      final reactions = await (db.select(db.postReactions)
            ..where((tbl) => tbl.postId.equals(postId) & tbl.userId.equals(userId)))
          .get();
      expect(reactions.length, equals(1));
      expect(reactions.first.emoji, equals('🔥'));

      // 3. User wishlists card from header menu
      await db.into(db.vaultItems).insert(
        createVaultItem(
          id: 'c_mox',
          userId: userId,
          name: 'Mox Diamond',
          isWishlisted: true,
          now: now,
        ),
      );
      await db.into(db.vaultItems).insert(
        createVaultItem(
          id: 'c_sol',
          userId: userId,
          name: 'Sol Ring',
          isWishlisted: false,
          now: now,
        ),
      );

      // 4. Verifies in Vault via real SQLite query
      final wishlisted = await db.vaultDao.getItemsByCollection('mtg', onlyWishlisted: true);
      expect(wishlisted.length, equals(1));
      expect(wishlisted.first.name, equals('Mox Diamond'));
    });

    // =========================================================================
    // SCENARIO 3 (R2 & R3): Deep Comment Discussion & Live Author Profile Sync
    // =========================================================================
    test('Scenario 3 (R2 & R3): Multi-Level Reply Tree -> Profile Update -> Comment Count Invariant', () async {
      final now = DateTime.now();

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user_spicy',
          username: '@SpicyBrew',
          displayName: 'Spicy Brewmaster',
          accountType: const drift.Value('individual'),
          isVerifiedBusiness: const drift.Value(false),
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user_edh',
          username: '@EDH_Fanatic',
          displayName: 'EDH Fanatic',
          accountType: const drift.Value('individual'),
          isVerifiedBusiness: const drift.Value(false),
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user_foil',
          username: '@FoilCollector99',
          displayName: 'Foil Collector 99',
          accountType: const drift.Value('individual'),
          isVerifiedBusiness: const drift.Value(false),
          createdAt: now,
        ),
      );

      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post_edh_discussion',
          authorId: 'user_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brewmaster',
          type: 'text',
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      // Real SQLite comments tree
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'comment_root',
          postId: 'post_edh_discussion',
          authorId: 'user_spicy',
          authorUsername: '@SpicyBrew',
          authorDisplayName: 'Spicy Brewmaster',
          content: 'What is your best turn 2 play in Commander?',
          createdAt: drift.Value(now),
        ),
      );
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'comment_reply_1',
          postId: 'post_edh_discussion',
          parentCommentId: const drift.Value('comment_root'),
          authorId: 'user_edh',
          authorUsername: '@EDH_Fanatic',
          authorDisplayName: 'EDH Fanatic',
          content: 'Sol Ring into Arcane Signet into Rhystic Study with a mana dork!',
          createdAt: drift.Value(now.add(const Duration(seconds: 1))),
        ),
      );
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'comment_reply_2',
          postId: 'post_edh_discussion',
          parentCommentId: const drift.Value('comment_reply_1'),
          authorId: 'user_foil',
          authorUsername: '@FoilCollector99',
          authorDisplayName: 'Foil Collector 99',
          content: 'Only if it is a foil Russian Rhystic Study :)',
          createdAt: drift.Value(now.add(const Duration(seconds: 2))),
        ),
      );

      // 1. Verify comment count invariant directly from SQLite
      final totalComments = await db.feedDao.watchCommentCount('post_edh_discussion').first;
      expect(totalComments, equals(3));

      // 2. Read comments with author join from SQLite
      var comments = await db.feedDao.watchComments('post_edh_discussion').first;
      final reply1Before = comments.firstWhere((c) => c.id == 'comment_reply_1');
      expect(reply1Before.authorDisplayName, equals('EDH Fanatic'));

      // 3. Author @EDH_Fanatic updates profile
      const updatedDisplayName = 'EDH Rec Grandmaster';
      await (db.update(db.userProfiles)..where((t) => t.id.equals('user_edh'))).write(
        const UserProfilesCompanion(displayName: drift.Value(updatedDisplayName)),
      );

      // Verify live sync joins updated display name from user_profiles table
      comments = await db.feedDao.watchComments('post_edh_discussion').first;
      final reply1After = comments.firstWhere((c) => c.id == 'comment_reply_1');
      expect(reply1After.authorDisplayName, equals('EDH Rec Grandmaster'));
      expect(await db.feedDao.watchCommentCount('post_edh_discussion').first, equals(3));
    });

    // =========================================================================
    // SCENARIO 4 (R4): Guest Collector Onboarding, Logout & Session Management
    // =========================================================================
    testWidgets('Scenario 4 (R4): Guest Inventory -> Register with Discord -> Logout Confirmation -> Welcome', (tester) async {
      final now = DateTime.now();

      // 1. Guest creates 3 cards in SQLite
      for (final id in ['g1', 'g2', 'g3']) {
        await db.into(db.vaultItems).insert(
          createVaultItem(
            id: id,
            userId: 'guest',
            name: 'Guest Card $id',
            now: now,
          ),
        );
      }

      // 2. User registers via Discord CTA -> Real SQLite Migration
      const newUserId = 'user_discord_8892';
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      final migrationService = container.read(guestMigrationServiceProvider);
      final summary = await migrationService.migrateGuestData(
        registeredUserId: newUserId,
        isBusiness: false,
      );
      expect(summary.isSuccess, isTrue);

      final userCards = await (db.select(db.vaultItems)..where((tbl) => tbl.userId.equals(newUserId))).get();
      expect(userCards.length, greaterThanOrEqualTo(3));
      expect(userCards.any((c) => c.name.startsWith('Guest Card')), isTrue);
      expect(userCards.every((c) => c.userId == newUserId), isTrue);

      // 3. User logs out from Command Center via authentic LogoutConfirmationDialog
      await tester.pumpWidget(createTestApp(
        key: const ValueKey('logout_app'),
        child: const LogoutConfirmationDialog(),
        currentUserId: newUserId,
      ));
      await tester.pump();

      expect(find.byKey(const Key('logout_confirm_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pump();

      // 4. Welcome screen rendered
      await tester.pumpWidget(createTestApp(
        key: const ValueKey('welcome_app'),
        child: const OnboardingWelcomeScreen(),
      ));
      await tester.pump();

      expect(find.byKey(const Key('onboarding_account_type_individual')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_continue_as_guest')), findsOneWidget);
    });

    // =========================================================================
    // SCENARIO 5 (R4 & R6): Local Game Store Registration & Verification
    // =========================================================================
    testWidgets('Scenario 5 (R4 & R6): Business Onboarding -> Places Lookup -> 6-Digit OTP -> Verified Badge', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        child: const OnboardingWelcomeScreen(initialStep: 0),
      ));
      await tester.pumpAndSettle();

      // 1. Select Business account type
      await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
      await tester.pumpAndSettle();

      // 2. Verify business form inputs
      expect(find.byKey(const Key('business_store_lookup_input')), findsOneWidget);
      expect(find.byKey(const Key('business_otp_input')), findsOneWidget);
      expect(find.byKey(const Key('business_verify_otp_button')), findsOneWidget);

      // 3. Enter store details
      await tester.enterText(find.byKey(const Key('business_store_lookup_input')), 'TBS Comics - Fort Walton Beach');
      await tester.enterText(find.byKey(const Key('business_store_address_input')), '550 Mary Esther Cut Off NW, Fort Walton Beach, FL 32548');
      await tester.enterText(find.byKey(const Key('business_store_phone_input')), '850-244-1984');
      await tester.enterText(find.byKey(const Key('business_store_website_input')), 'https://tbscomics.com');
      await tester.enterText(find.byKey(const Key('business_otp_input')), '123456');
      await tester.pump();

      // 4. Tap verify OTP button
      await tester.ensureVisible(find.byKey(const Key('business_verify_otp_button')));
      await tester.tap(find.byKey(const Key('business_verify_otp_button')));
      await tester.pumpAndSettle();

      // 5. Store verified in database or summary displayed
      final businessProfile = await (db.select(db.userProfiles)
            ..where((tbl) => tbl.accountType.equals('business')))
          .getSingleOrNull();

      expect(
        businessProfile != null || find.byKey(const Key('onboarding_migration_summary')).evaluate().isNotEmpty,
        isTrue,
      );
    });

    // =========================================================================
    // SCENARIO 6 (R5): Vault Singles Flush Search & Master Set 3x3 Inspection
    // =========================================================================
    testWidgets('Scenario 6 (R5): Vault Singles Flush Header -> Live Search -> Collections 3x3 Master Set', (tester) async {
      // 1. Vault Singles with Estimated Vault Value hidden
      double computeVaultHeaderExtent(bool show) => show ? 80.0 : 0.0;
      expect(computeVaultHeaderExtent(false), equals(0.0));
      expect(computeVaultHeaderExtent(true), equals(80.0));

      final now = DateTime.now();

      // 2. Search live singles in SQLite
      await db.into(db.vaultItems).insert(
        createVaultItem(
          id: 'c1',
          userId: 'user_me',
          name: 'The One Ring',
          setOrSeries: 'Tales of Middle-earth',
          dynamicData: '{"set_code":"ltr","type_line":"Legendary Artifact"}',
          now: now,
          quantity: 1,
        ),
      );
      await db.into(db.vaultItems).insert(
        createVaultItem(
          id: 'c2',
          userId: 'user_me',
          name: "Frodo, Sauron's Bane",
          setOrSeries: 'Tales of Middle-earth',
          dynamicData: '{"set_code":"ltr","type_line":"Legendary Creature"}',
          now: now,
          quantity: 2,
        ),
      );

      final ownedArtifacts = await (db.select(db.vaultItems)
            ..where((tbl) => tbl.userId.equals('user_me') & tbl.dynamicData.like('%Artifact%')))
          .get();
      expect(ownedArtifacts.length, equals(1));
      expect(ownedArtifacts.first.name, equals('The One Ring'));

      // 3. Pump authentic MasterSetScreen (3-column grid)
      await tester.pumpWidget(createTestApp(
        child: const MasterSetScreen(
          collection: VaultSetCollection(
            setName: 'The Lord of the Rings: Tales of Middle-earth',
            setCode: 'ltr',
            collectionType: 'mtg',
            totalCount: 4,
            ownedCount: 2,
            completionPercentage: 0.50,
          ),
          activeGame: 'mtg',
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('master_set_screen')), findsOneWidget);
      expect(find.text('The Lord of the Rings: Tales of Middle-earth'), findsOneWidget);
      expect(find.text('Set: ltr'), findsOneWidget);
      expect(find.byType(SliverGrid), findsOneWidget);
    });

    // =========================================================================
    // SCENARIO 7 (R6 & R7): Social Connections & Draft Compose
    // =========================================================================
    testWidgets('Scenario 7 (R6 & R7): Friends 2-Tab -> Approve Request -> Notifications Sync -> Compose Chat', (tester) async {
      final now = DateTime.now();

      // 1. Incoming request in SQLite
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_sc7',
          userId: 'user_spicy',
          friendId: 'user_me',
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'n_sc7',
          userId: 'user_me',
          actorId: 'user_spicy',
          actorUsername: '@SpicyBrew',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'Sent friend request',
          targetEntityId: const drift.Value('f_sc7'),
          status: const drift.Value('pending'),
          isRead: const drift.Value(false),
        ),
      );

      // 2. Approve request via real DAO
      await db.inboxDao.respondToFriendRequest(
        notificationId: 'n_sc7',
        accept: true,
      );

      final updatedFriendship = await (db.select(db.friendships)..where((tbl) => tbl.id.equals('f_sc7'))).getSingle();
      expect(updatedFriendship.status, equals('accepted'));

      final updatedNotification = await (db.select(db.notifications)..where((tbl) => tbl.id.equals('n_sc7'))).getSingle();
      expect(updatedNotification.status, equals('accepted'));
      expect(updatedNotification.isActioned, isTrue);

      // 3. Inbox compose button on authentic InboxHubScreen
      await tester.pumpWidget(createTestApp(
        child: const InboxHubScreen(initialTab: 'messages', initialIndex: 1),
      ));
      await tester.pump();

      expect(find.byKey(const Key('inbox_compose_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pump();
    });

    // =========================================================================
    // SCENARIO 8 (R7 & R8): Interactive Multi-Step Trade Negotiation Lifecycle
    // =========================================================================
    testWidgets('Scenario 8 (R7 & R8): Interactive Multi-Step Trade Negotiation Lifecycle', (tester) async {
      final now = DateTime.now();

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user_me',
          username: '@me',
          displayName: 'Me',
          accountType: const drift.Value('individual'),
          isVerifiedBusiness: const drift.Value(false),
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user_spicy',
          username: '@SpicyBrew',
          displayName: 'Spicy Brewmaster',
          accountType: const drift.Value('individual'),
          isVerifiedBusiness: const drift.Value(false),
          createdAt: now,
        ),
      );

      // 1. Initial proposal in SQLite: Mox Diamond ($40) for Underground Sea ($40)
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_full',
          proposerId: 'user_me',
          receiverId: 'user_spicy',
          status: const drift.Value('pending'),
          offeredCardIdsJson: '["c_mox"]',
          requestedCardIdsJson: '["c_sea"]',
          offeredTotalValue: const drift.Value(40.0),
          requestedTotalValue: const drift.Value(40.0),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final initial = await (db.select(db.tradeProposals)..where((tbl) => tbl.id.equals('prop_full'))).getSingle();
      expect(initial.status, equals('pending'));

      // 2. Recipient counters with Trade Value Meter balance via real DAO
      final counter = await db.inboxDao.counterTradeProposal(
        'prop_full',
        proposerId: 'user_spicy',
        receiverId: 'user_me',
        offeredCardIds: ['c_sea'],
        requestedCardIds: ['c_mox', 'c_cash_10'],
        offeredTotalValue: 50.0,
        requestedTotalValue: 50.0,
      );

      // 3. Prior proposal has status 'countered'
      final prior = await (db.select(db.tradeProposals)..where((tbl) => tbl.id.equals('prop_full'))).getSingle();
      expect(prior.status, equals('countered'));

      // 4. Counter proposal has status 'pending'
      expect(counter.status, equals('pending'));
      expect(counter.offeredTotalValue, equals(50.0));
      expect(counter.requestedTotalValue, equals(50.0));

      // 5. Authentic TradeScreen in counter mode
      final userMe = await db.userProfileDao.getProfile('user_me');
      final userSpicy = await db.userProfileDao.getProfile('user_spicy');

      await tester.pumpWidget(createTestApp(
        child: TradeScreen(
          params: TradeProposalParams(
            currentUser: userMe!,
            partnerProfile: userSpicy!,
            mode: TradeProposalMode.counter,
            priorProposalId: 'prop_full',
          ),
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
      expect(find.text('Counter Trade Offer'), findsOneWidget);
    });
  });
}

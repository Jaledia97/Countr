import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/presentation/widgets/trade_card_selection_sheet.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'trade_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime.now();

  final meUser = UserProfile(
    id: 'user-current-me',
    username: '@alice_proposer',
    displayName: 'Alice Proposer',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 3,
    repCount: 15,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'private', // Alice has private collection
  );

  final publicPartner = UserProfile(
    id: 'user-public-bob',
    username: '@bob_public',
    displayName: 'Bob Public',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 10,
    repCount: 42,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'public',
  );

  final privatePartner = UserProfile(
    id: 'user-private-charlie',
    username: '@charlie_private',
    displayName: 'Charlie Private',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 1,
    repCount: 5,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'private',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Upsert Profiles
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: meUser.id,
        username: meUser.username,
        displayName: meUser.displayName,
        collectionVisibility: const Value('private'),
        createdAt: now,
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: publicPartner.id,
        username: publicPartner.username,
        displayName: publicPartner.displayName,
        collectionVisibility: const Value('public'),
        createdAt: now,
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: privatePartner.id,
        username: privatePartner.username,
        displayName: privatePartner.displayName,
        collectionVisibility: const Value('private'),
        createdAt: now,
      ),
    );

    // Create system binders for Bob (Public Partner)
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_${publicPartner.id}',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: Value(publicPartner.id),
        createdAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );

    // Create system binders for Charlie (Private Partner)
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_${privatePartner.id}',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: Value(privatePartner.id),
        createdAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );

    // Create system binders for Alice (Current User / Proposer)
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_${meUser.id}',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: Value(meUser.id),
        createdAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );

    // Seed Cards for Bob (Public)
    // 1. Trade Binder Card 1
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'bob-binder-1',
        name: 'Force of Will',
        setOrSeries: 'ALL',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 80.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 85.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        primaryBinderId: Value('system_trade_block_${publicPartner.id}'),
        userId: Value(publicPartner.id),
      ),
    );
    // 2. Trade Binder Card 2
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'bob-binder-2',
        name: 'Mana Vault',
        setOrSeries: '2X2',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 50.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 55.0,
        lastPriceUpdate: now,
        dynamicData: '{"finish": "foil"}',
        primaryBinderId: Value('system_trade_block_${publicPartner.id}'),
        userId: Value(publicPartner.id),
      ),
    );
    // 3. Collection-Only Card 1
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'bob-coll-1',
        name: 'Black Lotus Display Piece',
        setOrSeries: 'CED',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 1200.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Mint',
        currentMarketPrice: 1500.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: Value(publicPartner.id),
      ),
    );
    // 4. Traded Out Card (is_traded = true) -> must NEVER be shown
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'bob-traded',
        name: 'Traded Away Card',
        setOrSeries: 'MH2',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Played',
        isTraded: const Value(true),
        currentMarketPrice: 20.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        primaryBinderId: Value('system_trade_block_${publicPartner.id}'),
        userId: Value(publicPartner.id),
      ),
    );
    // 5. Zero-Quantity Card -> must NEVER be shown
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'bob-zero-qty',
        name: 'Ghost Card Zero Qty',
        setOrSeries: 'MH2',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: now,
        quantity: const Value(0),
        condition: 'Played',
        currentMarketPrice: 20.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        primaryBinderId: Value('system_trade_block_${publicPartner.id}'),
        userId: Value(publicPartner.id),
      ),
    );

    // Seed Cards for Charlie (Private Partner)
    // 1. Trade Binder Card
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'charlie-binder-1',
        name: 'Underground Sea (Trade Binder)',
        setOrSeries: '3ED',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 700.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 750.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        primaryBinderId: Value('system_trade_block_${privatePartner.id}'),
        userId: Value(privatePartner.id),
      ),
    );
    // 2. Collection-Only Private Secret Card
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'charlie-coll-secret',
        name: 'Super Secret Personal Alpha Card',
        setOrSeries: 'LEA',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 5000.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 6000.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: Value(privatePartner.id),
      ),
    );

    // Seed Cards for Alice (Proposer with Private Collection)
    // 1. Trade Binder Card
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'alice-binder-1',
        name: 'Alice Trade Card 1',
        setOrSeries: 'MH3',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 30.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 35.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        primaryBinderId: Value('system_trade_block_${meUser.id}'),
        userId: Value(meUser.id),
      ),
    );
    // 2. Collection-Only Card
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'alice-coll-1',
        name: 'Alice Personal Collection Card',
        setOrSeries: 'MH3',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 100.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 120.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: Value(meUser.id),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSelectionSheetTestWidget({
    required UserProfile user,
    required bool isProposer,
    required ValueChanged<VaultItem> onCardToggled,
    Set<String> currentlySelectedCardIds = const {},
    double textScaleFactor = 1.0,
    Size surfaceSize = const Size(550, 900),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => meUser.id),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize,
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: Scaffold(
            body: TradeCardSelectionSheet(
              user: user,
              isProposer: isProposer,
              currentlySelectedCardIds: currentlySelectedCardIds,
              onCardToggled: onCardToggled,
            ),
          ),
        ),
      ),
    );
  }

  group('Adversarial Test Suite 1: TradeCardSelectionSheet Privacy & Filtering', () {
    testWidgets('Public Partner: 3-way toggle switches reactively between Trade Binder, Collection, and Both', (tester) async {
      await tester.binding.setSurfaceSize(const Size(550, 900));
      VaultItem? lastToggled;

      await tester.pumpWidget(
        buildSelectionSheetTestWidget(
          user: publicPartner,
          isProposer: false,
          onCardToggled: (item) => lastToggled = item,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 3-way Segmented Button is displayed; private banner is NOT displayed
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);
      expect(find.byKey(const Key('partner_collection_private_banner')), findsNothing);

      // 2. Default state: Trade Binder
      // Should show 'Force of Will' ($85.00) and 'Mana Vault' ($55.00)
      // Should NOT show 'Black Lotus Display Piece', traded cards, or zero-qty cards
      expect(find.text('Force of Will'), findsOneWidget);
      expect(find.text('Mana Vault'), findsOneWidget);
      expect(find.text('Black Lotus Display Piece'), findsNothing);
      expect(find.text('Traded Away Card'), findsNothing);
      expect(find.text('Ghost Card Zero Qty'), findsNothing);

      // Verify foil badge is rendered for 'Mana Vault'
      expect(find.text('FOIL'), findsOneWidget);

      // 3. Switch to Collection
      await tester.tap(find.byKey(const Key('trade_card_source_collection')));
      await tester.pumpAndSettle();

      // Now should show 'Black Lotus Display Piece' ($1500.00)
      // Should NOT show 'Force of Will' or 'Mana Vault'
      expect(find.text('Black Lotus Display Piece'), findsOneWidget);
      expect(find.text('Force of Will'), findsNothing);
      expect(find.text('Mana Vault'), findsNothing);

      // 4. Switch to Both
      await tester.tap(find.byKey(const Key('trade_card_source_both')));
      await tester.pumpAndSettle();

      // Now should show all 3 active cards simultaneously
      expect(find.text('Black Lotus Display Piece'), findsOneWidget);
      expect(find.text('Force of Will'), findsOneWidget);
      expect(find.text('Mana Vault'), findsOneWidget);
      expect(find.text('Traded Away Card'), findsNothing);
      expect(find.text('Ghost Card Zero Qty'), findsNothing);

      // 5. Verify tapping card invokes onCardToggled with correct model
      await tester.tap(find.text('Black Lotus Display Piece'));
      await tester.pumpAndSettle();
      expect(lastToggled, isNotNull);
      expect(lastToggled!.id, equals('bob-coll-1'));
      expect(lastToggled!.currentMarketPrice, equals(1500.0));
    });

    testWidgets('Private Partner: 3-way toggle hidden, lock banner rendered, collection cards unreachable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(550, 900));
      VaultItem? lastToggled;

      await tester.pumpWidget(
        buildSelectionSheetTestWidget(
          user: privatePartner,
          isProposer: false,
          onCardToggled: (item) => lastToggled = item,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Lock Banner is rendered
      expect(find.byKey(const Key('partner_collection_private_banner')), findsOneWidget);
      expect(find.text("Partner's collection is Private (Trade Binder only)"), findsOneWidget);

      // 2. Verify Segmented 3-Way toggle is completely hidden
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsNothing);

      // 3. Verify only Trade Binder card is shown
      expect(find.text('Underground Sea (Trade Binder)'), findsOneWidget);

      // 4. Invariant: Private Collection card MUST NOT be reachable or selectable
      expect(find.text('Super Secret Personal Alpha Card'), findsNothing);

      // Tapping trade card works
      await tester.tap(find.text('Underground Sea (Trade Binder)'));
      await tester.pumpAndSettle();
      expect(lastToggled, isNotNull);
      expect(lastToggled!.id, equals('charlie-binder-1'));
    });

    testWidgets('Dynamic Privacy Transition: Partner flips public -> private while sheet is active', (tester) async {
      await tester.binding.setSurfaceSize(const Size(550, 900));

      await tester.pumpWidget(
        buildSelectionSheetTestWidget(
          user: publicPartner,
          isProposer: false,
          onCardToggled: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Initially Public
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);
      expect(find.byKey(const Key('partner_collection_private_banner')), findsNothing);

      // Partner updates privacy to private in database
      await db.userProfileDao.updateCollectionVisibility(publicPartner.id, 'private');
      await tester.pumpAndSettle();

      // Sheet must reactively hide 3-way toggle and display lock banner!
      expect(find.byKey(const Key('partner_collection_private_banner')), findsOneWidget);
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsNothing);
    });

    testWidgets('Proposer Side: Can ALWAYS choose source even when proposer collection visibility is private', (tester) async {
      await tester.binding.setSurfaceSize(const Size(550, 900));

      // Alice's profile has collectionVisibility: 'private'
      await tester.pumpWidget(
        buildSelectionSheetTestWidget(
          user: meUser,
          isProposer: true,
          onCardToggled: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Proposer must see 3-way toggle, not the lock banner
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);
      expect(find.byKey(const Key('partner_collection_private_banner')), findsNothing);

      // Verify Proposer defaults to Both (can view both Trade Binder and Collection cards)
      expect(find.text('Alice Trade Card 1'), findsOneWidget);
      expect(find.text('Alice Personal Collection Card'), findsOneWidget);

      // Switch to Trade Binder
      await tester.tap(find.byKey(const Key('trade_card_source_trade_binder')));
      await tester.pumpAndSettle();

      expect(find.text('Alice Trade Card 1'), findsOneWidget);
      expect(find.text('Alice Personal Collection Card'), findsNothing);

      // Switch to Collection
      await tester.tap(find.byKey(const Key('trade_card_source_collection')));
      await tester.pumpAndSettle();

      // Proposer can view their own Collection cards despite privacy setting
      expect(find.text('Alice Personal Collection Card'), findsOneWidget);
      expect(find.text('Alice Trade Card 1'), findsNothing);

      // Switch back to Both
      await tester.tap(find.byKey(const Key('trade_card_source_both')));
      await tester.pumpAndSettle();

      expect(find.text('Alice Trade Card 1'), findsOneWidget);
      expect(find.text('Alice Personal Collection Card'), findsOneWidget);
    });
  });

  group('Adversarial Test Suite 2: TradeScreen Pre-Selection & StickyTradeValueMeter', () {
    testWidgets('First Frame Invariant: initialPartnerCard is staged and values are computed immediately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final preselectedCard = createTestCard(
        id: 'card-timetwister',
        name: 'Timetwister Collector Edition',
        currentMarketPrice: 2800.0,
        userId: publicPartner.id,
      );

      final params = TradeProposalParams(
        currentUser: meUser,
        partnerProfile: publicPartner,
        initialPartnerCard: preselectedCard,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            inboxDaoProvider.overrideWithValue(db.inboxDao),
          ],
          child: MaterialApp(
            home: TradeScreen(params: params),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify TradeScreen and StickyTradeValueMeter render immediately
      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
      expect(find.byKey(const Key('trade_fairness_gauge')), findsOneWidget);

      // 2. Verify preselected card is staged in partner's sending pod and user's receiving pod
      final partnerPod = find.byKey(Key('trade_participant_pod_${publicPartner.id}'));
      final userPod = find.byKey(Key('trade_participant_pod_${meUser.id}'));
      expect(partnerPod, findsOneWidget);
      expect(userPod, findsOneWidget);

      expect(find.descendant(of: partnerPod, matching: find.text('Timetwister Collector Edition')), findsOneWidget);
      expect(find.descendant(of: userPod, matching: find.text('Timetwister Collector Edition')), findsOneWidget);

      // 3. Verify StickyTradeValueMeter reflects the non-zero market totals immediately
      expect(find.textContaining('2800.00'), findsWidgets);

      // 4. Verify TradeFairnessGauge reflects 100.0% gap / LOPSIDED immediately without interaction
      expect(find.textContaining('LOPSIDED (100.0% gap)'), findsOneWidget);
    });

    testWidgets('Interactive Balancing: Adding equal value card shifts fairness gauge to FAIR dynamically', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final preselectedCard = createTestCard(
        id: 'card-lotus-petal',
        name: 'Lotus Petal Foil',
        currentMarketPrice: 100.0,
        userId: publicPartner.id,
      );

      final params = TradeProposalParams(
        currentUser: meUser,
        partnerProfile: publicPartner,
        initialPartnerCard: preselectedCard,
      );

      final controller = TradeProposalController(params);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            inboxDaoProvider.overrideWithValue(db.inboxDao),
            tradeProposalControllerProvider(params).overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: TradeScreen(params: params),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: Partner $100 vs User $0 -> LOPSIDED
      expect(find.textContaining('LOPSIDED (100.0% gap)'), findsOneWidget);

      // User adds card worth $98.00 (gap = 2.0% <= 10% -> FAIR)
      final aliceCard = createTestCard(
        id: 'alice-card-balance',
        name: 'Mox Opal',
        currentMarketPrice: 98.0,
        userId: meUser.id,
      );
      controller.addSendingCard(meUser.id, aliceCard);
      await tester.pumpAndSettle();

      // Value meter must now display both sides and FAIR gauge
      expect(find.textContaining('FAIR (2.0% gap)'), findsOneWidget);
      expect(find.textContaining('100.00'), findsWidgets);
      expect(find.textContaining('98.00'), findsWidgets);

      // Remove partner card -> Value meter drops partner side to $0.00
      controller.removeSendingCard(publicPartner.id, preselectedCard.id);
      await tester.pumpAndSettle();

      expect(find.textContaining('LOPSIDED (100.0% gap)'), findsOneWidget);
    });
  });

  group('Adversarial Test Suite 3: FeedScreen Bell Red Dot Zero Self-Notification Invariant', () {
    testWidgets('Red Dot Badge stays false during outgoing actions & rogue self-notifications; triggers only for incoming foreign notifications', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => meUser.id),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear any auto-seeded social notifications
      await db.delete(db.notifications).go();
      await db.delete(db.messages).go();
      await tester.pumpAndSettle();

      final bellFinder = find.byKey(const Key('feed_bell_red_dot'));
      expect(bellFinder, findsOneWidget);
      var badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isFalse);

      // 1. Outgoing Trade Proposal by Alice to Bob
      await db.inboxDao.createTradeProposal(
        proposerId: meUser.id,
        receiverId: publicPartner.id,
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
        offeredTotalValue: 150.0,
        requestedTotalValue: 150.0,
      );
      await tester.pumpAndSettle();

      badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isFalse, reason: 'Outgoing trade proposal must never illuminate red dot for sender');

      // 2. Outgoing Friend Request from Alice to Bob
      await db.friendsDao.sendFriendRequest(meUser.id, publicPartner.id);
      await tester.pumpAndSettle();

      badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isFalse, reason: 'Outgoing friend request must never illuminate red dot for sender');

      // 3. Outgoing Direct Message from Alice to Bob
      await db.inboxDao.sendMessage(
        senderId: meUser.id,
        recipientId: publicPartner.id,
        messageText: 'Hello Bob, interested in trading?',
      );
      await tester.pumpAndSettle();

      badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isFalse, reason: 'Outgoing message must never illuminate red dot for sender');

      // 4. Rogue / Corrupted Self-Notification (userId == actorId == meUser.id)
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'corrupt_self_notif_1',
          userId: meUser.id,
          actorId: meUser.id,
          actorUsername: meUser.username,
          type: 'trade_proposal',
          title: 'Self Action Trade',
          body: 'You proposed a trade',
          isRead: const Value(false),
          createdAt: Value(DateTime.now()),
        ),
      );
      await tester.pumpAndSettle();

      badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isFalse, reason: 'Rogue notification where actorId == userId must be filtered out by DAO');

      // 5. Soft-Deleted Foreign Notification (isDeleted == true)
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'deleted_foreign_notif',
          userId: meUser.id,
          actorId: publicPartner.id,
          actorUsername: publicPartner.username,
          type: 'post_like',
          title: 'Bob liked your post',
          body: 'liked your post',
          isRead: const Value(false),
          isDeleted: const Value(true),
          createdAt: Value(DateTime.now()),
        ),
      );
      await tester.pumpAndSettle();

      badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isFalse, reason: 'Deleted notifications must never illuminate red dot');

      // 6. Valid Incoming Notification from Bob to Alice
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'valid_incoming_trade_match',
          userId: meUser.id,
          actorId: publicPartner.id,
          actorUsername: publicPartner.username,
          type: 'trade_match',
          title: 'Trade Match Alert',
          body: '@bob_public has Force of Will in their Trade Binder!',
          isRead: const Value(false),
          createdAt: Value(DateTime.now()),
        ),
      );
      await tester.pumpAndSettle();

      // Red Dot MUST now illuminate!
      badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isTrue, reason: 'Incoming foreign notification must illuminate red dot badge');

      // 7. Mark all notifications as read
      await db.inboxDao.markAllNotificationsAsRead(meUser.id);
      await tester.pumpAndSettle();

      // Red Dot turns back off!
      badge = tester.widget<Badge>(bellFinder);
      expect(badge.isLabelVisible, isFalse, reason: 'Marking notifications as read must turn off red dot badge');
    });
  });

  group('Adversarial Test Suite 4: UI & Viewport Resilience Stress Tests', () {
    testWidgets('TradeCardSelectionSheet: Standard viewport (550px) renders cleanly with zero RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(550, 900));

      await tester.pumpWidget(
        buildSelectionSheetTestWidget(
          user: publicPartner,
          isProposer: false,
          onCardToggled: (_) {},
          surfaceSize: const Size(550, 900),
          textScaleFactor: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TradeCardSelectionSheet: Narrow viewport (320px) with 1.8x text scale empirically demonstrates RenderFlex overflow vulnerability', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      // Seed a card with an extremely long title and massive price
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'extreme-long-card',
          name: 'The Ultimate Ultra Extended Art Foil Mythic Rare Dragon with Longest Title in History',
          setOrSeries: 'SPECIAL-EDITION-2026',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 99999.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 123456.78,
          lastPriceUpdate: now,
          dynamicData: '{"finish": "etched"}',
          primaryBinderId: Value('system_trade_block_${publicPartner.id}'),
          userId: Value(publicPartner.id),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      final capturedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => capturedErrors.add(details);
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        buildSelectionSheetTestWidget(
          user: publicPartner,
          isProposer: false,
          onCardToggled: (_) {},
          surfaceSize: const Size(320, 568),
          textScaleFactor: 1.8,
        ),
      );
      await tester.pumpAndSettle();

      // Assert sheet renders the filter
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);

      // Verify layout overflow is empirically reproduced and detected
      final hasRenderFlexOverflow = capturedErrors.any((e) => e.toString().contains('A RenderFlex overflowed'));
      expect(hasRenderFlexOverflow, isTrue, reason: 'Header row at trade_card_selection_sheet.dart:106 lacks Expanded');
    });

    testWidgets('TradeScreen: Standard viewport (450px) renders cleanly with zero RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      final testCard = createTestCard(
        id: 'card-standard-pod',
        name: 'Sol Ring',
        currentMarketPrice: 15.0,
        userId: publicPartner.id,
      );

      final params = TradeProposalParams(
        currentUser: meUser,
        partnerProfile: publicPartner,
        initialPartnerCard: testCard,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            inboxDaoProvider.overrideWithValue(db.inboxDao),
          ],
          child: MaterialApp(
            home: TradeScreen(params: params),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TradeScreen: Narrow viewport (320px) with 1.6x text scale empirically demonstrates AppBar and Pod overflow vulnerability', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));

      final expensiveLongCard = createTestCard(
        id: 'card-extreme-value',
        name: 'Extremely Long Name for Staged Partner Card Alpha Version',
        currentMarketPrice: 88888.88,
        userId: publicPartner.id,
      );

      final params = TradeProposalParams(
        currentUser: meUser,
        partnerProfile: publicPartner,
        initialPartnerCard: expensiveLongCard,
      );

      final capturedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => capturedErrors.add(details);
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            inboxDaoProvider.overrideWithValue(db.inboxDao),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.6),
              ),
              child: TradeScreen(params: params),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;

      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);

      // Verify layout overflow is eliminated in AppBar and receiving chip on narrow viewport
      final hasRenderFlexOverflow = capturedErrors.any((e) => e.toString().contains('A RenderFlex overflowed'));
      expect(hasRenderFlexOverflow, isFalse, reason: 'AppBar action and receiving chip row overflow on narrow viewport');
    });

    testWidgets('FeedScreen AppBar: Narrow viewport (300px) has zero RenderFlex overflow when toggling search and notifications', (tester) async {
      await tester.binding.setSurfaceSize(const Size(300, 600));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => meUser.id),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(300, 600),
              ),
              child: FeedScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state
      expect(find.byKey(const Key('feed_appbar_notification_bell')), findsOneWidget);
      expect(find.byKey(const Key('feed_bell_red_dot')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap search button to expand search bar in narrow viewport
      await tester.tap(find.byKey(const Key('feed_appbar_search_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_input')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

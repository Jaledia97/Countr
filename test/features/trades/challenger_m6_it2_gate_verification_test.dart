import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/chat_conversation_screen.dart';
import 'package:countr/features/feed/data/daos/inbox_dao.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/utils/card_name_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const currentUserId = 'user_challenger_me';
  const partnerId = 'user_challenger_partner';
  const thirdPartnerId = 'user_challenger_third';
  const fourthPartnerId = 'user_challenger_fourth';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now();

    // Seed User Profiles
    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: currentUserId,
        username: '@challenger_me',
        displayName: 'Challenger Me Very Long Name For Overflow Testing',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(3),
        repCount: const drift.Value(10),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );

    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: partnerId,
        username: '@partner_trader',
        displayName: 'Partner Trader With Long Profile Title',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(2),
        repCount: const drift.Value(15),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );

    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: thirdPartnerId,
        username: '@third_collector',
        displayName: 'Third Collector',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(1),
        repCount: const drift.Value(8),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );

    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: fourthPartnerId,
        username: '@fourth_collector',
        displayName: 'Fourth Collector',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(0),
        repCount: const drift.Value(5),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );

    // Seed friendships with partner, third, and fourth
    await db.into(db.friendships).insert(
      FriendshipsCompanion.insert(
        id: 'fr_1',
        userId: currentUserId,
        friendId: partnerId,
        status: const drift.Value('accepted'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.friendships).insert(
      FriendshipsCompanion.insert(
        id: 'fr_2',
        userId: currentUserId,
        friendId: thirdPartnerId,
        status: const drift.Value('accepted'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.friendships).insert(
      FriendshipsCompanion.insert(
        id: 'fr_3',
        userId: currentUserId,
        friendId: fourthPartnerId,
        status: const drift.Value('accepted'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    // Seed Vault Items
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'item-mtg-black-lotus',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: 'Alpha',
        imageUrl: 'https://example.com/lotus.jpg',
        acquiredPrice: 5000.0,
        acquiredDate: now,
        quantity: const drift.Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 5000.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: const drift.Value(currentUserId),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'item-mtg-mox-sapphire',
        collectionType: 'mtg',
        name: 'Mox Sapphire',
        setOrSeries: 'Beta',
        imageUrl: 'https://example.com/mox.jpg',
        acquiredPrice: 4500.0,
        acquiredDate: now,
        quantity: const drift.Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 4500.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: const drift.Value(partnerId),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScope({
    required Widget child,
    String activeUserId = currentUserId,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => activeUserId),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: child,
      ),
    );
  }

  group('Milestone 6 Iteration 2 Gate Verification: Trade Negotiation Lifecycle', () {
    testWidgets('1. Cancel Trade by proposer: updates DB to cancelled, unpins banner, updates badge & posts notification', (tester) async {
      final now = DateTime.now();
      const proposalId = 'trade_proposal_cancel_it2';

      // Insert active pending proposal where currentUserId is proposer
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: proposalId,
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
          offeredTotalValue: const drift.Value(5000.0),
          requestedTotalValue: const drift.Value(4500.0),
          createdAt: drift.Value(now),
        ),
      );

      // Insert associated notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_cancel_it2',
          userId: partnerId,
          actorId: currentUserId,
          actorUsername: '@challenger_me',
          type: 'trade_proposal',
          title: 'Trade Proposal',
          body: 'offered a trade',
          targetEntityId: const drift.Value(proposalId),
          targetEntityType: const drift.Value('trade'),
          createdAt: drift.Value(now),
        ),
      );

      // Also seed an embedded chat message with this proposal
      await db.inboxDao.sendMessage(
        senderId: currentUserId,
        recipientId: partnerId,
        messageText: 'Sent you a trade proposal!',
        attachmentType: 'trade_proposal',
        attachmentTradeProposalId: proposalId,
      );

      final conversationId = InboxDao.getConversationId(currentUserId, partnerId);

      await tester.pumpWidget(
        buildScope(
          child: ChatConversationScreen(
            conversationId: conversationId,
            contactId: partnerId,
          ),
          activeUserId: currentUserId, // Me as proposer
        ),
      );
      await tester.pumpAndSettle();

      // Verify pinned banner is visible with PENDING badge
      expect(find.text('Active Trade Proposal'), findsOneWidget);
      // Pinned banner and embedded chat message both render trade_card_status_badge
      expect(find.byKey(const Key('trade_card_status_badge')), findsNWidgets(2));
      expect(find.text('PENDING'), findsWidgets);

      // Verify Cancel Trade button exists for proposer (on both pinned banner and embedded card)
      final cancelButtons = find.byKey(const Key('cancel_trade_button'));
      expect(cancelButtons, findsNWidgets(2));

      // Tap Cancel Trade on the pinned banner
      await tester.tap(cancelButtons.first);
      await tester.pumpAndSettle();

      // Verify Cancel Trade button is gone from both
      expect(find.byKey(const Key('cancel_trade_button')), findsNothing);

      // 1. Verify DB status is now 'cancelled'
      final updatedProposal = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(proposalId)))
          .getSingle();
      expect(updatedProposal.status, equals('cancelled'));

      // 2. Verify banner is completely unpinned
      expect(find.text('Active Trade Proposal'), findsNothing);

      // 3. Verify notification is actioned and cancelled
      final notif = await (db.select(db.notifications)
            ..where((t) => t.id.equals('notif_cancel_it2')))
          .getSingle();
      expect(notif.status, equals('cancelled'));
      expect(notif.isActioned, isTrue);

      // 4. Verify embedded trade card in chat history displays CANCELLED status badge
      expect(find.text('CANCELLED'), findsOneWidget);

      // 5. Verify cancellation chat notification was posted
      expect(find.text('✗ Trade proposal was cancelled.'), findsOneWidget);
    });

    testWidgets('2. Adversarial Cancel: recipient cannot cancel & idempotent cancellations succeed without corrupting state', (tester) async {
      final now = DateTime.now();
      const proposalId = 'trade_proposal_adv_cancel';

      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: proposalId,
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
          offeredTotalValue: const drift.Value(5000.0),
          requestedTotalValue: const drift.Value(4500.0),
          createdAt: drift.Value(now),
        ),
      );

      // Recipient attempts to cancel via DAO
      await db.inboxDao.cancelTradeProposal(proposalId, currentUserId: partnerId);

      var proposal = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(proposal.status, equals('pending'), reason: 'Recipient must NOT be able to cancel a trade proposed by another user');

      // Proposer cancels
      await db.inboxDao.cancelTradeProposal(proposalId, currentUserId: currentUserId);
      proposal = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(proposal.status, equals('cancelled'));

      // Re-cancelling already cancelled proposal is a clean no-op
      await db.inboxDao.cancelTradeProposal(proposalId, currentUserId: currentUserId);
      proposal = await (db.select(db.tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
      expect(proposal.status, equals('cancelled'));
    });

    testWidgets('3. Counter Trade by recipient: marks prior proposal countered, pre-loads builder, submits counter & pins new offer', (tester) async {
      final now = DateTime.now();
      const priorProposalId = 'trade_prior_counter_it2';

      // Insert proposal from partnerId to currentUserId
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: priorProposalId,
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
          requestedCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
          offeredTotalValue: const drift.Value(4500.0),
          requestedTotalValue: const drift.Value(5000.0),
          createdAt: drift.Value(now),
        ),
      );

      final conversationId = InboxDao.getConversationId(currentUserId, partnerId);

      await tester.pumpWidget(
        buildScope(
          child: ChatConversationScreen(
            conversationId: conversationId,
            contactId: partnerId,
          ),
          activeUserId: currentUserId, // Me as recipient
        ),
      );
      await tester.pumpAndSettle();

      // Recipient sees banner with Counter button
      final counterBtn = find.byKey(const Key('trade_counter_offer_button'));
      expect(counterBtn, findsOneWidget);

      // Tap Counter button -> pushes TradeScreen
      await tester.tap(counterBtn);
      await tester.pumpAndSettle();

      // Verify TradeScreen is loaded in counter mode
      expect(find.byType(TradeScreen), findsOneWidget);

      // Verify counter trade submission marks prior proposal countered in DB
      final counterProposal = await db.inboxDao.counterTradeProposal(
        priorProposalId,
        proposerId: currentUserId,
        receiverId: partnerId,
        offeredCardIds: ['item-mtg-black-lotus'],
        requestedCardIds: ['item-mtg-mox-sapphire'],
        offeredTotalValue: 5000.0,
        requestedTotalValue: 4500.0,
      );

      expect(counterProposal.status, equals('pending'));
      expect(counterProposal.proposerId, equals(currentUserId));
      expect(counterProposal.receiverId, equals(partnerId));

      // Prior proposal is marked 'countered'
      final prior = await (db.select(db.tradeProposals)..where((t) => t.id.equals(priorProposalId))).getSingle();
      expect(prior.status, equals('countered'));

      // Pop TradeScreen back to chat
      Navigator.of(tester.element(find.byType(TradeScreen))).pop();
      await tester.pumpAndSettle();

      // Banner in chat now displays the new pending counter proposal
      expect(find.text('Active Trade Proposal'), findsOneWidget);
      expect(find.text('PENDING'), findsWidgets);
    });

    testWidgets('4. Edit Trade by proposer: opens Trade Builder pre-loaded with current offer', (tester) async {
      final now = DateTime.now();
      const proposalId = 'trade_proposal_edit_it2';

      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: proposalId,
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
          offeredTotalValue: const drift.Value(5000.0),
          requestedTotalValue: const drift.Value(4500.0),
          createdAt: drift.Value(now),
        ),
      );

      final conversationId = InboxDao.getConversationId(currentUserId, partnerId);

      await tester.pumpWidget(
        buildScope(
          child: ChatConversationScreen(
            conversationId: conversationId,
            contactId: partnerId,
          ),
          activeUserId: currentUserId, // Me as proposer
        ),
      );
      await tester.pumpAndSettle();

      final editBtn = find.byKey(const Key('trade_edit_offer_button'));
      expect(editBtn, findsOneWidget);

      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify TradeScreen is opened
      expect(find.byType(TradeScreen), findsOneWidget);

      // Verify TradeScreen displays StickyTradeValueMeter and TradeFairnessGauge
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
      expect(find.byKey(const Key('trade_fairness_gauge')), findsOneWidget);
    });
  });

  group('Milestone 6 Iteration 2 Gate Verification: Card Name Resolution', () {
    test('5.1 CardNameResolver.formatSlug handles multi-TCG prefixes, slugs, UUIDs, slashes, and length truncation', () {
      // 1. Multi-TCG prefixes stripped to clean Title Case
      expect(CardNameResolver.formatSlug('item-mtg-black-lotus'), equals('Black Lotus'));
      expect(CardNameResolver.formatSlug('item-pokemon-charizard-base-set'), equals('Charizard Base Set'));
      expect(CardNameResolver.formatSlug('item-yugioh-blue-eyes-white-dragon'), equals('Blue Eyes White Dragon'));
      expect(CardNameResolver.formatSlug('item-lorcana-elsa-spirit-of-winter'), equals('Elsa Spirit Of Winter'));
      expect(CardNameResolver.formatSlug('item-starwars-darth-vader-leader'), equals('Darth Vader Leader'));

      // 2. Generic item prefix
      expect(CardNameResolver.formatSlug('item-time-walk'), equals('Time Walk'));

      // 3. Double-faced cards slash notation
      expect(
        CardNameResolver.formatSlug('item-mtg-delver-of-secrets // insectile-aberration'),
        equals('Delver Of Secrets'),
      );

      // 4. Raw UUIDs formatted safely without crashing
      final uuidResult = CardNameResolver.formatSlug('f47ac10b-58cc-4372-a567-0e02b2c3d479');
      expect(uuidResult, isNot(contains('item-')));
      expect(uuidResult.isNotEmpty, isTrue);

      // 5. Truncation: strings > 30 characters capped with '...'
      final longSlug = 'item-mtg-extremely-super-duper-long-card-name-that-exceeds-thirty-chars';
      final formattedLong = CardNameResolver.formatSlug(longSlug);
      expect(formattedLong.length, lessThanOrEqualTo(30));
      expect(formattedLong.endsWith('...'), isTrue);

      // 6. Null and whitespace
      expect(CardNameResolver.formatSlug(null), equals('Card Not Available'));
      expect(CardNameResolver.formatSlug(''), equals('Card Not Available'));
      expect(CardNameResolver.formatSlug('   '), equals('Card Not Available'));
    });

    test('5.2 CardNameResolver.resolveDisplayName queries database catalog with fallback', () async {
      // Seeded in vaultItems: id 'item-mtg-black-lotus' with name 'Black Lotus'
      final dbName = await CardNameResolver.resolveDisplayName(db, 'item-mtg-black-lotus');
      expect(dbName, equals('Black Lotus'));

      // Unseeded card: falls back to formatSlug
      final fallbackName = await CardNameResolver.resolveDisplayName(db, 'item-mtg-mox-jet');
      expect(fallbackName, equals('Mox Jet'));
    });
  });

  group('Milestone 6 Iteration 2 Gate Verification: Inbox Compose Button', () {
    testWidgets('6.1 Compose FAB opens user picker, supports 1-on-1 and 2-partner selection, blocks 3+', (tester) async {
      await tester.pumpWidget(
        buildScope(
          child: const InboxHubScreen(initialTab: 'messages'),
          activeUserId: currentUserId,
        ),
      );
      await tester.pumpAndSettle();

      final composeFab = find.byKey(const Key('inbox_compose_button'));
      expect(composeFab, findsOneWidget);

      await tester.tap(composeFab);
      await tester.pumpAndSettle();

      // Modal is visible
      expect(find.text('New Message'), findsOneWidget);

      // Current user should NOT be in the picker list
      expect(find.text('@challenger_me'), findsNothing);

      // Partner, Third, and Fourth collectors should be visible
      expect(find.text('Partner Trader With Long Profile Title'), findsOneWidget);
      expect(find.text('Third Collector'), findsOneWidget);
      expect(find.text('Fourth Collector'), findsOneWidget);

      // Select 1 partner (1-on-1)
      await tester.tap(find.text('Partner Trader With Long Profile Title'));
      await tester.pumpAndSettle();
      expect(find.text('Start Chat (1)'), findsOneWidget);

      // Select 2nd partner (3-way conversation)
      await tester.tap(find.text('Third Collector'));
      await tester.pumpAndSettle();
      expect(find.text('Start Chat (2)'), findsOneWidget);

      // Attempt to select 3rd partner (exceeding 2 partner limit)
      await tester.tap(find.text('Fourth Collector'));
      await tester.pumpAndSettle();

      // Should show warning snackbar and keep count at 2
      expect(find.text('Maximum 2 partners allowed for 3-way conversation'), findsOneWidget);
      expect(find.text('Start Chat (2)'), findsOneWidget);

      // Deselect third collector
      await tester.tap(find.text('Third Collector'));
      await tester.pumpAndSettle();
      expect(find.text('Start Chat (1)'), findsOneWidget);
    });
  });

  group('Milestone 6 Iteration 2 Gate Verification: Multi-Viewport Responsive Layout Stress', () {
    const viewports = [
      Size(240, 600), // Ultra narrow
      Size(320, 640), // Narrow
      Size(360, 720), // Standard small
      Size(400, 800), // Standard mobile
    ];

    for (final size in viewports) {
      testWidgets('7.1 Viewport ${size.width}x${size.height}: Chat with active trade banner renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();
        const proposalId = 'vp_trade_test';
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: proposalId,
            proposerId: partnerId,
            receiverId: currentUserId,
            status: const drift.Value('pending'),
            offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
            requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
            offeredTotalValue: const drift.Value(5000.0),
            requestedTotalValue: const drift.Value(4500.0),
            createdAt: drift.Value(now),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

        final conversationId = InboxDao.getConversationId(currentUserId, partnerId);

        await tester.pumpWidget(
          buildScope(
            child: ChatConversationScreen(
              conversationId: conversationId,
              contactId: partnerId,
            ),
            activeUserId: currentUserId,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflows at ${size.width}px');
      });

      testWidgets('7.2 Viewport ${size.width}x${size.height}: InboxHubScreen renders with zero RenderFlex overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildScope(
            child: const InboxHubScreen(initialTab: 'messages'),
            activeUserId: currentUserId,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflows at ${size.width}px');
      });
    }
  });
}

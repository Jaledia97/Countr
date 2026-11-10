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
import 'package:countr/features/trades/presentation/widgets/embedded_trade_offer_card.dart';
import 'package:countr/features/trades/utils/card_name_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const currentUserId = 'user_me';
  const partnerId = 'user_partner';
  const thirdPartnerId = 'user_third';
  const fourthPartnerId = 'user_fourth';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    final now = DateTime.now();
    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: currentUserId,
        username: '@collector_me',
        displayName: 'Collector Me',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(0),
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
        username: '@spicy_partner',
        displayName: 'Spicy Partner',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(0),
        repCount: const drift.Value(12),
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
        username: '@third_trader',
        displayName: 'Third Trader',
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

    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: fourthPartnerId,
        username: '@fourth_trader',
        displayName: 'Fourth Trader',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(0),
        repCount: const drift.Value(3),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestScope({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  // =========================================================================
  // SECTION 1: FEATURE 28 ADVERSARIAL STRESS (Inbox Compose & User Picker)
  // =========================================================================
  group('Feature 28 Adversarial Stress: Inbox Compose & User Picker', () {
    testWidgets('1.1: Rapid burst-tapping on compose FAB triggers user picker modal strictly once', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      final fabFinder = find.byKey(const Key('inbox_compose_button'));
      expect(fabFinder, findsOneWidget);

      // Rapidly fire multiple taps in quick succession
      await tester.tap(fabFinder);
      await tester.tap(fabFinder, warnIfMissed: false);
      await tester.tap(fabFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Modal must be presented strictly once
      expect(find.byKey(const Key('inbox_user_picker_modal')), findsOneWidget);
      expect(find.byKey(const Key('inbox_user_picker')), findsOneWidget);
    });

    testWidgets('1.2: Partner selection limits: attempting to select 3rd partner triggers warning SnackBar and preserves 2 selections', (tester) async {
      final now = DateTime.now();
      for (final uid in [partnerId, thirdPartnerId, fourthPartnerId]) {
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'fr_$uid',
            userId: currentUserId,
            friendId: uid,
            status: const drift.Value('accepted'),
            createdAt: drift.Value(now),
          ),
        );
      }

      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      // Select partner 1
      await tester.tap(find.text('Spicy Partner'));
      await tester.pumpAndSettle();
      expect(find.text('Start Chat (1)'), findsOneWidget);

      // Select partner 2
      await tester.tap(find.text('Third Trader'));
      await tester.pumpAndSettle();
      expect(find.text('Start Chat (2)'), findsOneWidget);

      // Attempt to select partner 3
      await tester.tap(find.text('Fourth Trader'));
      await tester.pumpAndSettle();

      // Verify warning snackbar is shown
      expect(find.text('Maximum 2 partners allowed for 3-way conversation'), findsOneWidget);

      // Selection must remain capped at 2
      expect(find.text('Start Chat (2)'), findsOneWidget);
      expect(find.text('2/2 partners selected'), findsOneWidget);
    });

    testWidgets('1.3: Self-exclusion: current user is strictly excluded from friend picker list', (tester) async {
      final now = DateTime.now();
      // Even if self is inserted into friendships (abnormal condition)
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_self',
          userId: currentUserId,
          friendId: currentUserId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_partner',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      expect(find.text('Collector Me'), findsNothing);
      expect(find.text('@collector_me'), findsNothing);
      expect(find.text('Spicy Partner'), findsOneWidget);
    });

    testWidgets('1.4: 0 friends empty state: displays "Invite friends to start a chat"', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      expect(find.text('Invite friends to start a chat'), findsOneWidget);
      expect(find.text('Start Chat'), findsOneWidget);

      // Start button is disabled when 0 friends selected
      final startBtn = tester.widget<ElevatedButton>(find.byKey(const Key('inbox_user_picker_start_button')));
      expect(startBtn.onPressed, isNull);
    });

    testWidgets('1.5: Deselecting partners updates counter and disables start button when empty', (tester) async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_p1',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      // Select
      await tester.tap(find.text('Spicy Partner'));
      await tester.pumpAndSettle();
      expect(find.text('Start Chat (1)'), findsOneWidget);

      // Deselect
      await tester.tap(find.text('Spicy Partner'));
      await tester.pumpAndSettle();
      expect(find.text('Start Chat'), findsOneWidget);

      final startBtn = tester.widget<ElevatedButton>(find.byKey(const Key('inbox_user_picker_start_button')));
      expect(startBtn.onPressed, isNull);
    });

    testWidgets('1.6: User picker search filters live with 250ms debouncing and strips "@" prefix', (tester) async {
      final now = DateTime.now();
      for (final uid in [partnerId, thirdPartnerId]) {
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'fr_search_$uid',
            userId: currentUserId,
            friendId: uid,
            status: const drift.Value('accepted'),
            createdAt: drift.Value(now),
          ),
        );
      }

      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      expect(find.text('Spicy Partner'), findsOneWidget);
      expect(find.text('Third Trader'), findsOneWidget);

      // Search with '@spicy'
      await tester.enterText(find.byKey(const Key('inbox_user_picker_search_input')), '@spicy');
      // Before debounce settles (100ms), both may still be visible
      await tester.pump(const Duration(milliseconds: 100));
      // After debounce settles (300ms total)
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Spicy Partner'), findsOneWidget);
      expect(find.text('Third Trader'), findsNothing);

      // Search with non-matching term
      await tester.enterText(find.byKey(const Key('inbox_user_picker_search_input')), 'nonexistent_user');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('No matching friends found'), findsOneWidget);
    });
  });

  // =========================================================================
  // SECTION 2: FEATURE 29 ADVERSARIAL STRESS (Banner Unpinning & Card Names)
  // =========================================================================
  group('Feature 29 Adversarial Stress: Banner Unpinning & Card Names', () {
    testWidgets('2.1: Banner unpins immediately when proposal status changes from pending to declined, cancelled, countered, or accepted', (tester) async {
      final now = DateTime.now();
      const proposalId = 'prop_lifecycle_test';

      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: proposalId,
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-black-lotus']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mox-pearl']),
          offeredTotalValue: const drift.Value(100.0),
          requestedTotalValue: const drift.Value(100.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      // Banner is visible when pending
      expect(find.text('Active Trade Proposal'), findsOneWidget);

      // Transition to 'declined'
      await (db.update(db.tradeProposals)..where((t) => t.id.equals(proposalId)))
          .write(const TradeProposalsCompanion(status: drift.Value('declined')));
      await tester.pumpAndSettle();
      expect(find.text('Active Trade Proposal'), findsNothing);

      // Reset to pending
      await (db.update(db.tradeProposals)..where((t) => t.id.equals(proposalId)))
          .write(const TradeProposalsCompanion(status: drift.Value('pending')));
      await tester.pumpAndSettle();
      expect(find.text('Active Trade Proposal'), findsOneWidget);

      // Transition to 'cancelled'
      await (db.update(db.tradeProposals)..where((t) => t.id.equals(proposalId)))
          .write(const TradeProposalsCompanion(status: drift.Value('cancelled')));
      await tester.pumpAndSettle();
      expect(find.text('Active Trade Proposal'), findsNothing);

      // Reset to pending
      await (db.update(db.tradeProposals)..where((t) => t.id.equals(proposalId)))
          .write(const TradeProposalsCompanion(status: drift.Value('pending')));
      await tester.pumpAndSettle();
      expect(find.text('Active Trade Proposal'), findsOneWidget);

      // Transition to 'countered'
      await (db.update(db.tradeProposals)..where((t) => t.id.equals(proposalId)))
          .write(const TradeProposalsCompanion(status: drift.Value('countered')));
      await tester.pumpAndSettle();
      expect(find.text('Active Trade Proposal'), findsNothing);

      // Reset to pending
      await (db.update(db.tradeProposals)..where((t) => t.id.equals(proposalId)))
          .write(const TradeProposalsCompanion(status: drift.Value('pending')));
      await tester.pumpAndSettle();
      expect(find.text('Active Trade Proposal'), findsOneWidget);

      // Transition to 'accepted'
      await (db.update(db.tradeProposals)..where((t) => t.id.equals(proposalId)))
          .write(const TradeProposalsCompanion(status: drift.Value('accepted')));
      await tester.pumpAndSettle();
      expect(find.text('Active Trade Proposal'), findsNothing);
    });

    test('2.2: Extreme inputs against CardNameResolver.formatSlug', () {
      // 1. 60+ character string: verify truncation to <= 30 chars with '...'
      const ultraLongName = 'item-mtg-extremely-hyper-convoluted-card-name-with-over-sixty-characters-for-testing';
      final formattedLong = CardNameResolver.formatSlug(ultraLongName);
      expect(formattedLong.length, lessThanOrEqualTo(30));
      expect(formattedLong.endsWith('...'), isTrue);

      // 2. Double-faced cards: verify front face resolution
      expect(
        CardNameResolver.formatSlug('Bala Ged Recovery // Bala Ged Sanctuary'),
        equals('Bala Ged Recovery'),
      );
      expect(
        CardNameResolver.formatSlug('Delver of Secrets // Insectile Aberration'),
        equals('Delver Of Secrets'),
      );

      // 3. Multi-TCG prefixes stripped to Title Case
      expect(CardNameResolver.formatSlug('item-mtg-black-lotus'), equals('Black Lotus'));
      expect(CardNameResolver.formatSlug('item-pokemon-charizard'), equals('Charizard'));
      expect(CardNameResolver.formatSlug('item-lorcana-elsa'), equals('Elsa'));
      expect(CardNameResolver.formatSlug('item-yugioh-blue-eyes-white-dragon'), equals('Blue Eyes White Dragon'));
      expect(CardNameResolver.formatSlug('item-starwars-darth-vader'), equals('Darth Vader'));

      // 4. Null / empty / whitespace fallback to 'Card Not Available'
      expect(CardNameResolver.formatSlug(null), equals('Card Not Available'));
      expect(CardNameResolver.formatSlug(''), equals('Card Not Available'));
      expect(CardNameResolver.formatSlug('   '), equals('Card Not Available'));
      expect(CardNameResolver.formatSlug('item-mtg-'), equals('Card Not Available'));
      expect(CardNameResolver.formatSlug('item-'), equals('Card Not Available'));
    });

    testWidgets('2.3: Raw slugs like "item-mtg-underground-sea" must NEVER appear in chat banner or card', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_slug_test',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-underground-sea']),
          requestedCardIdsJson: jsonEncode(['item-pokemon-charizard-vmax']),
          offeredTotalValue: const drift.Value(500.0),
          requestedTotalValue: const drift.Value(500.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      // Raw slug must NEVER appear
      expect(find.textContaining('item-mtg-underground-sea'), findsNothing);
      expect(find.textContaining('item-pokemon-charizard-vmax'), findsNothing);

      // Plain English resolved name MUST appear
      expect(find.textContaining('Underground Sea'), findsOneWidget);
      expect(find.textContaining('Charizard Vmax'), findsOneWidget);
    });

    testWidgets('2.4: EmbeddedTradeOfferCard renders correct status badge for all statuses', (tester) async {
      final now = DateTime.now();
      final statuses = ['pending', 'accepted', 'declined', 'cancelled', 'countered'];

      for (final status in statuses) {
        final propId = 'prop_status_$status';
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: propId,
            proposerId: partnerId,
            receiverId: currentUserId,
            status: drift.Value(status),
            offeredCardIdsJson: jsonEncode(['item-mtg-sol-ring']),
            requestedCardIdsJson: jsonEncode(['item-mtg-mana-vault']),
            offeredTotalValue: const drift.Value(10.0),
            requestedTotalValue: const drift.Value(10.0),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(buildTestScope(
          child: Scaffold(
            body: EmbeddedTradeOfferCard(
              proposalId: propId,
              currentUserId: currentUserId,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('trade_card_status_badge')), findsOneWidget);
        expect(find.text(status.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('2.5: Multiple trade proposals in conversation: only latest active pending proposal pins', (tester) async {
      final now = DateTime.now();
      // Insert an older proposal that was declined
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_older_declined',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('declined'),
          offeredCardIdsJson: jsonEncode(['item-mtg-sol-ring']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mana-vault']),
          offeredTotalValue: const drift.Value(10.0),
          requestedTotalValue: const drift.Value(10.0),
          createdAt: drift.Value(now.subtract(const Duration(hours: 2))),
        ),
      );

      // Insert a newer proposal that is pending
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_newer_pending',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-mox-ruby']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mox-sapphire']),
          offeredTotalValue: const drift.Value(100.0),
          requestedTotalValue: const drift.Value(100.0),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 5))),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      // Only the newer pending proposal should pin
      expect(find.text('Active Trade Proposal'), findsOneWidget);
      expect(find.textContaining('Mox Ruby'), findsOneWidget);
      expect(find.textContaining('Sol Ring'), findsNothing);
    });
  });

  // =========================================================================
  // SECTION 3: FEATURE 30 ADVERSARIAL STRESS (Cancel, Edit, Counter Lifecycle)
  // =========================================================================
  group('Feature 30 Adversarial Stress: Cancel, Edit, Counter Lifecycle', () {
    testWidgets('3.1: Proposer taps [Cancel Trade]: SQLite status updates to "cancelled" and banner unpins', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_cancel_lifecycle',
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-mox-diamond']),
          requestedCardIdsJson: jsonEncode(['item-mtg-volcanic-island']),
          offeredTotalValue: const drift.Value(600.0),
          requestedTotalValue: const drift.Value(600.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active Trade Proposal'), findsOneWidget);
      final cancelBtn = find.byKey(const Key('cancel_trade_button'));
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // SQLite DB status updated to 'cancelled'
      final record = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals('prop_cancel_lifecycle')))
          .getSingle();
      expect(record.status, equals('cancelled'));

      // Banner immediately unpinned
      expect(find.text('Active Trade Proposal'), findsNothing);
    });

    testWidgets('3.2: Proposer taps [Edit Trade]: TradeScreen loads in edit mode pre-loaded with current offer and live StickyTradeValueMeter', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_edit_lifecycle',
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-mox-diamond']),
          requestedCardIdsJson: jsonEncode(['item-mtg-volcanic-island']),
          offeredTotalValue: const drift.Value(600.0),
          requestedTotalValue: const drift.Value(600.0),
          note: const drift.Value('Initial trade note'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      final editBtn = find.byKey(const Key('trade_edit_offer_button'));
      expect(editBtn, findsOneWidget);

      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify TradeScreen loaded in Edit Mode
      expect(find.text('Edit Trade Offer'), findsOneWidget);
      expect(find.text('Update Trade Offer'), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);

      await tester.scrollUntilVisible(find.byType(TextField), 200);
      await tester.pumpAndSettle();
      expect(find.text('Initial trade note'), findsOneWidget);
    });

    testWidgets('3.3: Recipient taps [Counter Trade]: TradeScreen loads in counter mode with reversed roles, staged cards, and live StickyTradeValueMeter', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_counter_lifecycle',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-force-of-will']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mana-drain']),
          offeredTotalValue: const drift.Value(75.0),
          requestedTotalValue: const drift.Value(75.0),
          note: const drift.Value('Counter this offer'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      final counterBtn = find.byKey(const Key('trade_counter_offer_button'));
      expect(counterBtn, findsOneWidget);

      await tester.tap(counterBtn);
      await tester.pumpAndSettle();

      // Verify TradeScreen loaded in Counter Mode
      expect(find.text('Counter Trade Offer'), findsOneWidget);
      expect(find.text('Send Counter Offer'), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);

      await tester.scrollUntilVisible(find.byType(TextField), 200);
      await tester.pumpAndSettle();
      expect(find.text('Counter this offer'), findsOneWidget);
    });

    testWidgets('3.4: Submitting counter-offer atomically marks prior proposal "countered" and creates new pending proposal pinned to top banner', (tester) async {
      final now = DateTime.now();
      const priorId = 'prop_atom_counter';
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: priorId,
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-card-a']),
          requestedCardIdsJson: jsonEncode(['item-mtg-card-b']),
          offeredTotalValue: const drift.Value(50.0),
          requestedTotalValue: const drift.Value(50.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap [Counter] button
      await tester.tap(find.byKey(const Key('trade_counter_offer_button')));
      await tester.pumpAndSettle();

      expect(find.text('Counter Trade Offer'), findsOneWidget);

      // Submit counter offer
      await tester.tap(find.text('Send Counter Offer'));
      await tester.pumpAndSettle();

      // Verify DB state
      final prior = await (db.select(db.tradeProposals)..where((t) => t.id.equals(priorId))).getSingle();
      expect(prior.status, equals('countered'));

      final allPending = await (db.select(db.tradeProposals)
            ..where((t) => t.status.equals('pending')))
          .get();
      expect(allPending.length, equals(1));
      final counterProposal = allPending.first;
      expect(counterProposal.proposerId, equals(currentUserId));
      expect(counterProposal.receiverId, equals(partnerId));
      expect(counterProposal.status, equals('pending'));

      // Top banner remains pinned with the new active pending proposal
      expect(find.text('Active Trade Proposal'), findsOneWidget);
      expect(find.text('Trade proposal cancelled.'), findsNothing);
    });

    testWidgets('3.5: Rapid double-tap on [Cancel Trade] is idempotent and completes cleanly without error', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_rapid_cancel',
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-mox-jet']),
          requestedCardIdsJson: jsonEncode(['item-mtg-ancestral-recall']),
          offeredTotalValue: const drift.Value(150.0),
          requestedTotalValue: const drift.Value(150.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      final cancelBtn = find.byKey(const Key('cancel_trade_button'));
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.tap(cancelBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      final record = await (db.select(db.tradeProposals)
            ..where((t) => t.id.equals('prop_rapid_cancel')))
          .getSingle();
      expect(record.status, equals('cancelled'));
      expect(find.text('Active Trade Proposal'), findsNothing);
    });
  });
}

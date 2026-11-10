import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/trades/domain/models/trade_card_source_filter.dart';
import 'package:countr/features/trades/presentation/widgets/trade_card_selection_sheet.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.now();

  final meUser = UserProfile(
    id: 'user-me',
    username: '@user_me',
    displayName: 'My User',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 0,
    repCount: 0,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'private',
  );

  final publicPartnerUser = UserProfile(
    id: 'user-public-partner',
    username: '@public_partner',
    displayName: 'Public Partner',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 0,
    repCount: 0,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'public',
  );

  final privatePartnerUser = UserProfile(
    id: 'user-private-partner',
    username: '@private_partner',
    displayName: 'Private Partner',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 0,
    repCount: 0,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'private',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Insert profiles
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
        id: publicPartnerUser.id,
        username: publicPartnerUser.username,
        displayName: publicPartnerUser.displayName,
        collectionVisibility: const Value('public'),
        createdAt: now,
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: privatePartnerUser.id,
        username: privatePartnerUser.username,
        displayName: privatePartnerUser.displayName,
        collectionVisibility: const Value('private'),
        createdAt: now,
      ),
    );

    // Create system trade block binder for public partner
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_${publicPartnerUser.id}',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: Value(publicPartnerUser.id),
        createdAt: now,
      ),
    );

    // Create system trade block binder for private partner
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: 'system_trade_block_${privatePartnerUser.id}',
        name: 'Trade Block',
        collectionType: 'mtg',
        isSystemBinder: const Value(true),
        systemBinderType: const Value('trade_block'),
        userId: Value(privatePartnerUser.id),
        createdAt: now,
      ),
    );

    // Seed cards for public partner
    // 1. Trade binder card
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'pub-card-binder',
        name: 'Public Binder Card',
        setOrSeries: 'M21',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 15.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        primaryBinderId: Value('system_trade_block_${publicPartnerUser.id}'),
        userId: Value(publicPartnerUser.id),
      ),
    );
    // 2. Collection-only card
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'pub-card-coll',
        name: 'Public Collection Card',
        setOrSeries: 'M21',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 20.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 25.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: Value(publicPartnerUser.id),
      ),
    );

    // Seed cards for private partner
    // 1. Trade binder card
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'priv-card-binder',
        name: 'Private Binder Card',
        setOrSeries: 'NEO',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 30.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 35.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        primaryBinderId: Value('system_trade_block_${privatePartnerUser.id}'),
        userId: Value(privatePartnerUser.id),
      ),
    );
    // 2. Collection-only card (should NEVER be visible to trading partner)
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'priv-card-coll',
        name: 'Private Collection Secret Card',
        setOrSeries: 'NEO',
        collectionType: 'mtg',
        imageUrl: '',
        acquiredPrice: 100.0,
        acquiredDate: now,
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 150.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: Value(privatePartnerUser.id),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest({
    required UserProfile user,
    required bool isProposer,
    required ValueChanged<VaultItem> onCardToggled,
    Set<String> currentlySelectedCardIds = const {},
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => meUser.id),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TradeCardSelectionSheet(
            user: user,
            isProposer: isProposer,
            currentlySelectedCardIds: currentlySelectedCardIds,
            onCardToggled: onCardToggled,
          ),
        ),
      ),
    );
  }

  group('TradeCardSelectionSheet 3-Way Segmented Filter & Privacy Enforcement Tests', () {
    testWidgets('Public partner displays 3-way segmented filter and filters cards accordingly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));
      VaultItem? toggledItem;

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: publicPartnerUser,
          isProposer: false,
          onCardToggled: (item) => toggledItem = item,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 3-way segmented button is visible and partner privacy banner is NOT visible
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);
      expect(find.byKey(const Key('partner_collection_private_banner')), findsNothing);

      // 2. Default is Trade Binder -> shows 'Public Binder Card', does not show 'Public Collection Card'
      expect(find.text('Public Binder Card'), findsOneWidget);
      expect(find.text('Public Collection Card'), findsNothing);

      // 3. Select 'Collection' -> shows 'Public Collection Card', does not show 'Public Binder Card'
      await tester.tap(find.byKey(const Key('trade_card_source_collection')));
      await tester.pumpAndSettle();

      expect(find.text('Public Collection Card'), findsOneWidget);
      expect(find.text('Public Binder Card'), findsNothing);

      // 4. Select 'Both' -> shows both cards
      await tester.tap(find.byKey(const Key('trade_card_source_both')));
      await tester.pumpAndSettle();

      expect(find.text('Public Binder Card'), findsOneWidget);
      expect(find.text('Public Collection Card'), findsOneWidget);

      // 5. Tapping a card triggers onCardToggled
      await tester.tap(find.text('Public Binder Card'));
      await tester.pumpAndSettle();
      expect(toggledItem, isNotNull);
      expect(toggledItem!.id, equals('pub-card-binder'));
    });

    testWidgets('Private partner displays lock banner, hides segmented filter, and restricts strictly to Trade Binder', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: privatePartnerUser,
          isProposer: false,
          onCardToggled: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify privacy banner is present and segmented button is hidden
      expect(find.byKey(const Key('partner_collection_private_banner')), findsOneWidget);
      expect(find.text("Partner's collection is Private (Trade Binder only)"), findsOneWidget);
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsNothing);

      // 2. Verify Trade Binder card is shown, but Collection card is completely hidden
      expect(find.text('Private Binder Card'), findsOneWidget);
      expect(find.text('Private Collection Secret Card'), findsNothing);
    });

    testWidgets('Self selection sheet always shows 3-way filter even if self collection is private', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: meUser,
          isProposer: true,
          onCardToggled: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // User's own collectionVisibility is private, but since it's the proposer viewing their own cards,
      // they must see the 3-way filter and NOT the partner locked banner
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);
      expect(find.byKey(const Key('partner_collection_private_banner')), findsNothing);
    });

    testWidgets('Proposer defaults to Both filter, immediately displaying both owned Vault cards and Trade Block cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));

      final now = DateTime.now();
      // Insert 1 trade binder card for meUser
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'me-card-binder',
          name: 'Proposer Binder Mox',
          setOrSeries: 'LEA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 500.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 650.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          primaryBinderId: Value('system_trade_block_${meUser.id}'),
          userId: Value(meUser.id),
        ),
      );

      // Insert 1 general vault collection card for meUser
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'me-card-coll',
          name: 'Proposer Vault Lotus',
          setOrSeries: 'LEA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1000.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'Near Mint',
          currentMarketPrice: 2000.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          userId: Value(meUser.id),
        ),
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: meUser,
          isProposer: true,
          onCardToggled: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Verify segmented button has 'Both' selected by default for proposer
      final segmentedFinder = find.byKey(const Key('trade_card_source_filter_segmented'));
      expect(segmentedFinder, findsOneWidget);
      final segmented = tester.widget<SegmentedButton<TradeCardSourceFilter>>(segmentedFinder);
      expect(segmented.selected, equals({TradeCardSourceFilter.both}));

      // Both cards are visible immediately
      expect(find.text('Proposer Binder Mox'), findsOneWidget);
      expect(find.text('Proposer Vault Lotus'), findsOneWidget);
    });
  });
}

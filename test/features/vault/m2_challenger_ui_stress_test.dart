// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 2 Empirical UI Stress Test: Half-Height System Binder Presentation & Resilience

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildVaultTestApp({
    required String userId,
    required bool isBusiness,
    double textScale = 1.0,
    Size viewport = const Size(390, 844),
  }) {
    final user = AuthUser(
      id: userId,
      displayName: 'Empirical Challenger',
      username: 'challenger_m2_2',
      provider: AuthProviderType.email,
      tier: isBusiness ? AccountTier.business : AccountTier.free,
      isGuest: false,
      isVerifiedBusiness: isBusiness,
      createdAt: DateTime.now(),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        currentUserIdProvider.overrideWith((ref) => userId),
        currentUserProvider.overrideWith(
          (ref) => CurrentUserNotifier(ref.watch(authRepositoryProvider))
            ..setUser(user),
        ),
        vaultViewModeProvider.overrideWith((ref) => VaultViewMode.binders),
        activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const VaultScreen(),
        ),
      ),
    );
  }

  group('Group 1: Dedicated Top Dock Geometry & Aspect Ratios', () {
    testWidgets('1.1 Top dock has childAspectRatio 2.2 and Custom Binders grid has 1.05',
        (tester) async {
      const userId = 'user_m2_geo_test';

      // Seed 2 system binders and 2 custom binders
      await dao.seedSystemBindersForUser(userId, isBusiness: false);
      await dao.createBinder(
        name: 'Legacy Staples',
        collectionType: 'mtg',
        userId: userId,
      );
      await dao.createBinder(
        name: 'Modern Horizons 3 Foils',
        collectionType: 'mtg',
        userId: userId,
      );

      await tester.pumpWidget(
        buildVaultTestApp(userId: userId, isBusiness: false),
      );
      await tester.pumpAndSettle();

      // 1. Pinned System Binders Header
      expect(
        find.byKey(const Key('vault_pinned_system_binders_header')),
        findsOneWidget,
      );
      expect(find.text('PROFILE BINDERS'), findsOneWidget);
      expect(find.text('Synced with Profile'), findsOneWidget);

      // 2. Pinned System Binders Grid: aspect ratio 2.2
      final pinnedGridFinder =
          find.byKey(const Key('vault_pinned_system_binders_grid'));
      expect(pinnedGridFinder, findsOneWidget);

      final pinnedGrid = tester.widget<SliverGrid>(pinnedGridFinder);
      final pinnedDelegate =
          pinnedGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(pinnedDelegate.crossAxisCount, equals(2));
      expect(pinnedDelegate.childAspectRatio, equals(2.2),
          reason: 'Pinned system binders must be childAspectRatio: 2.2 (half-height of 1.05)');

      // 3. Custom Binders Header ("MY BINDERS")
      expect(find.byKey(const Key('vault_custom_binders_header')), findsOneWidget);
      expect(find.text('MY BINDERS'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Badge with count 2

      // 4. Custom Binders Grid: aspect ratio 1.05
      final customGridFinder =
          find.byKey(const PageStorageKey<String>('vault_binders_sliver_grid'));
      expect(customGridFinder, findsOneWidget);

      final customGrid = tester.widget<SliverGrid>(customGridFinder);
      final customDelegate =
          customGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(customDelegate.crossAxisCount, equals(2));
      expect(customDelegate.childAspectRatio, equals(1.05),
          reason: 'Custom user binders must be childAspectRatio: 1.05');
    });
  });

  group('Group 2: Amber Trade & Cyan Looking For Branding & Accents', () {
    testWidgets('2.1 Verified Amber Trade Binder and Cyan Looking For binder visual styling',
        (tester) async {
      const userId = 'user_m2_styling_test';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      await tester.pumpWidget(
        buildVaultTestApp(userId: userId, isBusiness: false),
      );
      await tester.pumpAndSettle();

      // 1. Amber Trade Binder
      final tradeCardFinder =
          find.byKey(const Key('vault_pinned_trade_binder'));
      expect(tradeCardFinder, findsOneWidget);
      expect(find.text('TRADE'), findsOneWidget);
      expect(find.text('Trade Binder'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);

      // Verify border accent color is Amber
      final tradeInkWell = tester.widget<InkWell>(tradeCardFinder);
      final tradeContainer = tradeInkWell.child as Container;
      final tradeBoxDec = tradeContainer.decoration as BoxDecoration;
      final tradeBorder = tradeBoxDec.border as Border;
      expect(
        tradeBorder.top.color,
        equals(AppColors.accentAmber.withValues(alpha: 0.55)),
        reason: 'Trade Binder must feature Amber accent border',
      );

      // 2. Cyan Looking For Binder
      final lfCardFinder =
          find.byKey(const Key('vault_pinned_looking_for_binder'));
      expect(lfCardFinder, findsOneWidget);
      expect(find.text('LOOKING FOR'), findsOneWidget);
      expect(find.text('Looking For'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      // Verify border accent color is Cyan
      final lfInkWell = tester.widget<InkWell>(lfCardFinder);
      final lfContainer = lfInkWell.child as Container;
      final lfBoxDec = lfContainer.decoration as BoxDecoration;
      final lfBorder = lfBoxDec.border as Border;
      expect(
        lfBorder.top.color,
        equals(AppColors.accentCyan.withValues(alpha: 0.55)),
        reason: 'Looking For binder must feature Cyan accent border',
      );
    });

    testWidgets('2.2 Empty custom binders state renders placeholder under MY BINDERS',
        (tester) async {
      const userId = 'user_m2_empty_state_test';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      await tester.pumpWidget(
        buildVaultTestApp(userId: userId, isBusiness: false),
      );
      await tester.pumpAndSettle();

      // Pinned grid still shows both binders
      expect(find.byKey(const Key('vault_pinned_trade_binder')), findsOneWidget);
      expect(find.byKey(const Key('vault_pinned_looking_for_binder')), findsOneWidget);

      // Empty custom binders card is rendered
      expect(
        find.byKey(const Key('vault_custom_binders_empty_card')),
        findsOneWidget,
      );
      expect(find.text('No Custom Binders Yet'), findsOneWidget);
      expect(
        find.text('Create custom albums to organize your collection.'),
        findsOneWidget,
      );
      expect(find.text('Create Binder'), findsOneWidget);
    });
  });

  group('Group 3: Multi-Viewport Layout Resilience (5x5 Stress Matrix)', () {
    // 5 widths x 5 text scale factors = 25 distinct viewport configurations
    final widths = [300.0, 320.0, 360.0, 390.0, 430.0];
    final textScales = [1.0, 1.2, 1.5, 1.8, 2.0];

    testWidgets(
        '3.1 Zero RenderFlex overflows across 25 viewport/scale combinations with populated binders',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const userId = 'user_m2_stress_matrix';
      final systemBinders =
          await dao.seedSystemBindersForUser(userId, isBusiness: false);

      final tradeBinder = systemBinders.firstWhere((b) =>
          b.name == 'Trade Binder' ||
          b.systemBinderType == 'trade_block' ||
          b.systemBinderType == 'trade_binder');

      // Add a custom binder with an extremely long name and high card count to stress wrap/ellipsis
      final customBinder = await dao.createBinder(
        name: 'Commander 2026 Competitive Hyper-Optimized Super Extended Album Name',
        collectionType: 'mtg',
        userId: userId,
      );

      // Insert card into trade binder
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card_stress_1',
              collectionType: 'mtg',
              name: 'Black Lotus Alpha Edition',
              setOrSeries: 'LEA',
              imageUrl: '',
              acquiredPrice: 50000.0,
              acquiredDate: DateTime.now(),
              condition: 'Near Mint',
              currentMarketPrice: 65000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(tradeBinder.id),
              userId: const drift.Value(userId),
              quantity: const drift.Value(999),
            ),
          );

      // Insert card into custom binder
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card_stress_2',
              collectionType: 'mtg',
              name: 'Mox Sapphire Unlimited Edition',
              setOrSeries: '2ED',
              imageUrl: '',
              acquiredPrice: 8000.0,
              acquiredDate: DateTime.now(),
              condition: 'Near Mint',
              currentMarketPrice: 9500.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(customBinder.id),
              userId: const drift.Value(userId),
              quantity: const drift.Value(4),
            ),
          );

      for (final width in widths) {
        for (final scale in textScales) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildVaultTestApp(
              userId: userId,
              isBusiness: false,
              textScale: scale,
              viewport: Size(width, 844),
            ),
          );
          await tester.pumpAndSettle();

          // Check for RenderFlex overflows or unhandled exceptions
          final exception = tester.takeException();
          expect(
            exception,
            isNull,
            reason:
                'RenderFlex overflow or exception encountered at width ${width}px with textScale ${scale}x',
          );

          // Assert essential widgets remain visible and intact
          expect(
            find.byKey(const Key('vault_pinned_system_binders_header')),
            findsOneWidget,
            reason: 'Pinned header must be present at width ${width}px, scale ${scale}x',
          );
          expect(
            find.byKey(const Key('vault_pinned_trade_binder')),
            findsOneWidget,
            reason: 'Trade binder card must be present at width ${width}px, scale ${scale}x',
          );
          expect(
            find.byKey(const Key('vault_pinned_looking_for_binder')),
            findsOneWidget,
            reason: 'Looking For card must be present at width ${width}px, scale ${scale}x',
          );
          expect(
            find.byKey(const Key('vault_custom_binders_header')),
            findsOneWidget,
            reason: 'Custom binders header must be present at width ${width}px, scale ${scale}x',
          );
          expect(
            find.byKey(const PageStorageKey<String>('vault_binders_sliver_grid')),
            findsOneWidget,
            reason: 'Custom binders grid must be present at width ${width}px, scale ${scale}x',
          );
        }
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
        '3.2 Zero RenderFlex overflows across 25 combinations with empty custom binders state',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const userId = 'user_m2_stress_empty_matrix';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      for (final width in widths) {
        for (final scale in textScales) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildVaultTestApp(
              userId: userId,
              isBusiness: false,
              textScale: scale,
              viewport: Size(width, 844),
            ),
          );
          await tester.pumpAndSettle();

          final exception = tester.takeException();
          expect(
            exception,
            isNull,
            reason:
                'RenderFlex overflow encountered in empty state at width ${width}px with textScale ${scale}x',
          );

          expect(
            find.byKey(const Key('vault_custom_binders_empty_card')),
            findsOneWidget,
          );
        }
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Group 4: Tapping Interaction & BinderDetailScreen Navigation', () {
    testWidgets('4.1 Tapping Trade Binder opens BinderDetailScreen with PINNED SYSTEM badge and pops back',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      const userId = 'user_m2_tap_normal';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      await tester.pumpWidget(
        buildVaultTestApp(userId: userId, isBusiness: false),
      );
      await tester.pumpAndSettle();

      final tradeCardFinder =
          find.byKey(const Key('vault_pinned_trade_binder'));
      expect(tradeCardFinder, findsOneWidget);

      // Tap the Trade Binder card
      await tester.tap(tradeCardFinder);
      await tester.pumpAndSettle();

      // Verify BinderDetailScreen is pushed
      expect(find.byType(BinderDetailScreen), findsOneWidget);
      expect(find.text('PINNED SYSTEM'), findsOneWidget);
      expect(
        find.text('Permanent System Binder • Quota Exempt'),
        findsOneWidget,
      );

      // Verify back button pops back to VaultScreen
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(BinderDetailScreen), findsNothing);
      expect(find.byKey(const Key('vault_pinned_trade_binder')), findsOneWidget);
    });

    testWidgets('4.2 Tapping Looking For binder opens BinderDetailScreen with PINNED SYSTEM badge and pops back',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      const userId = 'user_m2_tap_lf';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      await tester.pumpWidget(
        buildVaultTestApp(userId: userId, isBusiness: false),
      );
      await tester.pumpAndSettle();

      final lfCardFinder =
          find.byKey(const Key('vault_pinned_looking_for_binder'));
      expect(lfCardFinder, findsOneWidget);

      // Tap Looking For binder card
      await tester.tap(lfCardFinder);
      await tester.pumpAndSettle();

      // Verify BinderDetailScreen is pushed
      expect(find.byType(BinderDetailScreen), findsOneWidget);
      expect(find.text('PINNED SYSTEM'), findsOneWidget);
      expect(find.text('Looking For'), findsOneWidget);

      // Verify back button pops back to VaultScreen
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(BinderDetailScreen), findsNothing);
      expect(find.byKey(const Key('vault_pinned_looking_for_binder')), findsOneWidget);
    });

    testWidgets('4.3 Tapping Custom Binder opens BinderDetailScreen without PINNED SYSTEM badge and pops back',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      const userId = 'user_m2_tap_custom';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);
      final customBinder = await dao.createBinder(
        name: 'Pauper Cube 2026',
        collectionType: 'mtg',
        userId: userId,
      );

      await tester.pumpWidget(
        buildVaultTestApp(userId: userId, isBusiness: false),
      );
      await tester.pumpAndSettle();

      final customCardFinder =
          find.byKey(Key('vault_binder_card_${customBinder.id}'));
      expect(customCardFinder, findsOneWidget);

      // Tap Custom Binder card
      await tester.tap(customCardFinder);
      await tester.pumpAndSettle();

      // Verify BinderDetailScreen is pushed
      expect(find.byType(BinderDetailScreen), findsOneWidget);
      expect(find.text('Pauper Cube 2026'), findsOneWidget);
      expect(find.text('MTG Physical Anchor'), findsOneWidget);
      // No PINNED SYSTEM badge on custom binders
      expect(find.text('PINNED SYSTEM'), findsNothing);

      // Verify back button pops back to VaultScreen
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(BinderDetailScreen), findsNothing);
      expect(find.byKey(Key('vault_binder_card_${customBinder.id}')), findsOneWidget);
    });

    testWidgets(
        '4.4 Adversarial Challenge: User with "trade" in userId (trader_bob) must retain exactly 1 Trade Binder and 1 Looking For binder',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      const userId = 'trader_bob_42';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      await tester.pumpWidget(
        buildVaultTestApp(userId: userId, isBusiness: false),
      );
      await tester.pumpAndSettle();

      // Assert strictly one Trade Binder and strictly one Looking For binder exist
      final tradeFinders = find.byKey(const Key('vault_pinned_trade_binder'));
      final lfFinders = find.byKey(const Key('vault_pinned_looking_for_binder'));

      expect(tradeFinders, findsOneWidget,
          reason: 'User with "trade" in userId must have exactly 1 Trade Binder');
      expect(lfFinders, findsOneWidget,
          reason: 'User with "trade" in userId must not have Looking For binder misclassified as Trade Binder');
    });
  });
}

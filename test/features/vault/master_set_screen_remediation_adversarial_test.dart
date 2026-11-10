// Copyright (c) 2026 Countr. All rights reserved.
// Reviewer & Adversarial Critic Verification Test Suite
// Verifies:
// 1. SingleChildScrollView(scrollDirection: Axis.horizontal) on filter chips prevents overflow
//    and retains chip tap/selection interactions and horizontal scroll gestures.
// 2. FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft) on completion count Row
//    scales text down cleanly under extreme text scales (1.5x, 2.0x) and huge numbers without overflow.
// 3. Grid interactivity and responsiveness under severe layout constraints (300px width).

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';

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

  Widget buildTestApp({
    required Widget home,
    double textScale = 1.0,
    Size viewport = const Size(390, 844),
  }) {
    final user = AuthUser(
      id: 'reviewer-tester',
      displayName: 'Reviewer Critic',
      username: 'reviewer_m3_r2',
      provider: AuthProviderType.email,
      tier: AccountTier.free,
      isGuest: false,
      isVerifiedBusiness: false,
      createdAt: DateTime.now(),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        currentUserIdProvider.overrideWith((ref) => 'reviewer-tester'),
        currentUserProvider.overrideWith(
          (ref) => CurrentUserNotifier(ref.watch(authRepositoryProvider))
            ..setUser(user),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: home,
        ),
      ),
    );
  }

  group('REMEDIATION VERIFICATION: MasterSetScreen Overflow & Interactivity', () {
    testWidgets(
      'V1: Filter chips in horizontal SingleChildScrollView retain tap selection and filter the grid on 320px viewport at 1.5x scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert 3 cards in set BLB (Bloomburrow)
        // 1 owned, 2 missing
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'blb-1',
            collectionType: 'mtg',
            name: 'Mabel, Heir to Cragflame',
            setOrSeries: 'Bloomburrow',
            imageUrl: '',
            acquiredPrice: 4.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 5.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'blb',
              'collector_number': '1',
            }),
          ),
        );
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'blb-2',
            collectionType: 'mtg',
            name: 'Bria, Riptide Rogue',
            setOrSeries: 'Bloomburrow',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0), // missing
            condition: 'NM',
            currentMarketPrice: 15.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'blb',
              'collector_number': '2',
            }),
          ),
        );
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'blb-3',
            collectionType: 'mtg',
            name: 'Ygra, Eater of All',
            setOrSeries: 'Bloomburrow',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0), // missing
            condition: 'NM',
            currentMarketPrice: 20.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'blb',
              'collector_number': '3',
            }),
          ),
        );

        const blbCollection = VaultSetCollection(
          setName: 'Bloomburrow',
          setCode: 'BLB',
          collectionType: 'Magic: The Gathering',
          totalCount: 3,
          ownedCount: 1,
          completionPercentage: 0.333,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const MasterSetScreen(
              collection: blbCollection,
              activeGame: 'Magic: The Gathering',
            ),
            textScale: 1.5,
            viewport: const Size(320, 640),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify zero RenderFlex overflows
        expect(tester.takeException(), isNull, reason: 'Must have zero RenderFlex overflows');

        // 2. Verify SingleChildScrollView exists and is horizontal
        final scrollFinder = find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        );
        expect(scrollFinder, findsOneWidget, reason: 'Filter chips must be in horizontal SingleChildScrollView');

        // 3. Verify all 3 cards are initially shown under "All (3)"
        expect(find.byKey(const Key('master_set_card_blb-1')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_blb-2')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_blb-3')), findsOneWidget);

        // 4. Tap "Owned (1)" chip - verify interaction works
        final ownedChip = find.text('Owned (1)');
        expect(ownedChip, findsOneWidget);
        await tester.tap(ownedChip);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_card_blb-1')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_blb-2')), findsNothing);
        expect(find.byKey(const Key('master_set_card_blb-3')), findsNothing);

        // 5. Scroll to and tap "Missing (2)" chip - verify interaction works via horizontal scroll
        final missingChip = find.text('Missing (2)');
        expect(missingChip, findsOneWidget);
        await tester.ensureVisible(missingChip);
        await tester.pumpAndSettle();
        await tester.tap(missingChip);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_card_blb-1')), findsNothing);
        expect(find.byKey(const Key('master_set_card_blb-2')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_blb-3')), findsOneWidget);

        // 6. Scroll back and reset to "All (3)" chip
        final allChip = find.text('All (3)');
        await tester.ensureVisible(allChip);
        await tester.pumpAndSettle();
        await tester.tap(allChip);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('master_set_card_blb-1')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_blb-2')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_blb-3')), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'V2: FittedBox on completion count Row scales text cleanly under extreme 2.0x font scale and large counts without overflow',
      (tester) async {
        // Ultra-narrow viewport (280px) and extreme 2.0x accessibility font scale
        tester.view.physicalSize = const Size(280, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert card with large collector numbers and counts
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'huge-count-card',
            collectionType: 'mtg',
            name: 'Vastwood Seer // Vastwood Seer',
            setOrSeries: 'Extremely Long Set Name With Massive Tracked Numbers',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(8500),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'huge',
              'collector_number': '12345',
            }),
          ),
        );

        const hugeCollection = VaultSetCollection(
          setName: 'Extremely Long Set Name With Massive Tracked Numbers',
          setCode: 'HUGE',
          collectionType: 'Magic: The Gathering',
          totalCount: 99999,
          ownedCount: 85000,
          completionPercentage: 0.85,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const MasterSetScreen(
              collection: hugeCollection,
              activeGame: 'Magic: The Gathering',
            ),
            textScale: 2.0, // Extreme 2.0x font scaling
            viewport: const Size(280, 600),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Zero RenderFlex overflow even under 2.0x text scale on 280px screen
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'FittedBox must prevent overflow even under 2.0x scale on 280px');

        // 2. Verify FittedBox widget properties
        final fittedBoxFinder = find.descendant(
          of: find.byType(MasterSetScreen),
          matching: find.byWidgetPredicate(
            (w) => w is FittedBox && w.fit == BoxFit.scaleDown && w.alignment == Alignment.centerLeft,
          ),
        );
        expect(fittedBoxFinder, findsOneWidget, reason: 'FittedBox must use BoxFit.scaleDown and Alignment.centerLeft');

        // 3. Verify text content is fully rendered inside FittedBox
        expect(find.text('cards owned'), findsOneWidget);
        expect(find.text('1 / 99999'), findsOneWidget); // 1 distinct owned / 99999 total in set
        expect(find.text('0.0% complete'), findsOneWidget);
      },
    );

    testWidgets(
      'V3: Horizontal drag scrolling over FilterChips does not throw or corrupt layout',
      (tester) async {
        tester.view.physicalSize = const Size(300, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const collection = VaultSetCollection(
          setName: 'Modern Horizons 3',
          setCode: 'MH3',
          collectionType: 'Magic: The Gathering',
          totalCount: 10,
          ownedCount: 5,
          completionPercentage: 0.5,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const MasterSetScreen(
              collection: collection,
              activeGame: 'Magic: The Gathering',
            ),
            textScale: 1.5,
            viewport: const Size(300, 600),
          ),
        );
        await tester.pumpAndSettle();

        final scrollFinder = find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        );
        expect(scrollFinder, findsOneWidget);

        // Perform horizontal drag to test scroll physics
        await tester.drag(scrollFinder, const Offset(-150, 0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}

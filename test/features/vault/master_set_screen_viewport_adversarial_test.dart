// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Viewport Resilience & Interaction Stress Test for MasterSetScreen
// Testing across viewports: 320px, 360px, 390px, 430px
// Testing across text scales: 1.0x, 1.25x, 1.5x, 1.75x, 2.0x

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

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

  const testCollection = VaultSetCollection(
    setName: 'The Lord of the Rings: Tales of Middle-earth Special Collector Edition',
    setCode: 'LTR',
    collectionType: 'Magic: The Gathering',
    totalCount: 3,
    ownedCount: 2,
    completionPercentage: 0.667,
  );

  Future<void> seedStressCards() async {
    // Card 1: Owned x1, short name
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'card-ltr-1',
        collectionType: 'mtg',
        name: 'Frodo, Sauron\'s Bane',
        setOrSeries: 'The Lord of the Rings: Tales of Middle-earth Special Collector Edition',
        imageUrl: '',
        acquiredPrice: 2.50,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 3.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'set': 'ltr',
          'set_code': 'ltr',
          'collector_number': '1',
          'rarity': 'rare',
        }),
      ),
    );

    // Card 2: Unowned, long name with special characters
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'card-ltr-2',
        collectionType: 'mtg',
        name: 'Extremely Long Character Name For Stress Testing Overflow Boundaries & Wrapping',
        setOrSeries: 'The Lord of the Rings: Tales of Middle-earth Special Collector Edition',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 4.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'set': 'ltr',
          'set_code': 'ltr',
          'collector_number': '999',
          'rarity': 'mythic',
        }),
      ),
    );

    // Card 3: Owned x15 (multi-digit quantity), high value
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'card-ltr-3',
        collectionType: 'mtg',
        name: 'Aragorn, the Uniter',
        setOrSeries: 'The Lord of the Rings: Tales of Middle-earth Special Collector Edition',
        imageUrl: '',
        acquiredPrice: 8.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(15),
        condition: 'NM',
        currentMarketPrice: 12.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'set': 'ltr',
          'set_code': 'ltr',
          'collector_number': '300',
          'rarity': 'mythic',
        }),
      ),
    );
  }

  Widget buildApp({
    required Size viewport,
    required double textScale,
  }) {
    final user = AuthUser(
      id: 'test-user',
      displayName: 'Adversarial Reviewer',
      username: 'reviewer_m3_r2_2',
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
        currentUserIdProvider.overrideWith((ref) => 'test-user'),
        currentUserProvider.overrideWith(
          (ref) => CurrentUserNotifier(ref.watch(authRepositoryProvider))
            ..setUser(user),
        ),
        activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => const MasterSetScreen(
                collection: testCollection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        ),
      ),
    );
  }

  final testViewports = <String, Size>{
    '320px (iPhone SE / compact)': const Size(320, 568),
    '360px (standard compact Android)': const Size(360, 780),
    '390px (iPhone 14 / standard iOS)': const Size(390, 844),
    '430px (iPhone 15 Pro Max / large)': const Size(430, 932),
  };

  final testScales = <double>[1.0, 1.25, 1.5, 1.75, 2.0];

  for (final vpEntry in testViewports.entries) {
    final vpName = vpEntry.key;
    final vpSize = vpEntry.value;

    group('Viewport: $vpName', () {
      for (final scale in testScales) {
        testWidgets(
          'No RenderFlex overflow and full interaction at ${scale}x text scale',
          (tester) async {
            tester.view.physicalSize = Size(vpSize.width, vpSize.height);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await seedStressCards();

            await tester.pumpWidget(
              buildApp(viewport: vpSize, textScale: scale),
            );
            await tester.pumpAndSettle();

            // 1. Assert zero RenderFlex overflows
            final exception = tester.takeException();
            expect(
              exception,
              isNull,
              reason: 'Overflow occurred on $vpName at ${scale}x text scale: $exception',
            );

            // 2. Verify header components render
            expect(find.byKey(const Key('master_set_screen')), findsOneWidget);
            expect(find.byKey(const Key('master_set_back_button')), findsOneWidget);
            expect(find.text('Set: LTR'), findsOneWidget);

            // 3. Verify 3x3 grid cards rendered
            expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsOneWidget);
            expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsOneWidget);
            expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsOneWidget);

            // 4. Test Filter Chips interaction (horizontal scroll & tap)
            final missingChip = find.text('Missing (1)');
            expect(missingChip, findsOneWidget);
            await tester.ensureVisible(missingChip);
            await tester.tap(missingChip);
            await tester.pumpAndSettle();

            // Missing filter: only card 2 visible
            expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsOneWidget);
            expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsNothing);
            expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsNothing);

            // Tap "Owned" chip
            final ownedChip = find.text('Owned (2)');
            await tester.ensureVisible(ownedChip);
            await tester.tap(ownedChip);
            await tester.pumpAndSettle();

            // Owned filter: cards 1 & 3 visible
            expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsOneWidget);
            expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsOneWidget);
            expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsNothing);

            // Tap "All" chip to reset
            final allChip = find.text('All (3)');
            await tester.ensureVisible(allChip);
            await tester.tap(allChip);
            await tester.pumpAndSettle();

            // 5. Test Search input interaction
            final searchField = find.byKey(const Key('master_set_search_field'));
            expect(searchField, findsOneWidget);
            await tester.enterText(searchField, 'Frodo');
            await tester.pumpAndSettle();

            expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsOneWidget);
            expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsNothing);
            expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsNothing);

            // Clear search
            final clearBtn = find.byIcon(Icons.close);
            if (clearBtn.evaluate().isNotEmpty) {
              await tester.tap(clearBtn);
              await tester.pumpAndSettle();
            } else {
              await tester.enterText(searchField, '');
              await tester.pumpAndSettle();
            }

            // 6. Test Card tap opens CardDetailSheet
            final card1 = find.byKey(const Key('master_set_card_card-ltr-1'));
            await tester.ensureVisible(card1);
            await tester.tap(card1);
            await tester.pumpAndSettle();

            expect(find.byType(CardDetailSheet), findsOneWidget);

            // Close sheet
            final closeBtn = find.byKey(const Key('card_detail_close_button'));
            await tester.tap(closeBtn);
            await tester.pumpAndSettle();

            expect(find.byType(CardDetailSheet), findsNothing);

            // 7. Test AppBar Back Button tap
            final backBtn = find.byKey(const Key('master_set_back_button'));
            await tester.tap(backBtn);
            await tester.pumpAndSettle();

            // No exception after all operations
            expect(tester.takeException(), isNull);
          },
        );
      }
    });
  }
}

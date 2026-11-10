// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Challenger M3-2 Test Suite: System Binders Immutability, UI Resilience, and Business/OTP Verification

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/presentation/screens/business_registration_modal.dart';
import 'package:countr/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:countr/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
  });

  tearDown(() async {
    await db.close();
  });

  // Helper to insert a test card into SQLite anchored to a specific binder
  Future<void> insertTestCard({
    required String cardId,
    required String binderId,
    required String userId,
    String name = 'Mox Diamond',
  }) async {
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: cardId,
            collectionType: 'mtg',
            name: name,
            setOrSeries: 'STH',
            imageUrl: 'https://example.com/card_$cardId.jpg',
            acquiredPrice: 650.0,
            acquiredDate: DateTime.now(),
            condition: 'Near Mint',
            currentMarketPrice: 700.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: drift.Value(binderId),
            userId: drift.Value(userId),
          ),
        );
  }

  // =========================================================================
  // 1. System Binder Deletion Immutability
  // =========================================================================
  group('Challenger M3-2: 1. System Binder Deletion Immutability', () {
    test('1.1 Deleting "looking_for" system binder throws UnsupportedError and preserves card contents', () async {
      const userId = 'user_challenger_test_1';
      final binders = await db.vaultDao.seedSystemBindersForUser(userId, isBusiness: false);
      final lookingForBinder = binders.firstWhere((b) => b.systemBinderType == 'looking_for');

      const cardId = 'card_lf_001';
      await insertTestCard(cardId: cardId, binderId: lookingForBinder.id, userId: userId, name: 'Gaea\'s Cradle');

      // Assert card is in the binder before deletion attempt
      final initialItems = await (db.select(db.vaultItems)..where((t) => t.primaryBinderId.equals(lookingForBinder.id))).get();
      expect(initialItems.length, equals(1));
      expect(initialItems.first.id, equals(cardId));

      // Adversarially attempt to delete looking_for system binder
      expect(
        () async => await db.vaultDao.deleteBinder(lookingForBinder.id),
        throwsA(isA<UnsupportedError>()),
      );

      // Verify binder record is intact and NOT marked deleted
      final retrievedBinder = await db.vaultDao.getBinderById(lookingForBinder.id);
      expect(retrievedBinder, isNotNull);
      expect(retrievedBinder!.isDeleted, isFalse);
      expect(retrievedBinder.isSystemBinder, isTrue);
      expect(retrievedBinder.systemBinderType, equals('looking_for'));

      // Verify card inside binder remains anchored and intact
      final survivingItems = await (db.select(db.vaultItems)..where((t) => t.primaryBinderId.equals(lookingForBinder.id))).get();
      expect(survivingItems.length, equals(1));
      expect(survivingItems.first.id, equals(cardId));
      expect(survivingItems.first.primaryBinderId, equals(lookingForBinder.id));
      expect(survivingItems.first.isDeleted, isFalse);
    });

    test('1.2 Deleting "trade_block" system binder throws UnsupportedError and preserves card contents', () async {
      const userId = 'user_challenger_test_2';
      final binders = await db.vaultDao.seedSystemBindersForUser(userId, isBusiness: false);
      final tradeBlockBinder = binders.firstWhere((b) => b.systemBinderType == 'trade_block');

      const cardId = 'card_tb_001';
      await insertTestCard(cardId: cardId, binderId: tradeBlockBinder.id, userId: userId, name: 'Lion\'s Eye Diamond');

      expect(
        () async => await db.vaultDao.deleteBinder(tradeBlockBinder.id),
        throwsA(isA<UnsupportedError>()),
      );

      final retrievedBinder = await db.vaultDao.getBinderById(tradeBlockBinder.id);
      expect(retrievedBinder, isNotNull);
      expect(retrievedBinder!.isDeleted, isFalse);
      expect(retrievedBinder.isSystemBinder, isTrue);
      expect(retrievedBinder.systemBinderType, equals('trade_block'));

      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardId))).getSingle();
      expect(card.primaryBinderId, equals(tradeBlockBinder.id));
      expect(card.isDeleted, isFalse);
    });

    test('1.3 Deleting "store_inventory" system binder throws UnsupportedError and preserves card contents', () async {
      const storeId = 'store_challenger_biz_1';
      final binders = await db.vaultDao.seedSystemBindersForUser(storeId, isBusiness: true);
      final inventoryBinder = binders.firstWhere((b) => b.systemBinderType == 'store_inventory');

      const cardId = 'card_inv_001';
      await insertTestCard(cardId: cardId, binderId: inventoryBinder.id, userId: storeId, name: 'Black Lotus');

      expect(
        () async => await db.vaultDao.deleteBinder(inventoryBinder.id),
        throwsA(isA<UnsupportedError>()),
      );

      final retrievedBinder = await db.vaultDao.getBinderById(inventoryBinder.id);
      expect(retrievedBinder, isNotNull);
      expect(retrievedBinder!.isDeleted, isFalse);
      expect(retrievedBinder.isSystemBinder, isTrue);
      expect(retrievedBinder.systemBinderType, equals('store_inventory'));

      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardId))).getSingle();
      expect(card.primaryBinderId, equals(inventoryBinder.id));
      expect(card.isDeleted, isFalse);
    });

    test('1.4 Deleting "store_buylist" system binder throws UnsupportedError and preserves card contents', () async {
      const storeId = 'store_challenger_biz_2';
      final binders = await db.vaultDao.seedSystemBindersForUser(storeId, isBusiness: true);
      final buylistBinder = binders.firstWhere((b) => b.systemBinderType == 'store_buylist');

      const cardId = 'card_buy_001';
      await insertTestCard(cardId: cardId, binderId: buylistBinder.id, userId: storeId, name: 'Volcanic Island');

      expect(
        () async => await db.vaultDao.deleteBinder(buylistBinder.id),
        throwsA(isA<UnsupportedError>()),
      );

      final retrievedBinder = await db.vaultDao.getBinderById(buylistBinder.id);
      expect(retrievedBinder, isNotNull);
      expect(retrievedBinder!.isDeleted, isFalse);
      expect(retrievedBinder.isSystemBinder, isTrue);
      expect(retrievedBinder.systemBinderType, equals('store_buylist'));

      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardId))).getSingle();
      expect(card.primaryBinderId, equals(buylistBinder.id));
      expect(card.isDeleted, isFalse);
    });

    test('1.5 Contrast verification: Normal custom binder deletion succeeds and detaches cards', () async {
      const userId = 'user_custom_test';
      final customBinder = await db.vaultDao.createBinder(
        name: 'My EDH Foils',
        collectionType: 'mtg',
        userId: userId,
      );
      expect(customBinder.isSystemBinder, isFalse);

      const cardId = 'card_custom_001';
      await insertTestCard(cardId: cardId, binderId: customBinder.id, userId: userId, name: 'Sol Ring');

      // Deleting a custom non-system binder MUST succeed
      final deletedRows = await db.vaultDao.deleteBinder(customBinder.id);
      expect(deletedRows, equals(1));

      // Binder is soft-deleted
      final retrievedBinder = await db.vaultDao.getBinderById(customBinder.id, includeDeleted: true);
      expect(retrievedBinder, isNotNull);
      expect(retrievedBinder!.isDeleted, isTrue);

      // Card is unassigned (primaryBinderId is null)
      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals(cardId))).getSingle();
      expect(card.primaryBinderId, isNull);
    });
  });

  // =========================================================================
  // 2. UI Responsive Stress Testing
  // =========================================================================
  group('Challenger M3-2: 2. UI Responsive Stress Testing', () {
    testWidgets('2.1 UserProfileScreen for Individual renders with 0 RenderFlex overflows at 300px width', (tester) async {
      tester.view.physicalSize = const Size(300, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: 'user-edh-rec-fanatic'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero RenderFlex errors
      expect(tester.takeException(), isNull);

      // Verify Header components
      expect(find.byKey(const Key('profile_avatar')), findsOneWidget);
      expect(find.byKey(const Key('profile_display_name')), findsOneWidget);
      expect(find.byKey(const Key('profile_username')), findsOneWidget);
      expect(find.byKey(const Key('profile_tier_badge')), findsOneWidget);

      // Verify Action Buttons
      expect(find.byKey(const Key('profile_btn_looking_for')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_trade_block')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_shared_decks')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_propose_trade')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_add_friend')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_message')), findsOneWidget);

      // Verify Activity Wall Header
      expect(find.text('ACTIVITY WALL'), findsOneWidget);

      // Scroll down to stress test layout under narrow width
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('2.2 UserProfileScreen for Business renders VerifiedStoreBadge and store buttons with 0 overflow at 300px', (tester) async {
      tester.view.physicalSize = const Size(300, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: 'store-tbs-comics'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verified badge in narrow header
      expect(find.byKey(const Key('verified_store_badge')), findsOneWidget);
      expect(find.text('VERIFIED LGS'), findsOneWidget);

      // Business action buttons
      expect(find.byKey(const Key('profile_btn_store_inventory')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_store_buylist')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_shared_decks')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_propose_trade')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_message')), findsOneWidget);

      // Wall exists (scroll down if below the fold in 300px narrow viewport)
      await tester.scrollUntilVisible(find.text('ACTIVITY WALL'), 200);
      expect(find.text('ACTIVITY WALL'), findsOneWidget);

      // Scroll down further
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('2.3 AuthModalSheet in constrained height / landscape scenario scrolls without overflow', (tester) async {
      // Landscape or low-height phone viewport
      tester.view.physicalSize = const Size(480, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AuthModalSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Discord button is visible
      expect(find.byKey(const Key('auth_discord_cta_button')), findsOneWidget);

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('auth_guest_button')), findsOneWidget);
    });

    testWidgets('2.4 AuthModalSheet with keyboard open (bottomInset: 300) adjusts without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 640),
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: Scaffold(
                body: AuthModalSheet(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('auth_email_field')), findsOneWidget);

      // Switch to phone tab while keyboard inset is applied
      await tester.tap(find.byKey(const Key('auth_tab_phone')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('auth_phone_field')), findsOneWidget);
    });

    testWidgets('2.5 BusinessRegistrationModal in constrained viewport renders cleanly with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BusinessRegistrationModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('business_store_name_field')), findsOneWidget);
      expect(find.byKey(const Key('business_store_address_field')), findsOneWidget);
      expect(find.byKey(const Key('business_store_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('business_store_website_field')), findsOneWidget);
    });
  });

  // =========================================================================
  // 3. Business Registration & OTP Edge Cases
  // =========================================================================
  group('Challenger M3-2: 3. Business Registration & OTP Edge Cases', () {
    test('3.1 OTP bypass code "123456" succeeds and upgrades tier to business', () async {
      final repo = MockAuthRepository();

      final storeUser = await repo.registerBusiness(
        storeName: 'Countr Games & Hobbies',
        storeAddress: '123 Gathering Way, Seattle, WA 98101',
        storePhone: '(206) 555-1234',
        storeWebsite: 'https://countrgames.com',
        verificationCode: '123456',
      );

      expect(storeUser.tier, equals(AccountTier.business));
      expect(storeUser.isVerifiedBusiness, isTrue);
      expect(storeUser.isBusiness, isTrue);
      expect(storeUser.isGuest, isFalse);
      expect(storeUser.displayName, equals('Countr Games & Hobbies'));
      expect(storeUser.storeAddress, equals('123 Gathering Way, Seattle, WA 98101'));
      expect(storeUser.storePhone, equals('(206) 555-1234'));
      expect(storeUser.storeWebsite, equals('https://countrgames.com'));
    });

    test('3.2 Invalid OTP code "000000" is rejected with ArgumentError', () async {
      final repo = MockAuthRepository();

      expect(
        () async => await repo.registerBusiness(
          storeName: 'Test Store',
          storeAddress: '123 Street',
          storePhone: '555-0000',
          storeWebsite: 'https://teststore.com',
          verificationCode: '000000',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('3.3 Invalid OTP code "999999" is rejected with ArgumentError', () async {
      final repo = MockAuthRepository();

      expect(
        () async => await repo.registerBusiness(
          storeName: 'Test Store',
          storeAddress: '123 Street',
          storePhone: '555-9999',
          storeWebsite: 'https://teststore.com',
          verificationCode: '999999',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('3.4 Malformed and edge case OTP codes (empty, short, alphabetic) are rejected', () async {
      final repo = MockAuthRepository();

      // Empty string
      expect(
        () async => await repo.registerBusiness(
          storeName: 'Test Store',
          storeAddress: '123 Street',
          storePhone: '555-1234',
          storeWebsite: 'https://teststore.com',
          verificationCode: '',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Short code (5 digits)
      expect(
        () async => await repo.registerBusiness(
          storeName: 'Test Store',
          storeAddress: '123 Street',
          storePhone: '555-1234',
          storeWebsite: 'https://teststore.com',
          verificationCode: '12345',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Alphabetic code
      expect(
        () async => await repo.registerBusiness(
          storeName: 'Test Store',
          storeAddress: '123 Street',
          storePhone: '555-1234',
          storeWebsite: 'https://teststore.com',
          verificationCode: 'ABCDEF',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Code with surrounding whitespace
      expect(
        () async => await repo.registerBusiness(
          storeName: 'Test Store',
          storeAddress: '123 Street',
          storePhone: '555-1234',
          storeWebsite: 'https://teststore.com',
          verificationCode: ' 123456 ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('3.5 Phone SMS OTP verification accepts 123456 and rejects invalid codes', () async {
      final repo = MockAuthRepository();

      // Valid 123456
      final user = await repo.verifyPhoneOtp('(850) 244-4445', '123456');
      expect(user.provider, equals(AuthProviderType.phone));
      expect(user.phoneNumber, equals('(850) 244-4445'));

      // Invalid 000000
      expect(
        () async => await repo.verifyPhoneOtp('(850) 244-4445', '000000'),
        throwsA(isA<ArgumentError>()),
      );

      // Invalid 999999
      expect(
        () async => await repo.verifyPhoneOtp('(850) 244-4445', '999999'),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('3.6 UI flow in BusinessRegistrationModal displays error on invalid OTP and verifies on 123456', (tester) async {
      final authRepo = MockAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BusinessRegistrationModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter store details
      await tester.enterText(find.byKey(const Key('business_store_name_field')), 'My FLGS');
      await tester.enterText(find.byKey(const Key('business_store_address_field')), '100 Main St');
      await tester.enterText(find.byKey(const Key('business_store_phone_field')), '(555) 123-4567');
      await tester.enterText(find.byKey(const Key('business_store_website_field')), 'https://myflgs.com');

      // Tap Send Store Verification PIN
      await tester.tap(find.byKey(const Key('business_next_step_button')));
      await tester.pump(); // Advance frame without waiting for periodic timer

      expect(find.byKey(const Key('business_otp_field')), findsOneWidget);

      // Attempt invalid OTP 000000
      await tester.enterText(find.byKey(const Key('business_otp_field')), '000000');
      await tester.tap(find.byKey(const Key('business_submit_button')));
      await tester.pump(); // Process async submission

      expect(find.textContaining('Invalid store verification PIN'), findsOneWidget);

      // Attempt invalid OTP 999999
      await tester.enterText(find.byKey(const Key('business_otp_field')), '999999');
      await tester.tap(find.byKey(const Key('business_submit_button')));
      await tester.pump();

      expect(find.textContaining('Invalid store verification PIN'), findsOneWidget);

      // Now enter valid 123456
      await tester.enterText(find.byKey(const Key('business_otp_field')), '123456');
      await tester.tap(find.byKey(const Key('business_submit_button')));
      await tester.pump();

      // Verified: error message clears
      expect(find.textContaining('Invalid store verification PIN'), findsNothing);
    });
  });
}

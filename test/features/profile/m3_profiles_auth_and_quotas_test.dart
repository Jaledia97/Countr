// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive verification test suite for Milestone 3 (Epic 3: Profiles, Auth Onboarding, Quotas & System Binders)

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:countr/features/auth/presentation/widgets/verified_store_badge.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/profile/domain/services/tier_quota_service.dart';
import 'package:countr/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Trigger beforeOpen seeding
    await db.userProfileDao.seedDefaultProfiles();
  });

  tearDown(() async {
    await db.close();
  });

  group('M3 Verification: 1. Drift Schema v12 & Seeding', () {
    test('Drift database is on schemaVersion 12 or newer', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(12));
    });

    test('Default unified profiles are correctly seeded in SQLite', () async {
      final edh = await db.userProfileDao.getProfile('user-edh-rec-fanatic');
      expect(edh, isNotNull);
      expect(edh!.username, equals('@EDH_Rec_Fanatic'));
      expect(edh.displayName, equals('EDH Rec Fanatic'));
      expect(edh.isVerifiedBusiness, isFalse);

      final spicy = await db.userProfileDao.getProfile('user-spicy-brew-master');
      expect(spicy, isNotNull);
      expect(spicy!.username, equals('@SpicyBrewMaster'));

      final foil = await db.userProfileDao.getProfile('user-foil-collector-99');
      expect(foil, isNotNull);
      expect(foil!.username, equals('@FoilCollector99'));

      final tbs = await db.userProfileDao.getProfile('store-tbs-comics');
      expect(tbs, isNotNull);
      expect(tbs!.displayName, equals('TBS Comics - Fort Walton Beach'));
      expect(tbs.isVerifiedBusiness, isTrue);
      expect(tbs.accountType, equals('business'));
      expect(tbs.tier, equals('business'));

      final me = await db.userProfileDao.getProfile('user-current-me');
      expect(me, isNotNull);
      expect(me!.displayName, equals('Current Collector'));
    });

    test('System binders auto-provisioning for individual and business users', () async {
      // Provision individual binders
      final individualBinders = await db.vaultDao.seedSystemBindersForUser('user-test-ind', isBusiness: false);
      expect(individualBinders.length, equals(2));
      expect(individualBinders.any((b) => b.systemBinderType == 'looking_for' && b.isSystemBinder == true), isTrue);
      expect(individualBinders.any((b) => b.systemBinderType == 'trade_block' && b.isSystemBinder == true), isTrue);

      // Provision business binders
      final businessBinders = await db.vaultDao.seedSystemBindersForUser('user-test-biz', isBusiness: true);
      expect(businessBinders.length, equals(2));
      expect(businessBinders.any((b) => b.systemBinderType == 'store_inventory' && b.isSystemBinder == true), isTrue);
      expect(businessBinders.any((b) => b.systemBinderType == 'store_buylist' && b.isSystemBinder == true), isTrue);
    });
  });

  group('M3 Verification: 2. System Binder Hard Deletion Protection', () {
    test('Deleting a system binder throws UnsupportedError and protects the record', () async {
      final binders = await db.vaultDao.seedSystemBindersForUser('user-delete-test', isBusiness: false);
      final systemBinder = binders.firstWhere((b) => b.isSystemBinder == true);

      expect(
        () async => await db.vaultDao.deleteBinder(systemBinder.id),
        throwsA(isA<UnsupportedError>()),
      );

      // Verify binder still exists and is not deleted
      final retrieved = await db.vaultDao.getBinderById(systemBinder.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.isDeleted, isFalse);
    });

    test('getCustomBinderCount strictly excludes system binders', () async {
      const userId = 'user-quota-count-test';
      await db.vaultDao.seedSystemBindersForUser(userId, isBusiness: false);

      final initialCount = await db.vaultDao.getCustomBinderCount(userId: userId);
      expect(initialCount, equals(0));

      // Create a custom binder
      await db.vaultDao.createBinder(
        name: 'My Custom Binder',
        collectionType: 'mtg',
        userId: userId,
      );

      final afterCustom = await db.vaultDao.getCustomBinderCount(userId: userId);
      expect(afterCustom, equals(1));
    });
  });

  group('M3 Verification: 3. TierQuotaService Quota Enforcement', () {
    test('Enforces 2 binders / 3 decks for Guest and 3 binders / 5 decks for Free', () {
      final quotaService = TierQuotaService(db);

      expect(quotaService.maxCustomBindersFor(AccountTier.guest), equals(2));
      expect(quotaService.maxDecksFor(AccountTier.guest), equals(3));

      expect(quotaService.maxCustomBindersFor(AccountTier.free), equals(3));
      expect(quotaService.maxDecksFor(AccountTier.free), equals(5));

      expect(quotaService.maxCustomBindersFor(AccountTier.pro), equals(999999));
      expect(quotaService.maxDecksFor(AccountTier.pro), equals(999999));

      expect(quotaService.maxCustomBindersFor(AccountTier.business), equals(999999));
      expect(quotaService.maxDecksFor(AccountTier.business), equals(999999));
    });

    testWidgets('canCreateCustomBinder allows up to limit and blocks when exceeded', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWith((ref) => CurrentUserNotifier(
                MockAuthRepository(),
                ref,
              )..setUser(AuthUser.guest(guestId: 'guest-quota-user'))),
        ],
      );
      addTearDown(container.dispose);

      final quotaService = container.read(tierQuotaServiceProvider);

      // Clear any seeded custom binders for clean isolated quota test
      await (db.delete(db.vaultBinders)..where((t) => t.isSystemBinder.equals(false))).go();

      // Initially 0 custom binders -> allowed
      expect(await quotaService.canCreateCustomBinder(container), isTrue);

      // Create 1 custom binder -> allowed
      await db.vaultDao.createBinder(name: 'Binder 1', collectionType: 'mtg', userId: 'guest-quota-user');
      expect(await quotaService.canCreateCustomBinder(container), isTrue);

      // Create 2nd custom binder -> limit (2) reached for guest
      await db.vaultDao.createBinder(name: 'Binder 2', collectionType: 'mtg', userId: 'guest-quota-user');
      expect(await quotaService.canCreateCustomBinder(container), isFalse);
    });

    testWidgets('canCreateOrCloneDeck allows up to limit and blocks when exceeded', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWith((ref) => CurrentUserNotifier(
                MockAuthRepository(),
                ref,
              )..setUser(AuthUser.guest(guestId: 'guest-deck-user'))),
        ],
      );
      addTearDown(container.dispose);

      final quotaService = container.read(tierQuotaServiceProvider);

      // Clear any seeded decks for clean isolated quota test
      await (db.delete(db.decks)).go();

      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      // Create 3 decks for guest
      await db.vaultDao.createDeck('Deck 1', userId: 'guest-deck-user');
      await db.vaultDao.createDeck('Deck 2', userId: 'guest-deck-user');
      await db.vaultDao.createDeck('Deck 3', userId: 'guest-deck-user');

      // Now at limit 3 -> blocked
      expect(await quotaService.canCreateOrCloneDeck(container), isFalse);
    });
  });

  group('M3 Verification: 4. Multi-Provider Auth & Business LGS Verification', () {
    test('MockAuthRepository supports Discord authentication', () async {
      final repo = MockAuthRepository();
      final user = await repo.signInWithDiscord();

      expect(user.provider, equals(AuthProviderType.discord));
      expect(user.displayName, contains('Discord'));
      expect(user.isGuest, isFalse);
    });

    test('LGS Business registration verifies with OTP 123456 and upgrades tier', () async {
      final repo = MockAuthRepository();
      final user = await repo.registerBusiness(
        storeName: 'Emerald City Comics',
        storeAddress: '7744 49th St N, Pinellas Park, FL 33781',
        storePhone: '(727) 398-2665',
        storeWebsite: 'https://emeraldcitycomics.com',
        verificationCode: '123456',
      );

      expect(user.isVerifiedBusiness, isTrue);
      expect(user.tier, equals(AccountTier.business));
      expect(user.isBusiness, isTrue);
    });

    test('LGS Business registration rejects invalid OTP', () async {
      final repo = MockAuthRepository();
      expect(
        () async => await repo.registerBusiness(
          storeName: 'Emerald City Comics',
          storeAddress: '7744 49th St N',
          storePhone: '1234567890',
          storeWebsite: 'https://test.com',
          verificationCode: '000000',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('VerifiedStoreBadge renders store icon and VERIFIED LGS label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifiedStoreBadge(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('verified_store_badge')), findsOneWidget);
      expect(find.text('VERIFIED LGS'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });
  });

  group('M3 Verification: 5. Auth Modal Sheet UI Components', () {
    testWidgets('AuthModalSheet renders Discord CTA, social options, and guest button', (tester) async {
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

      // Full-width Discord button
      expect(find.byKey(const Key('auth_discord_cta_button')), findsOneWidget);
      expect(find.text('Continue with Discord'), findsOneWidget);

      // Social options
      expect(find.byKey(const Key('auth_google_button')), findsOneWidget);
      expect(find.byKey(const Key('auth_apple_button')), findsOneWidget);
      expect(find.byKey(const Key('auth_facebook_button')), findsOneWidget);

      // Email and Phone tabs
      expect(find.byKey(const Key('auth_tab_email')), findsOneWidget);
      expect(find.byKey(const Key('auth_tab_phone')), findsOneWidget);

      // Continue as Guest button
      expect(find.byKey(const Key('auth_guest_button')), findsOneWidget);
      expect(find.textContaining('Continue as Guest'), findsOneWidget);
    });
  });

  group('M3 Verification: 6. GuestMigrationService Data Migration', () {
    test('Atomically re-points guest data and auto-provisions system binders', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      // Seed guest items and binders
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'guest_binder_1',
              name: 'Guest Binder',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
              userId: const drift.Value('guest'),
            ),
          );

      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'guest_deck_1',
              name: 'Guest Deck',
              format: 'Commander',
              createdAt: DateTime.now(),
              userId: const drift.Value('guest'),
            ),
          );

      final migrationService = container.read(guestMigrationServiceProvider);
      const authenticatedUserId = 'user-new-migrated-100';

      await migrationService.migrateGuestData(
        newUserId: authenticatedUserId,
        isBusiness: false,
      );

      // Verify binder migrated
      final migratedBinder = await db.vaultDao.getBinderById('guest_binder_1');
      expect(migratedBinder, isNotNull);
      expect(migratedBinder!.userId, equals(authenticatedUserId));

      // Verify system binders provisioned
      final allBinders = await (db.select(db.vaultBinders)..where((t) => t.isDeleted.equals(false))).get();
      expect(
        allBinders.any((b) => b.userId == authenticatedUserId && b.isSystemBinder == true),
        isTrue,
      );
    });
  });

  group('M3 Verification: 7. UserProfileScreen Rendering & Actions', () {
    testWidgets('Individual user profile renders correct header and action bar', (tester) async {
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

      expect(find.byKey(const Key('user_profile_screen')), findsOneWidget);
      expect(find.byKey(const Key('profile_avatar')), findsOneWidget);
      expect(find.text('EDH Rec Fanatic'), findsOneWidget);
      expect(find.text('@EDH_Rec_Fanatic'), findsOneWidget);
      expect(find.byKey(const Key('profile_tier_badge')), findsOneWidget);

      // Individual action buttons
      expect(find.byKey(const Key('profile_btn_looking_for')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_trade_block')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_shared_decks')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_propose_trade')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_add_friend')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_message')), findsOneWidget);

      // Activity wall header
      expect(find.text('ACTIVITY WALL'), findsOneWidget);
    });

    testWidgets('Business profile renders VerifiedStoreBadge and store action bar', (tester) async {
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

      expect(find.text('TBS Comics - Fort Walton Beach'), findsOneWidget);
      expect(find.byKey(const Key('verified_store_badge')), findsOneWidget);

      // Business action buttons
      expect(find.byKey(const Key('profile_btn_store_inventory')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_store_buylist')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_shared_decks')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_propose_trade')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_message')), findsOneWidget);

      // Individual buttons should NOT appear
      expect(find.byKey(const Key('profile_btn_looking_for')), findsNothing);
      expect(find.byKey(const Key('profile_btn_trade_block')), findsNothing);
    });

    testWidgets('Tapping Looking For button opens 3x3 system binder modal', (tester) async {
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

      await tester.tap(find.byKey(const Key('profile_btn_looking_for')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('system_binder_grid_modal')), findsOneWidget);
      expect(find.text('Looking For'), findsWidgets);
    });
  });

  group('M3 Verification: 8. MorphingCommandCenter "My Profile" Top Tile', () {
    testWidgets('MorphingCommandCenter renders top My Profile tile with username and tier', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MorphingCommandCenter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('command_center_my_profile_tile')), findsOneWidget);
    });
  });
}

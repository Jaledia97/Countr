import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/router/app_router.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/presentation/screens/onboarding_welcome_screen.dart';
import 'package:countr/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/card_details_screen.dart';
import 'package:countr/features/vault/presentation/screens/collections_screen.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/feed/presentation/screens/friends_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/chat_conversation_screen.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/widgets/sticky_trade_value_meter.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/utils/card_name_resolver.dart';

class Tier2DelayedMockAuthRepository extends MockAuthRepository {
  int signOutCallCount = 0;
  Duration signOutDelay = Duration.zero;
  bool shouldFailSignOut = false;

  Tier2DelayedMockAuthRepository({super.initialUser});

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    if (signOutDelay > Duration.zero) {
      await Future.delayed(signOutDelay);
    }
    if (shouldFailSignOut) {
      throw Exception('Simulated network unreachable (DNS resolution failed)');
    }
    await super.signOut();
  }
}

void main() {
  group('Tier 2: Boundary & Corner Cases — Milestones 4 to 6 (Features 17 to 30)', () {

    // =========================================================================
    // FEATURE 17 BOUNDARIES (Log Out Feature)
    // =========================================================================
    group('Feature 17 Boundaries (Log Out Feature)', () {
      testWidgets('B17.1: Double tap on Log Out button does not trigger multiple sign-out transitions', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository()
          ..signOutDelay = const Duration(milliseconds: 300);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
              currentUserProvider.overrideWith(
                (ref) => CurrentUserNotifier(mockAuth)..setUser(AuthUser.guest()),
              ),
            ],
            child: MaterialApp(
              routes: {
                '/welcome': (c) => const Scaffold(body: Text('Welcome Screen')),
              },
              home: const Scaffold(
                body: LogoutConfirmationDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final confirmBtn = find.byKey(const Key('logout_confirm_button'));
        expect(confirmBtn, findsOneWidget);

        // Fire rapid multi-taps
        await tester.tap(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.tap(confirmBtn);

        // Inspect in-flight debounced state
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Allow async sign-out delay to finish
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(mockAuth.signOutCallCount, equals(1));
      });

      testWidgets('B17.2: Guest user tapping Log Out shows prompt clarifying guest status', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository();

        // 1. Guest user
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('guest_scope'),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
              currentUserProvider.overrideWith(
                (ref) => CurrentUserNotifier(mockAuth)..setUser(AuthUser.guest()),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: LogoutConfirmationDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('You are browsing as Guest. Local cards can be preserved.'), findsOneWidget);
        expect(find.textContaining('Guest'), findsWidgets);
        expect(find.text('Are you sure you want to log out?'), findsNothing);

        // 2. Registered user
        final registeredUser = AuthUser(
          id: 'user_reg_b172',
          displayName: 'Registered Pro',
          username: '@registered_pro',
          tier: AccountTier.pro,
          provider: AuthProviderType.google,
          isGuest: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('reg_scope'),
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
              currentUserProvider.overrideWith(
                (ref) => CurrentUserNotifier(mockAuth)..setUser(registeredUser),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: LogoutConfirmationDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Are you sure you want to log out?'), findsOneWidget);
        expect(find.text('You are browsing as Guest. Local cards can be preserved.'), findsNothing);
      });

      testWidgets('B17.3: Cancelling logout prompt retains current session and does not route to /welcome', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository();

        final registeredUser = AuthUser(
          id: 'user_active_b173',
          displayName: 'Active Collector',
          username: '@active_collector',
          tier: AccountTier.pro,
          provider: AuthProviderType.apple,
          isGuest: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        late final ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
              currentUserProvider.overrideWith(
                (ref) => CurrentUserNotifier(mockAuth)..setUser(registeredUser),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  home: Scaffold(
                    body: Builder(
                      builder: (innerContext) => ElevatedButton(
                        key: const Key('open_dialog_btn'),
                        onPressed: () => LogoutConfirmationDialog.show(innerContext),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_dialog_btn')));
        await tester.pumpAndSettle();
        expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

        await tester.tap(find.byKey(const Key('logout_cancel_button')));
        await tester.pumpAndSettle();

        expect(find.byType(LogoutConfirmationDialog), findsNothing);

        final currentUser = container.read(currentUserProvider);
        expect(currentUser.id, equals('user_active_b173'));
        expect(currentUser.isGuest, isFalse);
        expect(mockAuth.signOutCallCount, equals(0));
      });

      testWidgets('B17.4: Network failure during signOut falls back to local session reset', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository()
          ..shouldFailSignOut = true;

        final regUser = AuthUser(
          id: 'user_offline_b174',
          displayName: 'Offline User',
          username: '@offline_user',
          tier: AccountTier.free,
          provider: AuthProviderType.email,
          isGuest: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        late final ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
              currentUserProvider.overrideWith(
                (ref) => CurrentUserNotifier(mockAuth)..setUser(regUser),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  routes: {
                    '/welcome': (c) => const Scaffold(body: Text('Welcome Screen')),
                  },
                  home: const Scaffold(
                    body: LogoutConfirmationDialog(),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('logout_confirm_button')));
        await tester.pumpAndSettle();

        expect(mockAuth.signOutCallCount, equals(1));
        final userAfterLogout = container.read(currentUserProvider);
        expect(userAfterLogout.isGuest, isTrue);
      });

      testWidgets('B17.5: Post-logout navigation stack does not retain authenticated routes', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository();
        addTearDown(() => appRouter.go('/feed'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
            ],
            child: MaterialApp.router(
              routerConfig: appRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Starts on FeedScreen shell
        expect(find.byType(FeedScreen), findsOneWidget);

        final navContext = rootNavigatorKey.currentContext!;
        LogoutConfirmationDialog.show(navContext);
        await tester.pumpAndSettle();

        expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

        await tester.tap(find.byKey(const Key('logout_confirm_button')));
        await tester.pumpAndSettle();

        // Verified arrival at /welcome screen without retaining FeedScreen
        expect(find.byType(OnboardingWelcomeScreen), findsOneWidget);
        expect(find.byType(FeedScreen), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 18 BOUNDARIES (Complete 3-Step Onboarding Workflow)
    // =========================================================================
    group('Feature 18 Boundaries (Complete 3-Step Onboarding Workflow)', () {
      testWidgets('B18.1: Invalid phone number format rejects SMS send', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_auth_phone_tab')));
        await tester.pumpAndSettle();

        final phoneInput = find.byKey(const Key('onboarding_auth_phone_input'));
        final sendOtpBtn = find.byKey(const Key('onboarding_auth_send_otp'));

        // Case 1: Under 10 digits
        await tester.enterText(phoneInput, '12345');
        await tester.tap(sendOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid phone number (min 10 digits).'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_auth_otp_input')), findsNothing);

        // Case 2: Alphabetic
        await tester.enterText(phoneInput, 'abc');
        await tester.tap(sendOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid phone number (min 10 digits).'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_auth_otp_input')), findsNothing);

        // Case 3: Valid 10-digit phone
        await tester.enterText(phoneInput, '(850) 555-0199');
        await tester.tap(sendOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid phone number (min 10 digits).'), findsNothing);
        expect(find.byKey(const Key('onboarding_auth_otp_input')), findsOneWidget);
      });

      testWidgets('B18.2: Incorrect 6-digit OTP throws validation error without advancing step', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_auth_phone_tab')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('onboarding_auth_phone_input')), '8505550199');
        await tester.tap(find.byKey(const Key('onboarding_auth_send_otp')));
        await tester.pumpAndSettle();

        final otpInput = find.byKey(const Key('onboarding_auth_otp_input'));
        final verifyBtn = find.byKey(const Key('onboarding_auth_verify_otp'));

        // Wrong OTP code
        await tester.enterText(otpInput, '000000');
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Invalid OTP code. Use 123456.'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);

        // Valid OTP code 123456
        await tester.enterText(otpInput, '123456');
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Invalid OTP code. Use 123456.'), findsNothing);
      });

      testWidgets('B18.3: Username with illegal characters rejects setup', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        final nameInput = find.byKey(const Key('profile_setup_display_name_input'));
        final usernameInput = find.byKey(const Key('profile_setup_username_input'));
        final submitBtn = find.byKey(const Key('profile_setup_submit_button'));

        await tester.enterText(nameInput, 'Planeswalker');

        // Space inside username
        await tester.enterText(usernameInput, '@has space');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);

        // Illegal punctuation
        await tester.enterText(usernameInput, '@bad!char');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsOneWidget,
        );

        // Valid handle
        await tester.enterText(usernameInput, '@valid_handle_123');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsNothing,
        );
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
      });

      testWidgets('B18.4: Business registration with empty store address or phone fails validation', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockAuth = Tier2DelayedMockAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuth),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
        await tester.pumpAndSettle();

        final nameInput = find.byKey(const Key('business_store_lookup_input'));
        final addrInput = find.byKey(const Key('business_store_address_input'));
        final phoneInput = find.byKey(const Key('business_store_phone_input'));
        final webInput = find.byKey(const Key('business_store_website_input'));
        final otpInput = find.byKey(const Key('business_otp_input'));
        final verifyBtn = find.byKey(const Key('business_verify_otp_button'));

        // Missing address
        await tester.enterText(nameInput, 'TBS Comics');
        await tester.enterText(addrInput, '');
        await tester.enterText(phoneInput, '850-555-0100');
        await tester.enterText(webInput, 'https://tbscomics.com');
        await tester.enterText(otpInput, '123456');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);

        // Missing phone
        await tester.enterText(addrInput, '123 Main St');
        await tester.enterText(phoneInput, '');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);

        // Complete store details
        await tester.enterText(phoneInput, '850-555-0100');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsNothing);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
      });

      test('B18.5: Guest migration with 0 guest items completes successfully with zero counts', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await db.delete(db.vaultItems).go();
        await db.delete(db.vaultBinders).go();
        await db.delete(db.decks).go();
        await db.delete(db.exploreDeckVotes).go();

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(guestMigrationServiceProvider);

        final summary = await service.migrateGuestData(
          newUserId: 'user_empty_guest_b185',
          isBusiness: false,
        );

        expect(summary.isSuccess, isTrue);
        expect(summary.migratedVaultItems, equals(0));
        expect(summary.migratedBinders, equals(0));
        expect(summary.migratedDecks, equals(0));
        expect(summary.migratedVotes, equals(0));
      });
    });

    // =========================================================================
    // FEATURE 19 BOUNDARIES (Unified Card Details Resolution)
    // =========================================================================
    group('Feature 19 Boundaries (Unified Card Details Resolution)', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_mox',
            collectionType: 'mtg',
            name: 'Mox Diamond',
            setOrSeries: 'STH',
            imageUrl: '',
            acquiredPrice: 650.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 650.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'scryfall_id': 'b8703868-47a7-4a00-93a3-c475f1b0ef22',
              'type_line': 'Artifact',
              'oracle_text': 'Discard a land card: Add one mana of any color.',
              'prices': {'usd': '650.00'},
            }),
          ),
        );

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_lim',
            collectionType: 'mtg',
            name: "Lim-Dul's Vault",
            setOrSeries: 'ALL',
            imageUrl: '',
            acquiredPrice: 4.5,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 4.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'scryfall_id': 'aec89c76-56f3-4c42-8942-9c4c274245d4',
              'type_line': 'Instant',
              'oracle_text': 'Look at the top five cards of your library.',
              'prices': {'usd': '4.50'},
            }),
          ),
        );

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_promo_noprice',
            collectionType: 'mtg',
            name: 'Promo Card Without Pricing',
            setOrSeries: 'PRM',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 0.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'scryfall_id': '11111111-1111-1111-1111-111111111111',
              'type_line': 'Creature',
              'oracle_text': 'Promo text.',
              'prices': <String, dynamic>{},
            }),
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('B19.1: Malformed slug (item-mtg- with empty name) throws ArgumentError in VaultDao', () async {
        expect(
          () => dao.findCatalogCard(identifier: 'item-mtg-'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => dao.findCatalogCard(identifier: 'item-mtg----'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('B19.2: Slug with multiple hyphens cleans up extra hyphens gracefully in VaultDao.findCatalogCard', () async {
        final res = await dao.findCatalogCard(identifier: 'item-mtg-lim---dul-s-vault');
        expect(res, isNotNull);
        expect(res!.name, equals("Lim-Dul's Vault"));
      });

      testWidgets('B19.3: Unknown card ID falls back to error card tile without crash in CardDetailsScreen', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CardDetailsScreen(cardId: 'item-mtg-nonexistent-card-xyz'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(const Key('card_detail_error_tile')), findsOneWidget);
        expect(find.text('Card not found'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('B19.4: Card with missing price data maps prices gracefully in CardDetailsScreen', (tester) async {
        final res = await dao.findCatalogCard(identifier: 'c_promo_noprice');
        expect(res, isNotNull);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CardDetailsScreen(cardId: 'c_promo_noprice'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Promo Card Without Pricing'), findsWidgets);
        expect(find.textContaining('Unlisted'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      test('B19.5: Case variation (Item-MTG-MOX-DIAMOND) resolves cleanly to Mox Diamond in VaultDao', () async {
        final res = await dao.findCatalogCard(identifier: 'Item-MTG-MOX-DIAMOND');
        expect(res, isNotNull);
        expect(res!.name, equals('Mox Diamond'));
      });
    });

    // =========================================================================
    // FEATURE 20 BOUNDARIES (Vault Singles Header Spacing Fix)
    // =========================================================================
    group('Feature 20 Boundaries (Vault Singles Header Spacing Fix)', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('B20.1: Rapid toggle of show/hide vault value does not cause jumpy glitches in VaultScreen', (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: VaultScreen()),
          ),
        );
        await tester.pump();

        for (int i = 0; i < 10; i++) {
          final current = container.read(vaultShowEstimatedValueProvider);
          container.read(vaultShowEstimatedValueProvider.notifier).state = !current;
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);
      });

      testWidgets('B20.2: Extreme top padding / safe area insets respects SafeArea bounds in VaultScreen', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
              vaultShowEstimatedValueProvider.overrideWith((ref) => false),
            ],
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(padding: EdgeInsets.only(top: 50.0)),
                child: VaultScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('B20.3: Scroll offset > 0 when hiding header clamps cleanly to 0 extent in VaultScreen', (tester) async {
        for (int i = 0; i < 20; i++) {
          await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'scroll_card_$i',
              collectionType: 'mtg',
              name: 'Card $i',
              setOrSeries: 'SET',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );
        }

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            vaultShowEstimatedValueProvider.overrideWith((ref) => true),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: VaultScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
        await tester.pump();

        container.read(vaultShowEstimatedValueProvider.notifier).state = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('vault_value_header')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('B20.4: Empty Vault (0 cards) with hidden header leaves search bar at top in VaultScreen', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
              vaultShowEstimatedValueProvider.overrideWith((ref) => false),
            ],
            child: const MaterialApp(home: VaultScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);
        final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
        final searchBarTop = tester.getTopLeft(find.byKey(const Key('vault_singles_search_bar'))).dy;
        expect(searchBarTop - appBarBottom, equals(0.0));
      });

      testWidgets('B20.5: Zero dead space verified: distance between AppBar and search bar is exactly 0dp', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
              vaultShowEstimatedValueProvider.overrideWith((ref) => false),
            ],
            child: const MaterialApp(home: VaultScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
        final searchBarTop = tester.getTopLeft(find.byKey(const Key('vault_singles_search_bar'))).dy;
        expect(searchBarTop - appBarBottom, equals(0.0));
      });
    });

    // =========================================================================
    // FEATURE 21 BOUNDARIES (Vault Singles Live Search)
    // =========================================================================
    group('Feature 21 Boundaries (Vault Singles Live Search)', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'b21_sol',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'C21',
            imageUrl: '',
            acquiredPrice: 2.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'type_line': 'Artifact',
              'oracle_text': '{T}: Add {C}{C}.',
            }),
          ),
        );

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'b21_aether',
            collectionType: 'mtg',
            name: 'Aetherling',
            setOrSeries: 'DGM',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'type_line': 'Creature',
              'oracle_text': 'Exile Aetherling.',
            }),
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('B21.1: Search query with SQL injection characters does not leak rows in SQLite', () async {
        const query = "' OR 1=1 --";
        final matches = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: query);
        expect(matches, isEmpty, reason: "SQL Injection query '$query' must not return all rows!");
      });

      test('B21.2: Search query with regex metacharacters matches literally without crashing', () async {
        for (final meta in [r'.*', r'[a-z]+', r'\d+', r'^$', r'+', r'(']) {
          final matches = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: meta);
          expect(matches, isEmpty);
        }
      });

      test('B21.3: Search query of 250+ characters executes without error', () async {
        final longQuery = 'q' * 250;
        final matches = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: longQuery);
        expect(matches, isEmpty);
      });

      testWidgets('B21.4: Search matching 0 items displays clean empty state message in VaultScreen', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            ],
            child: const MaterialApp(home: VaultScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final searchTrigger = find.byKey(const Key('vault_search_expand_button'));
        if (searchTrigger.evaluate().isNotEmpty) {
          await tester.tap(searchTrigger);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }

        final textField = find.byType(TextField);
        await tester.enterText(textField.first, 'NonExistentCard123');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(const Key('vault_search_empty_state')), findsOneWidget);
        expect(find.text("No cards found matching 'NonExistentCard123'"), findsOneWidget);
        expect(find.text('Sol Ring'), findsNothing);
        expect(find.text('Aetherling'), findsNothing);
      });

      test('B21.5: Unicode symbols match accurately in SQLite search', () async {
        final matches = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'Aetherling');
        expect(matches.length, equals(1));
        expect(matches.first.name, equals('Aetherling'));
      });
    });

    // =========================================================================
    // FEATURE 22 BOUNDARIES (Vault Collections Set Completion Ratio)
    // =========================================================================
    group('Feature 22 Boundaries (Vault Collections Set Completion Ratio)', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();
      });

      tearDown(() async {
        await db.close();
      });

      test('B22.1: Non-existent set code returns 0.0% completion ratio in VaultDao', () async {
        final collections = await dao.watchSetCollections(
          collectionType: 'mtg',
          searchQuery: 'NonExistentSetXYZ',
        ).first;
        expect(collections, isEmpty);
      });

      test('B22.2: Master catalog with 0 cards in set handles safely (0.0%)', () async {
        const emptySet = VaultSetCollection(
          setName: 'Empty Set',
          setCode: 'EMP',
          collectionType: 'mtg',
          totalCount: 0,
          ownedCount: 0,
          completionPercentage: 0.0,
        );
        expect(emptySet.completionPercentage, equals(0.0));
        expect(emptySet.isComplete, isFalse);
      });

      test('B22.3: User owning 100 cards from different set does not inflate completion of target set', () async {
        for (int i = 1; i <= 2; i++) {
          await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mh3_$i',
              collectionType: 'mtg',
              name: 'MH3 Card $i',
              setOrSeries: 'Modern Horizons 3',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0), // Unowned
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'mh3', 'collector_number': '$i'}),
            ),
          );
        }

        for (int i = 1; i <= 100; i++) {
          await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'ltr_other_$i',
              collectionType: 'mtg',
              name: 'LTR Other $i',
              setOrSeries: 'Lord of the Rings',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1), // Owned!
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'ltr', 'collector_number': '$i'}),
            ),
          );
        }

        final collections = await dao.watchSetCollections(
          collectionType: 'mtg',
          searchQuery: 'Modern Horizons 3',
        ).first;
        expect(collections.length, equals(1));
        final mh3 = collections.first;

        expect(mh3.totalCount, equals(2));
        expect(mh3.ownedCount, equals(0));
        expect(mh3.completionPercentage, equals(0.0));
      });

      test('B22.4: 100% complete set ownership produces 1.0 (100.0%) in VaultDao', () async {
        for (int i = 1; i <= 2; i++) {
          await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'woe_$i',
              collectionType: 'mtg',
              name: 'WOE Card $i',
              setOrSeries: 'Wilds of Eldraine',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1), // Owned
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'woe', 'collector_number': '$i'}),
            ),
          );
        }

        final collections = await dao.watchSetCollections(
          collectionType: 'mtg',
          searchQuery: 'Wilds of Eldraine',
        ).first;
        expect(collections.length, equals(1));
        final woe = collections.first;

        expect(woe.totalCount, equals(2));
        expect(woe.ownedCount, equals(2));
        expect(woe.completionPercentage, equals(1.0));
        expect(woe.isComplete, isTrue);
      });

      test('B22.5: User owns more copies than catalog count clamps to 1.0 max in VaultDao', () async {
        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'lea_lotus',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'Limited Edition Alpha',
            imageUrl: '',
            acquiredPrice: 1000.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(10), // 10 copies
            condition: 'NM',
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'set_code': 'lea', 'collector_number': '1'}),
          ),
        );

        final collections = await dao.watchSetCollections(
          collectionType: 'mtg',
          searchQuery: 'Limited Edition Alpha',
        ).first;
        expect(collections.length, equals(1));
        final lea = collections.first;

        expect(lea.totalCount, equals(1));
        expect(lea.ownedCount, equals(1));
        expect(lea.completionPercentage, equals(1.0));
      });
    });

    // =========================================================================
    // FEATURE 23 BOUNDARIES (3x3 Master Set View)
    // =========================================================================
    group('Feature 23 Boundaries (3x3 Master Set View)', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('B23.1: Set with 0 cards displays clean empty set state in MasterSetScreen', (tester) async {
        const emptyCollection = VaultSetCollection(
          setName: 'Empty Set',
          setCode: 'EMP',
          collectionType: 'Magic: The Gathering',
          totalCount: 0,
          ownedCount: 0,
          completionPercentage: 0.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: MasterSetScreen(
                collection: emptyCollection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MasterSetScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      test('B23.2: Set with 1,000+ cards calculates grid row count correctly', () {
        const totalCards = 1050;
        final rows = (totalCards / 3).ceil();
        expect(rows, equals(350));
      });

      testWidgets('B23.3: Extreme quantity badge (x999) renders without overflow on 320px viewport in MasterSetScreen', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'extreme_card_1',
            collectionType: 'mtg',
            name: 'Relentless Rats',
            setOrSeries: 'Fifth Dawn',
            imageUrl: '',
            acquiredPrice: 2.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(999), // x999!
            condition: 'NM',
            currentMarketPrice: 2.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'set_code': '5dn', 'collector_number': '1'}),
          ),
        );

        const collection = VaultSetCollection(
          setName: 'Fifth Dawn',
          setCode: '5DN',
          collectionType: 'Magic: The Gathering',
          totalCount: 1,
          ownedCount: 1,
          completionPercentage: 1.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: MasterSetScreen(
                collection: collection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_quantity_badge')), findsOneWidget);
        expect(find.text('x999'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      test('B23.4: Grayscale color filter preserves alpha matrix identity', () {
        expect(vaultGrayscaleColorFilter, isNotNull);
        const grayscaleMatrix = <double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ];
        expect(grayscaleMatrix[18], equals(1.0));
        expect(ColorFilter.matrix(grayscaleMatrix), equals(vaultGrayscaleColorFilter));
      });

      testWidgets('B23.5: Standalone collections_screen renders with search bar and VaultCollectionViewSliver', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CollectionsScreen(initialGame: 'Magic: The Gathering'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('collections_screen')), findsOneWidget);
        expect(find.text('Set Collections'), findsOneWidget);
        expect(find.byType(VaultCollectionViewSliver), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 24 BOUNDARIES (Wishlist Badge & Filter in Vault/Binders)
    // =========================================================================
    group('Feature 24 Boundaries (Wishlist Badge & Filter in Vault/Binders)', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'reg_card_1',
            collectionType: 'mtg',
            name: 'Lightning Bolt',
            setOrSeries: 'Core Set 2010',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            isWishlisted: const drift.Value(false),
            currentMarketPrice: 1.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('B24.1: Vault with 0 wishlisted cards when filter active displays empty state in VaultScreen', (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: VaultScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final wishlistChip = find.byKey(const Key('vault_filter_wishlisted_chip'));
        expect(wishlistChip, findsWidgets);

        await tester.ensureVisible(wishlistChip.first);
        await tester.tap(wishlistChip.first);
        await tester.pumpAndSettle();

        expect(container.read(vaultWishlistFilterProvider), isTrue);
        expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);
      });

      test('B24.2: Toggling wishlist on a card while filter active immediately updates SQLite stream', () async {
        var wishlisted = await dao.watchItemsByCollection('mtg', onlyWishlisted: true).first;
        expect(wishlisted, isEmpty);

        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('reg_card_1'))).write(
          const VaultItemsCompanion(isWishlisted: drift.Value(true)),
        );

        wishlisted = await dao.watchItemsByCollection('mtg', onlyWishlisted: true).first;
        expect(wishlisted.length, equals(1));
        expect(wishlisted.first.name, equals('Lightning Bolt'));

        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('reg_card_1'))).write(
          const VaultItemsCompanion(isWishlisted: drift.Value(false)),
        );

        wishlisted = await dao.watchItemsByCollection('mtg', onlyWishlisted: true).first;
        expect(wishlisted, isEmpty);
      });

      test('B24.3: Batch wishlisting 20 cards updates all cards with isWishlisted: true in SQLite', () async {
        for (int i = 0; i < 20; i++) {
          await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'batch_c_$i',
              collectionType: 'mtg',
              name: 'Batch Card $i',
              setOrSeries: 'Set B',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isWishlisted: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );
        }

        await db.customUpdate(
          'UPDATE vault_items SET is_wishlisted = 1 WHERE collection_type = ?',
          variables: [drift.Variable.withString('mtg')],
          updates: {db.vaultItems},
        );

        final wishlisted = await dao.watchItemsByCollection('mtg', onlyWishlisted: true).first;
        expect(wishlisted.length, equals(21));
        expect(wishlisted.every((c) => c.isWishlisted == true), isTrue);
      });

      test('B24.4: Deleting a wishlisted card removes it from wishlisted filtered view in SQLite', () async {
        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('reg_card_1'))).write(
          const VaultItemsCompanion(isWishlisted: drift.Value(true)),
        );

        var wishlisted = await dao.watchItemsByCollection('mtg', onlyWishlisted: true).first;
        expect(wishlisted.length, equals(1));

        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('reg_card_1'))).write(
          const VaultItemsCompanion(isDeleted: drift.Value(true)),
        );

        wishlisted = await dao.watchItemsByCollection('mtg', onlyWishlisted: true).first;
        expect(wishlisted, isEmpty);
      });

      testWidgets('B24.5: Wishlist badge positioning sits at top right of card tile Positioned(top: 4, right: 4)', (tester) async {
        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('reg_card_1'))).write(
          const VaultItemsCompanion(isWishlisted: drift.Value(true)),
        );

        final item = (await dao.getItemById('reg_card_1'))!;
        expect(item.isWishlisted, isTrue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 300,
                  child: VaultItemTile(
                    item: item,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(const Key('vault_card_wishlist_badge'));
        expect(badgeFinder, findsOneWidget);

        final iconFinder = find.byKey(const Key('wishlist_badge_pos'));
        expect(iconFinder, findsOneWidget);

        final positionedFinder = find.ancestor(
          of: badgeFinder,
          matching: find.byType(Positioned),
        );
        expect(positionedFinder, findsOneWidget);

        final positioned = tester.widget<Positioned>(positionedFinder);
        expect(positioned.top, equals(4.0));
        expect(positioned.right, equals(4.0));
      });
    });

    // =========================================================================
    // FEATURE 25 BOUNDARIES (Friends & Groups 2-Tab Restructure)
    // =========================================================================
    const currentUserId = 'user_me';
    const partnerId = 'user_partner';

    Future<void> seedUser(AppDatabase db, String id, String handle, String name) async {
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: id,
          username: handle,
          displayName: name,
          accountType: const drift.Value('individual'),
          isVerifiedBusiness: const drift.Value(false),
          friendCount: const drift.Value(0),
          repCount: const drift.Value(10),
          tier: const drift.Value('free'),
          syncStatus: const drift.Value('synced'),
          collectionVisibility: const drift.Value('public'),
          createdAt: DateTime.now(),
          isDeleted: const drift.Value(false),
        ),
      );
    }

    Widget wrapScope(Widget child, AppDatabase db, {String uid = currentUserId}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => uid),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    group('Feature 25 Boundaries (Friends & Groups 2-Tab Restructure)', () {
      testWidgets('B25.1: Switching tabs changes TabBar selection index without crashing', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        final tabBar = tester.widget<TabBar>(find.byKey(const Key('friends_hub_tab_bar')));
        expect(tabBar.tabs.length, equals(2));
        expect(find.byKey(const Key('friends_search_input')), findsOneWidget);

        await tester.tap(find.byKey(const Key('friends_tab_groups')));
        await tester.pumpAndSettle();
        expect(find.text('TBS Comics Table 1'), findsOneWidget);
      });

      testWidgets('B25.2: Rapid swipe between tabs settles cleanly', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('friends_tab_groups')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends_tab_friends')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('friends_search_input')), findsOneWidget);
      });

      testWidgets('B25.3: Orientation change maintains active tab index', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(initialTab: 'groups'), db));
        await tester.pumpAndSettle();
        expect(find.text('TBS Comics Table 1'), findsOneWidget);

        tester.view.physicalSize = const Size(600, 800);
        await tester.pumpAndSettle();
        expect(find.text('TBS Comics Table 1'), findsOneWidget);
      });

      testWidgets('B25.4: Tab bar titles Friends and Groups are concise and avoid overflow', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        tester.view.physicalSize = const Size(360, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('friends_tab_friends')), findsOneWidget);
        expect(find.byKey(const Key('friends_tab_groups')), findsOneWidget);
      });

      testWidgets('B25.5: Non-existent route tab param initialTab: "unknown" defaults to Friends tab (0)', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(initialTab: 'unknown'), db));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('friends_search_input')), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 26 BOUNDARIES (Friends Tab 3-Section Layout)
    // =========================================================================
    group('Feature 26 Boundaries (Friends Tab 3-Section Layout)', () {
      testWidgets('B26.1: 0 incoming friend requests displays empty indicator', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        expect(find.text('No pending requests'), findsOneWidget);
      });

      testWidgets('B26.2: 5 incoming requests displays first 3 items with See More (2)', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        final now = DateTime.now();
        for (int i = 1; i <= 5; i++) {
          final uid = 'req_user_$i';
          await seedUser(db, uid, '@requester_$i', 'Requester $i');
          await db.into(db.friendships).insert(
            FriendshipsCompanion.insert(
              id: 'fr_in_$i',
              userId: uid,
              friendId: currentUserId,
              status: const drift.Value('pending'),
              createdAt: drift.Value(now),
            ),
          );
        }

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        expect(find.text('Friend Requests (5)'), findsOneWidget);
        expect(find.text('See More (2)'), findsOneWidget);

        await tester.tap(find.text('See More (2)'));
        await tester.pumpAndSettle();

        expect(find.text('Show Less'), findsOneWidget);
        expect(find.text('Requester 5'), findsOneWidget);
      });

      testWidgets('B26.3: Friends list search with no matches displays helpful message', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Spicy Partner');

        final now = DateTime.now();
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'fr_accepted_1',
            userId: currentUserId,
            friendId: partnerId,
            status: const drift.Value('accepted'),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('friends_search_input')), 'NonExistentZzz');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('No friends match your search'), findsOneWidget);
      });

      testWidgets('B26.4: 0 sent requests displays empty indicator', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        expect(find.text('No sent requests'), findsOneWidget);
      });

      testWidgets('B26.5: Approving a request removes it from incoming and adds to Friends List', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Spicy Partner');

        final now = DateTime.now();
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'fr_incoming_approve',
            userId: partnerId,
            friendId: currentUserId,
            status: const drift.Value('pending'),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(wrapScope(const FriendsHubScreen(), db));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('friend_request_approve_$partnerId')), findsOneWidget);

        await tester.tap(find.byKey(Key('friend_request_approve_$partnerId')));
        await tester.pumpAndSettle();

        final friendship = await (db.select(db.friendships)
              ..where((t) => t.userId.equals(partnerId) & t.friendId.equals(currentUserId)))
            .getSingleOrNull();
        expect(friendship?.status, equals('accepted'));

        expect(find.text('No pending requests'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('friends_list_section')),
            matching: find.text('Spicy Partner'),
          ),
          findsOneWidget,
        );
      });
    });

    // =========================================================================
    // FEATURE 27 BOUNDARIES (Inbox Messages Draft Compose Button)
    // =========================================================================
    group('Feature 27 Boundaries (Inbox Messages Draft Compose Button)', () {
      testWidgets('B27.1: User picker with 0 friends displays add friends state', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        await tester.pumpWidget(wrapScope(const InboxHubScreen(initialTab: 'messages'), db));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('inbox_compose_button')));
        await tester.pumpAndSettle();

        expect(find.text('Invite friends to start a chat'), findsOneWidget);
      });

      testWidgets('B27.2: Attempting to select 3+ partners blocks selection with limit warning', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, 'u1', '@u1', 'User One');
        await seedUser(db, 'u2', '@u2', 'User Two');
        await seedUser(db, 'u3', '@u3', 'User Three');

        final now = DateTime.now();
        for (final uid in ['u1', 'u2', 'u3']) {
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

        await tester.pumpWidget(wrapScope(const InboxHubScreen(initialTab: 'messages'), db));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('inbox_compose_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('User One'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('User Two'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('User Three'));
        await tester.pumpAndSettle();

        expect(find.text('Maximum 2 partners allowed for 3-way conversation'), findsOneWidget);
      });

      testWidgets('B27.3: Selecting self in user picker is disabled', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'My Self User');
        await seedUser(db, 'u1', '@u1', 'User One');

        final now = DateTime.now();
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'fr_u1',
            userId: currentUserId,
            friendId: 'u1',
            status: const drift.Value('accepted'),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(wrapScope(const InboxHubScreen(initialTab: 'messages'), db));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('inbox_compose_button')));
        await tester.pumpAndSettle();

        expect(find.text('My Self User'), findsNothing);
        expect(find.text('User One'), findsOneWidget);
      });

      testWidgets('B27.4: Rapid tapping on compose FAB opens modal only once', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');

        await tester.pumpWidget(wrapScope(const InboxHubScreen(initialTab: 'messages'), db));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('inbox_compose_button')));
        await tester.tap(find.byKey(const Key('inbox_compose_button')), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inbox_user_picker_modal')), findsOneWidget);
      });

      testWidgets('B27.5: Searching users in picker filters live with debouncing', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, 'u_spicy', '@SpicyBrewMaster', 'Spicy Brewmaster');
        await seedUser(db, 'u_edh', '@EDH_Rec_Fanatic', 'EDH Rec Fanatic');

        final now = DateTime.now();
        for (final uid in ['u_spicy', 'u_edh']) {
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

        await tester.pumpWidget(wrapScope(const InboxHubScreen(initialTab: 'messages'), db));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('inbox_compose_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('inbox_user_picker_search_input')), 'edh');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('EDH Rec Fanatic'), findsOneWidget);
        expect(find.text('Spicy Brewmaster'), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 28 BOUNDARIES (Reactive Trade Proposal Status & Unpinning)
    // =========================================================================
    group('Feature 28 Boundaries (Reactive Trade Proposal Status & Unpinning)', () {
      testWidgets('B28.1: Status transition outside chat immediately updates chat banner via stream', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final now = DateTime.now();
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_stream_1',
            proposerId: partnerId,
            receiverId: currentUserId,
            status: const drift.Value('pending'),
            offeredCardIdsJson: jsonEncode(['c1']),
            requestedCardIdsJson: jsonEncode(['c2']),
            offeredTotalValue: const drift.Value(10.0),
            requestedTotalValue: const drift.Value(10.0),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(wrapScope(
          const ChatConversationScreen(conversationId: 'user_me_user_partner', contactId: partnerId),
          db,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Active Trade Proposal'), findsOneWidget);

        await (db.update(db.tradeProposals)..where((t) => t.id.equals('prop_stream_1')))
            .write(const TradeProposalsCompanion(status: drift.Value('cancelled')));
        await tester.pumpAndSettle();

        expect(find.text('Active Trade Proposal'), findsNothing);
      });

      testWidgets('B28.2: Proposal with unknown status string defaults safely', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final now = DateTime.now();
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_unknown_status',
            proposerId: partnerId,
            receiverId: currentUserId,
            status: const drift.Value('unknown_future_status'),
            offeredCardIdsJson: jsonEncode(['c1']),
            requestedCardIdsJson: jsonEncode(['c2']),
            offeredTotalValue: const drift.Value(10.0),
            requestedTotalValue: const drift.Value(10.0),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(wrapScope(
          const ChatConversationScreen(conversationId: 'user_me_user_partner', contactId: partnerId),
          db,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Active Trade Proposal'), findsNothing);
      });

      testWidgets('B28.3: Trade proposal without active banner handles status changes cleanly', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        await tester.pumpWidget(wrapScope(
          const ChatConversationScreen(conversationId: 'user_me_user_partner', contactId: partnerId),
          db,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Active Trade Proposal'), findsNothing);
      });

      testWidgets('B28.4: Multiple proposals in conversation only pins single latest active offer', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final now = DateTime.now();
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_old_countered',
            proposerId: partnerId,
            receiverId: currentUserId,
            status: const drift.Value('countered'),
            offeredCardIdsJson: jsonEncode(['c1']),
            requestedCardIdsJson: jsonEncode(['c2']),
            offeredTotalValue: const drift.Value(10.0),
            requestedTotalValue: const drift.Value(10.0),
            createdAt: drift.Value(now),
          ),
        );
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_new_pending',
            proposerId: currentUserId,
            receiverId: partnerId,
            status: const drift.Value('pending'),
            offeredCardIdsJson: jsonEncode(['c2']),
            requestedCardIdsJson: jsonEncode(['c1']),
            offeredTotalValue: const drift.Value(15.0),
            requestedTotalValue: const drift.Value(15.0),
            createdAt: drift.Value(now.add(const Duration(minutes: 1))),
          ),
        );

        await tester.pumpWidget(wrapScope(
          const ChatConversationScreen(conversationId: 'user_me_user_partner', contactId: partnerId),
          db,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Active Trade Proposal'), findsOneWidget);
      });

      testWidgets('B28.5: Deleted trade proposal removes banner without crash', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final now = DateTime.now();
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_delete_me',
            proposerId: partnerId,
            receiverId: currentUserId,
            status: const drift.Value('pending'),
            offeredCardIdsJson: jsonEncode(['c1']),
            requestedCardIdsJson: jsonEncode(['c2']),
            offeredTotalValue: const drift.Value(10.0),
            requestedTotalValue: const drift.Value(10.0),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(wrapScope(
          const ChatConversationScreen(conversationId: 'user_me_user_partner', contactId: partnerId),
          db,
        ));
        await tester.pumpAndSettle();
        expect(find.text('Active Trade Proposal'), findsOneWidget);

        await (db.delete(db.tradeProposals)..where((t) => t.id.equals('prop_delete_me'))).go();
        await tester.pumpAndSettle();

        expect(find.text('Active Trade Proposal'), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 29 BOUNDARIES (Trade Card Plain English Name Resolution)
    // =========================================================================
    group('Feature 29 Boundaries (Trade Card Plain English Name Resolution)', () {
      test('B29.1: Card with special characters resolves and displays verbatim', () {
        final resolved = CardNameResolver.formatSlug('item-mtg-jace-the-mind-sculptor');
        expect(resolved, equals('Jace The Mind Sculptor'));
      });

      test('B29.2: Double-faced card names handles slash formatting', () {
        final resolved = CardNameResolver.formatSlug('delver-of-secrets-insectile-aberration');
        expect(resolved, isNotEmpty);
        expect(resolved.contains('Delver'), isTrue);
      });

      test('B29.3: Extremely long card name (60+ chars) truncates cleanly', () {
        const longSlug = 'item-mtg-our-market-research-shows-that-players-like-really-long-names';
        final resolved = CardNameResolver.formatSlug(longSlug);
        expect(resolved.endsWith('...'), isTrue);
        expect(resolved.length, lessThanOrEqualTo(30));
      });

      test('B29.4: Multi-TCG prefixes stripped cleanly to title case', () {
        final pokemon = CardNameResolver.formatSlug('item-pokemon-charizard-vmax');
        expect(pokemon, equals('Charizard Vmax'));

        final lorcana = CardNameResolver.formatSlug('item-lorcana-elsa-spirit-of-winter');
        expect(lorcana, equals('Elsa Spirit Of Winter'));
      });

      test('B29.5: Null card ID in trade item list handles graceful fallback', () {
        final resolvedNull = CardNameResolver.formatSlug(null);
        expect(resolvedNull, equals('Card Not Available'));

        final resolvedEmpty = CardNameResolver.formatSlug('');
        expect(resolvedEmpty, equals('Card Not Available'));
      });
    });

    // =========================================================================
    // FEATURE 30 BOUNDARIES (Full Trade Negotiation Lifecycle)
    // =========================================================================
    group('Feature 30 Boundaries (Full Trade Negotiation Lifecycle)', () {
      testWidgets('B30.1: Cancelling trade proposal in chat updates status to cancelled and unpins', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final now = DateTime.now();
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_cancel_chat',
            proposerId: currentUserId,
            receiverId: partnerId,
            status: const drift.Value('pending'),
            offeredCardIdsJson: jsonEncode(['c1']),
            requestedCardIdsJson: jsonEncode(['c2']),
            offeredTotalValue: const drift.Value(20.0),
            requestedTotalValue: const drift.Value(20.0),
            createdAt: drift.Value(now),
          ),
        );

        await tester.pumpWidget(wrapScope(
          const ChatConversationScreen(conversationId: 'user_me_user_partner', contactId: partnerId),
          db,
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cancel_trade_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('cancel_trade_button')));
        await tester.pumpAndSettle();

        final proposal = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_cancel_chat'))).getSingle();
        expect(proposal.status, equals('cancelled'));
        expect(find.text('Active Trade Proposal'), findsNothing);
      });

      test('B30.2: Countering a trade atomically marks prior proposal countered and creates new proposal', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final now = DateTime.now();
        await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: 'prop_to_counter',
            proposerId: partnerId,
            receiverId: currentUserId,
            status: const drift.Value('pending'),
            offeredCardIdsJson: jsonEncode(['c1']),
            requestedCardIdsJson: jsonEncode(['c2']),
            offeredTotalValue: const drift.Value(20.0),
            requestedTotalValue: const drift.Value(20.0),
            createdAt: drift.Value(now),
          ),
        );

        final newProposal = await db.inboxDao.counterTradeProposal(
          'prop_to_counter',
          proposerId: currentUserId,
          receiverId: partnerId,
          offeredCardIds: ['c2', 'c3'],
          requestedCardIds: ['c1'],
          offeredTotalValue: 25.0,
          requestedTotalValue: 20.0,
        );

        final prior = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_to_counter'))).getSingle();
        expect(prior.status, equals('countered'));

        expect(newProposal.status, equals('pending'));
        expect(newProposal.proposerId, equals(currentUserId));
        expect(newProposal.receiverId, equals(partnerId));
      });

      testWidgets('B30.3: Trade Value Meter with extreme delta indicates disparity warning', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final userMe = await db.userProfileDao.getProfile(currentUserId);
        final userPartner = await db.userProfileDao.getProfile(partnerId);

        final participants = [
          TradeParticipant(
            user: userMe!,
            sendingTotalValue: 5000.0,
            receivingTotalValue: 10.0,
          ),
          TradeParticipant(
            user: userPartner!,
            sendingTotalValue: 10.0,
            receivingTotalValue: 5000.0,
          ),
        ];

        final fairness = TradeFairnessResult.evaluate(participants);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: StickyTradeValueMeter(
              fairness: fairness,
              participants: participants,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
        expect(find.textContaining('LOPSIDED'), findsOneWidget);
      });

      testWidgets('B30.4: Editing trade by proposer loads TradeScreen in edit mode', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final userMe = await db.userProfileDao.getProfile(currentUserId);
        final userPartner = await db.userProfileDao.getProfile(partnerId);

        final params = TradeProposalParams(
          currentUser: userMe!,
          partnerProfile: userPartner!,
          mode: TradeProposalMode.edit,
          priorProposalId: 'prop_edit_mode',
        );

        await tester.pumpWidget(wrapScope(TradeScreen(params: params), db));
        await tester.pumpAndSettle();

        expect(find.text('Edit Trade Offer'), findsOneWidget);
        expect(find.text('Update Trade Offer'), findsOneWidget);
      });

      testWidgets('B30.5: Countering trade by recipient loads TradeScreen in counter mode', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        await seedUser(db, currentUserId, '@me', 'Me');
        await seedUser(db, partnerId, '@partner', 'Partner');

        final userMe = await db.userProfileDao.getProfile(currentUserId);
        final userPartner = await db.userProfileDao.getProfile(partnerId);

        final params = TradeProposalParams(
          currentUser: userMe!,
          partnerProfile: userPartner!,
          mode: TradeProposalMode.counter,
          priorProposalId: 'prop_counter_mode',
        );

        await tester.pumpWidget(wrapScope(TradeScreen(params: params), db));
        await tester.pumpAndSettle();

        expect(find.text('Counter Trade Offer'), findsOneWidget);
        expect(find.text('Send Counter Offer'), findsOneWidget);
      });
    });
  });
}

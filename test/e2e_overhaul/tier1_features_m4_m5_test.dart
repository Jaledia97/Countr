import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/router/app_router.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/screens/onboarding_welcome_screen.dart';
import 'package:countr/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/card_details_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

void main() {
  group('Tier 1: Feature Coverage — Milestone 4 & 5 (Features 17 to 24)', () {

    // =========================================================================
    // FEATURE 17: Log Out Feature
    // =========================================================================
    group('Feature 17: Log Out Feature', () {
      late AppDatabase db;
      late MockAuthRepository mockAuthRepo;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        await db.userProfileDao.seedDefaultProfiles();
        await (db.update(db.userProfiles)).write(
          const UserProfilesCompanion(avatarUrl: drift.Value(null)),
        );
        mockAuthRepo = MockAuthRepository();
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('F17.1: Log Out button is accessible in Command Center', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: MorphingCommandCenter(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final logoutBtnFinder = find.byKey(const Key('command_center_logout_button'));
        await tester.scrollUntilVisible(logoutBtnFinder, 300);

        expect(logoutBtnFinder, findsOneWidget);
        expect(find.text('Log Out'), findsWidgets);
        final button = tester.widget<ElevatedButton>(logoutBtnFinder);
        expect(button.enabled, isTrue);
      });

      testWidgets('F17.2: Log Out button is accessible in Profile/Account Settings', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: AppSettingsDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final logoutBtnFinder = find.byKey(const Key('app_settings_logout_button'));
        await tester.scrollUntilVisible(
          logoutBtnFinder,
          100,
          scrollable: find.byType(Scrollable).first,
        );

        expect(logoutBtnFinder, findsOneWidget);
        expect(find.text('Log Out'), findsWidgets);
        final button = tester.widget<ElevatedButton>(logoutBtnFinder);
        expect(button.enabled, isTrue);
      });

      testWidgets('F17.3: Tapping Log Out displays confirmation prompt dialog', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: MorphingCommandCenter(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final logoutBtnFinder = find.byKey(const Key('command_center_logout_button'));
        await tester.scrollUntilVisible(logoutBtnFinder, 300);

        await tester.tap(logoutBtnFinder);
        await tester.pumpAndSettle();

        expect(find.byType(LogoutConfirmationDialog), findsOneWidget);
        expect(find.byKey(const Key('logout_keep_guest_data_checkbox')), findsOneWidget);
        expect(find.byKey(const Key('logout_confirm_button')), findsOneWidget);
        expect(find.byKey(const Key('logout_cancel_button')), findsOneWidget);
      });

      testWidgets('F17.4: Confirmation dialog offers choice to keep guest data vs reset state', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: LogoutConfirmationDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxFinder = find.byKey(const Key('logout_keep_guest_data_checkbox'));
        expect(checkboxFinder, findsOneWidget);
        expect(find.text('Keep local guest cards & decks'), findsOneWidget);
        expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isTrue);

        // Toggle checkbox state off
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isFalse);

        // Toggle checkbox state back on
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isTrue);

        expect(find.byKey(const Key('logout_cancel_button')), findsOneWidget);
        expect(find.byKey(const Key('logout_confirm_button')), findsOneWidget);
      });

      testWidgets('F17.5: Confirming sign out clears session and routes to welcome screen', (tester) async {
        final regUser = AuthUser(
          id: 'user_reg_active_100',
          displayName: 'Active Collector',
          username: '@collector_active',
          provider: AuthProviderType.discord,
          tier: AccountTier.pro,
          isGuest: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        late ProviderContainer container;
        addTearDown(() => appRouter.go('/feed'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
              currentUserProvider.overrideWith((ref) => CurrentUserNotifier(mockAuthRepo)..setUser(regUser)),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp.router(
                  routerConfig: appRouter,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify active authenticated session
        expect(container.read(currentUserProvider).isGuest, isFalse);
        expect(container.read(isUserLoggedInProvider), isTrue);

        // Open genuine LogoutConfirmationDialog
        final rootContext = rootNavigatorKey.currentContext!;
        LogoutConfirmationDialog.show(rootContext);
        await tester.pumpAndSettle();

        expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

        // Confirm logout
        await tester.tap(find.byKey(const Key('logout_confirm_button')));
        await tester.pumpAndSettle();

        // Session reset verification: user is now guest
        expect(container.read(currentUserProvider).isGuest, isTrue);
        expect(container.read(isUserLoggedInProvider), isFalse);

        // Routing verification: navigated to /welcome mounting OnboardingWelcomeScreen
        expect(find.byType(OnboardingWelcomeScreen), findsOneWidget);
        expect(find.byKey(const Key('onboarding_welcome_screen')), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 18: Complete 3-Step Onboarding Workflow
    // =========================================================================
    group('Feature 18: Complete 3-Step Onboarding Workflow', () {
      late AppDatabase db;
      late MockAuthRepository mockAuthRepo;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        await db.userProfileDao.seedDefaultProfiles();
        await (db.update(db.userProfiles)).write(
          const UserProfilesCompanion(avatarUrl: drift.Value(null)),
        );
        mockAuthRepo = MockAuthRepository();
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('F18.1: Step 1 presents Account Type selection options', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(initialStep: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('onboarding_welcome_screen')), findsOneWidget);
        expect(find.byKey(const Key('onboarding_account_type_individual')), findsOneWidget);
        expect(find.byKey(const Key('onboarding_account_type_business')), findsOneWidget);
        expect(find.byKey(const Key('onboarding_continue_as_guest')), findsOneWidget);
        expect(find.text('Individual Player / Collector'), findsOneWidget);
        expect(find.text('Business / Local Game Store'), findsOneWidget);
        expect(find.textContaining('Continue as Guest'), findsOneWidget);
      });

      testWidgets('F18.2: Step 2 Individual features Discord as primary CTA with #5865F2 branding', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(initialStep: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 2 Individual
        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        final discordCtaFinder = find.byKey(const Key('onboarding_discord_cta_button'));
        expect(discordCtaFinder, findsOneWidget);
        expect(find.text('Continue with Discord'), findsOneWidget);

        final buttonWidget = tester.widget<ElevatedButton>(discordCtaFinder);
        expect(buttonWidget.style?.backgroundColor?.resolve({}), equals(const Color(0xFF5865F2)));

        // Secondary provider buttons
        expect(find.byKey(const Key('onboarding_auth_google')), findsOneWidget);
        expect(find.byKey(const Key('onboarding_auth_apple')), findsOneWidget);
        expect(find.byKey(const Key('onboarding_auth_facebook')), findsOneWidget);
      });

      testWidgets('F18.3: Step 2 Individual setup gathers display name, username, avatar, and commander', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(initialStep: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 -> Individual
        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        // Tap Discord CTA to authenticate and display Profile Setup
        await tester.tap(find.byKey(const Key('onboarding_auth_discord')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_setup_display_name_input')), findsOneWidget);
        expect(find.byKey(const Key('profile_setup_username_input')), findsOneWidget);
        expect(find.byKey(const Key('profile_setup_avatar_picker')), findsOneWidget);
        expect(find.byKey(const Key('profile_setup_favorite_format_picker')), findsOneWidget);
        expect(find.byKey(const Key('profile_setup_submit_button')), findsOneWidget);

        await tester.enterText(find.byKey(const Key('profile_setup_display_name_input')), 'Commander Player');
        await tester.enterText(find.byKey(const Key('profile_setup_username_input')), '@commander_play');

        await tester.ensureVisible(find.byKey(const Key('profile_setup_submit_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_setup_submit_button')));
        await tester.pumpAndSettle();

        // Step 3 reached
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
      });

      testWidgets('F18.4: Step 2 Business/LGS features Places lookup and 6-digit OTP', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
            ],
            child: const MaterialApp(
              home: OnboardingWelcomeScreen(initialStep: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select Business
        await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('business_store_lookup_input')), findsOneWidget);
        expect(find.byKey(const Key('business_otp_input')), findsOneWidget);
        expect(find.byKey(const Key('business_verify_otp_button')), findsOneWidget);

        // Fill store details
        await tester.enterText(find.byKey(const Key('business_store_lookup_input')), 'TBS Comics');
        await tester.enterText(find.byKey(const Key('business_store_address_input')), '68 SW Eglin Pkwy, Fort Walton Beach, FL');
        await tester.enterText(find.byKey(const Key('business_store_phone_input')), '(850) 244-4445');
        await tester.enterText(find.byKey(const Key('business_store_website_input')), 'https://tbscomics.com');

        await tester.ensureVisible(find.byKey(const Key('business_verify_otp_button')));
        await tester.pumpAndSettle();

        // Enter 6-digit OTP
        await tester.enterText(find.byKey(const Key('business_otp_input')), '123456');
        await tester.ensureVisible(find.byKey(const Key('business_verify_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('business_verify_otp_button')));
        await tester.pumpAndSettle();

        // Verification success: Step 3 reached with verified badge
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
        expect(find.textContaining('LGS Store Verified!'), findsOneWidget);
      });

      test('F18.5: Step 3 transitions to shell with guest-to-registered data merge', () async {
        final now = DateTime.now();
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

        // 1. Seed genuine guest data in Drift SQLite
        await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
              id: 'v_guest_sol_ring',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'C21',
              imageUrl: '',
              acquiredPrice: 2.50,
              acquiredDate: now,
              condition: 'NM',
              currentMarketPrice: 2.50,
              lastPriceUpdate: now,
              dynamicData: '{}',
              userId: const drift.Value('guest'),
            ));
        await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
              id: 'b_guest_edh',
              name: 'Guest EDH Binder',
              collectionType: 'mtg',
              createdAt: now,
              userId: const drift.Value('guest'),
              isSystemBinder: const drift.Value(false),
            ));
        await db.into(db.decks).insert(DecksCompanion.insert(
              id: 'd_guest_deck',
              name: 'Guest Deck',
              format: 'Commander',
              createdAt: now,
              userId: const drift.Value('guest'),
            ));

        // 2. Perform genuine migration via GuestMigrationService
        final service = container.read(guestMigrationServiceProvider);
        const registeredUserId = 'user_reg_100';
        final summary = await service.migrateGuestData(
          registeredUserId: registeredUserId,
          isBusiness: false,
        );

        expect(summary.isSuccess, isTrue);
        expect(summary.migratedVaultItems, equals(1));
        expect(summary.migratedBinders, equals(1));
        expect(summary.migratedDecks, equals(1));

        // 3. Empirically verify SQLite mutations in Drift
        final migratedItems = await (db.select(db.vaultItems)..where((t) => t.userId.equals(registeredUserId))).get();
        expect(migratedItems.length, equals(1));
        expect(migratedItems.first.name, equals('Sol Ring'));

        final remainingGuestItems = await (db.select(db.vaultItems)..where((t) => t.userId.equals('guest'))).get();
        expect(remainingGuestItems, isEmpty);

        final migratedBinders = await (db.select(db.vaultBinders)..where((t) => t.userId.equals(registeredUserId) & t.isSystemBinder.equals(false))).get();
        expect(migratedBinders.length, equals(1));
        expect(migratedBinders.first.name, equals('Guest EDH Binder'));

        final remainingGuestBinders = await (db.select(db.vaultBinders)..where((t) => t.userId.equals('guest') & t.isSystemBinder.equals(false))).get();
        expect(remainingGuestBinders, isEmpty);
      });
    });

    // =========================================================================
    // FEATURE 19: Unified Card Details Resolution
    // =========================================================================
    group('Feature 19: Unified Card Details Resolution', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        // Seed test catalog and owned items
        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card_bl',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'LEA',
            imageUrl: 'https://cards.scryfall.io/large/front/b/l.jpg',
            acquiredPrice: 25000.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'scryfall_id': 'scryfall_bl_1',
              'oracle_id': 'oracle_bl_1',
              'mana_cost': '{0}',
              'type_line': 'Artifact',
              'oracle_text': '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
              'prices': {'usd': '25000.00'},
            }),
          ),
        );

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card_tor',
            collectionType: 'mtg',
            name: 'The One Ring',
            setOrSeries: 'LTR',
            imageUrl: 'https://cards.scryfall.io/large/front/t/o/tor.jpg',
            acquiredPrice: 65.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 65.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'scryfall_id': 'scryfall_tor_2',
              'oracle_id': 'oracle_tor_2',
              'mana_cost': '{4}',
              'type_line': 'Legendary Artifact',
              'oracle_text': 'Indestructible. At the beginning of your upkeep, you lose 1 life.',
              'prices': {'usd': '65.00'},
            }),
          ),
        );

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item_owned_sol_ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'C21',
            imageUrl: 'https://cards.scryfall.io/sol.jpg',
            acquiredPrice: 1.5,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'scryfall_id': 'scryfall_sol_1',
              'type_line': 'Artifact',
              'oracle_text': '{T}: Add {C}{C}.',
              'prices': {'usd': '2.00'},
            }),
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('F19.1: Resolves cards by direct ID (cards.id) and renders in CardDetailsScreen', (tester) async {
        final resolved = await dao.findCatalogCard(identifier: 'card_bl');
        expect(resolved, isNotNull);
        expect(resolved!.name, equals('Black Lotus'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CardDetailsScreen(cardId: 'card_bl'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CardDetailsScreen), findsOneWidget);
        expect(find.text('Black Lotus'), findsWidgets);
        expect(find.byKey(const Key('card_detail_error_tile')), findsNothing);
      });

      testWidgets('F19.2: Resolves cards by Scryfall UUID (scryfall_id) and renders in CardDetailsScreen', (tester) async {
        final resolved = await dao.findCatalogCard(identifier: 'scryfall_tor_2');
        expect(resolved, isNotNull);
        expect(resolved!.name, equals('The One Ring'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CardDetailsScreen(cardId: 'scryfall_tor_2'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('The One Ring'), findsWidgets);
        expect(find.byKey(const Key('card_detail_error_tile')), findsNothing);
      });

      testWidgets('F19.3: Resolves cards by collection item ID and renders owned copy', (tester) async {
        final resolved = await dao.findCatalogCard(identifier: 'item_owned_sol_ring');
        expect(resolved, isNotNull);
        expect(resolved!.id, equals('item_owned_sol_ring'));
        expect(resolved.name, equals('Sol Ring'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CardDetailsScreen(cardId: 'item_owned_sol_ring'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Sol Ring'), findsWidgets);
        expect(find.text('1x'), findsWidgets);
      });

      testWidgets('F19.4: Strips legacy slug prefix item-mtg-... and matches Title Case in CardDetailsScreen', (tester) async {
        final resolved = await dao.findCatalogCard(identifier: 'item-mtg-black-lotus');
        expect(resolved, isNotNull);
        expect(resolved!.name, equals('Black Lotus'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CardDetailsScreen(cardId: 'item-mtg-black-lotus'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Black Lotus'), findsWidgets);
        expect(find.byKey(const Key('card_detail_error_tile')), findsNothing);
      });

      testWidgets('F19.5: Zero blank screens: returns complete card details (oracle, mana, type, prices)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: CardDetailsScreen(cardId: 'card_bl'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Black Lotus'), findsWidgets);
        expect(find.textContaining('Sacrifice Black Lotus'), findsWidgets);
        expect(find.text('Artifact'), findsWidgets);
        expect(find.textContaining(r'$25000'), findsWidgets);
        expect(find.byKey(const Key('card_detail_error_tile')), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 20: Vault Singles Header Spacing Fix
    // =========================================================================
    group('Feature 20: Vault Singles Header Spacing Fix', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'v_sol',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'STH',
            imageUrl: 'https://cards.scryfall.io/sol.jpg',
            acquiredPrice: 2.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('F20.1: When Estimated Vault Value is shown, header renders normal height in genuine VaultScreen', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
              vaultShowEstimatedValueProvider.overrideWith((ref) => true),
            ],
            child: const MaterialApp(
              home: VaultScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('vault_value_header')), findsOneWidget);
        expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);
      });

      testWidgets('F20.2: When Estimated Vault Value is hidden, collapse header delegate to 0dp extent', (tester) async {
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
              home: VaultScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('vault_value_header')), findsNothing);
        expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);
      });

      testWidgets('F20.3: When Estimated Vault Value is hidden, remove hardcoded empty SizedBox padding', (tester) async {
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
              home: VaultScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('vault_value_header')), findsNothing);
        expect(find.byKey(const Key('vault_singles_search_bar')), findsOneWidget);
      });

      testWidgets('F20.4: Search and filter bar sits flush at the very top of Vault Singles body with zero dead space', (tester) async {
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
              home: VaultScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
        final searchBarTop = tester.getTopLeft(find.byKey(const Key('vault_singles_search_bar'))).dy;
        final deadSpace = searchBarTop - appBarBottom;
        expect(deadSpace, equals(0.0), reason: 'Search bar must sit flush below AppBar with 0dp dead space');
      });

      testWidgets('F20.5: Toggling visibility updates layout dynamically between expanded and flush modes', (tester) async {
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
            child: const MaterialApp(
              home: VaultScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Expanded mode
        expect(find.byKey(const Key('vault_value_header')), findsOneWidget);

        // Toggle to collapsed
        container.read(vaultShowEstimatedValueProvider.notifier).state = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('vault_value_header')), findsNothing);

        // Toggle back to expanded
        container.read(vaultShowEstimatedValueProvider.notifier).state = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('vault_value_header')), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 21: Vault Singles Live Search
    // =========================================================================
    group('Feature 21: Vault Singles Live Search', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        Future<void> insertCard({
          required String id,
          required String name,
          required String typeLine,
          required String oracleText,
        }) async {
          await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: id,
              collectionType: 'mtg',
              name: name,
              setOrSeries: 'TEST',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'type_line': typeLine,
                'oracle_text': oracleText,
              }),
            ),
          );
        }

        await insertCard(
          id: 'c1',
          name: 'Sol Ring',
          typeLine: 'Artifact',
          oracleText: '{T}: Add {C}{C}.',
        );
        await insertCard(
          id: 'c2',
          name: 'Counterspell',
          typeLine: 'Instant',
          oracleText: 'Counter target spell.',
        );
        await insertCard(
          id: 'c3',
          name: 'Lightning Bolt',
          typeLine: 'Instant',
          oracleText: 'Deal 3 damage to any target.',
        );
        await insertCard(
          id: 'c4',
          name: 'Birds of Paradise',
          typeLine: 'Creature - Bird',
          oracleText: 'Flying. {T}: Add one mana of any color.',
        );
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('F21.1: Live search filters owned singles by card name in SQLite and VaultScreen', (tester) async {
        final res = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'Sol Ring');
        expect(res.length, equals(1));
        expect(res.first.name, equals('Sol Ring'));

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
        await tester.enterText(textField.first, 'Sol Ring');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Sol Ring'), findsWidgets);
        expect(find.text('Counterspell'), findsNothing);
        expect(find.text('Lightning Bolt'), findsNothing);
      });

      testWidgets('F21.2: Live search filters owned singles by card type_line', (tester) async {
        final res = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'Instant');
        expect(res.length, equals(2));
        final names = res.map((c) => c.name).toList();
        expect(names, containsAll(['Counterspell', 'Lightning Bolt']));
      });

      testWidgets('F21.3: Live search filters owned singles by oracle_text', (tester) async {
        final res = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'damage to any target');
        expect(res.length, equals(1));
        expect(res.first.name, equals('Lightning Bolt'));
      });

      testWidgets('F21.4: Search query matches case-insensitively and handles whitespace trimming', (tester) async {
        final res = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: '   bIrDs   ');
        expect(res.length, equals(1));
        expect(res.first.name, equals('Birds of Paradise'));
      });

      testWidgets('F21.5: Clearing search input restores full unfiltered vault item list immediately', (tester) async {
        final filtered = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'Bolt');
        expect(filtered.length, equals(1));

        final cleared = await dao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: '');
        expect(cleared.length, equals(4));
      });
    });

    // =========================================================================
    // FEATURE 22: Vault Collections Set Completion Ratio
    // =========================================================================
    group('Feature 22: Vault Collections Set Completion Ratio', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        // Insert 10 distinct cards for set LTR (7 unowned quantity: 0, 3 owned quantity: 1)
        for (int i = 1; i <= 10; i++) {
          await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'ltr_card_$i',
              collectionType: 'mtg',
              name: 'LTR Card $i',
              setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: drift.Value(i <= 3 ? 1 : 0),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'ltr',
                'collector_number': '$i',
              }),
            ),
          );
        }
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('F22.1: Completion percentage calculates distinct owned / master catalog set total', (tester) async {
        final collections = await dao.watchSetCollections(collectionType: 'mtg').first;
        expect(collections.length, equals(1));
        final ltr = collections.first;

        expect(ltr.totalCount, equals(10));
        expect(ltr.ownedCount, equals(3));
        expect(ltr.completionPercentage, closeTo(0.30, 0.001));
      });

      testWidgets('F22.2: Partial set ownership (5/10) yields exactly 50.0% completion', (tester) async {
        await (dao.update(dao.vaultItems)..where((t) => t.id.isIn(['ltr_card_4', 'ltr_card_5']))).write(
          const VaultItemsCompanion(quantity: drift.Value(1)),
        );

        final collections = await dao.watchSetCollections(collectionType: 'mtg').first;
        final ltr = collections.first;

        expect(ltr.totalCount, equals(10));
        expect(ltr.ownedCount, equals(5));
        expect(ltr.completionPercentage, closeTo(0.50, 0.001));
      });

      testWidgets('F22.3: Owning duplicate copies of same card does NOT increase completion count', (tester) async {
        await (dao.update(dao.vaultItems)).write(const VaultItemsCompanion(quantity: drift.Value(0)));
        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('ltr_card_1'))).write(
          const VaultItemsCompanion(quantity: drift.Value(4)),
        );

        final collections = await dao.watchSetCollections(collectionType: 'mtg').first;
        final ltr = collections.first;

        expect(ltr.totalCount, equals(10));
        expect(ltr.ownedCount, equals(1));
        expect(ltr.completionPercentage, closeTo(0.10, 0.001));
      });

      testWidgets('F22.4: Empty ownership yields 0.0% completion without division by zero', (tester) async {
        await (dao.update(dao.vaultItems)).write(const VaultItemsCompanion(quantity: drift.Value(0)));

        final collections = await dao.watchSetCollections(collectionType: 'mtg').first;
        final ltr = collections.first;

        expect(ltr.totalCount, equals(10));
        expect(ltr.ownedCount, equals(0));
        expect(ltr.completionPercentage, equals(0.0));
      });

      testWidgets('F22.5: Never divides owned by owned (which would falsely produce 100%)', (tester) async {
        await (dao.update(dao.vaultItems)).write(const VaultItemsCompanion(quantity: drift.Value(0)));
        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('ltr_card_1'))).write(
          const VaultItemsCompanion(quantity: drift.Value(1)),
        );

        final collections = await dao.watchSetCollections(collectionType: 'mtg').first;
        final ltr = collections.first;

        expect(ltr.completionPercentage, isNot(equals(1.0)));
        expect(ltr.completionPercentage, closeTo(0.10, 0.001));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: MaterialApp(
              home: MasterSetScreen(
                collection: ltr,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 / 10'), findsOneWidget);
        expect(find.text('10.0% complete'), findsOneWidget);
        expect(find.text('100.0% complete'), findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 23: 3x3 Master Set View
    // =========================================================================
    group('Feature 23: 3x3 Master Set View', () {
      late AppDatabase db;
      late VaultDao dao;
      late VaultSetCollection testCollection;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'zen_forest',
            collectionType: 'mtg',
            name: 'Forest',
            setOrSeries: 'Zendikar',
            imageUrl: '',
            acquiredPrice: 0.5,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(2), // x2 copies owned
            condition: 'NM',
            currentMarketPrice: 0.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'set_code': 'zen', 'collector_number': '1'}),
          ),
        );

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'zen_island',
            collectionType: 'mtg',
            name: 'Island',
            setOrSeries: 'Zendikar',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0), // Unowned
            condition: 'NM',
            currentMarketPrice: 0.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'set_code': 'zen', 'collector_number': '2'}),
          ),
        );

        testCollection = const VaultSetCollection(
          setName: 'Zendikar',
          setCode: 'ZEN',
          collectionType: 'Magic: The Gathering',
          totalCount: 2,
          ownedCount: 1,
          completionPercentage: 0.5,
        );
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('F23.1: Master Set screen displays cards in 3-column grid (crossAxisCount: 3)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: MaterialApp(
              home: MasterSetScreen(
                collection: testCollection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gridFinder = find.byKey(const Key('master_set_grid'));
        expect(gridFinder, findsOneWidget);

        final sliverGrid = tester.widget<SliverGrid>(gridFinder);
        final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(3));
      });

      testWidgets('F23.2: Owned cards render in full color art without grayscale filter', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: MaterialApp(
              home: MasterSetScreen(
                collection: testCollection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_owned_card')), findsOneWidget);
        expect(find.byKey(const Key('master_set_grayscale_zen_forest')), findsNothing);
      });

      testWidgets('F23.3: Owned cards render quantity badge (e.g. x2)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: MaterialApp(
              home: MasterSetScreen(
                collection: testCollection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_quantity_badge')), findsOneWidget);
        expect(find.text('x2'), findsOneWidget);
      });

      testWidgets('F23.4: Unowned cards render in true grayscale ColorFiltered matrix', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: MaterialApp(
              home: MasterSetScreen(
                collection: testCollection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final grayscaleFinder = find.byKey(const Key('master_set_grayscale_zen_island'));
        expect(grayscaleFinder, findsOneWidget);

        final colorFiltered = tester.widget<ColorFiltered>(grayscaleFinder);
        expect(colorFiltered.colorFilter, equals(vaultGrayscaleColorFilter));
      });

      testWidgets('F23.5: Unowned cards have dimmed opacity (0.55)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: MaterialApp(
              home: MasterSetScreen(
                collection: testCollection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final opacityFinder = find.byKey(const Key('unowned_card_dimmed_opacity'));
        expect(opacityFinder, findsOneWidget);
        final opacityWidget = tester.widget<Opacity>(opacityFinder);
        expect(opacityWidget.opacity, equals(0.55));
      });
    });

    // =========================================================================
    // FEATURE 24: Wishlist Badge & Filter in Vault/Binders
    // =========================================================================
    group('Feature 24: Wishlist Badge & Filter in Vault/Binders', () {
      late AppDatabase db;
      late VaultDao dao;

      setUp(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        db = AppDatabase(NativeDatabase.memory());
        dao = db.vaultDao;
        await dao.clearAllItems();

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card_ragavan',
            collectionType: 'mtg',
            name: 'Ragavan, Nimble Pilferer',
            setOrSeries: 'MH2',
            imageUrl: '',
            acquiredPrice: 50.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            isWishlisted: const drift.Value(true), // Wishlisted!
            currentMarketPrice: 55.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );

        await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card_sol_ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'C21',
            imageUrl: '',
            acquiredPrice: 2.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            isWishlisted: const drift.Value(false), // NOT wishlisted
            currentMarketPrice: 2.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('F24.1: Cards added via wishlist carry isWishlisted: true persisted in SQLite', () async {
        final item = await dao.getItemById('card_ragavan');
        expect(item, isNotNull);
        expect(item!.isWishlisted, isTrue);

        final nonWishlist = await dao.getItemById('card_sol_ring');
        expect(nonWishlist, isNotNull);
        expect(nonWishlist!.isWishlisted, isFalse);
      });

      testWidgets('F24.2: Wishlisted cards display dedicated Wishlist Badge in Vault', (tester) async {
        final item = (await dao.getItemById('card_ragavan'))!;

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

        expect(find.byKey(const Key('vault_card_wishlist_badge')), findsOneWidget);
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
      });

      testWidgets('F24.3: Vault filter pill row contains Wishlisted filter pill', (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(dao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
              vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            ],
            child: const MaterialApp(
              home: VaultScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final wishlistChipFinder = find.byKey(const Key('vault_filter_wishlisted_chip'));
        expect(wishlistChipFinder, findsWidgets);
        expect(find.text('Wishlisted'), findsWidgets);
      });

      testWidgets('F24.4: Activating Wishlisted filter displays only cards with isWishlisted: true', (tester) async {
        final wishlistedOnly = await dao.getItemsByCollection('mtg', onlyWishlisted: true);
        expect(wishlistedOnly.length, equals(1));
        expect(wishlistedOnly.first.name, equals('Ragavan, Nimble Pilferer'));

        final allCards = await dao.getItemsByCollection('mtg');
        expect(allCards.length, equals(2));
      });

      testWidgets('F24.5: De-wishlisting card removes card from Wishlisted filtered view', (tester) async {
        var wishlisted = await dao.getItemsByCollection('mtg', onlyWishlisted: true);
        expect(wishlisted.length, equals(1));

        await (dao.update(dao.vaultItems)..where((t) => t.id.equals('card_ragavan'))).write(
          const VaultItemsCompanion(isWishlisted: drift.Value(false)),
        );

        wishlisted = await dao.getItemsByCollection('mtg', onlyWishlisted: true);
        expect(wishlisted, isEmpty);
      });
    });
  });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/router/app_router.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:countr/features/auth/presentation/screens/onboarding_welcome_screen.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';

/// Test Auth Repository that extends MockAuthRepository to support latency and failure injection.
class AdversarialMockAuthRepository extends MockAuthRepository {
  int signOutCallCount = 0;
  Duration signOutDelay = Duration.zero;
  bool shouldFailSignOut = false;

  AdversarialMockAuthRepository({super.initialUser});

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    if (signOutDelay > Duration.zero) {
      await Future.delayed(signOutDelay);
    }
    if (shouldFailSignOut) {
      throw const SocketException('Simulated network unreachable (DNS resolution failed)');
    }
    await super.signOut();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late AdversarialMockAuthRepository mockAuthRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    await (db.update(db.userProfiles)).write(
      const UserProfilesCompanion(avatarUrl: drift.Value(null)),
    );
    mockAuthRepo = AdversarialMockAuthRepository();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItemsCompanion createTestCard({
    required String id,
    required String name,
    required String userId,
    String primaryBinderId = '',
  }) {
    final now = DateTime.now();
    return VaultItemsCompanion.insert(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'M20',
      imageUrl: '',
      acquiredPrice: 10.0,
      acquiredDate: now,
      condition: 'NM',
      currentMarketPrice: 10.0,
      lastPriceUpdate: now,
      dynamicData: '{}',
      userId: drift.Value(userId),
      primaryBinderId: drift.Value(primaryBinderId),
    );
  }

  Widget wrapWithTestScope({
    required Widget child,
    AuthUser? user,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        if (user != null)
          currentUserProvider.overrideWith((ref) => CurrentUserNotifier(mockAuthRepo)..setUser(user)),
        ...extraOverrides,
      ],
      child: MaterialApp(
        routes: {
          '/welcome': (context) => const Scaffold(
                body: Text('Welcome Screen', key: Key('mock_welcome_route')),
              ),
        },
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Milestone 4 Adversarial Verification — Feature 17 Log Out', () {
    // =========================================================================
    // B17.1: Double-tap debounce & re-entrance protection
    // =========================================================================
    testWidgets('B17.1: Rapid multi-tap on confirm logout triggers exactly ONE signOut operation', (tester) async {
      mockAuthRepo.signOutDelay = const Duration(milliseconds: 300);

      await tester.pumpWidget(
        wrapWithTestScope(
          child: const LogoutConfirmationDialog(),
          user: AuthUser.guest(),
        ),
      );
      await tester.pumpAndSettle();

      final confirmFinder = find.byKey(const Key('logout_confirm_button'));
      expect(confirmFinder, findsOneWidget);

      // Fire 5 rapid taps sequentially without waiting for async delay
      await tester.tap(confirmFinder);
      await tester.tap(confirmFinder);
      await tester.tap(confirmFinder);
      await tester.tap(confirmFinder);
      await tester.tap(confirmFinder);

      // Pump 1 frame to inspect in-flight debounce UI state
      await tester.pump(const Duration(milliseconds: 50));

      // CircularProgressIndicator should be active inside the confirm button
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Cancel button should be disabled (onPressed is null)
      final cancelButton = tester.widget<TextButton>(find.byKey(const Key('logout_cancel_button')));
      expect(cancelButton.onPressed, isNull);

      // Checkbox should be disabled (onChanged is null)
      final checkbox = tester.widget<CheckboxListTile>(find.byKey(const Key('logout_keep_guest_data_checkbox')));
      expect(checkbox.onChanged, isNull);

      // Complete async sign out delay
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Verify empirical assertion: signOut was called exactly once!
      expect(mockAuthRepo.signOutCallCount, equals(1));
    });

    // =========================================================================
    // B17.2: Contextual prompt (guest vs registered vs business)
    // =========================================================================
    testWidgets('B17.2: Guest prompt explicitly contains Guest clarification and retention guidance', (tester) async {
      await tester.pumpWidget(
        wrapWithTestScope(
          child: const LogoutConfirmationDialog(),
          user: AuthUser.guest(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You are browsing as Guest. Local cards can be preserved.'), findsOneWidget);
      expect(find.textContaining('Guest'), findsWidgets);
      expect(find.text('Are you sure you want to log out?'), findsNothing);
    });

    testWidgets('B17.2: Registered user prompt displays standard confirmation without guest string', (tester) async {
      final regUser = AuthUser(
        id: 'user_reg_adversary_1',
        displayName: 'Registered Pro',
        username: '@pro_collector',
        tier: AccountTier.pro,
        provider: AuthProviderType.discord,
        isGuest: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await tester.pumpWidget(
        wrapWithTestScope(
          child: const LogoutConfirmationDialog(),
          user: regUser,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      expect(find.text('You are browsing as Guest. Local cards can be preserved.'), findsNothing);
    });

    // =========================================================================
    // B17.3: Cancel logout cleanly preserves session, database, and navigation
    // =========================================================================
    testWidgets('B17.3: Cancelling logout prompt cleanly retains current session without route changes or data loss', (tester) async {
      final regUser = AuthUser(
        id: 'user_reg_active_session',
        displayName: 'Active Collector',
        username: '@active_col',
        tier: AccountTier.pro,
        provider: AuthProviderType.google,
        isGuest: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      late final ProviderContainer container;

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
              return MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (innerContext) => ElevatedButton(
                      onPressed: () => LogoutConfirmationDialog.show(innerContext),
                      child: const Text('Open Logout Dialog'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Logout Dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const Key('logout_cancel_button')));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.byType(LogoutConfirmationDialog), findsNothing);

      // Verify empirical session invariants:
      final currentUser = container.read(currentUserProvider);
      expect(currentUser.id, equals('user_reg_active_session'));
      expect(currentUser.isGuest, isFalse);
      expect(mockAuthRepo.signOutCallCount, equals(0));
    });

    // =========================================================================
    // B17.4: Network failure fallback to local guest session reset
    // =========================================================================
    testWidgets('B17.4: Network failure during signOut falls back gracefully to local session reset without crash', (tester) async {
      mockAuthRepo.shouldFailSignOut = true; // Simulates offline / DNS failure
      final regUser = AuthUser(
        id: 'user_reg_offline_test',
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
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            currentUserProvider.overrideWith((ref) => CurrentUserNotifier(mockAuthRepo)..setUser(regUser)),
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

      // Tap Confirm Logout while offline
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Verify signOut was attempted
      expect(mockAuthRepo.signOutCallCount, equals(1));

      // Verify session fell back to guest
      final userAfterLogout = container.read(currentUserProvider);
      expect(userAfterLogout.isGuest, isTrue);
    });

    // =========================================================================
    // B17.5: Post-logout route clearing (/welcome)
    // =========================================================================
    testWidgets('B17.5: Post-logout navigation routes to /welcome via GoRouter', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // We start at /feed
      expect(find.byType(FeedScreen), findsOneWidget);

      // Show dialog via rootNavigator context
      final navContext = rootNavigatorKey.currentContext!;
      LogoutConfirmationDialog.show(navContext);
      await tester.pumpAndSettle();

      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

      // Confirm logout
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Verify we arrived at /welcome (OnboardingWelcomeScreen is mounted)
      expect(find.byType(OnboardingWelcomeScreen), findsOneWidget);
    });

    // =========================================================================
    // Guest Data Preservation Checkbox: Purge vs Preserve in SQLite
    // =========================================================================
    testWidgets('Guest data retention: Unchecking checkbox purges guest data but leaves registered data intact', (tester) async {
      final now = DateTime.now();

      // 1. Seed SQLite with guest items and registered user items
      await db.into(db.vaultItems).insert(createTestCard(
        id: 'v_guest_alpha',
        name: 'Guest Black Lotus',
        userId: 'guest',
      ));
      await db.into(db.vaultItems).insert(createTestCard(
        id: 'v_guest_local',
        name: 'Local Mox',
        userId: 'user-current-me',
      ));
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'd_guest_deck',
        name: 'Guest Deck',
        format: 'Commander',
        createdAt: now,
        userId: const drift.Value('guest'),
      ));
      await db.into(db.vaultItems).insert(createTestCard(
        id: 'v_reg_beta',
        name: 'Registered Underground Sea',
        userId: 'user_reg_preserved_999',
      ));
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'd_reg_deck',
        name: 'Registered Modern Deck',
        format: 'Modern',
        createdAt: now,
        userId: const drift.Value('user_reg_preserved_999'),
      ));

      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            privacyModeProvider.overrideWith((ref) => true),
            streamerSecurityEnabledProvider.overrideWith((ref) => true),
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

      // Initial preferences are true
      expect(container.read(privacyModeProvider), isTrue);
      expect(container.read(streamerSecurityEnabledProvider), isTrue);

      // Uncheck "Keep local guest cards & decks"
      await tester.tap(find.byKey(const Key('logout_keep_guest_data_checkbox')));
      await tester.pumpAndSettle();

      // Confirm logout
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Invariant Check 1: Guest items were purged from SQLite
      final guestCards = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_guest_alpha') | t.id.equals('v_guest_local')))
          .get();
      expect(guestCards, isEmpty);

      final guestDecks = await (db.select(db.decks)
            ..where((t) => t.id.equals('d_guest_deck')))
          .get();
      expect(guestDecks, isEmpty);

      // Invariant Check 2: Registered user items were PRESERVED in SQLite
      final regCards = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_reg_beta')))
          .get();
      expect(regCards.length, equals(1));
      expect(regCards.first.name, equals('Registered Underground Sea'));

      final regDecks = await (db.select(db.decks)
            ..where((t) => t.id.equals('d_reg_deck')))
          .get();
      expect(regDecks.length, equals(1));

      // Invariant Check 3: Preferences were reset to false in dev/test
      expect(container.read(privacyModeProvider), isFalse);
      expect(container.read(streamerSecurityEnabledProvider), isFalse);
    });

    testWidgets('Guest data retention: Keeping checkbox checked preserves all guest data in SQLite', (tester) async {
      final now = DateTime.now();

      // Seed guest card and deck
      await db.into(db.vaultItems).insert(createTestCard(
        id: 'v_guest_stay',
        name: 'Preserved Guest Mox',
        userId: 'guest',
      ));
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'd_guest_stay',
        name: 'Preserved Guest Deck',
        format: 'Pauper',
        createdAt: now,
        userId: const drift.Value('guest'),
      ));

      await tester.pumpWidget(
        wrapWithTestScope(
          child: const LogoutConfirmationDialog(),
        ),
      );
      await tester.pumpAndSettle();

      // Checkbox is checked by default
      final checkbox = tester.widget<CheckboxListTile>(find.byKey(const Key('logout_keep_guest_data_checkbox')));
      expect(checkbox.value, isTrue);

      // Confirm logout with checkbox checked
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Invariant Check: Guest card and deck REMAIN in SQLite
      final guestCard = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('v_guest_stay')))
          .get();
      expect(guestCard.length, equals(1));

      final guestDeck = await (db.select(db.decks)
            ..where((t) => t.id.equals('d_guest_stay')))
          .get();
      expect(guestDeck.length, equals(1));
    });

    // =========================================================================
    // Entry Point Buttons: Command Center & App Settings
    // =========================================================================
    testWidgets('Entry points: Command Center and App Settings contain functional Log Out buttons', (tester) async {
      // 1. AppSettingsDialog contains app_settings_logout_button
      await tester.pumpWidget(
        wrapWithTestScope(
          child: const AppSettingsDialog(),
        ),
      );
      await tester.pumpAndSettle();

      final settingsLogoutFinder = find.byKey(const Key('app_settings_logout_button'));
      expect(settingsLogoutFinder, findsOneWidget);

      await tester.tap(settingsLogoutFinder);
      await tester.pumpAndSettle();

      // Logout confirmation dialog is presented
      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);
    });

    testWidgets('Entry points: MorphingCommandCenter bottom contains functional Log Out button', (tester) async {
      await tester.pumpWidget(
        wrapWithTestScope(
          child: const MorphingCommandCenter(),
        ),
      );
      await tester.pumpAndSettle();

      final commandCenterLogoutFinder = find.byKey(const Key('command_center_logout_button'));
      await tester.scrollUntilVisible(commandCenterLogoutFinder, 300);
      expect(commandCenterLogoutFinder, findsOneWidget);

      await tester.tap(commandCenterLogoutFinder);
      await tester.pumpAndSettle();

      // Logout confirmation dialog is presented
      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);
    });
  });
}

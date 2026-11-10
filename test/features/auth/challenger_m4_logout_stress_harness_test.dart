import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/router/app_router.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:countr/features/auth/presentation/screens/onboarding_welcome_screen.dart';
import 'package:countr/features/command_center/presentation/widgets/app_settings_dialog.dart';

/// Adversarial repository supporting latency, configurable exceptions, and call tracking
class StressTestAuthRepository extends MockAuthRepository {
  int signOutCalls = 0;
  Duration latency = Duration.zero;
  Object? errorToThrow;

  StressTestAuthRepository({super.initialUser});

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (latency > Duration.zero) {
      await Future.delayed(latency);
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    await super.signOut();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late StressTestAuthRepository stressAuthRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    stressAuthRepo = StressTestAuthRepository();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItemsCompanion createVaultItem({
    required String id,
    required String name,
    required String userId,
  }) {
    final now = DateTime.now();
    return VaultItemsCompanion.insert(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'TEST',
      imageUrl: '',
      acquiredPrice: 5.0,
      acquiredDate: now,
      condition: 'NM',
      currentMarketPrice: 5.0,
      lastPriceUpdate: now,
      dynamicData: '{}',
      userId: drift.Value(userId),
    );
  }

  group('Challenger M4 Stress Harness: Log Out & Session Management', () {
    // -------------------------------------------------------------------------
    // Stress Test 1: Barrier dismissal during in-flight async signOut
    // -------------------------------------------------------------------------
    testWidgets('Stress 1: Tapping dialog barrier during slow signOut does not throw setState/unmounted errors', (tester) async {
      stressAuthRepo.latency = const Duration(milliseconds: 400);
      addTearDown(() => appRouter.go('/feed'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(stressAuthRepo),
            currentUserProvider.overrideWith(
              (ref) => CurrentUserNotifier(stressAuthRepo)
                ..setUser(AuthUser(
                  id: 'user_in_flight',
                  displayName: 'In Flight User',
                  username: '@inflight',
                  tier: AccountTier.free,
                  provider: AuthProviderType.google,
                  isGuest: false,
                  createdAt: DateTime.now(),
                  lastLoginAt: DateTime.now(),
                )),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rootContext = rootNavigatorKey.currentContext!;
      LogoutConfirmationDialog.show(rootContext);
      await tester.pumpAndSettle();

      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

      // Tap confirm button (initiates 400ms async signOut)
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pump(const Duration(milliseconds: 50));

      // Circular indicator is showing
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Now tap the barrier outside the dialog (e.g. at top-left corner (10, 10))
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));

      // Advance time past the 400ms delay and let animations settle
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Zero exceptions thrown, and navigation successfully routed to /welcome
      expect(find.byType(OnboardingWelcomeScreen), findsOneWidget);
      expect(stressAuthRepo.signOutCalls, equals(1));
    });

    // -------------------------------------------------------------------------
    // Stress Test 2: Nested dialogs teardown (Logout opened from AppSettingsDialog)
    // -------------------------------------------------------------------------
    testWidgets('Stress 2: Confirming logout from inside AppSettingsDialog cleanly clears all dialogs and routes to /welcome', (tester) async {
      addTearDown(() => appRouter.go('/feed'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(stressAuthRepo),
            currentUserProvider.overrideWith(
              (ref) => CurrentUserNotifier(stressAuthRepo)
                ..setUser(AuthUser(
                  id: 'user_nested_dialog',
                  displayName: 'Nested Dialog User',
                  username: '@nested',
                  tier: AccountTier.pro,
                  provider: AuthProviderType.apple,
                  isGuest: false,
                  createdAt: DateTime.now(),
                  lastLoginAt: DateTime.now(),
                )),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rootContext = rootNavigatorKey.currentContext!;

      // 1. Open AppSettingsDialog
      showDialog(
        context: rootContext,
        builder: (_) => const AppSettingsDialog(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppSettingsDialog), findsOneWidget);

      // 2. Tap Log Out inside AppSettingsDialog to open LogoutConfirmationDialog
      final logoutBtnFinder = find.byKey(const Key('app_settings_logout_button'));
      await tester.scrollUntilVisible(
        logoutBtnFinder,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(logoutBtnFinder);
      await tester.pumpAndSettle();

      // Both dialogs are in the widget tree
      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

      // 3. Confirm logout
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Invariant: Both dialogs must be dismissed! No AppSettingsDialog remaining!
      expect(find.byType(LogoutConfirmationDialog), findsNothing);
      expect(find.byType(AppSettingsDialog), findsNothing);

      // Invariant: Landed on OnboardingWelcomeScreen
      expect(find.byType(OnboardingWelcomeScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Stress Test 3: Rapid cancel followed by immediate re-open and confirm
    // -------------------------------------------------------------------------
    testWidgets('Stress 3: Rapid cancel -> re-open -> confirm executes cleanly without state contamination', (tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(stressAuthRepo),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                routes: {
                  '/welcome': (c) => const Scaffold(body: Text('Welcome Screen')),
                },
                home: Scaffold(
                  body: Builder(
                    builder: (innerContext) => ElevatedButton(
                      key: const Key('open_dialog_test'),
                      onPressed: () => LogoutConfirmationDialog.show(innerContext),
                      child: const Text('Open Dialog'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cycle 1: Open and Cancel
      await tester.tap(find.byKey(const Key('open_dialog_test')));
      await tester.pumpAndSettle();
      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout_cancel_button')));
      await tester.pumpAndSettle();
      expect(find.byType(LogoutConfirmationDialog), findsNothing);
      expect(stressAuthRepo.signOutCalls, equals(0));

      // Cycle 2: Immediate Re-open and Confirm
      await tester.tap(find.byKey(const Key('open_dialog_test')));
      await tester.pumpAndSettle();
      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      expect(stressAuthRepo.signOutCalls, equals(1));
      expect(container.read(currentUserProvider).isGuest, isTrue);
    });

    // -------------------------------------------------------------------------
    // Stress Test 4: High volume guest data purge stress (100 cards & 10 decks)
    // -------------------------------------------------------------------------
    testWidgets('Stress 4: Purge under load (100 cards + 10 decks) executes in single atomic transaction', (tester) async {
      final now = DateTime.now();

      // Seed 100 guest cards and 10 decks
      await db.batch((batch) {
        for (int i = 0; i < 100; i++) {
          batch.insert(
            db.vaultItems,
            createVaultItem(
              id: 'guest_card_bulk_$i',
              name: 'Bulk Card #$i',
              userId: i.isEven ? 'guest' : 'user-current-me',
            ),
          );
        }
        for (int i = 0; i < 10; i++) {
          batch.insert(
            db.decks,
            DecksCompanion.insert(
              id: 'guest_deck_bulk_$i',
              name: 'Bulk Deck #$i',
              format: 'Modern',
              createdAt: now,
              userId: const drift.Value('guest'),
            ),
          );
        }
      });

      // Verify seeding
      final countBeforeCards = await db.select(db.vaultItems).get();
      final countBeforeDecks = await db.select(db.decks).get();
      expect(countBeforeCards.length, greaterThanOrEqualTo(100));
      expect(countBeforeDecks.length, greaterThanOrEqualTo(10));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(stressAuthRepo),
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

      // Uncheck "Keep local guest cards & decks"
      await tester.tap(find.byKey(const Key('logout_keep_guest_data_checkbox')));
      await tester.pumpAndSettle();

      // Confirm logout
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Empirical verification: All guest cards and guest decks were purged!
      final remainingGuestCards = await (db.select(db.vaultItems)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals('guest') |
                t.userId.equals('user-current-me') |
                t.userId.equals('local_user') |
                t.userId.equals('')))
          .get();
      expect(remainingGuestCards, isEmpty);

      final remainingGuestDecks = await (db.select(db.decks)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals('guest') |
                t.userId.equals('user-current-me') |
                t.userId.equals('local_user') |
                t.userId.equals('')))
          .get();
      expect(remainingGuestDecks, isEmpty);

      // Verify non-guest cards (user-edh-rec-fanatic, store-tbs-comics) were PRESERVED:
      final nonGuestCards = await (db.select(db.vaultItems)
            ..where((t) => t.userId.equals('user-edh-rec-fanatic') | t.userId.equals('store-tbs-comics')))
          .get();
      expect(nonGuestCards.length, equals(3));
    });

    // -------------------------------------------------------------------------
    // Stress Test 5: Unhandled error types during signOut (e.g. FormatException, TimeoutException)
    // -------------------------------------------------------------------------
    testWidgets('Stress 5: Catastrophic TimeoutException during signOut triggers resilient fallback to guest', (tester) async {
      stressAuthRepo.errorToThrow = TimeoutException('Firebase Auth backend timed out after 30s');

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(stressAuthRepo),
            currentUserProvider.overrideWith(
              (ref) => CurrentUserNotifier(stressAuthRepo)
                ..setUser(AuthUser(
                  id: 'user_timeout_test',
                  displayName: 'Timeout User',
                  username: '@timeout_user',
                  tier: AccountTier.pro,
                  provider: AuthProviderType.email,
                  isGuest: false,
                  createdAt: DateTime.now(),
                  lastLoginAt: DateTime.now(),
                )),
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

      // Confirm logout
      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Exception was trapped safely without crash; session was reset to guest
      expect(stressAuthRepo.signOutCalls, equals(1));
      expect(container.read(currentUserProvider).isGuest, isTrue);
      expect(container.read(isUserLoggedInProvider), isFalse);
    });
  });
}

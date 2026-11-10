import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/widgets/logout_confirmation_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockAuthRepository mockAuthRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    mockAuthRepo = MockAuthRepository();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject({AuthUser? user}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        if (user != null)
          currentUserProvider.overrideWith((ref) => CurrentUserNotifier(mockAuthRepo)..setUser(user)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: LogoutConfirmationDialog(),
        ),
      ),
    );
  }

  group('Feature 17: LogoutConfirmationDialog Tests', () {
    testWidgets('F17.4: Renders dialog with title, checkbox, cancel, and confirm buttons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Log Out'), findsWidgets);
      expect(find.byKey(const Key('logout_keep_guest_data_checkbox')), findsOneWidget);
      expect(find.text('Keep local guest cards & decks'), findsOneWidget);
      expect(find.byKey(const Key('logout_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('logout_confirm_button')), findsOneWidget);
      expect(find.byKey(const Key('confirm_logout_button')), findsOneWidget);
    });

    testWidgets('B17.2: Guest prompt includes Guest clarification', (tester) async {
      await tester.pumpWidget(buildSubject(user: AuthUser.guest()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Guest'), findsWidgets);
      expect(find.text('You are browsing as Guest. Local cards can be preserved.'), findsOneWidget);
    });

    testWidgets('B17.2: Registered prompt displays Are you sure you want to log out?', (tester) async {
      final regUser = AuthUser(
        id: 'user_reg_99',
        displayName: 'Registered Collector',
        username: '@collector_99',
        tier: AccountTier.free,
        provider: AuthProviderType.email,
        isGuest: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await tester.pumpWidget(buildSubject(user: regUser));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
    });

    testWidgets('B17.4: Unchecking keep guest data toggles checkbox state', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byKey(const Key('logout_keep_guest_data_checkbox')),
      );
      expect(checkbox.value, isTrue);

      await tester.tap(find.byKey(const Key('logout_keep_guest_data_checkbox')));
      await tester.pumpAndSettle();

      final updatedCheckbox = tester.widget<CheckboxListTile>(
        find.byKey(const Key('logout_keep_guest_data_checkbox')),
      );
      expect(updatedCheckbox.value, isFalse);
    });

    testWidgets('B17.3: Tapping cancel dismisses dialog', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LogoutConfirmationDialog.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LogoutConfirmationDialog), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppBar Privacy Mode Toggle Actions', () {
    testWidgets('VaultScreen: Privacy toggle in AppBar updates state and switches icon', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      container.read(privacyModeProvider.notifier).state = false;
      container.read(vaultViewModeProvider.notifier).state = VaultViewMode.allVault;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleButton = find.byKey(const Key('vault_privacy_mode_button'));
      expect(toggleButton, findsOneWidget);

      // Verify layout buttons are preserved alongside privacy toggle
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);

      // Initially visibility icon (privacy off)
      expect(
        find.descendant(of: toggleButton, matching: find.byIcon(Icons.visibility)),
        findsOneWidget,
      );

      // Tap toggle -> activates privacy mode
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(container.read(privacyModeProvider), isTrue);
      expect(
        find.descendant(of: toggleButton, matching: find.byIcon(Icons.visibility_off)),
        findsOneWidget,
      );

      // Tap toggle again -> deactivates privacy mode
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(container.read(privacyModeProvider), isFalse);
      expect(
        find.descendant(of: toggleButton, matching: find.byIcon(Icons.visibility)),
        findsOneWidget,
      );
    });

    testWidgets('DecksScreen: Privacy toggle in AppBar updates state and switches icon', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleButton = find.byKey(const Key('decks_privacy_mode_button'));
      expect(toggleButton, findsOneWidget);

      // Initially visibility icon
      expect(
        find.descendant(of: toggleButton, matching: find.byIcon(Icons.visibility)),
        findsOneWidget,
      );

      // Tap toggle -> activates privacy mode
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(container.read(privacyModeProvider), isTrue);
      expect(
        find.descendant(of: toggleButton, matching: find.byIcon(Icons.visibility_off)),
        findsOneWidget,
      );

      // Tap toggle again -> deactivates privacy mode
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(container.read(privacyModeProvider), isFalse);
      expect(
        find.descendant(of: toggleButton, matching: find.byIcon(Icons.visibility)),
        findsOneWidget,
      );
    });

    testWidgets('FeedScreen: Eyeball privacy toggle is removed from AppBar and privacy is controlled globally', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(privacyModeProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Eyeball button must NOT be present on FeedScreen AppBar
      expect(find.byKey(const Key('feed_privacy_mode_button')), findsNothing);

      // Verify Feed AppBar standard actions (Search, Inbox, Notifications) are cleanly present
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('Inbox'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);

      // Verify privacyModeProvider state is independently controlled
      container.read(privacyModeProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(container.read(privacyModeProvider), isTrue);

      container.read(privacyModeProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(container.read(privacyModeProvider), isFalse);
    });
  });
}

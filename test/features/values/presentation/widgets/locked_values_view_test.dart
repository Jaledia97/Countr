import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';

void main() {
  group('LockedValuesView Widget Tests', () {
    testWidgets('renders lock icon and verbatim privacy instruction message', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LockedValuesView(),
            ),
          ),
        ),
      );

      // Verify lock icon
      expect(find.byKey(const Key('locked_values_lock_icon')), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Verify verbatim copy from M1 requirements: "Values hidden. Disable Privacy Mode to view market data."
      expect(
        find.text('Values hidden. Disable Privacy Mode to view market data.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('locked_values_tab_message')), findsOneWidget);

      // Verify unlock button presence
      final buttonFinder = find.byKey(const Key('locked_values_disable_privacy_button'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('Disable Privacy Mode'), findsOneWidget);
    });

    testWidgets('tapping unlock button disables privacy mode reactively', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Start with Privacy Mode active (true)
      container.read(privacyModeProvider.notifier).state = true;
      expect(container.read(privacyModeProvider), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LockedValuesView(),
            ),
          ),
        ),
      );

      final buttonFinder = find.byKey(const Key('locked_values_disable_privacy_button'));
      expect(buttonFinder, findsOneWidget);

      // Tap Disable Privacy Mode button
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Privacy Mode should now be disabled (false)
      expect(container.read(privacyModeProvider), isFalse);
    });
  });
}

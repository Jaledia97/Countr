import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/trades/presentation/dialogs/large_value_difference_dialog.dart';

void main() {
  Widget buildTestHost({required Future<bool> Function(BuildContext) onTrigger}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('trigger_button'),
              onPressed: () => onTrigger(context),
              child: const Text('Trigger'),
            ),
          ),
        ),
      ),
    );
  }

  group('LargeValueDifferenceDialog Safeguard', () {
    testWidgets('Bypasses dialog immediately when gaps are below safeguard thresholds', (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        buildTestHost(
          onTrigger: (context) async {
            confirmed = await LargeValueDifferenceDialog.checkAndConfirm(
              context: context,
              dollarGap: 5.0,
              percentGap: 8.0,
            );
            return confirmed!;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('trigger_button')));
      await tester.pumpAndSettle();

      // Dialog must NOT appear
      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(confirmed, isTrue);
    });

    testWidgets('Triggers dialog when dollar gap >= \$10.00 and dismisses on [Review Trade]', (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        buildTestHost(
          onTrigger: (context) async {
            confirmed = await LargeValueDifferenceDialog.checkAndConfirm(
              context: context,
              dollarGap: 12.50,
              percentGap: 10.0,
            );
            return confirmed!;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('trigger_button')));
      await tester.pumpAndSettle();

      // Dialog must appear
      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.textContaining('\$12.50'), findsOneWidget);
      expect(find.textContaining('10.0%'), findsOneWidget);

      // Tap [Review Trade]
      await tester.tap(find.byKey(const Key('review_trade_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(confirmed, isFalse);
    });

    testWidgets('Triggers dialog when percent gap >= 15.0% and proceeds on [Proceed Anyway]', (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        buildTestHost(
          onTrigger: (context) async {
            confirmed = await LargeValueDifferenceDialog.checkAndConfirm(
              context: context,
              dollarGap: 6.00,
              percentGap: 25.0,
            );
            return confirmed!;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('trigger_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsOneWidget);
      expect(find.textContaining('\$6.00'), findsOneWidget);
      expect(find.textContaining('25.0%'), findsOneWidget);

      // Tap [Proceed Anyway]
      await tester.tap(find.byKey(const Key('proceed_anyway_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('large_value_difference_dialog')), findsNothing);
      expect(confirmed, isTrue);
    });
  });
}

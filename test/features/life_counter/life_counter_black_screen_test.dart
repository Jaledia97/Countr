import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/main.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  testWidgets('Launching MTG Commander mode from Command Center opens PodScaffoldWidget and can be exited without black screen', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: CountrApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Main Shell is on screen
    expect(find.text('Feed'), findsWidgets);

    // 2. Open Command Center via Menu button
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // 3. Scroll to Play / Track + and find Commander mode
    final scrollableFinder = find.byType(Scrollable).last;
    final playTrackFinder = find.text('Play / Track +');
    await tester.scrollUntilVisible(playTrackFinder, 200, scrollable: scrollableFinder);
    await tester.pumpAndSettle();

    final mtgFinder = find.text('MTG');
    await tester.scrollUntilVisible(mtgFinder, 200, scrollable: scrollableFinder);
    await tester.pumpAndSettle();
    await tester.tap(mtgFinder);
    await tester.pumpAndSettle();

    // 4. Verify PregameSetupSheet is shown
    final startMatchButtonFinder = find.byKey(const Key('start_match_button'));
    expect(startMatchButtonFinder, findsOneWidget);

    // 5. Tap START MATCH
    await tester.tap(startMatchButtonFinder);
    await tester.pumpAndSettle();

    // 6. Verify PodScaffoldWidget is active on screen (NOT a black screen!)
    expect(find.byType(PodScaffoldWidget), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);

    // 7. Verify players are rendered with life totals (e.g. 40)
    expect(find.text('40'), findsWidgets);

    // 8. Test life increment button on Player 1
    final plusButtons = find.byIcon(Icons.add);
    expect(plusButtons, findsWidgets);
    await tester.tap(plusButtons.first);
    await tester.pump();
    expect(find.text('41'), findsWidgets);

    // 9. Tap the exit button to return back to Countr shell cleanly
    final exitButton = find.byKey(const Key('life_counter_exit_button'));
    expect(exitButton, findsOneWidget);
    await tester.tap(exitButton);
    await tester.pumpAndSettle();

    // 10. Verify we are cleanly back in MainShellScreen (Feed) without crash or black screen
    expect(find.byType(PodScaffoldWidget), findsNothing);
    expect(find.text('Feed'), findsWidgets);
  });
}

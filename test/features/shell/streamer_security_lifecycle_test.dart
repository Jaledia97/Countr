import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/shell/presentation/screens/main_shell_screen.dart';

class MockNavigationShell extends StatefulWidget implements StatefulNavigationShell {
  @override
  final int currentIndex;

  const MockNavigationShell({super.key, this.currentIndex = 0});

  @override
  void goBranch(int index, {bool initialLocation = false}) {}

  @override
  State<MockNavigationShell> createState() => _MockNavigationShellState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNavigationShellState extends State<MockNavigationShell> {
  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('mock_nav_body'));
}

void main() {
  testWidgets('Streamer Security auto-enables privacy mode on paused lifecycle', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Streamer security enabled, privacy mode initially false
    container.read(streamerSecurityEnabledProvider.notifier).state = true;
    container.read(privacyModeProvider.notifier).state = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MainShellScreen(
            navigationShell: MockNavigationShell(),
          ),
        ),
      ),
    );

    expect(container.read(privacyModeProvider), isFalse);

    // Full Flutter lifecycle transition to paused: resumed -> inactive -> hidden -> paused
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(container.read(privacyModeProvider), isTrue);
  });

  testWidgets('Streamer Security auto-enables privacy mode on inactive lifecycle', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(streamerSecurityEnabledProvider.notifier).state = true;
    container.read(privacyModeProvider.notifier).state = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MainShellScreen(
            navigationShell: MockNavigationShell(),
          ),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(container.read(privacyModeProvider), isTrue);
  });

  testWidgets('Streamer Security auto-enables privacy mode on hidden lifecycle', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(streamerSecurityEnabledProvider.notifier).state = true;
    container.read(privacyModeProvider.notifier).state = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MainShellScreen(
            navigationShell: MockNavigationShell(),
          ),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    expect(container.read(privacyModeProvider), isTrue);
  });

  testWidgets('When Streamer Security is disabled, backgrounding does not alter privacy mode', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(streamerSecurityEnabledProvider.notifier).state = false;
    container.read(privacyModeProvider.notifier).state = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MainShellScreen(
            navigationShell: MockNavigationShell(),
          ),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(container.read(privacyModeProvider), isFalse);
  });

  testWidgets('Returning to resumed preserves privacy lock (no auto-unlock)', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(streamerSecurityEnabledProvider.notifier).state = true;
    container.read(privacyModeProvider.notifier).state = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MainShellScreen(
            navigationShell: MockNavigationShell(),
          ),
        ),
      ),
    );

    // Go to background (locks privacy mode)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(container.read(privacyModeProvider), isTrue);

    // Return to foreground (resumed): paused -> hidden -> inactive -> resumed
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(container.read(privacyModeProvider), isTrue);
  });
}

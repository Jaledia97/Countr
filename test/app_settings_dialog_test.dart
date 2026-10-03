import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/command_center/presentation/widgets/app_settings_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsDialog Component Unit & Widget Tests', () {
    testWidgets(
      'renders all controls, dark surface styling, backdrop blur, and header',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        // Verify header components
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
        expect(find.text('STANDARD'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.byType(BackdropFilter), findsWidgets);

        // Verify Privacy Mode control
        expect(
          find.byKey(const Key('command_center_privacy_mode_toggle')),
          findsOneWidget,
        );
        expect(find.text('Global Privacy Mode'), findsOneWidget);
        expect(find.text('Redact values and card prices'), findsOneWidget);

        // Verify Base Currency control
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
        expect(find.text('Base Currency'), findsOneWidget);
        expect(find.text('Normalized valuation engine'), findsOneWidget);

        // Verify Streamer Security control
        expect(
          find.byKey(const Key('command_center_streamer_security_toggle')),
          findsOneWidget,
        );
        expect(find.text('Streamer Security'), findsOneWidget);
        expect(find.text('Auto-enable privacy on background'), findsOneWidget);
      },
    );

    testWidgets(
      'toggling Global Privacy Mode switch updates state and reactive badge',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse);
        expect(find.text('STANDARD'), findsOneWidget);
        expect(find.text('PRIVACY'), findsNothing);

        // Tap privacy toggle
        final privacyToggle = find.byKey(
          const Key('command_center_privacy_mode_toggle'),
        );
        await tester.tap(privacyToggle);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isTrue);
        expect(find.text('PRIVACY'), findsOneWidget);
        expect(find.text('STANDARD'), findsNothing);

        // Tap privacy toggle again
        await tester.tap(privacyToggle);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse);
        expect(find.text('STANDARD'), findsOneWidget);
      },
    );

    testWidgets(
      'changing Base Currency dropdown updates baseCurrencyProvider reactively',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(baseCurrencyProvider), AppCurrency.usd);

        final dropdown = find.byKey(
          const Key('command_center_base_currency_dropdown'),
        );

        // Select EUR
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('EUR (€)').last);
        await tester.pumpAndSettle();
        expect(container.read(baseCurrencyProvider), AppCurrency.eur);

        // Select GBP
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('GBP (£)').last);
        await tester.pumpAndSettle();
        expect(container.read(baseCurrencyProvider), AppCurrency.gbp);

        // Select CAD
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('CAD (CA\$)').last);
        await tester.pumpAndSettle();
        expect(container.read(baseCurrencyProvider), AppCurrency.cad);
      },
    );

    testWidgets(
      'toggling Streamer Security switch updates streamerSecurityEnabledProvider reactively',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(streamerSecurityEnabledProvider), isFalse);

        final streamerToggle = find.byKey(
          const Key('command_center_streamer_security_toggle'),
        );
        await tester.tap(streamerToggle);
        await tester.pumpAndSettle();

        expect(container.read(streamerSecurityEnabledProvider), isTrue);

        await tester.tap(streamerToggle);
        await tester.pumpAndSettle();

        expect(container.read(streamerSecurityEnabledProvider), isFalse);
      },
    );

    testWidgets(
      'AppSettingsDialog.show displays modal and close button dismisses cleanly',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => AppSettingsDialog.show(context),
                    child: const Text('Open Settings'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsNothing);

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsOneWidget);
        expect(find.text('APP SETTINGS'), findsOneWidget);

        // Tap close button inside dialog
        final closeButton = find.descendant(
          of: find.byType(AppSettingsDialog),
          matching: find.byIcon(Icons.close_rounded),
        );
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsNothing);
        expect(find.text('Open Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'AppSettingsModal.show displays modal and tapping barrier dismisses cleanly',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => AppSettingsModal.show(context),
                    child: const Text('Open Settings Modal'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsNothing);

        await tester.tap(find.text('Open Settings Modal'));
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsOneWidget);

        // Tap outside dialog on barrier (e.g. top-left corner)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.byType(AppSettingsDialog), findsNothing);
        expect(find.text('Open Settings Modal'), findsOneWidget);
      },
    );

    testWidgets('renders cleanly without overflow on narrow screen (320x568)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('APP SETTINGS'), findsOneWidget);
      expect(
        find.byKey(const Key('command_center_privacy_mode_toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('command_center_base_currency_dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('command_center_streamer_security_toggle')),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders cleanly and scrolls without overflow on landscape screen (700x380)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(700, 380);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('APP SETTINGS'), findsOneWidget);

        final scrollableInDialog = find.descendant(
          of: find.byType(AppSettingsDialog),
          matching: find.byType(Scrollable),
        );
        expect(scrollableInDialog, findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const Key('command_center_streamer_security_toggle')),
          50,
          scrollable: scrollableInDialog,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('command_center_streamer_security_toggle')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'rapid 50x switch toggling maintains state consistency without desync',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        final privacyToggle = find.byKey(
          const Key('command_center_privacy_mode_toggle'),
        );
        final streamerToggle = find.byKey(
          const Key('command_center_streamer_security_toggle'),
        );

        for (int i = 0; i < 50; i++) {
          await tester.tap(privacyToggle);
          await tester.pump();
          await tester.tap(streamerToggle);
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse);
        expect(container.read(streamerSecurityEnabledProvider), isFalse);
        expect(find.text('STANDARD'), findsOneWidget);

        await tester.tap(privacyToggle);
        await tester.pumpAndSettle();
        expect(container.read(privacyModeProvider), isTrue);
        expect(find.text('PRIVACY'), findsOneWidget);
      },
    );

    testWidgets('system back navigation cleanly dismisses modal dialog', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => AppSettingsDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSettingsDialog), findsOneWidget);

      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(AppSettingsDialog), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets(
      'tapping close button when dialog is standalone without pop route does not crash',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        final closeButton = find.byKey(
          const Key('command_center_app_settings_close_button'),
        );
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AppSettingsDialog), findsOneWidget);
      },
    );

    testWidgets(
      're-opening AppSettingsDialog after clean dismissal succeeds without state lock',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => AppSettingsDialog.show(context),
                    child: const Text('Open Toggle'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1st cycle: open and dismiss via close button
        await tester.tap(find.text('Open Toggle'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsOneWidget);

        final closeButton = find.descendant(
          of: find.byType(AppSettingsDialog),
          matching: find.byIcon(Icons.close_rounded),
        );
        await tester.tap(closeButton);
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsNothing);

        // 2nd cycle: re-open cleanly
        await tester.tap(find.text('Open Toggle'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsOneWidget);

        // Dismiss via barrier tap
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsNothing);

        // 3rd cycle: re-open again
        await tester.tap(find.text('Open Toggle'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsDialog), findsOneWidget);
      },
    );

    testWidgets(
      'renders cleanly without overflow under accessibility text scale (1.8x) on narrow screen (320x568)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  size: const Size(320, 568),
                ),
                child: child!,
              ),
              home: const Scaffold(body: AppSettingsDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(
          find.byKey(const Key('command_center_privacy_mode_toggle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('command_center_streamer_security_toggle')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly without overflow under accessibility text scale (1.8x) on standard mobile screen (360x640)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  size: const Size(360, 640),
                ),
                child: child!,
              ),
              home: const Scaffold(body: AppSettingsDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(
          find.byKey(const Key('command_center_privacy_mode_toggle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('command_center_streamer_security_toggle')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly without overflow under extreme accessibility text scale (2.0x) on modern mobile screen (390x844)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                  size: const Size(390, 844),
                ),
                child: child!,
              ),
              home: const Scaffold(body: AppSettingsDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly and side-by-side on wide tablet / desktop viewport (800x600)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AppSettingsDialog())),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly without overflow under elevated accessibility text scale (2.5x) on narrow screen (320x568)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.5),
                  size: const Size(320, 568),
                ),
                child: child!,
              ),
              home: const Scaffold(body: AppSettingsDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(
          find.byKey(const Key('command_center_privacy_mode_toggle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('command_center_streamer_security_toggle')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly without overflow under accessibility text scale (1.8x) on compact fold screen (340x700)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(340, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  size: const Size(340, 700),
                ),
                child: child!,
              ),
              home: const Scaffold(body: AppSettingsDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('APP SETTINGS'), findsOneWidget);
        expect(
          find.byKey(const Key('command_center_base_currency_dropdown')),
          findsOneWidget,
        );
      },
    );
  });
}

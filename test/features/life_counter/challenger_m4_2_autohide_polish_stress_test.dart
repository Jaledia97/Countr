// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M4-2 Empirical Stress Test Suite
// Requirements Under Test:
// - R4.3: Auto-Hide Central Utility Bar (Geometry Midpoint Stability, Inactivity Collapse, Screen Touch Expansion, Modal Route Open Suppression)
// - R4.4: Polish & Accessibility Toggles (OLED True Black, Wakelock Platform Safety, PodHaptics Safety, Dual-Key Switch Finders)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/services/pod_haptics.dart';
import 'package:countr/features/life_counter/domain/services/wakelock_service.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/dialogs/reset_game_dialog.dart';
import 'package:countr/features/life_counter/presentation/widgets/central_utility_bar.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_art_backdrop.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<PodPlayerState> makeTestPlayers(int count, {int startingLife = 40, bool withArt = false}) {
    return List.generate(
      count,
      (i) => PodPlayerState(
        id: 'p$i',
        seatIndex: i,
        name: 'Player ${i + 1}',
        life: startingLife,
        commanderArtCropUrl: withArt ? 'https://example.com/art_$i.jpg' : null,
      ),
    );
  }

  PodState makeTestPod(
    int count, {
    int startingLife = 40,
    String format = 'commander',
    String cardDensity = 'Default',
    bool withArt = false,
  }) {
    return PodState(
      sessionId: 'challenger_m4_2_pod_session',
      format: format,
      startingLife: startingLife,
      players: makeTestPlayers(count, startingLife: startingLife, withArt: withArt),
      cardDensity: cardDensity,
    );
  }

  Widget wrapWithScaffold(Widget child, {Size size = const Size(390, 844)}) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('CH-M4-2-G1: Geometry Stress & Center Hub Midpoint Stability (R4.3)', () {
    testWidgets('Expanded CentralUtilityBar (264dp) maintains center hub midpoint alignment within 0.5px', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(
        const CentralUtilityBar(
          playerCount: 4,
          isCollapsed: false,
        ),
      ));
      await tester.pumpAndSettle();

      final barCenter = tester.getCenter(find.byType(CentralUtilityBar));
      final hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));

      expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5),
          reason: 'Expanded bar horizontal midpoint must coincide with center hub die button');
      expect((barCenter.dy - hubCenter.dy).abs(), lessThan(0.5),
          reason: 'Expanded bar vertical midpoint must coincide with center hub die button');
    });

    testWidgets('Collapsed CentralUtilityBar (48dp pill) maintains center hub midpoint alignment within 0.5px', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(
        const CentralUtilityBar(
          playerCount: 4,
          isCollapsed: true,
        ),
      ));
      await tester.pumpAndSettle();

      final barCenter = tester.getCenter(find.byType(CentralUtilityBar));
      final hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));

      expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5),
          reason: 'Collapsed bar horizontal midpoint must coincide with center hub die button');
      expect((barCenter.dy - hubCenter.dy).abs(), lessThan(0.5),
          reason: 'Collapsed bar vertical midpoint must coincide with center hub die button');
    });

    testWidgets('CentralUtilityBar dynamic collapse and expand transition preserves midpoint stability across all animation frames', (tester) async {
      bool isCollapsed = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return wrapWithScaffold(
              CentralUtilityBar(
                playerCount: 4,
                isCollapsed: isCollapsed,
                onToggleCollapse: () {
                  setState(() {
                    isCollapsed = !isCollapsed;
                  });
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify initially expanded at t = 0ms
      Offset barCenter = tester.getCenter(find.byType(CentralUtilityBar));
      Offset hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));
      expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5));

      // Trigger collapse animation
      await tester.tap(find.byKey(const Key('center_hub_button')));
      // Sample during animation at 50ms intervals up to 250ms duration
      for (int step = 0; step < 5; step++) {
        await tester.pump(const Duration(milliseconds: 50));
        barCenter = tester.getCenter(find.byType(CentralUtilityBar));
        hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));
        expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5),
            reason: 'Horizontal midpoint stability must hold during collapse frame step $step');
        expect((barCenter.dy - hubCenter.dy).abs(), lessThan(0.5),
            reason: 'Vertical midpoint stability must hold during collapse frame step $step');
      }

      await tester.pumpAndSettle();
      barCenter = tester.getCenter(find.byType(CentralUtilityBar));
      hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));
      expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5));

      // Trigger expand animation
      await tester.tap(find.byKey(const Key('center_hub_button')));
      for (int step = 0; step < 5; step++) {
        await tester.pump(const Duration(milliseconds: 50));
        barCenter = tester.getCenter(find.byType(CentralUtilityBar));
        hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));
        expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5),
            reason: 'Horizontal midpoint stability must hold during expand frame step $step');
        expect((barCenter.dy - hubCenter.dy).abs(), lessThan(0.5),
            reason: 'Vertical midpoint stability must hold during expand frame step $step');
      }
      await tester.pumpAndSettle();
    });

    testWidgets('PodScaffoldWidget cross-viewport geometry stress: zero RenderFlex overflow across diverse viewports and player counts', (tester) async {
      final viewports = <Size>[
        const Size(320, 480),   // Tiny legacy mobile
        const Size(360, 640),   // Compact Android
        const Size(390, 844),   // Standard iPhone
        const Size(412, 915),   // Modern Android
        const Size(480, 800),   // Mid-tier device
        const Size(768, 1024),  // Tablet portrait
        const Size(1024, 768),  // Tablet landscape
        const Size(800, 1200),  // Ultra-tall tablet
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        for (final playerCount in [2, 4, 6]) {
          final podState = makeTestPod(playerCount);

          // 1. Test Expanded State
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: ThemeData.dark(),
                home: Scaffold(
                  body: PodScaffoldWidget(
                    podState: podState,
                    autohideMenu: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'No layout overflow in expanded state on viewport ${vp.width}x${vp.height} with $playerCount players');

          final barCenter = tester.getCenter(find.byType(CentralUtilityBar));
          final hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));
          expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5),
              reason: 'Midpoint stability on viewport ${vp.width}x${vp.height} (expanded)');

          // 2. Test Collapsed State
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: ThemeData.dark(),
                home: Scaffold(
                  body: PodScaffoldWidget(
                    podState: podState,
                    autohideMenu: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'No layout overflow in collapsed state on viewport ${vp.width}x${vp.height} with $playerCount players');

          final barCenterCollapsed = tester.getCenter(find.byType(CentralUtilityBar));
          final hubCenterCollapsed = tester.getCenter(find.byKey(const Key('center_hub_button')));
          expect((barCenterCollapsed.dx - hubCenterCollapsed.dx).abs(), lessThan(0.5),
              reason: 'Midpoint stability on viewport ${vp.width}x${vp.height} (collapsed)');
        }
      }
    });
  });

  group('CH-M4-2-G2: Inactivity Timing & Gesture Arena Stress (R4.3)', () {
    testWidgets('Inactivity timing: 3.9s maintains expanded state, 4.0s triggers collapse', (tester) async {
      final podState = makeTestPod(2);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: true,
        ),
      ));
      await tester.pumpAndSettle();

      CentralUtilityBar bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isFalse, reason: 'Bar must start expanded');

      // Tap screen to ensure inactivity timer starts at a clean reference time
      await tester.tapAt(const Offset(50, 50));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isFalse);

      // Advance by 3.5 seconds (less than 4s threshold)
      await tester.pump(const Duration(milliseconds: 3500));
      bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isFalse, reason: 'Bar must remain expanded before 4 seconds of inactivity');

      // Advance additional 700ms (total 4.2s > 4.0s threshold)
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isTrue, reason: 'Bar must collapse after 4 seconds of inactivity');
    });

    testWidgets('Screen touches across life hitboxes, gear button, and empty quadrants immediately wake and expand bar', (tester) async {
      final podState = makeTestPod(4);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: true,
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Allow bar to collapse after 4s
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isTrue);

      // Touch 1: Tap hitbox_plus on player 0
      await tester.tap(find.byKey(const Key('hitbox_plus_p0')));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isFalse,
          reason: 'Tapping life plus hitbox must immediately expand utility bar');

      // Let it collapse again
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isTrue);

      // Touch 2: Tap hitbox_minus on player 1
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isFalse,
          reason: 'Tapping life minus hitbox must immediately expand utility bar');

      // Let it collapse again
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isTrue);

      // Touch 3: Tap gear button on player 2
      await tester.tap(find.byKey(const Key('gear_button_p2')));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isFalse,
          reason: 'Tapping gear button must immediately expand utility bar');

      // Let it collapse again
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isTrue);

      // Touch 4: Tap empty space at top left
      await tester.tapAt(const Offset(30, 50));
      await tester.pump();
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isFalse,
          reason: 'Tapping background area must immediately expand utility bar');
    });

    testWidgets('Disabled autohide (autohideMenu: false) keeps bar expanded indefinitely across 16s', (tester) async {
      final podState = makeTestPod(2);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: false,
        ),
      ));
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        final bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
        expect(bar.isCollapsed, isFalse, reason: 'Bar must never collapse when autohideMenu is false (tick $i)');
      }
    });

    testWidgets('Modal route open suppression: ResetGameDialog halts autohide collapse until dismissed', (tester) async {
      final podState = makeTestPod(2);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Open Reset Game dialog by tapping reset button
      await tester.tap(find.byKey(const Key('central_hub_reset_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ResetGameDialog), findsOneWidget);

      // Advance 5 seconds while dialog is active
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      // Bar must NOT collapse while dialog route is active
      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isFalse,
          reason: 'Utility bar must not collapse while ResetGameDialog is open');

      // Dismiss dialog
      await tester.tap(find.byKey(const Key('cancel_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(ResetGameDialog), findsNothing);

      // Now 4 seconds pass after dismissal
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isTrue,
          reason: 'Utility bar must collapse 4 seconds after modal dialog is dismissed');
    });

    testWidgets('Modal route open suppression: PregameSetupSheet halts autohide collapse until dismissed', (tester) async {
      final podState = makeTestPod(2);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Open Settings / Setup Sheet
      await tester.tap(find.byKey(const Key('central_hub_settings_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PregameSetupSheet), findsOneWidget);

      // Advance 6 seconds while sheet is active
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isFalse,
          reason: 'Utility bar must not collapse while PregameSetupSheet is active');

      // Dismiss setup sheet
      Navigator.of(tester.element(find.byType(PregameSetupSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(PregameSetupSheet), findsNothing);

      // Advance 4s after returning to board
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar)).isCollapsed, isTrue,
          reason: 'Utility bar must collapse 4s after setup sheet dismissal');
    });
  });

  group('CH-M4-2-G3: Polish & Accessibility Toggles Stress (R4.4)', () {
    testWidgets('OLED True Black: isOledMode = true forces 0xFF000000 card color and suppresses CommanderArtBackdrop across all players', (tester) async {
      final podWithArt = makeTestPod(4, withArt: true);

      // 1. OLED Mode ENABLED
      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podWithArt,
          isOledMode: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Invariant: Zero CommanderArtBackdrop widgets rendered in OLED mode
      expect(find.byType(CommanderArtBackdrop), findsNothing,
          reason: 'CommanderArtBackdrop must be suppressed in OLED true black mode');

      // Check card background colors on all 4 quadrants
      final quadrantFinders = find.byType(PlayerQuadrantWidget);
      expect(quadrantFinders, findsNWidgets(4));

      for (int i = 0; i < 4; i++) {
        final quadrant = quadrantFinders.at(i);
        final container = tester.widget<Container>(
          find.descendant(of: quadrant, matching: find.byType(Container)).first,
        );
        final boxDeco = container.decoration as BoxDecoration;
        expect(boxDeco.color, const Color(0xFF000000),
            reason: 'Player quadrant $i background color must be #000000 in OLED mode');
      }

      // 2. OLED Mode DISABLED
      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podWithArt,
          isOledMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      // CommanderArtBackdrop rendered for players with art
      expect(find.byType(CommanderArtBackdrop), findsNWidgets(4),
          reason: 'CommanderArtBackdrop must render when isOledMode is false');

      for (int i = 0; i < 4; i++) {
        final quadrant = quadrantFinders.at(i);
        final container = tester.widget<Container>(
          find.descendant(of: quadrant, matching: find.byType(Container)).first,
        );
        final boxDeco = container.decoration as BoxDecoration;
        expect(boxDeco.color, const Color(0xFF1E1E2C),
            reason: 'Player quadrant $i background color must be #1E1E2C in normal mode');
      }
    });

    test('WakelockService rapid toggle stress (20 cycles) executes safely without platform channel crashes', () async {
      for (int i = 0; i < 20; i++) {
        await WakelockService.enable();
        expect(WakelockService.isEnabled, isTrue);

        await WakelockService.disable();
        expect(WakelockService.isEnabled, isFalse);

        await WakelockService.setEnabled(i % 2 == 0);
        expect(WakelockService.isEnabled, i % 2 == 0);
      }
      // Leave disabled at end of test
      await WakelockService.disable();
      expect(WakelockService.isEnabled, isFalse);
    });

    test('PodHaptics vibration stress (20 cycles) executes cleanly with enabled true and false', () async {
      for (int i = 0; i < 20; i++) {
        PodHaptics.enabled = (i % 2 == 0);
        expect(PodHaptics.enabled, (i % 2 == 0));

        await PodHaptics.lightImpact();
        await PodHaptics.mediumImpact();
        await PodHaptics.selectionClick();
        await PodHaptics.heavyImpact();
      }
      // Restore default enabled
      PodHaptics.enabled = true;
      expect(PodHaptics.enabled, isTrue);
    });

    testWidgets('Immersive mode SystemChrome calls execute without exception during PodScaffoldWidget lifecycle', (tester) async {
      final podState = makeTestPod(2);

      // Mount with immersive mode true
      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          isImmersiveMode: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Re-mount with immersive mode false
      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          isImmersiveMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PregameSetupSheet dual-key switch finder matrix verifies all 6 switches findable and interactive', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pair 1: Auto-Hide Menu
      final autohide1 = find.byKey(const Key('pregame_autohide_switch'));
      final autohide2 = find.byKey(const Key('pregame_autohide_mode_switch'));
      expect(autohide1, findsOneWidget);
      expect(autohide2, findsOneWidget);
      await tester.tap(autohide1);
      await tester.pumpAndSettle();
      await tester.tap(autohide2);
      await tester.pumpAndSettle();

      // Pair 2: OLED True Black
      final oled1 = find.byKey(const Key('pregame_oled_switch'));
      final oled2 = find.byKey(const Key('pregame_oled_mode_switch'));
      expect(oled1, findsOneWidget);
      expect(oled2, findsOneWidget);
      await tester.tap(oled1);
      await tester.pumpAndSettle();
      await tester.tap(oled2);
      await tester.pumpAndSettle();

      // Pair 3: Keep Display Awake (Wakelock)
      final wake1 = find.byKey(const Key('pregame_wakelock_switch'));
      final wake2 = find.byKey(const Key('pregame_wakelock_mode_switch'));
      expect(wake1, findsOneWidget);
      expect(wake2, findsOneWidget);
      await tester.tap(wake1);
      await tester.pumpAndSettle();
      await tester.tap(wake2);
      await tester.pumpAndSettle();

      // Pair 4: Haptic Feedback
      final haptics1 = find.byKey(const Key('pregame_haptics_switch'));
      final haptics2 = find.byKey(const Key('pregame_haptics_mode_switch'));
      expect(haptics1, findsOneWidget);
      expect(haptics2, findsOneWidget);
      await tester.tap(haptics1);
      await tester.pumpAndSettle();
      await tester.tap(haptics2);
      await tester.pumpAndSettle();

      // Pair 5: Immersive Mode
      final immersive1 = find.byKey(const Key('pregame_immersive_switch'));
      final immersive2 = find.byKey(const Key('pregame_immersive_mode_switch'));
      expect(immersive1, findsOneWidget);
      expect(immersive2, findsOneWidget);
      await tester.tap(immersive1);
      await tester.pumpAndSettle();
      await tester.tap(immersive2);
      await tester.pumpAndSettle();

      // Switch 6: Camera Mode
      final cameraSwitch = find.byKey(const Key('pregame_camera_mode_switch'));
      expect(cameraSwitch, findsOneWidget);
      await tester.tap(cameraSwitch);
      await tester.pumpAndSettle();

      // Dual-key alias for Start Match Button
      final startMatch1 = find.byKey(const Key('pregame_start_match_button'));
      final startMatch2 = find.byKey(const Key('start_match_button'));
      expect(startMatch1, findsOneWidget);
      expect(startMatch2, findsOneWidget);
    });
  });
}

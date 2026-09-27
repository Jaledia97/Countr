// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Pod Geometry & Inversion Stress Test Suite.
// Stress tests 1v1 to 6P layout geometries under adversarial screen dimensions,
// orientations, extreme values, 180° inverted hit-test geometry, and accessibility scaling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PodState createPod(int playerCount, {int startingLife = 40}) {
    return PodState(
      sessionId: 'adv_test_session',
      format: 'commander',
      startingLife: startingLife,
      players: List.generate(
        playerCount,
        (i) => PodPlayerState(
          id: 'p${i + 1}',
          seatIndex: i,
          name: 'Player ${i + 1}',
          life: startingLife,
        ),
      ),
    );
  }

  Future<void> pumpPodWithSize(
    WidgetTester tester, {
    required PodState state,
    required Size size,
    double textScale = 1.0,
    void Function(String playerId, int delta)? onLifeDelta,
    void Function(String targetId, String sourceId, int delta)? onCommanderDamage,
    void Function(String playerId, String color, int delta)? onManaDelta,
    VoidCallback? onRandomizerPressed,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: PodScaffoldWidget(
            podState: state,
            onLifeDelta: onLifeDelta,
            onCommanderDamage: onCommanderDamage,
            onManaDelta: onManaDelta,
            onRandomizerPressed: onRandomizerPressed,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // =========================================================================
  // SUITE 1: Extreme Resolution & Aspect Ratio Matrix (1v1 to 6P)
  // =========================================================================
  group('Adversarial Viewport & Layout Geometry Matrix', () {
    final viewports = <String, Size>{
      'Tiny Phone (320x480)': const Size(320, 480),
      'Tiny Landscape (480x320)': const Size(480, 320),
      'Foldable Cover Narrow (280x653)': const Size(280, 653),
      'Foldable Landscape (653x280)': const Size(653, 280),
      'Budget Android (360x640)': const Size(360, 640),
      'Standard Phone (390x844)': const Size(390, 844),
      'Standard Phone Landscape (844x390)': const Size(844, 390),
      'Small Tablet (600x960)': const Size(600, 960),
      'iPad Portrait (768x1024)': const Size(768, 1024),
      'iPad Landscape (1024x768)': const Size(1024, 768),
      'Large Tablet (1200x800)': const Size(1200, 800),
      'Ultra-Wide Tablet (1600x1200)': const Size(1600, 1200),
      'Extreme High-Res (2560x1600)': const Size(2560, 1600),
    };

    for (final count in [1, 2, 3, 4, 5, 6]) {
      for (final entry in viewports.entries) {
        testWidgets('$count-Player on ${entry.key} renders without RenderFlex overflow', (tester) async {
          final state = createPod(count);
          await pumpPodWithSize(tester, state: state, size: entry.value);

          // Verify all player quadrants exist
          for (int i = 1; i <= count; i++) {
            expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
          }

          // Verify CenterHubButton exists
          expect(find.byKey(const Key('center_hub_button')), findsOneWidget);

          // Assert zero Flutter layout exceptions (no RenderFlex overflow)
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // =========================================================================
  // SUITE 2: 180° Inversion Hit-Test Transformation Stress
  // =========================================================================
  group('180° Opposing Inversion Hit-Test Verification', () {
    testWidgets('1v1: Top player (p2) rotated 180° correctly transforms minus and plus hitboxes', (tester) async {
      int p1Delta = 0;
      int p2Delta = 0;

      final state = createPod(2, startingLife: 40);
      await pumpPodWithSize(
        tester,
        state: state,
        size: const Size(400, 800),
        onLifeDelta: (id, delta) {
          if (id == 'p1') p1Delta += delta;
          if (id == 'p2') p2Delta += delta;
        },
      );

      // Verify p2 is rotated 180° (quarterTurns: 2)
      final p2Rotated = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)),
      );
      expect(p2Rotated.quarterTurns, 2);

      // Tap p2's plus hitbox
      final p2Plus = find.byKey(const Key('hitbox_plus_p2'));
      expect(p2Plus, findsOneWidget);
      await tester.tap(p2Plus);
      await tester.pump();
      expect(p2Delta, 1);
      expect(p1Delta, 0);

      // Tap p2's minus hitbox
      final p2Minus = find.byKey(const Key('hitbox_minus_p2'));
      expect(p2Minus, findsOneWidget);
      await tester.tap(p2Minus);
      await tester.pump();
      expect(p2Delta, 0); // 1 + (-1) = 0
      expect(p1Delta, 0);

      // Tap p1's plus hitbox
      final p1Plus = find.byKey(const Key('hitbox_plus_p1'));
      await tester.tap(p1Plus);
      await tester.pump();
      expect(p1Delta, 1);
      expect(p2Delta, 0);
    });

    testWidgets('4P: Inverted seats (p2, p3) have plus on left and minus on right of screen space', (tester) async {
      final state = createPod(4, startingLife: 40);
      await pumpPodWithSize(tester, state: state, size: const Size(400, 800));

      // For unrotated P1 (bottom left):
      // minus hitbox is on left (dx ~50), plus hitbox is on right (dx ~150)
      final p1MinusCenter = tester.getCenter(find.byKey(const Key('hitbox_minus_p1')));
      final p1PlusCenter = tester.getCenter(find.byKey(const Key('hitbox_plus_p1')));
      expect(p1MinusCenter.dx, lessThan(p1PlusCenter.dx));

      // For rotated P2 (top left):
      // Because rotated 180°, minus hitbox is now visually on the right of its quadrant,
      // and plus hitbox is on the left of its quadrant!
      final p2MinusCenter = tester.getCenter(find.byKey(const Key('hitbox_minus_p2')));
      final p2PlusCenter = tester.getCenter(find.byKey(const Key('hitbox_plus_p2')));
      expect(p2PlusCenter.dx, lessThan(p2MinusCenter.dx));

      // This confirms: For the player sitting across the table, their visual left is minus and visual right is plus!
      // Flawless ergonomic inversion.
    });

    testWidgets('6P: All 3 top seats (p2, p3, p4) maintain 180° rotation and independent tap isolation', (tester) async {
      final deltas = <String, int>{};
      final state = createPod(6, startingLife: 40);

      await pumpPodWithSize(
        tester,
        state: state,
        size: const Size(600, 900),
        onLifeDelta: (id, delta) {
          deltas[id] = (deltas[id] ?? 0) + delta;
        },
      );

      for (final id in ['p2', 'p3', 'p4']) {
        final rotated = tester.widget<RotatedBox>(
          find.ancestor(of: find.byKey(Key('quadrant_$id')), matching: find.byType(RotatedBox)),
        );
        expect(rotated.quarterTurns, 2);

        // Tap plus on each top player
        await tester.tap(find.byKey(Key('hitbox_plus_$id')));
        await tester.pump();
        expect(deltas[id], 1);
      }

      // Bottom players unaffected
      expect(deltas['p1'], isNull);
      expect(deltas['p5'], isNull);
      expect(deltas['p6'], isNull);
    });
  });

  // =========================================================================
  // SUITE 3: Extreme Content Stress (Massive Life, Huge Names, Multiple Badges)
  // =========================================================================
  group('Extreme Content & Status Stress Tests', () {
    testWidgets('Quadrant survives extreme life values (99999, -999) without overflow', (tester) async {
      final extremeState = PodState(
        sessionId: 'extreme_vals',
        format: 'commander',
        startingLife: 40,
        players: [
          const PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 99999),
          const PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: -999),
          const PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 0),
          const PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 1000000),
        ],
      );

      await pumpPodWithSize(tester, state: extremeState, size: const Size(360, 640));

      expect(find.text('99999'), findsOneWidget);
      expect(find.text('-999'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1000000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Quadrant handles long names, tax, monarch, initiative, and lethal banners simultaneously', (tester) async {
      final loadedPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Lord Niv-Mizzet the Firemind Supreme Dracogenius',
        life: 40,
        poison: 12, // Lethal poison
        energy: 99,
        experience: 50,
        commanderTax: 10,
        isMonarch: true,
        hasInitiative: true,
        commanderDamageTaken: {'p2': 25}, // Lethal cmd damage
      );

      final state = PodState(
        sessionId: 'loaded_player',
        format: 'commander',
        startingLife: 40,
        players: [
          loadedPlayer,
          const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWithSize(tester, state: state, size: const Size(360, 640));

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.byKey(const Key('poison_lethal_alert_p1')), findsOneWidget);
      expect(find.byKey(const Key('chip_monarch')), findsOneWidget);
      expect(find.byKey(const Key('chip_initiative')), findsOneWidget);
      expect(find.text('Tax: +20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // SUITE 4: Phone Drawer Stress in Crowded Pods
  // =========================================================================
  group('Phone Drawer Interactions in Crowded Pods', () {
    testWidgets('6-player pod on 360x640 phone opens drawer without overflow', (tester) async {
      final state = createPod(6, startingLife: 40);
      await pumpPodWithSize(tester, state: state, size: const Size(360, 640));

      // Find drawer toggle for p1
      final toggleP1 = find.byKey(const Key('drawer_toggle_p1'));
      expect(toggleP1, findsOneWidget);

      // Open drawer
      await tester.tap(toggleP1);
      await tester.pump();

      // Drawer panel is visible
      expect(find.byKey(const Key('drawer_panel_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close drawer
      await tester.tap(toggleP1);
      await tester.pump();
      expect(find.byKey(const Key('drawer_panel_p1')), findsNothing);
    });

    testWidgets('Opening floating mana modal from drawer works cleanly', (tester) async {
      final state = createPod(4, startingLife: 40);
      await pumpPodWithSize(tester, state: state, size: const Size(390, 844));

      // Open phone drawer
      await tester.tap(find.byKey(const Key('drawer_toggle_p1')));
      await tester.pump();

      // The tool drawer contains horizontal steppers that exceed quadrant width on narrow phones.
      // Scroll to reveal the mana button before tapping.
      final manaBtn = find.byKey(const Key('mana_drawer_btn_p1'));
      expect(manaBtn, findsOneWidget);
      await tester.scrollUntilVisible(manaBtn, 50.0, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();

      await tester.tap(manaBtn);
      await tester.pumpAndSettle();

      // Mana modal sheet should be displayed
      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsOneWidget);
      expect(find.text('Mana Pool & Storm: Player 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dismiss modal by tapping outside or via Clear Pool
      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsNothing);
    });
  });

  // =========================================================================
  // SUITE 5: Accessibility Font Scaling Stress
  // =========================================================================
  group('Accessibility Font Scaling Stress Tests', () {
    testWidgets('1v1 pod with 1.5x font scaling renders cleanly', (tester) async {
      final state = createPod(2, startingLife: 40);
      await pumpPodWithSize(
        tester,
        state: state,
        size: const Size(390, 844),
        textScale: 1.5,
      );

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4P pod with 1.3x font scaling on phone renders cleanly', (tester) async {
      final state = createPod(4, startingLife: 40);
      await pumpPodWithSize(
        tester,
        state: state,
        size: const Size(400, 800),
        textScale: 1.3,
      );

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p4')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

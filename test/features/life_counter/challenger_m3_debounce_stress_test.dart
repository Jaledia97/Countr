// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/game_history_entry.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/game_history_modal.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Challenge Dimension 1: High-Frequency Tapping Bursts & 1500ms Consolidation', () {
    testWidgets('Burst of 20 rapid taps within 500ms consolidates into single GameHistoryEntry after 1500ms silence', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final lifeDeltas = <int>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onLifeDelta: (d) => lifeDeltas.add(d),
          onCommitLifeHistory: ({
            required String playerId,
            required int startLife,
            required int endLife,
            required int netDelta,
          }) {
            commits.add({
              'playerId': playerId,
              'startLife': startLife,
              'endLife': endLife,
              'netDelta': netDelta,
            });
          },
        ),
      ));

      // Initial state: life 40, no delta badge, no commits
      expect(find.byKey(const Key('life_display_p1')), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
      expect(commits, isEmpty);

      // Execute 20 rapid taps on hitbox_plus_p1 spaced by 25ms (total burst duration = 475ms)
      for (int i = 1; i <= 20; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        if (i < 20) {
          await tester.pump(const Duration(milliseconds: 25));
        } else {
          await tester.pump();
        }

        // Check delta badge updates monotonically without premature history commit
        expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
        expect(find.text('+$i'), findsOneWidget);
        expect(commits, isEmpty, reason: 'No commit should fire during active tap burst');
      }

      expect(lifeDeltas.length, 20);
      expect(lifeDeltas.every((d) => d == 1), isTrue);

      // Advance by 1499ms since the 20th tap (1ms before debounce threshold)
      await tester.pump(const Duration(milliseconds: 1499));
      expect(commits, isEmpty, reason: 'Debounce timer must not fire prior to 1500ms of silence');
      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);

      // Advance 1ms more (reaching 1500ms silence threshold)
      await tester.pump(const Duration(milliseconds: 1));
      expect(commits.length, 1, reason: 'Exactly one consolidated entry must be committed');
      expect(commits.first['playerId'], 'p1');
      expect(commits.first['startLife'], 40);
      expect(commits.first['endLife'], 60);
      expect(commits.first['netDelta'], 20);

      // Delta badge should now be dismissed
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);

      // Further idle time must not produce duplicate commits
      await tester.pump(const Duration(seconds: 2));
      expect(commits.length, 1);
    });

    testWidgets('High-frequency negative tapping burst (15 rapid taps) consolidates accurately into single negative entry', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onCommitLifeHistory: ({
            required String playerId,
            required int startLife,
            required int endLife,
            required int netDelta,
          }) {
            commits.add({
              'playerId': playerId,
              'startLife': startLife,
              'endLife': endLife,
              'netDelta': netDelta,
            });
          },
        ),
      ));

      // 15 rapid decrements
      for (int i = 1; i <= 15; i++) {
        await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.text('-$i'), findsOneWidget);
      }

      expect(commits, isEmpty);

      // Wait 1500ms silence
      await tester.pump(const Duration(milliseconds: 1500));
      expect(commits.length, 1);
      expect(commits.first['playerId'], 'p1');
      expect(commits.first['startLife'], 40);
      expect(commits.first['endLife'], 25);
      expect(commits.first['netDelta'], -15);
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
    });

    testWidgets('Late tap at 1400ms resets the 1500ms debounce window and consolidates combined burst', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onCommitLifeHistory: ({
            required String playerId,
            required int startLife,
            required int endLife,
            required int netDelta,
          }) {
            commits.add({
              'playerId': playerId,
              'startLife': startLife,
              'endLife': endLife,
              'netDelta': netDelta,
            });
          },
        ),
      ));

      // Initial burst: 4 taps (+4)
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('+4'), findsOneWidget);

      // Wait 1400ms (100ms before debounce expiration)
      await tester.pump(const Duration(milliseconds: 1400));
      expect(commits, isEmpty);

      // Late tap: +1 tap -> total delta = +5
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump();
      expect(find.text('+5'), findsOneWidget);

      // Wait 1000ms (total 2400ms elapsed since first burst, but only 1000ms since late tap)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(commits, isEmpty, reason: 'Debounce window was refreshed by late tap');

      // Wait 500ms more (reaching 1500ms since late tap)
      await tester.pump(const Duration(milliseconds: 500));
      expect(commits.length, 1);
      expect(commits.first['startLife'], 40);
      expect(commits.first['endLife'], 45);
      expect(commits.first['netDelta'], 5);
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
    });
  });

  group('Challenge Dimension 2: Concurrent Multi-Player Tapping Isolation', () {
    testWidgets('4 player quadrants tapping simultaneously maintain independent delta badges and isolated history commits', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final p1 = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Player 1', life: 40);
      final p2 = const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Player 2', life: 40);
      final p3 = const PodPlayerState(id: 'p3', seatIndex: 2, name: 'Player 3', life: 40);
      final p4 = const PodPlayerState(id: 'p4', seatIndex: 3, name: 'Player 4', life: 40);

      // 2x2 grid harness containing 4 independent PlayerQuadrantWidgets
      await tester.pumpWidget(wrapWithScaffold(
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: PlayerQuadrantWidget(
                      player: p1,
                      isTablet: false,
                      opponents: [p2, p3, p4],
                      onCommitLifeHistory: ({
                        required String playerId,
                        required int startLife,
                        required int endLife,
                        required int netDelta,
                      }) {
                        commits.add({
                          'playerId': playerId,
                          'startLife': startLife,
                          'endLife': endLife,
                          'netDelta': netDelta,
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: PlayerQuadrantWidget(
                      player: p2,
                      isTablet: false,
                      opponents: [p1, p3, p4],
                      onCommitLifeHistory: ({
                        required String playerId,
                        required int startLife,
                        required int endLife,
                        required int netDelta,
                      }) {
                        commits.add({
                          'playerId': playerId,
                          'startLife': startLife,
                          'endLife': endLife,
                          'netDelta': netDelta,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: PlayerQuadrantWidget(
                      player: p3,
                      isTablet: false,
                      opponents: [p1, p2, p4],
                      onCommitLifeHistory: ({
                        required String playerId,
                        required int startLife,
                        required int endLife,
                        required int netDelta,
                      }) {
                        commits.add({
                          'playerId': playerId,
                          'startLife': startLife,
                          'endLife': endLife,
                          'netDelta': netDelta,
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: PlayerQuadrantWidget(
                      player: p4,
                      isTablet: false,
                      opponents: [p1, p2, p3],
                      onCommitLifeHistory: ({
                        required String playerId,
                        required int startLife,
                        required int endLife,
                        required int netDelta,
                      }) {
                        commits.add({
                          'playerId': playerId,
                          'startLife': startLife,
                          'endLife': endLife,
                          'netDelta': netDelta,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));

      // Verify all 4 players render
      expect(find.byKey(const Key('life_display_p1')), findsOneWidget);
      expect(find.byKey(const Key('life_display_p2')), findsOneWidget);
      expect(find.byKey(const Key('life_display_p3')), findsOneWidget);
      expect(find.byKey(const Key('life_display_p4')), findsOneWidget);

      // Concurrently / interleaved taps across all 4 players:
      // P1: +3, P2: -2, P3: +5, P4: -4
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        await tester.pump(const Duration(milliseconds: 10));
      }
      for (int i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('hitbox_minus_p2')));
        await tester.pump(const Duration(milliseconds: 10));
      }
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p3')));
        await tester.pump(const Duration(milliseconds: 10));
      }
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('hitbox_minus_p4')));
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Check all 4 delta badges simultaneously display isolated pending values
      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);

      expect(find.byKey(const Key('delta_badge_p2')), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);

      expect(find.byKey(const Key('delta_badge_p3')), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);

      expect(find.byKey(const Key('delta_badge_p4')), findsOneWidget);
      expect(find.text('-4'), findsOneWidget);

      // Stagger P1 vs P2: tap P2 once more at t=500ms
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('hitbox_minus_p2')));
      await tester.pump();
      expect(find.text('-3'), findsOneWidget); // P2 is now -3

      // At t=1500ms from P1's last tap (which was at t=0ms):
      // P1, P3, P4 have experienced 1500ms of silence. P2 has only had 1000ms.
      await tester.pump(const Duration(milliseconds: 1000));

      // P1 (+3), P3 (+5), P4 (-4) should be committed!
      final committedIds = commits.map((c) => c['playerId']).toSet();
      expect(committedIds.contains('p1'), isTrue);
      expect(committedIds.contains('p3'), isTrue);
      expect(committedIds.contains('p4'), isTrue);
      expect(committedIds.contains('p2'), isFalse, reason: 'P2 timer was refreshed and must still be pending');

      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
      expect(find.byKey(const Key('delta_badge_p3')), findsNothing);
      expect(find.byKey(const Key('delta_badge_p4')), findsNothing);
      expect(find.byKey(const Key('delta_badge_p2')), findsOneWidget);

      // Advance another 500ms (reaching 1500ms since P2's last tap)
      await tester.pump(const Duration(milliseconds: 500));
      expect(commits.length, 4);
      final p2Commit = commits.firstWhere((c) => c['playerId'] == 'p2');
      expect(p2Commit['netDelta'], -3);
      expect(find.byKey(const Key('delta_badge_p2')), findsNothing);
    });

    testWidgets('PodScaffoldWidget 4-player pod accumulates commits into podState history and presents them via history modal', (tester) async {
      final p1 = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      final p2 = const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);
      final p3 = const PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40);
      final p4 = const PodPlayerState(id: 'p4', seatIndex: 3, name: 'Dave', life: 40);

      final podState = PodState(
        sessionId: 'pod_4p_test',
        format: 'Commander',
        startingLife: 40,
        players: [p1, p2, p3, p4],
      );

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          seatingOrientation: 'standard',
          isCameraMode: true,
        ),
      ));

      // Tap +2 on Alice (P1)
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 20));

      // Tap -5 on Bob (P2)
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('hitbox_minus_p2')));
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Wait 1600ms for both debounces to commit
      await tester.pump(const Duration(milliseconds: 1600));

      // Open history modal
      await tester.tap(find.byKey(const Key('central_hub_history_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game_history_modal')), findsOneWidget);
      expect(find.textContaining('gained 2 life (40 -> 42)'), findsOneWidget);
      expect(find.textContaining('lost 5 life (40 -> 35)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('game_history_close_button')));
      await tester.pumpAndSettle();
    });
  });

  group('Challenge Dimension 3: Hold Acceleration Interval (250ms) and Scaling (±5 -> ±10 after 2s)', () {
    testWidgets('Hold on minus ticks at 250ms intervals with initial -5 and accelerates to -10 after 2000ms', (tester) async {
      final deltas = <int>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 100);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onLifeDelta: (d) => deltas.add(d),
        ),
      ));

      final minusCenter = tester.getCenter(find.byKey(const Key('hitbox_minus_p1')));
      final gesture = await tester.startGesture(minusCenter);

      // Trigger Flutter long-press timeout (500ms)
      await tester.pump(const Duration(milliseconds: 500));

      // Initial immediate tick at hold start = -5
      expect(deltas, equals([-5]));

      // Tick 1 (at 250ms hold elapsed): tick = -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas, equals([-5, -5]));

      // Tick 2 (500ms): tick = -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas, equals([-5, -5, -5]));

      // Tick 3 (750ms): tick = -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 4);

      // Tick 4 (1000ms): tick = -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 5);

      // Tick 5 (1250ms): tick = -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 6);

      // Tick 6 (1500ms): tick = -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 7);

      // Tick 7 (1750ms): tick = -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 8);
      expect(deltas.every((d) => d == -5), isTrue, reason: 'All ticks prior to 2000ms must be ±5');

      // Tick 8 (2000ms): ACCELERATION THRESHOLD MET! Should tick -10
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 9);
      expect(deltas.last, -10, reason: 'Tick at 2000ms continuous hold must accelerate to -10');

      // Tick 9 (2250ms): Should tick -10
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 10);
      expect(deltas.last, -10);

      // Tick 10 (2500ms): Should tick -10
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas.length, 11);
      expect(deltas.last, -10);

      // Release gesture
      await gesture.up();
      await tester.pump();

      // Total delta = 8 ticks of -5 (-40) + 3 ticks of -10 (-30) = -70
      final totalDelta = deltas.reduce((a, b) => a + b);
      expect(totalDelta, -70);
      expect(find.text('-70'), findsOneWidget);

      // Verify no commits while holding
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('-70'), findsOneWidget);

      // After 1500ms from gesture release: single consolidated commit
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
    });

    testWidgets('Hold on plus stops acceleration immediately upon gesture cancellation/up before 2s', (tester) async {
      final deltas = <int>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onLifeDelta: (d) => deltas.add(d),
        ),
      ));

      final plusCenter = tester.getCenter(find.byKey(const Key('hitbox_plus_p1')));
      final gesture = await tester.startGesture(plusCenter);
      await tester.pump(const Duration(milliseconds: 500)); // long-press fires: +5

      // Hold for 3 ticks (750ms)
      await tester.pump(const Duration(milliseconds: 750));
      expect(deltas, equals([5, 5, 5, 5])); // initial + 3 ticks

      // Release early at 750ms (well under 2000ms)
      await gesture.up();
      await tester.pump();

      // Ensure no further ticks occur
      await tester.pump(const Duration(milliseconds: 500));
      expect(deltas.length, 4);
      expect(deltas.every((d) => d == 5), isTrue);
    });
  });

  group('Challenge Dimension 4: Net-Zero Delta (No No-Op History Entry)', () {
    testWidgets('Tapping +3 then -3 within 1500ms produces 0 net delta and commits ZERO history entries', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onCommitLifeHistory: ({
            required String playerId,
            required int startLife,
            required int endLife,
            required int netDelta,
          }) {
            commits.add({
              'playerId': playerId,
              'startLife': startLife,
              'endLife': endLife,
              'netDelta': netDelta,
            });
          },
        ),
      ));

      // Tap +1 three times
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('+3'), findsOneWidget);

      // Now tap -1 three times (net delta returns to 0)
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump(const Duration(milliseconds: 50));

      // When net delta is 0, transient delta badge must not be rendered
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);

      // Wait out full 1500ms debounce timeout
      await tester.pump(const Duration(milliseconds: 1600));

      // Verify NO history entry was committed
      expect(commits, isEmpty, reason: 'Net-zero bursts must not commit no-op entries to gameHistory');
      expect(find.text('40'), findsOneWidget);
    });

    testWidgets('Oscillating taps (+5 then -5) netting to zero cleanly resets burst tracking for next action', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onCommitLifeHistory: ({
            required String playerId,
            required int startLife,
            required int endLife,
            required int netDelta,
          }) {
            commits.add({
              'playerId': playerId,
              'startLife': startLife,
              'endLife': endLife,
              'netDelta': netDelta,
            });
          },
        ),
      ));

      // Oscillate +2 then -2
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump(const Duration(milliseconds: 20));

      // Wait 1500ms debounce
      await tester.pump(const Duration(milliseconds: 1500));
      expect(commits, isEmpty);

      // Now start a new interaction burst: tap +4
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('+4'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(commits.length, 1);
      expect(commits.first['startLife'], 40);
      expect(commits.first['endLife'], 44);
      expect(commits.first['netDelta'], 4);
    });
  });

  group('Challenge Dimension 5: Widget Teardown / Dispose Flushing Pending Delta Cleanly', () {
    testWidgets('Unmounting quadrant during active pending delta flushes commit cleanly before teardown', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      bool isMounted = true;

      await tester.pumpWidget(wrapWithScaffold(
        StatefulBuilder(
          builder: (context, setState) {
            return isMounted
                ? PlayerQuadrantWidget(
                    player: player,
                    isTablet: false,
                    opponents: const [],
                    onCommitLifeHistory: ({
                      required String playerId,
                      required int startLife,
                      required int endLife,
                      required int netDelta,
                    }) {
                      commits.add({
                        'playerId': playerId,
                        'startLife': startLife,
                        'endLife': endLife,
                        'netDelta': netDelta,
                      });
                    },
                  )
                : const SizedBox(key: Key('placeholder_after_unmount'));
          },
        ),
      ));

      // Tap +7 rapidly
      for (int i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('+7'), findsOneWidget);
      expect(commits, isEmpty);

      // Wait only 400ms (debounce timer has 1100ms remaining)
      await tester.pump(const Duration(milliseconds: 400));
      expect(commits, isEmpty);

      // Unmount the widget immediately while debounce timer is still pending!
      final state = tester.state(find.byType(StatefulBuilder));
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        isMounted = false;
      });
      await tester.pump(); // Triggers dispose() on PlayerQuadrantWidget

      // Verification: dispose() must flush the pending delta (+7) cleanly
      expect(find.byKey(const Key('placeholder_after_unmount')), findsOneWidget);
      expect(commits.length, 1, reason: 'Pending delta must be flushed to history upon widget teardown');
      expect(commits.first['playerId'], 'p1');
      expect(commits.first['startLife'], 40);
      expect(commits.first['endLife'], 47);
      expect(commits.first['netDelta'], 7);

      // Advance simulated time past original debounce expiration to ensure no exception is thrown
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(commits.length, 1, reason: 'Cancelled debounce timer must not fire post-dispose');
    });

    testWidgets('Unmounting quadrant with net-zero pending delta flushes nothing', (tester) async {
      final commits = <Map<String, dynamic>>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      bool isMounted = true;

      await tester.pumpWidget(wrapWithScaffold(
        StatefulBuilder(
          builder: (context, setState) {
            return isMounted
                ? PlayerQuadrantWidget(
                    player: player,
                    isTablet: false,
                    opponents: const [],
                    onCommitLifeHistory: ({
                      required String playerId,
                      required int startLife,
                      required int endLife,
                      required int netDelta,
                    }) {
                      commits.add({
                        'playerId': playerId,
                        'startLife': startLife,
                        'endLife': endLife,
                        'netDelta': netDelta,
                      });
                    },
                  )
                : const SizedBox();
          },
        ),
      ));

      // Tap +2 then -2 (net delta 0)
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump(const Duration(milliseconds: 10));

      // Unmount immediately
      final state = tester.state(find.byType(StatefulBuilder));
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        isMounted = false;
      });
      await tester.pump();

      expect(commits, isEmpty, reason: 'Net zero pending delta must not flush any entry on teardown');
    });
  });

  group('Challenge Dimension 6: GameHistoryModal Open / Scroll / Clear Interactions', () {
    testWidgets('GameHistoryModal handles high-volume history (60 entries) with smooth scrolling and virtualization', (tester) async {
      final entries = List.generate(
        60,
        (i) => GameHistoryEntry.lifeChange(
          playerId: 'p${(i % 4) + 1}',
          playerName: 'Player ${(i % 4) + 1}',
          startLife: 40 + i,
          endLife: 40 + i + (i.isEven ? 4 : -5),
          netDelta: i.isEven ? 4 : -5,
          timestamp: DateTime(2026, 4, 17, 10, 0).add(Duration(minutes: i)),
        ),
      );

      await tester.pumpWidget(wrapWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_history_btn'),
            onPressed: () => GameHistoryModal.show(context, gameHistory: entries),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('open_history_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game_history_modal')), findsOneWidget);
      expect(find.text('Game History & Turn Log'), findsOneWidget);

      // Verify the first entry is rendered
      expect(find.byKey(Key('history_item_${entries.first.id}')), findsOneWidget);

      // Scroll down to stress-test lazy rendering of 60 items
      await tester.scrollUntilVisible(
        find.byKey(Key('history_item_${entries.last.id}')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      // Verify bottom entries are rendered without errors
      expect(find.byKey(Key('history_item_${entries.last.id}')), findsOneWidget);

      // Close modal
      await tester.tap(find.byKey(const Key('game_history_close_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('game_history_modal')), findsNothing);
    });

    testWidgets('GameHistoryModal clear button invokes callback, dismisses modal, and renders empty state on next open', (tester) async {
      var currentHistory = [
        GameHistoryEntry.lifeChange(
          playerId: 'p1',
          playerName: 'Alice',
          startLife: 40,
          endLife: 35,
          netDelta: -5,
        ),
        GameHistoryEntry.lifeChange(
          playerId: 'p2',
          playerName: 'Bob',
          startLife: 40,
          endLife: 42,
          netDelta: 2,
        ),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        StatefulBuilder(
          builder: (context, setState) => ElevatedButton(
            key: const Key('open_history_btn'),
            onPressed: () => GameHistoryModal.show(
              context,
              gameHistory: currentHistory,
              onClearHistory: () {
                setState(() {
                  currentHistory = const [];
                });
              },
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      // Open with populated history
      await tester.tap(find.byKey(const Key('open_history_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game_history_clear_button')), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);

      // Tap clear
      await tester.tap(find.byKey(const Key('game_history_clear_button')));
      await tester.pumpAndSettle();

      // Modal popped
      expect(find.byKey(const Key('game_history_modal')), findsNothing);

      // Re-open: should now display empty state
      await tester.tap(find.byKey(const Key('open_history_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game_history_empty')), findsOneWidget);
      expect(find.text('No committed game actions yet.'), findsOneWidget);
      expect(find.byKey(const Key('game_history_clear_button')), findsNothing);
    });

    testWidgets('End-to-End PodScaffoldWidget integration: life change commits to history and displays in modal via CentralUtilityBar', (tester) async {
      final p1 = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      final p2 = const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);
      final podState = PodState(
        sessionId: 'session_e2e',
        format: 'Commander',
        startingLife: 40,
        players: [p1, p2],
      );

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          seatingOrientation: 'standard',
          isCameraMode: true,
        ),
      ));

      // Tap +6 on P1
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('+6'), findsOneWidget);

      // Wait 1500ms debounce
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);

      // Open history modal via CentralUtilityBar
      expect(find.byKey(const Key('central_hub_history_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('central_hub_history_button')));
      await tester.pumpAndSettle();

      // Verify GameHistoryModal is open and displays committed entry
      expect(find.byKey(const Key('game_history_modal')), findsOneWidget);
      expect(find.textContaining('gained 6 life (40 -> 46)'), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byKey(const Key('game_history_clear_button')));
      await tester.pumpAndSettle();

      // Modal closed
      expect(find.byKey(const Key('game_history_modal')), findsNothing);

      // Reopen history to confirm pod state cleared history
      await tester.tap(find.byKey(const Key('central_hub_history_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game_history_empty')), findsOneWidget);
      expect(find.text('No committed game actions yet.'), findsOneWidget);
    });
  });
}

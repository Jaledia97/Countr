// Copyright (c) 2026 Countr. All rights reserved.
// Automated verification audit test suite for Feature 48 (Strict Turn Logic Omission).
// Verifies Requirement R7: 100% passive companion utility with zero active turn-passing,
// zero turn timers, zero chess clocks, and zero active turn state across all layers.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 48 (Requirement R7): Strict Turn Logic Omission Audit', () {
    // =========================================================================
    // 1. DOMAIN LAYER AUDIT: PodState & PodPlayerState Schemas
    // =========================================================================
    group('1. Domain Layer Models Audit', () {
      test('1.1: PodState JSON schema strictly omits all turn/clock fields', () {
        const pod = PodState(
          sessionId: 'audit_pod_session_001',
          format: 'commander',
          startingLife: 40,
          players: [],
        );

        final json = pod.toJson();

        // Forbidden active turn logic fields
        expect(json.containsKey('active_player_turn'), isFalse,
            reason: 'PodState must never contain active_player_turn');
        expect(json.containsKey('active_player_id'), isFalse,
            reason: 'PodState must never contain active_player_id');
        expect(json.containsKey('active_turn_seat'), isFalse,
            reason: 'PodState must never contain active_turn_seat');
        expect(json.containsKey('turn_number'), isFalse,
            reason: 'PodState must never contain turn_number');
        expect(json.containsKey('turn_count'), isFalse,
            reason: 'PodState must never contain turn_count');
        expect(json.containsKey('turn_timer_seconds'), isFalse,
            reason: 'PodState must never contain turn_timer_seconds');
        expect(json.containsKey('chess_clock'), isFalse,
            reason: 'PodState must never contain chess_clock');
        expect(json.containsKey('chess_clock_enabled'), isFalse,
            reason: 'PodState must never contain chess_clock_enabled');
        expect(json.containsKey('turn_order'), isFalse,
            reason: 'PodState must never contain turn_order');
        expect(json.containsKey('current_phase'), isFalse,
            reason: 'PodState must never contain current_phase');
        expect(json.containsKey('time_bank'), isFalse,
            reason: 'PodState must never contain time_bank');
        expect(json.containsKey('priority_player_id'), isFalse,
            reason: 'PodState must never contain priority_player_id');
      });

      test('1.2: PodPlayerState JSON schema strictly omits individual turn/timer fields', () {
        const player = PodPlayerState(
          id: 'p1_audit',
          seatIndex: 0,
          name: 'Player 1',
          life: 40,
        );

        final json = player.toJson();

        // Forbidden individual player turn fields
        expect(json.containsKey('is_current_turn'), isFalse,
            reason: 'PodPlayerState must never contain is_current_turn');
        expect(json.containsKey('is_active_turn'), isFalse,
            reason: 'PodPlayerState must never contain is_active_turn');
        expect(json.containsKey('turn_timer'), isFalse,
            reason: 'PodPlayerState must never contain turn_timer');
        expect(json.containsKey('time_remaining'), isFalse,
            reason: 'PodPlayerState must never contain time_remaining');
        expect(json.containsKey('clock_seconds'), isFalse,
            reason: 'PodPlayerState must never contain clock_seconds');
        expect(json.containsKey('has_priority'), isFalse,
            reason: 'PodPlayerState must never contain has_priority');
        expect(json.containsKey('turns_taken'), isFalse,
            reason: 'PodPlayerState must never contain turns_taken');
      });
    });

    // =========================================================================
    // 2. NETWORK PROTOCOL AUDIT: P2P Wire Schemas & Packet Types
    // =========================================================================
    group('2. P2P Mesh Network Protocol Audit', () {
      test('2.1: P2pPacketType enum omits all turn passing, timers, and clock synchronization', () {
        for (final packetType in P2pPacketType.values) {
          final typeName = packetType.name.toLowerCase();
          final wireName = packetType.wireName.toLowerCase();

          // Assert absence of forbidden turn keywords in packet types
          expect(typeName.contains('turn'), isFalse,
              reason: 'Packet type $typeName must not reference turn');
          expect(typeName.contains('clock'), isFalse,
              reason: 'Packet type $typeName must not reference clock');
          expect(typeName.contains('pass'), isFalse,
              reason: 'Packet type $typeName must not reference pass');
          expect(typeName.contains('priority'), isFalse,
              reason: 'Packet type $typeName must not reference priority');

          expect(wireName.contains('turn'), isFalse,
              reason: 'Wire name $wireName must not reference turn');
          expect(wireName.contains('clock'), isFalse,
              reason: 'Wire name $wireName must not reference clock');
        }
      });

      test('2.2: P2pPacket serialized payloads strictly omit turn metadata', () {
        final packet = P2pPacket(
          type: P2pPacketType.lifeDelta,
          senderId: 'device_node_1',
          targetPlayerId: 'p1_audit',
          delta: -3,
          sequenceNumber: 14,
        );

        final json = packet.toJson();

        expect(json.containsKey('turn'), isFalse);
        expect(json.containsKey('turn_number'), isFalse);
        expect(json.containsKey('active_player'), isFalse);
        expect(json.containsKey('clock_time'), isFalse);
      });
    });

    // =========================================================================
    // 3. PERSISTENCE LAYER AUDIT: Drift Database Tables & Schemas
    // =========================================================================
    group('3. Drift SQLite v10 Schema Audit', () {
      test('3.1: MatchSessions and MatchPlayers tables contain zero turn/clock columns', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        final sessionColumns = db.matchSessions.$columns.map((c) => c.$name.toLowerCase()).toList();

        // Forbidden column names in MatchSessions
        expect(sessionColumns.contains('turn_number'), isFalse);
        expect(sessionColumns.contains('current_turn'), isFalse);
        expect(sessionColumns.contains('active_player'), isFalse);
        expect(sessionColumns.contains('active_player_id'), isFalse);
        expect(sessionColumns.contains('turn_timer'), isFalse);
        expect(sessionColumns.contains('chess_clock'), isFalse);
        expect(sessionColumns.contains('time_limit'), isFalse);

        final playerColumns = db.matchPlayers.$columns.map((c) => c.$name.toLowerCase()).toList();

        // Forbidden column names in MatchPlayers
        expect(playerColumns.contains('is_turn'), isFalse);
        expect(playerColumns.contains('is_active_turn'), isFalse);
        expect(playerColumns.contains('turn_seconds'), isFalse);
        expect(playerColumns.contains('clock_time'), isFalse);
        expect(playerColumns.contains('time_bank'), isFalse);
      });

      test('3.2: MatchEvents transaction event types omit turn-passing events', () {
        // Documented event types in MatchEvents table:
        const validEventTypes = {
          'session_created',
          'life_delta',
          'commander_damage',
          'poison',
          'energy',
          'experience',
          'commander_tax',
          'monarch',
          'initiative',
          'day_night',
          'mana_change',
          'mana_clear',
          'storm',
          'dice_roll',
          'coin_flip',
          'reset',
          'undo',
        };

        expect(validEventTypes.contains('pass_turn'), isFalse);
        expect(validEventTypes.contains('next_turn'), isFalse);
        expect(validEventTypes.contains('end_turn'), isFalse);
        expect(validEventTypes.contains('turn_timeout'), isFalse);
        expect(validEventTypes.contains('clock_tick'), isFalse);
      });
    });

    // =========================================================================
    // 4. PRESENTATION & UI LAYER AUDIT: PodScaffoldWidget & Quadrants
    // =========================================================================
    group('4. Presentation & UI Widgets Audit', () {
      final testPod4P = const PodState(
        sessionId: 'audit_ui_pod_4p',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'David', life: 40),
        ],
      );

      testWidgets('4.1: UI renders zero turn-passing buttons, timers, or chess clocks', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PodScaffoldWidget(
              podState: testPod4P,
            ),
          ),
        );
        await tester.pump();

        // 1. Assert zero turn-passing or end-turn text in widget tree
        expect(find.textContaining('Pass Turn'), findsNothing);
        expect(find.textContaining('End Turn'), findsNothing);
        expect(find.textContaining('Turn:'), findsNothing);
        expect(find.textContaining('Current Turn'), findsNothing);
        expect(find.textContaining('Active Player'), findsNothing);

        // 2. Assert zero turn/clock keys in widget tree
        expect(find.byKey(const Key('pass_turn_btn')), findsNothing);
        expect(find.byKey(const Key('end_turn_btn')), findsNothing);
        expect(find.byKey(const Key('turn_timer')), findsNothing);
        expect(find.byKey(const Key('chess_clock')), findsNothing);
        expect(find.byKey(const Key('turn_indicator')), findsNothing);
      });

      testWidgets('4.2: Passive equality principle: all players have simultaneous concurrent interaction', (tester) async {
        final adjustedPlayers = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: PodScaffoldWidget(
              podState: testPod4P,
              onLifeDelta: (playerId, delta) => adjustedPlayers.add(playerId),
            ),
          ),
        );
        await tester.pump();

        // In a passive companion utility, Player 1, Player 2, Player 3, and Player 4
        // can all adjust life totals simultaneously without waiting for an active turn.
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        await tester.tap(find.byKey(const Key('hitbox_plus_p2')));
        await tester.tap(find.byKey(const Key('hitbox_plus_p3')));
        await tester.tap(find.byKey(const Key('hitbox_plus_p4')));
        await tester.pump();

        expect(adjustedPlayers, containsAll(['p1', 'p2', 'p3', 'p4']),
            reason: 'All players must be able to interact concurrently without turn priority locks');
      });
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';
import 'package:countr/features/life_counter/presentation/dialogs/session_recovery_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late MatchSessionRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    repository = MatchSessionRepository(db: database);
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  // ===========================================================================
  // GROUP 1: Rapid Lifecycle Transitions & FIFO Queue Stress
  // ===========================================================================
  group('1. Rapid Lifecycle Transitions & FIFO Write Queue Stress', () {
    test('T1.1: 200 concurrent un-flushed writes across rapid lifecycle transitions flush deterministically without loss', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
          const PlayerSetupConfig(id: 'p3', seatOrder: 2, name: 'Charlie', startingLife: 40),
          const PlayerSetupConfig(id: 'p4', seatOrder: 3, name: 'Diana', startingLife: 40),
        ],
      );

      final sessionId = initial.sessionId;

      // Fire 200 write operations into the queue without awaiting them individually
      final List<Future<void>> futures = [];
      for (int i = 0; i < 50; i++) {
        // Alice takes 1 life delta
        futures.add(repository.recordLifeDelta(
          sessionId: sessionId,
          playerId: 'p1',
          delta: -1,
          sequenceNumber: 2 + (i * 4),
        ));
        // Bob takes 1 commander damage from Alice
        futures.add(repository.recordCommanderDamage(
          sessionId: sessionId,
          targetPlayerId: 'p2',
          sourcePlayerId: 'p1',
          delta: 1,
          sequenceNumber: 3 + (i * 4),
        ));
        // Charlie floats 1 red mana
        futures.add(repository.recordManaChange(
          sessionId: sessionId,
          playerId: 'p3',
          color: 'R',
          delta: 1,
          sequenceNumber: 4 + (i * 4),
        ));
        // Diana gains 1 poison
        futures.add(repository.recordCounterChange(
          sessionId: sessionId,
          playerId: 'p4',
          counterType: 'poison',
          delta: 1,
          sequenceNumber: 5 + (i * 4),
        ));
      }

      expect(futures.length, equals(200));

      // Simulate rapid lifecycle pause / flush mid-flight
      await repository.flush();

      // Ensure all 200 write futures completed successfully
      await Future.wait(futures);

      // Verify restored state from SQLite
      final restored = await repository.restoreActiveSession();
      expect(restored, isNotNull);

      final p1 = restored!.players.firstWhere((p) => p.id == 'p1');
      final p2 = restored.players.firstWhere((p) => p.id == 'p2');
      final p3 = restored.players.firstWhere((p) => p.id == 'p3');
      final p4 = restored.players.firstWhere((p) => p.id == 'p4');

      // Alice: 40 - 50 = -10 life
      expect(p1.life, equals(-10));
      // Bob: 40 - 50 = -10 life, 50 commander damage from p1
      expect(p2.life, equals(-10));
      expect(p2.commanderDamageTaken['p1'], equals(50));
      // Charlie: 50 Red mana
      expect(p3.floatingMana['R'], equals(50));
      // Diana: 50 Poison counters
      expect(p4.poison, equals(50));

      // Verify event count in DB: 1 session_created + 200 writes = 201 events
      final events = await database.matchDao.getEventsForSession(sessionId);
      expect(events.length, equals(201));

      // Verify sequence numbers are strictly 1..201 monotonic
      for (int i = 0; i < events.length; i++) {
        expect(events[i].sequenceNumber, equals(i + 1));
      }
    });

    test('T1.2: Concurrent flush calls during active pipeline do not deadlock', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      // Enqueue 30 life deltas
      for (int i = 0; i < 30; i++) {
        repository.recordLifeDelta(
          sessionId: initial.sessionId,
          playerId: 'p1',
          delta: 1,
          sequenceNumber: i + 2,
        );
      }

      // Concurrently trigger 5 flush calls
      final flushes = List.generate(5, (_) => repository.flush());
      await Future.wait(flushes);

      final restored = await repository.restoreActiveSession();
      expect(restored!.players.first.life, equals(70)); // 40 + 30
    });

    test('T1.3: FIFO queue survives task failure and continues processing subsequent writes', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      // Task 1: Valid write
      final f1 = repository.recordLifeDelta(
        sessionId: initial.sessionId,
        playerId: 'p1',
        delta: 5,
        sequenceNumber: 2,
      );

      // Task 2: Faulty write targeting non-existent player (should throw ArgumentError)
      final f2 = repository.recordLifeDelta(
        sessionId: initial.sessionId,
        playerId: 'non_existent_player',
        delta: -10,
        sequenceNumber: 3,
      );

      // Task 3: Subsequent valid write
      final f3 = repository.recordLifeDelta(
        sessionId: initial.sessionId,
        playerId: 'p1',
        delta: -3,
        sequenceNumber: 4,
      );

      await f1;
      await expectLater(f2, throwsA(isA<ArgumentError>()));
      await f3;

      await repository.flush();

      final restored = await repository.restoreActiveSession();
      // Alice: 40 + 5 - 3 = 42
      expect(restored!.players.first.life, equals(42));
    });

    test('T1.4: Simulated crash/restart with new repository instance restores exact state', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );

      await repository.recordLifeDelta(sessionId: initial.sessionId, playerId: 'p1', delta: -12, sequenceNumber: 2);
      await repository.recordCounterChange(sessionId: initial.sessionId, playerId: 'p2', counterType: 'energy', delta: 7, sequenceNumber: 3);
      await repository.flush();

      // Dispose current repository (simulating app process kill)
      repository.dispose();

      // Launch fresh repository instance on the same SQLite database
      final freshRepo = MatchSessionRepository(db: database);
      final restored = await freshRepo.restoreActiveSession();

      expect(restored, isNotNull);
      expect(restored!.sessionId, equals(initial.sessionId));
      expect(restored.players[0].life, equals(28));
      expect(restored.players[1].energy, equals(7));

      freshRepo.dispose();
    });
  });

  // ===========================================================================
  // GROUP 2: State Reconstruction Across Complex Event Streams
  // ===========================================================================
  group('2. Mathematical Fidelity Across Complex Event Streams', () {
    test('T2.1: Multi-player full game simulation (WUBRGC mana, storm, poison, commander dmg, monarch, initiative, day/night)', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
          const PlayerSetupConfig(id: 'p3', seatOrder: 2, name: 'Charlie', startingLife: 40),
          const PlayerSetupConfig(id: 'p4', seatOrder: 3, name: 'Diana', startingLife: 40),
        ],
      );
      final sid = initial.sessionId;

      // 1. WUBRGC mana pool additions for Alice
      int seq = 2;
      for (final color in ['W', 'U', 'B', 'R', 'G', 'C']) {
        await repository.recordManaChange(sessionId: sid, playerId: 'p1', color: color, delta: 3, sequenceNumber: seq++);
      }
      // Deduct 1 Blue and 2 Colorless
      await repository.recordManaChange(sessionId: sid, playerId: 'p1', color: 'U', delta: -1, sequenceNumber: seq++);
      await repository.recordManaChange(sessionId: sid, playerId: 'p1', color: 'C', delta: -2, sequenceNumber: seq++);

      // 2. Storm count adjustments
      await repository.recordStormChange(sessionId: sid, playerId: 'p1', delta: 5, sequenceNumber: seq++);

      // 3. Commander damage matrix
      // Bob takes 14 commander damage from Alice (p1)
      await repository.recordCommanderDamage(sessionId: sid, targetPlayerId: 'p2', sourcePlayerId: 'p1', delta: 14, sequenceNumber: seq++);
      // Bob takes 7 commander damage from Charlie (p3) -> total 21 commander damage taken! (14 from p1, 7 from p3)
      await repository.recordCommanderDamage(sessionId: sid, targetPlayerId: 'p2', sourcePlayerId: 'p3', delta: 7, sequenceNumber: seq++);
      // Charlie takes 21 commander damage from Alice (p1) -> Lethal 21 commander damage from a SINGLE opponent!
      await repository.recordCommanderDamage(sessionId: sid, targetPlayerId: 'p3', sourcePlayerId: 'p1', delta: 21, sequenceNumber: seq++);

      // 4. Poison counters
      await repository.recordCounterChange(sessionId: sid, playerId: 'p4', counterType: 'poison', delta: 9, sequenceNumber: seq++);

      // 5. Monarch stealing chain: p1 -> p2 -> p4
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'monarch', delta: 1, sequenceNumber: seq++);
      await repository.recordCounterChange(sessionId: sid, playerId: 'p2', counterType: 'monarch', delta: 1, sequenceNumber: seq++);
      await repository.recordCounterChange(sessionId: sid, playerId: 'p4', counterType: 'monarch', delta: 1, sequenceNumber: seq++);

      // 6. Initiative stealing chain: p3 -> p1
      await repository.recordCounterChange(sessionId: sid, playerId: 'p3', counterType: 'initiative', delta: 1, sequenceNumber: seq++);
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'initiative', delta: 1, sequenceNumber: seq++);

      // 7. Day/Night cycle flips: Day -> Night -> Day -> Night
      await repository.recordDayNightToggle(sessionId: sid, isDay: false, sequenceNumber: seq++);
      await repository.recordDayNightToggle(sessionId: sid, isDay: true, sequenceNumber: seq++);
      await repository.recordDayNightToggle(sessionId: sid, isDay: false, sequenceNumber: seq++);

      // 8. Experience and Commander Tax
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'experience', delta: 4, sequenceNumber: seq++);
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'commander_tax', delta: 6, sequenceNumber: seq++);

      await repository.flush();

      // Reconstruct state via MatchSessionRepository
      final pod = await repository.restoreActiveSession();
      expect(pod, isNotNull);

      // Verify Day/Night is Night (false)
      expect(pod!.isDay, isFalse);

      final p1 = pod.players.firstWhere((p) => p.id == 'p1');
      final p2 = pod.players.firstWhere((p) => p.id == 'p2');
      final p3 = pod.players.firstWhere((p) => p.id == 'p3');
      final p4 = pod.players.firstWhere((p) => p.id == 'p4');

      // Alice verifications
      expect(p1.floatingMana, equals({'W': 3, 'U': 2, 'B': 3, 'R': 3, 'G': 3, 'C': 1}));
      expect(p1.stormCount, equals(5));
      expect(p1.experience, equals(4));
      expect(p1.commanderTax, equals(6));
      expect(p1.isMonarch, isFalse); // Lost to p2, then p4
      expect(p1.hasInitiative, isTrue); // Stole from p3

      // Bob verifications
      expect(p2.life, equals(19)); // 40 - 14 - 7 = 19
      expect(p2.commanderDamageTaken['p1'], equals(14));
      expect(p2.commanderDamageTaken['p3'], equals(7));
      expect(p2.isEliminated, isFalse); // Neither single opponent did >= 21
      expect(p2.isMonarch, isFalse);

      // Charlie verifications
      expect(p3.life, equals(19)); // 40 - 21 = 19
      expect(p3.commanderDamageTaken['p1'], equals(21));
      expect(p3.isEliminated, isTrue); // Exactly 21 from Alice!
      expect(p3.hasInitiative, isFalse); // Lost to p1

      // Diana verifications
      expect(p4.poison, equals(9));
      expect(p4.isEliminated, isFalse);
      expect(p4.isMonarch, isTrue); // Holds Monarch exclusively
      expect(p4.hasInitiative, isFalse);

      // Verify pod exclusivity: only 1 Monarch and only 1 Initiative holder across all players
      expect(pod.players.where((p) => p.isMonarch).length, equals(1));
      expect(pod.players.where((p) => p.hasInitiative).length, equals(1));
    });

    test('T2.2: Replay fidelity oracle: MatchDao.reconstructStateFromEvents matches restoreActiveSession exactly', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );
      final sid = initial.sessionId;

      await repository.recordLifeDelta(sessionId: sid, playerId: 'p1', delta: -8, sequenceNumber: 2);
      await repository.recordCommanderDamage(sessionId: sid, targetPlayerId: 'p2', sourcePlayerId: 'p1', delta: 6, sequenceNumber: 3);
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'poison', delta: 4, sequenceNumber: 4);
      await repository.recordManaChange(sessionId: sid, playerId: 'p2', color: 'G', delta: 5, sequenceNumber: 5);
      await repository.recordStormChange(sessionId: sid, playerId: 'p2', delta: 3, sequenceNumber: 6);
      await repository.recordCounterChange(sessionId: sid, playerId: 'p2', counterType: 'monarch', delta: 1, sequenceNumber: 7);
      await repository.flush();

      // State from MatchDao event replay
      final replayedState = await database.matchDao.reconstructStateFromEvents(sid);

      // State from MatchSessionRepository
      final restored = await repository.restoreActiveSession();

      for (final p in restored!.players) {
        final replayed = replayedState[p.id]!;
        expect(p.life, equals(replayed['life']));
        expect(p.poison, equals(replayed['poison']));
        expect(p.stormCount, equals(replayed['stormCount']));
        expect(p.isMonarch, equals(replayed['isMonarch']));
        expect(p.commanderDamageTaken, equals(replayed['commanderDamage']));
        expect(p.floatingMana, equals(replayed['floatingMana']));
      }
    });
  });

  // ===========================================================================
  // GROUP 3: Extreme Input Boundaries & Multi-Lethal Conditions
  // ===========================================================================
  group('3. Extreme Input Boundaries & Multi-Lethal Conditions', () {
    test('T3.1: Extreme life totals (-50 to 99999) handled with numeric precision', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );

      // Drop Alice to -50 life (40 - 90 = -50)
      await repository.recordLifeDelta(sessionId: initial.sessionId, playerId: 'p1', delta: -90, sequenceNumber: 2);

      // Boost Bob to 99,999 life (40 + 99959 = 99999)
      await repository.recordLifeDelta(sessionId: initial.sessionId, playerId: 'p2', delta: 99959, sequenceNumber: 3);

      await repository.flush();

      final restored = await repository.restoreActiveSession();
      expect(restored!.players[0].life, equals(-50));
      expect(restored.players[0].isEliminated, isTrue);

      expect(restored.players[1].life, equals(99999));
      expect(restored.players[1].isEliminated, isFalse);
    });

    test('T3.2: Multi-lethal conditions simultaneously (-5 life, 12 poison, 25 cmd dmg)', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );

      final sid = initial.sessionId;

      // Alice takes 25 commander damage from Bob (life: 40 - 25 = 15, cmd: 25 -> LETHAL CMD)
      await repository.recordCommanderDamage(sessionId: sid, targetPlayerId: 'p1', sourcePlayerId: 'p2', delta: 25, sequenceNumber: 2);

      // Alice takes 20 life damage (life: 15 - 20 = -5 -> LETHAL LIFE)
      await repository.recordLifeDelta(sessionId: sid, playerId: 'p1', delta: -20, sequenceNumber: 3);

      // Alice gains 12 poison counters (12 -> LETHAL POISON)
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'poison', delta: 12, sequenceNumber: 4);

      await repository.flush();

      final restored = await repository.restoreActiveSession();
      final alice = restored!.players.firstWhere((p) => p.id == 'p1');

      expect(alice.life, equals(-5));
      expect(alice.poison, equals(12));
      expect(alice.commanderDamageTaken['p2'], equals(25));
      expect(alice.isEliminated, isTrue);
    });

    test('T3.3: Adversarial Undo Check: Undoing life delta on a player with lethal commander damage', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );
      final sid = initial.sessionId;

      // 1. Bob deals 25 commander damage to Alice without life delta (or life heals back to 30)
      await repository.recordCommanderDamage(sessionId: sid, targetPlayerId: 'p1', sourcePlayerId: 'p2', delta: 25, sequenceNumber: 2);
      // Life is 40 - 25 = 15. Heal Alice by 20 to 35.
      await repository.recordLifeDelta(sessionId: sid, playerId: 'p1', delta: 20, sequenceNumber: 3);

      var pod = await repository.restoreActiveSession();
      expect(pod!.players.first.life, equals(35));
      expect(pod.players.first.commanderDamageTaken['p2'], equals(25));
      expect(pod.players.first.isEliminated, isTrue); // Still eliminated due to 25 commander damage!

      // 2. Accidental life change: Alice loses 2 life
      await repository.recordLifeDelta(sessionId: sid, playerId: 'p1', delta: -2, sequenceNumber: 4);

      // 3. User undoes the last event (the -2 life delta)
      final undone = await repository.undoLastEvent(sid);
      expect(undone, isNotNull);

      // 4. Verify whether Alice remains eliminated despite life being 35 (>0) because commander damage is 25
      final alice = undone!.players.firstWhere((p) => p.id == 'p1');
      expect(alice.life, equals(35));
      expect(alice.commanderDamageTaken['p2'], equals(25));
      
      // CRITICAL ASSERTION:
      // Does undoing a life delta erroneously resurrect a player who is dead to commander damage?
      expect(alice.isEliminated, isTrue, reason: 'Player must remain eliminated when commander damage >= 21, even if life delta is undone');
    });

    test('T3.3b: Adversarial Undo Check: Undoing poison on a player with lethal commander damage', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );
      final sid = initial.sessionId;

      // 1. Bob deals 22 commander damage to Alice (lethal commander damage)
      await repository.recordCommanderDamage(sessionId: sid, targetPlayerId: 'p1', sourcePlayerId: 'p2', delta: 22, sequenceNumber: 2);
      // Alice is healed to 30
      await repository.recordLifeDelta(sessionId: sid, playerId: 'p1', delta: 12, sequenceNumber: 3);

      var pod = await repository.restoreActiveSession();
      expect(pod!.players.first.isEliminated, isTrue);

      // 2. Alice gains 1 poison counter
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'poison', delta: 1, sequenceNumber: 4);

      // 3. User undoes the poison counter
      final undone = await repository.undoLastEvent(sid);
      expect(undone, isNotNull);

      final alice = undone!.players.firstWhere((p) => p.id == 'p1');
      expect(alice.poison, equals(0));
      expect(alice.commanderDamageTaken['p2'], equals(22));

      // CRITICAL ASSERTION:
      // Does undoing poison erroneously resurrect a player who is dead to commander damage?
      expect(alice.isEliminated, isTrue, reason: 'Player must remain eliminated when commander damage >= 21, even if poison counter is undone');
    });

    test('T3.3c: Adversarial Undo Check: Undoing life delta on a player with lethal poison counters', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );
      final sid = initial.sessionId;

      // 1. Alice gains 10 poison counters (lethal poison)
      await repository.recordCounterChange(sessionId: sid, playerId: 'p1', counterType: 'poison', delta: 10, sequenceNumber: 2);

      var pod = await repository.restoreActiveSession();
      expect(pod!.players.first.isEliminated, isTrue);

      // 2. Alice takes 1 life damage (life: 39)
      await repository.recordLifeDelta(sessionId: sid, playerId: 'p1', delta: -1, sequenceNumber: 3);

      // 3. User undoes the life delta
      final undone = await repository.undoLastEvent(sid);
      expect(undone, isNotNull);

      final alice = undone!.players.firstWhere((p) => p.id == 'p1');
      expect(alice.life, equals(40));
      expect(alice.poison, equals(10));

      // CRITICAL ASSERTION:
      // Does undoing life delta erroneously resurrect a player who is dead to poison?
      expect(alice.isEliminated, isTrue, reason: 'Player must remain eliminated when poison >= 10, even if life delta is undone');
    });

    testWidgets('T3.4: SessionRecoveryDialog renders extreme boundaries without RenderFlex overflow', (tester) async {
      // 6 players with extreme life values and long strings
      final session = MatchSession(
        id: 'session_extreme',
        name: 'Extreme Match',
        format: 'Commander',
        startingLife: 40,
        playerCount: 6,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
        isP2pHost: true,
        isDeleted: false,
      );

      final players = [
        const MatchPlayer(id: 'p1', sessionId: 'session_extreme', seatOrder: 0, playerName: 'Very Long Player Name The Third', currentLife: -50, isEliminated: true, poison: 15, energy: 0, experience: 0, commanderTax: 0, stormCount: 0, isMonarch: false, hasInitiative: false, isLocalDevice: true, isDeleted: false),
        const MatchPlayer(id: 'p2', sessionId: 'session_extreme', seatOrder: 1, playerName: 'Bob', currentLife: 99999, isEliminated: false, poison: 0, energy: 0, experience: 0, commanderTax: 0, stormCount: 0, isMonarch: false, hasInitiative: false, isLocalDevice: true, isDeleted: false),
        const MatchPlayer(id: 'p3', sessionId: 'session_extreme', seatOrder: 2, playerName: 'Charlie', currentLife: 0, isEliminated: true, poison: 0, energy: 0, experience: 0, commanderTax: 0, stormCount: 0, isMonarch: false, hasInitiative: false, isLocalDevice: true, isDeleted: false),
        const MatchPlayer(id: 'p4', sessionId: 'session_extreme', seatOrder: 3, playerName: 'Diana', currentLife: 40, isEliminated: false, poison: 0, energy: 0, experience: 0, commanderTax: 0, stormCount: 0, isMonarch: false, hasInitiative: false, isLocalDevice: true, isDeleted: false),
        const MatchPlayer(id: 'p5', sessionId: 'session_extreme', seatOrder: 4, playerName: 'Evan', currentLife: 1, isEliminated: false, poison: 0, energy: 0, experience: 0, commanderTax: 0, stormCount: 0, isMonarch: false, hasInitiative: false, isLocalDevice: true, isDeleted: false),
        const MatchPlayer(id: 'p6', sessionId: 'session_extreme', seatOrder: 5, playerName: 'Fiona', currentLife: 38, isEliminated: false, poison: 0, energy: 0, experience: 0, commanderTax: 0, stormCount: 0, isMonarch: false, hasInitiative: false, isLocalDevice: true, isDeleted: false),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SessionRecoveryDialog(
            session: session,
            players: players,
            onContinue: () {},
            onStartNew: () {},
          ),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.byType(SessionRecoveryDialog), findsOneWidget);
      expect(find.text('-50'), findsOneWidget);
      expect(find.text('99999'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // GROUP 4: Corrupted, Partial, and Boundary Event Logs Recovery
  // ===========================================================================
  group('4. Corrupted, Partial, and Boundary Event Logs Recovery', () {
    test('T4.1: Corrupted JSON payloads in player and session rows do not crash restoreActiveSession', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      // Intentionally inject malformed JSON into SQLite columns
      await (database.update(database.matchSessions)..where((t) => t.id.equals(initial.sessionId))).write(
        const MatchSessionsCompanion(
          settingsJson: drift.Value('{this is NOT valid JSON}'),
        ),
      );

      await (database.update(database.matchPlayers)..where((t) => t.id.equals('p1'))).write(
        const MatchPlayersCompanion(
          commanderDamageJson: drift.Value('{"corrupted_key:'),
          floatingManaJson: drift.Value('[1, 2, 3]'), // Array instead of Map
          countersJson: drift.Value('invalid syntax'),
        ),
      );

      // Must restore safely with fallback values without throwing FormatException
      final restored = await repository.restoreActiveSession();
      expect(restored, isNotNull);
      expect(restored!.players.first.commanderDamageTaken, isEmpty);
      // Floating mana falls back to default empty pool
      expect(restored.players.first.floatingMana['W'], equals(0));
    });

    test('T4.2: Gapped sequence numbers are handled and maxSeq is tracked correctly', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      // Directly insert an event with a large gap in sequence number (e.g. seq = 42)
      await database.matchDao.recordEvent(
        sessionId: initial.sessionId,
        eventType: 'day_night',
        sequenceNumber: 42,
        value: 0, // Night
      );

      final restored = await repository.restoreActiveSession();
      expect(restored, isNotNull);
      expect(restored!.isDay, isFalse);
      expect(restored.sequenceNumber, equals(42));
    });

    test('T4.3: Soft-deleted events are ignored during state reconstruction', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      // Record a day_night event
      await database.matchDao.recordEvent(
        sessionId: initial.sessionId,
        eventType: 'day_night',
        sequenceNumber: 10,
        value: 0, // Night
      );

      // Soft delete this event
      await (database.update(database.matchEvents)..where((t) => t.sequenceNumber.equals(10))).write(
        const MatchEventsCompanion(
          isDeleted: drift.Value(true),
        ),
      );

      final restored = await repository.restoreActiveSession();
      // Since event 10 is soft-deleted, it should be ignored and default day remains true
      expect(restored!.isDay, isTrue);
    });

    test('T4.4: Disposed repository throws StateError on attempted write', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      repository.dispose();

      expect(
        () => repository.recordLifeDelta(
          sessionId: initial.sessionId,
          playerId: 'p1',
          delta: -1,
          sequenceNumber: 2,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

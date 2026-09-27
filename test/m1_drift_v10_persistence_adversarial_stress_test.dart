import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial Persistence Stress Suite: Drift Schema v10 & MatchDao', () {
    // =========================================================================
    // 1. High-Throughput Concurrent Event Writing Bursts
    // =========================================================================
    test('Burst Stress 1: 100 simultaneous concurrent life mutations on a single player', () async {
      final sessionId = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [
          MatchPlayersCompanion.insert(
            id: 'player_burst_1',
            sessionId: 'placeholder',
            seatOrder: 0,
            playerName: 'Stress Tester',
          ),
        ],
      );

      // Launch 100 simultaneous async life increments (+1 each)
      const burstCount = 100;
      final futures = List.generate(burstCount, (i) {
        return db.matchDao.updatePlayerLife(
          sessionId: sessionId,
          playerId: 'player_burst_1',
          delta: 1,
          note: 'Burst life delta #$i',
        );
      });

      // Await all 100 concurrent mutations
      await Future.wait(futures);

      // 1. Verify player life total is exactly 40 + 100 = 140
      final player = await db.matchDao.getPlayerById('player_burst_1');
      expect(player, isNotNull);
      expect(player!.currentLife, equals(140));
      expect(player.isEliminated, isFalse);

      // 2. Verify exactly 101 events exist (1 session_created + 100 life_delta)
      final events = await db.matchDao.getEventsForSession(sessionId);
      expect(events.length, equals(101));

      // 3. Monotonic sequence number integrity: strictly 1..101 with ZERO gaps and ZERO duplicates
      final seqNumbers = events.map((e) => e.sequenceNumber).toList();
      final expectedSeqs = List.generate(101, (i) => i + 1);
      expect(seqNumbers, equals(expectedSeqs));

      // 4. Verify every single event has a unique ID
      final eventIds = events.map((e) => e.id).toSet();
      expect(eventIds.length, equals(101));

      // 5. Verify outbox SyncQueue integrity:
      // 1 session INSERT + 1 player INSERT + 1 session_created event INSERT
      // + 100 life_delta event INSERTs + 100 player UPDATEs = 203 entries
      final syncEntries = await (db.select(db.syncQueue)).get();
      final eventSyncEntries = syncEntries.where((s) => s.entityType == 'match_event').toList();
      final playerSyncEntries = syncEntries.where((s) => s.entityType == 'match_player').toList();

      expect(eventSyncEntries.length, equals(101));
      expect(eventSyncEntries.every((s) => s.operation == 'INSERT'), isTrue);
      // 1 initial INSERT + 100 UPDATEs
      expect(playerSyncEntries.length, equals(101));
    });

    test('Burst Stress 2: 100 multi-player, multi-domain concurrent mutations with state replay check', () async {
      final sessionId = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 4,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'P2'),
          MatchPlayersCompanion.insert(id: 'p3', sessionId: 'x', seatOrder: 2, playerName: 'P3'),
          MatchPlayersCompanion.insert(id: 'p4', sessionId: 'x', seatOrder: 3, playerName: 'P4'),
        ],
      );

      final List<Future<void>> concurrentOps = [];

      // 25 Life mutations spread across all 4 players
      for (var i = 0; i < 25; i++) {
        final pid = 'p${(i % 4) + 1}';
        final delta = (i % 2 == 0) ? -2 : 3;
        concurrentOps.add(db.matchDao.updatePlayerLife(sessionId: sessionId, playerId: pid, delta: delta));
      }

      // 25 Counter mutations (poison, energy, xp, commander_tax)
      final counterTypes = ['poison', 'energy', 'experience', 'commander_tax'];
      for (var i = 0; i < 25; i++) {
        final pid = 'p${(i % 4) + 1}';
        final counter = counterTypes[i % counterTypes.length];
        concurrentOps.add(db.matchDao.recordCounterChange(
          sessionId: sessionId,
          playerId: pid,
          counterType: counter,
          delta: 1,
        ));
      }

      // 25 Commander damage mutations across player pairs
      for (var i = 0; i < 25; i++) {
        final targetId = 'p${(i % 4) + 1}';
        final sourceId = 'p${((i + 1) % 4) + 1}';
        concurrentOps.add(db.matchDao.recordCommanderDamage(
          sessionId: sessionId,
          targetPlayerId: targetId,
          sourcePlayerId: sourceId,
          delta: 2,
          applyLifeDelta: true,
        ));
      }

      // 25 Mana & Storm mutations
      final manaColors = ['W', 'U', 'B', 'R', 'G', 'C'];
      for (var i = 0; i < 25; i++) {
        final pid = 'p${(i % 4) + 1}';
        if (i % 5 == 0) {
          concurrentOps.add(db.matchDao.recordStormChange(sessionId: sessionId, playerId: pid, delta: 1));
        } else {
          final color = manaColors[i % manaColors.length];
          concurrentOps.add(db.matchDao.recordManaChange(sessionId: sessionId, playerId: pid, manaColor: color, delta: 1));
        }
      }

      // Execute all 100 concurrent mutations simultaneously
      await Future.wait(concurrentOps);

      // Verify total events: 1 initial session_created + 100 burst operations = 101 events
      final events = await db.matchDao.getEventsForSession(sessionId);
      expect(events.length, equals(101));

      // Monotonic sequence verification: 1..101 contiguous
      final seqs = events.map((e) => e.sequenceNumber).toList();
      expect(seqs, equals(List.generate(101, (i) => i + 1)));

      // Mathematically verify that event-sourced replay state EXACTLY matches denormalized player tables
      final reconstructed = await db.matchDao.reconstructStateFromEvents(sessionId);
      final players = await db.matchDao.getPlayersForSession(sessionId);

      for (final p in players) {
        final recon = reconstructed[p.id]!;
        expect(recon['life'], equals(p.currentLife), reason: 'Life mismatch for ${p.id}');
        expect(recon['poison'], equals(p.poison), reason: 'Poison mismatch for ${p.id}');
        expect(recon['energy'], equals(p.energy), reason: 'Energy mismatch for ${p.id}');
        expect(recon['experience'], equals(p.experience), reason: 'Experience mismatch for ${p.id}');
        expect(recon['commanderTax'], equals(p.commanderTax), reason: 'Commander tax mismatch for ${p.id}');
        expect(recon['stormCount'], equals(p.stormCount), reason: 'Storm count mismatch for ${p.id}');

        // Floating mana check
        final dbMana = jsonDecode(p.floatingManaJson ?? '{}') as Map<String, dynamic>;
        final reconMana = recon['floatingMana'] as Map<String, int>;
        for (final c in manaColors) {
          expect(reconMana[c] ?? 0, equals(dbMana[c] ?? 0), reason: 'Mana $c mismatch for ${p.id}');
        }

        // Commander damage check
        final dbCmd = jsonDecode(p.commanderDamageJson ?? '{}') as Map<String, dynamic>;
        final reconCmd = recon['commanderDamage'] as Map<String, int>;
        for (final entry in dbCmd.entries) {
          expect(reconCmd[entry.key] ?? 0, equals(entry.value), reason: 'Cmd damage from ${entry.key} mismatch for ${p.id}');
        }
      }
    });

    test('Burst Stress 3: Cross-session concurrency isolation across 5 simultaneous sessions', () async {
      const sessionCount = 5;
      const writesPerSession = 20;

      final sessionIds = await Future.wait(List.generate(sessionCount, (sIndex) {
        return db.matchDao.createSession(
          name: 'Session #$sIndex',
          format: 'Commander',
          startingLife: 40,
          playerCount: 1,
          players: [
            MatchPlayersCompanion.insert(
              id: 'player_s$sIndex',
              sessionId: 'placeholder',
              seatOrder: 0,
              playerName: 'Player $sIndex',
            ),
          ],
          abandonExistingActive: false,
        );
      }));

      // Launch 100 simultaneous operations across all 5 sessions (20 per session)
      final allFutures = <Future<void>>[];
      for (var s = 0; s < sessionCount; s++) {
        final sId = sessionIds[s];
        final pId = 'player_s$s';
        for (var w = 0; w < writesPerSession; w++) {
          allFutures.add(db.matchDao.updatePlayerLife(sessionId: sId, playerId: pId, delta: 1));
        }
      }

      await Future.wait(allFutures);

      // Verify each session isolated sequence numbers: strictly 1..21 per session
      for (var s = 0; s < sessionCount; s++) {
        final sId = sessionIds[s];
        final events = await db.matchDao.getEventsForSession(sId);
        expect(events.length, equals(21));
        final seqs = events.map((e) => e.sequenceNumber).toList();
        expect(seqs, equals(List.generate(21, (i) => i + 1)), reason: 'Session $sId sequence numbers broken');

        final player = await db.matchDao.getPlayerById('player_s$s');
        expect(player!.currentLife, equals(40 + writesPerSession));
      }
    });

    // =========================================================================
    // 2. Monotonic Sequence Number Integrity
    // =========================================================================
    test('Monotonicity survives undos, lobby resets, and arbitrary event sequencing', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      // Sequence 1: session_created
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -5); // Seq 2
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'poison', delta: 2); // Seq 3
      await db.matchDao.undoLastEvent(sessionId: s); // Seq 4 (undo event)
      await db.matchDao.resetSession(s, 40); // Seq 5 (reset event)
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: 3); // Seq 6

      final events = await db.matchDao.getEventsForSession(s);
      expect(events.length, equals(6));
      expect(events.map((e) => e.sequenceNumber).toList(), equals([1, 2, 3, 4, 5, 6]));

      expect(events[0].eventType, equals('session_created'));
      expect(events[1].eventType, equals('life_delta'));
      expect(events[2].eventType, equals('poison'));
      expect(events[3].eventType, equals('undo'));
      expect(events[4].eventType, equals('reset'));
      expect(events[5].eventType, equals('life_delta'));
    });

    test('Sequence generator is resilient to soft-deleted events (no sequence regression)', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -2); // Seq 2
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -3); // Seq 3

      // Manually soft-delete event seq 3
      final allEvents = await (db.select(db.matchEvents)..where((t) => t.sessionId.equals(s))).get();
      final lastEvent = allEvents.firstWhere((e) => e.sequenceNumber == 3);
      await (db.update(db.matchEvents)..where((t) => t.id.equals(lastEvent.id))).write(
        const MatchEventsCompanion(isDeleted: Value(true)),
      );

      // New mutation must calculate max from all rows (including soft deleted) -> seq 4
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: 5);

      final rawEvents = await (db.select(db.matchEvents)..where((t) => t.sessionId.equals(s))).get();
      final latest = rawEvents.firstWhere((e) => e.delta == 5);
      expect(latest.sequenceNumber, equals(4), reason: 'Sequence number regressed due to soft-deleted record');
    });

    test('External sequence number jump is respected monotonically', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      // Record an event with explicit sequence number 77 (e.g. from P2P packet sync)
      await db.matchDao.recordEvent(
        sessionId: s,
        eventType: 'dice_roll',
        sequenceNumber: 77,
        payload: {'d20': 20},
      );

      // Next DAO mutation must pick up at 78
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: 1);

      final rawEvents = await (db.select(db.matchEvents)..where((t) => t.sessionId.equals(s))).get();
      final lifeEvent = rawEvents.firstWhere((e) => e.eventType == 'life_delta');
      expect(lifeEvent.sequenceNumber, equals(78));
    });

    // =========================================================================
    // 3. Rollback Atomicity on Injected & Mid-Transaction Failures
    // =========================================================================
    test('Rollback Atomicity 1: Mid-transaction simulated failure leaves zero partial writes', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      final initialPlayer = await db.matchDao.getPlayerById('p1');
      expect(initialPlayer!.currentLife, equals(40));

      final initialEventsCount = (await db.matchDao.getEventsForSession(s)).length;
      final initialSyncCount = (await db.select(db.syncQueue).get()).length;

      // Simulate a compound transaction that updates player, inserts event, but throws before commit
      try {
        await db.transaction(() async {
          // 1. Partial update
          await (db.update(db.matchPlayers)..where((t) => t.id.equals('p1'))).write(
            const MatchPlayersCompanion(currentLife: Value(999)),
          );

          // 2. Partial insert into matchEvents
          await db.into(db.matchEvents).insert(
            MatchEventsCompanion.insert(
              id: 'orphan_event_1',
              sessionId: s,
              playerId: 'p1',
              eventType: 'corrupt_event',
              timestamp: DateTime.now(),
            ),
          );

          // 3. Partial insert into syncQueue
          await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'orphan_sync_1',
              entityType: 'match_event',
              entityId: 'orphan_event_1',
              operation: 'INSERT',
              timestamp: DateTime.now(),
            ),
          );

          // 4. Injected catastrophic crash
          throw StateError('Simulated transaction failure / power loss / disk error');
        });
      } catch (e) {
        expect(e, isA<StateError>());
      }

      // Verify complete rollback: player life unchanged, zero orphan events, zero orphan sync entries
      final playerAfterCrash = await db.matchDao.getPlayerById('p1');
      expect(playerAfterCrash!.currentLife, equals(40));

      final eventsAfterCrash = await db.matchDao.getEventsForSession(s);
      expect(eventsAfterCrash.length, equals(initialEventsCount));
      expect(eventsAfterCrash.any((e) => e.id == 'orphan_event_1'), isFalse);

      final syncAfterCrash = await db.select(db.syncQueue).get();
      expect(syncAfterCrash.length, equals(initialSyncCount));
      expect(syncAfterCrash.any((s) => s.id == 'orphan_sync_1'), isFalse);
    });

    test('Rollback Atomicity 2: Primary Key uniqueness violation triggers clean transaction rollback', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      // Attempt transaction where second insert duplicates existing primary key
      expect(
        () async {
          await db.transaction(() async {
            // Valid insert
            await db.into(db.matchEvents).insert(
              MatchEventsCompanion.insert(
                id: 'evt_valid_1',
                sessionId: s,
                playerId: 'p1',
                eventType: 'life_delta',
                delta: const Value(-1),
                value: const Value(39),
                sequenceNumber: const Value(2),
                timestamp: DateTime.now(),
              ),
            );

            // Colliding insert with duplicate ID
            await db.into(db.matchEvents).insert(
              MatchEventsCompanion.insert(
                id: 'evt_valid_1', // Duplicate primary key
                sessionId: s,
                playerId: 'p1',
                eventType: 'life_delta',
                delta: const Value(-1),
                value: const Value(38),
                sequenceNumber: const Value(3),
                timestamp: DateTime.now(),
              ),
            );
          });
        },
        throwsA(anything),
      );

      // Verify rollback: even evt_valid_1 was rolled back completely
      final events = await (db.select(db.matchEvents)..where((t) => t.id.equals('evt_valid_1'))).get();
      expect(events, isEmpty);
    });

    test('Rollback Atomicity 2b: Foreign key violation triggers rollback when PRAGMA foreign_keys = ON', () async {
      // Explicitly enable SQLite foreign keys on connection
      await db.customStatement('PRAGMA foreign_keys = ON;');

      expect(
        () async {
          await db.transaction(() async {
            await db.into(db.matchEvents).insert(
              MatchEventsCompanion.insert(
                id: 'fk_test',
                sessionId: 'non_existent_session_id', // Invalid foreign key
                playerId: 'p1',
                eventType: 'life_delta',
                timestamp: DateTime.now(),
              ),
            );
          });
        },
        throwsA(anything),
      );

      final events = await (db.select(db.matchEvents)..where((t) => t.id.equals('fk_test'))).get();
      expect(events, isEmpty);
    });

    test('Adversarial Defect Check: undoLastEvent(life_delta) erroneously resurrects players eliminated by poison or commander damage', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      // 1. Player is eliminated by reaching 10 poison counters
      await db.matchDao.recordCounterChange(
        sessionId: s,
        playerId: 'p1',
        counterType: 'poison',
        delta: 10,
      );

      var p = await db.matchDao.getPlayerById('p1');
      expect(p!.poison, equals(10));
      expect(p.isEliminated, isTrue);

      // 2. An unrelated life delta of -1 occurs while player has 10 poison
      await db.matchDao.updatePlayerLife(
        sessionId: s,
        playerId: 'p1',
        delta: -1,
      );

      p = await db.matchDao.getPlayerById('p1');
      expect(p!.currentLife, equals(39));
      expect(p.poison, equals(10));
      expect(p.isEliminated, isTrue);

      // 3. User undoes the life delta (-1)
      await db.matchDao.undoLastEvent(sessionId: s);

      p = await db.matchDao.getPlayerById('p1');
      expect(p!.currentLife, equals(40));
      expect(p.poison, equals(10));

      // In MTG rules, a player with 10 poison remains eliminated even if life delta is undone:
      expect(p.isEliminated, isTrue, reason: 'Player must remain eliminated when poison >= 10, even if life delta is undone');
    });

    test('Rollback Atomicity 3: MatchDao built-in validation failures abort cleanly', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      final initialEvents = await db.matchDao.getEventsForSession(s);

      // 1. updatePlayerLife with non-existent player
      await expectLater(
        () => db.matchDao.updatePlayerLife(sessionId: s, playerId: 'ghost_player', delta: 5),
        throwsA(isA<ArgumentError>()),
      );

      // 2. recordCommanderDamage with non-existent target
      await expectLater(
        () => db.matchDao.recordCommanderDamage(
          sessionId: s,
          targetPlayerId: 'ghost_player',
          sourcePlayerId: 'p1',
          delta: 5,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 3. recordCounterChange with non-existent player
      await expectLater(
        () => db.matchDao.recordCounterChange(
          sessionId: s,
          playerId: 'ghost_player',
          counterType: 'poison',
          delta: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 4. recordManaChange with non-existent player
      await expectLater(
        () => db.matchDao.recordManaChange(
          sessionId: s,
          playerId: 'ghost_player',
          manaColor: 'U',
          delta: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 5. recordStormChange with non-existent player
      await expectLater(
        () => db.matchDao.recordStormChange(
          sessionId: s,
          playerId: 'ghost_player',
          delta: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Verify no stray events were recorded
      final eventsAfterFailures = await db.matchDao.getEventsForSession(s);
      expect(eventsAfterFailures.length, equals(initialEvents.length));
    });

    // =========================================================================
    // 4. Soft-Delete Filtering Correctness Under High Volume
    // =========================================================================
    test('Soft-Delete Filtering: Mass session & event filtering across 20 sessions', () async {
      const totalSessions = 20;
      final sessionIds = <String>[];

      for (var i = 0; i < totalSessions; i++) {
        final sId = await db.matchDao.createSession(
          name: 'Session #$i',
          format: 'Commander',
          startingLife: 40,
          playerCount: 2,
          players: [
            MatchPlayersCompanion.insert(id: 's${i}_p1', sessionId: 'x', seatOrder: 0, playerName: 'P1'),
            MatchPlayersCompanion.insert(id: 's${i}_p2', sessionId: 'x', seatOrder: 1, playerName: 'P2'),
          ],
          abandonExistingActive: false,
        );

        // Add 3 events per session
        await db.matchDao.updatePlayerLife(sessionId: sId, playerId: 's${i}_p1', delta: -1);
        await db.matchDao.updatePlayerLife(sessionId: sId, playerId: 's${i}_p2', delta: -2);
        await db.matchDao.recordCounterChange(sessionId: sId, playerId: 's${i}_p1', counterType: 'energy', delta: 1);

        sessionIds.add(sId);
      }

      // Soft-delete the first 10 sessions
      for (var i = 0; i < 10; i++) {
        await db.matchDao.softDeleteSession(sessionIds[i]);
      }

      // Verify active queries exclude soft-deleted sessions
      for (var i = 0; i < totalSessions; i++) {
        final sId = sessionIds[i];
        final session = await db.matchDao.getSessionById(sId);
        final players = await db.matchDao.getPlayersForSession(sId);
        final events = await db.matchDao.getEventsForSession(sId);

        if (i < 10) {
          // Must be filtered
          expect(session, isNull, reason: 'Soft-deleted session $sId was not filtered from getSessionById');
          expect(players, isEmpty, reason: 'Soft-deleted players for $sId were not filtered');
          expect(events, isEmpty, reason: 'Soft-deleted events for $sId were not filtered');
        } else {
          // Must be visible
          expect(session, isNotNull);
          expect(players.length, equals(2));
          expect(events.length, equals(4)); // 1 created + 3 mutations
        }
      }

      // Verify underlying raw SQLite database still contains all 20 sessions and 40 players with is_deleted = 1
      final rawSessions = await db.select(db.matchSessions).get();
      expect(rawSessions.length, equals(20));
      expect(rawSessions.where((s) => s.isDeleted).length, equals(10));
      expect(rawSessions.where((s) => !s.isDeleted).length, equals(10));

      final rawPlayers = await db.select(db.matchPlayers).get();
      expect(rawPlayers.length, equals(40));
      expect(rawPlayers.where((p) => p.isDeleted).length, equals(20));
      expect(rawPlayers.where((p) => !p.isDeleted).length, equals(20));

      final rawEvents = await db.select(db.matchEvents).get();
      expect(rawEvents.length, equals(80)); // 20 * 4
      expect(rawEvents.where((e) => e.isDeleted).length, equals(40));
      expect(rawEvents.where((e) => !e.isDeleted).length, equals(40));
    });

    test('Mutation attempts on soft-deleted session or players are rejected', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p_deleted', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      await db.matchDao.softDeleteSession(s);

      // Updating life on a soft-deleted player throws ArgumentError
      await expectLater(
        () => db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p_deleted', delta: 5),
        throwsA(isA<ArgumentError>()),
      );

      // Updating counter on a soft-deleted player throws ArgumentError
      await expectLater(
        () => db.matchDao.recordCounterChange(sessionId: s, playerId: 'p_deleted', counterType: 'poison', delta: 1),
        throwsA(isA<ArgumentError>()),
      );

      // Resetting a soft-deleted session throws ArgumentError
      await expectLater(
        () => db.matchDao.resetSession(s),
        throwsA(isA<ArgumentError>()),
      );
    });

    // =========================================================================
    // 5. Deep Behavioral & Lethal State Stress Tests
    // =========================================================================
    test('Zero and negative life elimination transitions under heavy life swinging', () async {
      final s = await db.matchDao.createSession(
        format: 'Standard',
        startingLife: 20,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      // Drop to exactly 0 -> eliminated
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -20);
      var p = await db.matchDao.getPlayerById('p1');
      expect(p!.currentLife, equals(0));
      expect(p.isEliminated, isTrue);
      expect(p.eliminatedAt, isNotNull);

      // Further overkill to -15
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -15);
      p = await db.matchDao.getPlayerById('p1');
      expect(p!.currentLife, equals(-15));
      expect(p.isEliminated, isTrue);

      // Undo overkill back to 0 -> still eliminated
      await db.matchDao.undoLastEvent(sessionId: s);
      p = await db.matchDao.getPlayerById('p1');
      expect(p!.currentLife, equals(0));
      expect(p.isEliminated, isTrue);

      // Undo drop to 0 back to 20 -> un-eliminated
      await db.matchDao.undoLastEvent(sessionId: s);
      p = await db.matchDao.getPlayerById('p1');
      expect(p!.currentLife, equals(20));
      expect(p.isEliminated, isFalse);
      expect(p.eliminatedAt, isNull);
    });

    test('Lobby reset zeroes counters, clears commander damage, and revives eliminated players', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'Bob'),
        ],
      );

      // Knock out Bob with lethal commander damage (21)
      await db.matchDao.recordCommanderDamage(
        sessionId: s,
        targetPlayerId: 'p2',
        sourcePlayerId: 'p1',
        delta: 21,
      );

      var bob = await db.matchDao.getPlayerById('p2');
      expect(bob!.isEliminated, isTrue);

      // Alice accumulates counters
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'energy', delta: 8);
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'monarch', delta: 1);

      // Execute Reset Session
      await db.matchDao.resetSession(s, 40);

      final players = await db.matchDao.getPlayersForSession(s);
      final aliceReset = players.firstWhere((p) => p.id == 'p1');
      final bobReset = players.firstWhere((p) => p.id == 'p2');

      expect(bobReset.isEliminated, isFalse);
      expect(bobReset.eliminatedAt, isNull);
      expect(bobReset.currentLife, equals(40));
      expect(bobReset.commanderDamageJson, equals('{}'));

      expect(aliceReset.energy, equals(0));
      expect(aliceReset.isMonarch, isFalse);
      expect(aliceReset.currentLife, equals(40));

      // Verify reset state replay
      final recon = await db.matchDao.reconstructStateFromEvents(s);
      expect(recon['p2']!['isEliminated'], isFalse);
      expect(recon['p2']!['life'], equals(40));
      expect(recon['p1']!['energy'], equals(0));
    });

    test('Adversarial Invariant: clearManaPool enforces player existence/soft-delete validation', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      // clearManaPool validates player existence and throws ArgumentError if player does not exist
      await expectLater(
        () => db.matchDao.clearManaPool(sessionId: s, playerId: 'ghost_player'),
        throwsA(isA<ArgumentError>()),
      );

      final eventsAfter = await db.matchDao.getEventsForSession(s);
      final hasGhostEvent = eventsAfter.any((e) => e.playerId == 'ghost_player');
      expect(hasGhostEvent, isFalse, reason: 'clearManaPool must validate player existence and never create ghost events');
    });

    test('Adversarial Invariant: undoLastEvent(mana_clear) synchronizes player table and event replay', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      // Add 5 Blue mana
      await db.matchDao.recordManaChange(sessionId: s, playerId: 'p1', manaColor: 'U', delta: 5);
      var p = await db.matchDao.getPlayerById('p1');
      var mana = jsonDecode(p!.floatingManaJson!) as Map<String, dynamic>;
      expect(mana['U'], equals(5));

      // Clear pool
      await db.matchDao.clearManaPool(sessionId: s, playerId: 'p1');
      p = await db.matchDao.getPlayerById('p1');
      mana = jsonDecode(p!.floatingManaJson!) as Map<String, dynamic>;
      expect(mana['U'], equals(0));

      // Undo the clear
      await db.matchDao.undoLastEvent(sessionId: s);

      // Check player table floating mana: restored by undoLastEvent
      p = await db.matchDao.getPlayerById('p1');
      mana = jsonDecode(p!.floatingManaJson!) as Map<String, dynamic>;
      final dbManaU = mana['U'];

      // Check reconstructStateFromEvents: mana_clear was marked isUndone: true,
      // so replay skips the clear and restores Blue mana to 5!
      final recon = await db.matchDao.reconstructStateFromEvents(s);
      final reconManaU = (recon['p1']!['floatingMana'] as Map<String, int>)['U'];

      expect(dbManaU, equals(5), reason: 'DB player table must be restored by undoLastEvent for mana_clear');
      expect(reconManaU, equals(5), reason: 'Replay restored mana because mana_clear event was marked isUndone=true');
      expect(dbManaU == reconManaU, isTrue, reason: 'undoLastEvent(mana_clear) keeps player table and event replay strictly synchronized');
    });
  });
}

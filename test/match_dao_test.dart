import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MatchDao Unit Tests', () {
    // -------------------------------------------------------------------------
    // 1. Session & Player Lifecycle CRUD
    // -------------------------------------------------------------------------
    test('createSession() atomically creates session, players, initial event, and sync outbox', () async {
      final sessionId = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 4,
        players: [
          MatchPlayersCompanion.insert(
            id: 'p1',
            sessionId: 'placeholder',
            seatOrder: 0,
            playerName: 'Alice',
          ),
          MatchPlayersCompanion.insert(
            id: 'p2',
            sessionId: 'placeholder',
            seatOrder: 1,
            playerName: 'Bob',
          ),
          MatchPlayersCompanion.insert(
            id: 'p3',
            sessionId: 'placeholder',
            seatOrder: 2,
            playerName: 'Charlie',
          ),
          MatchPlayersCompanion.insert(
            id: 'p4',
            sessionId: 'placeholder',
            seatOrder: 3,
            playerName: 'Diana',
          ),
        ],
      );

      expect(sessionId, isNotEmpty);

      // Verify session exists
      final session = await db.matchDao.getSessionById(sessionId);
      expect(session, isNotNull);
      expect(session!.format, equals('Commander'));
      expect(session.startingLife, equals(40));
      expect(session.playerCount, equals(4));
      expect(session.status, equals('active'));

      // Verify players exist and are in seat order
      final players = await db.matchDao.getPlayersForSession(sessionId);
      expect(players.length, equals(4));
      expect(players[0].playerName, equals('Alice'));
      expect(players[0].seatOrder, equals(0));
      expect(players[0].currentLife, equals(40));
      expect(players[1].playerName, equals('Bob'));

      // Verify initial session_created event
      final events = await db.matchDao.getEventsForSession(sessionId);
      expect(events.length, equals(1));
      expect(events.first.eventType, equals('session_created'));
      expect(events.first.sequenceNumber, equals(1));

      // Verify sync queue entries (1 session + 4 players + 1 event = 6 entries)
      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.isIn([sessionId, 'p1', 'p2', 'p3', 'p4', events.first.id])))
          .get();
      expect(syncEntries.length, equals(6));
    });

    test('getActiveSession() retrieves active session and ignores soft-deleted sessions', () async {
      final s1 = await db.matchDao.createSession(
        name: 'Pod Alpha',
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'P2'),
        ],
      );

      final active = await db.matchDao.getActiveSession();
      expect(active, isNotNull);
      expect(active!.id, equals(s1));

      // Soft delete s1
      await db.matchDao.softDeleteSession(s1);

      final activeAfterDelete = await db.matchDao.getActiveSession();
      expect(activeAfterDelete, isNull);
    });

    test('getPlayersForSession() preserves strict seat_order ASC', () async {
      final s = await db.matchDao.createSession(
        format: 'Standard',
        startingLife: 20,
        playerCount: 3,
        players: [
          // Insert out of order
          MatchPlayersCompanion.insert(id: 'p3', sessionId: 'x', seatOrder: 2, playerName: 'Charlie'),
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'Bob'),
        ],
      );

      final players = await db.matchDao.getPlayersForSession(s);
      expect(players.length, equals(3));
      expect(players[0].seatOrder, equals(0));
      expect(players[0].playerName, equals('Alice'));
      expect(players[1].seatOrder, equals(1));
      expect(players[1].playerName, equals('Bob'));
      expect(players[2].seatOrder, equals(2));
      expect(players[2].playerName, equals('Charlie'));
    });

    test('completeSession() and abandonSession() transition status and set endedAt', () async {
      final s1 = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Solo')],
      );

      await db.matchDao.completeSession(s1);
      final completed = await db.matchDao.getSessionById(s1);
      expect(completed!.status, equals('completed'));
      expect(completed.endedAt, isNotNull);

      final s2 = await db.matchDao.createSession(
        format: 'Brawl',
        startingLife: 30,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 0, playerName: 'Solo 2')],
      );

      await db.matchDao.abandonSession(s2);
      final abandoned = await db.matchDao.getSessionById(s2);
      expect(abandoned!.status, equals('abandoned'));
      expect(abandoned.endedAt, isNotNull);
    });

    test('softDeleteSession() marks session, players, and events as isDeleted = true', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'P2'),
        ],
      );

      await db.matchDao.softDeleteSession(s);

      // Filtered from active queries
      expect(await db.matchDao.getSessionById(s), isNull);
      expect(await db.matchDao.getPlayersForSession(s), isEmpty);
      expect(await db.matchDao.getEventsForSession(s), isEmpty);

      // Still physically in SQLite with is_deleted = 1
      final rawSession = await (db.select(db.matchSessions)..where((t) => t.id.equals(s))).getSingle();
      expect(rawSession.isDeleted, isTrue);

      final rawPlayers = await (db.select(db.matchPlayers)..where((t) => t.sessionId.equals(s))).get();
      expect(rawPlayers.every((p) => p.isDeleted), isTrue);

      final rawEvents = await (db.select(db.matchEvents)..where((t) => t.sessionId.equals(s))).get();
      expect(rawEvents.every((e) => e.isDeleted), isTrue);
    });

    // -------------------------------------------------------------------------
    // 2. Reactive Stream Watchers
    // -------------------------------------------------------------------------
    test('watchActiveSession() emits active session and updates when session state changes', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      final stream = db.matchDao.watchActiveSession();
      final first = await stream.first;
      expect(first, isNotNull);
      expect(first!.id, equals(s));

      // Abandoning triggers update
      final expectation = expectLater(
        stream,
        emitsInOrder([
          isNotNull,
          isNull, // After abandon
        ]),
      );

      await db.matchDao.abandonSession(s);
      await expectation;
    });

    test('watchPlayersForSession() reactively emits updated player records when life changes', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      final stream = db.matchDao.watchPlayersForSession(s);
      final expectation = expectLater(
        stream.map((list) => list.first.currentLife),
        emitsInOrder([
          40, // initial
          35, // after -5
          38, // after +3
        ]),
      );

      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -5);
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: 3);
      await expectation;
    });

    test('watchEventsForSession() emits newly appended events in sequence order', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      final stream = db.matchDao.watchEventsForSession(s);
      final expectation = expectLater(
        stream.map((list) => list.map((e) => e.eventType).toList()),
        emitsInOrder([
          ['session_created'],
          ['session_created', 'life_delta'],
          ['session_created', 'life_delta', 'poison'],
        ]),
      );

      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -2);
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'poison', delta: 1);
      await expectation;
    });

    // -------------------------------------------------------------------------
    // 3. Life & Damage Transactions
    // -------------------------------------------------------------------------
    test('updatePlayerLife() updates currentLife, logs life_delta event, and sets isEliminated at 0', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -40);

      final player = await db.matchDao.getPlayerById('p1');
      expect(player!.currentLife, equals(0));
      expect(player.isEliminated, isTrue);
      expect(player.eliminatedAt, isNotNull);

      final events = await db.matchDao.getEventsForSession(s);
      expect(events.length, equals(2));
      expect(events.last.eventType, equals('life_delta'));
      expect(events.last.delta, equals(-40));
      expect(events.last.value, equals(0));
    });

    test('recordCommanderDamage() tracks damage matrix per commander and flags lethal at >= 21', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'alice', sessionId: 'x', seatOrder: 0, playerName: 'Alice'),
          MatchPlayersCompanion.insert(id: 'bob', sessionId: 'x', seatOrder: 1, playerName: 'Bob'),
        ],
      );

      // Bob takes 15 commander damage from Alice
      await db.matchDao.recordCommanderDamage(
        sessionId: s,
        targetPlayerId: 'bob',
        sourcePlayerId: 'alice',
        delta: 15,
        applyLifeDelta: true,
      );

      var bob = await db.matchDao.getPlayerById('bob');
      expect(bob!.currentLife, equals(25)); // 40 - 15 = 25
      expect(bob.isEliminated, isFalse);

      // Bob takes 6 more commander damage from Alice (total = 21 -> lethal)
      await db.matchDao.recordCommanderDamage(
        sessionId: s,
        targetPlayerId: 'bob',
        sourcePlayerId: 'alice',
        delta: 6,
        applyLifeDelta: true,
      );

      bob = await db.matchDao.getPlayerById('bob');
      expect(bob!.currentLife, equals(19)); // 25 - 6 = 19
      expect(bob.isEliminated, isTrue); // Lethal commander damage (21 >= 21)

      final cmdDamage = jsonDecode(bob.commanderDamageJson!) as Map<String, dynamic>;
      expect(cmdDamage['alice'], equals(21));
    });

    test('recordCommanderDamage() respects applyLifeDelta flag', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'P2'),
        ],
      );

      // Damage applied WITHOUT life reduction
      await db.matchDao.recordCommanderDamage(
        sessionId: s,
        targetPlayerId: 'p2',
        sourcePlayerId: 'p1',
        delta: 5,
        applyLifeDelta: false,
      );

      final p2 = await db.matchDao.getPlayerById('p2');
      expect(p2!.currentLife, equals(40)); // Life untouched
      final cmdDmg = jsonDecode(p2.commanderDamageJson!) as Map<String, dynamic>;
      expect(cmdDmg['p1'], equals(5));
    });

    // -------------------------------------------------------------------------
    // 4. Secondary Counters & Pod-Wide Exclusive Tokens
    // -------------------------------------------------------------------------
    test('poison counter increments and triggers lethal defeat at 10 poison', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'poison', delta: 9);
      var p1 = await db.matchDao.getPlayerById('p1');
      expect(p1!.poison, equals(9));
      expect(p1.isEliminated, isFalse);

      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'poison', delta: 1);
      p1 = await db.matchDao.getPlayerById('p1');
      expect(p1!.poison, equals(10));
      expect(p1.isEliminated, isTrue);
    });

    test('monarch token is pod-wide exclusive: claiming on player A strips from player B', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'Bob'),
        ],
      );

      // Alice claims monarch
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'monarch', delta: 1);
      var p1 = await db.matchDao.getPlayerById('p1');
      var p2 = await db.matchDao.getPlayerById('p2');
      expect(p1!.isMonarch, isTrue);
      expect(p2!.isMonarch, isFalse);

      // Bob claims monarch
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p2', counterType: 'monarch', delta: 1);
      p1 = await db.matchDao.getPlayerById('p1');
      p2 = await db.matchDao.getPlayerById('p2');
      expect(p1!.isMonarch, isFalse);
      expect(p2!.isMonarch, isTrue);
    });

    test('initiative token is pod-wide exclusive: claiming on player B strips from player A', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'Bob'),
        ],
      );

      // Alice claims initiative
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'initiative', delta: 1);
      var p1 = await db.matchDao.getPlayerById('p1');
      var p2 = await db.matchDao.getPlayerById('p2');
      expect(p1!.hasInitiative, isTrue);
      expect(p2!.hasInitiative, isFalse);

      // Bob takes initiative
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p2', counterType: 'initiative', delta: 1);
      p1 = await db.matchDao.getPlayerById('p1');
      p2 = await db.matchDao.getPlayerById('p2');
      expect(p1!.hasInitiative, isFalse);
      expect(p2!.hasInitiative, isTrue);
    });

    test('energy, experience, and commanderTax track independently', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'energy', delta: 3);
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'experience', delta: 5);
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'commander_tax', delta: 4);

      final p = await db.matchDao.getPlayerById('p1');
      expect(p!.energy, equals(3));
      expect(p.experience, equals(5));
      expect(p.commanderTax, equals(4));
    });

    // -------------------------------------------------------------------------
    // 5. Floating Mana Pool & Storm Drawers
    // -------------------------------------------------------------------------
    test('recordManaChange() increments individual WUBRGC mana pips', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      await db.matchDao.recordManaChange(sessionId: s, playerId: 'p1', manaColor: 'U', delta: 3);
      await db.matchDao.recordManaChange(sessionId: s, playerId: 'p1', manaColor: 'R', delta: 2);

      final p = await db.matchDao.getPlayerById('p1');
      final mana = jsonDecode(p!.floatingManaJson!) as Map<String, dynamic>;
      expect(mana['U'], equals(3));
      expect(mana['R'], equals(2));
      expect(mana['W'], equals(0));
    });

    test('clearManaPool() zeroes all 6 floating mana pools and storm counter in a single transaction', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      await db.matchDao.recordManaChange(sessionId: s, playerId: 'p1', manaColor: 'G', delta: 5);
      await db.matchDao.recordStormChange(sessionId: s, playerId: 'p1', delta: 7);

      var p = await db.matchDao.getPlayerById('p1');
      expect(p!.stormCount, equals(7));

      await db.matchDao.clearManaPool(sessionId: s, playerId: 'p1');

      p = await db.matchDao.getPlayerById('p1');
      expect(p!.stormCount, equals(0));
      final mana = jsonDecode(p.floatingManaJson!) as Map<String, dynamic>;
      for (final key in ['W', 'U', 'B', 'R', 'G', 'C']) {
        expect(mana[key], equals(0));
      }
    });

    // -------------------------------------------------------------------------
    // 6. Lobby Reset
    // -------------------------------------------------------------------------
    test('resetSession() reverts life and counters while strictly preserving seat order and deck info', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(
            id: 'p1',
            sessionId: 'x',
            seatOrder: 0,
            playerName: 'Alice',
            commanderName: const Value('Atraxa'),
          ),
          MatchPlayersCompanion.insert(
            id: 'p2',
            sessionId: 'x',
            seatOrder: 1,
            playerName: 'Bob',
            commanderName: const Value('Urza'),
          ),
        ],
      );

      // Modify life and counters
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -15);
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p2', counterType: 'poison', delta: 5);
      await db.matchDao.recordCommanderDamage(
        sessionId: s,
        targetPlayerId: 'p2',
        sourcePlayerId: 'p1',
        delta: 7,
      );

      // Reset
      await db.matchDao.resetSession(s, 40);

      final players = await db.matchDao.getPlayersForSession(s);
      expect(players[0].currentLife, equals(40));
      expect(players[0].commanderName, equals('Atraxa'));
      expect(players[0].poison, equals(0));
      expect(players[0].isEliminated, isFalse);

      expect(players[1].currentLife, equals(40));
      expect(players[1].commanderName, equals('Urza'));
      expect(players[1].poison, equals(0));
      expect(players[1].isEliminated, isFalse);
      expect(players[1].commanderDamageJson, equals('{}'));
    });

    // -------------------------------------------------------------------------
    // 7. Event Sourcing, Monotonic Ordering & Replay
    // -------------------------------------------------------------------------
    test('sequenceNumber strictly increments monotonically per session (1, 2, 3...)', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'P1')],
      );

      // seq 1 is session_created
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -1); // seq 2
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -2); // seq 3
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'energy', delta: 1); // seq 4

      final events = await db.matchDao.getEventsForSession(s);
      expect(events.length, equals(4));
      expect(events.map((e) => e.sequenceNumber).toList(), equals([1, 2, 3, 4]));
    });

    test('reconstructStateFromEvents() mathematically matches denormalized MatchPlayers state', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 2,
        players: [
          MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice'),
          MatchPlayersCompanion.insert(id: 'p2', sessionId: 'x', seatOrder: 1, playerName: 'Bob'),
        ],
      );

      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -5);
      await db.matchDao.recordCounterChange(sessionId: s, playerId: 'p1', counterType: 'poison', delta: 3);
      await db.matchDao.recordCommanderDamage(sessionId: s, targetPlayerId: 'p2', sourcePlayerId: 'p1', delta: 8);

      final reconstructed = await db.matchDao.reconstructStateFromEvents(s);
      final p1 = await db.matchDao.getPlayerById('p1');
      final p2 = await db.matchDao.getPlayerById('p2');

      expect(reconstructed['p1']!['life'], equals(p1!.currentLife));
      expect(reconstructed['p1']!['poison'], equals(p1.poison));
      expect(reconstructed['p2']!['life'], equals(p2!.currentLife));
      expect(reconstructed['p2']!['commanderDamage']['p1'], equals(8));
    });

    // -------------------------------------------------------------------------
    // 8. Event Sourcing Undo Mechanism
    // -------------------------------------------------------------------------
    test('undoLastEvent() reverses life delta, marks event undone, and logs undo event', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -5);
      var p1 = await db.matchDao.getPlayerById('p1');
      expect(p1!.currentLife, equals(35));

      final undoneEvent = await db.matchDao.undoLastEvent(sessionId: s);
      expect(undoneEvent, isNotNull);
      expect(undoneEvent!.eventType, equals('life_delta'));

      p1 = await db.matchDao.getPlayerById('p1');
      expect(p1!.currentLife, equals(40)); // Restored

      final events = await db.matchDao.getEventsForSession(s);
      expect(events.last.eventType, equals('undo'));
    });

    test('undoLastEvent() un-eliminates a player if restored life > 0 or commander damage < 21', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      // Lethal drop to 0
      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -40);
      var p1 = await db.matchDao.getPlayerById('p1');
      expect(p1!.isEliminated, isTrue);

      // Undo lethal drop
      await db.matchDao.undoLastEvent(sessionId: s);
      p1 = await db.matchDao.getPlayerById('p1');
      expect(p1!.currentLife, equals(40));
      expect(p1.isEliminated, isFalse);
      expect(p1.eliminatedAt, isNull);
    });

    // -------------------------------------------------------------------------
    // 9. Concurrency & Transaction Atomicity Rollback
    // -------------------------------------------------------------------------
    test('transaction rolls back completely if an error occurs mid-transaction (zero partial writes)', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      // Attempting an update for a non-existent player throws ArgumentError
      expect(
        () => db.matchDao.updatePlayerLife(sessionId: s, playerId: 'non_existent_player', delta: -10),
        throwsA(isA<ArgumentError>()),
      );

      // No stray events recorded
      final events = await db.matchDao.getEventsForSession(s);
      expect(events.length, equals(1)); // Only initial session_created
    });

    // -------------------------------------------------------------------------
    // 10. SyncQueue Outbox Verification
    // -------------------------------------------------------------------------
    test('all mutations log corresponding entries in sync_queue with correct entityType and operation', () async {
      final s = await db.matchDao.createSession(
        format: 'Commander',
        startingLife: 40,
        playerCount: 1,
        players: [MatchPlayersCompanion.insert(id: 'p1', sessionId: 'x', seatOrder: 0, playerName: 'Alice')],
      );

      await db.matchDao.updatePlayerLife(sessionId: s, playerId: 'p1', delta: -3);

      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('match_event')))
          .get();

      expect(syncEntries.length, equals(2)); // session_created + life_delta
      expect(syncEntries.every((e) => e.operation == 'INSERT'), isTrue);
    });
  });
}

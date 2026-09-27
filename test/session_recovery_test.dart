import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';
import 'package:countr/features/life_counter/presentation/dialogs/session_recovery_dialog.dart';

/// Helper to simulate lifecycle transitions matching Flutter 3.13+ state machine edges.
void transitionLifecycle(WidgetTester tester, AppLifecycleState target) {
  final current = tester.binding.lifecycleState ?? AppLifecycleState.resumed;
  if (current == target) return;

  if (target == AppLifecycleState.paused) {
    if (current == AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    } else if (current == AppLifecycleState.inactive) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  } else if (target == AppLifecycleState.resumed) {
    if (current == AppLifecycleState.paused) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    } else if (current == AppLifecycleState.hidden) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  } else if (target == AppLifecycleState.inactive) {
    if (current == AppLifecycleState.paused) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  } else if (target == AppLifecycleState.hidden) {
    if (current == AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
}

/// Minimal harness widget demonstrating session recovery flow.
class SessionRecoveryTestHarness extends ConsumerStatefulWidget {
  const SessionRecoveryTestHarness({super.key});

  @override
  ConsumerState<SessionRecoveryTestHarness> createState() => _SessionRecoveryTestHarnessState();
}

class _SessionRecoveryTestHarnessState extends ConsumerState<SessionRecoveryTestHarness> {
  PodState? _currentPodState;
  bool _showingNewGameSetup = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleChange,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForActiveSession());
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Flush pending DB writes on pause to guarantee zero loss
      ref.read(matchSessionRepositoryProvider).flush();
    }
  }

  Future<void> _checkForActiveSession() async {
    final repo = ref.read(matchSessionRepositoryProvider);
    final session = await repo.getActiveSessionMetadata();
    if (!mounted) return;

    if (session != null) {
      final db = ref.read(appDatabaseProvider);
      final players = await db.matchDao.getPlayersForSession(session.id);

      if (!mounted) return;
      SessionRecoveryDialog.show(
        context: context,
        session: session,
        players: players,
        onContinue: () async {
          Navigator.of(context, rootNavigator: true).pop();
          final pod = await repo.restoreActiveSession();
          if (mounted) {
            setState(() {
              _currentPodState = pod;
            });
          }
        },
        onStartNew: () async {
          Navigator.of(context, rootNavigator: true).pop();
          if (mounted) {
            setState(() {
              _showingNewGameSetup = true;
            });
          }
          await repo.abandonSession(session.id);
        },
      );
    } else {
      setState(() {
        _showingNewGameSetup = true;
      });
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPodState != null) {
      final pod = _currentPodState!;
      return Scaffold(
        key: const Key('active_pod_screen'),
        body: Column(
          children: [
            Text('Session: ${pod.sessionId}'),
            Text('Format: ${pod.format}'),
            for (final p in pod.players)
              ListTile(
                key: Key('player_tile_${p.id}'),
                title: Text(p.name),
                subtitle: Text('Life: ${p.life} • Poison: ${p.poison}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('decrement_life_${p.id}'),
                      icon: const Icon(Icons.remove),
                      onPressed: () async {
                        final repo = ref.read(matchSessionRepositoryProvider);
                        await repo.recordLifeDelta(
                          sessionId: pod.sessionId,
                          playerId: p.id,
                          delta: -1,
                          sequenceNumber: pod.sequenceNumber + 1,
                        );
                        final updated = await repo.restoreActiveSession();
                        setState(() => _currentPodState = updated);
                      },
                    ),
                    IconButton(
                      key: Key('increment_life_${p.id}'),
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final repo = ref.read(matchSessionRepositoryProvider);
                        await repo.recordLifeDelta(
                          sessionId: pod.sessionId,
                          playerId: p.id,
                          delta: 1,
                          sequenceNumber: pod.sequenceNumber + 1,
                        );
                        final updated = await repo.restoreActiveSession();
                        setState(() => _currentPodState = updated);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (_showingNewGameSetup) {
      return const Scaffold(
        key: Key('new_game_setup_screen'),
        body: Center(child: Text('New Game Setup Wizard')),
      );
    }

    return const Scaffold(
      key: Key('loading_screen'),
      body: Center(child: Text('Loading...')),
    );
  }
}

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

  Widget buildTestWidget({required AppDatabase db, required MatchSessionRepository repo}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        matchSessionRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: SessionRecoveryTestHarness(),
      ),
    );
  }

  group('Session Recovery & Lifecycle Widget Tests', () {
    testWidgets('T1: Cold launch without active session opens New Game Setup directly', (tester) async {
      await tester.pumpWidget(buildTestWidget(db: database, repo: repository));
      await tester.pumpAndSettle();

      expect(find.byType(SessionRecoveryDialog), findsNothing);
      expect(find.byKey(const Key('new_game_setup_screen')), findsOneWidget);
    });

    testWidgets('T2: Cold launch with active session prompts SessionRecoveryDialog', (tester) async {
      // Seed an active session with 4 players
      await tester.runAsync(() async {
        await repository.createSession(
          format: 'Commander',
          startingLife: 40,
          players: [
            const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
            const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
            const PlayerSetupConfig(id: 'p3', seatOrder: 2, name: 'Charlie', startingLife: 40),
            const PlayerSetupConfig(id: 'p4', seatOrder: 3, name: 'Diana', startingLife: 40),
          ],
        );
      });

      await tester.pumpWidget(buildTestWidget(db: database, repo: repository));
      await tester.pumpAndSettle();

      expect(find.byType(SessionRecoveryDialog), findsOneWidget);
      expect(find.text('Active Match Detected'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Diana'), findsOneWidget);
      expect(find.byKey(const Key('session_recovery_continue_button')), findsOneWidget);
      expect(find.byKey(const Key('session_recovery_start_new_button')), findsOneWidget);
    });

    testWidgets('T3: Tapping Continue Match restores PodState and mounts active pod screen', (tester) async {
      late PodState initial;
      await tester.runAsync(() async {
        initial = await repository.createSession(
          format: 'Commander',
          startingLife: 40,
          players: [
            const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
            const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
          ],
        );

        // Alice took 4 damage, Bob took 7 damage before crash
        await repository.recordLifeDelta(sessionId: initial.sessionId, playerId: 'p1', delta: -4, sequenceNumber: 2);
        await repository.recordLifeDelta(sessionId: initial.sessionId, playerId: 'p2', delta: -7, sequenceNumber: 3);
      });

      await tester.pumpWidget(buildTestWidget(db: database, repo: repository));
      await tester.pumpAndSettle();

      expect(find.byType(SessionRecoveryDialog), findsOneWidget);

      // Tap Continue Match
      await tester.tap(find.byKey(const Key('session_recovery_continue_button')));
      await tester.pumpAndSettle();

      expect(find.byType(SessionRecoveryDialog), findsNothing);
      expect(find.byKey(const Key('active_pod_screen')), findsOneWidget);
      expect(find.text('Life: 36 • Poison: 0'), findsOneWidget); // Alice (40 - 4 = 36)
      expect(find.text('Life: 33 • Poison: 0'), findsOneWidget); // Bob (40 - 7 = 33)
    });

    testWidgets('T4: Tapping Start New Game marks session abandoned and opens setup wizard', (tester) async {
      await tester.runAsync(() async {
        await repository.createSession(
          format: 'Commander',
          startingLife: 40,
          players: [
            const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          ],
        );
      });

      await tester.pumpWidget(buildTestWidget(db: database, repo: repository));
      await tester.pumpAndSettle();

      expect(find.byType(SessionRecoveryDialog), findsOneWidget);

      // Tap Start New Game
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('session_recovery_start_new_button')));
        await tester.pumpAndSettle();
      });

      expect(find.byType(SessionRecoveryDialog), findsNothing);
      expect(find.byKey(const Key('new_game_setup_screen')), findsOneWidget);

      // Verify in DB that session was marked abandoned
      final sessionMeta = await tester.runAsync(() => repository.getActiveSessionMetadata());
      expect(sessionMeta, isNull);
    });

    testWidgets('T5: Rapid delta input before sudden lifecycle pause guarantees zero data loss', (tester) async {
      await tester.runAsync(() async {
        await repository.createSession(
          format: 'Commander',
          startingLife: 40,
          players: [
            const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          ],
        );
      });

      await tester.pumpWidget(buildTestWidget(db: database, repo: repository));
      await tester.pumpAndSettle();

      // Continue match
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('session_recovery_continue_button')));
        await tester.pumpAndSettle();
      });

      expect(find.byKey(const Key('active_pod_screen')), findsOneWidget);

      // Tap decrement 5 times in rapid succession
      await tester.runAsync(() async {
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('decrement_life_p1')));
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
      });

      // App is immediately backgrounded / paused by OS
      transitionLifecycle(tester, AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // Simulate process restart: create a new repository instance pointing to the same database
      await tester.runAsync(() async {
        final freshRepo = MatchSessionRepository(db: database);
        final restored = await freshRepo.restoreActiveSession();

        expect(restored, isNotNull);
        expect(restored!.players.first.life, equals(35)); // 40 - 5 = 35 exactly
        freshRepo.dispose();
      });
    });

    test('T6: Reconstitutes complex state: Commander Damage Matrix, Poison, Monarch, Storm', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );

      // 1. Bob takes 8 commander damage from Alice (source: p1)
      await repository.recordCommanderDamage(
        sessionId: initial.sessionId,
        targetPlayerId: 'p2',
        sourcePlayerId: 'p1',
        delta: 8,
        sequenceNumber: 2,
      );

      // 2. Alice gains 3 poison counters
      await repository.recordCounterChange(
        sessionId: initial.sessionId,
        playerId: 'p1',
        counterType: 'poison',
        delta: 3,
        sequenceNumber: 3,
      );

      // 3. Bob claims Monarch
      await repository.recordCounterChange(
        sessionId: initial.sessionId,
        playerId: 'p2',
        counterType: 'monarch',
        delta: 1,
        sequenceNumber: 4,
      );

      // 4. Alice floats 2 red mana and increases storm count to 4
      await repository.recordManaChange(
        sessionId: initial.sessionId,
        playerId: 'p1',
        color: 'R',
        delta: 2,
        sequenceNumber: 5,
      );
      await repository.recordStormChange(
        sessionId: initial.sessionId,
        playerId: 'p1',
        delta: 4,
        sequenceNumber: 6,
      );

      // Restore session and verify full state reconstruction
      final restored = await repository.restoreActiveSession();
      expect(restored, isNotNull);

      final alice = restored!.players.firstWhere((p) => p.id == 'p1');
      final bob = restored.players.firstWhere((p) => p.id == 'p2');

      // Alice assertions
      expect(alice.poison, equals(3));
      expect(alice.floatingMana['R'], equals(2));
      expect(alice.stormCount, equals(4));
      expect(alice.isMonarch, isFalse);

      // Bob assertions
      expect(bob.life, equals(32)); // 40 - 8 = 32
      expect(bob.commanderDamageTaken['p1'], equals(8));
      expect(bob.isMonarch, isTrue);
    });

    test('T7: Reset Game preserves seating and decks while clearing damage & counters', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40, commanderName: 'Atraxa'),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40, commanderName: 'Urza'),
        ],
      );

      // Apply damage and counters
      await repository.recordLifeDelta(sessionId: initial.sessionId, playerId: 'p1', delta: -15, sequenceNumber: 2);
      await repository.recordCounterChange(sessionId: initial.sessionId, playerId: 'p2', counterType: 'poison', delta: 4, sequenceNumber: 3);

      // Execute Reset Game
      final resetState = await repository.resetSession(initial.sessionId, 40);

      expect(resetState.players[0].life, equals(40));
      expect(resetState.players[0].name, equals('Alice'));
      expect(resetState.players[0].commanderName, equals('Atraxa'));

      expect(resetState.players[1].life, equals(40));
      expect(resetState.players[1].poison, equals(0));
      expect(resetState.players[1].name, equals('Bob'));
      expect(resetState.players[1].commanderName, equals('Urza'));
    });

    test('T8: Event Undo rolls back state and persists correctly across reload', () async {
      final initial = await repository.createSession(
        format: 'Commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      // Alice accidentally decrements by 5
      await repository.recordLifeDelta(sessionId: initial.sessionId, playerId: 'p1', delta: -5, sequenceNumber: 2);
      var current = await repository.restoreActiveSession();
      expect(current!.players.first.life, equals(35));

      // User presses Undo
      final undone = await repository.undoLastEvent(initial.sessionId);
      expect(undone!.players.first.life, equals(40));

      // Simulate app restart and restore
      final freshRepo = MatchSessionRepository(db: database);
      final restoredAfterRestart = await freshRepo.restoreActiveSession();
      expect(restoredAfterRestart!.players.first.life, equals(40));
      freshRepo.dispose();
    });
  });
}

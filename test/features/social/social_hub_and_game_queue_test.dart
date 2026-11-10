// Copyright (c) 2026 Countr. All rights reserved.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/domain/models/group_game_models.dart';
import 'package:countr/features/feed/presentation/providers/group_game_providers.dart';
import 'package:countr/features/feed/presentation/screens/friends_hub_screen.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    await db.vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest({String? initialTab}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
      ],
      child: MaterialApp(
        home: FriendsHubScreen(initialTab: initialTab),
      ),
    );
  }

  group('2-Tab Social Hub (Friends | Groups)', () {
    testWidgets('Renders top tabs Friends and Groups with backward compatibility for search', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Main top tabs
      expect(find.byKey(const Key('friends_tab_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_groups')), findsOneWidget);

      // Friends tab search bar preserved
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);

      // Backward compatible sub-tabs
      expect(find.byKey(const Key('friends_tab_my_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_requests')), findsOneWidget);
    });

    testWidgets('Switching to Groups tab displays active LGS EDH pods', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest(initialTab: 'groups'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Seeded pods are rendered
      expect(find.byKey(const Key('group_game_card_game_tbs_table_1')), findsOneWidget);
      expect(find.byKey(const Key('group_game_card_game_emerald_coast_table_2')), findsOneWidget);

      expect(find.text('TBS Comics Table 1'), findsOneWidget);
      expect(find.text('Emerald Coast EDH Table 2'), findsOneWidget);

      // Reserve Spot button is visible
      expect(find.byKey(const Key('reserve_spot_btn_game_tbs_table_1')), findsOneWidget);
    });
  });

  group('Waitlist Queue Reservation & Seat Rotation Workflow', () {
    testWidgets('Reserving a spot opens deck sheet and adds user to waitlist queue', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest(initialTab: 'groups'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final reserveBtn = find.byKey(const Key('reserve_spot_btn_game_tbs_table_1'));
      expect(reserveBtn, findsOneWidget);

      // Tap Reserve Spot in Next Game
      await tester.tap(reserveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal sheet opens
      expect(find.byKey(const Key('reserve_spot_deck_sheet')), findsOneWidget);
      expect(find.byKey(const Key('confirm_join_queue_btn')), findsOneWidget);

      // Confirm reservation
      await tester.tap(find.byKey(const Key('confirm_join_queue_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Queue state updates: Leave Queue button appears
      expect(find.byKey(const Key('leave_queue_btn_game_tbs_table_1')), findsOneWidget);
      expect(find.text('You are #1 in line'), findsOneWidget);
    });

    test('Queue rotation seamlessly pulls waitlisted player into active pod seat with 40 life and preloaded deck', () {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(groupGamesProvider.notifier);

      // 1. Initially Table 1 has 4 seated players, 0 in waitlist
      var games = container.read(groupGamesProvider);
      var table1 = games.firstWhere((g) => g.id == 'game_tbs_table_1');
      expect(table1.waitlistCount, equals(0));
      expect(table1.seatedPlayers.length, equals(4));

      // 2. Reserve spot with a chosen deck and commander
      final entry = WaitlistQueueEntry(
        userId: 'user-current-me',
        username: '@collector_me',
        displayName: 'Foil Enthusiast Me',
        deckId: 'deck_edgar_markov_vampires',
        deckName: 'Edgar Markov Vampires',
        commanderCardId: 'card_edgar_markov',
        commanderName: 'Edgar Markov',
        joinedAt: DateTime.now(),
      );

      notifier.reserveSpotInGame(
        gameId: 'game_tbs_table_1',
        entry: entry,
      );

      games = container.read(groupGamesProvider);
      table1 = games.firstWhere((g) => g.id == 'game_tbs_table_1');
      expect(table1.waitlistCount, equals(1));
      expect(table1.isUserQueued('user-current-me'), isTrue);

      // 3. Rotate queue into seats
      final resultingPodState = notifier.rotateQueueIntoSeats('game_tbs_table_1');
      expect(resultingPodState, isNotNull);

      // Waitlist drops back to 0
      games = container.read(groupGamesProvider);
      table1 = games.firstWhere((g) => g.id == 'game_tbs_table_1');
      expect(table1.waitlistCount, equals(0));

      // Queued user is now seated
      final seatedUser = resultingPodState!.players.firstWhere((p) => p.id == 'user-current-me');
      expect(seatedUser.name, equals('Foil Enthusiast Me'));
      expect(seatedUser.deckId, equals('deck_edgar_markov_vampires'));
      expect(seatedUser.commanderName, equals('Edgar Markov'));
      expect(seatedUser.life, equals(40));

      // All 4 players have 40 starting life
      for (final player in resultingPodState.players) {
        expect(player.life, equals(40));
      }
    });

    testWidgets('Rotated PodState mounts directly into PodScaffoldWidget without configuration errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(groupGamesProvider.notifier);
      notifier.reserveSpotInGame(
        gameId: 'game_tbs_table_1',
        entry: WaitlistQueueEntry(
          userId: 'user-current-me',
          username: '@collector_me',
          displayName: 'Foil Collector',
          commanderName: 'Edgar Markov',
          joinedAt: DateTime.now(),
        ),
      );

      final podState = notifier.rotateQueueIntoSeats('game_tbs_table_1')!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PodScaffoldWidget(podState: podState),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pod mounts with 4 players, 40 life
      expect(find.byType(PodScaffoldWidget), findsOneWidget);
    });
  });
}

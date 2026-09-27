// Copyright (c) 2026 Countr. All rights reserved.
// Unit test suite for Riverpod PodController state binding layer.

import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PodState initialPod;
  late PodController controller;

  setUp(() {
    initialPod = const PodState(
      sessionId: 'test_session',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ],
    );
    controller = PodController(initialState: initialPod);
  });

  tearDown(() {
    controller.dispose();
  });

  group('PodController Standalone Mechanics', () {
    test('adjustLife modifies life total and updates sequence number', () async {
      await controller.adjustLife('p1', -3);
      expect(controller.state.getPlayer('p1')!.life, 37);
      expect(controller.state.sequenceNumber, 1);

      await controller.adjustLife('p1', 5);
      expect(controller.state.getPlayer('p1')!.life, 42);
      expect(controller.state.sequenceNumber, 2);
    });

    test('recordCommanderDamage modifies damage taken and reduces life', () async {
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 4,
      );

      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, 36);
      expect(p1.commanderDamageTaken['p2'], 4);
      expect(p1.hasAnyLethalCommanderDamage, isFalse);

      // Hit 21 lethal threshold
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 17,
      );
      final p1Lethal = controller.state.getPlayer('p1')!;
      expect(p1Lethal.commanderDamageTaken['p2'], 21);
      expect(p1Lethal.hasAnyLethalCommanderDamage, isTrue);
      expect(p1Lethal.isEliminated, isTrue);
    });

    test('adjustMana updates mana pool and increments storm count on positive delta', () async {
      await controller.adjustMana(playerId: 'p1', color: 'U', delta: 2);
      expect(controller.state.getPlayer('p1')!.floatingMana['U'], 2);
      expect(controller.state.getPlayer('p1')!.stormCount, 1);

      await controller.adjustMana(playerId: 'p1', color: 'R', delta: 1);
      expect(controller.state.getPlayer('p1')!.floatingMana['R'], 1);
      expect(controller.state.getPlayer('p1')!.stormCount, 2);

      // Decrement does not increment storm count
      await controller.adjustMana(playerId: 'p1', color: 'U', delta: -1);
      expect(controller.state.getPlayer('p1')!.floatingMana['U'], 1);
      expect(controller.state.getPlayer('p1')!.stormCount, 2);
    });

    test('adjustMana clamps negative mana to 0', () async {
      await controller.adjustMana(playerId: 'p1', color: 'B', delta: -5);
      expect(controller.state.getPlayer('p1')!.floatingMana['B'], 0);
    });

    test('clearManaPool zeroes all 6 colors and resets storm count', () async {
      await controller.adjustMana(playerId: 'p1', color: 'W', delta: 3);
      await controller.adjustMana(playerId: 'p1', color: 'G', delta: 2);
      expect(controller.state.getPlayer('p1')!.floatingMana['W'], 3);
      expect(controller.state.getPlayer('p1')!.floatingMana['G'], 2);
      expect(controller.state.getPlayer('p1')!.stormCount, 2);

      await controller.clearManaPool('p1');

      final p1 = controller.state.getPlayer('p1')!;
      for (final color in ['W', 'U', 'B', 'R', 'G', 'C']) {
        expect(p1.floatingMana[color], 0);
      }
      expect(p1.stormCount, 0);
      expect(p1.life, 40); // Untouched
    });

    test('claimToken enforces pod-wide exclusivity for Monarch and Initiative', () async {
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');
      expect(controller.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p2')!.isMonarch, isFalse);

      await controller.claimToken(tokenType: 'monarch', claimantId: 'p2');
      expect(controller.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p2')!.isMonarch, isTrue);
    });

    test('toggleDayNight flips isDay across pod', () async {
      expect(controller.state.isDay, isTrue);
      await controller.toggleDayNight();
      expect(controller.state.isDay, isFalse);
      await controller.toggleDayNight();
      expect(controller.state.isDay, isTrue);
    });

    test('resetGame resets counters and life while preserving seating', () async {
      await controller.adjustLife('p1', -15);
      await controller.adjustMana(playerId: 'p1', color: 'U', delta: 4);
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');

      await controller.resetGame(40);

      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, 40);
      expect(p1.floatingMana['U'], 0);
      expect(p1.stormCount, 0);
      expect(p1.isMonarch, isFalse);
      expect(p1.name, 'Alice');
      expect(p1.seatIndex, 0);
    });
  });
}

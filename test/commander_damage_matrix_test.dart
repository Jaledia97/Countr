// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_damage_matrix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestHarness(Widget child, {Size size = const Size(800, 600)}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('CommanderDamageMatrixWidget Tests (Features 32 & 33)', () {
    const targetPlayer = PodPlayerState(
      id: 'p1',
      seatIndex: 0,
      name: 'Alice',
      life: 40,
      commanderDamageTaken: {'p2': 6, 'p3': 21},
    );

    const opp2 = PodPlayerState(
      id: 'p2',
      seatIndex: 1,
      name: 'Bob',
      life: 40,
      commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/front/b/o/bob.jpg',
    );

    const opp3 = PodPlayerState(
      id: 'p3',
      seatIndex: 2,
      name: 'Charlie',
      life: 40,
    );

    testWidgets('renders opposing commander avatar buttons with short name and damage tally',
        (tester) async {
      String? damagedTarget;
      String? sourceOpponent;
      int damageAmount = 0;

      await tester.pumpWidget(
        buildTestHarness(
          CommanderDamageMatrixWidget(
            player: targetPlayer,
            opponents: const [opp2, opp3],
            isTablet: true,
            onCommanderDamage: (oppId, delta) {
              damagedTarget = targetPlayer.id;
              sourceOpponent = oppId;
              damageAmount = delta;
            },
          ),
        ),
      );

      // Verify buttons exist with correct keys
      expect(find.byKey(const Key('cmd_damage_btn_p1_from_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_btn_p1_from_p3')), findsOneWidget);

      // Verify short name and damage tally
      expect(find.text('Bob: 6'), findsOneWidget);
      expect(find.text('Cha: 21'), findsOneWidget);

      // Verify avatar rendering: opp2 has CountrCachedImage, opp3 has fallback initial
      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.text('C'), findsOneWidget); // Charlie's initial

      // Tap Bob's avatar button -> +1 damage
      await tester.tap(find.byKey(const Key('cmd_damage_btn_p1_from_p2')));
      await tester.pump();
      expect(damagedTarget, 'p1');
      expect(sourceOpponent, 'p2');
      expect(damageAmount, 1);

      // Long press Charlie's avatar button -> -1 damage
      await tester.longPress(find.byKey(const Key('cmd_damage_btn_p1_from_p3')));
      await tester.pump();
      expect(sourceOpponent, 'p3');
      expect(damageAmount, -1);
    });

    testWidgets('empty opponents list renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const CommanderDamageMatrixWidget(
            player: targetPlayer,
            opponents: [],
            isTablet: true,
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('phone mode renders Wrap layout instead of SingleChildScrollView',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const CommanderDamageMatrixWidget(
            player: targetPlayer,
            opponents: [opp2, opp3],
            isTablet: false,
          ),
          size: const Size(360, 600),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('21 damage triggers red lethal background styling on button',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const CommanderDamageMatrixWidget(
            player: targetPlayer,
            opponents: [opp2, opp3],
            isTablet: true,
          ),
        ),
      );

      // Charlie has 21 damage -> lethal styling
      final charlieBtnFinder = find.ancestor(
        of: find.text('Cha: 21'),
        matching: find.byType(AnimatedContainer),
      );
      expect(charlieBtnFinder, findsOneWidget);

      final animatedContainer = tester.widget<AnimatedContainer>(charlieBtnFinder);
      final decoration = animatedContainer.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.red.shade700));
    });
  });
}

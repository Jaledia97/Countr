// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M5-2: Empirical Adversarial Stress Suite for Milestone 5 Gate.
// Targets: Database Isolation Bleed, Concurrent Transitions, Boundary Extrema, Zero Overflow.

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M5-2: Empirical Adversarial Stress & Isolation Suite', () {
    // =========================================================================
    // 1. Database Isolation & Zero Bleed Stress
    // =========================================================================
    group('1. Database Isolation & Zero Isolation Bleed', () {
      test('1.1. Dual concurrent AppDatabase instances operate in complete isolation without state bleed', () async {
        final db1 = AppDatabase(NativeDatabase.memory());
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db1.close();
          await db2.close();
        });

        final dao1 = VaultDao(db1);

        // Hard clear all items to test pure isolation from zero baseline
        await db1.delete(db1.vaultItems).go();
        await db2.delete(db2.vaultItems).go();

        expect(await db1.select(db1.vaultItems).get(), isEmpty);
        expect(await db2.select(db2.vaultItems).get(), isEmpty);

        // Insert 100 items into db1 concurrently
        final insertFutures = List.generate(100, (i) {
          return db1.into(db1.vaultItems).insert(
                VaultItemsCompanion.insert(
                  id: 'db1_item_$i',
                  collectionType: 'mtg',
                  name: 'Isolated Mox $i',
                  setOrSeries: 'LEA',
                  imageUrl: 'https://cards.scryfall.io/mox.jpg',
                  acquiredPrice: 100.0 + i,
                  acquiredDate: DateTime(2024, 1, 1),
                  quantity: const drift.Value(1),
                  condition: 'NM',
                  currentMarketPrice: 200.0 + i,
                  lastPriceUpdate: DateTime(2024, 1, 1),
                  dynamicData: jsonEncode({'rarity': 'rare', 'index': i}),
                ),
              );
        });
        await Future.wait(insertFutures);

        // Verify DB1 has exactly 100 items, and DB2 has strictly 0 items (zero bleed)
        final db1Items = await db1.select(db1.vaultItems).get();
        final db2Items = await db2.select(db2.vaultItems).get();
        expect(db1Items.length, equals(100));
        expect(db2Items, isEmpty);

        // Clear DB1, verify DB1 is empty of active items and DB2 remains unaffected
        await dao1.clearAllItems();
        final activeDb1 = await (db1.select(db1.vaultItems)..where((t) => t.isDeleted.equals(false))).get();
        expect(activeDb1, isEmpty);
        expect(await db2.select(db2.vaultItems).get(), isEmpty);
      });

      test('1.2. Rapid interleaved concurrent transactions do not cause race conditions or unhandled locks', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());
        final dao = VaultDao(db);
        await db.delete(db.vaultItems).go();

        // Concurrently run 50 writes and 50 queries simultaneously
        final writes = List.generate(50, (i) async {
          await db.into(db.vaultItems).insertOnConflictUpdate(
                VaultItemsCompanion.insert(
                  id: 'interleaved_item_$i',
                  collectionType: 'mtg',
                  name: 'Card $i',
                  setOrSeries: 'M21',
                  imageUrl: '',
                  acquiredPrice: 1.0,
                  acquiredDate: DateTime.now(),
                  condition: 'NM',
                  currentMarketPrice: 2.0,
                  lastPriceUpdate: DateTime.now(),
                  dynamicData: '{}',
                ),
              );
        });

        final queries = List.generate(50, (i) async {
          return dao.searchCatalogCards('Card');
        });

        // Await all simultaneous async operations without throwing
        await Future.wait([...writes, ...queries]);
        final finalItems = await db.select(db.vaultItems).get();
        expect(finalItems.length, equals(50));
      });
    });

    // =========================================================================
    // 2. Boundary Conditions & Extrema Stress
    // =========================================================================
    group('2. Boundary Conditions & Life Total Extrema Stress', () {
      test('2.1. PodPlayerState survives extrema: 0 life, negative life (-999), and huge life (999,999)', () {
        final stateZero = const PodPlayerState(
          id: 'p_zero',
          seatIndex: 0,
          name: 'Dead Player',
          life: 0,
          poison: 0,
          energy: 0,
          experience: 0,
          commanderTax: 0,
          isMonarch: false,
          hasInitiative: false,
          commanderDamageTaken: {},
          floatingMana: {},
          stormCount: 0,
          isEliminated: true,
        );
        expect(stateZero.life, equals(0));
        expect(stateZero.isEliminated, isTrue);

        final stateNegative = stateZero.copyWith(life: -999);
        expect(stateNegative.life, equals(-999));

        final stateHuge = stateZero.copyWith(life: 999999, isEliminated: false);
        expect(stateHuge.life, equals(999999));
        expect(stateHuge.isEliminated, isFalse);
      });

      testWidgets('2.2. PodScaffoldWidget renders with extrema life totals without throwing or crashing', (tester) async {
        final extremaPod = PodState(
          sessionId: 'extrema_session',
          format: 'commander',
          startingLife: 40,
          players: [
            const PodPlayerState(
              id: 'p0',
              seatIndex: 0,
              name: 'Player Max Life',
              life: 999999,
              poison: 99,
              energy: 999,
              experience: 99,
              commanderTax: 20,
              isMonarch: true,
              hasInitiative: true,
              commanderDamageTaken: {},
              floatingMana: {},
              stormCount: 50,
              isEliminated: false,
            ),
            const PodPlayerState(
              id: 'p1',
              seatIndex: 1,
              name: 'Player Negative Life',
              life: -999,
              poison: 10,
              energy: 0,
              experience: 0,
              commanderTax: 0,
              isMonarch: false,
              hasInitiative: false,
              commanderDamageTaken: {'p0': 21},
              floatingMana: {},
              stormCount: 0,
              isEliminated: true,
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: PodScaffoldWidget(
                  podState: extremaPod,
                  onLifeDelta: (_, _) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PodScaffoldWidget), findsOneWidget);
      });
    });

    // =========================================================================
    // 3. Concurrent Screen Transitions & Zero RenderFlex Overflow
    // =========================================================================
    group('3. Screen Transitions & Layout Resilience', () {
      testWidgets('3.1. Rapidly alternating between CommandCenter and VaultScreen throws zero exceptions', (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final testNotifier = ValueNotifier<int>(0);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: ValueListenableBuilder<int>(
                valueListenable: testNotifier,
                builder: (context, index, _) {
                  return Scaffold(
                    body: index == 0
                        ? const MorphingCommandCenter()
                        : const VaultScreen(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Rapidly toggle 10 times
        for (int i = 0; i < 10; i++) {
          testNotifier.value = (i % 2);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('3.2. DecksScreen renders on compact 300x500 viewport without RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(300, 500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: DecksScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DecksScreen), findsOneWidget);
      });
    });
  });
}

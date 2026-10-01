import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

import 'package:countr/core/state/tcg_context_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // TIER 1 — ISOLATED FEATURE TESTS (R2: Cross-Screen TCG Context Sync)
  // ===========================================================================
  group('R2 — Tier 1: Isolated TCG Context Synchronization Tests', () {
    test('R2-T1-1: Maps "Magic: The Gathering" to "mtg" and vice-versa', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter('Magic: The Gathering'),
        equals('mtg'),
      );
      expect(
        TcgContextSync.mapDeckFilterToGameContext('mtg'),
        equals('Magic: The Gathering'),
      );
    });

    test('R2-T1-2: Maps "Pokémon TCG" to "pokemon" and vice-versa', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter('Pokémon TCG'),
        equals('pokemon'),
      );
      expect(
        TcgContextSync.mapDeckFilterToGameContext('pokemon'),
        equals('Pokémon TCG'),
      );
    });

    test('R2-T1-3: Maps "Disney Lorcana" to "lorcana" and vice-versa', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter('Disney Lorcana'),
        equals('lorcana'),
      );
      expect(
        TcgContextSync.mapDeckFilterToGameContext('lorcana'),
        equals('Disney Lorcana'),
      );
    });

    test('R2-T1-4: Maps "All Collections" to "all" and vice-versa', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter('All Collections'),
        equals('all'),
      );
      expect(
        TcgContextSync.mapDeckFilterToGameContext('all'),
        equals('All Collections'),
      );
    });

    test('R2-T1-5: Non-TCG collections (Comic Books, Sports Cards) safely fallback to "all"', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter('Comic Books'),
        equals('all'),
      );
      expect(
        TcgContextSync.mapGameContextToDeckFilter('Sports Cards'),
        equals('all'),
      );
    });
  });

  // ===========================================================================
  // TIER 2 — BOUNDARY & CORNER CASES
  // ===========================================================================
  group('R2 — Tier 2: Boundary & Corner Cases', () {
    test('R2-T2-1: Unrecognized or custom collection strings fallback to "all"', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter('Unknown TCG 2026'),
        equals('all'),
      );
      expect(
        TcgContextSync.mapDeckFilterToGameContext('yugioh_custom'),
        equals('All Collections'),
      );
    });

    test('R2-T2-2: Whitespace and case-insensitive normalization', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter('  pokemon tcg  '),
        equals('pokemon'),
      );
      expect(
        TcgContextSync.mapGameContextToDeckFilter('DISNEY LORCANA'),
        equals('lorcana'),
      );
      expect(
        TcgContextSync.mapDeckFilterToGameContext('  POKEMON  '),
        equals('Pokémon TCG'),
      );
    });

    test('R2-T2-3: Synchronized listener bridge does not enter recursive loop on rapid updates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      TcgContextSync.bindSync(container);

      // Perform rapid updates alternating between providers
      for (int i = 0; i < 20; i++) {
        container.read(activeDeckTcgFilterProvider.notifier).state = 'pokemon';
        expect(container.read(activeGameContextProvider), equals('Pokémon TCG'));

        container.read(activeGameContextProvider.notifier).state = 'Disney Lorcana';
        expect(container.read(activeDeckTcgFilterProvider), equals('lorcana'));

        container.read(activeDeckTcgFilterProvider.notifier).state = 'all';
        expect(container.read(activeGameContextProvider), equals('All Collections'));

        container.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';
        expect(container.read(activeDeckTcgFilterProvider), equals('mtg'));
      }
    });

    test('R2-T2-4: Resetting filter to "all" in Decks updates Vault to "All Collections"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      TcgContextSync.bindSync(container);

      container.read(activeDeckTcgFilterProvider.notifier).state = 'mtg';
      expect(container.read(activeGameContextProvider), equals('Magic: The Gathering'));

      container.read(activeDeckTcgFilterProvider.notifier).state = 'all';
      expect(container.read(activeGameContextProvider), equals('All Collections'));
    });

    test('R2-T2-5: Empty string in game context safely resolves to "all"', () {
      expect(
        TcgContextSync.mapGameContextToDeckFilter(''),
        equals('all'),
      );
    });
  });

  // ===========================================================================
  // TIER 3 — PAIRWISE & CROSS-FEATURE COMBINATIONS
  // ===========================================================================
  group('R2 — Tier 3: Cross-Feature Combinations', () {
    testWidgets('R2-T3-1: DecksScreen reflects TCG filter when game context changes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      TcgContextSync.bindSync(container);

      // Set Vault to MTG
      container.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title should show Magic: The Gathering
      expect(find.text('Magic: The Gathering'), findsOneWidget);
    });

    testWidgets('R2-T3-2: DecksScreen reflects Pokémon filter when context changes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      TcgContextSync.bindSync(container);

      // Set Vault to Pokémon TCG
      container.read(activeGameContextProvider.notifier).state = 'Pokémon TCG';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title should show Pokémon
      expect(find.text('Pokémon'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TIER 4 — REAL-WORLD WORKLOAD SCENARIOS & E2E FLOWS
  // ===========================================================================
  group('R2 — Tier 4: Real-World Workload Scenarios & E2E Flows', () {
    testWidgets('R2-T4-1: Multi-screen navigation preserves active TCG context without reset to default', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      TcgContextSync.bindSync(container);

      // 1. User starts in Vault screen with 'Magic: The Gathering'
      container.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: const VaultScreen(),
                bottomNavigationBar: Row(
                  children: [
                    ElevatedButton(
                      key: const Key('nav_decks_btn'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DecksScreen()),
                        );
                      },
                      child: const Text('Go to Decks'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2. User navigates to Decks screen
      await tester.tap(find.byKey(const Key('nav_decks_btn')));
      await tester.pumpAndSettle();

      // Verify Decks screen inherited MTG context
      expect(find.text('Magic: The Gathering'), findsOneWidget);

      // 3. User switches context in Decks screen to 'Disney Lorcana' via dropdown
      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Disney Lorcana'));
      await tester.pumpAndSettle();

      expect(find.text('Disney Lorcana'), findsOneWidget);
      expect(container.read(activeDeckTcgFilterProvider), equals('lorcana'));
      expect(container.read(activeGameContextProvider), equals('Disney Lorcana'));

      // 4. User navigates back to Vault screen
      Navigator.pop(tester.element(find.byType(DecksScreen)));
      await tester.pumpAndSettle();

      // Verify Vault screen now has Disney Lorcana active
      expect(container.read(activeGameContextProvider), equals('Disney Lorcana'));
    });

    testWidgets('R2-T4-2: Switching to All Collections clears filter constraints symmetrically', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      TcgContextSync.bindSync(container);

      container.read(activeGameContextProvider.notifier).state = 'Pokémon TCG';
      expect(container.read(activeDeckTcgFilterProvider), equals('pokemon'));

      // Change to All Collections
      container.read(activeGameContextProvider.notifier).state = 'All Collections';
      expect(container.read(activeDeckTcgFilterProvider), equals('all'));
    });
  });
}

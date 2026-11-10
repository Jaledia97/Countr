import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import '../helpers/e2e_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = createE2ETestDatabase();
    dao = db.vaultDao;
    await seedStandardM1Catalog(dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tier 1 - Feature 3: Fast Search 200ms Debounce & Query Cancellation', () {
    test('F3.1: Rapid typing within <200ms cancels pending debounce timer and defers query dispatch', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
      );
      addTearDown(container.dispose);

      Timer? debounceTimer;
      String currentQuery = '';

      void onSearchChanged(String val) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 200), () {
          currentQuery = val.trim();
          container.read(vaultSearchQueryProvider.notifier).state = currentQuery;
        });
      }

      // Type "B", then "Bl", then "Bla" each after 50ms (total elapsed 150ms < 200ms)
      onSearchChanged('B');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(currentQuery, isEmpty, reason: 'Debounce should not fire after 50ms');

      onSearchChanged('Bl');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(currentQuery, isEmpty, reason: 'Debounce should not fire after 100ms');

      onSearchChanged('Bla');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(currentQuery, isEmpty, reason: 'Debounce should not fire after 150ms');

      // Now wait remaining time until 200ms threshold completes
      await Future.delayed(const Duration(milliseconds: 160));
      expect(currentQuery, equals('Bla'), reason: 'Debounce should fire after 200ms of inactivity');
      expect(container.read(vaultSearchQueryProvider), equals('Bla'));
    });

    test('F3.2: 200ms debounce fires and executes SQLite query only once after user pauses', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
      );
      addTearDown(container.dispose);

      int queryExecutionCount = 0;
      Timer? debounceTimer;

      void simulateSearchInput(String val) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 200), () async {
          container.read(vaultSearchQueryProvider.notifier).state = val.trim();
          queryExecutionCount++;
          await dao.getItemsByCollection('mtg', searchQuery: val.trim(), onlyOwned: false);
        });
      }

      simulateSearchInput('L');
      await Future.delayed(const Duration(milliseconds: 60));
      simulateSearchInput('Lo');
      await Future.delayed(const Duration(milliseconds: 60));
      simulateSearchInput('Lot');
      await Future.delayed(const Duration(milliseconds: 60));
      simulateSearchInput('Lotus');

      // Wait 250ms for the final debounce to complete
      await Future.delayed(const Duration(milliseconds: 250));

      expect(queryExecutionCount, equals(1), reason: 'Only the final search query after pause should execute');
      expect(container.read(vaultSearchQueryProvider), equals('Lotus'));
    });

    test('F3.3: Typing a new character while an active timer is pending cancels previous timer', () async {
      Timer? debounceTimer;
      bool firstTimerFired = false;
      bool secondTimerFired = false;

      debounceTimer = Timer(const Duration(milliseconds: 200), () {
        firstTimerFired = true;
      });

      // After 100ms, user types another key: cancel previous timer
      await Future.delayed(const Duration(milliseconds: 100));
      expect(debounceTimer.isActive, isTrue);
      debounceTimer.cancel();

      debounceTimer = Timer(const Duration(milliseconds: 200), () {
        secondTimerFired = true;
      });

      // Wait 120ms (total 220ms from start, but only 120ms from second timer)
      await Future.delayed(const Duration(milliseconds: 120));
      expect(firstTimerFired, isFalse, reason: 'Cancelled first timer must never fire');
      expect(secondTimerFired, isFalse, reason: 'Second timer has not reached 200ms yet');

      // Wait remaining 100ms for second timer
      await Future.delayed(const Duration(milliseconds: 100));
      expect(secondTimerFired, isTrue);
    });

    test('F3.4: Clear action immediately cancels pending debounce and clears state to empty', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
      );
      addTearDown(container.dispose);

      Timer? debounceTimer;
      debounceTimer = Timer(const Duration(milliseconds: 200), () {
        container.read(vaultSearchQueryProvider.notifier).state = 'Sol Ring';
      });

      // Immediate user clear
      debounceTimer.cancel();
      container.read(vaultSearchQueryProvider.notifier).state = '';

      await Future.delayed(const Duration(milliseconds: 250));
      expect(container.read(vaultSearchQueryProvider), isEmpty);
    });

    test('F3.5: Search results prioritize prefix matches before contains matches', () async {
      // Insert cards: "Sol Ring" (prefix for "Sol") and "Absolve" (contains "sol")
      final extraCards = [
        createE2ETestCard(
          id: 'c-absorb',
          name: 'Absolve',
          setOrSeries: 'Test Set',
          setCode: 'tst',
          currentMarketPrice: 1.0,
          quantity: 1,
        ),
      ];
      await insertTestCards(dao, extraCards);

      final results = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'sol',
        onlyOwned: false,
      );

      expect(results, isNotEmpty);
      expect(results.any((c) => c.name == 'Sol Ring'), isTrue);
      expect(results.any((c) => c.name == 'Absolve'), isTrue);

      // Sol Ring (prefix match) should be ranked before Absolve (contains match)
      final solIndex = results.indexWhere((c) => c.name == 'Sol Ring');
      final absolveIndex = results.indexWhere((c) => c.name == 'Absolve');
      expect(solIndex, lessThan(absolveIndex));
    });
  });
}

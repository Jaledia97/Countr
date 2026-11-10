import 'dart:convert';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/card_reputation_dao.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CardReputationDao reputationDao;
  late VaultDao vaultDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    reputationDao = db.cardReputationDao;
    vaultDao = db.vaultDao;
    await vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTestCard({
    required String id,
    required String name,
    int? score,
    int? upvotes,
    int? downvotes,
    String dynamicData = '{}',
    double price = 10.0,
  }) async {
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'TEST',
        imageUrl: 'https://cards.example.com/$id.png',
        acquiredPrice: 5.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: const Value(1),
        condition: 'NM',
        currentMarketPrice: price,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: dynamicData,
        reputationScore: Value(score),
        upvotes: Value(upvotes),
        downvotes: Value(downvotes),
      ),
    );
  }

  group('Adversarial Test: Atomic Voting Engine Invariants', () {
    test('MAX(0, ...) protects downvotes and upvotes from negative counter corruption', () async {
      // Seed a card where upvotes/downvotes are initially 0 but corrupted initialScore is -5
      await insertTestCard(
        id: 'corrupt_card',
        name: 'Corrupted Card',
        score: -5,
        upvotes: 0,
        downvotes: 0,
      );

      // Downvoting should increment downvotes to 1, score to -6
      final res1 = await reputationDao.castVote(
        cardId: 'corrupt_card',
        targetVote: -1,
      );
      expect(res1.downvotes, equals(1));
      expect(res1.upvotes, equals(0));
      expect(res1.newScore, equals(-6));

      // Toggle off downvote -> deltaDown -1, deltaScore +1
      final res2 = await reputationDao.castVote(
        cardId: 'corrupt_card',
        targetVote: -1,
      );
      expect(res2.downvotes, equals(0));
      expect(res2.newScore, equals(-5));
    });

    test('Parallel concurrent votes from multiple distinct users preserve consistency', () async {
      await insertTestCard(id: 'hot_card', name: 'Hot Card', score: 0);

      // Simulate 10 users casting votes concurrently
      final futures = <Future<CardVoteResult>>[];
      for (int i = 0; i < 10; i++) {
        final userId = 'user_$i';
        // 7 upvotes, 3 downvotes
        final targetVote = i < 7 ? 1 : -1;
        futures.add(
          reputationDao.castVote(
            cardId: 'hot_card',
            userId: userId,
            targetVote: targetVote,
          ),
        );
      }

      await Future.wait(futures);

      final summary = await reputationDao.getReputationScore('hot_card');
      // 7 upvotes - 3 downvotes = net score 4
      expect(summary.score, equals(4));
      expect(summary.upvotes, equals(7));
      expect(summary.downvotes, equals(3));
    });

    test('Voting on card not yet in vault_items succeeds gracefully without crashing', () async {
      final res = await reputationDao.castVote(
        cardId: 'unimported_card_999',
        targetVote: 1,
      );
      expect(res.newVote, equals(1));
      expect(res.newScore, equals(1));

      // watchReputationScore also returns valid non-null summary for non-existent vault_item
      final summary = await reputationDao.getReputationScore('unimported_card_999');
      expect(summary.score, equals(0)); // not in vault_items, vi.reputation_score is null -> 0
      expect(summary.userVote, equals(1));
    });

    test('Complete cycle of transitions: neutral -> up -> down -> neutral -> down -> up', () async {
      await insertTestCard(id: 'cycle_card', name: 'Cycle Card');

      // 1. Upvote
      var r = await reputationDao.castVote(cardId: 'cycle_card', targetVote: 1);
      expect(r.newVote, equals(1));
      expect(r.newScore, equals(1));
      expect(r.upvotes, equals(1));
      expect(r.downvotes, equals(0));

      // 2. Direct switch to Downvote
      r = await reputationDao.castVote(cardId: 'cycle_card', targetVote: -1);
      expect(r.newVote, equals(-1));
      expect(r.newScore, equals(-1));
      expect(r.upvotes, equals(0));
      expect(r.downvotes, equals(1));

      // 3. Toggle off downvote
      r = await reputationDao.castVote(cardId: 'cycle_card', targetVote: -1);
      expect(r.newVote, equals(0));
      expect(r.newScore, equals(0));
      expect(r.upvotes, equals(0));
      expect(r.downvotes, equals(0));

      // 4. Downvote
      r = await reputationDao.castVote(cardId: 'cycle_card', targetVote: -1);
      expect(r.newVote, equals(-1));
      expect(r.newScore, equals(-1));

      // 5. Direct switch to Upvote
      r = await reputationDao.castVote(cardId: 'cycle_card', targetVote: 1);
      expect(r.newVote, equals(1));
      expect(r.newScore, equals(1));
      expect(r.upvotes, equals(1));
      expect(r.downvotes, equals(0));
    });
  });

  group('Adversarial Test: Sort Stability and Corrupt Metadata Handling', () {
    test('sortVaultItemsInMemory handles null scores, malformed JSON, and missing CMC/dates', () {
      final items = [
        VaultItem(
          id: 'i1',
          collectionType: 'mtg',
          name: 'Bravo Card',
          setOrSeries: 'S1',
          imageUrl: '',
          acquiredPrice: 10,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 50,
          lastPriceUpdate: DateTime.now(),
          dynamicData: 'MALFORMED_JSON_STRING',
          reputationScore: null,
        ),
        VaultItem(
          id: 'i2',
          collectionType: 'mtg',
          name: 'Alpha Card',
          setOrSeries: 'S1',
          imageUrl: '',
          acquiredPrice: 10,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 20,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{"reputation_score": 15, "cmc": 4.0, "released_at": "2024-01-01"}',
          reputationScore: 15,
        ),
        VaultItem(
          id: 'i3',
          collectionType: 'mtg',
          name: 'Charlie Card',
          setOrSeries: 'S1',
          imageUrl: '',
          acquiredPrice: 10,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 100,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{"reputation_score": -10, "cmc": 1.0, "released_at": "2020-05-15"}',
          reputationScore: -10,
        ),
      ];

      // Sort by reputationHighest: i2 (15) > i1 (0 fallback) > i3 (-10)
      final sortedRepHigh = sortVaultItemsInMemory(items, VaultSortOption.reputationHighest);
      expect(sortedRepHigh.map((e) => e.id).toList(), equals(['i2', 'i1', 'i3']));

      // Sort by reputationLowest: i3 (-10) < i1 (0 fallback) < i2 (15)
      final sortedRepLow = sortVaultItemsInMemory(items, VaultSortOption.reputationLowest);
      expect(sortedRepLow.map((e) => e.id).toList(), equals(['i3', 'i1', 'i2']));

      // Sort by manaValueCmc: i1 (0.0 fallback) < i3 (1.0) < i2 (4.0)
      final sortedCmc = sortVaultItemsInMemory(items, VaultSortOption.manaValueCmc);
      expect(sortedCmc.map((e) => e.id).toList(), equals(['i1', 'i3', 'i2']));

      // Sort by releaseDate: i2 (2024) > i3 (2020) > i1 ('')
      final sortedDate = sortVaultItemsInMemory(items, VaultSortOption.releaseDate);
      expect(sortedDate.map((e) => e.id).toList(), equals(['i2', 'i3', 'i1']));
    });

    test('SQLite VaultDao handles ties in reputation score with alphabetical tiebreaker', () async {
      await insertTestCard(id: 'c_zebra', name: 'Zebra', score: 5);
      await insertTestCard(id: 'c_apple', name: 'Apple', score: 5);
      await insertTestCard(id: 'c_mango', name: 'Mango', score: 5);

      final list = await vaultDao.getItemsByCollection(
        'mtg',
        sortOption: VaultSortOption.reputationHighest,
      );

      // All have score 5, so secondary order must be name A-Z: Apple, Mango, Zebra
      expect(list.map((c) => c.name).toList(), equals(['Apple', 'Mango', 'Zebra']));
    });
  });

  group('Adversarial Test: Viewport & Layout Robustness (320px & High Scaling)', () {
    testWidgets('320px viewport with extreme 5-digit reputation score renders with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      await insertTestCard(
        id: 'extreme_card',
        name: 'Omniscience, Ultimate High Score Edition',
        score: 99999,
        dynamicData: jsonEncode({
          'reputation_score': 99999,
          'oracle_text': 'You may cast spells from your hand without paying their mana costs.',
        }),
      );

      final card = (await (db.select(db.vaultItems)..where((t) => t.id.equals('extreme_card'))).getSingle());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: CardDetailSheet(item: card),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));
      expect(scoreFinder, findsOneWidget);
      expect(tester.widget<Text>(scoreFinder).data, equals('99999'));
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('320px viewport in All Cards mode with Search expanded renders with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => true), // All Cards mode
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
              ),
              child: const VaultScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify buttons exist in AppBar
      expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_mtg_filter_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_import_button')), findsOneWidget);

      // Expand search
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}

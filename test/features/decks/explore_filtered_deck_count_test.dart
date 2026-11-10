import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('ExploreDeckDao Filtered Deck Count Tests (Milestone 2 - R4)', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
    });

    tearDown(() async {
      await db.close();
    });

    test('Returns accurate count for initial seeded dataset (19 total: 12 official, 7 community)', () async {
      final totalCount = await exploreDao.getFilteredExploreDeckCount();
      expect(totalCount, equals(19));

      final officialCount = await exploreDao.getFilteredExploreDeckCount(
        category: ExploreCategory.official,
      );
      expect(officialCount, equals(12));

      final communityCount = await exploreDao.getFilteredExploreDeckCount(
        category: ExploreCategory.community,
      );
      expect(communityCount, equals(7));
    });

    test('Filters by format accurately without pagination limit', () async {
      final commanderCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Commander'),
      );
      expect(commanderCount, greaterThan(0));
      expect(commanderCount, lessThanOrEqualTo(19));

      final standardCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Standard'),
      );
      expect(standardCount, greaterThanOrEqualTo(0));
      expect(commanderCount + standardCount, lessThanOrEqualTo(19));
    });

    test('Filters by color identity accurately with colorMatchMode', () async {
      final blueCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(colors: ['U'], colorMatchMode: 'including'),
      );
      expect(blueCount, greaterThan(0));

      final colorlessCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(colors: ['C'], colorMatchMode: 'including'),
      );
      expect(colorlessCount, greaterThanOrEqualTo(0));
    });

    test('Filters by price range accurately', () async {
      final budgetCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(priceRange: 'budget_0_50'),
      );
      final midCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(priceRange: 'mid_50_200'),
      );
      final highCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(priceRange: 'high_200_plus'),
      );

      expect(budgetCount + midCount + highCount, equals(19));
    });

    test('Filters by search query matching deck name or creator name', () async {
      final officialWotcCount = await exploreDao.getFilteredExploreDeckCount(
        searchQuery: 'Wizards of the Coast',
      );
      expect(officialWotcCount, equals(12));

      final spicyCount = await exploreDao.getFilteredExploreDeckCount(
        searchQuery: 'SpicyBrewMaster',
      );
      expect(spicyCount, greaterThanOrEqualTo(1));
    });

    test('watchFilteredExploreDeckCount emits reactively when decks are inserted or soft-deleted', () async {
      final countStream = exploreDao.watchFilteredExploreDeckCount(
        category: ExploreCategory.community,
      );

      expectLater(
        countStream,
        emitsInOrder([
          7, // Initial community decks
          8, // After inserting new community deck
          7, // After soft-deleting deck
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      final newDeckId = 'reactive_test_deck_1';
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: newDeckId,
          name: 'Reactive Test Deck',
          format: 'Commander',
          sourceType: const Value('community'),
          createdAt: DateTime.now(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await (db.update(db.exploreDecks)..where((t) => t.id.equals(newDeckId)))
          .write(const ExploreDecksCompanion(isDeleted: Value(true)));
    });
  });

  group('ExploreDecksTabView UI Dynamic Counter Invariants (R4)', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Header displays true database deck count badge (Key: explore_decks_count_badge)', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreDecksTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header count badge should display '19 decks'
      expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
      expect(find.text('19 decks'), findsOneWidget);

      // Tap 'Official (WotC)' category pill
      await tester.tap(find.byKey(const Key('explore_pill_official')));
      await tester.pumpAndSettle();

      // Header count badge should update reactively to '12 decks'
      expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
      expect(find.text('12 decks'), findsOneWidget);

      // Tap 'Community' category pill
      await tester.tap(find.byKey(const Key('explore_pill_community')));
      await tester.pumpAndSettle();

      // Header count badge should update reactively to '7 decks'
      expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
      expect(find.text('7 decks'), findsOneWidget);
    });
  });
}

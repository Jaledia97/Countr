import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_sync_service.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 3 - F9: Explore Decks "My Uploads" Filter Pill & DAO Pushdown', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);

      final now = DateTime.now();

      // Seed deck by user 'alice_123'
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_alice',
          name: 'Alice Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          authorId: const Value('alice_123'),
          creatorName: const Value('Alice'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // Seed deck by user 'bob_456'
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_bob',
          name: 'Bob Deck',
          format: 'Modern',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          authorId: const Value('bob_456'),
          creatorName: const Value('Bob'),
          cardCount: const Value(60),
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // Seed deck with authorId = 'local_user'
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_local',
          name: 'Local User Deck',
          format: 'Standard',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          authorId: const Value('local_user'),
          creatorName: const Value('Local Hero'),
          cardCount: const Value(60),
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('DAO filters correctly when category is ExploreCategory.myUploads', () async {
      // 1. For alice_123, should only return deck_alice
      final aliceCount = await exploreDao.getFilteredExploreDeckCount(
        category: ExploreCategory.myUploads,
        currentUserId: 'alice_123',
      );
      expect(aliceCount, equals(1));

      final aliceDecks = await exploreDao.watchExploreDecks(
        category: ExploreCategory.myUploads,
        userId: 'alice_123',
      ).first;
      expect(aliceDecks.length, equals(1));
      expect(aliceDecks.first.deck.id, equals('deck_alice'));

      // 2. For bob_456, should only return deck_bob
      final bobCount = await exploreDao.getFilteredExploreDeckCount(
        category: ExploreCategory.myUploads,
        currentUserId: 'bob_456',
      );
      expect(bobCount, equals(1));

      final bobDecks = await exploreDao.watchExploreDecks(
        category: ExploreCategory.myUploads,
        userId: 'bob_456',
      ).first;
      expect(bobDecks.length, equals(1));
      expect(bobDecks.first.deck.id, equals('deck_bob'));

      // 3. For local user aliases ('local_user' or 'user-current-me'), should match 'local_user'
      final localCount = await exploreDao.getFilteredExploreDeckCount(
        category: ExploreCategory.myUploads,
        currentUserId: 'user-current-me',
      );
      expect(localCount, equals(1));

      final localDecks = await exploreDao.watchExploreDecks(
        category: ExploreCategory.myUploads,
        userId: 'user-current-me',
      ).first;
      expect(localDecks.length, equals(1));
      expect(localDecks.first.deck.id, equals('deck_local'));

      // 4. When currentUserId is an unmatched user, returns 0 for myUploads
      final emptyCount = await exploreDao.getFilteredExploreDeckCount(
        category: ExploreCategory.myUploads,
        currentUserId: 'unmatched_user',
      );
      expect(emptyCount, equals(0));
    });

    testWidgets('UI renders "My Uploads" pill with Key("explore_pill_my_uploads") and filters feed',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(VaultDao(db)),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
            decksTopTabProvider.overrideWith((ref) => 1),
            currentUserIdProvider.overrideWith((ref) => 'alice_123'),
          ],
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify My Uploads pill exists
      final myUploadsPillFinder = find.byKey(const Key('explore_pill_my_uploads'));
      expect(myUploadsPillFinder, findsOneWidget);

      // Tap "My Uploads"
      await tester.tap(myUploadsPillFinder);
      await tester.pumpAndSettle();

      // Alice's deck should be present
      expect(find.text('Alice Deck'), findsWidgets);
      // Bob's deck should not be present
      expect(find.text('Bob Deck'), findsNothing);
    });
  });

  group('Milestone 3 - F10: "All Explore Decks" Uncropped Grid Sizing (0.54 ratio & 63/88 aspect)', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);

      final now = DateTime.now();
      for (int i = 1; i <= 4; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'grid_deck_$i',
            name: 'Grid Deck $i',
            format: 'Commander',
            tcgDomain: const Value('mtg'),
            sourceType: const Value('community'),
            commanderImageUrl: const Value('https://cards.scryfall.io/normal/front/1/2/test.jpg'),
            commanderName: const Value('Atraxa, Praetors\' Voice'),
            cardCount: const Value(100),
            estimatedPrice: const Value(250.0),
            score: const Value(50),
            createdAt: now,
            updatedAt: Value(now),
            isDeleted: const Value(false),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Explore feed grid uses childAspectRatio: 0.54', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(VaultDao(db)),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
            decksTopTabProvider.overrideWith((ref) => 1),
          ],
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridFinders = find.byType(SliverGrid);
      expect(gridFinders, findsWidgets);

      final sliverGridWidget = tester.widget<SliverGrid>(gridFinders.first);
      final delegate = sliverGridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(2));
      expect(delegate.childAspectRatio, equals(0.54));
    });

    testWidgets('ExploreDeckCard renders CountrCachedImage with BoxFit.contain and 63/88 AspectRatio',
        (tester) async {
      final sampleDeck = ExploreDeckWithVote(
        deck: ExploreDeck(
          id: 'sample_deck_ratio',
          name: 'Uncropped Ratio Commander Deck',
          format: 'Commander',
          tcgDomain: 'mtg',
          sourceType: 'community',
          creatorName: 'DeckTester',
          commanderImageUrl: 'https://cards.scryfall.io/normal/front/1/2/test.jpg',
          commanderName: 'Sol Ring Commander',
          cardCount: 100,
          colorIdentity: '["C"]',
          estimatedPrice: 199.99,
          score: 42,
          upvotes: 45,
          downvotes: 3,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isDeleted: false,
        ),
        userVote: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: ExploreDeckCard(deckWithVote: sampleDeck),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AspectRatio widget with 63 / 88 ratio exists
      final aspectRatioFinders = find.byType(AspectRatio);
      expect(aspectRatioFinders, findsWidgets);
      final hasCardRatio = aspectRatioFinders.evaluate().any((elem) {
        final widget = elem.widget as AspectRatio;
        return (widget.aspectRatio - (63.0 / 88.0)).abs() < 0.001;
      });
      expect(hasCardRatio, isTrue);

      // Verify CountrCachedImage has fit: BoxFit.contain
      final imageFinders = find.byType(CountrCachedImage);
      expect(imageFinders, findsOneWidget);
      final cachedImage = tester.widget<CountrCachedImage>(imageFinders);
      expect(cachedImage.fit, equals(BoxFit.contain));

      // Verify metadata block details are rendered below image
      expect(find.text('Uncropped Ratio Commander Deck'), findsOneWidget);
      expect(find.text('@DeckTester'), findsOneWidget);
      expect(find.text(r'$199.99'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });
  });

  group('Milestone 3 - F11: Live MTGJSON Precon Ingestion & Auto-Sync Service', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('isTargetPrecon accurately filters WotC and Secret Lair precons', () {
      // Commander Decks
      expect(
        MtgjsonPreconSyncService.isTargetPrecon({
          'name': 'Arm for Battle',
          'type': 'Commander Deck',
          'fileName': 'CommanderLegends_CMR',
        }),
        isTrue,
      );

      // Secret Lair Drops
      expect(
        MtgjsonPreconSyncService.isTargetPrecon({
          'name': 'Secret Lair Drop Series: Heads I Win, Tails You Lose',
          'type': 'Secret Lair Drop',
          'fileName': 'SecretLairDrop_SLD',
        }),
        isTrue,
      );

      // Deck with type or name matching precon patterns
      expect(
        MtgjsonPreconSyncService.isTargetPrecon({
          'name': 'Starter Commander Decks 2022',
          'type': 'Boxed Set',
          'fileName': 'SCD_2022',
        }),
        isTrue,
      );

      // Non-target deck types (e.g. booster pack or cube)
      expect(
        MtgjsonPreconSyncService.isTargetPrecon({
          'name': 'Modern Horizons 3 Draft Booster Box',
          'type': 'Booster Pack',
          'fileName': 'Booster_MH3',
        }),
        isFalse,
      );

      // Empty or missing fileName
      expect(
        MtgjsonPreconSyncService.isTargetPrecon({
          'name': 'Missing File',
          'type': 'Commander Deck',
        }),
        isFalse,
      );
    });

    test('checkAndSyncNewlyReleasedPrecons performs delta ingestion and avoids duplicates', () async {
      final mockDeckListJson = jsonEncode({
        'data': [
          {
            'name': 'Veloci-ramp-tor Precon',
            'type': 'Commander Deck',
            'code': 'LCC',
            'fileName': 'Velociramptor_LCC',
          },
          {
            'name': 'Some Duel Deck',
            'type': 'Duel Deck',
            'code': 'DD1',
            'fileName': 'DuelDeck_DD1',
          },
        ],
      });

      final mockPreconDeckJson = jsonEncode({
        'data': {
          'name': 'Veloci-ramp-tor',
          'code': 'LCC',
          'type': 'Commander Deck',
          'commander': [
            {
              'name': 'Pantlaza, Sun-Favored',
              'count': 1,
              'scryfallId': 'test-pantlaza-id',
            }
          ],
          'cards': [
            {
              'name': 'Ghalta, Primal Hunger',
              'count': 1,
              'types': ['Creature'],
              'scryfallId': 'test-ghalta-id',
            },
            {
              'name': 'Forest',
              'count': 30,
              'types': ['Land'],
            }
          ],
        },
      });

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://mtgjson.com/api/v5/DeckList.json') {
          return http.Response(mockDeckListJson, 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.toString() == 'https://mtgjson.com/api/v5/decks/Velociramptor_LCC.json') {
          return http.Response(mockPreconDeckJson, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      // 1. Initial sync: should detect 1 new precon and ingest it
      final syncedFirstRun = await MtgjsonPreconSyncService.checkAndSyncNewlyReleasedPrecons(
        db,
        httpClient: mockClient,
      );
      expect(syncedFirstRun, equals(1));

      // Verify the deck is in SQLite
      final decks = await db.select(db.exploreDecks).get();
      expect(decks.length, equals(1));
      expect(decks.first.name, equals('Veloci-ramp-tor'));
      expect(decks.first.commanderName, equals('Pantlaza, Sun-Favored'));
      expect(decks.first.sourceType, equals('official'));
      expect(decks.first.tags, contains('fn:Velociramptor_LCC'));

      // 2. Second sync with same mock data: delta comparison sees fn:Velociramptor_LCC exists
      final syncedSecondRun = await MtgjsonPreconSyncService.checkAndSyncNewlyReleasedPrecons(
        db,
        httpClient: mockClient,
      );
      expect(syncedSecondRun, equals(0));

      // SQLite decks count remains 1
      final decksAfter = await db.select(db.exploreDecks).get();
      expect(decksAfter.length, equals(1));
    });
  });
}

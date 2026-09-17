import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Test 1: Network Failure Modes in fetchCardRulings', () {
    test('HTTP 500 Internal Server Error returns null without throwing', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      final service = ScryfallService(client: mockClient);
      final rulings = await service.fetchCardRulings('fail-500');
      expect(rulings, isNull);
    });

    test('Socket Timeout / TimeoutException returns null without throwing', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Scryfall request timed out after 10000ms');
      });
      final service = ScryfallService(client: mockClient);
      final rulings = await service.fetchCardRulings('timeout-id');
      expect(rulings, isNull);
    });

    test('Malformed JSON: HTML error page (502 Bad Gateway) handled gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>502 Bad Gateway</body></html>', 200);
      });
      final service = ScryfallService(client: mockClient);
      final rulings = await service.fetchCardRulings('bad-gateway');
      expect(rulings, isEmpty);
    });

    test('Malformed JSON: Non-map root or invalid data structure handled gracefully', () async {
      final responses = [
        'null',
        '12345',
        '"just a string"',
        '[]',
        '{"data": null}',
        '{"data": "not a list"}',
        '{"data": [null, 123, "invalid"]}',
      ];

      for (final body in responses) {
        final mockClient = MockClient((request) async => http.Response(body, 200));
        final service = ScryfallService(client: mockClient);
        final rulings = await service.fetchCardRulings('malformed-id');
        expect(rulings, isEmpty, reason: 'Failed for body: $body');
      }
    });

    test('Offline status / SocketException returns null without throwing', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Network is unreachable / offline');
      });
      final service = ScryfallService(client: mockClient);
      final rulings = await service.fetchCardRulings('offline-id');
      expect(rulings, isNull);
    });
  });

  group('Adversarial Test 1b: Network Failure Caching Dynamics in CardDetailSheet', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('proves transient network failure does not poison cache and retries when online', (tester) async {
      var networkShouldFail = true;
      var networkCalls = 0;

      final mockClient = MockClient((request) async {
        networkCalls++;
        if (networkShouldFail) {
          throw const SocketException('Device is offline');
        }
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [
              {
                'object': 'ruling',
                'oracle_id': 'oracle-retry',
                'published_at': '2023-01-01',
                'comment': 'Recovered ruling from Scryfall',
              }
            ]
          }),
          200,
        );
      });
      final service = ScryfallService(client: mockClient);

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'offline-recovery-card',
              collectionType: 'mtg',
              name: 'Resilient Mage',
              setOrSeries: 'M21',
              imageUrl: 'https://cards.scryfall.io/front/mage.jpg',
              acquiredPrice: 1.0,
              acquiredDate: DateTime(2021, 1, 1),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime(2021, 1, 1),
              dynamicData: '{}',
            ),
          );

      final initialCard = await db.vaultDao.getItemById('offline-recovery-card');

      // First open: network fails
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: initialCard!))),
        ),
      );
      await tester.pumpAndSettle();

      expect(networkCalls, 1);

      // Verify that SQLite database does NOT contain 'cached_rulings'
      final cardAfterFail = await db.vaultDao.getItemById('offline-recovery-card');
      expect(cardAfterFail, isNotNull);
      final dynamicDataAfterFail = jsonDecode(cardAfterFail!.dynamicData) as Map<String, dynamic>;
      expect(dynamicDataAfterFail.containsKey('cached_rulings'), isFalse);

      // Network is now back online
      networkShouldFail = false;

      // Re-open card sheet
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: cardAfterFail))),
        ),
      );
      await tester.pumpAndSettle();

      // Because 'cached_rulings' was NOT persisted on failure, it successfully retried when online!
      expect(networkCalls, 2);
      expect(find.text('Recovered ruling from Scryfall'), findsOneWidget);

      final cardAfterSuccess = await db.vaultDao.getItemById('offline-recovery-card');
      expect(cardAfterSuccess, isNotNull);
      final dynamicDataAfterSuccess = jsonDecode(cardAfterSuccess!.dynamicData) as Map<String, dynamic>;
      expect(dynamicDataAfterSuccess.containsKey('cached_rulings'), isTrue);
      expect(dynamicDataAfterSuccess['cached_rulings'], isNotEmpty);
    });
  });

  group('Adversarial Test 2: Non-MTG Card Isolation', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Pokemon cards never query Scryfall rulings', (tester) async {
      var networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });
      final service = ScryfallService(client: mockClient);

      final pokemonCard = VaultItem(
        id: 'pkmn-charizard',
        collectionType: 'pokemon',
        name: 'Charizard ex',
        setOrSeries: '151',
        imageUrl: 'https://images.pokemontcg.io/sv3pt5/199_hires.png',
        acquiredPrice: 120.0,
        acquiredDate: DateTime(2023, 9, 22),
        quantity: 1,
        condition: 'NM',
        isGraded: true,
        currentMarketPrice: 140.0,
        lastPriceUpdate: DateTime(2023, 9, 22),
        dynamicData: '{"hp":"330","stage":"Stage 2","types":["Fire"]}',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: pokemonCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(networkCalled, isFalse);
    });

    testWidgets('Lorcana cards never query Scryfall rulings', (tester) async {
      var networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });
      final service = ScryfallService(client: mockClient);

      final lorcanaCard = VaultItem(
        id: 'lorcana-elsa',
        collectionType: 'lorcana',
        name: 'Elsa - Spirit of Winter',
        setOrSeries: 'The First Chapter',
        imageUrl: 'https://lorcana.cards/elsa.jpg',
        acquiredPrice: 45.0,
        acquiredDate: DateTime(2023, 8, 18),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 50.0,
        lastPriceUpdate: DateTime(2023, 8, 18),
        dynamicData: '{"lore":3,"inkwell":true}',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: lorcanaCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(networkCalled, isFalse);
    });

    testWidgets('Sports cards never query Scryfall rulings', (tester) async {
      var networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });
      final service = ScryfallService(client: mockClient);

      final sportsCard = VaultItem(
        id: 'sports-jordan-1986',
        collectionType: 'sports',
        name: 'Michael Jordan Rookie #57',
        setOrSeries: '1986 Fleer',
        imageUrl: 'https://sportscards.com/jordan.jpg',
        acquiredPrice: 3000.0,
        acquiredDate: DateTime(2020, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: true,
        currentMarketPrice: 4500.0,
        lastPriceUpdate: DateTime(2020, 1, 1),
        dynamicData: '{"sport":"Basketball","team":"Chicago Bulls"}',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: sportsCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(networkCalled, isFalse);
    });

    testWidgets('proves non-MTG card with text resembling MTG keywords omits MTG mechanics', (tester) async {
      final pokemonWithKeywords = VaultItem(
        id: 'pkmn-flying-charizard',
        collectionType: 'pokemon',
        name: 'Charizard',
        setOrSeries: 'Base Set',
        imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
        acquiredPrice: 200.0,
        acquiredDate: DateTime(2020, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 250.0,
        lastPriceUpdate: DateTime(2020, 1, 1),
        dynamicData: jsonEncode({
          'keywords': ['Flying'],
          'oracle_text': 'Flying: Charizard flies around the sky in search of powerful enemies.',
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: pokemonWithKeywords))),
        ),
      );
      await tester.pumpAndSettle();

      // Non-MTG card must NOT display MTG mechanics or rulings
      expect(find.text('Card Mechanics & Rulings'), findsNothing);
      expect(find.text('This creature can only be blocked by other creatures with flying or reach.'), findsNothing);
    });
  });

  group('Adversarial Test 3: Screen Reader Accessibility', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('card_detail_flip_button exposes semantic label and button flag', (tester) async {
      final dfc = VaultItem(
        id: 'dfc-test-a11y',
        collectionType: 'mtg',
        name: 'Delver of Secrets // Insectile Aberration',
        setOrSeries: 'Innistrad',
        imageUrl: 'https://cards.scryfall.io/front/delver.jpg',
        acquiredPrice: 5.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 8.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'card_faces': [
            {'name': 'Delver of Secrets', 'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'}},
            {'name': 'Insectile Aberration', 'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'}},
          ],
        }),
      );

      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CardDetailSheet(item: dfc),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final flipBtnFinder = find.byKey(const Key('card_detail_flip_button'));
        expect(flipBtnFinder, findsOneWidget);

        final semantics = tester.getSemantics(flipBtnFinder);
        expect(semantics.label, 'Flip card');
        expect(semantics.hint, 'Toggles between front and back face');
        expect(semantics.flagsCollection.isButton, isTrue);

        final size = tester.getSize(flipBtnFinder);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('fullscreen_flip_button exposes semantic label and button flag', (tester) async {
      final dfc = VaultItem(
        id: 'dfc-test-fullscreen-a11y',
        collectionType: 'mtg',
        name: 'Nicol Bolas, the Ravager',
        setOrSeries: 'M19',
        imageUrl: 'https://cards.scryfall.io/front/bolas.jpg',
        acquiredPrice: 35.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 40.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'card_faces': [
            {'name': 'Nicol Bolas', 'image_uris': {'normal': 'https://cards.scryfall.io/front/bolas.jpg'}},
            {'name': 'Nicol Bolas, the Arisen', 'image_uris': {'normal': 'https://cards.scryfall.io/back/arisen.jpg'}},
          ],
        }),
      );

      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfc)));
        await tester.pumpAndSettle();

        final flipBtnFinder = find.byKey(const Key('fullscreen_flip_button'));
        expect(flipBtnFinder, findsOneWidget);

        final semantics = tester.getSemantics(flipBtnFinder);
        expect(semantics.label, 'Flip card');
        expect(semantics.hint, 'Toggles between front and back face');
        expect(semantics.flagsCollection.isButton, isTrue);

        final size = tester.getSize(flipBtnFinder);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('rulings list items expose readable semantic text for assistive technologies', (tester) async {
      final cardWithRulings = VaultItem(
        id: 'ruling-a11y-card',
        collectionType: 'mtg',
        name: 'The One Ring',
        setOrSeries: 'LTR',
        imageUrl: 'https://cards.scryfall.io/large/front/ring.jpg',
        acquiredPrice: 50.0,
        acquiredDate: DateTime(2023, 6, 23),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 75.0,
        lastPriceUpdate: DateTime(2023, 6, 23),
        dynamicData: jsonEncode({
          'cached_rulings': [
            {
              'oracle_id': 'ring-oracle',
              'published_at': '2023-06-23',
              'comment': 'Protection from everything means that the player cannot be damaged or targeted.',
            },
            {
              'oracle_id': 'ring-oracle',
              'published_at': '2023-09-01',
              'comment': 'Burden counters remain on The One Ring as long as it is on the battlefield.',
            }
          ],
        }),
      );

      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CardDetailSheet(item: cardWithRulings),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check text semantics for ruling date and comment
        final dateFinder = find.text('2023-06-23');
        expect(dateFinder, findsOneWidget);
        final dateSemantics = tester.getSemantics(dateFinder);
        expect(dateSemantics.label, contains('2023-06-23'));

        final commentFinder = find.text('Protection from everything means that the player cannot be damaged or targeted.');
        expect(commentFinder, findsOneWidget);
        final commentSemantics = tester.getSemantics(commentFinder);
        expect(commentSemantics.label, contains('Protection from everything'));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('card_detail_flip_button passes labeledTapTargetGuideline', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final dfc = VaultItem(
          id: 'dfc-guideline-test',
          collectionType: 'mtg',
          name: 'Delver of Secrets',
          setOrSeries: 'ISD',
          imageUrl: 'https://cards.scryfall.io/front/delver.jpg',
          acquiredPrice: 5.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          currentMarketPrice: 8.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'card_faces': [
              {'name': 'Delver of Secrets', 'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'}},
              {'name': 'Insectile Aberration', 'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'}},
            ],
          }),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CardDetailSheet(item: dfc),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final evaluation = await labeledTapTargetGuideline.evaluate(tester);
        expect(evaluation.passed, isTrue);
      } finally {
        handle.dispose();
      }
    });
  });
}

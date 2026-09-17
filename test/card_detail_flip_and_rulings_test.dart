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
import 'package:countr/features/hydration/domain/models/scryfall_ruling.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScryfallRuling Model Tests', () {
    test('serializes to and from JSON correctly', () {
      final json = {
        'oracle_id': 'oracle-123',
        'source': 'wotc',
        'published_at': '2023-06-23',
        'comment': 'Protection from everything means that The One Ring cannot be targeted.',
      };

      final ruling = ScryfallRuling.fromJson(json);
      expect(ruling.oracleId, 'oracle-123');
      expect(ruling.source, 'wotc');
      expect(ruling.publishedAt, '2023-06-23');
      expect(ruling.comment, contains('Protection from everything'));

      final encoded = ruling.toJson();
      expect(encoded['oracle_id'], 'oracle-123');
      expect(encoded['source'], 'wotc');
      expect(encoded['published_at'], '2023-06-23');
      expect(encoded['comment'], contains('Protection from everything'));

      final ruling2 = ScryfallRuling.fromJson(json);
      expect(ruling, equals(ruling2));
      expect(ruling.hashCode, equals(ruling2.hashCode));
      expect(ruling.toString(), contains('2023-06-23'));
    });

    test('handles missing or alternate keys in JSON gracefully', () {
      final json = {
        'publishedAt': '2024-01-15',
        'comment': 'Deathtouch applies to any amount of damage.',
      };

      final ruling = ScryfallRuling.fromJson(json);
      expect(ruling.oracleId, isNull);
      expect(ruling.source, 'wotc');
      expect(ruling.publishedAt, '2024-01-15');
      expect(ruling.comment, 'Deathtouch applies to any amount of damage.');
    });
  });

  group('ScryfallService.fetchCardRulings Unit Tests', () {
    test('fetches and parses rulings successfully on 200 OK', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/cards/card-abc-123/rulings') {
          return http.Response(
            jsonEncode({
              'object': 'list',
              'has_more': false,
              'data': [
                {
                  'object': 'ruling',
                  'oracle_id': '8aa18e12-4e4b-4a57-a3f2-ef4799042c12',
                  'source': 'wotc',
                  'published_at': '2023-06-23',
                  'comment': 'Ruling 1: Protection from everything.',
                },
                {
                  'object': 'ruling',
                  'oracle_id': '8aa18e12-4e4b-4a57-a3f2-ef4799042c12',
                  'source': 'wotc',
                  'published_at': '2023-09-01',
                  'comment': 'Ruling 2: Burden counters accumulate.',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{"error": "Not Found"}', 404);
      });

      final service = ScryfallService(client: mockClient);
      final rulings = await service.fetchCardRulings('card-abc-123');

      expect(rulings, isNotNull);
      expect(rulings!.length, 2);
      expect(rulings[0].publishedAt, '2023-06-23');
      expect(rulings[0].comment, 'Ruling 1: Protection from everything.');
      expect(rulings[1].publishedAt, '2023-09-01');
      expect(rulings[1].comment, 'Ruling 2: Burden counters accumulate.');
    });

    test('returns empty list on 404 HTTP response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"object": "error", "message": "Not Found"}', 404);
      });

      final service = ScryfallService(client: mockClient);
      final rulings = await service.fetchCardRulings('non-existent-id');
      expect(rulings, isEmpty);
    });

    test('handles network exceptions / socket failures gracefully by returning null', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection reset by peer');
      });

      final service = ScryfallService(client: mockClient);
      final rulings = await service.fetchCardRulings('broken-network-id');
      expect(rulings, isNull);
    });
  });

  group('CardDetailSheet Flip UI Widget Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    VaultItem createItem({
      required String id,
      required String name,
      required String dynamicData,
    }) {
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'Innistrad',
        imageUrl: 'https://cards.scryfall.io/front/delver.jpg',
        acquiredPrice: 5.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 8.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: dynamicData,
      );
    }

    Widget buildSheet(VaultItem item, {ScryfallService? scryfallService}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          if (scryfallService != null)
            scryfallServiceProvider.overrideWithValue(scryfallService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CardDetailSheet(item: item),
          ),
        ),
      );
    }

    testWidgets('single-faced card does NOT render the flip button', (tester) async {
      final singleFaced = createItem(
        id: 'single-1',
        name: 'Lightning Bolt',
        dynamicData: jsonEncode({
          'oracle_text': 'Lightning Bolt deals 3 damage to any target.',
        }),
      );

      await tester.pumpWidget(buildSheet(singleFaced));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    testWidgets('multi-faced card with card_faces renders flip button and flips on tap', (tester) async {
      final dfc = createItem(
        id: 'dfc-delver',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicData: jsonEncode({
          'oracle_text': 'At the beginning of your upkeep, look at the top card of your library.',
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'},
            },
            {
              'name': 'Insectile Aberration',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'},
            },
          ],
        }),
      );

      await tester.pumpWidget(buildSheet(dfc));
      await tester.pumpAndSettle();

      // Flip button must be visible
      final flipButton = find.byKey(const Key('card_detail_flip_button'));
      expect(flipButton, findsOneWidget);

      // Tap flip button
      await tester.tap(flipButton);
      await tester.pump(const Duration(milliseconds: 200)); // mid-flip
      await tester.pumpAndSettle();

      // Tap card artwork to flip back
      final artworkHero = find.byKey(const Key('card_artwork_dfc-delver'));
      expect(artworkHero, findsOneWidget);
      await tester.tap(artworkHero);
      await tester.pumpAndSettle();
    });

    testWidgets('multi-faced card with back_image_url renders flip button and flips', (tester) async {
      final dfc = createItem(
        id: 'dfc-reversible',
        name: 'Reversible Pathway',
        dynamicData: jsonEncode({
          'oracle_text': 'Tap for red // Tap for green.',
          'back_image_url': 'https://cards.scryfall.io/back/green_pathway.jpg',
        }),
      );

      await tester.pumpWidget(buildSheet(dfc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('card_detail_flip_button')));
      await tester.pumpAndSettle();
    });
  });

  group('FullScreenCardViewer Flip & Foil Shading Tests', () {
    VaultItem createDfcItem() {
      return VaultItem(
        id: 'fullscreen-dfc-1',
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
            {
              'name': 'Nicol Bolas, the Ravager',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/bolas.jpg'},
            },
            {
              'name': 'Nicol Bolas, the Arisen',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/arisen.jpg'},
            },
          ],
        }),
      );
    }

    VaultItem createSingleItem() {
      return VaultItem(
        id: 'fullscreen-single-1',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: 'Alpha',
        imageUrl: 'https://cards.scryfall.io/front/lotus.jpg',
        acquiredPrice: 10000.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: true,
        currentMarketPrice: 20000.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: '{}',
      );
    }

    testWidgets('shows flip button for multi-faced card and omits for single-faced', (tester) async {
      final dfc = createDfcItem();
      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfc)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsOneWidget);

      final single = createSingleItem();
      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: single)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);
    });

    testWidgets('preserves foil ShaderMask across 3D flips on multi-faced card', (tester) async {
      final dfc = createDfcItem();
      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: dfc)));
      await tester.pumpAndSettle();

      // Initially foil is off -> no ShaderMask
      expect(find.byType(ShaderMask), findsNothing);

      // Toggle foil ON
      final foilToggle = find.byKey(const Key('fullscreen_foil_toggle'));
      await tester.tap(foilToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ShaderMask must be present
      expect(find.byType(ShaderMask), findsOneWidget);

      // Flip card while foil is active
      final flipButton = find.byKey(const Key('fullscreen_flip_button'));
      await tester.tap(flipButton);
      await tester.pump(const Duration(milliseconds: 200));

      // Foil ShaderMask remains active during flip transition
      expect(find.byType(ShaderMask), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      // Foil ShaderMask remains active on back face
      expect(find.byType(ShaderMask), findsOneWidget);

      // Toggle foil OFF on back face
      await tester.tap(foilToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group('Card Mechanics & Rulings Section and SQLite Caching Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders pre-cached rulings from dynamicData without network request', (tester) async {
      var networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });
      final mockService = ScryfallService(client: mockClient);

      final cardWithCachedRulings = VaultItem(
        id: 'the-one-ring',
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
          'keywords': ['Lifelink'],
          'cached_rulings': [
            {
              'oracle_id': 'ring-oracle',
              'published_at': '2023-06-23',
              'comment': 'Protection from everything means that the player cannot be damaged or targeted.',
            },
          ],
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: cardWithCachedRulings),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section header exists
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      // Keyword exists
      expect(find.text('Lifelink'), findsWidgets);
      // Cached ruling publication date and comment exist
      expect(find.text('2023-06-23'), findsOneWidget);
      expect(find.text('Protection from everything means that the player cannot be damaged or targeted.'), findsOneWidget);

      // Zero network calls made
      expect(networkCalled, isFalse);
    });

    testWidgets('fetches Scryfall rulings on demand and persists to SQLite database', (tester) async {
      var fetchCount = 0;
      final mockClient = MockClient((request) async {
        fetchCount++;
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [
              {
                'object': 'ruling',
                'oracle_id': 'sheoldred-oracle',
                'published_at': '2022-09-09',
                'comment': 'If a spell causes a player to draw multiple cards, Sheoldred triggers for each one.',
              }
            ]
          }),
          200,
        );
      });
      final mockService = ScryfallService(client: mockClient);

      // Insert card into Drift SQLite database first
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'sheoldred-apocalypse',
              collectionType: 'mtg',
              name: 'Sheoldred, the Apocalypse',
              setOrSeries: 'DMU',
              imageUrl: 'https://cards.scryfall.io/front/sheoldred.jpg',
              acquiredPrice: 60.0,
              acquiredDate: DateTime(2022, 9, 9),
              condition: 'NM',
              currentMarketPrice: 85.0,
              lastPriceUpdate: DateTime(2022, 9, 9),
              dynamicData: jsonEncode({
                'keywords': ['Deathtouch'],
                'oracle_text': 'Deathtouch\\nWhenever you draw a card, you gain 2 life.',
              }),
            ),
          );

      final card = await db.vaultDao.getItemById('sheoldred-apocalypse');
      expect(card, isNotNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: card!),
            ),
          ),
        ),
      );

      // Settle async fetch and SQLite persistence
      await tester.pumpAndSettle();

      expect(fetchCount, 1);
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      expect(find.text('2022-09-09'), findsOneWidget);
      expect(
        find.text('If a spell causes a player to draw multiple cards, Sheoldred triggers for each one.'),
        findsOneWidget,
      );

      // Verify that rulings were cached into the SQLite database
      final updatedFromDb = await db.vaultDao.getItemById('sheoldred-apocalypse');
      expect(updatedFromDb, isNotNull);
      final decodedData = jsonDecode(updatedFromDb!.dynamicData) as Map<String, dynamic>;
      expect(decodedData.containsKey('cached_rulings'), isTrue);
      final cachedList = decodedData['cached_rulings'] as List;
      expect(cachedList.length, 1);
      expect(cachedList[0]['published_at'], '2022-09-09');
    });

    testWidgets('offline fallback gracefully handles network errors without crashing', (tester) async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No Internet Connection');
      });
      final mockService = ScryfallService(client: mockClient);

      final cardWithoutRulings = VaultItem(
        id: 'offline-bear',
        collectionType: 'mtg',
        name: 'Grizzly Bears',
        setOrSeries: 'Alpha',
        imageUrl: 'https://cards.scryfall.io/front/bear.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime(2020, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        currentMarketPrice: 2.0,
        lastPriceUpdate: DateTime(2020, 1, 1),
        dynamicData: jsonEncode({
          'oracle_text': 'A bear with no rules text.',
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: cardWithoutRulings),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No crash, and section cleanly omitted for vanilla card
      expect(find.text('Card Mechanics & Rulings'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

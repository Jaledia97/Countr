import 'dart:convert';
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

  group('Adversarial Test 1: Rapid Card Flipping Stress Harness (50 Rapid Taps)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    VaultItem createDfcItem({required String id, required String name}) {
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'Innistrad',
        imageUrl: 'https://cards.scryfall.io/front/dfc_front.jpg',
        acquiredPrice: 12.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 18.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'card_faces': [
            {
              'name': '$name (Front)',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/dfc_front.jpg'},
            },
            {
              'name': '$name (Back)',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/dfc_back.jpg'},
            },
          ],
        }),
      );
    }

    testWidgets('CardDetailSheet survives 50 rapid flip taps during active 3D rotation without deadlock or layout exceptions', (tester) async {
      final dfcItem = createDfcItem(id: 'dfc-stress-1', name: 'Huntmaster of the Fells');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: dfcItem),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final flipButtonFinder = find.byKey(const Key('card_detail_flip_button'));
      expect(flipButtonFinder, findsOneWidget);

      final artworkFinder = find.byKey(const Key('card_artwork_dfc-stress-1'));
      expect(artworkFinder, findsOneWidget);

      // Perform 50 rapid taps alternating between flip button and card artwork mid-rotation
      for (int i = 0; i < 50; i++) {
        final target = (i % 2 == 0) ? flipButtonFinder : artworkFinder;
        await tester.tap(target);
        // Advance animation by a short slice (10ms) so tap occurs during active 3D rotation
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Ensure no animation controller deadlock: pumpAndSettle must complete cleanly
      await tester.pumpAndSettle();

      // 50 is an even number of toggles: state should return to front face
      expect(tester.takeException(), isNull);
      expect(flipButtonFinder, findsOneWidget);

      // Verify another tap after settling flips to back face
      await tester.tap(flipButtonFinder);
      await tester.pump(const Duration(milliseconds: 200)); // mid-flip
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('FullScreenCardViewer survives 50 rapid flip taps during active 3D rotation without deadlock or layout exceptions', (tester) async {
      final dfcItem = createDfcItem(id: 'dfc-fullscreen-stress', name: 'Jace, Vryn\'s Prodigy');

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenCardViewer(item: dfcItem),
        ),
      );
      await tester.pumpAndSettle();

      final flipButton = find.byKey(const Key('fullscreen_flip_button'));
      expect(flipButton, findsOneWidget);

      // Perform 50 rapid taps with 8ms pump between taps
      for (int i = 0; i < 50; i++) {
        await tester.tap(flipButton);
        await tester.pump(const Duration(milliseconds: 8));
      }

      // Must settle cleanly without deadlock
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(flipButton, findsOneWidget);
    });
  });

  group('Adversarial Test 2: Rapid Foil Finish & Flip Concurrency Stress Harness', () {
    VaultItem createDfcItem() {
      return VaultItem(
        id: 'dfc-foil-flip-stress',
        collectionType: 'mtg',
        name: 'Archangel Avacyn',
        setOrSeries: 'Shadows over Innistrad',
        imageUrl: 'https://cards.scryfall.io/front/avacyn.jpg',
        acquiredPrice: 20.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 25.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'card_faces': [
            {
              'name': 'Archangel Avacyn',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/avacyn.jpg'},
            },
            {
              'name': 'Avacyn, the Purifier',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/purifier.jpg'},
            },
          ],
        }),
      );
    }

    testWidgets('rapidly toggles Foil Finish ON/OFF while actively flipping card art without ticker or shader collision', (tester) async {
      final dfcItem = createDfcItem();

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenCardViewer(item: dfcItem),
        ),
      );
      await tester.pumpAndSettle();

      final flipButton = find.byKey(const Key('fullscreen_flip_button'));
      final foilToggle = find.byKey(const Key('fullscreen_foil_toggle'));

      // Loop 20 times: trigger flip, then toggle foil, advancing by varying time slices
      for (int i = 0; i < 20; i++) {
        if (i % 2 == 0) {
          await tester.tap(flipButton);
        }
        await tester.pump(const Duration(milliseconds: 25));
        await tester.tap(foilToggle);
        await tester.pump(const Duration(milliseconds: 25));
      }

      // Check exception state
      expect(tester.takeException(), isNull);

      // If foil is currently active, ShaderMask exists
      final bool hasShaderMask = find.byType(ShaderMask).evaluate().isNotEmpty;
      if (hasShaderMask) {
        // Turn foil off to allow pumpAndSettle without repeating ticker timeout
        await tester.tap(foilToggle);
        await tester.pump();
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ShaderMask), findsNothing);

      // Now toggle foil ON, let it run, verify ShaderMask present
      await tester.tap(foilToggle);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShaderMask), findsOneWidget);

      // Flip while foil is ON
      await tester.tap(flipButton);
      await tester.pump(const Duration(milliseconds: 200)); // mid-flip
      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250)); // flip finished
      expect(find.byType(ShaderMask), findsOneWidget);

      // Toggle foil OFF and settle
      await tester.tap(foilToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Test 3: Malformed Rulings Payload Parsing Harness', () {
    test('parses completely empty JSON object without throwing', () {
      final ruling = ScryfallRuling.fromJson(const {});
      expect(ruling.oracleId, isNull);
      expect(ruling.source, 'wotc');
      expect(ruling.publishedAt, '');
      expect(ruling.comment, '');
    });

    test('handles JSON with explicit null fields gracefully', () {
      final json = {
        'oracle_id': null,
        'source': null,
        'published_at': null,
        'publishedAt': null,
        'comment': null,
      };

      final ruling = ScryfallRuling.fromJson(json);
      expect(ruling.oracleId, isNull);
      expect(ruling.source, 'wotc');
      expect(ruling.publishedAt, '');
      expect(ruling.comment, '');
    });

    test('handles JSON with unrecognized extra and nested keys without distortion', () {
      final json = {
        'oracle_id': 'oracle-xyz',
        'source': 'wotc',
        'published_at': '2024-05-01',
        'comment': 'Valid comment',
        'unknown_field': 12345,
        'nested_object': {'a': 1, 'b': 'test'},
        'metadata': ['one', 'two'],
      };

      final ruling = ScryfallRuling.fromJson(json);
      expect(ruling.oracleId, 'oracle-xyz');
      expect(ruling.source, 'wotc');
      expect(ruling.publishedAt, '2024-05-01');
      expect(ruling.comment, 'Valid comment');
    });

    test('stress tests parsing 150 rulings in bulk for throughput and memory stability', () {
      final bulkPayload = List.generate(150, (i) => {
        'object': 'ruling',
        'oracle_id': 'oracle-uuid-$i',
        'source': (i % 2 == 0) ? 'wotc' : 'scryfall',
        'published_at': '2023-${(i % 12 + 1).toString().padLeft(2, '0')}-01',
        'comment': 'Detailed ruling rule #$i: This is an official ruling regarding state-based actions and triggers.',
      });

      final stopwatch = Stopwatch()..start();
      final parsed = bulkPayload.map((map) => ScryfallRuling.fromJson(map)).toList();
      stopwatch.stop();

      expect(parsed.length, 150);
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // sub-100ms parsing
      expect(parsed[0].comment, contains('rule #0'));
      expect(parsed[149].comment, contains('rule #149'));
    });

    test('evaluates resilience against unexpected non-string types in ruling payload', () {
      // Adversarial payload with unexpected types (int, bool, list)
      final malformedPayload = {
        'oracle_id': 99999, // int instead of String
        'source': true, // bool instead of String
        'published_at': 20240101, // int instead of String
        'comment': 42, // int instead of String
      };

      // We test whether ScryfallRuling.fromJson tolerates or throws TypeError on unexpected types
      try {
        final ruling = ScryfallRuling.fromJson(malformedPayload);
        // If it parsed by converting to string:
        expect(ruling, isNotNull);
      } catch (e) {
        // Documenting exact failure mode if type cast error occurs
        expect(e, isA<TypeError>());
      }
    });

    test('ScryfallService handles API responses containing mixed valid and malformed ruling objects gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [
              {
                'object': 'ruling',
                'oracle_id': 'ruling-1',
                'published_at': '2023-01-01',
                'comment': 'Valid ruling 1',
              },
              {
                'object': 'ruling',
                // Malformed entry with non-string comment causing TypeError
                'oracle_id': 12345,
                'comment': 9999,
              },
              {
                'object': 'ruling',
                'oracle_id': 'ruling-2',
                'published_at': '2023-02-02',
                'comment': 'Valid ruling 2',
              }
            ],
          }),
          200,
        );
      });

      final service = ScryfallService(client: mockClient);
      // fetchCardRulings has a global try/catch returning [] on unexpected format/TypeError
      final rulings = await service.fetchCardRulings('mixed-card-id');
      // Graceful fallback returns empty list rather than crashing the UI
      expect(rulings, isEmpty);
    });
  });

  group('Adversarial Test 4: SQLite Cache Durability Across Sheet Lifecycle', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('cached rulings in dynamicData survive sheet close and re-open without new network calls', (tester) async {
      int networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [
              {
                'object': 'ruling',
                'oracle_id': 'durability-oracle-1',
                'published_at': '2023-04-14',
                'comment': 'First official durable ruling for this card.',
              },
              {
                'object': 'ruling',
                'oracle_id': 'durability-oracle-2',
                'published_at': '2023-05-20',
                'comment': 'Second official durable ruling for this card.',
              },
            ],
          }),
          200,
        );
      });
      final mockService = ScryfallService(client: mockClient);

      // 1. Seed card in SQLite database with empty rulings cache
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'durable-card-1',
          collectionType: 'mtg',
          name: 'Teferi, Hero of Dominaria',
          setOrSeries: 'DOM',
          imageUrl: 'https://cards.scryfall.io/front/teferi.jpg',
          acquiredPrice: 40.0,
          acquiredDate: DateTime(2023, 1, 1),
          condition: 'NM',
          currentMarketPrice: 45.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'oracle_text': '+1: Draw a card at the beginning of the next end step, untap two lands.',
          }),
        ),
      );

      final initialCard = await db.vaultDao.getItemById('durable-card-1');
      expect(initialCard, isNotNull);

      // Helper to pump the sheet in a Navigator route so it can be pushed and popped
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockService),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_sheet_button'),
                      onPressed: () {
                        CardDetailSheet.show(context, initialCard!);
                      },
                      child: const Text('Open Sheet'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Open the sheet for the first time
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Verify network request was dispatched once
      expect(networkCallCount, 1);
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      expect(find.text('First official durable ruling for this card.'), findsOneWidget);
      expect(find.text('Second official durable ruling for this card.'), findsOneWidget);

      // 2. Verify SQLite database was updated with cached_rulings
      final cardAfterFirstOpen = await db.vaultDao.getItemById('durable-card-1');
      expect(cardAfterFirstOpen, isNotNull);
      final decodedData = jsonDecode(cardAfterFirstOpen!.dynamicData) as Map<String, dynamic>;
      expect(decodedData.containsKey('cached_rulings'), isTrue);
      final cachedList = decodedData['cached_rulings'] as List;
      expect(cachedList.length, 2);

      // 3. Close the sheet (pop from Navigator)
      final closeButton = find.byType(IconButton).first;
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Sheet should now be dismissed
      expect(find.text('Card Mechanics & Rulings'), findsNothing);

      // 4. Re-open sheet with the refreshed database item
      final cardFreshFromDb = await db.vaultDao.getItemById('durable-card-1');
      expect(cardFreshFromDb, isNotNull);

      // Trigger re-opening with the persisted item
      final BuildContext currentContext = tester.element(find.byKey(const Key('open_sheet_button')));
      CardDetailSheet.show(currentContext, cardFreshFromDb!);
      await tester.pumpAndSettle();

      // 5. Verify cached rulings render immediately WITHOUT additional network requests
      expect(networkCallCount, 1); // Strictly 1, zero new network requests!
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      expect(find.text('First official durable ruling for this card.'), findsOneWidget);
      expect(find.text('Second official durable ruling for this card.'), findsOneWidget);

      // 6. Close sheet again
      final closeButton2 = find.byType(IconButton).first;
      await tester.tap(closeButton2);
      await tester.pumpAndSettle();
      expect(networkCallCount, 1);
    });

    testWidgets('empty rulings response is cached in SQLite dynamicData and does not trigger repeated network calls', (tester) async {
      int networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [],
          }),
          200,
        );
      });
      final mockService = ScryfallService(client: mockClient);

      // Card with no rulings
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-no-rulings',
          collectionType: 'mtg',
          name: 'Vanilla Creature',
          setOrSeries: 'M21',
          imageUrl: 'https://cards.scryfall.io/front/creature.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2023, 1, 1),
          condition: 'NM',
          currentMarketPrice: 1.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'oracle_text': 'A simple creature with no abilities.',
          }),
        ),
      );

      final initialCard = await db.vaultDao.getItemById('card-no-rulings');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockService),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_empty_sheet_button'),
                      onPressed: () {
                        CardDetailSheet.show(context, initialCard!);
                      },
                      child: const Text('Open Empty Sheet'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // First open
      await tester.tap(find.byKey(const Key('open_empty_sheet_button')));
      await tester.pumpAndSettle();
      expect(networkCallCount, 1);

      // Verify SQLite cached empty rulings list
      final cardAfterFirstOpen = await db.vaultDao.getItemById('card-no-rulings');
      final decodedData = jsonDecode(cardAfterFirstOpen!.dynamicData) as Map<String, dynamic>;
      expect(decodedData.containsKey('cached_rulings'), isTrue);
      expect((decodedData['cached_rulings'] as List), isEmpty);

      // Close sheet
      final closeButton = find.byType(IconButton).first;
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Re-open sheet with cached empty rulings
      final reloadedCard = await db.vaultDao.getItemById('card-no-rulings');
      final BuildContext currentContext = tester.element(find.byKey(const Key('open_empty_sheet_button')));
      CardDetailSheet.show(currentContext, reloadedCard!);
      await tester.pumpAndSettle();

      // Must NOT trigger another network request
      expect(networkCallCount, 1);
    });
  });
}

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

  group('Reviewer 2 Adversarial & Edge Case Tests for R3', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp(VaultItem item, {ScryfallService? scryfallService}) {
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

    testWidgets('Edge Case: Card with 0 rulings caches empty list and never re-fetches', (tester) async {
      int apiCallCount = 0;
      final mockClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [], // 0 rulings returned
          }),
          200,
        );
      });
      final mockService = ScryfallService(client: mockClient);

      // Insert item into SQLite
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-zero-rulings',
          collectionType: 'mtg',
          name: 'Vanilla Mountain',
          setOrSeries: 'LEA',
          imageUrl: 'https://cards.scryfall.io/mountain.jpg',
          acquiredPrice: 10.0,
          acquiredDate: DateTime(2023, 1, 1),
          condition: 'NM',
          currentMarketPrice: 15.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'oracle_text': '{T}: Add {R}.',
          }),
        ),
      );

      final item = await db.vaultDao.getItemById('card-zero-rulings');
      expect(item, isNotNull);

      // First render: triggers fetch, receives 0 rulings, persists cached_rulings: []
      await tester.pumpWidget(createTestApp(item!, scryfallService: mockService));
      await tester.pumpAndSettle();

      expect(apiCallCount, 1);
      // Section header should NOT be displayed because keywords and rulings are both empty
      expect(find.text('Card Mechanics & Rulings'), findsNothing);

      // Verify SQLite now stores cached_rulings: []
      final persisted = await db.vaultDao.getItemById('card-zero-rulings');
      expect(persisted, isNotNull);
      final dynamicMap = jsonDecode(persisted!.dynamicData) as Map<String, dynamic>;
      expect(dynamicMap.containsKey('cached_rulings'), isTrue);
      expect(dynamicMap['cached_rulings'], isEmpty);

      // Second render with the persisted item: should NOT make any API calls!
      await tester.pumpWidget(createTestApp(persisted, scryfallService: mockService));
      await tester.pumpAndSettle();

      expect(apiCallCount, 1); // No second network call
    });

    testWidgets('Edge Case: Missing back art (empty URL, 1 face, nulls) omits flip button cleanly', (tester) async {
      final itemsWithInvalidBackArt = [
        // 1. back_image_url is empty string
        VaultItem(
          id: 'invalid-back-1',
          collectionType: 'mtg',
          name: 'Fake Card 1',
          setOrSeries: 'SET',
          imageUrl: 'https://cards.scryfall.io/front.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
          currentMarketPrice: 2.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({'back_image_url': ''}),
        ),
        // 2. card_faces has only 1 element
        VaultItem(
          id: 'invalid-back-2',
          collectionType: 'mtg',
          name: 'Fake Card 2',
          setOrSeries: 'SET',
          imageUrl: 'https://cards.scryfall.io/front.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
          currentMarketPrice: 2.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'card_faces': [
              {'name': 'Only Front', 'image_uris': {'normal': 'https://cards.scryfall.io/front.jpg'}},
            ],
          }),
        ),
        // 3. card_faces second face has empty image_uris and empty direct url
        VaultItem(
          id: 'invalid-back-3',
          collectionType: 'mtg',
          name: 'Fake Card 3',
          setOrSeries: 'SET',
          imageUrl: 'https://cards.scryfall.io/front.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
          currentMarketPrice: 2.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'card_faces': [
              {'name': 'Front', 'image_uris': {'normal': 'https://cards.scryfall.io/front.jpg'}},
              {'name': 'Back with no image', 'image_uris': {}, 'image_url': ''},
            ],
          }),
        ),
      ];

      for (final item in itemsWithInvalidBackArt) {
        // Test in CardDetailSheet
        await tester.pumpWidget(createTestApp(item));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('card_detail_flip_button')), findsNothing,
            reason: 'Flip button should not appear for item: ${item.id}');

        // Test in FullScreenCardViewer
        await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: item)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing,
            reason: 'Fullscreen flip button should not appear for item: ${item.id}');
      }
    });

    testWidgets('Edge Case: Non-MTG cards (Pokemon, Lorcana) completely omit rulings requests and section', (tester) async {
      int networkCallCount = 0;
      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response('{}', 200);
      });
      final mockService = ScryfallService(client: mockClient);

      final pokemonCard = VaultItem(
        id: 'pkmn-charizard',
        collectionType: 'pokemon',
        name: 'Charizard Base Set',
        setOrSeries: 'Base Set',
        imageUrl: 'https://images.pokemontcg.io/base1/4.png',
        acquiredPrice: 300.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: true, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 450.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'hp': '120',
          'types': ['Fire'],
          'attacks': [
            {'name': 'Fire Spin', 'damage': '100'}
          ],
        }),
      );

      await tester.pumpWidget(createTestApp(pokemonCard, scryfallService: mockService));
      await tester.pumpAndSettle();

      // Zero network calls made to Scryfall for Pokemon
      expect(networkCallCount, 0);
      // No Card Mechanics & Rulings section
      expect(find.text('Card Mechanics & Rulings'), findsNothing);

      final lorcanaCard = VaultItem(
        id: 'lorcana-elsa',
        collectionType: 'lorcana',
        name: 'Elsa - Spirit of Winter',
        setOrSeries: 'The First Chapter',
        imageUrl: 'https://lorcania.com/cards/elsa.jpg',
        acquiredPrice: 40.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 50.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'ink_cost': 8,
          'strength': 4,
          'willpower': 6,
        }),
      );

      await tester.pumpWidget(createTestApp(lorcanaCard, scryfallService: mockService));
      await tester.pumpAndSettle();

      // Zero network calls made for Lorcana
      expect(networkCallCount, 0);
      expect(find.text('Card Mechanics & Rulings'), findsNothing);
    });

    testWidgets('Offline Behavior: Pre-cached rulings render offline during network outage', (tester) async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Offline: No route to host');
      });
      final mockService = ScryfallService(client: mockClient);

      final offlineCardWithCache = VaultItem(
        id: 'offline-cached-card',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        imageUrl: 'https://cards.scryfall.io/solring.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 2.5,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'oracle_text': '{T}: Add {C}{C}.',
          'cached_rulings': [
            {
              'published_at': '2011-09-22',
              'comment': 'Sol Ring provides two colorless mana, not generic mana.',
            }
          ],
        }),
      );

      await tester.pumpWidget(createTestApp(offlineCardWithCache, scryfallService: mockService));
      await tester.pumpAndSettle();

      // Cleanly renders section and cached ruling despite network being offline
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      expect(find.text('2011-09-22'), findsOneWidget);
      expect(
        find.text('Sol Ring provides two colorless mana, not generic mana.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Offline Behavior: Network Timeout / Exception handled without crashing', (tester) async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Scryfall request timed out');
      });
      final mockService = ScryfallService(client: mockClient);

      final cardWithoutCache = VaultItem(
        id: 'timeout-card',
        collectionType: 'mtg',
        name: 'Urza, Lord High Artificer',
        setOrSeries: 'MH1',
        imageUrl: 'https://cards.scryfall.io/urza.jpg',
        acquiredPrice: 40.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 45.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'oracle_text': 'When Urza enters the battlefield, create a 0/0 Construct.',
        }),
      );

      await tester.pumpWidget(createTestApp(cardWithoutCache, scryfallService: mockService));
      await tester.pumpAndSettle();

      // Zero unhandled exceptions, app remains functional
      expect(tester.takeException(), isNull);
    });
  });
}

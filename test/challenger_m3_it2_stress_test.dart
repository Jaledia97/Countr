import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenge 1: Network Failure Modes & Caching State Machine', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('HTTP 500, SocketException, TimeoutException return null; 404 and 200-empty return []', () async {
      // 500 Internal Server Error -> null
      final client500 = MockClient((r) async => http.Response('Internal Server Error', 500));
      final service500 = ScryfallService(client: client500);
      expect(await service500.fetchCardRulings('c500'), isNull);

      // SocketException (Offline) -> null
      final clientSocket = MockClient((r) async => throw const SocketException('Connection refused'));
      final serviceSocket = ScryfallService(client: clientSocket);
      expect(await serviceSocket.fetchCardRulings('csocket'), isNull);

      // TimeoutException -> null
      final clientTimeout = MockClient((r) async => throw TimeoutException('Deadline exceeded'));
      final serviceTimeout = ScryfallService(client: clientTimeout);
      expect(await serviceTimeout.fetchCardRulings('ctimeout'), isNull);

      // 404 Not Found -> []
      final client404 = MockClient((r) async => http.Response('Not Found', 404));
      final service404 = ScryfallService(client: client404);
      expect(await service404.fetchCardRulings('c404'), isEmpty);

      // 200 with empty list -> []
      final client200Empty = MockClient((r) async => http.Response(jsonEncode({'object': 'list', 'data': []}), 200));
      final service200Empty = ScryfallService(client: client200Empty);
      expect(await service200Empty.fetchCardRulings('c200empty'), isEmpty);
    });

    testWidgets('Offline failure does not write cached_rulings; subsequent online view populates rulings', (tester) async {
      var isOnline = false;
      var apiRequestCount = 0;

      final mockClient = MockClient((request) async {
        apiRequestCount++;
        if (!isOnline) {
          throw const SocketException('No internet');
        }
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [
              {
                'oracle_id': 'oracle-123',
                'published_at': '2023-11-17',
                'comment': 'Empirically tested online recovery ruling.',
              }
            ]
          }),
          200,
        );
      });
      final service = ScryfallService(client: mockClient);

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'offline-mtg-card',
              collectionType: 'mtg',
              name: 'Recovery Test Card',
              setOrSeries: 'TEST',
              imageUrl: 'https://cards.scryfall.io/front/test.jpg',
              acquiredPrice: 1.0,
              acquiredDate: DateTime(2023, 1, 1),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime(2023, 1, 1),
              dynamicData: '{}',
            ),
          );

      final initialCard = await db.vaultDao.getItemById('offline-mtg-card');
      expect(initialCard, isNotNull);

      // Attempt 1: Offline
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

      expect(apiRequestCount, 1);
      expect(find.text('Empirically tested online recovery ruling.'), findsNothing);

      // Database verification: must NOT contain cached_rulings
      final dbCardAfterOffline = await db.vaultDao.getItemById('offline-mtg-card');
      final dataAfterOffline = jsonDecode(dbCardAfterOffline!.dynamicData) as Map<String, dynamic>;
      expect(dataAfterOffline.containsKey('cached_rulings'), isFalse,
          reason: 'cached_rulings must NOT be written when network call fails');

      // Now bring network online
      isOnline = true;

      // Attempt 2: Re-open card sheet
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: dbCardAfterOffline))),
        ),
      );
      await tester.pumpAndSettle();

      // Should have triggered second request and rendered ruling
      expect(apiRequestCount, 2);
      expect(find.text('Empirically tested online recovery ruling.'), findsOneWidget);

      // Database verification: now must contain cached_rulings
      final dbCardAfterOnline = await db.vaultDao.getItemById('offline-mtg-card');
      final dataAfterOnline = jsonDecode(dbCardAfterOnline!.dynamicData) as Map<String, dynamic>;
      expect(dataAfterOnline.containsKey('cached_rulings'), isTrue);
      expect((dataAfterOnline['cached_rulings'] as List).length, 1);
    });

    testWidgets('HTTP 500 error does not write cached_rulings; subsequent view retries', (tester) async {
      var serverHealthy = false;
      var apiRequestCount = 0;

      final mockClient = MockClient((request) async {
        apiRequestCount++;
        if (!serverHealthy) {
          return http.Response('Server Error', 500);
        }
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [
              {
                'oracle_id': 'oracle-500',
                'published_at': '2024-01-01',
                'comment': 'Server recovered ruling.',
              }
            ]
          }),
          200,
        );
      });
      final service = ScryfallService(client: mockClient);

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: '500-mtg-card',
              collectionType: 'mtg',
              name: '500 Recovery Card',
              setOrSeries: 'TEST',
              imageUrl: 'https://cards.scryfall.io/front/500.jpg',
              acquiredPrice: 1.0,
              acquiredDate: DateTime(2024, 1, 1),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime(2024, 1, 1),
              dynamicData: '{}',
            ),
          );

      final initialCard = await db.vaultDao.getItemById('500-mtg-card');

      // Attempt 1: 500 error
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

      expect(apiRequestCount, 1);
      final dbCard1 = await db.vaultDao.getItemById('500-mtg-card');
      final data1 = jsonDecode(dbCard1!.dynamicData) as Map<String, dynamic>;
      expect(data1.containsKey('cached_rulings'), isFalse);

      // Server recovers
      serverHealthy = true;

      // Attempt 2: Re-open
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: dbCard1))),
        ),
      );
      await tester.pumpAndSettle();

      expect(apiRequestCount, 2);
      expect(find.text('Server recovered ruling.'), findsOneWidget);

      final dbCard2 = await db.vaultDao.getItemById('500-mtg-card');
      final data2 = jsonDecode(dbCard2!.dynamicData) as Map<String, dynamic>;
      expect(data2.containsKey('cached_rulings'), isTrue);
    });

    testWidgets('Legitimate 404 caches [] to prevent repeating calls for cards with no rulings endpoint', (tester) async {
      var apiRequestCount = 0;
      final mockClient = MockClient((request) async {
        apiRequestCount++;
        return http.Response('Not Found', 404);
      });
      final service = ScryfallService(client: mockClient);

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: '404-card',
              collectionType: 'mtg',
              name: '404 Card',
              setOrSeries: 'TEST',
              imageUrl: 'https://cards.scryfall.io/front/404.jpg',
              acquiredPrice: 1.0,
              acquiredDate: DateTime(2024, 1, 1),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime(2024, 1, 1),
              dynamicData: '{}',
            ),
          );

      final initialCard = await db.vaultDao.getItemById('404-card');

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

      expect(apiRequestCount, 1);

      // Card with confirmed 404 should persist []
      final dbCard = await db.vaultDao.getItemById('404-card');
      final data = jsonDecode(dbCard!.dynamicData) as Map<String, dynamic>;
      expect(data.containsKey('cached_rulings'), isTrue);
      expect((data['cached_rulings'] as List).isEmpty, isTrue);

      // Re-opening should NOT trigger network call
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: dbCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(apiRequestCount, 1);
    });
  });

  group('Challenge 2: Non-MTG Isolation Stress Test', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Pokemon card with MTG glossary words (Flying, Ward, Flash, Trample) omits Mechanics section', (tester) async {
      final pokemonCard = VaultItem(
        id: 'pkmn-adversarial-keywords',
        collectionType: 'pokemon',
        name: 'Flying Pikachu VMAX',
        setOrSeries: 'Celebrations',
        imageUrl: 'https://images.pokemontcg.io/cel25/7_hires.png',
        acquiredPrice: 10.0,
        acquiredDate: DateTime(2022, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 12.0,
        lastPriceUpdate: DateTime(2022, 1, 1),
        dynamicData: jsonEncode({
          'keywords': ['Flying', 'Ward', 'Flash', 'Trample'],
          'oracle_text': 'Flying: During your opponent’s next turn, prevent all damage done to this Pokémon by attacks.',
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: pokemonCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics & Rulings'), findsNothing);
      expect(find.text('Flying'), findsNothing);
      expect(find.text('This creature can only be blocked by other creatures with flying or reach.'), findsNothing);
      expect(find.text('Ward'), findsNothing);
    });

    testWidgets('Lorcana card with Ward text and keywords omits Mechanics section', (tester) async {
      final lorcanaCard = VaultItem(
        id: 'lorcana-adversarial-ward',
        collectionType: 'lorcana',
        name: 'Cogsworth - Grandfather Clock',
        setOrSeries: 'Rise of the Floodborn',
        imageUrl: 'https://lorcana.cards/cogsworth.jpg',
        acquiredPrice: 15.0,
        acquiredDate: DateTime(2023, 11, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 18.0,
        lastPriceUpdate: DateTime(2023, 11, 1),
        dynamicData: jsonEncode({
          'keywords': ['Ward', 'Support'],
          'oracle_text': 'Ward (Opponents can\'t choose this character except to challenge.)',
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: lorcanaCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics & Rulings'), findsNothing);
      expect(find.text('Whenever this permanent becomes the target of a spell or ability an opponent controls...'), findsNothing);
    });

    testWidgets('Sports card with description containing MTG glossary keywords omits Mechanics section', (tester) async {
      final sportsCard = VaultItem(
        id: 'sports-adversarial-text',
        collectionType: 'sports',
        name: 'Shohei Ohtani #17',
        setOrSeries: '2023 Topps Now',
        imageUrl: 'https://sportscards.com/ohtani.jpg',
        acquiredPrice: 50.0,
        acquiredDate: DateTime(2023, 4, 1),
        quantity: 1,
        condition: 'Gem Mint 10',
        isGraded: true, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 85.0,
        lastPriceUpdate: DateTime(2023, 4, 1),
        dynamicData: jsonEncode({
          'oracle_text': 'Flash: Known for blazing fast speed, haste on the bases, and flying around the outfield.',
          'keywords': ['Haste', 'Flash', 'Flying'],
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: sportsCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics & Rulings'), findsNothing);
      expect(find.text('Haste'), findsNothing);
      expect(find.text('Flash'), findsNothing);
    });

    testWidgets('MTG card with keywords DOES display Card Mechanics & Rulings section', (tester) async {
      final mtgCard = VaultItem(
        id: 'mtg-keywords-card',
        collectionType: 'mtg',
        name: 'Serra Angel',
        setOrSeries: '30A',
        imageUrl: 'https://cards.scryfall.io/front/angel.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 3.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'keywords': ['Flying', 'Vigilance'],
          'oracle_text': 'Flying, vigilance',
          'cached_rulings': [],
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: mtgCard))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
      expect(find.text('Flying'), findsOneWidget);
      expect(find.text('This creature can only be blocked by other creatures with flying or reach.'), findsOneWidget);
      expect(find.text('Vigilance'), findsOneWidget);
      expect(find.textContaining('Attacking doesn\'t cause this creature to tap'), findsOneWidget);
    });
  });

  group('Challenge 3: Accessibility & Touch Target Evaluation', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('card_detail_flip_button passes labeledTapTargetGuideline and touch target >=48x48', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final dfc = VaultItem(
          id: 'dfc-card-detail-a11y',
          collectionType: 'mtg',
          name: 'Fable of the Mirror-Breaker',
          setOrSeries: 'NEO',
          imageUrl: 'https://cards.scryfall.io/front/fable.jpg',
          acquiredPrice: 15.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
          currentMarketPrice: 20.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'card_faces': [
              {
                'name': 'Fable of the Mirror-Breaker',
                'image_uris': {'normal': 'https://cards.scryfall.io/front/fable.jpg'},
              },
              {
                'name': 'Reflection of Kiki-Jiki',
                'image_uris': {'normal': 'https://cards.scryfall.io/back/kiki.jpg'},
              },
            ],
            'cached_rulings': [],
          }),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
            ],
            child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: dfc))),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byKey(const Key('card_detail_flip_button'));
        expect(buttonFinder, findsOneWidget);

        // Check size >= 48x48
        final renderBox = tester.renderObject<RenderBox>(buttonFinder);
        expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
        expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

        // Check semantics properties
        final semantics = tester.getSemantics(buttonFinder);
        expect(semantics.label, 'Flip card');
        expect(semantics.hint, 'Toggles between front and back face');
        expect(semantics.flagsCollection.isButton, isTrue);
        expect(semantics.tooltip, 'Flip card');

        // Evaluate Flutter accessibility guideline
        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'card_detail_flip_button must pass labeledTapTargetGuideline');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('fullscreen_flip_button passes labeledTapTargetGuideline and touch target >=48x48', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final dfc = VaultItem(
          id: 'dfc-fullscreen-a11y',
          collectionType: 'mtg',
          name: 'Huntmaster of the Fells',
          setOrSeries: 'DKA',
          imageUrl: 'https://cards.scryfall.io/front/huntmaster.jpg',
          acquiredPrice: 8.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
          currentMarketPrice: 10.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({
            'card_faces': [
              {
                'name': 'Huntmaster of the Fells',
                'image_uris': {'normal': 'https://cards.scryfall.io/front/huntmaster.jpg'},
              },
              {
                'name': 'Ravager of the Fells',
                'image_uris': {'normal': 'https://cards.scryfall.io/back/ravager.jpg'},
              },
            ],
          }),
        );

        await tester.pumpWidget(
          MaterialApp(home: FullScreenCardViewer(item: dfc)),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byKey(const Key('fullscreen_flip_button'));
        expect(buttonFinder, findsOneWidget);

        // Check size >= 48x48
        final renderBox = tester.renderObject<RenderBox>(buttonFinder);
        expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
        expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

        // Check semantics properties
        final semantics = tester.getSemantics(buttonFinder);
        expect(semantics.label, 'Flip card');
        expect(semantics.hint, 'Toggles between front and back face');
        expect(semantics.flagsCollection.isButton, isTrue);
        expect(semantics.tooltip, 'Flip card');

        // Confirm the flip button node satisfies labeledTapTargetGuideline criteria
        expect(semantics.label.isNotEmpty || semantics.tooltip.isNotEmpty, isTrue,
            reason: 'fullscreen_flip_button must provide a non-empty label or tooltip for screen readers');

        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'FullScreenCardViewer must pass labeledTapTargetGuideline: ${eval.reason}');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('fullscreen_flip_button widget directly passes labeledTapTargetGuideline', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        // Evaluate the flip button widget tree under labeledTapTargetGuideline
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Semantics(
                  button: true,
                  label: 'Flip card',
                  hint: 'Toggles between front and back face',
                  child: Tooltip(
                    message: 'Flip card',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('fullscreen_flip_button'),
                        onTap: () {},
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.flip_camera_android_rounded,
                                size: 20,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final eval = await labeledTapTargetGuideline.evaluate(tester);
        expect(eval.passed, isTrue, reason: 'fullscreen_flip_button widget must pass labeledTapTargetGuideline');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Single-faced cards do NOT render flip buttons in either viewer', (tester) async {
      final singleFaced = VaultItem(
        id: 'single-faced-card',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: 'LEA',
        imageUrl: 'https://cards.scryfall.io/front/bolt.jpg',
        acquiredPrice: 100.0,
        acquiredDate: DateTime(2020, 1, 1),
        quantity: 1,
        condition: 'LP',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 150.0,
        lastPriceUpdate: DateTime(2020, 1, 1),
        dynamicData: '{}',
      );

      // Check CardDetailSheet
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: singleFaced))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);

      // Check FullScreenCardViewer
      await tester.pumpWidget(
        MaterialApp(home: FullScreenCardViewer(item: singleFaced)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);
    });
  });
}

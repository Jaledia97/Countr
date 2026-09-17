import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_controller.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_state.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/hydration/presentation/widgets/hydration_progress_card.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Phase 2.5 - ScryfallService Tests', () {
    test('fetchBulkDownloadUri extracts jsonl_download_uri from Scryfall metadata',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'object': 'bulk_data',
            'id': 'e2ef41e3-5778-4bc2-af3f-78eca4dd9c23',
            'type': 'default_cards',
            'name': 'Default Cards',
            'jsonl_download_uri':
                'https://data.scryfall.io/default-cards/default-cards-2026.jsonl.gz',
            'compressed_size': 78247919,
          }),
          200,
        );
      });

      final service = ScryfallService(client: mockClient);
      final uri = await service.fetchBulkDownloadUri();
      expect(uri,
          'https://data.scryfall.io/default-cards/default-cards-2026.jsonl.gz');
    });

    test('fetchBulkDownloadUri extracts default_cards from list response',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'object': 'list',
            'has_more': false,
            'data': [
              {
                'object': 'bulk_data',
                'type': 'oracle_cards',
                'jsonl_download_uri': 'https://data.scryfall.io/oracle.jsonl.gz',
              },
              {
                'object': 'bulk_data',
                'type': 'default_cards',
                'jsonl_download_uri':
                    'https://data.scryfall.io/default.jsonl.gz',
              }
            ],
          }),
          200,
        );
      });

      final service = ScryfallService(client: mockClient);
      final uri = await service.fetchBulkDownloadUri();
      expect(uri, 'https://data.scryfall.io/default.jsonl.gz');
    });

    test('downloadBulkFile streams bytes directly to disk file with progress',
        () async {
      final sampleData = utf8.encode('[{"id":"card-1","name":"Black Lotus"}]');
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable([sampleData]),
          200,
          contentLength: sampleData.length,
        );
      });

      final service = ScryfallService(client: mockClient);
      final tempFile = File(
          '${Directory.systemTemp.path}/test_download_${DateTime.now().millisecondsSinceEpoch}.json');

      int progressCalls = 0;
      final file = await service.downloadBulkFile(
        downloadUri: 'https://data.scryfall.io/test.json',
        targetFilePath: tempFile.path,
        onProgress: (bytes, total) {
          progressCalls++;
          expect(bytes, sampleData.length);
          expect(total, sampleData.length);
        },
      );

      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('Black Lotus'));
      expect(progressCalls, greaterThanOrEqualTo(1));

      // Cleanup
      await file.delete();
    });
  });

  group('Phase 2.5 - ScryfallStreamingParser Mapping & Streaming Tests', () {
    test('mapScryfallCardToCompanion correctly maps fields and sets quantity: 0',
        () {
      final cardJson = {
        'id': 'mtg-001',
        'name': 'Sol Ring',
        'set_name': 'Commander 2026',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/sol_ring.jpg',
        },
        'prices': {
          'usd': '1.75',
        },
        'mana_cost': '{1}',
        'type_line': 'Artifact',
        'oracle_text': '{T}: Add {C}{C}.',
        'rarity': 'uncommon',
      };

      final companion = mapScryfallCardToCompanion(cardJson);

      expect(companion.id.value, 'mtg-001');
      expect(companion.collectionType.value, 'mtg');
      expect(companion.name.value, 'Sol Ring');
      expect(companion.setOrSeries.value, 'Commander 2026');
      expect(companion.imageUrl.value,
          'https://cards.scryfall.io/normal/sol_ring.jpg');
      expect(companion.currentMarketPrice.value, 1.75);
      expect(companion.acquiredPrice.value, 0.0);
      expect(companion.quantity.value, 0); // Must be 0 for catalog dictionary
      expect(companion.isGraded.value, isFalse);

      final dynamicData =
          jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['mana_cost'], '{1}');
      expect(dynamicData['oracle_text'], '{T}: Add {C}{C}.');
    });

    test('mapScryfallCardToCompanion supports double-faced cards', () {
      final doubleFacedCard = {
        'id': 'mtg-dfc',
        'name': 'Delver of Secrets // Insectile Aberration',
        'set': 'ISD',
        'card_faces': [
          {
            'name': 'Delver of Secrets',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/delver.jpg',
            }
          },
          {
            'name': 'Insectile Aberration',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/insectile.jpg',
            }
          }
        ],
        'prices': {'usd': null, 'usd_foil': '4.50'},
      };

      final companion = mapScryfallCardToCompanion(doubleFacedCard);
      expect(companion.imageUrl.value,
          'https://cards.scryfall.io/normal/delver.jpg');
      expect(companion.currentMarketPrice.value, 4.50);
      expect(companion.setOrSeries.value, 'ISD');
    });

    test('mapScryfallCardToCompanion joins oracle_text of card_faces with // and preserves front and back images', () {
      final dfcCard = {
        'id': 'mtg-dfc-oracle',
        'name': 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        'set_name': 'Core Set 2019',
        'card_faces': [
          {
            'name': 'Nicol Bolas, the Ravager',
            'mana_cost': '{1}{U}{B}{R}',
            'type_line': 'Legendary Creature — Elder Dragon',
            'oracle_text': 'Flying\nWhen Nicol Bolas, the Ravager enters the battlefield, each opponent discards a card.',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/nicol_front.jpg',
            },
          },
          {
            'name': 'Nicol Bolas, the Arisen',
            'mana_cost': '',
            'type_line': 'Legendary Planeswalker — Bolas',
            'oracle_text': '+2: Draw two cards.\n-3: Nicol Bolas deals 10 damage to target creature or planeswalker.',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/nicol_back.jpg',
            },
          },
        ],
        'prices': {'usd': '35.00'},
      };

      final companion = mapScryfallCardToCompanion(dfcCard);
      expect(companion.imageUrl.value, 'https://cards.scryfall.io/normal/front/nicol_front.jpg');
      expect(companion.setOrSeries.value, 'Core Set 2019');

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(
        dynamicData['oracle_text'],
        'Flying\nWhen Nicol Bolas, the Ravager enters the battlefield, each opponent discards a card. // +2: Draw two cards.\n-3: Nicol Bolas deals 10 damage to target creature or planeswalker.',
      );
      expect(dynamicData['back_image_url'], 'https://cards.scryfall.io/normal/front/nicol_back.jpg');
      expect(dynamicData['image_uris'], isNotNull);
      expect(dynamicData['image_uris']['normal'], 'https://cards.scryfall.io/normal/front/nicol_front.jpg');
      expect(dynamicData['card_faces'], isA<List>());
      final faces = dynamicData['card_faces'] as List;
      expect(faces.length, 2);
      expect(faces[0]['name'], 'Nicol Bolas, the Ravager');
      expect(faces[0]['image_url'], 'https://cards.scryfall.io/normal/front/nicol_front.jpg');
      expect(faces[1]['name'], 'Nicol Bolas, the Arisen');
      expect(faces[1]['image_url'], 'https://cards.scryfall.io/normal/front/nicol_back.jpg');
    });

    test('mapScryfallCardToCompanion captures flavor_name and persists in companion and dynamicData', () {
      final cardWithFlavorName = {
        'id': 'mtg-ozolith-adamantium',
        'name': 'The Ozolith',
        'flavor_name': 'Adamantium Bonding Tank',
        'set_name': 'Secret Lair Drop',
        'oracle_text': 'Whenever a creature you control leaves the battlefield, if it had counters on it, put those counters on The Ozolith.',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/front/ozolith.jpg',
        },
        'prices': {'usd': '42.00'},
      };

      final companion = mapScryfallCardToCompanion(cardWithFlavorName);
      expect(companion.name.value, 'The Ozolith');
      expect(companion.flavorName.value, 'Adamantium Bonding Tank');
      expect(companion.currentMarketPrice.value, 42.00);

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['flavor_name'], 'Adamantium Bonding Tank');
      expect(dynamicData['oracle_text'], contains('Whenever a creature you control'));
    });

    test('mapScryfallCardToCompanion captures flavor_name from card_faces if top-level is absent', () {
      final cardWithFaceFlavor = {
        'id': 'mtg-dfc-flavor',
        'name': 'Front Name // Back Name',
        'set': 'SLD',
        'card_faces': [
          {
            'name': 'Front Name',
            'flavor_name': 'Alternate Front',
            'oracle_text': 'Front oracle text.',
            'image_uris': {'normal': 'https://example.com/f.jpg'},
          },
          {
            'name': 'Back Name',
            'flavor_name': 'Alternate Back',
            'oracle_text': 'Back oracle text.',
            'image_uris': {'normal': 'https://example.com/b.jpg'},
          },
        ],
        'prices': {'usd': '12.00'},
      };

      final companion = mapScryfallCardToCompanion(cardWithFaceFlavor);
      expect(companion.flavorName.value, 'Alternate Front // Alternate Back');

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['flavor_name'], 'Alternate Front // Alternate Back');
      expect(dynamicData['oracle_text'], 'Front oracle text. // Back oracle text.');
      expect(dynamicData['back_image_url'], 'https://example.com/b.jpg');
    });

    test('parseStream handles strings with braces, escapes, and emits chunks',
        () async {
      final cards = [
        {
          'id': 'c1',
          'name': 'Card One',
          'oracle_text': '{T}: Add {G}. "A forest whispered: {yes}."',
          'prices': {'usd': '0.50'}
        },
        {
          'id': 'c2',
          'name': 'Card Two',
          'oracle_text': 'Target creature gains "flying".',
          'prices': {'usd': '2.00'}
        },
        {
          'id': 'c3',
          'name': 'Card Three',
          'prices': {'usd': '10.00'}
        }
      ];

      final jsonString = jsonEncode(cards);
      final byteStream = Stream.value(utf8.encode(jsonString));

      final parser = ScryfallStreamingParser();
      final chunks = await parser.parseStream(byteStream, chunkSize: 2).toList();

      expect(chunks.length, 2); // 2 in first chunk, 1 in second chunk
      expect(chunks[0].length, 2);
      expect(chunks[1].length, 1);
      expect(chunks[0][0].name.value, 'Card One');
      expect(chunks[0][1].name.value, 'Card Two');
      expect(chunks[1][0].name.value, 'Card Three');
    });

    test('parseFileInIsolate parses disk file and respects isolate backpressure',
        () async {
      final cards = List.generate(25, (index) => {
            'id': 'card-$index',
            'name': 'Catalog Card #$index',
            'set_name': 'Test Set',
            'prices': {'usd': '$index.50'},
          });

      final tempFile = File(
          '${Directory.systemTemp.path}/isolate_test_${DateTime.now().millisecondsSinceEpoch}.json');
      await tempFile.writeAsString(jsonEncode(cards));

      final parser = ScryfallStreamingParser();
      int chunkCount = 0;
      int itemsReceived = 0;

      final total = await parser.parseFileInIsolate(
        filePath: tempFile.path,
        chunkSize: 10,
        onChunk: (chunk, countSoFar) async {
          chunkCount++;
          itemsReceived += chunk.length;
          expect(countSoFar, itemsReceived);
          // Simulate brief async db batch write
          await Future.delayed(const Duration(milliseconds: 5));
        },
      );

      expect(total, 25);
      expect(itemsReceived, 25);
      expect(chunkCount, 3); // 10 + 10 + 5

      // Cleanup
      await tempFile.delete();
    });

    test('parseFileInIsolate handles gzipped JSONL (.jsonl.gz) files transparently',
        () async {
      final cards = List.generate(
          15,
          (i) => {
                'id': 'gz-card-$i',
                'name': 'Gzip Card #$i',
                'set_name': 'Gzip Set',
                'prices': {'usd': '3.50'},
              });

      // JSONL format: each line is a JSON object
      final jsonlLines = cards.map((c) => jsonEncode(c)).join('\n');
      final gzippedBytes = gzip.encode(utf8.encode(jsonlLines));

      final tempGzFile = File(
          '${Directory.systemTemp.path}/test_cards_${DateTime.now().millisecondsSinceEpoch}.jsonl.gz');
      await tempGzFile.writeAsBytes(gzippedBytes);

      final parser = ScryfallStreamingParser();
      int receivedCount = 0;

      final total = await parser.parseFileInIsolate(
        filePath: tempGzFile.path,
        chunkSize: 5,
        onChunk: (chunk, countSoFar) async {
          receivedCount += chunk.length;
        },
      );

      expect(total, 15);
      expect(receivedCount, 15);

      await tempGzFile.delete();
    });
  });

  group('Phase 2.5 - Drift Chunked Ingestion & Portfolio Separation', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.seedDatabase(); // Seeds 4 owned items (quantity > 0)
    });

    tearDown(() async {
      await db.close();
    });

    test('insertDictionaryChunked inserts catalog items without breaking batch',
        () async {
      final catalogItems = List.generate(
        2500,
        (i) => VaultItemsCompanion.insert(
          id: 'bulk-card-$i',
          collectionType: 'mtg',
          name: 'Bulk MTG Card #$i',
          setOrSeries: 'Core Set',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0), // Catalog unowned
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 1.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      int progressCalls = 0;
      await db.vaultDao.insertDictionaryChunked(
        catalogItems,
        onProgress: (inserted, total) {
          progressCalls++;
        },
      );

      expect(progressCalls, 3); // 1000 + 1000 + 500 = 3 chunks

      final allItems = await db.vaultDao.watchItemsByCollection('all').first;
      // 4 seeded + 2500 bulk = 2504 items
      expect(allItems.length, 2504);
    });

    test(
        'vaultPortfolioSummaryProvider strictly ignores catalog items (quantity: 0)',
        () async {
      final container = ProviderContainer(
        overrides: [
          activeGameContextProvider.overrideWith((ref) => 'All Collections'),
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );

      // Wait for initial seeded items to be active
      await container.read(vaultItemsStreamProvider.future);
      final initialSummary = container.read(vaultPortfolioSummaryProvider);

      // Total owned items = 4 (from seed)
      expect(initialSummary.totalItemCount, 4);
      final initialMarketValue = initialSummary.totalMarketValue;
      expect(initialMarketValue, greaterThan(0));

      // Now insert 100 catalog cards with huge market price, but quantity: 0
      final catalogCards = List.generate(
        100,
        (i) => VaultItemsCompanion.insert(
          id: 'expensive-catalog-$i',
          collectionType: 'mtg',
          name: 'Black Lotus Specimen #$i',
          setOrSeries: 'Alpha',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0), // UNOWNED
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 100000.0, // $100,000 each!
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      await db.vaultDao.insertDictionaryBatch(catalogCards);

      // Refresh stream
      await container.read(vaultItemsStreamProvider.future);
      final updatedSummary = container.read(vaultPortfolioSummaryProvider);

      // Portfolio valuation MUST NOT change because catalog items have quantity == 0!
      expect(updatedSummary.totalItemCount, 4);
      expect(updatedSummary.totalMarketValue, initialMarketValue);
      expect(updatedSummary.totalCostBasis, initialSummary.totalCostBasis);

      container.dispose();
    });
  });

  group('Phase 2.5 - HydrationController State Flow Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('startHydration transitions through states cleanly and completes',
        () async {
      await db.vaultDao.clearAllItems();

      final sampleCards = [
        {
          'id': 'mtg-test-1',
          'name': 'Counterspell',
          'prices': {'usd': '1.50'},
        },
        {
          'id': 'mtg-test-2',
          'name': 'Lightning Bolt',
          'prices': {'usd': '2.00'},
        },
      ];

      final tempFile = File(
          '${Directory.systemTemp.path}/hydration_ctrl_test_${DateTime.now().millisecondsSinceEpoch}.json');
      await tempFile.writeAsString(jsonEncode(sampleCards));

      final controller = HydrationController(
        scryfallService: ScryfallService(),
        parser: ScryfallStreamingParser(),
        vaultDao: db.vaultDao,
      );

      expect(controller.state.status, HydrationStatus.idle);

      await controller.startHydration(
        localFileToHydrate: tempFile,
        estimatedTotal: 2,
      );

      expect(controller.state.status, HydrationStatus.complete);
      expect(controller.state.insertedCount, 2);
      expect(controller.state.progress, 1.0);
      expect(controller.state.statusMessage, contains('2 MTG cards indexed'));

      // Check Drift SQLite has the 2 cards
      final items = await db.vaultDao.watchItemsByCollection('mtg').first;
      expect(items.length, 2);
      expect(items.map((i) => i.name), containsAll(['Counterspell', 'Lightning Bolt']));

      // Reset
      controller.reset();
      expect(controller.state.status, HydrationStatus.idle);

      // Cleanup
      await tempFile.delete();
    });
  });

  group('Phase 2.5 - UI Widgets & Integration Tests', () {
    testWidgets('HydrationProgressCard renders downloading and error states',
        (tester) async {
      // 1. Idle state -> SizedBox.shrink
      final idleContainer = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: idleContainer,
          child: const MaterialApp(
            home: Scaffold(body: HydrationProgressCard()),
          ),
        ),
      );
      expect(find.text('HYDRATION ENGINE'), findsNothing);

      // 2. Downloading state
      final downloadingContainer = ProviderContainer(
        overrides: [
          hydrationControllerProvider.overrideWith(
            (ref) => _StaticMockHydrationController(
              const HydrationState(
                status: HydrationStatus.downloading,
                statusMessage: 'Downloading MTG catalog (15.0 MB / 45.0 MB)...',
                progress: 0.33,
                bytesDownloaded: 15 * 1024 * 1024,
                totalBytes: 45 * 1024 * 1024,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: downloadingContainer,
          child: const MaterialApp(
            home: Scaffold(body: HydrationProgressCard()),
          ),
        ),
      );

      expect(find.text('HYDRATION ENGINE'), findsOneWidget);
      expect(find.text('DOWNLOADING'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('Downloading MTG catalog (15.0 MB / 45.0 MB)...'),
          findsOneWidget);

      // 3. Error state with retry
      final errorContainer = ProviderContainer(
        overrides: [
          hydrationControllerProvider.overrideWith(
            (ref) => _StaticMockHydrationController(
              const HydrationState(
                status: HydrationStatus.error,
                statusMessage: 'Network timeout',
                errorMessage: 'SocketException',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: errorContainer,
          child: const MaterialApp(
            home: Scaffold(body: HydrationProgressCard()),
          ),
        ),
      );

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Network timeout'), findsOneWidget);
    });

    testWidgets('VaultScreen displays Hydrate action button and invokes controller',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.seedDatabase();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the bolt hydration button in AppBar
      final boltButton = find.byTooltip('Hydrate MTG Dictionary');
      expect(boltButton, findsOneWidget);

      await db.close();
      container.dispose();
    });
  });
}

class _StaticMockHydrationController extends StateNotifier<HydrationState>
    implements HydrationController {
  _StaticMockHydrationController(super.state);

  @override
  Future<void> startHydration(
      {String? overrideDownloadUri,
      File? localFileToHydrate,
      int? estimatedTotal}) async {}

  @override
  void reset() {
    state = const HydrationState();
  }
}

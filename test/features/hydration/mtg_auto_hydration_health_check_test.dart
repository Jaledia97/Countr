import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_controller.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_state.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

class _MockTrackingHydrationController extends StateNotifier<HydrationState>
    implements HydrationController {
  int startHydrationCallCount = 0;
  String? lastOverrideDownloadUri;

  _MockTrackingHydrationController([HydrationState? initialState])
      : super(initialState ?? const HydrationState());

  @override
  Future<void> startHydration({
    String? overrideDownloadUri,
    File? localFileToHydrate,
    int? estimatedTotal,
  }) async {
    startHydrationCallCount++;
    lastOverrideDownloadUri = overrideDownloadUri;
    state = state.copyWith(status: HydrationStatus.downloading);
  }

  @override
  void reset() {
    state = const HydrationState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_cache_test_root_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return mockCacheDir.path;
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (mockCacheDir.existsSync()) {
      try {
        mockCacheDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('MtgAutoHydration & Health Check Unit Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    group('VaultDao.getMtgCatalogCardCount()', () {
      test('returns 0 when database has no MTG catalog cards', () async {
        final count = await db.vaultDao.getMtgCatalogCardCount();
        expect(count, equals(0));
      });

      test('counts only unowned MTG reference cards (quantity == 0, isDeleted == false)', () async {
        final items = [
          // 1. Valid MTG Catalog card (quantity 0, not deleted)
          VaultItemsCompanion.insert(
            id: 'mtg-cat-1',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'C21',
            imageUrl: 'https://example.com/sol_ring.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
          // 2. Valid MTG Catalog card (quantity 0, not deleted)
          VaultItemsCompanion.insert(
            id: 'mtg-cat-2',
            collectionType: 'mtg',
            name: 'Command Tower',
            setOrSeries: 'C21',
            imageUrl: 'https://example.com/command_tower.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 0.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
          // 3. Owned MTG card (quantity > 0) -> Should NOT count in catalog
          VaultItemsCompanion.insert(
            id: 'mtg-owned-1',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'LEA',
            imageUrl: 'https://example.com/lotus.jpg',
            acquiredPrice: 5000.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
          // 4. Soft-deleted MTG Catalog card -> Should NOT count
          VaultItemsCompanion.insert(
            id: 'mtg-deleted-1',
            collectionType: 'mtg',
            name: 'Deleted Card',
            setOrSeries: 'C21',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 1.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            isDeleted: const drift.Value(true),
          ),
          // 5. Pokemon Catalog card (collectionType != 'mtg') -> Should NOT count
          VaultItemsCompanion.insert(
            id: 'pkm-cat-1',
            collectionType: 'pokemon',
            name: 'Pikachu',
            setOrSeries: 'Base Set',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 15.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        ];

        for (final item in items) {
          await db.into(db.vaultItems).insert(item);
        }

        final count = await db.vaultDao.getMtgCatalogCardCount();
        expect(count, equals(2));
      });
    });

    group('CountrImageCacheManager.isImageCacheHealthy()', () {
      test('returns false when sample card art is not cached on disk', () async {
        final healthy = await CountrImageCacheManager.instance.isImageCacheHealthy(
          sampleCardIds: ['non-existent-card-id-1', 'non-existent-card-id-2'],
        );
        expect(healthy, isFalse);
      });

      test('returns true when sample card art file exists in disk cache', () async {
        final cacheManager = CountrImageCacheManager.instance;
        const testCardId = 'test-cached-card-healthy';
        final testKey = CountrImageCacheManager.cardArtKey(testCardId);

        // Put a fake file into cache
        final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        await cacheManager.putFile(
          'https://example.com/test_card.jpg',
          dummyBytes,
          key: testKey,
          fileExtension: 'jpg',
        );

        final healthy = await cacheManager.isImageCacheHealthy(
          sampleCardIds: [testCardId],
        );
        expect(healthy, isTrue);

        // Cleanup
        await cacheManager.removeFile(testKey);
      });
    });

    group('MtgAutoHydrationCoordinator Auto-Trigger & Recovery', () {
      test('triggers startHydration when catalog card count is below 100 in MTG context', () async {
        final mockHydrationCtrl = _MockTrackingHydrationController();

        final container = ProviderContainer(
          overrides: [
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            hydrationControllerProvider.overrideWith((ref) => mockHydrationCtrl),
          ],
        );

        final coordinator = container.read(mtgAutoHydrationCoordinatorProvider);
        await coordinator.checkAndTriggerAutoHydration();

        expect(mockHydrationCtrl.startHydrationCallCount, equals(1));
        container.dispose();
      });

      test('does not trigger startHydration when active game is not MTG unless force is true', () async {
        final mockHydrationCtrl = _MockTrackingHydrationController();

        final container = ProviderContainer(
          overrides: [
            activeGameContextProvider.overrideWith((ref) => 'Pokemon TCG'),
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            hydrationControllerProvider.overrideWith((ref) => mockHydrationCtrl),
          ],
        );

        final coordinator = container.read(mtgAutoHydrationCoordinatorProvider);

        // Active game is Pokemon -> should not trigger
        await coordinator.checkAndTriggerAutoHydration(force: false);
        expect(mockHydrationCtrl.startHydrationCallCount, equals(0));

        // When forced -> should trigger
        await coordinator.checkAndTriggerAutoHydration(force: true);
        expect(mockHydrationCtrl.startHydrationCallCount, equals(1));

        container.dispose();
      });

      test('does not trigger startHydration if hydration is already in progress', () async {
        final mockHydrationCtrl = _MockTrackingHydrationController(
          const HydrationState(status: HydrationStatus.downloading),
        );

        final container = ProviderContainer(
          overrides: [
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            hydrationControllerProvider.overrideWith((ref) => mockHydrationCtrl),
          ],
        );

        final coordinator = container.read(mtgAutoHydrationCoordinatorProvider);
        await coordinator.checkAndTriggerAutoHydration();

        expect(mockHydrationCtrl.startHydrationCallCount, equals(0));
        container.dispose();
      });

      test('does not trigger startHydration if catalog count is >= 100 and cache is healthy', () async {
        // Seed 100 catalog cards
        final bulkCatalog = List.generate(
          100,
          (i) => VaultItemsCompanion.insert(
            id: 'bulk-mtg-$i',
            collectionType: 'mtg',
            name: 'Bulk Card $i',
            setOrSeries: 'Set',
            imageUrl: 'https://example.com/art.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 1.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );
        await db.vaultDao.insertDictionaryBatch(bulkCatalog);

        // Pre-populate cache for all default sampleCardIds so cache check passes
        final cacheManager = CountrImageCacheManager.instance;
        final oneRingKey = CountrImageCacheManager.cardArtKey('item-mtg-one-ring');
        final edgarKey = CountrImageCacheManager.cardArtKey('edgar-markov');
        final edgarDeckKey = CountrImageCacheManager.cardArtKey('deck-edgar-markov');

        final sampleBytes = Uint8List.fromList([1, 2, 3]);
        await cacheManager.putFile('https://example.com/ring.jpg', sampleBytes, key: oneRingKey);
        await cacheManager.putFile('https://example.com/edgar.jpg', sampleBytes, key: edgarKey);
        await cacheManager.putFile('https://example.com/deck.jpg', sampleBytes, key: edgarDeckKey);

        final mockHydrationCtrl = _MockTrackingHydrationController();
        final container = ProviderContainer(
          overrides: [
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            hydrationControllerProvider.overrideWith((ref) => mockHydrationCtrl),
          ],
        );

        final coordinator = container.read(mtgAutoHydrationCoordinatorProvider);
        await coordinator.checkAndTriggerAutoHydration();

        // Since count is 100 and cache is healthy, it should NOT trigger hydration
        expect(mockHydrationCtrl.startHydrationCallCount, equals(0));

        // Cleanup
        await cacheManager.removeFile(oneRingKey);
        await cacheManager.removeFile(edgarKey);
        await cacheManager.removeFile(edgarDeckKey);
        container.dispose();
      });
    });
  });
}

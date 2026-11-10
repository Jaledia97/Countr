import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/card_image_and_data_cache_resolver.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

/// Configurable Fake Scryfall Service for adversarial failure simulation.
class AdversarialScryfallService extends ScryfallService {
  final Map<String, Map<String, dynamic>> mockCardsById;
  final Map<String, Map<String, dynamic>> mockCardsByName;
  bool shouldThrowSocketException;
  bool shouldThrowTimeoutException;
  bool shouldThrowHttpException;
  Completer<Map<String, dynamic>?>? networkCompleter;
  int fetchCallCount = 0;

  AdversarialScryfallService({
    this.mockCardsById = const {},
    this.mockCardsByName = const {},
    this.shouldThrowSocketException = false,
    this.shouldThrowTimeoutException = false,
    this.shouldThrowHttpException = false,
    this.networkCompleter,
  });

  @override
  Future<Map<String, dynamic>?> fetchCardDetails({
    String? scryfallId,
    String? name,
  }) async {
    fetchCallCount++;
    if (networkCompleter != null) {
      return networkCompleter!.future;
    }
    if (shouldThrowSocketException) {
      throw const SocketException('Connection refused: api.scryfall.com');
    }
    if (shouldThrowTimeoutException) {
      throw TimeoutException('Scryfall request timed out');
    }
    if (shouldThrowHttpException) {
      throw const HttpException('500 Internal Server Error');
    }

    if (scryfallId != null && mockCardsById.containsKey(scryfallId)) {
      return mockCardsById[scryfallId];
    }
    if (name != null) {
      final clean = name.contains('//')
          ? name.split('//').first.trim().toLowerCase()
          : name.trim().toLowerCase();
      for (final entry in mockCardsByName.entries) {
        if (entry.key.toLowerCase() == clean ||
            entry.key.toLowerCase() == name.trim().toLowerCase()) {
          return entry.value;
        }
      }
    }
    return null;
  }
}

VaultItemsCompanion makeCompanion({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'PRM',
  String imageUrl = '',
  String? flavorName,
  int quantity = 1,
  double currentMarketPrice = 0.0,
  String dynamicData = '{}',
  bool isDeleted = false,
}) {
  final now = DateTime.now();
  return VaultItemsCompanion.insert(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    flavorName: flavorName != null
        ? drift.Value(flavorName)
        : const drift.Value.absent(),
    acquiredPrice: 0.0,
    acquiredDate: now,
    quantity: drift.Value(quantity),
    condition: 'NM',
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: now,
    dynamicData: dynamicData,
    isDeleted: drift.Value(isDeleted),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir =
        Directory.systemTemp.createTempSync('countr_adversarial_cache_root_');
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

  late AppDatabase db;
  late VaultDao vaultDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = db.vaultDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial 1: Corrupted Card Data & Malformed DynamicData JSON Stress', () {
    test('Handles malformed and non-Map dynamicData strings without crashing',
        () async {
      final fakeScryfall = AdversarialScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final malformedPayloads = [
        '',
        '{}',
        'invalid json syntax {{{',
        '12345678',
        'true',
        'null',
        '[1, 2, 3]',
        '{"broken":',
        '{"scryfall_id": null, "oracle_id": null}',
        '{"oracle_text": null, "type_line": null}',
        '{"card_faces": "not-a-list", "oracle_text": ""}',
      ];

      for (int i = 0; i < malformedPayloads.length; i++) {
        final payload = malformedPayloads[i];
        final stubItem = VaultItem(
          id: 'corrupt-item-$i',
          collectionType: 'mtg',
          name: 'Corrupt Test Card $i',
          setOrSeries: 'TEST',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 0.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: payload,
        );

        // isCardComplete must return false and not throw
        expect(resolver.isCardComplete(stubItem), isFalse,
            reason: 'Payload "$payload" should not be complete');

        // resolveCardDataAndImage must return without unhandled exception
        final resolved = await resolver.resolveCardDataAndImage(stubItem);
        expect(resolved, isNotNull);
        expect(resolved.id, equals(stubItem.id));
      }
    });

    test('Synthetic UUID prefixes (12a34567, 722a3456) are NOT treated as valid Scryfall IDs',
        () async {
      final fakeScryfall = AdversarialScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      // Seed a unique catalog card with name "Imperial Seal" (not in db default seeds)
      const catalogScryfallId = 'c0260408-0f0c-4375-9e67-d842b109b85c';
      await db.into(db.vaultItems).insert(makeCompanion(
            id: catalogScryfallId,
            name: 'Imperial Seal',
            quantity: 0,
            imageUrl: 'https://cards.scryfall.io/normal/imperial-seal.jpg',
            currentMarketPrice: 120.0,
            dynamicData: jsonEncode({
              'id': catalogScryfallId,
              'oracle_id': 'oracle-imperial-seal',
              'name': 'Imperial Seal',
              'oracle_text': 'Search your library for a card, then shuffle and put that card on top.',
              'type_line': 'Sorcery',
              'mana_cost': '{B}',
            }),
          ));

      // Synthetic UUID used for test vaults
      const syntheticId = '12a34567-0000-0000-0000-000000000000';
      await db.into(db.vaultItems).insert(makeCompanion(
            id: syntheticId,
            name: 'Imperial Seal',
            quantity: 1,
            imageUrl: 'https://cards.scryfall.io/normal/12a34567-placeholder.jpg',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById(syntheticId))!;
      final repaired = await resolver.resolveCardDataAndImage(stub);

      // Should have resolved via name to the Imperial Seal catalog entry
      expect(repaired.imageUrl,
          equals('https://cards.scryfall.io/normal/imperial-seal.jpg'));
      expect(repaired.currentMarketPrice, equals(120.0));
      final dynamicData = jsonDecode(repaired.dynamicData);
      expect(dynamicData['oracle_text'], contains('Search your library'));
    });

    test('Non-UUID custom IDs and special SQL characters do not crash query engine',
        () async {
      final fakeScryfall = AdversarialScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final weirdCards = [
        'custom-id-#1234',
        "Card with 'single quotes'",
        'Lim-Dûl\'s Vault',
        'Kong // Godzilla',
        '   whitespace padded   ',
        'Special "Quotes" & <Tags>',
        '⚡ Lightning Bolt ⚡',
        "'; DROP TABLE vault_items; --",
      ];

      final countBefore = (await db.select(db.vaultItems).get()).length;

      for (int i = 0; i < weirdCards.length; i++) {
        final cardName = weirdCards[i];
        final id = 'weird-id-$i';
        await db.into(db.vaultItems).insert(makeCompanion(
              id: id,
              name: cardName,
              quantity: 1,
              dynamicData: '{}',
            ));

        final item = (await vaultDao.getItemById(id))!;
        final resolved = await resolver.resolveCardDataAndImage(item);
        expect(resolved, isNotNull);
        expect(resolved.id, equals(id));
      }

      // Verify database table still exists and is intact with exactly the inserted items added
      final allItems = await db.select(db.vaultItems).get();
      expect(allItems.length, equals(countBefore + weirdCards.length));
    });

    test('Preserves user customizations (cached_rulings, deck_history, personal_notes) during catalog backfill',
        () async {
      // Seed catalog card
      const scryfallId = '8093f10e-25c4-424a-af61-3368b3ab42f2';
      await db.into(db.vaultItems).insert(makeCompanion(
            id: scryfallId,
            name: 'Black Lotus',
            quantity: 0,
            imageUrl: 'https://cards.scryfall.io/normal/black-lotus.jpg',
            currentMarketPrice: 20000.0,
            dynamicData: jsonEncode({
              'id': scryfallId,
              'oracle_id': 'oracle-black-lotus',
              'name': 'Black Lotus',
              'oracle_text': '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
              'type_line': 'Artifact',
              'mana_cost': '{0}',
            }),
          ));

      // User card with custom notes and deck history
      const userCardId = 'user-prized-lotus';
      final userDynamicData = jsonEncode({
        'scryfall_id': scryfallId,
        'cached_rulings': [{'comment': 'Sacrifice is part of the cost.'}],
        'deck_history': ['Vintage Storm', 'Cube Draft 2026'],
        'personal_notes': 'Gifted by grandfather in 1995.',
      });

      await db.into(db.vaultItems).insert(makeCompanion(
            id: userCardId,
            name: 'Black Lotus',
            quantity: 1,
            imageUrl: '',
            dynamicData: userDynamicData,
          ));

      final stub = (await vaultDao.getItemById(userCardId))!;
      final fakeScryfall = AdversarialScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final repaired = await resolver.resolveCardDataAndImage(stub);

      // Verify Oracle text and photo were backfilled
      expect(repaired.imageUrl,
          equals('https://cards.scryfall.io/normal/black-lotus.jpg'));
      expect(repaired.currentMarketPrice, equals(20000.0));

      // Verify user customizations were preserved
      final mergedData = jsonDecode(repaired.dynamicData) as Map<String, dynamic>;
      expect(mergedData['oracle_text'], contains('Sacrifice Black Lotus'));
      expect(mergedData['personal_notes'], equals('Gifted by grandfather in 1995.'));
      expect(mergedData['deck_history'], equals(['Vintage Storm', 'Cube Draft 2026']));
      expect(mergedData['cached_rulings'], isNotEmpty);
    });
  });

  group('Adversarial 2: Offline Simulation & Network Error Handling', () {
    test('Recovers gracefully when Scryfall throws SocketException (offline/airplane mode)',
        () async {
      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'item-airplane-mode',
            name: 'Urza\'s Saga',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById('item-airplane-mode'))!;
      final fakeScryfall = AdversarialScryfallService(
        shouldThrowSocketException: true,
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final result = await resolver.resolveCardDataAndImage(stub);

      // Returned without crashing
      expect(result.id, equals('item-airplane-mode'));
      expect(result.name, equals('Urza\'s Saga'));
      expect(fakeScryfall.fetchCallCount, equals(1));
    });

    test('Recovers gracefully when Scryfall throws TimeoutException',
        () async {
      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'item-timeout',
            name: 'Ragavan, Nimble Pilferer',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById('item-timeout'))!;
      final fakeScryfall = AdversarialScryfallService(
        shouldThrowTimeoutException: true,
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final result = await resolver.resolveCardDataAndImage(stub);
      expect(result.id, equals('item-timeout'));
    });

    test('Recovers gracefully when Scryfall throws HttpException (500 Server Error)',
        () async {
      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'item-server-error',
            name: 'Mox Diamond',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById('item-server-error'))!;
      final fakeScryfall = AdversarialScryfallService(
        shouldThrowHttpException: true,
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final result = await resolver.resolveCardDataAndImage(stub);
      expect(result.id, equals('item-server-error'));
    });

    test('resolveVariantImageUrl returns null cleanly without crashing on network exceptions',
        () async {
      final fakeScryfall = AdversarialScryfallService(
        shouldThrowSocketException: true,
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final url = await resolver.resolveVariantImageUrl(
          scryfallId: 'non-existent-offline-variant-id');
      expect(url, isNull);
    });
  });

  group('Adversarial 3: Local Catalog Search Priorities & art_series Exclusion', () {
    test('Strict Priority: scryfallId takes precedence over oracleId and name',
        () async {
      // Seed 2 conflicting cards:
      // Card A: id = 'scry-alpha', oracle = 'oracle-shared', name = 'Target Name'
      // Card B: id = 'scry-beta', oracle = 'oracle-unique-b', name = 'Target Name'
      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'scry-alpha',
            name: 'Alpha Printing',
            quantity: 0,
            imageUrl: 'https://example.com/alpha.jpg',
            dynamicData: jsonEncode({
              'id': 'scry-alpha',
              'oracle_id': 'oracle-shared',
              'name': 'Alpha Printing',
              'oracle_text': 'Alpha oracle text',
              'type_line': 'Artifact',
              'layout': 'normal',
            }),
          ));

      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'scry-beta',
            name: 'Beta Printing',
            quantity: 0,
            imageUrl: 'https://example.com/beta.jpg',
            dynamicData: jsonEncode({
              'id': 'scry-beta',
              'oracle_id': 'oracle-shared',
              'name': 'Beta Printing',
              'oracle_text': 'Beta oracle text',
              'type_line': 'Artifact',
              'layout': 'normal',
            }),
          ));

      // Query specifically by scryfallId = 'scry-alpha' while providing oracle_id that matches both
      final match = await vaultDao.findCatalogCard(
        scryfallId: 'scry-alpha',
        oracleId: 'oracle-shared',
        name: 'Beta Printing',
      );

      expect(match, isNotNull);
      expect(match!.id, equals('scry-alpha'));
      expect(match.name, equals('Alpha Printing'));
    });

    test('Strict Priority: oracleId takes precedence over name when scryfallId differs',
        () async {
      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'scry-gamma',
            name: 'Gamma Card',
            quantity: 0,
            imageUrl: 'https://example.com/gamma.jpg',
            dynamicData: jsonEncode({
              'id': 'scry-gamma',
              'oracle_id': 'oracle-exact-match',
              'name': 'Gamma Card',
              'oracle_text': 'Gamma rules text',
              'type_line': 'Instant',
              'layout': 'normal',
            }),
          ));

      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'scry-delta',
            name: 'Delta Card',
            quantity: 0,
            imageUrl: 'https://example.com/delta.jpg',
            dynamicData: jsonEncode({
              'id': 'scry-delta',
              'oracle_id': 'oracle-different',
              'name': 'Delta Card',
              'oracle_text': 'Delta rules text',
              'type_line': 'Sorcery',
              'layout': 'normal',
            }),
          ));

      // Search with non-matching scryfallId, matching oracleId for Gamma, and name for Delta
      final match = await vaultDao.findCatalogCard(
        scryfallId: 'scryfall-id-not-in-db',
        oracleId: 'oracle-exact-match',
        name: 'Delta Card',
      );

      expect(match, isNotNull);
      expect(match!.id, equals('scry-gamma'));
      expect(match.name, equals('Gamma Card'));
    });

    test('Art Series cards (layout == art_series) are strictly excluded from catalog matches',
        () async {
      const artSeriesScryfallId = 'art-series-rhystic-study';
      const normalScryfallId = 'normal-playable-rhystic-study';

      // Insert art_series card
      await db.into(db.vaultItems).insert(makeCompanion(
            id: artSeriesScryfallId,
            name: 'Rhystic Study',
            quantity: 0,
            imageUrl: 'https://example.com/art-series.jpg',
            dynamicData: jsonEncode({
              'id': artSeriesScryfallId,
              'oracle_id': 'oracle-rhystic',
              'name': 'Rhystic Study',
              'layout': 'art_series',
              'oracle_text': '',
              'type_line': 'Card // Art',
            }),
          ));

      // Insert playable normal card
      await db.into(db.vaultItems).insert(makeCompanion(
            id: normalScryfallId,
            name: 'Rhystic Study',
            quantity: 0,
            imageUrl: 'https://example.com/playable.jpg',
            dynamicData: jsonEncode({
              'id': normalScryfallId,
              'oracle_id': 'oracle-rhystic',
              'name': 'Rhystic Study',
              'layout': 'normal',
              'oracle_text': 'Whenever an opponent casts a spell...',
              'type_line': 'Enchantment',
            }),
          ));

      // Query by name
      final matchByName = await vaultDao.findCatalogCard(name: 'Rhystic Study');
      expect(matchByName, isNotNull);
      expect(matchByName!.id, equals(normalScryfallId));

      // Query by scryfallId targeting the art_series card directly
      final matchArtSeriesId = await vaultDao.findCatalogCard(scryfallId: artSeriesScryfallId);
      // Must be excluded!
      expect(matchArtSeriesId, isNull);

      // Query by oracleId: must return playable card, never art_series
      final matchByOracle = await vaultDao.findCatalogCard(oracleId: 'oracle-rhystic');
      expect(matchByOracle, isNotNull);
      expect(matchByOracle!.id, equals(normalScryfallId));
    });

    test('Soft-deleted items (is_deleted = 1) are never returned by findCatalogCard',
        () async {
      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'deleted-scryfall-card',
            name: 'Mana Vault',
            quantity: 0,
            imageUrl: 'https://example.com/mana-vault.jpg',
            isDeleted: true,
            dynamicData: jsonEncode({
              'id': 'deleted-scryfall-card',
              'oracle_id': 'oracle-mana-vault',
              'name': 'Mana Vault',
              'layout': 'normal',
              'oracle_text': '{T}: Add {C}{C}{C}.',
            }),
          ));

      final match = await vaultDao.findCatalogCard(
        scryfallId: 'deleted-scryfall-card',
        oracleId: 'oracle-mana-vault',
        name: 'Mana Vault',
      );

      expect(match, isNull);
    });

    test('Double-faced cards match across split slash formats (//)',
        () async {
      // Seed catalog card with front face name
      await db.into(db.vaultItems).insert(makeCompanion(
            id: 'dfc-delver-scryfall',
            name: 'Delver of Secrets',
            quantity: 0,
            imageUrl: 'https://example.com/delver.jpg',
            dynamicData: jsonEncode({
              'id': 'dfc-delver-scryfall',
              'oracle_id': 'oracle-delver',
              'name': 'Delver of Secrets',
              'layout': 'transform',
              'card_faces': [
                {'name': 'Delver of Secrets', 'oracle_text': 'At the beginning...'},
                {'name': 'Insectile Aberration', 'oracle_text': 'Flying'},
              ],
            }),
          ));

      // Match using full DFC name with //
      final matchFull = await vaultDao.findCatalogCard(
          name: 'Delver of Secrets // Insectile Aberration');
      expect(matchFull, isNotNull);
      expect(matchFull!.id, equals('dfc-delver-scryfall'));

      // Match using exact front face name
      final matchFront = await vaultDao.findCatalogCard(name: 'Delver of Secrets');
      expect(matchFront, isNotNull);
      expect(matchFront!.id, equals('dfc-delver-scryfall'));
    });
  });

  group('Adversarial 4: Concurrency & Race Condition Stress', () {
    test('Thundering Herd: 25 simultaneous concurrent calls resolving the SAME stub card',
        () async {
      const targetCardId = 'stub-thundering-herd-rhystic';
      await db.into(db.vaultItems).insert(makeCompanion(
            id: targetCardId,
            name: 'Rhystic Study',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final scryfallPayload = {
        'id': 'scryfall-thundering-herd-rhystic',
        'oracle_id': 'oracle-thundering-rhystic',
        'name': 'Rhystic Study',
        'mana_cost': '{2}{U}',
        'type_line': 'Enchantment',
        'oracle_text': 'Whenever an opponent casts a spell...',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/rhystic-herd.jpg',
        },
        'prices': {'usd': '45.00'},
      };

      final fakeScryfall = AdversarialScryfallService(
        mockCardsByName: {'Rhystic Study': scryfallPayload},
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final stub = (await vaultDao.getItemById(targetCardId))!;

      // Dispatch 25 concurrent resolution requests for the exact same card
      final futures = List.generate(25, (_) => resolver.resolveCardDataAndImage(stub));
      final results = await Future.wait(futures);

      expect(results.length, equals(25));
      for (final res in results) {
        expect(res.imageUrl, equals('https://cards.scryfall.io/normal/rhystic-herd.jpg'));
        expect(res.currentMarketPrice, equals(45.00));
        final data = jsonDecode(res.dynamicData);
        expect(data['type_line'], equals('Enchantment'));
      }

      // Verify database has exactly 1 catalog entry and 1 user entry without corrupt duplication
      final catalogRows = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('scryfall-thundering-herd-rhystic')))
          .get();
      expect(catalogRows.length, equals(1));
      expect(catalogRows.first.quantity, equals(0));

      final userRows = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals(targetCardId)))
          .get();
      expect(userRows.length, equals(1));
      expect(userRows.first.quantity, equals(1));
    });

    test('High Concurrency: 50 distinct stub cards resolving in parallel',
        () async {
      final fakeCards = <String, Map<String, dynamic>>{};
      final insertedIds = <String>[];
      for (int i = 0; i < 50; i++) {
        final cardName = 'Parallel Card $i';
        final scryId = 'parallel-scry-$i';
        fakeCards[cardName] = {
          'id': scryId,
          'oracle_id': 'oracle-parallel-$i',
          'name': cardName,
          'mana_cost': '{$i}',
          'type_line': 'Artifact Creature',
          'oracle_text': 'Parallel abilities $i',
          'image_uris': {'normal': 'https://cards.scryfall.io/normal/card-$i.jpg'},
          'prices': {'usd': '$i.50'},
        };

        final userId = 'user-parallel-$i';
        insertedIds.add(userId);
        await db.into(db.vaultItems).insert(makeCompanion(
              id: userId,
              name: cardName,
              quantity: 1,
              imageUrl: '',
              dynamicData: '{}',
            ));
      }

      final fakeScryfall = AdversarialScryfallService(
        mockCardsByName: fakeCards,
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      // Collect the 50 inserted items
      final allItems = await (db.select(db.vaultItems)
            ..where((t) => t.id.isIn(insertedIds)))
          .get();
      expect(allItems.length, equals(50));

      // Resolve all 50 simultaneously
      final resolvedList = await Future.wait(
        allItems.map((item) => resolver.resolveCardDataAndImage(item)),
      );

      expect(resolvedList.length, equals(50));
      for (int i = 0; i < 50; i++) {
        final resolved = resolvedList.firstWhere((r) => r.name == 'Parallel Card $i');
        expect(resolved.imageUrl, equals('https://cards.scryfall.io/normal/card-$i.jpg'));
        final data = jsonDecode(resolved.dynamicData);
        expect(data['type_line'], equals('Artifact Creature'));
      }
    });

    test('Concurrent resolveVariantImageUrl calls with mixed cache hits and misses',
        () async {
      // Seed 5 variants in catalog
      for (int i = 0; i < 5; i++) {
        await db.into(db.vaultItems).insert(makeCompanion(
              id: 'cached-variant-$i',
              name: 'Variant Card $i',
              quantity: 0,
              imageUrl: 'https://cards.scryfall.io/normal/variant-$i.jpg',
              dynamicData: jsonEncode({
                'id': 'cached-variant-$i',
                'name': 'Variant Card $i',
                'layout': 'normal',
                'oracle_text': 'Text $i',
              }),
            ));
      }

      final fakeRemoteVariants = <String, Map<String, dynamic>>{};
      for (int i = 5; i < 10; i++) {
        fakeRemoteVariants['remote-variant-$i'] = {
          'id': 'remote-variant-$i',
          'name': 'Remote Variant Card $i',
          'image_uris': {'normal': 'https://cards.scryfall.io/normal/remote-$i.jpg'},
        };
      }

      final fakeScryfall = AdversarialScryfallService(
        mockCardsById: fakeRemoteVariants,
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      // 20 concurrent variant lookups (mix of cached, remote, and non-existent)
      final requests = <Future<String?>>[];
      for (int i = 0; i < 5; i++) {
        requests.add(resolver.resolveVariantImageUrl(scryfallId: 'cached-variant-$i'));
      }
      for (int i = 5; i < 10; i++) {
        requests.add(resolver.resolveVariantImageUrl(scryfallId: 'remote-variant-$i'));
      }
      for (int i = 10; i < 20; i++) {
        requests.add(resolver.resolveVariantImageUrl(scryfallId: 'missing-variant-$i'));
      }

      final results = await Future.wait(requests);
      expect(results.length, equals(20));

      for (int i = 0; i < 5; i++) {
        expect(results[i], equals('https://cards.scryfall.io/normal/variant-$i.jpg'));
      }
      for (int i = 5; i < 10; i++) {
        expect(results[i], equals('https://cards.scryfall.io/normal/remote-$i.jpg'));
      }
      for (int i = 10; i < 20; i++) {
        expect(results[i], isNull);
      }
    });
  });

  group('Adversarial 5: Decoupled Description Rendering & Slow Image Load Stress', () {
    testWidgets(
        'CardDetailSheet displays full description immediately even with slow network latency',
        (tester) async {
      final cardItem = VaultItem(
        id: 'item-slow-network-decoupled',
        collectionType: 'mtg',
        name: 'The One Ring',
        setOrSeries: 'LTR',
        imageUrl: '', // missing image
        acquiredPrice: 75.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 75.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'oracle_text': 'Indestructible\nWhen The One Ring enters the battlefield, if you cast it, you gain protection from everything until your next turn.',
          'type_line': 'Legendary Artifact',
          'mana_cost': '{4}',
          'rarity': 'Mythic Rare',
        }),
      );

      final completer = Completer<Map<String, dynamic>?>();
      final fakeScryfall = AdversarialScryfallService(
        networkCompleter: completer,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            scryfallServiceProvider.overrideWithValue(fakeScryfall),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: cardItem,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );

      // Single initial pump: Oracle text must be present immediately while network is pending
      await tester.pump();

      expect(find.text('Oracle Rules Text'), findsOneWidget);
      expect(find.textContaining('protection from everything'), findsOneWidget);
      expect(find.text('Legendary Artifact'), findsOneWidget);

      // Complete network fetch to cleanly unwind background future
      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Double-faced card flips Oracle text immediately without image dependency',
        (tester) async {
      final dfcCard = VaultItem(
        id: 'item-dfc-fable',
        collectionType: 'mtg',
        name: 'Fable of the Mirror-Breaker // Reflection of Kiki-Jiki',
        setOrSeries: 'NEO',
        imageUrl: '',
        acquiredPrice: 20.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 20.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'card_faces': [
            {
              'name': 'Fable of the Mirror-Breaker',
              'mana_cost': '{2}{R}',
              'type_line': 'Enchantment — Saga',
              'oracle_text': '(As this Saga enters and after your draw step, add a lore counter.)',
            },
            {
              'name': 'Reflection of Kiki-Jiki',
              'mana_cost': '',
              'type_line': 'Enchantment Creature — Goblin Shaman',
              'oracle_text': '{1}, {T}: Create a token that\'s a copy of another target nonlegendary creature you control.',
            }
          ],
          'oracle_text': '(As this Saga enters...) // {1}, {T}: Create a token...',
          'type_line': 'Enchantment — Saga // Enchantment Creature',
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: dfcCard,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Front face rules text is visible
      expect(find.text('Oracle Rules Text'), findsOneWidget);
      expect(find.textContaining('As this Saga enters'), findsOneWidget);
    });
  });
}

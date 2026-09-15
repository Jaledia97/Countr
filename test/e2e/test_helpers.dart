import 'package:camera/camera.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Creates a mock [TextBlock] with the given bounding box and optional text.
TextBlock createMockTextBlock(
  Rect boundingBox, {
  String text = 'Sample Card Title',
}) {
  return TextBlock(
    text: text,
    lines: const [],
    boundingBox: boundingBox,
    recognizedLanguages: const [],
    cornerPoints: const [],
  );
}

/// Creates a lightweight mock [CameraImage] suitable for passing to scanner frame processing.
/// Lightweight mock [CameraImage] for testing frame skipping and lock behavior.
class FakeCameraImage implements CameraImage {
  @override
  final int width;
  @override
  final int height;

  FakeCameraImage({this.width = 720, this.height = 1280});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CameraImage createMockCameraImage({int width = 720, int height = 1280}) {
  return FakeCameraImage(width: width, height: height);
}

/// Instantiates an isolated in-memory [AppDatabase] for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Helper method to create standard test cards.
VaultItem createTestCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'Core Set',
  double acquiredPrice = 10.0,
  double currentMarketPrice = 15.0,
  int quantity = 0,
  String condition = 'NM',
  String? collectorNumber,
  String? primaryBinderId,
  String dynamicData = '{}',
}) {
  final data = collectorNumber != null && !dynamicData.contains('collector_number')
      ? '{"collector_number":"$collectorNumber"}'
      : dynamicData;

  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: 'https://example.com/cards/$id.jpg',
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime.now(),
    quantity: quantity,
    condition: condition,
    isGraded: false,
    personalNotes: null,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime.now(),
    dynamicData: data,
    primaryBinderId: primaryBinderId,
  );
}

/// Seeds standard multi-collection test fixture cards into the database.
Future<void> seedComprehensiveTestCatalog(VaultDao dao) async {
  await dao.clearAllItems();
  final cards = [
    // MTG Catalog Cards (quantity == 0)
    createTestCard(
      id: 'mtg-lotus',
      name: 'Black Lotus',
      collectionType: 'mtg',
      setOrSeries: 'Vintage Masters',
      acquiredPrice: 5000.0,
      currentMarketPrice: 5500.0,
      quantity: 0,
      collectorNumber: '232',
    ),
    createTestCard(
      id: 'mtg-sol-ring',
      name: 'Sol Ring',
      collectionType: 'mtg',
      setOrSeries: 'Commander',
      acquiredPrice: 1.5,
      currentMarketPrice: 2.0,
      quantity: 0,
      collectorNumber: '101',
    ),
    createTestCard(
      id: 'mtg-urza-saga',
      name: "Urza's Saga",
      collectionType: 'mtg',
      setOrSeries: 'Modern Horizons 2',
      acquiredPrice: 35.0,
      currentMarketPrice: 40.0,
      quantity: 0,
      collectorNumber: '259',
    ),
    createTestCard(
      id: 'mtg-force-will',
      name: 'Force of Will',
      collectionType: 'mtg',
      setOrSeries: 'Alliances',
      acquiredPrice: 90.0,
      currentMarketPrice: 100.0,
      quantity: 0,
      collectorNumber: '042',
    ),
    createTestCard(
      id: 'mtg-split-fire-ice',
      name: 'Fire // Ice',
      collectionType: 'mtg',
      setOrSeries: 'Apocalypse',
      acquiredPrice: 2.0,
      currentMarketPrice: 3.5,
      quantity: 0,
      collectorNumber: '128',
    ),

    // Pokémon Catalog Cards (quantity == 0)
    createTestCard(
      id: 'pkm-charizard-ex',
      name: 'Charizard ex',
      collectionType: 'pokemon',
      setOrSeries: 'Obsidian Flames',
      acquiredPrice: 40.0,
      currentMarketPrice: 45.0,
      quantity: 0,
      collectorNumber: '125',
    ),
    createTestCard(
      id: 'pkm-pikachu',
      name: 'Pikachu',
      collectionType: 'pokemon',
      setOrSeries: 'Base Set',
      acquiredPrice: 25.0,
      currentMarketPrice: 30.0,
      quantity: 0,
      collectorNumber: '25',
    ),

    // One Piece / Other
    createTestCard(
      id: 'op-luffy',
      name: 'Monkey D. Luffy',
      collectionType: 'onepiece',
      setOrSeries: 'Romance Dawn',
      acquiredPrice: 12.0,
      currentMarketPrice: 15.0,
      quantity: 0,
      collectorNumber: '001',
    ),
  ];

  for (final c in cards) {
    await dao.into(dao.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: c.id,
            collectionType: c.collectionType,
            name: c.name,
            setOrSeries: c.setOrSeries,
            imageUrl: c.imageUrl,
            acquiredPrice: c.acquiredPrice,
            acquiredDate: c.acquiredDate,
            quantity: drift.Value(c.quantity),
            condition: c.condition,
            isGraded: drift.Value(c.isGraded),
            personalNotes: drift.Value(c.personalNotes),
            currentMarketPrice: c.currentMarketPrice,
            lastPriceUpdate: c.lastPriceUpdate,
            dynamicData: c.dynamicData,
            primaryBinderId: drift.Value(c.primaryBinderId),
          ),
        );
  }
}

/// Helper method to safely delete a single item from the database.
/// Supports both direct DAO method (when present) and fallback Drift query.
Future<int> deleteVaultItem(VaultDao dao, String id) async {
  try {
    return await (dao as dynamic).deleteItem(id) as int;
  } catch (_) {
    return (dao.delete(dao.vaultItems)..where((t) => t.id.equals(id))).go();
  }
}

/// Helper method to safely delete multiple items from the database in bulk.
/// Supports both direct DAO method (when present) and fallback Drift query.
Future<int> deleteVaultItems(VaultDao dao, List<String> ids) async {
  try {
    return await (dao as dynamic).deleteItems(ids) as int;
  } catch (_) {
    return (dao.delete(dao.vaultItems)..where((t) => t.id.isIn(ids))).go();
  }
}

/// Stages a card into the Inbox holding area with optional explicit binder tag.
Future<void> stageCardToInbox(
  VaultDao dao,
  VaultItem card, {
  bool isFoil = false,
  String binderId = 'INBOX',
}) async {
  await dao.upsertScannedCardToInbox(card, isFoil: isFoil);
  // Defensively ensure primary_binder_id is set to binderId
  await (dao.update(dao.vaultItems)..where((t) => t.id.equals(card.id))).write(
    VaultItemsCompanion(primaryBinderId: drift.Value(binderId)),
  );
}

/// Wrapper for building test widgets with full Riverpod ProviderScope and in-memory DB.
Widget createE2ETestHarness({
  required Widget child,
  required AppDatabase db,
  String activeGame = 'All Collections',
  List<Override> additionalOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      activeGameContextProvider.overrideWith((ref) => activeGame),
      ...additionalOverrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

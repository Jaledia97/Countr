import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/domain/legality_enforcer.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:uuid/uuid.dart';

/// In-memory isolated database instance for Phase 4.6 E2E tests.
AppDatabase createPhase46TestDb() {
  return AppDatabase(NativeDatabase.memory());
}

/// Backward-compatible alias pointing directly to production CardAvailability domain model.
typedef Phase46CardAvailability = CardAvailability;

/// Helper method to create standard test cards with comprehensive Scryfall metadata.
VaultItem createPhase46TestCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'LTR',
  String? scryfallId,
  String? oracleId,
  String? finish,
  String? imageUrl,
  double acquiredPrice = 10.0,
  double currentMarketPrice = 15.0,
  int quantity = 1,
  String condition = 'NM',
  String? manaCost,
  double? cmc,
  String typeLine = 'Artifact',
  String oracleText = '',
  Map<String, String>? legalities,
  Map<String, dynamic>? additionalDynamicData,
}) {
  final effectiveScryfallId = scryfallId ?? id;
  final effectiveOracleId = oracleId ?? 'oracle-$id';
  final effectiveFinish = finish ??
      (condition.toLowerCase().contains('etched')
          ? 'etched'
          : condition.toLowerCase().contains('foil')
              ? 'foil'
              : 'nonfoil');

  final defaultLegalities = legalities ??
      {
        'commander': 'legal',
        'modern': 'legal',
        'standard': 'legal',
        'legacy': 'legal',
        'vintage': 'legal',
        'pauper': 'not_legal',
      };

  final dynamicMap = <String, dynamic>{
    'scryfall_id': effectiveScryfallId,
    'oracle_id': effectiveOracleId,
    'finish': effectiveFinish,
    'finishes': [effectiveFinish],
    'type_line': typeLine,
    'oracle_text': oracleText,
    'legalities': defaultLegalities,
    'image_uris': {
      'normal': imageUrl ??
          'https://cards.scryfall.io/normal/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
      'large': imageUrl ??
          'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
      'art_crop': imageUrl ??
          'https://cards.scryfall.io/art_crop/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
    },
  };

  if (manaCost != null) {
    dynamicMap['mana_cost'] = manaCost;
  }
  if (cmc != null) {
    dynamicMap['cmc'] = cmc;
  }
  if (additionalDynamicData != null) {
    dynamicMap.addAll(additionalDynamicData);
  }

  final defaultImage = imageUrl ??
      'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038';

  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: defaultImage,
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime.now(),
    quantity: quantity,
    condition: condition,
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    personalNotes: null,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime.now(),
    dynamicData: jsonEncode(dynamicMap),
    primaryBinderId: null,
    isDeleted: false,
    updatedAt: null,
  );
}

/// Resolves the canonical grouping key (scryfall_id, finish) for a VaultItem via production VaultVariantHelper.
String resolveVariantGroupingKey(VaultItem item) {
  final printingId = VaultVariantHelper.resolvePrintingId(item);
  final finish = VaultVariantHelper.resolveFinish(item);
  return '${printingId}_$finish';
}

/// Groups a list of VaultItems strictly by (scryfall_id, finish).
Map<String, List<VaultItem>> groupVaultItemsByVariant(List<VaultItem> items) {
  final grouped = <String, List<VaultItem>>{};
  for (final item in items) {
    final key = resolveVariantGroupingKey(item);
    grouped.putIfAbsent(key, () => []).add(item);
  }
  return grouped;
}

/// Computes the total quantity for a variant bucket.
int computeVariantQuantity(List<VaultItem> variantItems) {
  return variantItems.fold<int>(0, (sum, i) => sum + i.quantity);
}

/// Computes physical card availability directly via production VaultDao.watchAllCardAvailability.
Future<CardAvailability> calculateItemAvailability(
  AppDatabase db,
  String vaultItemId,
) async {
  final availabilityMap = await db.vaultDao.watchAllCardAvailability().first;
  return availabilityMap[vaultItemId] ?? CardAvailability.zero;
}

/// Watches active assembled deck badges directly via production VaultDao.watchItemActiveDecks.
Stream<List<String>> watchAssembledDeckBadges(AppDatabase db, String vaultItemId) {
  return db.vaultDao.watchItemActiveDecks(vaultItemId);
}

/// Helper method to create and insert a deck into the database.
Future<Deck> createAndInsertDeck(
  AppDatabase db, {
  required String id,
  required String name,
  String format = 'Commander',
  bool isRegistered = false,
  bool isCompetitive = false,
  String? coverItemId,
  String? description,
}) async {
  final now = DateTime.now();
  await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: id,
          name: name,
          format: format,
          isRegistered: drift.Value(isRegistered),
          isCompetitive: drift.Value(isCompetitive),
          coverItemId: drift.Value(coverItemId),
          description: drift.Value(description),
          createdAt: now,
          tcgDomain: const drift.Value('mtg'),
          isDeleted: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );

  // Automatically create active DeckVersion
  final versionId = 'ver-$id-1';
  await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: id,
          versionNumber: 1,
          isActive: const drift.Value(true),
          createdAt: now,
          isDeleted: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );

  return (db.select(db.decks)..where((t) => t.id.equals(id))).getSingle();
}

/// Helper method to add a card to a deck version with specified board zone.
Future<DeckVersionItem> addCardToDeckZone(
  AppDatabase db, {
  required String deckId,
  required String vaultItemId,
  int quantity = 1,
  String boardZone = 'Mainboard',
  bool isProxy = false,
}) async {
  final version = await (db.select(db.deckVersions)
        ..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true) & t.isDeleted.equals(false)))
      .getSingle();

  final dviId = const Uuid().v4();
  final now = DateTime.now();

  await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: dviId,
          versionId: version.id,
          vaultItemId: vaultItemId,
          quantity: drift.Value(quantity),
          boardZone: boardZone,
          isProxy: drift.Value(isProxy),
          isDeleted: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );

  return (db.select(db.deckVersionItems)..where((t) => t.id.equals(dviId))).getSingle();
}

/// Move a card between board zones in a deck directly via production VaultDao.moveDeckItemBoard.
Future<void> moveCardBetweenZones(
  AppDatabase db, {
  required String deckId,
  required String vaultItemId,
  required String fromZone,
  required String toZone,
  int quantity = 1,
}) async {
  if (quantity <= 0) return;
  await db.vaultDao.moveDeckItemBoard(
    deckId,
    vaultItemId,
    toZone,
    quantity,
    fromZone,
  );
}

/// Evaluates legality for a single card in a format.
LegalityResult checkCardLegalityDirect(VaultItem item, String format) {
  if (item.dynamicData.isEmpty) {
    return LegalityResult(true, []);
  }
  try {
    final data = jsonDecode(item.dynamicData) as Map<String, dynamic>;
    final legalities = data['legalities'] as Map<String, dynamic>?;
    if (legalities != null) {
      final status = legalities[format.toLowerCase()];
      if (status != 'legal' && status != 'restricted') {
        return LegalityResult(
          false,
          ['${item.name} is not legal in $format (Status: $status)'],
        );
      }
    }
  } catch (_) {}
  return LegalityResult(true, []);
}

/// Calculates accurate CMC from mana cost or symbol strings.
/// Supports split cards, hybrid, twobrid, and numeric generic costs.
double calculateAccurateCmc(String? manaCost, {double? fallbackCmc}) {
  if (manaCost == null || manaCost.isEmpty) {
    return fallbackCmc ?? 0.0;
  }

  // Split cards e.g. "{1}{R} // {1}{U}"
  if (manaCost.contains('//')) {
    final faces = manaCost.split('//');
    double sum = 0.0;
    for (final face in faces) {
      final faceTrimmed = face.trim();
      final val = ScryfallSymbolCatalog.calculateManaValue(faceTrimmed);
      sum += val ?? 0.0;
    }
    return sum;
  }

  final parsed = ScryfallSymbolCatalog.calculateManaValue(manaCost);
  if (parsed != null) return parsed;
  return fallbackCmc ?? 0.0;
}

/// Builds Mana Curve histogram from a collection of cards.
Map<int, int> computeDeckManaCurve(List<Map<String, dynamic>> items) {
  final curve = <int, int>{};
  for (final item in items) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final dynamicStr = item['dynamic_data'] as String?;
    double cmc = 0.0;
    if (dynamicStr != null && dynamicStr.isNotEmpty) {
      try {
        final data = jsonDecode(dynamicStr) as Map<String, dynamic>;
        final manaCost = data['mana_cost'] as String?;
        final fallback = (data['cmc'] as num?)?.toDouble();
        cmc = calculateAccurateCmc(manaCost, fallbackCmc: fallback);
      } catch (_) {}
    }
    final cmcBucket = cmc.toInt();
    curve[cmcBucket] = (curve[cmcBucket] ?? 0) + qty;
  }
  return curve;
}

/// Test harness wrapper providing MaterialApp, ProviderScope, and DB bindings.
Widget buildPhase46TestHarness({
  required Widget child,
  required AppDatabase db,
  String activeGame = 'Magic: The Gathering',
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      activeGameContextProvider.overrideWith((ref) => activeGame),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );
}

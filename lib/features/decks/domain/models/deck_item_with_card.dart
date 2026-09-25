import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';
import 'package:countr/features/values/domain/services/trimmed_average_calculator.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Strongly-typed domain model representing a joined deck version item and physical vault item.
///
/// Extends [MapView<String, dynamic>] to ensure 100% backward compatibility across all
/// legacy callers and test harnesses that access fields via map indexing (`item['name']`).
@immutable
class DeckItemWithCard extends MapView<String, dynamic> {
  // --- Deck Version Item Fields ---
  final String dviId;
  final String versionId;
  final String vaultItemId;
  final int deckQuantity;
  final String boardZone;
  final bool isProxy;

  // --- Vault Item Provenance & Metadata ---
  final String id;
  final String name;
  final String setOrSeries;
  final String? imageUrl;
  final String? dynamicData;
  final double currentMarketPrice;
  final int vaultQuantity;
  final bool isGraded;
  final String condition;
  final double acquiredPrice;
  final double? purchasePrice;
  final DateTime? acquiredDate;
  final DateTime? dateObtained;
  final String? notes;
  final String protectionStatus;

  const DeckItemWithCard._(
    super.raw, {
    required this.dviId,
    required this.versionId,
    required this.vaultItemId,
    required this.deckQuantity,
    required this.boardZone,
    required this.isProxy,
    required this.id,
    required this.name,
    required this.setOrSeries,
    this.imageUrl,
    this.dynamicData,
    required this.currentMarketPrice,
    required this.vaultQuantity,
    required this.isGraded,
    required this.condition,
    required this.acquiredPrice,
    this.purchasePrice,
    this.acquiredDate,
    this.dateObtained,
    this.notes,
    required this.protectionStatus,
  });

  /// Defensive factory constructing [DeckItemWithCard] from SQLite row data or mock maps.
  factory DeckItemWithCard.fromMap(Map<String, dynamic> map) => DeckItemWithCard.fromRow(map);

  factory DeckItemWithCard.fromRow(Map<String, dynamic> row) {
    final dviId = row['dvi_id']?.toString() ?? '';
    final versionId = row['version_id']?.toString() ?? '';
    final vaultItemId = row['vault_item_id']?.toString() ?? row['id']?.toString() ?? '';
    final deckQuantity = (row['deck_quantity'] as num?)?.toInt() ?? (row['quantity'] as num?)?.toInt() ?? 1;
    final boardZone = row['board_zone']?.toString() ?? 'Mainboard';
    final isProxy = row['is_proxy'] == 1 || row['is_proxy'] == true;

    final id = row['id']?.toString() ?? vaultItemId;
    final name = row['name']?.toString() ?? 'Unknown Card';
    final setOrSeries = row['set_or_series']?.toString() ?? 'MTG';
    final imageUrl = row['image_url']?.toString();
    final dynamicData = row['dynamic_data']?.toString();
    final currentMarketPrice = (row['current_market_price'] as num?)?.toDouble() ?? 0.0;
    final vaultQuantity = (row['vault_quantity'] as num?)?.toInt() ?? (row['quantity'] as num?)?.toInt() ?? 1;
    final isGraded = row['is_graded'] == 1 || row['is_graded'] == true;
    final condition = row['condition']?.toString() ?? 'NM';
    final acquiredPrice = (row['acquired_price'] as num?)?.toDouble() ?? 0.0;
    final purchasePrice = (row['purchase_price'] as num?)?.toDouble();

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String && val.trim().isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final acquiredDate = parseDate(row['acquired_date']);
    final dateObtained = parseDate(row['date_obtained']);
    final notes = row['notes']?.toString();
    final protectionStatus = row['protection_status']?.toString() ?? 'Sleeved';

    // Canonical map backing the MapView so all existing index operations work
    final canonicalMap = Map<String, dynamic>.of(row);
    canonicalMap['dvi_id'] = dviId;
    canonicalMap['version_id'] = versionId;
    canonicalMap['vault_item_id'] = vaultItemId;
    canonicalMap['deck_quantity'] = deckQuantity;
    canonicalMap['board_zone'] = boardZone;
    canonicalMap['is_proxy'] = isProxy ? 1 : 0;
    canonicalMap['id'] = id;
    canonicalMap['name'] = name;
    canonicalMap['set_or_series'] = setOrSeries;
    canonicalMap['image_url'] = imageUrl;
    canonicalMap['dynamic_data'] = dynamicData;
    canonicalMap['current_market_price'] = currentMarketPrice;
    canonicalMap['vault_quantity'] = vaultQuantity;
    canonicalMap['is_graded'] = isGraded ? 1 : 0;
    canonicalMap['condition'] = condition;
    canonicalMap['acquired_price'] = acquiredPrice;
    canonicalMap['purchase_price'] = purchasePrice;
    canonicalMap['acquired_date'] = acquiredDate;
    canonicalMap['date_obtained'] = dateObtained;
    canonicalMap['notes'] = notes;
    canonicalMap['protection_status'] = protectionStatus;

    return DeckItemWithCard._(
      canonicalMap,
      dviId: dviId,
      versionId: versionId,
      vaultItemId: vaultItemId,
      deckQuantity: deckQuantity,
      boardZone: boardZone,
      isProxy: isProxy,
      id: id,
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: imageUrl,
      dynamicData: dynamicData,
      currentMarketPrice: currentMarketPrice,
      vaultQuantity: vaultQuantity,
      isGraded: isGraded,
      condition: condition,
      acquiredPrice: acquiredPrice,
      purchasePrice: purchasePrice,
      acquiredDate: acquiredDate,
      dateObtained: dateObtained,
      notes: notes,
      protectionStatus: protectionStatus,
    );
  }

  // --- Financial & Domain Helpers ---

  /// Effective cost basis per unit: purchasePrice ?? acquiredPrice ?? 0.0.
  double get effectiveCostBasis {
    if (purchasePrice != null && !purchasePrice!.isNaN && purchasePrice! >= 0.0) {
      return purchasePrice!;
    }
    if (!acquiredPrice.isNaN && acquiredPrice >= 0.0) {
      return acquiredPrice;
    }
    return 0.0;
  }

  /// Total cost basis for this deck line: effectiveCostBasis * deckQuantity.
  double get lineCostBasis => effectiveCostBasis * deckQuantity;

  /// Resolves effective unit market price in [targetCurrency] using Trimmed Average
  /// calculation from dynamicData with fallback to currentMarketPrice.
  double resolveMarketPrice(AppCurrency targetCurrency) {
    final trimmed = TrimmedAverageCalculator.computeFromPayload(
      dynamicData,
      targetCurrency: targetCurrency,
    );
    if (trimmed > 0.0) {
      return trimmed;
    }
    final fallback = currentMarketPrice > 0.0
        ? currentMarketPrice
        : VaultPricingHelper.extractFromDynamicData(dynamicData);
    return ExchangeRateService.convert(
      fallback,
      from: AppCurrency.usd,
      to: targetCurrency,
    );
  }

  /// Total market value for this deck line in [targetCurrency]: unitPrice * deckQuantity.
  double lineMarketValue(AppCurrency targetCurrency) {
    return resolveMarketPrice(targetCurrency) * deckQuantity;
  }

  /// Adapter converting this joined item into a fully populated [VaultItem] DataClass.
  VaultItem toVaultItem() {
    return VaultItem(
      id: id,
      collectionType: this['collection_type']?.toString() ?? 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: imageUrl ?? '',
      flavorName: this['flavor_name']?.toString(),
      acquiredPrice: acquiredPrice,
      acquiredDate: acquiredDate ?? DateTime.now(),
      quantity: vaultQuantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: this['is_altered'] == 1 || this['is_altered'] == true,
      isMisprint: this['is_misprint'] == 1 || this['is_misprint'] == true,
      isSigned: this['is_signed'] == 1 || this['is_signed'] == true,
      personalNotes: this['personal_notes']?.toString(),
      dateObtained: dateObtained,
      purchasePrice: purchasePrice,
      binderPage: (this['binder_page'] as num?)?.toInt(),
      binderSlot: this['binder_slot']?.toString(),
      notes: notes,
      protectionStatus: protectionStatus,
      primaryBinderId: this['primary_binder_id']?.toString(),
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: dynamicData ?? '{}',
    );
  }
}

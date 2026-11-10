import 'dart:convert';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/services/trade_pricing_calculator.dart';

/// Represents the transfer of an individual card from one participant to another in a trade.
class TradeCardTransfer {
  final String cardId;
  final String senderId;
  final String recipientId;
  final double marketPrice;
  final String finish;
  final String cardName;
  final String? setName;
  final String? collectorNumber;
  final String? imageUrl;
  final Map<String, dynamic> cardSnapshot;

  const TradeCardTransfer({
    required this.cardId,
    required this.senderId,
    required this.recipientId,
    required this.marketPrice,
    required this.finish,
    required this.cardName,
    this.setName,
    this.collectorNumber,
    this.imageUrl,
    this.cardSnapshot = const {},
  });

  /// Factory creating transfer from a [VaultItem] and routing details.
  factory TradeCardTransfer.fromVaultItem({
    required VaultItem item,
    required String senderId,
    required String recipientId,
  }) {
    final finish = TradePricingCalculator.resolveFinish(item);
    final price = TradePricingCalculator.calculateCardPrice(item, finish: finish);
    final imageUrl = item.imageUrl;

    String? collectorNum;
    String? scryfallId;
    if (item.dynamicData.isNotEmpty) {
      try {
        final decoded = jsonDecode(item.dynamicData);
        if (decoded is Map) {
          collectorNum = decoded['collector_number']?.toString();
          scryfallId = decoded['scryfall_id']?.toString() ?? decoded['id']?.toString();
        }
      } catch (_) {}
    }

    final snapshot = <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'setName': item.setOrSeries,
      'collectorNumber': collectorNum,
      'imageUrl': imageUrl,
      'finish': finish,
      'marketPrice': price,
      'scryfallId': scryfallId,
    };

    return TradeCardTransfer(
      cardId: item.id,
      senderId: senderId,
      recipientId: recipientId,
      marketPrice: price,
      finish: finish,
      cardName: item.name,
      setName: item.setOrSeries,
      collectorNumber: collectorNum,
      imageUrl: imageUrl,
      cardSnapshot: snapshot,
    );
  }

  TradeCardTransfer copyWith({
    String? cardId,
    String? senderId,
    String? recipientId,
    double? marketPrice,
    String? finish,
    String? cardName,
    String? setName,
    String? collectorNumber,
    String? imageUrl,
    Map<String, dynamic>? cardSnapshot,
  }) {
    return TradeCardTransfer(
      cardId: cardId ?? this.cardId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      marketPrice: marketPrice ?? this.marketPrice,
      finish: finish ?? this.finish,
      cardName: cardName ?? this.cardName,
      setName: setName ?? this.setName,
      collectorNumber: collectorNumber ?? this.collectorNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      cardSnapshot: cardSnapshot ?? this.cardSnapshot,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardId': cardId,
      'senderId': senderId,
      'recipientId': recipientId,
      'marketPrice': marketPrice,
      'finish': finish,
      'cardName': cardName,
      'setName': setName,
      'collectorNumber': collectorNumber,
      'imageUrl': imageUrl,
      'cardSnapshot': cardSnapshot,
    };
  }

  factory TradeCardTransfer.fromJson(Map<String, dynamic> json) {
    return TradeCardTransfer(
      cardId: json['cardId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      marketPrice: (json['marketPrice'] as num?)?.toDouble() ?? 0.0,
      finish: json['finish'] as String? ?? 'non_foil',
      cardName: json['cardName'] as String? ?? 'Unknown Card',
      setName: json['setName'] as String?,
      collectorNumber: json['collectorNumber'] as String?,
      imageUrl: json['imageUrl'] as String?,
      cardSnapshot: json['cardSnapshot'] is Map
          ? Map<String, dynamic>.from(json['cardSnapshot'] as Map)
          : {},
    );
  }

  static List<TradeCardTransfer> listFromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => TradeCardTransfer.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static String listToJson(List<TradeCardTransfer> transfers) {
    return jsonEncode(transfers.map((t) => t.toJson()).toList());
  }
}

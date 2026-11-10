import 'dart:math' as math;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';

/// Represents a participant in a 2-way or 3-way trade.
class TradeParticipant {
  final UserProfile user;
  final List<VaultItem> sendingCards;
  final List<VaultItem> receivingCards;
  final List<TradeCardTransfer> sendingTransfers;
  final List<TradeCardTransfer> receivingTransfers;
  final double sendingTotalValue;
  final double receivingTotalValue;

  const TradeParticipant({
    required this.user,
    this.sendingCards = const [],
    this.receivingCards = const [],
    this.sendingTransfers = const [],
    this.receivingTransfers = const [],
    this.sendingTotalValue = 0.0,
    this.receivingTotalValue = 0.0,
  });

  String get id => user.id;
  String get displayName => user.displayName;
  String get username => user.username;
  String? get avatarUrl => user.avatarUrl;

  /// Net dollar change for this participant:
  /// Positive means receiving more value than sending (+).
  /// Negative means giving away more value than receiving (-).
  double get netDelta => receivingTotalValue - sendingTotalValue;

  /// Absolute dollar difference between sending and receiving.
  double get absoluteDollarGap => (receivingTotalValue - sendingTotalValue).abs();

  /// Percentage differential between sending and receiving:
  /// (|Receiving - Sending| / max(Receiving, Sending)) * 100%
  double get percentageDelta {
    final denom = math.max(sendingTotalValue, receivingTotalValue);
    if (denom <= 0.0) return 0.0;
    return (absoluteDollarGap / denom) * 100.0;
  }

  /// True if this participant has a large value gap (>= 15% OR >= $10.00).
  bool get hasLargeValueGap {
    // Only flag if at least one card is being sent or received
    if (sendingTotalValue == 0.0 && receivingTotalValue == 0.0) return false;
    return percentageDelta >= 15.0 || absoluteDollarGap >= 10.0;
  }

  TradeParticipant copyWith({
    UserProfile? user,
    List<VaultItem>? sendingCards,
    List<VaultItem>? receivingCards,
    List<TradeCardTransfer>? sendingTransfers,
    List<TradeCardTransfer>? receivingTransfers,
    double? sendingTotalValue,
    double? receivingTotalValue,
  }) {
    return TradeParticipant(
      user: user ?? this.user,
      sendingCards: sendingCards ?? this.sendingCards,
      receivingCards: receivingCards ?? this.receivingCards,
      sendingTransfers: sendingTransfers ?? this.sendingTransfers,
      receivingTransfers: receivingTransfers ?? this.receivingTransfers,
      sendingTotalValue: sendingTotalValue ?? this.sendingTotalValue,
      receivingTotalValue: receivingTotalValue ?? this.receivingTotalValue,
    );
  }
}

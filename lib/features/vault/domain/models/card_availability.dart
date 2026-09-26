import 'package:flutter/foundation.dart';

/// Immutable model representing real-time physical card availability.
///
/// Invariant: Owned = Available + In Deck.
@immutable
class CardAvailability {
  final int owned;
  final int available;
  final int inDeck;

  const CardAvailability({
    required this.owned,
    required this.available,
    required this.inDeck,
  });

  /// Default zero availability.
  static const zero = CardAvailability(owned: 0, available: 0, inDeck: 0);

  CardAvailability copyWith({
    int? owned,
    int? available,
    int? inDeck,
  }) {
    return CardAvailability(
      owned: owned ?? this.owned,
      available: available ?? this.available,
      inDeck: inDeck ?? this.inDeck,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardAvailability &&
          runtimeType == other.runtimeType &&
          owned == other.owned &&
          available == other.available &&
          inDeck == other.inDeck;

  @override
  int get hashCode => Object.hash(owned, available, inDeck);

  @override
  String toString() =>
      'CardAvailability(Owned: $owned, Available: $available, InDeck: $inDeck)';
}

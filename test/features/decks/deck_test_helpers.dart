import 'package:countr/core/database/app_database.dart';

/// Helper to instantiate a [Deck] with sensible defaults for test environments.
Deck createTestDeck({
  required String id,
  required String name,
  String format = 'MTG Commander',
  String? description,
  int wins = 0,
  int losses = 0,
  int draws = 0,
  String? coverItemId,
  String? coverCropRect,
  DateTime? createdAt,
  String tcgDomain = 'mtg',
  bool isRegistered = false,
  bool isCompetitive = false,
  bool? isAssembled,
  bool isCloned = false,
  bool isDeleted = false,
}) {
  return Deck(
    id: id,
    name: name,
    format: format,
    description: description,
    wins: wins,
    losses: losses,
    draws: draws,
    coverItemId: coverItemId,
    coverCropRect: coverCropRect,
    createdAt: createdAt ?? DateTime.now(),
    tcgDomain: tcgDomain,
    isRegistered: isRegistered,
    isAssembled: isAssembled ?? isRegistered,
    isCompetitive: isCompetitive,
    isCloned: isCloned,
    isDeleted: isDeleted,
  );
}

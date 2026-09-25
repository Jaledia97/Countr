/// Represents the zones in which a card can be placed within a deck.
enum BoardZone {
  mainboard('Mainboard', 'Mainboard'),
  sideboard('Sideboard', 'Sideboard'),
  maybeboard('Maybeboard', 'Maybeboard'),
  commander('Commander', 'Commander'),
  companion('Companion', 'Companion');

  const BoardZone(this.value, this.displayName);

  /// Canonical database string representation (PascalCase).
  final String value;

  /// User-facing display title.
  final String displayName;

  /// Parses a string into a [BoardZone], falling back to [BoardZone.mainboard] if unknown or null.
  static BoardZone fromString(String? zone) {
    if (zone == null) return BoardZone.mainboard;
    final clean = zone.trim().toLowerCase();
    switch (clean) {
      case 'commander':
        return BoardZone.commander;
      case 'sideboard':
        return BoardZone.sideboard;
      case 'maybeboard':
        return BoardZone.maybeboard;
      case 'companion':
        return BoardZone.companion;
      case 'mainboard':
      default:
        return BoardZone.mainboard;
    }
  }

  /// Tries to parse a string into a [BoardZone], returning null if unrecognized or null.
  static BoardZone? tryParse(String? zone) {
    if (zone == null) return null;
    final clean = zone.trim().toLowerCase();
    switch (clean) {
      case 'commander':
        return BoardZone.commander;
      case 'sideboard':
        return BoardZone.sideboard;
      case 'maybeboard':
        return BoardZone.maybeboard;
      case 'companion':
        return BoardZone.companion;
      case 'mainboard':
        return BoardZone.mainboard;
      default:
        return null;
    }
  }
}

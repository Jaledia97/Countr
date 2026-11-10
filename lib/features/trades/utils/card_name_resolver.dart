import '../../../../core/database/app_database.dart';

/// Centralized utility for resolving raw card identifiers, slugs, and catalog entities
/// into clean, plain English Title Case names with robust truncation and error fallback.
class CardNameResolver {
  /// Formats raw card IDs and slugs into clean, readable Title Case names.
  /// Handles prefixes like 'item-(mtg|pokemon|yugioh|lorcana|starwars)-',
  /// double-faced slash notation, hyphens, underscores, and length truncation.
  static String formatSlug(String? identifier) {
    if (identifier == null || identifier.trim().isEmpty) {
      return 'Card Not Available';
    }
    var clean = identifier.trim();

    // 1. Strip legacy multi-TCG slug prefix 'item-(mtg|pokemon|yugioh|lorcana|starwars)-'
    final slugMatch = RegExp(
      r'^item-(mtg|pokemon|yugioh|lorcana|starwars)-',
      caseSensitive: false,
    ).firstMatch(clean);
    if (slugMatch != null) {
      clean = clean.substring(slugMatch.end);
    }

    // 2. Strip generic 'item-' prefix if present
    if (clean.toLowerCase().startsWith('item-')) {
      clean = clean.substring(5);
    }

    // 3. Handle double-faced cards 'Face A // Face B' -> 'Face A'
    if (clean.contains('//')) {
      clean = clean.split('//').first.trim();
    }

    // 4. Split by hyphens, underscores, and whitespace
    final words = clean
        .split(RegExp(r'[-_\s]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'Card Not Available';
    }

    // 5. Convert words to Title Case
    final title = words.map((w) {
      if (w.length <= 1) return w.toUpperCase();
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    // 6. Truncate if extreme length (> 30 characters)
    if (title.length > 30) {
      return '${title.substring(0, 27)}...';
    }
    return title;
  }

  /// Resolves display name for a card identifier using the database catalog,
  /// falling back to [formatSlug] if catalog record is not found.
  static Future<String> resolveDisplayName(
    AppDatabase db,
    String? identifier,
  ) async {
    if (identifier == null || identifier.trim().isEmpty) {
      return 'Card Not Available';
    }
    final card = await db.vaultDao.findCatalogCard(identifier: identifier);
    if (card != null && card.name.trim().isNotEmpty) {
      final name = card.name.trim();
      if (name.length > 30) {
        return '${name.substring(0, 27)}...';
      }
      return name;
    }
    return formatSlug(identifier);
  }
}

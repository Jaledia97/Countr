import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
class ParsedDeckItem {
  final int quantity;
  final String name;
  final String? setCode;
  final String? collectorNumber;

  ParsedDeckItem({
    required this.quantity,
    required this.name,
    this.setCode,
    this.collectorNumber,
  });
}

class DeckIOParser {
  /// Regex to parse: "1 Lathril, Blade of the Elves (KHC) 1"
  /// Group 1: Quantity
  /// Group 2: Name
  /// Group 3: Set code (optional)
  /// Group 4: Collector number (optional)
  static final RegExp _mtgListRegex =
      RegExp(r'^(\d+)\x20+(.+?)(?:\x20+\((.+?)\)\x20+(\d+))?$');

  /// Parses a multi-line plaintext list of MTG cards.
  static List<ParsedDeckItem> parseList(String text) {
    final lines = text.split('\n');
    final List<ParsedDeckItem> result = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      final match = _mtgListRegex.firstMatch(trimmed);
      if (match != null) {
        final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
        final name = match.group(2)?.trim() ?? '';
        final setCode = match.group(3)?.trim();
        final collectorNumber = match.group(4)?.trim();

        if (name.isNotEmpty) {
          result.add(ParsedDeckItem(
            quantity: qty,
            name: name,
            setCode: setCode,
            collectorNumber: collectorNumber,
          ));
        }
      }
    }
    return result;
  }

  /// Exports missing cards (unowned or marked as proxy) for TCGplayer Mass Entry.
  /// Standard TCGPlayer format is just: "Quantity Card Name"
  static String exportMissingCards(List<DeckVersionItem> items, Map<String, VaultItem> resolvedVaultItems) {
    final buffer = StringBuffer();
    for (final deckItem in items) {
      if (deckItem.isProxy) {
        final vItem = resolvedVaultItems[deckItem.vaultItemId];
        final name = vItem?.name ?? 'Unknown Card';
        buffer.writeln('${deckItem.quantity} $name');
      }
    }
    return buffer.toString().trim();
  }

  /// Evaluates imported items against VaultDao for Conflict Engine
  static Future<List<DeckVersionItemsCompanion>> evaluateImport(
    List<ParsedDeckItem> parsedItems,
    VaultDao vaultDao,
    String versionId,
  ) async {
    final List<DeckVersionItemsCompanion> resolved = [];
    
    for (final item in parsedItems) {
      // Find matching item in Vault
      final matched = await vaultDao.searchCatalogCards(item.name, limit: 1);
      if (matched.isNotEmpty) {
        final vaultItem = matched.first;
        final available = await vaultDao.getAvailableQuantity(vaultItem.id);
        
        resolved.add(DeckVersionItemsCompanion.insert(
          id: 'temp-id-${DateTime.now().millisecondsSinceEpoch}',
          versionId: versionId,
          vaultItemId: vaultItem.id,
          quantity: drift.Value(item.quantity),
          boardZone: 'Mainboard',
          // If the available amount is less than what we need, mark it as proxy
          isProxy: drift.Value(available < item.quantity),
        ));
      }
    }
    return resolved;
  }
}

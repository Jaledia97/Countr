import 'package:countr/features/decks/domain/models/board_zone.dart';

/// Represents a card item in the deck assembly pick-list.
class AssemblyPickItem {
  final String dviId;
  final String vaultItemId;
  final String cardName;
  final String setCode;
  final String? imageUrl;
  final BoardZone boardZone;
  final int requiredQuantity;
  final int availableQuantity;
  final int pullQuantity; // min(requiredQuantity, availableQuantity)
  final int deficitQuantity; // max(0, requiredQuantity - availableQuantity)
  final String? binderId;
  final String locationName; // "Binder A", "Bulk Box", "Unsorted Vault"
  final bool isProxy;
  bool isPulled;

  AssemblyPickItem({
    required this.dviId,
    required this.vaultItemId,
    required this.cardName,
    required this.setCode,
    this.imageUrl,
    required this.boardZone,
    required this.requiredQuantity,
    required this.availableQuantity,
    required this.pullQuantity,
    required this.deficitQuantity,
    this.binderId,
    required this.locationName,
    this.isProxy = false,
    this.isPulled = false,
  });

  bool get hasDeficit => deficitQuantity > 0;
}

/// Represents the overall physical pick-list plan for assembling a deck.
class DeckAssemblyPlan {
  final String deckId;
  final String deckName;
  final List<AssemblyPickItem> items;
  final Map<String, List<AssemblyPickItem>> itemsByLocation;
  final List<AssemblyPickItem> deficitItems;

  DeckAssemblyPlan({
    required this.deckId,
    required this.deckName,
    required this.items,
    required this.itemsByLocation,
    required this.deficitItems,
  });

  int get totalRequired => items.fold(0, (sum, i) => sum + i.requiredQuantity);
  int get totalAvailable => items.fold(0, (sum, i) => sum + i.pullQuantity);
  int get totalDeficit => deficitItems.fold(0, (sum, i) => sum + i.deficitQuantity);
  int get totalPulled => items.where((i) => i.isPulled).fold(0, (sum, i) => sum + i.pullQuantity);
  bool get hasDeficit => totalDeficit > 0;
  double get progress => totalAvailable > 0 ? (totalPulled / totalAvailable) : 1.0;
}

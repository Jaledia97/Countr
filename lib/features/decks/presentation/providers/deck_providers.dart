import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';

final deckListProvider = StreamProvider<List<Deck>>((ref) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchAllDecks();
});

final deckProvider = StreamProvider.family<Deck, String>((ref, id) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchDeck(id);
});

final deckItemsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, deckId) {
  try {
    final dao = ref.watch(vaultDaoProvider);
    return dao.watchDeckItems(deckId).map((items) {
      if (items.isEmpty) {
        return MockDeckData.getDeckItems(deckId);
      }
      return items;
    }).handleError((_) => MockDeckData.getDeckItems(deckId));
  } catch (_) {
    return Stream.value(MockDeckData.getDeckItems(deckId));
  }
});

final deckVersionsProvider =
    StreamProvider.family<List<DeckVersion>, String>((ref, deckId) {
  try {
    final dao = ref.watch(vaultDaoProvider);
    return dao.watchDeckVersions(deckId).map((versions) {
      if (versions.isEmpty) {
        return MockDeckData.getMockVersions(deckId);
      }
      return versions;
    }).handleError((_) => MockDeckData.getMockVersions(deckId));
  } catch (_) {
    return Stream.value(MockDeckData.getMockVersions(deckId));
  }
});

final deckMatchupsProvider =
    StreamProvider.family<List<DeckMatchup>, String>((ref, deckId) {
  try {
    final dao = ref.watch(vaultDaoProvider);
    return dao.watchDeckMatchups(deckId).map((matchups) {
      if (matchups.isEmpty) {
        return MockDeckData.getMockMatchups(deckId);
      }
      return matchups;
    }).handleError((_) => MockDeckData.getMockMatchups(deckId));
  } catch (_) {
    return Stream.value(MockDeckData.getMockMatchups(deckId));
  }
});

final itemActiveDecksProvider =
    StreamProvider.family<List<String>, String>((ref, vaultItemId) {
  final dao = ref.watch(vaultDaoProvider);
  return dao.watchItemActiveDecks(vaultItemId);
});

class DeckAnalytics {
  final Map<int, int> manaCurve;
  final Map<String, int> colorDevotion;
  final Map<String, int> colorProduction;
  final double blingPercentage;

  DeckAnalytics({
    required this.manaCurve,
    required this.colorDevotion,
    required this.colorProduction,
    required this.blingPercentage,
  });
}

final deckAnalyticsProvider =
    Provider.family<AsyncValue<DeckAnalytics>, String>((ref, deckId) {
  final itemsAsync = ref.watch(deckItemsProvider(deckId));

  return itemsAsync.whenData((items) {
    final manaCurve = <int, int>{};
    final colorDevotion = <String, int>{};
    final colorProduction = <String, int>{};
    int totalCards = 0;
    int blingCards = 0;

    for (final item in items) {
      final int qty = item['deck_quantity'] as int? ?? 1;
      totalCards += qty;

      // Bling check: graded, altered, signed, misprint, or finishes (foil, etched) / promo
      final isGraded = item['is_graded'] == 1 || item['is_graded'] == true;
      final isAltered = item['is_altered'] == 1 || item['is_altered'] == true;
      final isSigned = item['is_signed'] == 1 || item['is_signed'] == true;
      final isMisprint =
          item['is_misprint'] == 1 || item['is_misprint'] == true;

      bool cardHasBling = isGraded || isAltered || isSigned || isMisprint;

      final dynamicDataStr = item['dynamic_data'] as String?;
      if (dynamicDataStr != null && dynamicDataStr.isNotEmpty) {
        try {
          final data = jsonDecode(dynamicDataStr) as Map<String, dynamic>;

          if (!cardHasBling) {
            if (data['promo'] == true) {
              cardHasBling = true;
            } else if (data['finishes'] is List) {
              final finishes = (data['finishes'] as List).cast<String>();
              if (finishes.contains('foil') || finishes.contains('etched')) {
                cardHasBling = true;
              }
            } else if (data['frame_effects'] is List) {
              final effects = (data['frame_effects'] as List).cast<String>();
              if (effects.contains('showcase') ||
                  effects.contains('extendedart') ||
                  effects.contains('borderless')) {
                cardHasBling = true;
              }
            }
          }

          // Mana Curve (cmc)
          final cmcNum = data['cmc'] as num?;
          if (cmcNum != null) {
            final cmc = cmcNum.toInt();
            manaCurve[cmc] = (manaCurve[cmc] ?? 0) + qty;
          }

          // Helper to parse mana cost string into devotion
          void parseManaCost(String cost) {
            final matches = RegExp(r'\{([^}]+)\}').allMatches(cost);
            for (final match in matches) {
              final sym = match.group(1)!;
              if (sym.contains('/')) {
                final parts = sym.split('/');
                for (final part in parts) {
                  if (part != 'P' &&
                      part != '2' &&
                      RegExp(r'^[WUBRGC]$').hasMatch(part)) {
                    colorDevotion[part] = (colorDevotion[part] ?? 0) + qty;
                  }
                }
              } else if (RegExp(r'^[WUBRGC]$').hasMatch(sym)) {
                colorDevotion[sym] = (colorDevotion[sym] ?? 0) + qty;
              }
            }
          }

          // Color Devotion (mana_cost parsing, DFCs/adventures via card_faces)
          final manaCost = data['mana_cost'] as String?;
          if (manaCost != null && manaCost.isNotEmpty) {
            parseManaCost(manaCost);
          } else if (data['card_faces'] is List) {
            for (final face in (data['card_faces'] as List)) {
              if (face is Map<String, dynamic> && face['mana_cost'] is String) {
                parseManaCost(face['mana_cost'] as String);
              }
            }
          }

          // Color Production (produced_mana)
          final produced = data['produced_mana'] as List<dynamic>?;
          if (produced != null) {
            for (final c in produced) {
              final color = c.toString();
              colorProduction[color] = (colorProduction[color] ?? 0) + qty;
            }
          }
        } catch (_) {}
      }

      if (cardHasBling) {
        blingCards += qty;
      }
    }

    return DeckAnalytics(
      manaCurve: manaCurve,
      colorDevotion: colorDevotion,
      colorProduction: colorProduction,
      blingPercentage: totalCards > 0 ? (blingCards / totalCards) : 0.0,
    );
  });
});

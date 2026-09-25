import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/decks/domain/deck_gear.dart';

/// Manages reactive Deck Gear state per deck.
class DeckGearNotifier extends StateNotifier<DeckGear> {
  final String deckId;

  DeckGearNotifier(this.deckId) : super(const DeckGear());

  void setSleeveBrand(String brand) {
    state = state.copyWith(sleeveBrand: brand);
  }

  void setSleeveColor(String color) {
    state = state.copyWith(sleeveColor: color);
  }

  void setDeckBoxModel(String model) {
    state = state.copyWith(deckBoxModel: model);
  }
}

final deckGearProvider =
    StateNotifierProvider.family<DeckGearNotifier, DeckGear, String>(
  (ref, deckId) => DeckGearNotifier(deckId),
);

/// Tracks checked physical tokens for tournament packing checklists per deck.
class DeckCheckedTokensNotifier extends StateNotifier<Set<String>> {
  DeckCheckedTokensNotifier() : super(const {});

  void toggle(String token) {
    if (state.contains(token)) {
      state = {...state}..remove(token);
    } else {
      state = {...state, token};
    }
  }

  void clear() {
    state = const {};
  }
}

final deckCheckedTokensProvider =
    StateNotifierProvider.family<DeckCheckedTokensNotifier, Set<String>, String>(
  (ref, deckId) => DeckCheckedTokensNotifier(),
);

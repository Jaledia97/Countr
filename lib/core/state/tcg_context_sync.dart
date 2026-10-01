import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';

/// Bridging utility and canonical authority for cross-screen TCG context
/// synchronization between Vault ([activeGameContextProvider]) and Decks
/// ([activeDeckTcgFilterProvider]).
class TcgContextSync {
  // Domain keys (used by Decks & Deck Builders)
  static const String domainAll = 'all';
  static const String domainMtg = 'mtg';
  static const String domainPokemon = 'pokemon';
  static const String domainLorcana = 'lorcana';

  // Game / Collection titles (used by Vault & Game Context)
  static const String gameAll = 'All Collections';
  static const String gameMtg = 'Magic: The Gathering';
  static const String gamePokemon = 'Pokémon TCG';
  static const String gameLorcana = 'Disney Lorcana';
  static const String gameComics = 'Comic Books';
  static const String gameSports = 'Sports Cards';

  /// Supported TCG games that have corresponding deck builder formats.
  static const List<String> supportedTcgGames = [
    gameMtg,
    gamePokemon,
    gameLorcana,
  ];

  /// Supported collection titles in the Vault selector.
  static const List<String> vaultCollections = [
    gameAll,
    gameMtg,
    gamePokemon,
    gameLorcana,
    gameComics,
    gameSports,
  ];

  /// Supported TCG domain codes in the Decks selector.
  static const List<String> deckDomains = [
    domainAll,
    domainMtg,
    domainPokemon,
    domainLorcana,
  ];

  /// Metadata models for collections and options
  static const List<Map<String, dynamic>> collectionDefinitions = [
    {
      'title': gameAll,
      'domain': domainAll,
      'icon': Icons.all_inbox_rounded,
      'color': AppColors.accentCyan,
    },
    {
      'title': gameMtg,
      'domain': domainMtg,
      'icon': Icons.auto_awesome_rounded,
      'color': AppColors.accentViolet,
    },
    {
      'title': gamePokemon,
      'domain': domainPokemon,
      'icon': Icons.catching_pokemon_rounded,
      'color': AppColors.accentAmber,
    },
    {
      'title': gameLorcana,
      'domain': domainLorcana,
      'icon': Icons.auto_stories_rounded,
      'color': AppColors.accentVioletLight,
    },
    {
      'title': gameComics,
      'domain': 'comic',
      'icon': Icons.menu_book_rounded,
      'color': AppColors.accentEmerald,
    },
    {
      'title': gameSports,
      'domain': 'sport',
      'icon': Icons.sports_football_rounded,
      'color': AppColors.accentCyan,
    },
  ];

  /// Converts a game/collection title to the corresponding deck TCG domain.
  /// Non-TCG collections (e.g. Comic Books, Sports Cards) or 'All Collections'
  /// map to 'all'.
  static String gameToDomain(String? game) {
    if (game == null || game.isEmpty) return domainAll;
    final lower = game.toLowerCase().replaceAll('é', 'e').trim();
    if (lower.contains('magic') || lower == 'mtg') return domainMtg;
    if (lower.contains('pokemon') || lower == 'pkm') return domainPokemon;
    if (lower.contains('lorcana')) return domainLorcana;
    return domainAll;
  }

  /// Converts a deck TCG domain to the canonical game context title.
  static String domainToGame(String? domain) {
    if (domain == null || domain.isEmpty) return gameAll;
    final lower = domain.toLowerCase().trim();
    switch (lower) {
      case domainMtg:
      case 'magic':
        return gameMtg;
      case domainPokemon:
      case 'pokémon':
      case 'pkm':
        return gamePokemon;
      case domainLorcana:
        return gameLorcana;
      case domainAll:
      default:
        return gameAll;
    }
  }

  /// Normalizes any collection type or game title into a canonical domain key.
  static String normalizeCollectionType(String? type) {
    if (type == null || type.isEmpty) return domainAll;
    final lower = type.toLowerCase().replaceAll('é', 'e').trim();
    if (lower.contains('magic') || lower.contains('mtg')) return domainMtg;
    if (lower.contains('pokemon') || lower.contains('pkm')) return domainPokemon;
    if (lower.contains('lorcana')) return domainLorcana;
    if (lower.contains('comic')) return 'comic';
    if (lower.contains('sport')) return 'sport';
    if (lower.contains('all')) return domainAll;
    return lower;
  }

  /// Normalizes a game context string to canonical title.
  static String normalizeGameContext(String? game) {
    if (game == null || game.isEmpty) return gameAll;
    final lower = game.toLowerCase().replaceAll('é', 'e').trim();
    if (lower.contains('magic') || lower == 'mtg') return gameMtg;
    if (lower.contains('pokemon') || lower == 'pkm') return gamePokemon;
    if (lower.contains('lorcana')) return gameLorcana;
    if (lower.contains('comic')) return gameComics;
    if (lower.contains('sport')) return gameSports;
    return gameAll;
  }

  /// Returns true if the domain is a playable TCG ('mtg', 'pokemon', 'lorcana').
  static bool isTcgDomain(String domain) {
    final lower = domain.toLowerCase().trim();
    return lower == domainMtg || lower == domainPokemon || lower == domainLorcana;
  }

  /// Maps Vault game context string to Decks TCG filter domain.
  static String mapGameContextToDeckFilter(String gameContext) => gameToDomain(gameContext);

  /// Maps Decks TCG filter domain to Vault game context string.
  static String mapDeckFilterToGameContext(String deckFilter) => domainToGame(deckFilter);

  /// Establishes bidirectional listener synchronization on a ProviderContainer.
  static void bindSync(ProviderContainer container) {
    bool isSyncing = false;

    // Listen to Vault context -> update Decks filter
    container.listen<String>(
      activeGameContextProvider,
      (previous, next) {
        if (isSyncing) return;
        final targetDeckFilter = gameToDomain(next);
        if (container.read(activeDeckTcgFilterProvider) != targetDeckFilter) {
          isSyncing = true;
          try {
            container.read(activeDeckTcgFilterProvider.notifier).state =
                targetDeckFilter;
          } finally {
            isSyncing = false;
          }
        }
      },
      fireImmediately: true,
    );

    // Listen to Decks filter -> update Vault context
    container.listen<String>(
      activeDeckTcgFilterProvider,
      (previous, next) {
        if (isSyncing) return;
        final targetGameContext = domainToGame(next);
        if (container.read(activeGameContextProvider) != targetGameContext) {
          isSyncing = true;
          try {
            container.read(activeGameContextProvider.notifier).state =
                targetGameContext;
          } finally {
            isSyncing = false;
          }
        }
      },
    );
  }
}

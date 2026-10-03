import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_controller.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Provider for the Scryfall API and download streaming service.
final scryfallServiceProvider = Provider<ScryfallService>((ref) {
  return ScryfallService();
});

/// Provider for the low-memory background streaming isolate parser.
final scryfallStreamingParserProvider = Provider<ScryfallStreamingParser>((ref) {
  return ScryfallStreamingParser();
});

/// StateNotifierProvider exposing the HydrationController and its state.
final hydrationControllerProvider =
    StateNotifierProvider<HydrationController, HydrationState>((ref) {
  final scryfallService = ref.watch(scryfallServiceProvider);
  final parser = ref.watch(scryfallStreamingParserProvider);
  final vaultDao = ref.watch(vaultDaoProvider);

  return HydrationController(
    scryfallService: scryfallService,
    parser: parser,
    vaultDao: vaultDao,
  );
});

/// Provider for the MTG auto-hydration coordinator.
final mtgAutoHydrationCoordinatorProvider =
    Provider<MtgAutoHydrationCoordinator>((ref) {
  return MtgAutoHydrationCoordinator(ref);
});

/// Coordinates automatic background Scryfall hydration and art pre-caching
/// based on catalog threshold (< 100 MTG cards) and image cache presence.
class MtgAutoHydrationCoordinator {
  final Ref _ref;
  bool _isChecking = false;

  MtgAutoHydrationCoordinator(this._ref);

  /// Inspects SQLite database and disk cache health. If MTG catalog data
  /// is missing (< 100 catalog cards) or cache was wiped, triggers background hydration.
  Future<void> checkAndTriggerAutoHydration({bool force = false}) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final activeGame = _ref.read(activeGameContextProvider);
      final isMtg = activeGame.toLowerCase().contains('magic') ||
          activeGame.toLowerCase() == 'mtg';
      if (!isMtg && !force) return;

      final hydrationState = _ref.read(hydrationControllerProvider);
      if (hydrationState.isLoading) return; // Already in progress

      final dao = _ref.read(vaultDaoProvider);
      final catalogCount = await dao.getMtgCatalogCardCount();

      // Check if catalog is unpopulated (threshold < 100 items)
      final bool needsCatalogHydration = catalogCount < 100;

      // Check if image cache is healthy
      final bool cacheHealthy =
          await CountrImageCacheManager.instance.isImageCacheHealthy();

      if (needsCatalogHydration || !cacheHealthy || force) {
        debugPrint(
          '[MtgAutoHydration] Health check: catalogCount=$catalogCount, cacheHealthy=$cacheHealthy. '
          'Auto-triggering Scryfall hydration & pre-caching.',
        );

        // 1. Trigger background bulk hydration
        if (needsCatalogHydration || force) {
          _ref.read(hydrationControllerProvider.notifier).startHydration();
        }

        // 2. Pre-cache essential deck cover images
        _precacheEssentialArt();
      }
    } catch (e, stackTrace) {
      debugPrint('[MtgAutoHydration] Health check failed: $e\n$stackTrace');
    } finally {
      _isChecking = false;
    }
  }

  void _precacheEssentialArt() {
    final cacheManager = CountrImageCacheManager.instance;
    cacheManager
        .precacheCardArt(
          'edgar-markov',
          'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
        )
        .ignore();
    cacheManager
        .precacheDeckCover(
          'deck-edgar-markov',
          'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
        )
        .ignore();
  }
}

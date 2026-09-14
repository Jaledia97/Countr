import 'package:flutter_riverpod/flutter_riverpod.dart';
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

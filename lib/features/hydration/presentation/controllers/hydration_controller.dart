import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

/// StateNotifier controlling the MTG Bulk Hydration pipeline.
/// Safely coordinates HTTP streaming download, background isolate JSON chunk parsing,
/// Drift database batch transactions, and real-time UI state emissions.
class HydrationController extends StateNotifier<HydrationState> {
  final ScryfallService _scryfallService;
  final ScryfallStreamingParser _parser;
  final VaultDao _vaultDao;
  final Future<Directory> Function()? _tempDirProvider;

  HydrationController({
    required ScryfallService scryfallService,
    required ScryfallStreamingParser parser,
    required VaultDao vaultDao,
    Future<Directory> Function()? tempDirProvider,
  })  : _scryfallService = scryfallService,
        _parser = parser,
        _vaultDao = vaultDao,
        _tempDirProvider = tempDirProvider,
        super(const HydrationState());

  /// Starts the end-to-end hydration pipeline.
  /// If [localFileToHydrate] is provided, downloading is bypassed (ideal for testing).
  Future<void> startHydration({
    String? overrideDownloadUri,
    File? localFileToHydrate,
    int? estimatedTotal,
  }) async {
    if (state.isLoading) return;

    File? tempFile;
    try {
      if (localFileToHydrate != null) {
        tempFile = localFileToHydrate;
      } else {
        // Step 1: Fetch bulk metadata
        state = state.copyWith(
          status: HydrationStatus.fetchingMetadata,
          statusMessage: 'Connecting to Scryfall API for latest bulk export...',
          clearProgress: true,
          clearError: true,
        );

        final downloadUri = overrideDownloadUri ??
            await _scryfallService.fetchBulkDownloadUri();

        // Step 2: Download bulk file streaming to disk
        state = state.copyWith(
          status: HydrationStatus.downloading,
          statusMessage: 'Initiating stream download to temporary disk cache...',
          progress: 0.0,
          bytesDownloaded: 0,
        );

        final Directory tempDir = _tempDirProvider != null
            ? await _tempDirProvider()
            : Directory.systemTemp;

        final targetPath =
            '${tempDir.path}/scryfall_bulk_cards_${DateTime.now().millisecondsSinceEpoch}.json';

        tempFile = await _scryfallService.downloadBulkFile(
          downloadUri: downloadUri,
          targetFilePath: targetPath,
          onProgress: (bytes, total) {
            final progress =
                (total != null && total > 0) ? (bytes / total).clamp(0.0, 1.0) : null;
            final mbDown = (bytes / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = total != null
                ? '${(total / (1024 * 1024)).toStringAsFixed(1)} MB'
                : 'Unknown';

            state = state.copyWith(
              bytesDownloaded: bytes,
              totalBytes: total,
              progress: progress,
              statusMessage: 'Downloading MTG catalog ($mbDown MB / $mbTotal)...',
            );
          },
        );
      }

      // Step 3: Spawn background isolate for streaming parse & chunked database insertion
      final estTotal = estimatedTotal ?? state.estimatedTotalCards;
      state = state.copyWith(
        status: HydrationStatus.parsingAndInserting,
        progress: 0.0,
        insertedCount: 0,
        estimatedTotalCards: estTotal,
        statusMessage: 'Spawning background isolate & hydrating local ledger...',
      );

      final totalCards = await _parser.parseFileInIsolate(
        filePath: tempFile.path,
        chunkSize: 1000,
        onChunk: (chunk, countSoFar) async {
          // Chunked Drift batch write
          await _vaultDao.insertDictionaryBatch(chunk);

          final progress = (countSoFar / estTotal).clamp(0.0, 0.99);
          final chunkNum = (countSoFar / 1000).ceil();

          state = state.copyWith(
            insertedCount: countSoFar,
            progress: progress,
            statusMessage:
                'Chunk $chunkNum written (${countSoFar.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} cards)...',
          );
        },
      );

      // Step 4: Hydration Complete
      state = state.copyWith(
        status: HydrationStatus.complete,
        progress: 1.0,
        insertedCount: totalCards,
        statusMessage:
            'Hydration complete! ${totalCards.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} MTG cards indexed.',
      );
    } catch (e) {
      state = state.copyWith(
        status: HydrationStatus.error,
        errorMessage: e.toString(),
        statusMessage: 'Hydration interrupted: ${e.toString()}',
      );
    } finally {
      // Clean up temporary file unless it was a caller-provided test fixture
      if (tempFile != null && localFileToHydrate == null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  /// Resets state back to idle.
  void reset() {
    state = const HydrationState();
  }
}

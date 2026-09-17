import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:countr/features/hydration/domain/models/scryfall_ruling.dart';

/// Service for interacting with Scryfall's bulk data API and safely streaming
/// multi-hundred megabyte JSON archives directly to disk to prevent OOM.
class ScryfallService {
  final http.Client _client;

  ScryfallService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the metadata for the latest 'default-cards' bulk data export
  /// and extracts the direct download URI.
  ///
  /// Endpoint: https://api.scryfall.com/bulk-data/default-cards
  Future<String> fetchBulkDownloadUri({
    String endpoint = 'https://api.scryfall.com/bulk-data/default-cards',
  }) async {
    final response = await _client.get(
      Uri.parse(endpoint),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Countr/1.0 (Flutter; Educational Portfolio App)',
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to fetch Scryfall bulk data metadata. HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Scryfall bulk data now defaults to jsonl_download_uri (.jsonl.gz),
    // but gracefully fallback to legacy download_uri or download_url.
    String? downloadUri = (data['jsonl_download_uri'] ??
        data['download_uri'] ??
        data['download_url']) as String?;

    // If querying the list endpoint /bulk-data, search for 'default_cards'
    if (downloadUri == null && data['data'] is List) {
      final list = data['data'] as List;
      final defaultCardsItem = list.firstWhere(
        (item) => item is Map && item['type'] == 'default_cards',
        orElse: () => list.isNotEmpty && list.first is Map ? list.first : null,
      );
      if (defaultCardsItem is Map) {
        downloadUri = (defaultCardsItem['jsonl_download_uri'] ??
            defaultCardsItem['download_uri'] ??
            defaultCardsItem['download_url']) as String?;
      }
    }

    if (downloadUri == null || downloadUri.isEmpty) {
      throw FormatException(
        'Scryfall bulk metadata response missing download URI. Keys received: ${data.keys.toList()}',
      );
    }

    return downloadUri;
  }

  /// Downloads the bulk JSON file from [downloadUri] by streaming chunks
  /// directly to [targetFilePath] on disk without keeping the full payload in RAM.
  ///
  /// Calls [onProgress] with (bytesDownloaded, totalBytes) if provided.
  Future<File> downloadBulkFile({
    required String downloadUri,
    required String targetFilePath,
    void Function(int bytesDownloaded, int? totalBytes)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(downloadUri));
    request.headers['User-Agent'] = 'Countr/1.0 (Flutter; Educational Portfolio App)';
    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      throw HttpException(
        'Failed to download bulk file. HTTP ${streamedResponse.statusCode}',
      );
    }

    final totalBytes = streamedResponse.contentLength;
    var bytesDownloaded = 0;

    final file = File(targetFilePath);
    if (await file.exists()) {
      await file.delete();
    }
    await file.create(recursive: true);

    final sink = file.openWrite();
    try {
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;
        onProgress?.call(bytesDownloaded, totalBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    return file;
  }

  /// Queries official card rulings for the given [scryfallId] from Scryfall:
  /// https://api.scryfall.com/cards/{id}/rulings
  ///
  /// Returns a list of [ScryfallRuling] objects on success (or an empty list if
  /// the card has zero rulings or returned 404).
  /// Returns `null` if a transient network failure, timeout, socket exception,
  /// or non-200/non-404 HTTP status occurred.
  Future<List<ScryfallRuling>?> fetchCardRulings(String scryfallId) async {
    try {
      final uri = Uri.parse('https://api.scryfall.com/cards/$scryfallId/rulings');
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Countr/1.0 (Flutter; Educational Portfolio App)',
        },
      );

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] is List) {
            final list = decoded['data'] as List;
            return list
                .whereType<Map<String, dynamic>>()
                .map((item) => ScryfallRuling.fromJson(item))
                .toList();
          }
          return const [];
        } catch (_) {
          return const [];
        }
      } else if (response.statusCode == 404) {
        return const [];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Searches cards by query using the Scryfall search API:
  /// https://api.scryfall.com/cards/search?q={query}
  /// Returns a list of Scryfall card JSON maps or empty list.
  Future<List<Map<String, dynamic>>?> searchCards(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final uri = Uri.parse(
        'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent(trimmed)}&order=name',
      );
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Countr/1.0 (Flutter; Educational Portfolio App)',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .whereType<Map<String, dynamic>>()
              .take(limit)
              .toList();
          return list;
        }
      }
      return const [];
    } catch (_) {
      return null;
    }
  }

  /// Fetches full card details from Scryfall by [scryfallId] or [name].
  /// Tries /cards/{id} if id is a valid UUID, otherwise /cards/named?exact={name}.
  Future<Map<String, dynamic>?> fetchCardDetails({
    String? scryfallId,
    String? name,
  }) async {
    try {
      Uri? uri;
      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (scryfallId != null && uuidRegex.hasMatch(scryfallId)) {
        uri = Uri.parse('https://api.scryfall.com/cards/$scryfallId');
      } else if (name != null && name.trim().isNotEmpty) {
        final cleanName =
            name.contains(' // ') ? name.split(' // ').first.trim() : name.trim();
        uri = Uri.parse(
            'https://api.scryfall.com/cards/named?exact=${Uri.encodeQueryComponent(cleanName)}');
      }

      if (uri == null) return null;

      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Countr/1.0 (Flutter; Educational Portfolio App)',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

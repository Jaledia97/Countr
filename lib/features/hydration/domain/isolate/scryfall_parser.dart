import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:countr/core/database/app_database.dart';

/// Maps a Scryfall JSON card map into a Drift [VaultItemsCompanion] record.
/// Sets `quantity: 0` to denote a catalog dictionary entry (unowned reference).
VaultItemsCompanion mapScryfallCardToCompanion(Map<String, dynamic> card) {
  final now = DateTime.now();
  final id = (card['id'] as String?) ?? const Uuid().v4();
  final name = (card['name'] as String?) ?? 'Unknown';
  final setName =
      (card['set_name'] as String?) ?? (card['set'] as String?) ?? 'Unknown Set';

  // Robust image URI extraction with double-faced card fallback
  String imageUrl = '';
  if (card['image_uris'] is Map) {
    final uris = card['image_uris'] as Map<String, dynamic>;
    imageUrl = (uris['normal'] ??
            uris['large'] ??
            uris['small'] ??
            uris['png'] ??
            uris['border_crop'] ??
            uris['art_crop'] ??
            '') as String;
  } else if (card['card_faces'] is List &&
      (card['card_faces'] as List).isNotEmpty) {
    final firstFace = (card['card_faces'] as List)[0];
    if (firstFace is Map && firstFace['image_uris'] is Map) {
      final uris = firstFace['image_uris'] as Map<String, dynamic>;
      imageUrl = (uris['normal'] ??
              uris['large'] ??
              uris['small'] ??
              uris['png'] ??
              uris['border_crop'] ??
              uris['art_crop'] ??
              '') as String;
    }
  }

  // Multi-faced card handling: card_faces, oracle_text, back_image_url
  final cardFaces = <Map<String, dynamic>>[];
  if (card['card_faces'] is List) {
    for (final face in (card['card_faces'] as List)) {
      if (face is Map) {
        String faceImg = '';
        if (face['image_uris'] is Map) {
          final u = face['image_uris'] as Map;
          faceImg = (u['normal'] ??
                  u['large'] ??
                  u['small'] ??
                  u['png'] ??
                  u['border_crop'] ??
                  u['art_crop'] ??
                  '')
              ?.toString() ??
              '';
        }
        cardFaces.add({
          'name': face['name']?.toString() ?? '',
          'mana_cost': face['mana_cost']?.toString() ?? '',
          'type_line': face['type_line']?.toString() ?? '',
          'oracle_text': face['oracle_text']?.toString() ?? '',
          if (face['flavor_name'] != null) 'flavor_name': face['flavor_name']?.toString(),
          if (face['power'] != null) 'power': face['power']?.toString(),
          if (face['toughness'] != null) 'toughness': face['toughness']?.toString(),
          if (face['loyalty'] != null) 'loyalty': face['loyalty']?.toString(),
          'image_url': faceImg,
          if (face['image_uris'] is Map) 'image_uris': face['image_uris'],
        });
      }
    }
  }

  String oracleText = (card['oracle_text'] as String?) ?? '';
  if (cardFaces.isNotEmpty) {
    final faceTexts = cardFaces
        .map((f) => (f['oracle_text'] as String?)?.trim() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    if (faceTexts.isNotEmpty) {
      oracleText = faceTexts.join(' // ');
    }
  }

  String? backImageUrl;
  if (cardFaces.length > 1 &&
      cardFaces[1]['image_url'] != null &&
      (cardFaces[1]['image_url'] as String).isNotEmpty) {
    backImageUrl = cardFaces[1]['image_url'] as String;
  }

  // Extract flavor_name (top-level or combined from card_faces)
  String? flavorName = card['flavor_name'] as String?;
  if ((flavorName == null || flavorName.trim().isEmpty) && cardFaces.isNotEmpty) {
    final faceFlavors = cardFaces
        .map((f) => f['flavor_name'] as String?)
        .where((f) => f != null && f.trim().isNotEmpty)
        .map((f) => f!.trim())
        .toList();
    if (faceFlavors.isNotEmpty) {
      flavorName = faceFlavors.join(' // ');
    }
  }
  if (flavorName != null && flavorName.trim().isEmpty) {
    flavorName = null;
  }

  // Resolve top-level image_uris (if top-level is null but face 0 has it)
  dynamic imageUris = card['image_uris'];
  if (imageUris == null && cardFaces.isNotEmpty && cardFaces[0]['image_uris'] != null) {
    imageUris = cardFaces[0]['image_uris'];
  }

  // Market price extraction (USD normal, foil, etched, EUR, EUR foil)
  double marketPrice = 0.0;
  if (card['prices'] is Map) {
    final prices = card['prices'] as Map<String, dynamic>;
    final usd = prices['usd']?.toString();
    final usdFoil = prices['usd_foil']?.toString();
    final usdEtched = prices['usd_etched']?.toString();
    final eur = prices['eur']?.toString();
    final eurFoil = prices['eur_foil']?.toString();
    marketPrice = double.tryParse(usd ?? '') ??
        double.tryParse(usdFoil ?? '') ??
        double.tryParse(usdEtched ?? '') ??
        double.tryParse(eur ?? '') ??
        double.tryParse(eurFoil ?? '') ??
        0.0;
  }

  // Dynamic metadata JSON payload
  final dynamicData = jsonEncode({
    'mana_cost': card['mana_cost'] ?? '',
    'type_line': card['type_line'] ?? '',
    'oracle_text': oracleText,
    'rarity': card['rarity'] ?? '',
    'collector_number': card['collector_number'] ?? '',
    'artist': card['artist'] ?? '',
    'flavor_text': card['flavor_text'] ?? '',
    'flavor_name': flavorName ?? '',
    if (card['power'] != null) 'power': card['power']?.toString(),
    if (card['toughness'] != null) 'toughness': card['toughness']?.toString(),
    if (card['loyalty'] != null) 'loyalty': card['loyalty']?.toString(),
    'scryfall_uri': card['scryfall_uri'] ?? '',
    if (cardFaces.isNotEmpty) 'card_faces': cardFaces,
    if (imageUris is Map) 'image_uris': imageUris,
    'back_image_url': ?backImageUrl,
  });

  return VaultItemsCompanion.insert(
    id: id,
    collectionType: 'mtg',
    name: name,
    flavorName: flavorName != null ? Value(flavorName) : const Value.absent(),
    setOrSeries: setName,
    imageUrl: imageUrl,
    acquiredPrice: 0.0,
    acquiredDate: now,
    quantity: const Value(0), // Catalog/unowned dictionary entry
    condition: 'NM',
    isGraded: const Value(false),
    personalNotes: const Value(null),
    currentMarketPrice: marketPrice,
    lastPriceUpdate: now,
    dynamicData: dynamicData,
  );
}

/// Parameters passed to the spawned background isolate.
class _ParserIsolateParams {
  final SendPort sendPort;
  final String filePath;
  final int chunkSize;

  _ParserIsolateParams({
    required this.sendPort,
    required this.filePath,
    required this.chunkSize,
  });
}

/// Entrypoint executed inside the dedicated background isolate.
void _scryfallStreamParserIsolateEntry(_ParserIsolateParams params) async {
  final mainSendPort = params.sendPort;
  final ackReceivePort = ReceivePort();

  // Send back our ack SendPort so main isolate can send backpressure acknowledgments
  mainSendPort.send(ackReceivePort.sendPort);

  Completer<void>? ackCompleter;
  ackReceivePort.listen((message) {
    if (message == 'ack') {
      ackCompleter?.complete();
    }
  });

  Future<void> sendChunkAndWaitAck(List<VaultItemsCompanion> chunk) async {
    ackCompleter = Completer<void>();
    mainSendPort.send(chunk);
    await ackCompleter!.future;
  }

  final file = File(params.filePath);
  if (!await file.exists()) {
    mainSendPort.send('error:File not found at ${params.filePath}');
    ackReceivePort.close();
    return;
  }

  int totalProcessed = 0;
  var currentChunk = <VaultItemsCompanion>[];

  // Character-by-character JSON streaming state machine
  int depth = 0;
  bool inString = false;
  bool isEscaped = false;
  final buffer = StringBuffer();

  try {
    // Detect gzip by file extension or magic bytes (0x1F, 0x8B)
    bool isGzip = params.filePath.endsWith('.gz');
    if (!isGzip && await file.length() >= 2) {
      try {
        final header = await file.openRead(0, 2).first;
        if (header.length >= 2 && header[0] == 0x1F && header[1] == 0x8B) {
          isGzip = true;
        }
      } catch (_) {}
    }

    final rawStream = file.openRead();
    final Stream<List<int>> byteStream =
        isGzip ? rawStream.transform(gzip.decoder) : rawStream;
    final stream = byteStream.cast<List<int>>().transform(utf8.decoder);

    await for (final textChunk in stream) {
      final len = textChunk.length;
      for (var i = 0; i < len; i++) {
        final codeUnit = textChunk.codeUnitAt(i);

        if (depth == 0) {
          // Look for beginning of card object '{' (0x7B)
          if (codeUnit == 0x7B) {
            depth = 1;
            inString = false;
            isEscaped = false;
            buffer.writeCharCode(codeUnit);
          }
          // Ignore array brackets '[', ']', commas, newlines, and whitespace
          continue;
        }

        // depth > 0: We are inside a card JSON object
        if (inString) {
          if (isEscaped) {
            isEscaped = false;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x5C) {
            // Backslash '\'
            isEscaped = true;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x22) {
            // Quote '"' terminates string
            inString = false;
            buffer.writeCharCode(codeUnit);
          } else {
            buffer.writeCharCode(codeUnit);
          }
        } else {
          // Not inside a string
          if (codeUnit == 0x22) {
            // Quote '"' enters string
            inString = true;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x7B) {
            // Nested '{' increments depth
            depth++;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x7D) {
            // '}' decrements depth
            depth--;
            buffer.writeCharCode(codeUnit);

            if (depth == 0) {
              // Card object completed!
              try {
                final cardMap =
                    jsonDecode(buffer.toString()) as Map<String, dynamic>;
                final companion = mapScryfallCardToCompanion(cardMap);
                currentChunk.add(companion);
                totalProcessed++;
              } catch (_) {
                // Ignore malformed card entry and continue
              }

              buffer.clear();

              // Send batch of 1,000 companions when threshold reached
              if (currentChunk.length >= params.chunkSize) {
                await sendChunkAndWaitAck(currentChunk);
                // Immediately drop references to allow garbage collection
                currentChunk = <VaultItemsCompanion>[];
              }
            }
          } else {
            buffer.writeCharCode(codeUnit);
          }
        }
      }
    }

    // Flush any remaining cards
    if (currentChunk.isNotEmpty) {
      await sendChunkAndWaitAck(currentChunk);
      currentChunk = <VaultItemsCompanion>[];
    }

    mainSendPort.send('done:$totalProcessed');
  } catch (e, stack) {
    mainSendPort.send('error:$e\n$stack');
  } finally {
    ackReceivePort.close();
  }
}

/// Infinitely scalable, low-memory streaming parser for massive bulk card files.
/// Emits chunks of 1,000 items with bidirectional backpressure across isolates.
class ScryfallStreamingParser {
  /// Parses a Scryfall bulk data file at [filePath] in a background isolate.
  /// Batches of [chunkSize] (default 1,000) are emitted via [onChunk].
  ///
  /// Backpressure is strictly maintained: the isolate pauses until [onChunk] finishes
  /// executing the database batch insert, preventing memory ballooning and OOM crashes.
  Future<int> parseFileInIsolate({
    required String filePath,
    required Future<void> Function(
            List<VaultItemsCompanion> chunk, int currentTotal)
        onChunk,
    int chunkSize = 1000,
  }) async {
    final mainReceivePort = ReceivePort();
    SendPort? isolateAckSendPort;
    final completer = Completer<int>();
    var totalProcessedSoFar = 0;

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _scryfallStreamParserIsolateEntry,
        _ParserIsolateParams(
          sendPort: mainReceivePort.sendPort,
          filePath: filePath,
          chunkSize: chunkSize,
        ),
      );

      mainReceivePort.listen((message) async {
        if (message is SendPort) {
          isolateAckSendPort = message;
        } else if (message is List<VaultItemsCompanion>) {
          totalProcessedSoFar += message.length;
          try {
            await onChunk(message, totalProcessedSoFar);
          } finally {
            // Acknowledge chunk processed so isolate can proceed
            isolateAckSendPort?.send('ack');
          }
        } else if (message is String) {
          if (message.startsWith('done:')) {
            final total =
                int.tryParse(message.substring(5)) ?? totalProcessedSoFar;
            if (!completer.isCompleted) completer.complete(total);
          } else if (message.startsWith('error:')) {
            if (!completer.isCompleted) {
              completer.completeError(
                  Exception(message.substring(6)));
            }
          }
        }
      });

      return await completer.future;
    } finally {
      mainReceivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  /// Parses an in-memory stream of bytes (useful for unit tests or memory pipelines).
  Stream<List<VaultItemsCompanion>> parseStream(
    Stream<List<int>> byteStream, {
    int chunkSize = 1000,
    bool isGzip = false,
  }) async* {
    var currentChunk = <VaultItemsCompanion>[];
    int depth = 0;
    bool inString = false;
    bool isEscaped = false;
    final buffer = StringBuffer();

    final Stream<List<int>> effectiveStream =
        isGzip ? byteStream.transform(gzip.decoder) : byteStream;

    await for (final textChunk
        in effectiveStream.cast<List<int>>().transform(utf8.decoder)) {
      final len = textChunk.length;
      for (var i = 0; i < len; i++) {
        final codeUnit = textChunk.codeUnitAt(i);

        if (depth == 0) {
          if (codeUnit == 0x7B) {
            depth = 1;
            inString = false;
            isEscaped = false;
            buffer.writeCharCode(codeUnit);
          }
          continue;
        }

        if (inString) {
          if (isEscaped) {
            isEscaped = false;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x5C) {
            isEscaped = true;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x22) {
            inString = false;
            buffer.writeCharCode(codeUnit);
          } else {
            buffer.writeCharCode(codeUnit);
          }
        } else {
          if (codeUnit == 0x22) {
            inString = true;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x7B) {
            depth++;
            buffer.writeCharCode(codeUnit);
          } else if (codeUnit == 0x7D) {
            depth--;
            buffer.writeCharCode(codeUnit);

            if (depth == 0) {
              try {
                final cardMap =
                    jsonDecode(buffer.toString()) as Map<String, dynamic>;
                currentChunk.add(mapScryfallCardToCompanion(cardMap));
              } catch (_) {}

              buffer.clear();

              if (currentChunk.length >= chunkSize) {
                yield currentChunk;
                currentChunk = <VaultItemsCompanion>[];
              }
            }
          } else {
            buffer.writeCharCode(codeUnit);
          }
        }
      }
    }

    if (currentChunk.isNotEmpty) {
      yield currentChunk;
    }
  }
}

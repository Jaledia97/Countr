import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';

/// Robust parser for Magic: The Gathering preconstructed decks.
/// Supports both MTGJSON `AllDeckFiles` / `DeckList` official schemas
/// and Countr's bundled precon schema (`assets/decks/precons.json`).
class MtgjsonPreconParser {
  /// Parses raw JSON string into a list of [PreconDeckDto]s.
  static List<PreconDeckDto> parseJson(String jsonString) {
    if (jsonString.trim().isEmpty) return [];
    final decoded = jsonDecode(jsonString);
    return parseObject(decoded);
  }

  /// Parses byte data, auto-detecting gzip compression via magic bytes `0x1F, 0x8B`.
  static List<PreconDeckDto> parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) return [];

    final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    final Uint8List payloadBytes = isGzip ? Uint8List.fromList(gzip.decode(bytes)) : bytes;
    final jsonString = utf8.decode(payloadBytes);
    return parseJson(jsonString);
  }

  /// Dynamically traverses decoded JSON structures (List or Map) to extract decks.
  static List<PreconDeckDto> parseObject(dynamic data) {
    if (data == null) return [];

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => parseDeck(Map<String, dynamic>.from(item)))
          .toList();
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      // 1. Check for standard envelope: {"data": ...}
      if (map.containsKey('data')) {
        return parseObject(map['data']);
      }

      // 2. Check for standard decks wrapper: {"decks": [...]}
      if (map.containsKey('decks') && map['decks'] is List) {
        return parseObject(map['decks']);
      }

      // 3. Check if this map is itself a single deck
      if (_isDeckObject(map)) {
        return [parseDeck(map)];
      }

      // 4. Check nested dictionary of decks (e.g. grouped by set code or UUID)
      final extracted = <PreconDeckDto>[];
      for (final value in map.values) {
        if (value is Map || value is List) {
          extracted.addAll(parseObject(value));
        }
      }
      return extracted;
    }

    return [];
  }

  /// Determines if a JSON map represents a single deck.
  static bool _isDeckObject(Map<String, dynamic> map) {
    final hasCards = map.containsKey('cards') && map['cards'] is List;
    final hasMainBoard =
        (map.containsKey('mainBoard') && map['mainBoard'] is List) ||
            (map.containsKey('mainboard') && map['mainboard'] is List);
    final hasCommander = map.containsKey('commander');

    return hasCards || hasMainBoard || hasCommander;
  }

  /// Parses a single deck map into a [PreconDeckDto].
  static PreconDeckDto parseDeck(Map<String, dynamic> map) {
    final name = PreconSafeCast.string(map['name'], fallback: 'Untitled Deck')!;
    final setCode = PreconSafeCast.string(
      map['release_code'] ??
          map['code'] ??
          map['setCode'] ??
          map['set'],
    );

    final originalType = PreconSafeCast.string(map['type']);
    final format = normalizeFormat(
      PreconSafeCast.string(map['format']) ?? originalType,
    );

    // Deterministic ID resolution
    final id = PreconSafeCast.string(map['id']) ??
        buildDeterministicDeckId(setCode: setCode, name: name);

    // Release Date and Year
    DateTime? releaseDate;
    final dateStr = PreconSafeCast.string(map['releaseDate'] ?? map['release_date']);
    if (dateStr != null) {
      releaseDate = DateTime.tryParse(dateStr);
    }

    int? releaseYear = PreconSafeCast.integer(map['release_year'] ?? map['releaseYear']) ??
        releaseDate?.year;

    final description = PreconSafeCast.string(map['description']);

    // Color Identity
    final colorRaw = map['color_identity'] ?? map['colorIdentity'] ?? map['colors'];
    var colorIdentity = PreconSafeCast.stringList(colorRaw)
        .map((e) => e.toUpperCase())
        .toList();

    // Extract Cards across Zones
    final commanderCards = <PreconCardDto>[];
    final mainboardCards = <PreconCardDto>[];
    final sideboardCards = <PreconCardDto>[];

    final isCountrBundled = map.containsKey('cards') && map['cards'] is List;

    if (isCountrBundled) {
      // 1. Process commander object if present
      final commanderRaw = map['commander'];
      if (commanderRaw is Map) {
        commanderCards.add(
          PreconCardDto.fromMap(
            Map<String, dynamic>.from(commanderRaw),
            defaultZone: BoardZone.commander.value,
          ),
        );
      } else if (commanderRaw is List) {
        for (final c in commanderRaw.whereType<Map>()) {
          commanderCards.add(
            PreconCardDto.fromMap(
              Map<String, dynamic>.from(c),
              defaultZone: BoardZone.commander.value,
            ),
          );
        }
      }

      // 2. Process cards array
      final cardsRaw = map['cards'];
      if (cardsRaw is List) {
        for (final cardMap in cardsRaw.whereType<Map>()) {
          final parsedCard = PreconCardDto.fromMap(Map<String, dynamic>.from(cardMap));
          final zone = BoardZone.fromString(parsedCard.boardZone);

          switch (zone) {
            case BoardZone.commander:
              commanderCards.add(parsedCard);
              break;
            case BoardZone.sideboard:
              sideboardCards.add(parsedCard);
              break;
            case BoardZone.mainboard:
            default:
              mainboardCards.add(parsedCard);
              break;
          }
        }
      }
    } else {
      // MTGJSON AllDeckFiles schema (commander, mainBoard, sideBoard)
      final commanderRaw = map['commander'] ?? map['commanders'];
      if (commanderRaw is List) {
        for (final c in commanderRaw.whereType<Map>()) {
          commanderCards.add(
            PreconCardDto.fromMap(
              Map<String, dynamic>.from(c),
              defaultZone: BoardZone.commander.value,
            ),
          );
        }
      } else if (commanderRaw is Map) {
        commanderCards.add(
          PreconCardDto.fromMap(
            Map<String, dynamic>.from(commanderRaw),
            defaultZone: BoardZone.commander.value,
          ),
        );
      }

      final mainboardRaw = map['mainBoard'] ?? map['mainboard'];
      if (mainboardRaw is List) {
        for (final c in mainboardRaw.whereType<Map>()) {
          mainboardCards.add(
            PreconCardDto.fromMap(
              Map<String, dynamic>.from(c),
              defaultZone: BoardZone.mainboard.value,
            ),
          );
        }
      }

      final sideboardRaw = map['sideBoard'] ?? map['sideboard'];
      if (sideboardRaw is List) {
        for (final c in sideboardRaw.whereType<Map>()) {
          sideboardCards.add(
            PreconCardDto.fromMap(
              Map<String, dynamic>.from(c),
              defaultZone: BoardZone.sideboard.value,
            ),
          );
        }
      }
    }

    // Fallback: If color identity wasn't specified, aggregate from commanders / cards
    if (colorIdentity.isEmpty) {
      final colorSet = <String>{};
      for (final card in [...commanderCards, ...mainboardCards]) {
        colorSet.addAll(card.colors);
      }
      colorIdentity = colorSet.toList()..sort();
    }

    final estimatedPrice = PreconSafeCast.float(map['estimated_price'] ?? map['estimatedPrice']);
    final creatorName = PreconSafeCast.string(
      map['creator_name'] ?? map['creatorName'],
      fallback: 'Wizards of the Coast',
    )!;
    final sourceType = PreconSafeCast.string(
      map['source_type'] ?? map['sourceType'],
      fallback: 'official',
    )!;
    final tags = PreconSafeCast.stringList(map['tags']);

    return PreconDeckDto(
      id: id,
      name: name,
      format: format,
      type: originalType,
      description: description,
      releaseDate: releaseDate,
      releaseYear: releaseYear,
      setCode: setCode,
      colorIdentity: colorIdentity,
      commanderCards: commanderCards,
      mainboardCards: mainboardCards,
      sideboardCards: sideboardCards,
      estimatedPrice: estimatedPrice,
      creatorName: creatorName,
      sourceType: sourceType,
      tags: tags,
    );
  }

  /// Normalizes arbitrary format and deck type strings to canonical Countr formats.
  static String normalizeFormat(String? typeOrFormat) {
    if (typeOrFormat == null || typeOrFormat.trim().isEmpty) {
      return 'Commander';
    }
    final s = typeOrFormat.trim().toLowerCase();
    if (s.contains('commander') || s.contains('edh') || s == 'brawl') {
      return 'Commander';
    }
    if (s.contains('challenger')) {
      return 'Challenger';
    }
    if (s.contains('starter') ||
        s.contains('intro') ||
        s.contains('welcome') ||
        s.contains('planeswalker deck')) {
      return 'Starter Kit';
    }
    if (s.contains('duel deck') || s.contains('duel decks')) {
      return 'Duel Decks';
    }
    if (s.contains('planechase')) {
      return 'Planechase';
    }
    if (s.contains('archenemy')) {
      return 'Archenemy';
    }
    if (s == 'modern') return 'Modern';
    if (s == 'standard') return 'Standard';
    if (s == 'pioneer') return 'Pioneer';
    if (s == 'legacy') return 'Legacy';
    if (s == 'vintage') return 'Vintage';
    if (s == 'pauper') return 'Pauper';

    // Capitalize as default
    return typeOrFormat.trim();
  }

  /// Fast, deterministic 32-bit FNV-1a hash formatted as an 8-character hex string.
  /// Guarantees identical output across Dart VM, AOT, Web, and all SDK versions.
  static String _fnv1a32Hex(String input) {
    var hash = 0x811c9dc5; // 32-bit FNV offset basis (2166136261)
    final bytes = utf8.encode(input);
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff; // 32-bit FNV prime (16777619)
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Generates a deterministic deck ID from set code and deck name.
  static String buildDeterministicDeckId({
    String? setCode,
    required String name,
  }) {
    final cleanSet = setCode?.trim().toLowerCase();
    final prefix = (cleanSet != null && cleanSet.isNotEmpty)
        ? cleanSet
        : 'mtg';
    var slug = slugify(name);
    if (slug.isEmpty) {
      slug = 'deck-${_fnv1a32Hex(name)}';
    }
    return 'precon-$prefix-$slug';
  }

  /// URL/ID-friendly slugification helper.
  /// If the text contains no ASCII alphanumeric characters (e.g. CJK, Cyrillic, emoji),
  /// falls back to a deterministic 8-character hex hash prefixed with [fallbackPrefix].
  static String slugify(String text, {String fallbackPrefix = 'deck'}) {
    final clean = text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r"^-+|-+$"), '');
    if (clean.isNotEmpty) {
      return clean;
    }
    final hash = _fnv1a32Hex(text);
    return '$fallbackPrefix-$hash';
  }
}

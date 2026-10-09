import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';

/// Utility providing robust, zero-crash type coercion for dynamic map payloads.
abstract final class PreconSafeCast {
  /// Safely converts any dynamic value to a trimmed string.
  /// Returns [fallback] if null, empty, or non-primitive collection (Map/List).
  static String? string(dynamic value, {String? fallback}) {
    if (value == null) return fallback;
    if (value is Map || value is List) return fallback;
    final str = value.toString().trim();
    return str.isNotEmpty ? str : fallback;
  }

  /// Safely converts dynamic value to an integer.
  /// Supports `int`, `num`, and numeric strings (e.g. "4", "4.0").
  static int? integer(dynamic value, {int? fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.isFinite ? value.toInt() : fallback;
    if (value is String) {
      final trimmed = value.trim();
      final parsedInt = int.tryParse(trimmed);
      if (parsedInt != null) return parsedInt;
      final parsedDouble = double.tryParse(trimmed);
      if (parsedDouble != null && parsedDouble.isFinite) return parsedDouble.toInt();
    }
    return fallback;
  }

  /// Safely converts dynamic value to a double.
  /// Supports `double`, `num`, and strings (including currency signs like "$3.50").
  static double? float(dynamic value, {double? fallback}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.trim().replaceFirst(RegExp(r'^\$'), '');
      final parsed = double.tryParse(sanitized);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  /// Safely converts dynamic value to a boolean.
  /// Supports `bool`, `num` (1/0), and strings ("true", "false", "foil", "nonfoil").
  static bool? boolean(dynamic value, {bool? fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'foil') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'nonfoil') return false;
    }
    return fallback;
  }

  /// Safely casts or converts any map to `Map<String, dynamic>`.
  static Map<String, dynamic>? stringMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k?.toString() ?? '', v));
    }
    return null;
  }

  /// Safely extracts a List of trimmed non-empty Strings from List or comma-separated String.
  static List<String> stringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      final parts = value.split(',');
      return parts
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

/// DTO representing an individual card within a preconstructed deck.
@immutable
class PreconCardDto {
  final String scryfallId;
  final String? oracleId;
  final String? uuid;
  final String name;
  final int count;
  final String? setCode;
  final String? number;
  final List<String> finishes;
  final bool isFoil;
  final String layout;
  final String? imageUrl;
  final String? artCropUrl;
  final String? manaCost;
  final double? cmc;
  final String? typeLine;
  final List<String> colors;
  final double? price;
  final String boardZone;
  final Map<String, dynamic> rawDynamicData;

  const PreconCardDto({
    required this.scryfallId,
    this.oracleId,
    this.uuid,
    required this.name,
    this.count = 1,
    this.setCode,
    this.number,
    this.finishes = const ['nonfoil'],
    this.isFoil = false,
    this.layout = 'normal',
    this.imageUrl,
    this.artCropUrl,
    this.manaCost,
    this.cmc,
    this.typeLine,
    this.colors = const [],
    this.price,
    this.boardZone = 'Mainboard',
    this.rawDynamicData = const {},
  });

  bool get isCommander =>
      boardZone.toLowerCase() == BoardZone.commander.value.toLowerCase() ||
      boardZone.toLowerCase() == 'commander';

  bool get isSideboard =>
      boardZone.toLowerCase() == BoardZone.sideboard.value.toLowerCase() ||
      boardZone.toLowerCase() == 'sideboard';

  bool get isMainboard =>
      boardZone.toLowerCase() == BoardZone.mainboard.value.toLowerCase() ||
      boardZone.toLowerCase() == 'mainboard';

  /// Serializes dynamicData map for insertion into `vault_items.dynamicData`.
  Map<String, dynamic> toDynamicDataMap() {
    final merged = Map<String, dynamic>.from(rawDynamicData);
    merged['name'] ??= name;
    if (manaCost != null) merged['mana_cost'] ??= manaCost;
    if (typeLine != null) merged['type_line'] ??= typeLine;
    if (cmc != null) merged['cmc'] ??= cmc;
    if (colors.isNotEmpty) merged['colors'] ??= colors;
    merged['scryfall_id'] ??= scryfallId;
    if (oracleId != null) merged['oracle_id'] ??= oracleId;

    // Strict layout enforcement: never allow non-playable art_series layout into dynamicData
    if (layout == 'art_series' || merged['layout'] == 'art_series') {
      merged['layout'] = 'normal';
    } else {
      merged['layout'] = layout;
    }

    if (setCode != null) {
      merged['set'] ??= setCode!.toLowerCase();
      merged['set_code'] ??= setCode!.toLowerCase();
    }
    if (number != null) merged['collector_number'] ??= number;
    merged['finishes'] ??= finishes;
    merged['finish'] ??= isFoil ? 'foil' : 'nonfoil';

    // Strict image URIs enforcement: never allow art_series URLs to persist in dynamicData
    final existingUris = merged['image_uris'];
    final bool hasArtSeriesUrl = existingUris is Map &&
        existingUris.values.any((u) => u != null && u.toString().contains('art_series'));

    if (existingUris == null || existingUris is! Map || hasArtSeriesUrl) {
      merged['image_uris'] = {
        'small': imageUrl ?? '',
        'normal': imageUrl ?? '',
        'large': imageUrl ?? '',
        'art_crop': artCropUrl ?? '',
      };
    } else {
      final mapUris = Map<String, dynamic>.from(existingUris);
      mapUris['small'] ??= imageUrl ?? '';
      mapUris['normal'] ??= imageUrl ?? '';
      mapUris['large'] ??= imageUrl ?? '';
      mapUris['art_crop'] ??= artCropUrl ?? '';
      merged['image_uris'] = mapUris;
    }

    // Sanitize card_faces if art_series is detected in faces
    if (merged['card_faces'] is List) {
      final faces = merged['card_faces'] as List;
      if (faces.any((f) => f.toString().contains('art_series'))) {
        merged.remove('card_faces');
      }
    }

    return merged;
  }

  /// Serializes to JSON string for SQLite storage.
  String toDynamicDataJson() => jsonEncode(toDynamicDataMap());

  /// Creates a [PreconCardDto] from a map representation.
  factory PreconCardDto.fromMap(
    Map<String, dynamic> map, {
    String defaultZone = 'Mainboard',
  }) {
    final rawName = PreconSafeCast.string(map['name'], fallback: 'Unknown Card')!;
    final identifiers = PreconSafeCast.stringMap(map['identifiers']);

    final scryfallId = PreconSafeCast.string(
      identifiers?['scryfallId'] ??
          map['scryfall_id'] ??
          map['scryfallId'] ??
          map['id'] ??
          map['uuid'],
      fallback: '',
    )!;

    final oracleId = PreconSafeCast.string(
      identifiers?['scryfallOracleId'] ??
          map['oracle_id'] ??
          map['oracleId'],
    );

    final uuid = PreconSafeCast.string(map['uuid'] ?? identifiers?['mtgjsonId']);
    final count = PreconSafeCast.integer(map['count'] ?? map['quantity'], fallback: 1)!;
    final setCode = PreconSafeCast.string(map['setCode'] ?? map['set_code'] ?? map['set']);
    final number = PreconSafeCast.string(map['number'] ?? map['collector_number'] ?? map['collectorNumber']);

    final finishesList = PreconSafeCast.stringList(map['finishes']);
    final finishes = finishesList.isNotEmpty ? finishesList : const ['nonfoil'];

    final bool isFoil = PreconSafeCast.boolean(map['isFoil']) ??
        PreconSafeCast.boolean(map['is_foil']) ??
        (map['finish'] != null
            ? PreconSafeCast.string(map['finish'])?.toLowerCase() == 'foil'
            : finishes.contains('foil'));

    final rawLayout = PreconSafeCast.string(map['layout'])?.toLowerCase();
    final typeLineRaw = PreconSafeCast.string(map['type_line'] ?? map['typeLine'] ?? map['type']);
    final typeLineLower = typeLineRaw?.toLowerCase();
    final nameLower = rawName.toLowerCase();
    final setCodeLower = setCode?.toLowerCase();

    final rawImageUrl = PreconSafeCast.string(map['image_url'] ?? map['imageUrl']);
    final rawArtCropUrl = PreconSafeCast.string(map['art_crop_url'] ?? map['artCropUrl']);

    // Pre-extract dynamic data to check for nested art_series indicators
    Map<String, dynamic> dynData = {};
    final rawDyn = map['dynamicData'] ?? map['dynamic_data'];
    if (rawDyn is Map) {
      dynData = Map<String, dynamic>.from(rawDyn);
    } else if (rawDyn is String && rawDyn.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDyn);
        if (decoded is Map) {
          dynData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    final dynLayout = dynData['layout']?.toString().toLowerCase();

    // Enforce art series exclusion (Requirement R5):
    // Detects explicit layout, nested dynamicData layout, type line variants ("Art Card", "Art Series"),
    // name suffixes ("// ... Art Card", "(Art Card)"), Scryfall CDN art_series URLs,
    // and art series set codes (e.g. AMH1, AMH2, AAFR, AMID, ASTX).
    final isArtSeries = rawLayout == 'art_series' ||
        dynLayout == 'art_series' ||
        (typeLineLower != null &&
            (typeLineLower.contains('art series') || typeLineLower.contains('art card'))) ||
        nameLower.contains('art series') ||
        nameLower.contains('art card') ||
        (rawImageUrl != null && rawImageUrl.contains('art_series')) ||
        (rawArtCropUrl != null && rawArtCropUrl.contains('art_series')) ||
        (setCodeLower != null &&
            setCodeLower.length >= 4 &&
            setCodeLower.startsWith('a') &&
            RegExp(r'^a[a-z0-9]{3,4}$').hasMatch(setCodeLower));

    final effectiveLayout = isArtSeries ? 'normal' : (rawLayout ?? 'normal');

    // Clean name: isolate front playable face before // or remove (Art Card) / (Art Series) suffixes
    String cleanName = rawName;
    if (isArtSeries) {
      cleanName = cleanName.contains('//') ? cleanName.split('//').first.trim() : cleanName.trim();
      cleanName = cleanName
          .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
          .trim();
    }
    final name = isArtSeries && cleanName.isNotEmpty ? cleanName : rawName;

    String? imageUrl = rawImageUrl;
    String? artCropUrl = rawArtCropUrl;

    if (isArtSeries) {
      imageUrl = CountrCachedImage.buildScryfallNamedUrl(name, version: 'normal');
      artCropUrl = CountrCachedImage.buildScryfallNamedUrl(name, version: 'art_crop');

      // Sanitize rawDynamicData at ingestion time
      dynData['layout'] = 'normal';
      dynData['image_uris'] = {
        'small': imageUrl,
        'normal': imageUrl,
        'large': imageUrl,
        'art_crop': artCropUrl,
      };
      dynData.remove('card_faces');
    } else {
      if (imageUrl == null && scryfallId.length > 2) {
        imageUrl =
            'https://cards.scryfall.io/normal/front/${scryfallId[0]}/${scryfallId[1]}/$scryfallId.jpg';
      }
      if (artCropUrl == null && scryfallId.length > 2) {
        artCropUrl =
            'https://cards.scryfall.io/art_crop/front/${scryfallId[0]}/${scryfallId[1]}/$scryfallId.jpg';
      }
    }

    final manaCost = PreconSafeCast.string(map['mana_cost'] ?? map['manaCost']);
    final cmc = PreconSafeCast.float(map['cmc'] ?? map['manaValue']);
    final colors = PreconSafeCast.stringList(map['colors']);
    final price = PreconSafeCast.float(map['price']);

    // Determine zone
    String boardZone = defaultZone;
    final explicitZone = PreconSafeCast.string(map['board_zone'] ?? map['boardZone']);
    if (explicitZone != null) {
      boardZone = BoardZone.fromString(explicitZone).value;
    } else if (PreconSafeCast.boolean(map['is_commander']) == true ||
        PreconSafeCast.boolean(map['isCommander']) == true) {
      boardZone = BoardZone.commander.value;
    }

    return PreconCardDto(
      scryfallId: scryfallId,
      oracleId: oracleId,
      uuid: uuid,
      name: name,
      count: count,
      setCode: setCode,
      number: number,
      finishes: finishes,
      isFoil: isFoil,
      layout: effectiveLayout,
      imageUrl: imageUrl,
      artCropUrl: artCropUrl,
      manaCost: manaCost,
      cmc: cmc,
      typeLine: typeLineRaw,
      colors: colors,
      price: price,
      boardZone: boardZone,
      rawDynamicData: dynData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scryfall_id': scryfallId,
      'oracle_id': oracleId,
      'uuid': uuid,
      'name': name,
      'count': count,
      'set_code': setCode,
      'number': number,
      'finishes': finishes,
      'is_foil': isFoil,
      'layout': layout,
      'image_url': imageUrl,
      'art_crop_url': artCropUrl,
      'mana_cost': manaCost,
      'cmc': cmc,
      'type_line': typeLine,
      'colors': colors,
      'price': price,
      'board_zone': boardZone,
      'raw_dynamic_data': rawDynamicData,
    };
  }

  PreconCardDto copyWith({
    String? scryfallId,
    String? oracleId,
    String? uuid,
    String? name,
    int? count,
    String? setCode,
    String? number,
    List<String>? finishes,
    bool? isFoil,
    String? layout,
    String? imageUrl,
    String? artCropUrl,
    String? manaCost,
    double? cmc,
    String? typeLine,
    List<String>? colors,
    double? price,
    String? boardZone,
    Map<String, dynamic>? rawDynamicData,
  }) {
    return PreconCardDto(
      scryfallId: scryfallId ?? this.scryfallId,
      oracleId: oracleId ?? this.oracleId,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      count: count ?? this.count,
      setCode: setCode ?? this.setCode,
      number: number ?? this.number,
      finishes: finishes ?? this.finishes,
      isFoil: isFoil ?? this.isFoil,
      layout: layout ?? this.layout,
      imageUrl: imageUrl ?? this.imageUrl,
      artCropUrl: artCropUrl ?? this.artCropUrl,
      manaCost: manaCost ?? this.manaCost,
      cmc: cmc ?? this.cmc,
      typeLine: typeLine ?? this.typeLine,
      colors: colors ?? this.colors,
      price: price ?? this.price,
      boardZone: boardZone ?? this.boardZone,
      rawDynamicData: rawDynamicData ?? this.rawDynamicData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreconCardDto &&
          runtimeType == other.runtimeType &&
          scryfallId == other.scryfallId &&
          boardZone == other.boardZone &&
          count == other.count &&
          name == other.name;

  @override
  int get hashCode => Object.hash(scryfallId, boardZone, count, name);

  @override
  String toString() =>
      'PreconCardDto(name: $name, scryfallId: $scryfallId, count: $count, zone: $boardZone)';
}

/// DTO representing a full preconstructed deck.
@immutable
class PreconDeckDto {
  final String id;
  final String name;
  final String format;
  final String? type;
  final String? description;
  final DateTime? releaseDate;
  final int? releaseYear;
  final String? setCode;
  final List<String> colorIdentity;
  final List<PreconCardDto> commanderCards;
  final List<PreconCardDto> mainboardCards;
  final List<PreconCardDto> sideboardCards;
  final double? estimatedPrice;
  final String creatorName;
  final String sourceType;
  final List<String> tags;

  const PreconDeckDto({
    required this.id,
    required this.name,
    required this.format,
    this.type,
    this.description,
    this.releaseDate,
    this.releaseYear,
    this.setCode,
    this.colorIdentity = const [],
    this.commanderCards = const [],
    this.mainboardCards = const [],
    this.sideboardCards = const [],
    this.estimatedPrice,
    this.creatorName = 'Wizards of the Coast',
    this.sourceType = 'official',
    this.tags = const [],
  });

  /// All cards aggregated across all zones.
  List<PreconCardDto> get allCards => [
        ...commanderCards,
        ...mainboardCards,
        ...sideboardCards,
      ];

  /// Total physical card count (sum of all counts).
  int get totalCardCount =>
      allCards.fold<int>(0, (sum, card) => sum + card.count);

  /// Primary commander card if present.
  PreconCardDto? get primaryCommander =>
      commanderCards.isNotEmpty ? commanderCards.first : null;

  /// Computed deck price based on individual card prices.
  double get computedPrice => allCards.fold<double>(
        0.0,
        (sum, card) => sum + ((card.price ?? 0.0) * card.count),
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'format': format,
      'type': type,
      'description': description,
      'release_date': releaseDate?.toIso8601String(),
      'release_year': releaseYear,
      'release_code': setCode,
      'color_identity': colorIdentity,
      'commander': primaryCommander?.toMap(),
      'commanders': commanderCards.map((c) => c.toMap()).toList(),
      'mainboard': mainboardCards.map((c) => c.toMap()).toList(),
      'sideboard': sideboardCards.map((c) => c.toMap()).toList(),
      'estimated_price': estimatedPrice ?? computedPrice,
      'creator_name': creatorName,
      'source_type': sourceType,
      'tags': tags,
    };
  }

  PreconDeckDto copyWith({
    String? id,
    String? name,
    String? format,
    String? type,
    String? description,
    DateTime? releaseDate,
    int? releaseYear,
    String? setCode,
    List<String>? colorIdentity,
    List<PreconCardDto>? commanderCards,
    List<PreconCardDto>? mainboardCards,
    List<PreconCardDto>? sideboardCards,
    double? estimatedPrice,
    String? creatorName,
    String? sourceType,
    List<String>? tags,
  }) {
    return PreconDeckDto(
      id: id ?? this.id,
      name: name ?? this.name,
      format: format ?? this.format,
      type: type ?? this.type,
      description: description ?? this.description,
      releaseDate: releaseDate ?? this.releaseDate,
      releaseYear: releaseYear ?? this.releaseYear,
      setCode: setCode ?? this.setCode,
      colorIdentity: colorIdentity ?? this.colorIdentity,
      commanderCards: commanderCards ?? this.commanderCards,
      mainboardCards: mainboardCards ?? this.mainboardCards,
      sideboardCards: sideboardCards ?? this.sideboardCards,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      creatorName: creatorName ?? this.creatorName,
      sourceType: sourceType ?? this.sourceType,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreconDeckDto &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PreconDeckDto(id: $id, name: $name, format: $format, totalCards: $totalCardCount)';
}

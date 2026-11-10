// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';

/// Service responsible for fetching live MTGJSON v5 preconstructed decks,
/// comparing remote catalog releases against SQLite, and downloading / seeding
/// newly released WotC and Secret Lair precons in the background.
class MtgjsonPreconSyncService {
  static const String deckListUrl = 'https://mtgjson.com/api/v5/DeckList.json';
  static const String decksBaseUrl = 'https://mtgjson.com/api/v5/decks';

  /// Target WotC official preconstructed deck types.
  static const Set<String> targetWotcPreconTypes = {
    'Commander Deck',
    'MTGO Commander Deck',
    'Historic Brawl Precon Deck',
    'Brawl Deck',
    'Starter Kit',
    'Arena Starter Kit',
    'Starter Deck',
    'Arena Starter Deck',
    'Spellslinger Starter Kit',
    'Welcome Deck',
    'Challenger Deck',
    'Pioneer Challenger Deck',
    'Duel Deck',
    'MTGO Duel Deck',
    'Duel Of The Planeswalkers Deck',
    'Planechase Deck',
    'Archenemy Deck',
    'Theme Deck',
    'Intro Pack',
    'MTGO Theme Deck',
    'Event Deck',
    'Modern Event Deck',
    'Planeswalker Deck',
    'Guild Kit',
    'Clash Pack',
    'Game Night Deck',
  };

  /// Determines whether a DeckList.json entry matches official WotC precons
  /// or Secret Lair preconstructed drops.
  static bool isTargetPrecon(Map<String, dynamic> entry) {
    final fileName = entry['fileName']?.toString() ?? '';
    if (fileName.trim().isEmpty) return false;

    final type = entry['type']?.toString() ?? '';
    final code = entry['code']?.toString().toUpperCase() ?? '';
    final name = entry['name']?.toString() ?? '';
    final lowerName = name.toLowerCase();

    if (targetWotcPreconTypes.contains(type)) return true;

    // Secret Lair Drop decks
    if (type.contains('Secret Lair') ||
        code == 'SLD' ||
        lowerName.contains('secret lair')) {
      return true;
    }

    // Name-based precon matching for generic types (e.g. Boxed Set)
    if (lowerName.contains('commander deck') ||
        lowerName.contains('challenger deck') ||
        lowerName.contains('starter kit') ||
        lowerName.contains('game night')) {
      return true;
    }

    return false;
  }

  /// Extracts the set of known MTGJSON deck fileNames stored locally in `explore_decks`.
  static Future<Set<String>> getLocalPreconFileNames(AppDatabase db) async {
    final rows = await (db.select(db.exploreDecks)
          ..where((t) => t.sourceType.equals('official') & t.isDeleted.equals(false)))
        .get();

    final fileNames = <String>{};
    for (final row in rows) {
      if (row.tags != null && row.tags!.isNotEmpty) {
        for (final tag in row.tags!.split(',')) {
          final trimmed = tag.trim();
          if (trimmed.startsWith('fn:')) {
            fileNames.add(trimmed.substring(3).trim());
          } else if (trimmed.startsWith('fileName:')) {
            fileNames.add(trimmed.substring(9).trim());
          }
        }
      }
    }
    return fileNames;
  }

  /// Checks for newly released WotC and Secret Lair precons on MTGJSON,
  /// downloads missing deck files, parses & sanitizes them in a background isolate,
  /// and batch inserts them into SQLite.
  ///
  /// Returns the number of newly ingested decks.
  static Future<int> checkAndSyncNewlyReleasedPrecons(
    AppDatabase db, {
    http.Client? httpClient,
    int maxDecksToDownload = 50,
  }) async {
    if (kIsWeb) return 0;
    if (Platform.environment.containsKey('FLUTTER_TEST') && httpClient == null) {
      // Avoid firing unmocked network calls during unit test execution
      return 0;
    }

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      debugPrint('[MtgjsonPreconSyncService] Checking $deckListUrl for new precons...');
      final response = await client.get(
        Uri.parse(deckListUrl),
        headers: {'User-Agent': 'Countr/1.0 (Live Precon Sync)'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[MtgjsonPreconSyncService] Remote DeckList returned HTTP ${response.statusCode}');
        return 0;
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> deckListData = decoded is Map<String, dynamic> && decoded.containsKey('data')
          ? decoded['data'] as List<dynamic>
          : (decoded is List ? decoded : []);

      final localFileNames = await getLocalPreconFileNames(db);
      final newEntries = <Map<String, dynamic>>[];

      for (final item in deckListData) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final fileName = map['fileName']?.toString();
        if (fileName == null || fileName.isEmpty) continue;

        if (isTargetPrecon(map) && !localFileNames.contains(fileName)) {
          newEntries.add(map);
        }
      }

      if (newEntries.isEmpty) {
        debugPrint('[MtgjsonPreconSyncService] Local precon catalog is fully up to date.');
        return 0;
      }

      debugPrint('[MtgjsonPreconSyncService] Discovered ${newEntries.length} new precons to ingest.');

      // Sort newest first
      newEntries.sort((a, b) {
        final dateA = a['releaseDate']?.toString() ?? '';
        final dateB = b['releaseDate']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });

      final entriesToSync = newEntries.take(maxDecksToDownload).toList();
      final newRawDecks = <Map<String, dynamic>>[];

      for (final entry in entriesToSync) {
        final fileName = entry['fileName'] as String;
        try {
          final deckUrl = '$decksBaseUrl/$fileName.json';
          final deckResp = await client.get(
            Uri.parse(deckUrl),
            headers: {'User-Agent': 'Countr/1.0 (Live Precon Sync)'},
          ).timeout(const Duration(seconds: 10));

          if (deckResp.statusCode == 200) {
            final rawDeckMap = await parseAndSanitizeDeckInIsolate(deckResp.body, fileName);
            if (rawDeckMap != null) {
              newRawDecks.add(rawDeckMap);
            }
          }
        } catch (e) {
          debugPrint('[MtgjsonPreconSyncService] Failed to download precon $fileName: $e');
        }
      }

      if (newRawDecks.isNotEmpty) {
        await ExploreSeederService.seedFromRawDecks(db, newRawDecks);
        debugPrint('[MtgjsonPreconSyncService] Successfully seeded ${newRawDecks.length} new precons into SQLite.');
      }

      return newRawDecks.length;
    } catch (e) {
      debugPrint('[MtgjsonPreconSyncService] Precon auto-sync failed: $e');
      return 0;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Parses deck JSON and prepares raw deck map with sanitized cards off the UI thread.
  static Future<Map<String, dynamic>?> parseAndSanitizeDeckInIsolate(
    String jsonString,
    String fileName,
  ) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future.value(_parseAndSanitizeDeck(jsonString, fileName));
    }
    return Isolate.run(() => _parseAndSanitizeDeck(jsonString, fileName));
  }

  static Map<String, dynamic>? _parseAndSanitizeDeck(String jsonString, String fileName) {
    try {
      final decoded = jsonDecode(jsonString);
      final rawDeck = decoded is Map<String, dynamic> && decoded.containsKey('data')
          ? decoded['data'] as Map<String, dynamic>
          : decoded as Map<String, dynamic>;

      final parsed = MtgjsonPreconParser.parseObject(rawDeck);
      if (parsed.isEmpty) return null;

      final dto = parsed.first;
      return _dtoToRawDeck(dto, fileName);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _dtoToRawDeck(PreconDeckDto dto, String fileName) {
    final primaryCmdr = dto.primaryCommander;
    Map<String, dynamic>? commanderMap;
    if (primaryCmdr != null) {
      commanderMap = {
        'name': primaryCmdr.name,
        'scryfall_id': primaryCmdr.scryfallId,
        'oracle_id': primaryCmdr.oracleId,
        'count': primaryCmdr.count,
        'board_zone': 'Commander',
        'mana_cost': primaryCmdr.manaCost,
        'cmc': primaryCmdr.cmc,
        'type_line': primaryCmdr.typeLine,
        'colors': primaryCmdr.colors,
        'image_url': primaryCmdr.imageUrl,
        'art_crop_url': primaryCmdr.artCropUrl,
        'price': primaryCmdr.price ?? 0.50,
        'is_commander': true,
      };
    }

    final cards = <Map<String, dynamic>>[];
    if (dto.commanderCards.length > 1) {
      for (int i = 1; i < dto.commanderCards.length; i++) {
        final c = dto.commanderCards[i];
        cards.add({
          'name': c.name,
          'scryfall_id': c.scryfallId,
          'oracle_id': c.oracleId,
          'count': c.count,
          'board_zone': 'Commander',
          'mana_cost': c.manaCost,
          'cmc': c.cmc,
          'type_line': c.typeLine,
          'colors': c.colors,
          'image_url': c.imageUrl,
          'art_crop_url': c.artCropUrl,
          'price': c.price ?? 0.50,
          'is_commander': true,
        });
      }
    }

    for (final c in dto.mainboardCards) {
      cards.add({
        'name': c.name,
        'scryfall_id': c.scryfallId,
        'oracle_id': c.oracleId,
        'count': c.count,
        'board_zone': 'Mainboard',
        'mana_cost': c.manaCost,
        'cmc': c.cmc,
        'type_line': c.typeLine,
        'colors': c.colors,
        'image_url': c.imageUrl,
        'art_crop_url': c.artCropUrl,
        'price': c.price ?? 0.50,
        'is_commander': false,
      });
    }

    for (final c in dto.sideboardCards) {
      cards.add({
        'name': c.name,
        'scryfall_id': c.scryfallId,
        'oracle_id': c.oracleId,
        'count': c.count,
        'board_zone': 'Sideboard',
        'mana_cost': c.manaCost,
        'cmc': c.cmc,
        'type_line': c.typeLine,
        'colors': c.colors,
        'image_url': c.imageUrl,
        'art_crop_url': c.artCropUrl,
        'price': c.price ?? 0.50,
        'is_commander': false,
      });
    }

    final featuredCat = _deriveFeaturedCategory(dto.format, dto.type);

    return {
      'id': dto.id,
      'name': dto.name,
      'format': dto.format,
      'type': dto.type,
      'source_type': 'official',
      'creator_name': 'Wizards of the Coast',
      'description': dto.description ??
          'Official Magic: The Gathering preconstructed ${dto.format} deck (${dto.name}).',
      'release_code': dto.setCode,
      'release_date': dto.releaseDate?.toIso8601String(),
      'release_year': dto.releaseYear,
      'color_identity': dto.colorIdentity,
      'card_count': dto.totalCardCount,
      'estimated_price': dto.estimatedPrice ?? dto.computedPrice,
      'upvotes': 15,
      'downvotes': 1,
      'score': 14,
      'featured_category': featuredCat,
      'tags': 'fn:$fileName,official,wotc,${dto.format.toLowerCase()}',
      'commander': commanderMap,
      'cards': cards,
    };
  }

  static String _deriveFeaturedCategory(String format, String? rawType) {
    final lowerFormat = format.toLowerCase();
    final lowerType = rawType?.toLowerCase() ?? '';

    if (lowerFormat.contains('commander') || lowerType.contains('commander')) {
      return 'Suggested Commanders';
    }
    if (lowerFormat.contains('standard') || lowerType.contains('standard')) {
      return 'Popular Standard Decks';
    }
    if (lowerFormat.contains('modern') || lowerType.contains('modern')) {
      return 'Top Modern Decks';
    }
    if (lowerFormat.contains('pioneer') || lowerType.contains('pioneer')) {
      return 'Pioneer Showdown';
    }
    return 'Hot New Precons';
  }
}

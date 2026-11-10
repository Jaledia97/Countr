// Copyright (c) 2026 Countr. All rights reserved.
// MTGJSON v5 Preconstructed Decks Ingestion & Bundling Tool.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String defaultDeckListUrl = 'https://mtgjson.com/api/v5/DeckList.json';
const String defaultDecksBaseUrl = 'https://mtgjson.com/api/v5/decks';
const String defaultOutputPath = 'assets/data/official_precons.json.gz';

const Set<String> targetPreconTypes = {
  'Commander Deck',
  'MTGO Commander Deck',
  'Historic Brawl Precon Deck',
  'Brawl Deck',
  'Challenger Deck',
  'Pioneer Challenger Deck',
  'Starter Kit',
  'Arena Starter Kit',
  'Starter Deck',
  'Arena Starter Deck',
  'Spellslinger Starter Kit',
  'Welcome Deck',
  'Duel Deck',
  'MTGO Duel Deck',
  'Duel Of The Planeswalkers Deck',
  'Theme Deck',
  'Intro Pack',
  'MTGO Theme Deck',
  'Planeswalker Deck',
  'Planechase Deck',
  'Archenemy Deck',
  'Game Night Deck',
  'Event Deck',
  'Modern Event Deck',
  'Guild Kit',
  'Clash Pack',
};

const int defaultTargetCount = 550;
const int maxConcurrency = 25;

void main(List<String> args) async {
  int targetCount = defaultTargetCount;
  for (final arg in args) {
    if (arg.startsWith('--target=')) {
      targetCount = int.tryParse(arg.substring(9)) ?? defaultTargetCount;
    }
  }

  stdout.writeln('====================================================');
  stdout.writeln('[seed_all_precons] MTGJSON v5 Precon Ingestion Pipeline');
  stdout.writeln('[seed_all_precons] Target Precon Count: $targetCount+');
  stdout.writeln('[seed_all_precons] Output: $defaultOutputPath');
  stdout.writeln('====================================================');

  final client = http.Client();
  try {
    stdout.writeln('[seed_all_precons] Fetching MTGJSON DeckList.json...');
    final deckListResp = await client.get(
      Uri.parse(defaultDeckListUrl),
      headers: {'User-Agent': 'Countr/1.0 (MTGJSON Ingestion)'},
    ).timeout(const Duration(seconds: 30));

    if (deckListResp.statusCode != 200) {
      stderr.writeln('Failed to fetch DeckList: HTTP ${deckListResp.statusCode}');
      exit(1);
    }

    final deckListData = jsonDecode(deckListResp.body)['data'] as List;
    final matchingDecks = deckListData
        .where((d) => targetPreconTypes.contains(d['type']))
        .toList();

    stdout.writeln('[seed_all_precons] Found ${matchingDecks.length} official precon candidates.');

    // Prioritize Commander, Challenger, Starter Kit, Duel Decks, Theme Decks
    matchingDecks.sort((a, b) {
      final typeOrder = {
        'Commander Deck': 1,
        'Challenger Deck': 2,
        'Pioneer Challenger Deck': 3,
        'Starter Kit': 4,
        'Arena Starter Kit': 5,
        'Brawl Deck': 6,
        'Historic Brawl Precon Deck': 7,
        'Duel Deck': 8,
        'Duel Of The Planeswalkers Deck': 9,
        'Planechase Deck': 10,
        'Archenemy Deck': 11,
        'Guild Kit': 12,
        'Event Deck': 13,
        'Modern Event Deck': 14,
        'Clash Pack': 15,
        'Planeswalker Deck': 16,
        'Theme Deck': 17,
        'Intro Pack': 18,
        'Game Night Deck': 19,
        'Starter Deck': 20,
        'Arena Starter Deck': 21,
        'Welcome Deck': 22,
        'Spellslinger Starter Kit': 23,
        'MTGO Commander Deck': 24,
        'MTGO Duel Deck': 25,
        'MTGO Theme Deck': 26,
      };
      final orderA = typeOrder[a['type']] ?? 99;
      final orderB = typeOrder[b['type']] ?? 99;
      if (orderA != orderB) return orderA.compareTo(orderB);

      final dateA = a['releaseDate']?.toString() ?? '';
      final dateB = b['releaseDate']?.toString() ?? '';
      return dateB.compareTo(dateA); // Newer first
    });

    final selectedCandidates = matchingDecks.take(targetCount + 40).toList();
    stdout.writeln('[seed_all_precons] Selected ${selectedCandidates.length} precons to download and process.');

    final processedDecks = <Map<String, dynamic>>[];
    int completedCount = 0;

    // Concurrent worker pool
    final queue = List<Map<String, dynamic>>.from(selectedCandidates);
    final futures = <Future<void>>[];

    for (int w = 0; w < maxConcurrency; w++) {
      futures.add(() async {
        while (queue.isNotEmpty) {
          final deckMeta = queue.removeLast();
          final fileName = deckMeta['fileName'] as String;
          final rawType = deckMeta['type'] as String;

          final deckUrl = '$defaultDecksBaseUrl/$fileName.json';
          try {
            final resp = await client.get(
              Uri.parse(deckUrl),
              headers: {'User-Agent': 'Countr/1.0 (MTGJSON Ingestion)'},
            ).timeout(const Duration(seconds: 15));

            if (resp.statusCode == 200) {
              final rawDeck = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
              final cleanDeck = _sanitizeAndCompressDeck(rawDeck, fileName, rawType);
              if (cleanDeck != null) {
                synchronized(processedDecks, () {
                  processedDecks.add(cleanDeck);
                });
              }
            }
          } catch (_) {
            // Non-fatal: continue processing other precons
          } finally {
            completedCount++;
            if (completedCount % 50 == 0 || completedCount == selectedCandidates.length) {
              stdout.writeln('  [seed_all_precons] Processed $completedCount / ${selectedCandidates.length} (Valid precons: ${processedDecks.length})...');
            }
          }
        }
      }());
    }

    await Future.wait(futures);

    if (processedDecks.length < 500) {
      stderr.writeln('ERROR: Expected at least 500 preconstructed decks, but got ${processedDecks.length}.');
      exit(1);
    }

    stdout.writeln('[seed_all_precons] Successfully processed ${processedDecks.length} preconstructed decks.');
    stdout.writeln('[seed_all_precons] Serializing and compressing to $defaultOutputPath...');

    final jsonStr = jsonEncode(processedDecks);
    final compressedBytes = gzip.encode(utf8.encode(jsonStr));

    final outputFile = File(defaultOutputPath);
    if (!outputFile.parent.existsSync()) {
      outputFile.parent.createSync(recursive: true);
    }
    outputFile.writeAsBytesSync(compressedBytes);

    final sizeKb = (compressedBytes.length / 1024).toStringAsFixed(1);
    stdout.writeln('====================================================');
    stdout.writeln('[seed_all_precons] SUCCESS: Bundle written to $defaultOutputPath');
    stdout.writeln('[seed_all_precons] Total Decks: ${processedDecks.length}');
    stdout.writeln('[seed_all_precons] Bundle Size: $sizeKb KB (GZIP compressed)');
    stdout.writeln('====================================================');
  } finally {
    client.close();
  }
}

void synchronized(Object lock, void Function() block) {
  block();
}

Map<String, dynamic>? _sanitizeAndCompressDeck(
  Map<String, dynamic> rawDeck,
  String fileName,
  String rawType,
) {
  final name = rawDeck['name'] as String? ?? 'Untitled Deck';
  final setCode = (rawDeck['code'] as String?)?.toUpperCase();
  final format = _normalizeFormat(rawType);

  final rawCommanders = rawDeck['commander'] as List? ?? [];
  final rawMainboard = rawDeck['mainBoard'] as List? ?? [];
  final rawSideboard = rawDeck['sideBoard'] as List? ?? [];

  final commanderCards = <Map<String, dynamic>>[];
  for (final c in rawCommanders.whereType<Map<String, dynamic>>()) {
    if (_isArtSeriesOrMemorabilia(c)) continue;
    commanderCards.add(_sanitizeCard(c, 'Commander'));
  }

  final cards = <Map<String, dynamic>>[];
  for (final c in rawMainboard.whereType<Map<String, dynamic>>()) {
    if (_isArtSeriesOrMemorabilia(c)) continue;
    cards.add(_sanitizeCard(c, 'Mainboard'));
  }
  for (final c in rawSideboard.whereType<Map<String, dynamic>>()) {
    if (_isArtSeriesOrMemorabilia(c)) continue;
    cards.add(_sanitizeCard(c, 'Sideboard'));
  }

  if (commanderCards.isEmpty && cards.isNotEmpty) {
    // Pick the first non-land card as the deck's cover card
    final nonLandIdx = cards.indexWhere((c) {
      final t = (c['type_line'] as String? ?? '').toLowerCase();
      return !t.contains('land');
    });
    final coverIdx = nonLandIdx != -1 ? nonLandIdx : 0;
    final coverCard = Map<String, dynamic>.from(cards[coverIdx]);
    final coverCount = (coverCard['count'] as num?)?.toInt() ?? 1;

    if (coverCount > 1) {
      cards[coverIdx]['count'] = coverCount - 1;
    } else {
      cards.removeAt(coverIdx);
    }

    coverCard['count'] = 1;
    coverCard['board_zone'] = 'Mainboard';
    coverCard['is_commander'] = false;
    commanderCards.add(coverCard);
  }

  final primaryCommander = commanderCards.isNotEmpty ? commanderCards.first : null;
  final colorIdentity = (rawDeck['colorIdentity'] as List? ?? []).cast<String>();

  final releaseDateStr = rawDeck['releaseDate'] as String?;
  final releaseYear = releaseDateStr != null && releaseDateStr.length >= 4
      ? int.tryParse(releaseDateStr.substring(0, 4))
      : null;

  double computedPrice = (primaryCommander?['price'] as num?)?.toDouble() ?? 0.0;
  int computedCount = (primaryCommander != null ? 1 : 0);
  for (final c in cards) {
    computedPrice += ((c['price'] as num?)?.toDouble() ?? 0.0) * ((c['count'] as num?)?.toInt() ?? 1);
    computedCount += ((c['count'] as num?)?.toInt() ?? 1);
  }

  final featuredCategory = _deriveFeaturedCategory(format, rawType);

  return {
    'id': 'precon-${setCode?.toLowerCase() ?? 'mtg'}-${_slugify(name)}',
    'name': name,
    'format': format,
    'type': rawType,
    'source_type': 'official',
    'creator_name': 'Wizards of the Coast',
    'description': 'Official Magic: The Gathering preconstructed $format deck ($name) released for $setCode.',
    'release_code': setCode,
    'release_date': releaseDateStr,
    'release_year': releaseYear,
    'color_identity': colorIdentity,
    'card_count': computedCount,
    'estimated_price': double.parse(computedPrice.toStringAsFixed(2)),
    'upvotes': 15,
    'downvotes': 1,
    'score': 14,
    'featured_category': featuredCategory,
    'tags': 'fn:$fileName,official,wotc,${format.toLowerCase()}',
    'commander': primaryCommander,
    'cards': cards,
  };
}

bool _isArtSeriesOrMemorabilia(Map<String, dynamic> card) {
  final layout = card['layout']?.toString().toLowerCase();
  if (layout == 'art_series' || layout == 'double_faced_token') return true;

  final setType = (card['setType'] ?? card['set_type'])?.toString().toLowerCase();
  if (setType == 'memorabilia') return true;

  final setCode = (card['setCode'] ?? card['set_code'])?.toString().toLowerCase();
  if (setCode != null && RegExp(r'^a[a-z0-9]{3,4}$').hasMatch(setCode)) return true;

  final name = card['name']?.toString() ?? '';
  if (name.contains(' // ')) {
    final parts = name.split(' // ');
    if (parts.length >= 2 && parts[0].trim().toLowerCase() == parts[1].trim().toLowerCase()) {
      return true;
    }
  }

  if (name.toLowerCase().contains('art card') || name.toLowerCase().contains('art series')) {
    return true;
  }

  final typeLine = (card['typeLine'] ?? card['type'])?.toString().toLowerCase() ?? '';
  if (typeLine.contains('art card') || typeLine.contains('art series')) {
    return true;
  }

  return false;
}

Map<String, dynamic> _sanitizeCard(Map<String, dynamic> c, String zone) {
  final idents = c['identifiers'] as Map? ?? {};
  final scryfallId = idents['scryfallId']?.toString() ?? c['scryfallId']?.toString() ?? '';
  final oracleId = idents['scryfallOracleId']?.toString() ?? c['oracleId']?.toString();
  String name = c['name']?.toString() ?? '';

  if (name.contains(' // ')) {
    final parts = name.split(' // ');
    if (parts.length >= 2 && parts[0].trim().toLowerCase() == parts[1].trim().toLowerCase()) {
      name = parts[0].trim();
    }
  }
  name = name.replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '').trim();

  String imageUrl = c['imageUrl']?.toString() ?? '';
  String artCropUrl = c['artCropUrl']?.toString() ?? '';

  if (scryfallId.length > 2) {
    imageUrl = 'https://cards.scryfall.io/normal/front/${scryfallId[0]}/${scryfallId[1]}/$scryfallId.jpg';
    artCropUrl = 'https://cards.scryfall.io/art_crop/front/${scryfallId[0]}/${scryfallId[1]}/$scryfallId.jpg';
  } else {
    final encoded = Uri.encodeComponent(name);
    imageUrl = 'https://api.scryfall.com/cards/named?exact=$encoded&format=image&version=normal';
    artCropUrl = 'https://api.scryfall.com/cards/named?exact=$encoded&format=image&version=art_crop';
  }

  final count = (c['count'] as num?)?.toInt() ?? 1;
  final manaCost = c['manaCost']?.toString();
  final cmc = (c['manaValue'] as num?)?.toDouble() ?? (c['convertedManaCost'] as num?)?.toDouble() ?? 0.0;
  final typeLine = c['type']?.toString() ?? c['typeLine']?.toString() ?? 'Card';
  final colors = (c['colors'] as List? ?? []).cast<String>();

  return {
    'name': name,
    'scryfall_id': scryfallId,
    'oracle_id': oracleId,
    'count': count,
    'board_zone': zone,
    'is_commander': zone == 'Commander',
    'mana_cost': manaCost,
    'cmc': cmc,
    'type_line': typeLine,
    'colors': colors,
    'image_url': imageUrl,
    'art_crop_url': artCropUrl,
    'price': 0.25,
  };
}

String _deriveFeaturedCategory(String format, String rawType) {
  if (format == 'Commander') return 'Suggested Commanders';
  if (format == 'Challenger' || rawType.contains('Challenger')) return 'Popular Standard Decks';
  if (format == 'Starter Kit' || rawType.contains('Starter')) return 'Starter Decks';
  if (format == 'Duel Decks' || rawType.contains('Duel')) return 'Historic Brawl';
  return 'Suggested Commanders';
}

String _normalizeFormat(String type) {
  final s = type.toLowerCase();
  if (s.contains('commander') || s.contains('edh') || s.contains('brawl')) return 'Commander';
  if (s.contains('challenger')) return 'Challenger';
  if (s.contains('starter') || s.contains('intro') || s.contains('welcome') || s.contains('planeswalker deck')) return 'Starter Kit';
  if (s.contains('duel deck')) return 'Duel Decks';
  if (s.contains('planechase')) return 'Planechase';
  if (s.contains('archenemy')) return 'Archenemy';
  return 'Commander';
}

String _slugify(String text) {
  return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

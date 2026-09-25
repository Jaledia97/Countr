// Copyright (c) 2026 Countr. All rights reserved.
// Symbology download pipeline tool.
//
// Downloads official MTG SVG symbology vector assets from Scryfall Symbology API
// and verifies them for offline bundling in Countr.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String scryfallSymbologyUrl = 'https://api.scryfall.com/symbology';
const String defaultUserAgent = 'CountrApp/1.0.0';
const String defaultAssetsDir = 'assets/symbology';
const String defaultCatalogPath =
    'lib/features/symbology/data/scryfall_symbol_catalog.dart';
const String cachedSymbologyJsonPath =
    '.agents/teamwork/survey_spec_miner_1/symbology.json';
const String proposedCatalogPath =
    '.agents/teamwork/m1_explorer_catalog_3/proposed_scryfall_symbol_catalog.dart';

void printUsage() {
  stdout.writeln('Usage: dart run tool/download_symbology.dart [options]');
  stdout.writeln('Options:');
  stdout.writeln(
      '  --offline-data <path>  Load JSON from file instead of Scryfall API');
  stdout.writeln(
      '  --assets-dir <path>    Target directory for SVGs (default: assets/symbology)');
  stdout.writeln(
      '  --catalog-path <path>  Target path for catalog Dart file (default: lib/features/symbology/data/scryfall_symbol_catalog.dart)');
  stdout.writeln(
      '  --delay-ms <ms>        Delay between SVG downloads in ms (default: 50)');
  stdout.writeln(
      '  --force                Force re-download of all SVG files');
  stdout.writeln(
      '  --help, -h             Print this help message');
}

/// Normalizes a Scryfall symbol (e.g. `{W/U}`, `{½}`, `{∞}`) to its local SVG filename.
String normalizeSymbolToFilename(String symbol) {
  final inner = symbol.replaceAll('{', '').replaceAll('}', '').trim();
  if (inner == '½') return 'HALF.svg';
  if (inner == '∞') return 'INFINITY.svg';
  return '${inner.replaceAll('/', '')}.svg';
}

/// Validates that an SVG file has non-empty, well-formed vector XML content.
void validateSvgContent(String filename, String content) {
  if (content.trim().isEmpty) {
    throw FormatException('SVG file $filename is empty.');
  }
  if (content.length < 100) {
    throw FormatException(
        'SVG file $filename is suspiciously small (${content.length} bytes).');
  }
  if (!content.contains('<svg')) {
    throw FormatException('SVG file $filename is missing opening <svg> tag.');
  }
  if (!content.contains('</svg>')) {
    throw FormatException('SVG file $filename is missing closing </svg> tag.');
  }
  if (content.contains('<!DOCTYPE html') || content.contains('<html')) {
    throw FormatException(
        'SVG file $filename contains HTML error page instead of valid SVG.');
  }
}

Future<void> main(List<String> args) async {
  String? offlineDataPath;
  String assetsDirPath = defaultAssetsDir;
  String catalogPath = defaultCatalogPath;
  int delayMs = 50;
  bool forceDownload = false;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      printUsage();
      exit(0);
    } else if (arg == '--offline-data' && i + 1 < args.length) {
      offlineDataPath = args[++i];
    } else if (arg == '--assets-dir' && i + 1 < args.length) {
      assetsDirPath = args[++i];
    } else if (arg == '--catalog-path' && i + 1 < args.length) {
      catalogPath = args[++i];
    } else if (arg == '--delay-ms' && i + 1 < args.length) {
      delayMs = int.tryParse(args[++i]) ?? 50;
    } else if (arg == '--force') {
      forceDownload = true;
    }
  }

  final assetsDir = Directory(assetsDirPath);
  if (!assetsDir.existsSync()) {
    stdout.writeln('Creating directory: ${assetsDir.path}');
    assetsDir.createSync(recursive: true);
  }

  List<dynamic> symbolList = [];
  final client = http.Client();

  try {
    if (offlineDataPath != null) {
      stdout.writeln('Loading symbology catalog from specified file: $offlineDataPath...');
      final file = File(offlineDataPath);
      if (!file.existsSync()) {
        stderr.writeln('Error: Specified offline data file not found: $offlineDataPath');
        exit(1);
      }
      final jsonStr = await file.readAsString();
      final decoded = jsonDecode(jsonStr);
      symbolList = decoded['data'] as List<dynamic>;
    } else {
      stdout.writeln('Fetching official MTG symbology from $scryfallSymbologyUrl...');
      try {
        final response = await client.get(
          Uri.parse(scryfallSymbologyUrl),
          headers: {
            'User-Agent': defaultUserAgent,
            'Accept': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          symbolList = decoded['data'] as List<dynamic>;
        } else {
          stderr.writeln(
              'Warning: Scryfall API returned HTTP ${response.statusCode}. Checking local fallback...');
        }
      } catch (e) {
        stderr.writeln('Warning: Network request to Scryfall failed: $e. Checking local fallback...');
      }

      if (symbolList.isEmpty) {
        final fallbackFile = File(cachedSymbologyJsonPath);
        if (fallbackFile.existsSync()) {
          stdout.writeln('Using local cached symbology dataset: $cachedSymbologyJsonPath');
          final jsonStr = await fallbackFile.readAsString();
          final decoded = jsonDecode(jsonStr);
          symbolList = decoded['data'] as List<dynamic>;
        } else {
          stderr.writeln('Error: Could not fetch symbology from network and no cached file was found.');
          exit(1);
        }
      }
    }

    stdout.writeln('Loaded ${symbolList.length} MTG symbols from catalog.');
    if (symbolList.length != 84) {
      stderr.writeln('Warning: Expected 84 symbols, found ${symbolList.length}.');
    }

    // Download & validate each SVG asset
    int newlyDownloaded = 0;
    int alreadyValid = 0;

    for (int i = 0; i < symbolList.length; i++) {
      final item = symbolList[i] as Map<String, dynamic>;
      final symbol = item['symbol'] as String;
      final svgUri = item['svg_uri'] as String;
      final filename = normalizeSymbolToFilename(symbol);
      final targetFile = File('${assetsDir.path}/$filename');

      String svgContent = '';
      bool needDownload = forceDownload || !targetFile.existsSync() || targetFile.lengthSync() < 100;

      if (!needDownload) {
        try {
          svgContent = await targetFile.readAsString();
          validateSvgContent(filename, svgContent);
          alreadyValid++;
        } catch (_) {
          needDownload = true;
        }
      }

      if (needDownload) {
        stdout.writeln('[${i + 1}/${symbolList.length}] Downloading $symbol -> $filename...');
        bool downloaded = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            final res = await client.get(
              Uri.parse(svgUri),
              headers: {'User-Agent': defaultUserAgent},
            );
            if (res.statusCode == 200) {
              svgContent = utf8.decode(res.bodyBytes);
              validateSvgContent(filename, svgContent);
              await targetFile.writeAsString(svgContent);
              downloaded = true;
              newlyDownloaded++;
              break;
            } else {
              stderr.writeln('Attempt $attempt: HTTP ${res.statusCode} for $svgUri');
            }
          } catch (e) {
            stderr.writeln('Attempt $attempt failed for $svgUri: $e');
          }
          if (attempt < 3) {
            await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
          }
        }

        if (!downloaded) {
          stderr.writeln('Error: Failed to download $svgUri after 3 attempts.');
          exit(1);
        }

        if (delayMs > 0 && i < symbolList.length - 1) {
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    stdout.writeln(
        'All ${symbolList.length} MTG SVG symbols verified in ${assetsDir.path} ($newlyDownloaded downloaded, $alreadyValid verified existing).');

    // Ensure catalog file exists
    final catalogFile = File(catalogPath);
    if (!catalogFile.existsSync()) {
      stdout.writeln('Deploying catalog file to $catalogPath...');
      final proposedFile = File(proposedCatalogPath);
      if (proposedFile.existsSync()) {
        catalogFile.parent.createSync(recursive: true);
        await proposedFile.copy(catalogFile.path);
        stdout.writeln('Deployed catalog from $proposedCatalogPath to $catalogPath.');
      }
    } else {
      stdout.writeln('Catalog file already exists at $catalogPath.');
    }

    stdout.writeln('Symbology download pipeline finished successfully!');
  } finally {
    client.close();
  }
}

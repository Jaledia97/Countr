import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/scanner/domain/profiles/collectible_profile.dart';
import 'package:countr/features/scanner/domain/profiles/mtg_collectible_profile.dart';
import 'package:countr/features/scanner/domain/profiles/comic_collectible_profile.dart';
import 'package:countr/features/scanner/domain/vision/bk_tree.dart';
import 'package:countr/features/scanner/domain/vision/dhash.dart';
import 'package:countr/features/scanner/domain/vision/vision_isolate.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

// Mock ungenerated properties by reading from dynamicData JSON
extension VaultItemMigrationExt on VaultItem {
  int? get artHash {
    if (dynamicData.isEmpty) return null;
    try {
      final decoded = jsonDecode(dynamicData);
      if (decoded is! Map) return null;
      final val = decoded['art_hash'];
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    } catch (_) {
      return null;
    }
  }

  String? get collectorNumber {
    if (dynamicData.isEmpty) return null;
    try {
      final decoded = jsonDecode(dynamicData);
      if (decoded is! Map) return null;
      final val = decoded['collector_number'];
      if (val == null) return null;
      final s = val.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  String? get setCode {
    if (dynamicData.isEmpty) return null;
    try {
      final decoded = jsonDecode(dynamicData);
      if (decoded is! Map) return null;
      final val = decoded['set'] ?? decoded['set_code'];
      if (val == null) return null;
      final s = val.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  String? get barcode {
    if (dynamicData.isEmpty) return null;
    try {
      final decoded = jsonDecode(dynamicData);
      if (decoded is! Map) return null;
      final val = decoded['barcode'];
      if (val == null) return null;
      final s = val.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }
}

class ScanMatchResult {
  final VaultItem match;
  final int tier;
  final CollectibleProfile? profile;

  ScanMatchResult(this.match, this.tier, {this.profile});
}

class CascadeScannerCoordinator {
  final BkTree bkTree;
  final List<CollectibleProfile> profiles;

  CascadeScannerCoordinator({
    required this.bkTree,
    List<CollectibleProfile>? profiles,
  }) : profiles = profiles ?? [
          MtgCollectibleProfile(),
          ComicCollectibleProfile(),
        ];

  /// Cascades through available profiles to automatically extract candidate
  /// titles/numbers and execute matches against all profiles. The first profile
  /// to yield a confident match wins.
  Future<ScanMatchResult?> matchOcr({
    required String ocrText,
    required VaultDao dao,
    List<CollectibleProfile>? candidateProfiles,
    int? artHash,
  }) async {
    final activeProfiles = candidateProfiles ?? profiles;

    // 1. Tier 0: Barcode check (if enabled for profile)
    for (final profile in activeProfiles) {
      if (profile.enableBarcodeScanning) {
        final barcodeMatch = RegExp(r'\b\d{12,13}\b').firstMatch(ocrText);
        if (barcodeMatch != null) {
          final barcodeStr = barcodeMatch.group(0)!;
          final allItems = await (profile.collectionType != null
              ? (dao.select(dao.db.vaultItems)
                    ..where((t) => t.collectionType.equals(profile.collectionType!)))
                  .get()
              : dao.select(dao.db.vaultItems).get());
          for (final item in allItems) {
            if (item.barcode == barcodeStr) {
              return ScanMatchResult(item, 0, profile: profile);
            }
          }
        }
      }
    }

    // 2. Tier 1: OCR Heuristics across all profiles (First confident match wins)
    for (final profile in activeProfiles) {
      final candidateNumber = profile.extractCollectorNumber(ocrText);
      final candidateTitle = profile.extractTitle(ocrText);

      if (candidateTitle != null && candidateNumber != null) {
        final exactMatch = await _findExactMatch(
          dao,
          candidateTitle,
          candidateNumber,
          collectionType: profile.collectionType,
        );
        if (exactMatch != null) {
          return ScanMatchResult(exactMatch, 1, profile: profile);
        }
      }
    }

    // 3. Tier 2: Targeted pHash / dHash across all profiles
    if (artHash != null) {
      for (final profile in activeProfiles) {
        final candidateTitle = profile.extractTitle(ocrText);
        if (candidateTitle != null) {
          final candidates = await _findCandidatesByTitle(
            dao,
            candidateTitle,
            collectionType: profile.collectionType,
          );
          VaultItem? bestCandidate;
          int lowestDistance = 999;
          for (final candidate in candidates) {
            if (candidate.artHash != null) {
              final distance = DHash.hammingDistance(candidate.artHash!, artHash);
              if (distance <= 10 && distance < lowestDistance) {
                lowestDistance = distance;
                bestCandidate = candidate;
              }
            }
          }
          if (bestCandidate != null) {
            return ScanMatchResult(bestCandidate, 2, profile: profile);
          }
        }
      }

      // 4. Tier 3: Zero-Text Visual Path (BK-Tree Lookup)
      final results = bkTree.search(artHash, threshold: 10);
      if (results.isNotEmpty) {
        final bestMatchId = results.first.key;
        final bestMatch = await dao.getItemById(bestMatchId);
        if (bestMatch != null) {
          final matchedProfile = activeProfiles.isNotEmpty
              ? activeProfiles.firstWhere(
                  (p) => p.collectionType == bestMatch.collectionType,
                  orElse: () => activeProfiles.first,
                )
              : null;
          return ScanMatchResult(bestMatch, 3, profile: matchedProfile);
        }
      }
    }

    return null;
  }

  Future<(ScanMatchResult?, List<double>?)> processFrame({
    required CameraImage cameraImage,
    CollectibleProfile? profile,
    List<CollectibleProfile>? profiles,
    required VaultDao dao,
    required TextRecognizer textRecognizer,
  }) async {
    final activeProfiles =
        profiles ?? (profile != null ? [profile] : this.profiles);

    // 1. Clutter Elimination (Warp Perspective) offloaded to Isolate
    final targetProfile = activeProfiles.isNotEmpty
        ? activeProfiles.first
        : MtgCollectibleProfile();
    final aspectRatio =
        targetProfile.artCropBounds.width / targetProfile.artCropBounds.height;
    final isolateResult =
        await ScannerWorkerIsolate.processFrame(cameraImage, aspectRatio);
    final croppedHashBytes = isolateResult.$1;
    final croppedJpgBytes = isolateResult.$2;
    final corners = isolateResult.$3;

    if (croppedHashBytes == null || croppedJpgBytes == null) {
      return (null, null); // No card found
    }

    // OCR on cropped image using a unique temporary file to prevent IO contention
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/cropped_for_ocr_${DateTime.now().millisecondsSinceEpoch}_${cameraImage.hashCode}.jpg');
    await file.writeAsBytes(croppedJpgBytes);

    String ocrText = '';
    try {
      final inputImage = InputImage.fromFile(file);
      final recognized = await textRecognizer.processImage(inputImage);
      final cleanedLines = OcrHeuristicMatcher.extractCleanedLines(recognized);
      ocrText = cleanedLines.join('\n');
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Calculate dHash for Tier 2 & 3 on the 9x8 bytes returned from OpenCV Isolate
    final hash = DHash.calculate(croppedHashBytes);

    // Cascade through available profiles to find a match
    final match = await matchOcr(
      ocrText: ocrText,
      dao: dao,
      candidateProfiles: activeProfiles,
      artHash: hash,
    );

    return (match, corners);
  }

  Future<VaultItem?> _findExactMatch(
    VaultDao dao,
    String title,
    String number, {
    String? collectionType,
  }) async {
    final cleanTitle =
        title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final trimmedNumber = number.trim();
    if (cleanTitle.isEmpty || trimmedNumber.isEmpty) {
      return null;
    }

    final numPrefix = trimmedNumber.contains('/')
        ? trimmedNumber.split('/').first.trim()
        : trimmedNumber;
    final unpaddedNum = int.tryParse(numPrefix)?.toString();

    // 1. Check candidate items by title (and match collector_number)
    final candidates = await _findCandidatesByTitle(
      dao,
      title,
      collectionType: collectionType,
    );
    for (final item in candidates) {
      if (collectionType != null && item.collectionType != collectionType) {
        continue;
      }
      final itemCollector = item.collectorNumber;
      if (itemCollector != null && itemCollector.isNotEmpty) {
        final itemPrefix = itemCollector.split('/').first.trim();
        final itemUnpadded = int.tryParse(itemPrefix)?.toString();
        if (itemCollector == trimmedNumber ||
            itemCollector == numPrefix ||
            itemPrefix == numPrefix ||
            (unpaddedNum != null &&
                (itemCollector == unpaddedNum || itemUnpadded == unpaddedNum))) {
          return item;
        }
      }
    }

    return null;
  }

  Future<List<VaultItem>> _findCandidatesByTitle(
    VaultDao dao,
    String title, {
    String? collectionType,
  }) async {
    final cleanTitle =
        title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (cleanTitle.isEmpty) return [];

    final query = dao.select(dao.db.vaultItems)
      ..where((t) {
        final nameMatch = t.name.equals(title) |
            t.name.lower().equals(title.toLowerCase()) |
            t.name.like('%$title%');
        if (collectionType != null) {
          return nameMatch & t.collectionType.equals(collectionType);
        }
        return nameMatch;
      });
    final exactOrLike = await query.get();
    List<VaultItem> matches = [];
    if (exactOrLike.isNotEmpty) {
      matches = List.of(exactOrLike);
    } else {
      // Fallback search across items by sanitized name
      final all = await (collectionType != null
          ? (dao.select(dao.db.vaultItems)
                ..where((t) => t.collectionType.equals(collectionType)))
              .get()
          : dao.select(dao.db.vaultItems).get());
      matches = all.where((item) {
        final itemClean =
            item.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        if (itemClean.isEmpty) return false;
        return itemClean == cleanTitle ||
            (cleanTitle.length >= 3 && itemClean.contains(cleanTitle)) ||
            (itemClean.length >= 3 && cleanTitle.contains(itemClean));
      }).toList();
    }

    // Prioritize exact match, then closer string length
    matches.sort((a, b) {
      final aClean = a.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      final bClean = b.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      final aExact = aClean == cleanTitle ? 0 : 1;
      final bExact = bClean == cleanTitle ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);
      final aDiff = (aClean.length - cleanTitle.length).abs();
      final bDiff = (bClean.length - cleanTitle.length).abs();
      return aDiff.compareTo(bDiff);
    });

    return matches;
  }
}

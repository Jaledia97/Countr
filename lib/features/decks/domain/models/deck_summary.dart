// Copyright (c) 2026 Countr. All rights reserved.
// Deck summary model for decks screen architecture.

import 'dart:convert';
import 'package:countr/core/database/app_database.dart';

/// Aggregated summary model for a deck in DecksScreen, including the active Commander,
/// art crop URL, color identity, card count, and assembly completeness.
class DeckSummary {
  final String id;
  final String name;
  final String format;
  final String tcgDomain;
  final bool isRegistered;
  final bool isCompetitive;
  final DateTime createdAt;
  final String? coverItemId;
  final String? coverCropRect;
  final String? activeVersionId;
  final String? commanderCardId;
  final String? commanderName;
  final String? commanderImageUrl;
  final String? commanderArtCrop;
  final List<String> colorIdentity;
  final int cardCount;
  final int targetCardCount;
  int get targetCount => targetCardCount;
  final double completeness;
  final String assemblyStatus;
  final Deck deck;

  const DeckSummary({
    required this.id,
    required this.name,
    required this.format,
    required this.tcgDomain,
    required this.isRegistered,
    required this.isCompetitive,
    required this.createdAt,
    this.coverItemId,
    this.coverCropRect,
    this.activeVersionId,
    this.commanderCardId,
    this.commanderName,
    this.commanderImageUrl,
    this.commanderArtCrop,
    this.colorIdentity = const [],
    required this.cardCount,
    required this.targetCardCount,
    required this.completeness,
    required this.assemblyStatus,
    required this.deck,
  });

  /// Instantiates a [DeckSummary] from a raw Drift LEFT JOIN query row.
  factory DeckSummary.fromRow({
    required String id,
    required String name,
    required String format,
    required String tcgDomain,
    required bool isRegistered,
    required bool isCompetitive,
    required DateTime createdAt,
    String? coverItemId,
    String? coverCropRect,
    String? activeVersionId,
    String? commanderCardId,
    String? commanderName,
    String? commanderImageUrl,
    String? commanderDynamicData,
    required int cardCount,
  }) {
    String? artCrop;
    List<String> colors = [];

    if (commanderDynamicData != null && commanderDynamicData.isNotEmpty) {
      try {
        final decoded = jsonDecode(commanderDynamicData);
        if (decoded is Map<String, dynamic>) {
          if (decoded['image_uris'] is Map) {
            artCrop = decoded['image_uris']['art_crop'] as String?;
          } else if (decoded['card_faces'] is List && (decoded['card_faces'] as List).isNotEmpty) {
            final face0 = (decoded['card_faces'] as List).first;
            if (face0 is Map && face0['image_uris'] is Map) {
              artCrop = face0['image_uris']['art_crop'] as String?;
            }
          }

          if (decoded['color_identity'] is List) {
            colors = (decoded['color_identity'] as List)
                .map((e) => e.toString().toUpperCase())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      } catch (_) {}
    }
    artCrop ??= commanderImageUrl;

    final target = computeTargetCardCount(format);
    final comp = target > 0 ? (cardCount / target).clamp(0.0, 1.0) : 1.0;

    final status = isRegistered
        ? 'Assembled'
        : (cardCount >= target && cardCount > 0 ? 'Ready' : 'Draft');

    final deck = Deck(
      id: id,
      name: name,
      format: format,
      tcgDomain: tcgDomain,
      isRegistered: isRegistered,
      isAssembled: isRegistered,
      isCompetitive: isCompetitive,
      coverItemId: coverItemId,
      coverCropRect: coverCropRect,
      createdAt: createdAt,
      wins: 0,
      losses: 0,
      draws: 0,
      isCloned: false,
      isDeleted: false,
    );

    return DeckSummary(
      id: id,
      name: name,
      format: format,
      tcgDomain: tcgDomain,
      isRegistered: isRegistered,
      isCompetitive: isCompetitive,
      createdAt: createdAt,
      coverItemId: coverItemId,
      coverCropRect: coverCropRect,
      activeVersionId: activeVersionId,
      commanderCardId: commanderCardId,
      commanderName: commanderName,
      commanderImageUrl: commanderImageUrl,
      commanderArtCrop: artCrop,
      colorIdentity: colors,
      cardCount: cardCount,
      targetCardCount: target,
      completeness: comp,
      assemblyStatus: status,
      deck: deck,
    );
  }

  /// Target count based on format rules.
  static int computeTargetCardCount(String format) {
    final lower = format.toLowerCase();
    if (lower.contains('commander') || lower.contains('edh')) return 100;
    if (lower.contains('standard') ||
        lower.contains('modern') ||
        lower.contains('pioneer') ||
        lower.contains('legacy') ||
        lower.contains('vintage') ||
        lower.contains('pauper') ||
        lower.contains('core')) {
      return 60;
    }
    return 60;
  }
}

import 'package:flutter/material.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';

/// Data-dense ExpansionTile list item for catalog card search results.
///
/// Features a compact 48-56px header with leading thumbnail, title + ManaCostBar,
/// subtitle with set code, rarity badge, type line, and current price, plus
/// a customizable trailing widget (e.g. stepper or add button).
/// Expands to reveal full Oracle text (rendered with inline [ManaText] symbols),
/// flavor text, and detailed set printing metadata.
class CatalogCardListTile extends StatelessWidget {
  final VaultItem card;
  final Widget? trailing;
  final bool isPrivacyMode;
  final bool initiallyExpanded;
  final VoidCallback? onTap;

  const CatalogCardListTile({
    super.key,
    required this.card,
    this.trailing,
    this.isPrivacyMode = false,
    this.initiallyExpanded = false,
    this.onTap,
  });

  static Color getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'mythic':
        return AppColors.accentAmber;
      case 'rare':
        return AppColors.accentAmberLight;
      case 'uncommon':
        return AppColors.accentCyan;
      case 'common':
        return AppColors.textSecondary;
      default:
        return AppColors.textMuted;
    }
  }

  String _resolveThumbnailUrl(VaultItem item, Map<String, dynamic> data) {
    if (data.isNotEmpty) {
      if (data['image_uris'] is Map) {
        final uris = data['image_uris'] as Map;
        final small = uris['small']?.toString();
        if (small != null && small.trim().isNotEmpty) {
          return small.trim();
        }
      }
      if (data['card_faces'] is List && (data['card_faces'] as List).isNotEmpty) {
        final face0 = (data['card_faces'] as List).first;
        if (face0 is Map && face0['image_uris'] is Map) {
          final uris = face0['image_uris'] as Map;
          final small = uris['small']?.toString();
          if (small != null && small.trim().isNotEmpty) {
            return small.trim();
          }
        }
      }
    }
    return item.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final data = ParsedJsonCache.parse(card.dynamicData);
    final manaCost =
        data['mana_cost']?.toString() ?? data['mana']?.toString() ?? '';
    final typeLine = data['type_line']?.toString() ?? '';
    final rarity = (data['rarity']?.toString() ?? '').toLowerCase();
    final rarityColor = getRarityColor(rarity);

    String? oracleText = data['oracle_text']?.toString();
    if ((oracleText == null || oracleText.isEmpty) &&
        data['card_faces'] is List &&
        (data['card_faces'] as List).isNotEmpty) {
      final faces = data['card_faces'] as List;
      final faceTexts = <String>[];
      for (final f in faces) {
        if (f is Map && f['oracle_text'] != null) {
          faceTexts.add(f['oracle_text'].toString());
        }
      }
      if (faceTexts.isNotEmpty) {
        oracleText = faceTexts.join('\n//\n');
      }
    }

    final flavorText = data['flavor_text']?.toString();
    final collectorNum = data['collector_number']?.toString();
    final releaseDate = data['released_at']?.toString();
    final imageUrl = _resolveThumbnailUrl(card, data);

    final displayName = (card.flavorName != null && card.flavorName!.isNotEmpty)
        ? card.flavorName!
        : card.name;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorderSubtle),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            childrenPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 38,
                height: 50,
                color: AppColors.surfaceRaised,
                child: imageUrl.isNotEmpty
                    ? CountrCachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: AppColors.surfaceBorder.withValues(alpha: 0.3),
                          child: const Center(
                            child: Icon(Icons.style_outlined,
                                color: AppColors.textMuted, size: 18),
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceBorder.withValues(alpha: 0.3),
                        child: const Center(
                          child: Icon(Icons.style_outlined,
                              color: AppColors.textMuted, size: 18),
                        ),
                      ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (manaCost.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: ManaCostBar(
                        manaCost: manaCost,
                        symbolSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    [
                      if (card.setOrSeries.isNotEmpty)
                        card.setOrSeries.toUpperCase(),
                      if (typeLine.isNotEmpty) typeLine,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (rarity.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: rarityColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        rarity.toUpperCase(),
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    isPrivacyMode
                        ? '****'
                        : '\$${card.currentMarketPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.accentEmerald,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            trailing: trailing,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                        color: AppColors.surfaceBorderSubtle, height: 12),
                    if (card.flavorName != null &&
                        card.flavorName!.isNotEmpty &&
                        card.flavorName != card.name) ...[
                      Text(
                        'Canonical Name: ${card.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (oracleText != null && oracleText.trim().isNotEmpty) ...[
                      ManaText(
                        oracleText.trim(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                        symbolSize: 12,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (flavorText != null && flavorText.trim().isNotEmpty) ...[
                      Text(
                        flavorText.trim(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (card.setOrSeries.isNotEmpty)
                          _buildDetailPill(
                              'Set', card.setOrSeries.toUpperCase()),
                        if (collectorNum != null && collectorNum.isNotEmpty)
                          _buildDetailPill('No.', '#$collectorNum'),
                        if (rarity.isNotEmpty)
                          _buildDetailPill('Rarity', rarity.toUpperCase()),
                        if (releaseDate != null && releaseDate.isNotEmpty)
                          _buildDetailPill('Released', releaseDate),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPill(String label, String value) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        fontSize: 10.5,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

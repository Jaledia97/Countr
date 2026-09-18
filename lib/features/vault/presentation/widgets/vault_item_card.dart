import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'card_detail_sheet.dart';
import 'polymorphic_attribute_chip.dart';

/// Individual Ledger Card for a VaultItem.
/// Dynamically adapts between Investor Mode (financial ledger) and Player Mode (game mechanics).
class VaultItemCard extends StatelessWidget {
  final VaultItem item;
  final UserPersona? persona;
  final VoidCallback? onTap;

  const VaultItemCard({
    super.key,
    required this.item,
    this.persona,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (persona != null) {
      return _buildCardContent(context, persona!);
    }

    final hasScope =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
            context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
                null;

    if (hasScope) {
      return Consumer(
        builder: (context, ref, _) {
          final activePersona = ref.watch(userPersonaProvider);
          return _buildCardContent(context, activePersona);
        },
      );
    }

    // Graceful fallback for isolated widget tests without ProviderScope
    return _buildCardContent(context, UserPersona.investor);
  }

  Widget _buildCardContent(BuildContext context, UserPersona activePersona) {
    // Decode dynamic metadata safely
    Map<String, dynamic> data = {};
    if (item.dynamicData.isNotEmpty) {
      try {
        data = jsonDecode(item.dynamicData) as Map<String, dynamic>;
      } catch (_) {
        data = {};
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () => CardDetailSheet.show(context, item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Icon, Name, Condition & Grade Badge
                _buildHeaderRow(),

                const SizedBox(height: 10),

                // Middle: Polymorphic Chip
                PolymorphicAttributeChip(
                  collectionType: item.collectionType,
                  dynamicDataJson: item.dynamicData,
                ),

                const SizedBox(height: 12),

                // Bottom: Dynamic Persona View
                if (activePersona == UserPersona.investor)
                  _buildInvestorFinancialRow()
                else
                  _buildPlayerMechanicsRow(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leading Artwork Thumbnail with Type Icon Fallback
        _buildLeadingThumbnail(),
        const SizedBox(width: 12),

        // Name & Set
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.flavorName != null && item.flavorName!.isNotEmpty
                    ? item.flavorName!
                    : item.name,
                style: AppTypography.heading2.copyWith(fontSize: 14.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.flavorName != null && item.flavorName!.isNotEmpty
                    ? '[${item.name}] • ${item.setOrSeries}'
                    : item.setOrSeries,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Condition / Grade Pill & Duplicate Counter Badge
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.quantity > 1) ...[
                  Container(
                    key: Key('vault_item_duplicate_badge_${item.id}'),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isGraded
                        ? AppColors.accentCyan.withValues(alpha: 0.18)
                        : AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.isGraded
                          ? AppColors.accentCyan.withValues(alpha: 0.6)
                          : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Text(
                    item.condition,
                    style: TextStyle(
                      color: item.isGraded
                          ? AppColors.accentCyan
                          : AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (item.isGraded) ...[
              const SizedBox(height: 3),
              const Text(
                'SLAB / GRADED',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  double _getEffectiveMarketPrice() =>
      VaultPricingHelper.resolveEffectiveMarketPrice(item);

  Widget _buildInvestorFinancialRow() {
    final effectivePrice = _getEffectiveMarketPrice();
    final delta =
        (effectivePrice - item.acquiredPrice) * item.quantity;
    final pct = item.acquiredPrice > 0
        ? ((effectivePrice - item.acquiredPrice) /
                item.acquiredPrice) *
            100
        : 0.0;
    final isProfit = delta >= 0;
    final pLColor = isProfit ? AppColors.accentEmerald : AppColors.accentRose;
    final pctSign = isProfit ? '+' : '';
    final deltaSign = isProfit ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: item.quantity == 0
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          color: AppColors.accentCyan, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'CATALOG / UNOWNED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentCyan,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MARKET VALUE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effectivePrice > 0
                          ? '\$${effectivePrice.toStringAsFixed(2)}'
                          : 'Unlisted',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Acquired Price
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'ACQUIRED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${item.acquiredPrice.toStringAsFixed(2)}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Current Market Price (TMV)
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'LIVE TMV',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentCyan,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  effectivePrice > 0
                                      ? '\$${effectivePrice.toStringAsFixed(2)}'
                                      : 'Unlisted',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Financial Delta (P/L Percentage in Green or Red)
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: pLColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: pLColor.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isProfit
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: pLColor,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$pctSign${pct.toStringAsFixed(1)}% ($deltaSign\$${delta.abs().toStringAsFixed(2)})',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: pLColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPlayerMechanicsRow(Map<String, dynamic> data) {
    final manaCost =
        data['mana_cost']?.toString() ?? data['mana']?.toString() ?? '';
    final power = data['power']?.toString();
    final toughness = data['toughness']?.toString();
    final loyalty = data['loyalty']?.toString();
    final rawKeywords = data['keywords'];
    final keywordsList = rawKeywords is List ? rawKeywords : null;
    final oracleText = data['oracle_text']?.toString() ?? '';
    final mechanics = MtgKeywordGlossary.extractKeywords(
      keywords: keywordsList,
      oracleText: oracleText,
    );

    // Pokémon-specific data support
    final hp = data['hp']?.toString();
    final stage = data['stage']?.toString();

    final hasMana = manaCost.isNotEmpty;
    final hasPT = power != null && toughness != null && power.isNotEmpty;
    final hasLoyalty = !hasPT && loyalty != null && loyalty.isNotEmpty;
    final hasHp = hp != null && hp.isNotEmpty;
    final hasMechanics = mechanics.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accentViolet.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Mana Value / Cost Badge
              if (hasMana)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accentViolet.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: AppColors.accentVioletLight, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          manaCost,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Power / Toughness Badge
              if (hasPT)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accentAmber.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '⚔️ $power / 🛡️ $toughness',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.accentAmberLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else if (hasLoyalty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accentAmber.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Loyalty: $loyalty',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.accentAmberLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else if (hasHp)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accentAmber.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'HP $hp${stage != null ? ' • $stage' : ''}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.accentAmberLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

              if (!hasMana && !hasPT && !hasLoyalty && !hasHp)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_esports_rounded,
                        size: 14, color: AppColors.accentVioletLight),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${item.collectionType.toUpperCase()} UTILITY',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

              // Game Utility Indicator Tag (zero financial deltas)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorderSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'GAME UTILITY',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          // Keyword Badges (e.g. Flying, Trample, Indestructible)
          if (hasMechanics) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: mechanics.map((kw) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    kw,
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Resolves the optimal artwork thumbnail URL from dynamic metadata or database fields.
  ///
  /// Priority:
  /// 1. `dynamicData['image_uris']['small']` (Scryfall small thumbnail, 146x204)
  /// 2. `dynamicData['card_faces'][0]['image_uris']['small']` (for DFC/transform cards)
  /// 3. `item.imageUrl` (canonical card art URL in SQLite)
  /// 4. Empty string if no image URL is available
  String _resolveThumbnailUrl() {
    if (item.dynamicData.isNotEmpty) {
      try {
        final decoded = jsonDecode(item.dynamicData);
        if (decoded is Map) {
          // 1. Top-level image_uris['small']
          if (decoded['image_uris'] is Map) {
            final uris = decoded['image_uris'] as Map;
            final small = uris['small']?.toString();
            if (small != null && small.trim().isNotEmpty) {
              return small.trim();
            }
          }
          // 2. Double-faced / multi-face card_faces[0]['image_uris']['small']
          if (decoded['card_faces'] is List &&
              (decoded['card_faces'] as List).isNotEmpty) {
            final face0 = (decoded['card_faces'] as List).first;
            if (face0 is Map && face0['image_uris'] is Map) {
              final uris = face0['image_uris'] as Map;
              final small = uris['small']?.toString();
              if (small != null && small.trim().isNotEmpty) {
                return small.trim();
              }
            }
          }
        }
      } catch (_) {
        // Fall through to item.imageUrl on malformed JSON
      }
    }

    final direct = item.imageUrl.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    return '';
  }

  /// Builds a rounded leading artwork thumbnail for the List View item card.
  ///
  /// Uses [width] = 38 and [height] = 52 (card aspect ratio ~1:1.37) with
  /// anti-aliased clipping (`borderRadius: BorderRadius.circular(6)`).
  ///
  /// Gracefully falls back to [_buildFallbackTypeIcon] when loading fails or no URL exists.
  Widget _buildLeadingThumbnail({
    double width = 38,
    double height = 52,
    double borderRadius = 6.0,
  }) {
    final thumbUrl = _resolveThumbnailUrl();

    if (thumbUrl.isNotEmpty) {
      return Container(
        key: Key('vault_card_leading_thumbnail_${item.id}'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: AppColors.surfaceBorderSubtle,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          thumbUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppColors.surfaceRaised,
              child: const Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.accentCyan,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackTypeIcon(width: width, height: height, borderRadius: borderRadius),
        ),
      );
    }

    return _buildFallbackTypeIcon(width: width, height: height, borderRadius: borderRadius);
  }

  /// Builds the fallback type icon container when no artwork is available or loading errors occur.
  Widget _buildFallbackTypeIcon({
    double width = 38,
    double height = 52,
    double borderRadius = 6.0,
  }) {
    return Container(
      key: Key('vault_card_leading_fallback_${item.id}'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _getTypeColor(item.collectionType).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: _getTypeColor(item.collectionType).withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Icon(
          _getTypeIcon(item.collectionType),
          color: _getTypeColor(item.collectionType),
          size: 20,
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'mtg':
        return Icons.auto_awesome_rounded;
      case 'pokemon':
        return Icons.catching_pokemon_rounded;
      case 'comic':
        return Icons.menu_book_rounded;
      case 'sports_card':
        return Icons.sports_football_rounded;
      default:
        return Icons.style_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'mtg':
        return AppColors.accentViolet;
      case 'pokemon':
        return AppColors.accentAmber;
      case 'comic':
        return AppColors.accentEmerald;
      case 'sports_card':
        return AppColors.accentCyan;
      default:
        return AppColors.accentCyan;
    }
  }
}

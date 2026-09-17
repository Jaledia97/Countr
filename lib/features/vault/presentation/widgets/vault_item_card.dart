import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';
import 'card_detail_sheet.dart';
import 'polymorphic_attribute_chip.dart';

/// Individual Ledger Card for a VaultItem.
/// Dynamically adapts between Investor Mode (financial ledger) and Player Mode (game mechanics).
class VaultItemCard extends StatelessWidget {
  final VaultItem item;
  final UserPersona? persona;

  const VaultItemCard({
    super.key,
    required this.item,
    this.persona,
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
          onTap: () => CardDetailSheet.show(context, item),
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
        // Type Icon Box
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _getTypeColor(item.collectionType).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _getTypeColor(item.collectionType).withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            _getTypeIcon(item.collectionType),
            color: _getTypeColor(item.collectionType),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),

        // Name & Set
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: AppTypography.heading2.copyWith(fontSize: 14.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.setOrSeries,
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

        // Condition / Grade Pill
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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

  Widget _buildInvestorFinancialRow() {
    final delta =
        (item.currentMarketPrice - item.acquiredPrice) * item.quantity;
    final pct = item.acquiredPrice > 0
        ? ((item.currentMarketPrice - item.acquiredPrice) /
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
                      '\$${item.currentMarketPrice.toStringAsFixed(2)}',
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
                                  '\$${item.currentMarketPrice.toStringAsFixed(2)}',
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

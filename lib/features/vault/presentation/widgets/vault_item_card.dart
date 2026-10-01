import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'card_detail_sheet.dart';
import 'polymorphic_attribute_chip.dart';

/// Individual Ledger Card for a VaultItem.
/// Dynamically adapts between Investor Mode (financial ledger) and Player Mode (game mechanics).
class VaultItemCard extends StatefulWidget {
  final VaultItem item;
  final UserPersona? persona;
  final VoidCallback? onTap;
  final bool? isPrivacyMode;
  final bool? initiallyExpanded;
  final bool hasMultipleVariants;

  const VaultItemCard({
    super.key,
    required this.item,
    this.persona,
    this.onTap,
    this.isPrivacyMode,
    this.initiallyExpanded,
    this.hasMultipleVariants = false,
  });

  @override
  State<VaultItemCard> createState() => _VaultItemCardState();
}

class _VaultItemCardState extends State<VaultItemCard> {
  bool? _isExpanded;

  VaultItem get item => widget.item;
  UserPersona? get persona => widget.persona;
  VoidCallback? get onTap => widget.onTap;
  bool? get isPrivacyMode => widget.isPrivacyMode;

  @override
  void didUpdateWidget(covariant VaultItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  bool _resolveInitialExpanded(BuildContext context) {
    return widget.initiallyExpanded ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final hasScope =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
            context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
                null;

    final bool effectiveExpanded =
        _isExpanded ?? _resolveInitialExpanded(context);

    final content = hasScope
        ? Consumer(
            builder: (context, ref, _) {
              final UserPersona activePersona =
                  persona ?? ref.watch(userPersonaProvider);
              final bool privacyActive =
                  isPrivacyMode ?? ref.watch(privacyModeProvider);
              return _buildCardContent(
                context,
                activePersona,
                isPrivacyMode: privacyActive,
                effectiveExpanded: effectiveExpanded,
              );
            },
          )
        : _buildCardContent(
            context,
            persona ?? UserPersona.investor,
            isPrivacyMode: isPrivacyMode ?? false,
            effectiveExpanded: effectiveExpanded,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: content,
          );
        }
        return content;
      },
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    UserPersona activePersona, {
    required bool isPrivacyMode,
    required bool effectiveExpanded,
  }) {
    final data = ParsedJsonCache.parse(item.dynamicData);

    String? manaCost = data['mana_cost']?.toString();
    String? typeLine = data['type_line']?.toString();
    String? oracleText = data['oracle_text']?.toString();
    if (data['card_faces'] is List && (data['card_faces'] as List).isNotEmpty) {
      final face0 = (data['card_faces'] as List)[0];
      if (face0 is Map) {
        manaCost ??= face0['mana_cost']?.toString();
        typeLine ??= face0['type_line']?.toString();
        oracleText ??= face0['oracle_text']?.toString();
      }
    }

    String? rulingsSnippet;
    if (data['rulings'] is List && (data['rulings'] as List).isNotEmpty) {
      final r0 = (data['rulings'] as List).first;
      if (r0 is Map) {
        rulingsSnippet = r0['comment']?.toString();
      } else if (r0 is String) {
        rulingsSnippet = r0;
      }
    } else if (data['scryfall_rulings'] is List &&
        (data['scryfall_rulings'] as List).isNotEmpty) {
      final r0 = (data['scryfall_rulings'] as List).first;
      if (r0 is Map) {
        rulingsSnippet = r0['comment']?.toString();
      }
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.surfaceBorderSubtle,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: AppColors.accentCyan.withValues(alpha: 0.08),
            highlightColor: Colors.transparent,
            listTileTheme: const ListTileThemeData(
              horizontalTitleGap: 12.0,
            ),
          ),
          child: ExpansionTile(
            key: Key('vault_item_expansion_tile_${item.id}'),
            initiallyExpanded: effectiveExpanded,
            maintainState: true,
            onExpansionChanged: (expanded) {
              setState(() {
                _isExpanded = expanded;
              });
            },
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            leading: GestureDetector(
              key: Key('vault_card_thumbnail_tap_${item.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap ?? () => CardDetailSheet.show(context, item),
              child: _buildLeadingThumbnail(width: 38, height: 52),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.flavorName != null && item.flavorName!.isNotEmpty
                        ? item.flavorName!
                        : item.name,
                    style: AppTypography.heading2.copyWith(fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (manaCost != null && manaCost.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ManaCostBar(
                        manaCost: manaCost,
                        symbolSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: _buildSubtitleRow(
              data,
              isPrivacyMode: isPrivacyMode,
              activePersona: activePersona,
              isExpanded: effectiveExpanded,
            ),
            trailing: _buildTrailing(data),
            children: [
              if (oracleText != null && oracleText.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.surfaceBorderSubtle,
                      width: 0.8,
                    ),
                  ),
                  child: ManaText(
                    oracleText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (rulingsSnippet != null && rulingsSnippet.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ruling: $rulingsSnippet',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              PolymorphicAttributeChip(
                collectionType: item.collectionType,
                dynamicDataJson: item.dynamicData,
              ),
              const SizedBox(height: 4),
              if (activePersona == UserPersona.investor)
                _buildInvestorFinancialRow(isPrivacyMode: isPrivacyMode)
              else
                _buildPlayerMechanicsRow(data),
              const SizedBox(height: 4),
              _buildQuickActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleRow(
    Map<String, dynamic> data, {
    required bool isPrivacyMode,
    required UserPersona activePersona,
    required bool isExpanded,
  }) {
    final rarity = (data['rarity']?.toString() ?? '').toLowerCase();
    final typeLine = data['type_line']?.toString() ?? '';
    final rarityColor = _getRarityColor(rarity);

    final String setAndNameText =
        item.flavorName != null && item.flavorName!.isNotEmpty
            ? '[${item.name}] • ${item.setOrSeries}'
            : item.setOrSeries;

    final effectivePrice = _getEffectiveMarketPrice();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final row = Row(
                children: [
                  Expanded(
                    child: Text(
                      setAndNameText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (rarity.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: rarityColor.withValues(alpha: 0.4),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            rarity.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: rarityColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (typeLine.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        typeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                  if (activePersona != UserPersona.player && !isExpanded) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isPrivacyMode
                              ? '****'
                              : (effectivePrice > 0
                                  ? '\$${effectivePrice.toStringAsFixed(2)}'
                                  : 'Unlisted'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentEmerald,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
              if (constraints.maxWidth < 60) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 60, maxWidth: 60),
                    child: row,
                  ),
                );
              }
              return row;
            },
          ),
          OptionalDeckBadges(item: item),
          OptionalCardAvailabilityBreakdown(item: item),
        ],
      ),
    );
  }

  Widget _buildTrailing(Map<String, dynamic> data) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
      children: [
        if (item.quantity > 1 || (widget.hasMultipleVariants && item.quantity == 1)) ...[
          Container(
            key: item.quantity > 1
                ? Key('vault_item_duplicate_badge_${item.id}')
                : Key('vault_item_variant_badge_${item.id}'),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (item.isGraded)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  item.condition.isNotEmpty ? item.condition : 'SLAB',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 2),
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
          )
        else if (item.condition.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppColors.surfaceBorder,
                width: 0.8,
              ),
            ),
            child: Text(
              item.condition.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(width: 2),
        const Icon(
          Icons.expand_more_rounded,
          color: AppColors.textMuted,
          size: 18,
        ),
      ],
    ),);
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            key: Key('vault_card_full_details_${item.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: AppColors.textDark,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              minimumSize: const Size(0, 26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 13),
            label: const Text(
              'Full Details',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            onPressed: onTap ?? () => CardDetailSheet.show(context, item),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            key: Key('vault_card_switch_printing_${item.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.surfaceBorder),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              minimumSize: const Size(0, 26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 13),
            label: const Text('Switch', style: TextStyle(fontSize: 10)),
            onPressed: () => CardDetailSheet.show(context, item),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            key: Key('vault_card_move_assign_${item.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.surfaceBorder),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              minimumSize: const Size(0, 26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.drive_file_move_outlined, size: 13),
            label: const Text('Move', style: TextStyle(fontSize: 10)),
            onPressed: () => CardDetailSheet.show(context, item),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
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

  double _getEffectiveMarketPrice() =>
      VaultPricingHelper.resolveEffectiveMarketPrice(item);

  Widget _buildInvestorFinancialRow({required bool isPrivacyMode}) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                      isPrivacyMode
                          ? '****'
                          : (effectivePrice > 0
                              ? '\$${effectivePrice.toStringAsFixed(2)}'
                              : 'Unlisted'),
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
                                  isPrivacyMode
                                      ? '****'
                                      : '\$${item.acquiredPrice.toStringAsFixed(2)}',
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
                                  isPrivacyMode
                                      ? '****'
                                      : (effectivePrice > 0
                                          ? '\$${effectivePrice.toStringAsFixed(2)}'
                                          : 'Unlisted'),
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
                                isPrivacyMode
                                    ? '****'
                                    : '$pctSign${pct.toStringAsFixed(1)}% ($deltaSign\$${delta.abs().toStringAsFixed(2)})',
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
        final decoded = ParsedJsonCache.parse(item.dynamicData);
        if (decoded.isNotEmpty) {
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
      } catch (e, stackTrace) {
        debugPrint('[VaultItemCard] Failed to extract small thumbnail URI: $e\n$stackTrace');
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
        child: IgnorePointer(
          child: CountrCachedImage(
            imageUrl: thumbUrl,
            cacheKey: CountrImageCacheManager.cardArtKey(item.id),
            cardName: item.name,
            tcgDomain: item.collectionType,
            fit: BoxFit.cover,
            width: width,
            height: height,
            errorWidget: _buildFallbackTypeIcon(width: width, height: height, borderRadius: borderRadius),
          ),
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

class OptionalDeckBadges extends StatelessWidget {
  final VaultItem item;
  const OptionalDeckBadges({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    bool hasProviderScope = false;
    context.visitAncestorElements((element) {
      final typeStr = element.widget.runtimeType.toString();
      if (typeStr == 'ProviderScope' || typeStr == 'UncontrolledProviderScope') {
        hasProviderScope = true;
        return false;
      }
      return true;
    });

    if (!hasProviderScope) return const SizedBox.shrink();

    return Consumer(
      builder: (context, ref, _) {
        final assignedDecks = ref.watch(
          allCardActiveDecksProvider.select((asyncVal) =>
              asyncVal.asData?.value[item.id] ?? const <String>[]),
        );
        if (assignedDecks.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: assignedDecks.map((deckName) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorderSubtle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
              ),
              child: Text(
                '⚔️ $deckName',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCyan,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class OptionalCardAvailabilityBreakdown extends StatelessWidget {
  final VaultItem item;
  const OptionalCardAvailabilityBreakdown({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.quantity <= 0) return const SizedBox.shrink();

    bool hasProviderScope = false;
    context.visitAncestorElements((element) {
      final typeStr = element.widget.runtimeType.toString();
      if (typeStr == 'ProviderScope' || typeStr == 'UncontrolledProviderScope') {
        hasProviderScope = true;
        return false;
      }
      return true;
    });

    if (!hasProviderScope) {
      return _buildPill(item.quantity, item.quantity, 0);
    }

    return Consumer(
      builder: (context, ref, _) {
        final availabilityMap = ref.watch(allCardAvailabilityProvider).valueOrNull;
        final availability = availabilityMap?[item.id] ??
            CardAvailability(
              owned: item.quantity,
              available: item.quantity,
              inDeck: 0,
            );

        return _buildPill(
          availability.owned,
          availability.available,
          availability.inDeck,
        );
      },
    );
  }

  Widget _buildPill(int owned, int available, int inDeck) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        key: Key('vault_item_availability_${item.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorderSubtle, width: 0.6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Owned: $owned',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCyan,
                ),
              ),
              const Text('  |  ', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              Text(
                'Available: $available',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentEmerald,
                ),
              ),
              const Text('  |  ', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              Text(
                'In Deck: $inDeck',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: inDeck > 0 ? AppColors.accentVioletLight : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


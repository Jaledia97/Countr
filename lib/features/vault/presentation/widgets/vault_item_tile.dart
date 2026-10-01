import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'card_detail_sheet.dart';

/// ManaBox-style Card Tile displaying card artwork, name, set code, and market price.
/// Designed for responsive multi-column grid layouts in the Vault.
class VaultItemTile extends StatelessWidget {
  final VaultItem item;
  final VoidCallback? onTap;
  final bool? isPrivacyMode;
  final bool hasMultipleVariants;

  const VaultItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.isPrivacyMode,
    this.hasMultipleVariants = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOwned = item.quantity > 0;

    return Container(
      key: Key('vault_tile_${item.id}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => CardDetailSheet.show(context, item),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxCaptionHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight * 0.48
                : double.infinity;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Artwork Container with Badges
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  item.imageUrl.isNotEmpty
                      ? CountrCachedImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),

                  // Gradient scrim at bottom of image
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Top Left: Graded or Foil Indicator (relocated to prevent badge collisions)
                  if (item.isGraded)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        key: Key('vault_tile_slab_badge_${item.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Text(
                          'SLAB',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    )
                  else if (item.condition.toLowerCase().contains('foil'))
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        key: Key('vault_tile_foil_badge_${item.id}'),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.accentCyan,
                          size: 11,
                        ),
                      ),
                    ),

                  // Top Right: Quantity Duplicate Badge or Unowned Reference Badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: isOwned
                        ? (item.quantity > 1 || hasMultipleVariants
                            ? Container(
                                key: item.quantity > 1
                                    ? Key('vault_tile_duplicate_badge_${item.id}')
                                    : Key('vault_tile_variant_badge_${item.id}'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  key: Key('vault_tile_quantity_badge_${item.id}'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink())
                        : (item.quantity == 0
                            ? Container(
                                key: Key('vault_tile_unowned_badge_${item.id}'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.accentAmber.withValues(alpha: 0.85),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'UNOWNED',
                                  style: TextStyle(
                                    color: AppColors.accentAmber,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 6.8,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink()),
                  ),

                  // Bottom Left on Image: Price Badge
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Builder(
                      builder: (context) {
                        final price = _getEffectiveMarketPrice();
                        final hasScope =
                            context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
                                context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;

                        if (hasScope) {
                          return Consumer(
                            builder: (context, ref, _) {
                              final bool privacyActive = isPrivacyMode ?? ref.watch(privacyModeProvider);
                              final currency = ref.watch(baseCurrencyProvider);
                              final priceText = formatMarketPriceLabel(
                                price,
                                currency: currency,
                                isPrivacyMode: privacyActive,
                              );
                              return _buildPriceBadge(priceText);
                            },
                          );
                        }

                        final priceText = formatMarketPriceLabel(
                          price,
                          isPrivacyMode: isPrivacyMode ?? false,
                        );
                        return _buildPriceBadge(priceText);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Caption Info
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxCaptionHeight),
              child: ClipRect(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.flavorName != null && item.flavorName!.isNotEmpty
                              ? item.flavorName!
                              : item.name,
                          style: AppTypography.heading2.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.flavorName != null && item.flavorName!.isNotEmpty
                              ? '[${item.name}] • ${item.setOrSeries}'
                              : item.setOrSeries,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Deck Badges
                        _OptionalTileDeckBadges(item: item),
                        // Availability Breakdown
                        _OptionalTileAvailabilityBreakdown(item: item),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  ),
);
  }

  double _getEffectiveMarketPrice() =>
      VaultPricingHelper.resolveEffectiveMarketPrice(item);

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.all(8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_outlined, size: 28, color: AppColors.textMuted),
              const SizedBox(height: 4),
              Text(
                item.name,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceBadge(String priceText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.5)),
      ),
      child: Text(
        priceText,
        style: const TextStyle(
          color: AppColors.accentAmber,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _OptionalTileDeckBadges extends StatelessWidget {
  final VaultItem item;
  const _OptionalTileDeckBadges({required this.item});

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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorderSubtle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
              ),
              child: Text(
                '⚔️ $deckName',
                style: const TextStyle(
                  fontSize: 8,
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

class _OptionalTileAvailabilityBreakdown extends StatelessWidget {
  final VaultItem item;
  const _OptionalTileAvailabilityBreakdown({required this.item});

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
      return _buildStaticBreakdown(item.quantity, item.quantity, 0);
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

        return _buildStaticBreakdown(
          availability.owned,
          availability.available,
          availability.inDeck,
        );
      },
    );
  }

  Widget _buildStaticBreakdown(int owned, int available, int inDeck) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Container(
        key: Key('vault_tile_availability_${item.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorderSubtle, width: 0.5),
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
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCyan,
                ),
              ),
              const Text(' | ', style: TextStyle(fontSize: 8.5, color: AppColors.textMuted)),
              Text(
                'Available: $available',
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentEmerald,
                ),
              ),
              const Text(' | ', style: TextStyle(fontSize: 8.5, color: AppColors.textMuted)),
              Text(
                'In Deck: $inDeck',
                style: TextStyle(
                  fontSize: 8.5,
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


import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'card_detail_sheet.dart';

/// ManaBox-style Card Tile displaying card artwork, name, set code, and market price.
/// Designed for responsive multi-column grid layouts in the Vault.
class VaultItemTile extends StatelessWidget {
  final VaultItem item;
  final VoidCallback? onTap;

  const VaultItemTile({
    super.key,
    required this.item,
    this.onTap,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Artwork Container with Badges
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholder(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: AppColors.surfaceRaised,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            );
                          },
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

                  // Top Left: Quantity or Unowned Badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: isOwned
                        ? (item.quantity > 1
                            ? Container(
                                key: Key('vault_tile_duplicate_badge_${item.id}'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.accentCyan.withValues(alpha: 0.8),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  style: const TextStyle(
                                    color: AppColors.accentCyan,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink())
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'REF',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                  ),

                  // Top Right: Graded or Foil Indicator
                  if (item.isGraded)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(5),
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
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.accentCyan,
                          size: 11,
                        ),
                      ),
                    ),

                  // Bottom Left on Image: Price Badge
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '\$${item.currentMarketPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Caption Info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.heading2.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.setOrSeries,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.all(8),
      child: Column(
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
    );
  }
}

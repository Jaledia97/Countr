import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

/// Standard Rec. 709 grayscale matrix filter for unowned cards.
const ColorFilter vaultGrayscaleColorFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
]);

/// Sliver displaying card collections grouped by set in a clean 2x2 grid
/// with visual completion progress, expandable card lists, and grayscale unowned card rendering.
class VaultCollectionViewSliver extends ConsumerStatefulWidget {
  final String activeGame;
  final String? searchQuery;

  const VaultCollectionViewSliver({
    super.key,
    required this.activeGame,
    this.searchQuery,
  });

  @override
  ConsumerState<VaultCollectionViewSliver> createState() =>
      _VaultCollectionViewSliverState();
}

class _VaultCollectionViewSliverState
    extends ConsumerState<VaultCollectionViewSliver> {
  String? _expandedSetCode;

  void _toggleExpand(String code) {
    setState(() {
      if (_expandedSetCode == code) {
        _expandedSetCode = null;
      } else {
        _expandedSetCode = code;
      }
    });
  }

  double _calculateChildAspectRatio(BuildContext context) {
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1.0);
    final screenWidth = media.size.width;
    if (textScale > 1.8) return 0.70;
    if (textScale > 1.3) return 0.90;
    if (screenWidth <= 360) return 1.05;
    return 1.15;
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(vaultSetCollectionsStreamProvider);

    return collectionsAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accentCyan),
              SizedBox(height: 16),
              Text(
                'Loading collections...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Error loading collections: $err',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
      data: (collections) {
        if (collections.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.collections_bookmark_outlined,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Collections in ${widget.activeGame}',
                      style: AppTypography.heading2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set collections will appear here once cards are saved or catalog data is hydrated.',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final dynamicAspectRatio = _calculateChildAspectRatio(context);
        final expanded = _expandedSetCode != null
            ? collections
                .where((c) =>
                    (c.setCode.isNotEmpty ? c.setCode : c.setName) ==
                    _expandedSetCode)
                .firstOrNull
            : null;

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverGrid(
                key: const Key('vault_collections_sliver_grid'),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: dynamicAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final collection = collections[index];
                    final code = collection.setCode.isNotEmpty
                        ? collection.setCode
                        : collection.setName;
                    final isExpanded = _expandedSetCode == code;
                    return VaultCollectionCard(
                      key: Key('vault_collection_tile_$code'),
                      collection: collection,
                      activeGame: widget.activeGame,
                      isExpanded: isExpanded,
                      onToggle: () => _toggleExpand(code),
                    );
                  },
                  childCount: collections.length,
                ),
              ),
            ),
            if (expanded != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _buildExpandedSection(context, expanded),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildExpandedSection(
    BuildContext context,
    VaultSetCollection collection,
  ) {
    final dao = ref.watch(vaultDaoProvider);
    final code =
        collection.setCode.isNotEmpty ? collection.setCode : collection.setName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_open_rounded,
                        size: 18,
                        color: AppColors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${collection.setName} Cards',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Close set cards',
                  onPressed: () => _toggleExpand(code),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.surfaceBorder, height: 1),
          StreamBuilder<List<VaultItem>>(
            stream: dao.watchItemsBySet(
              collection.setName,
              collectionType: widget.activeGame,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }

              final cards = snapshot.data ?? const <VaultItem>[];
              if (cards.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No cards found in this set',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  key: Key('vault_collection_grid_${collection.setCode}'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _VaultCollectionCardItem(item: card);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Compact 2x2 grid tile for an individual set collection with completion progress bar.
class VaultCollectionCard extends StatelessWidget {
  final VaultSetCollection collection;
  final String activeGame;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const VaultCollectionCard({
    super.key,
    required this.collection,
    required this.activeGame,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (collection.completionPercentage * 100);
    final pctFormatted = pct == pct.truncateToDouble()
        ? '${pct.toInt()}%'
        : '${pct.toStringAsFixed(1)}%';
    final statsText =
        '$pctFormatted • ${collection.ownedCount}/${collection.totalCount} owned';
    final code =
        collection.setCode.isNotEmpty ? collection.setCode : collection.setName;
    final isCompact = MediaQuery.sizeOf(context).width <= 360;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? AppColors.accentCyan : AppColors.surfaceBorder,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('vault_collection_header_$code'),
          onTap: onToggle,
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (collection.sampleImageUrl != null &&
                        collection.sampleImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CountrCachedImage(
                            imageUrl: collection.sampleImageUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.collections_bookmark_rounded,
                          color: AppColors.accentCyan,
                          size: 18,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (collection.setCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.surfaceBorder,
                                ),
                              ),
                              child: Text(
                                collection.setCode,
                                style: const TextStyle(
                                  color: AppColors.accentCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (collection.isComplete) ...[
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 10,
                                      color: AppColors.accentEmerald,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      '100%',
                                      style: TextStyle(
                                        color: AppColors.accentEmerald,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isExpanded
                          ? AppColors.accentCyan
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.setName,
                      style: AppTypography.heading2.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statsText,
                      style: TextStyle(
                        color: collection.isComplete
                            ? AppColors.accentEmerald
                            : AppColors.accentCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        key: Key('vault_collection_progress_$code'),
                        value: collection.completionPercentage.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          collection.isComplete
                              ? AppColors.accentEmerald
                              : AppColors.accentCyan,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid card item inside an expanded collection set.
/// Renders owned cards in full color and unowned cards in grayscale via ColorFiltered.matrix.
class _VaultCollectionCardItem extends StatelessWidget {
  final VaultItem item;

  const _VaultCollectionCardItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isOwned = item.quantity > 0;

    Widget artwork = item.imageUrl.isNotEmpty
        ? CountrCachedImage(
            imageUrl: item.imageUrl,
            fit: BoxFit.cover,
            errorWidget: _buildPlaceholder(),
          )
        : _buildPlaceholder();

    if (!isOwned) {
      artwork = ColorFiltered(
        key: Key('vault_collection_grayscale_${item.id}'),
        colorFilter: vaultGrayscaleColorFilter,
        child: artwork,
      );
    }

    String? collectorNumber;
    if (item.dynamicData.isNotEmpty) {
      try {
        final parsed = jsonDecode(item.dynamicData) as Map<String, dynamic>;
        collectorNumber = parsed['collector_number']?.toString();
      } catch (_) {}
    }

    return InkWell(
      key: Key('vault_collection_item_${item.id}'),
      onTap: () => CardDetailSheet.show(context, item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOwned
                ? AppColors.surfaceBorder
                : AppColors.surfaceBorder.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            artwork,
            // Gradient scrim at bottom for text readability
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 38,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                alignment: Alignment.bottomLeft,
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Top badges: Collector number and owned/unowned status
            if (collectorNumber != null && collectorNumber.isNotEmpty)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#$collectorNumber',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (!isOwned)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: const Text(
                    'UNOWNED',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              )
            else if (item.quantity > 1)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.quantity}x',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceHighlight,
      alignment: Alignment.center,
      child: const Icon(
        Icons.style_outlined,
        color: AppColors.textMuted,
        size: 24,
      ),
    );
  }
}

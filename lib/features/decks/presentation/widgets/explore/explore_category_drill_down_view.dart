import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';

/// Dedicated 2-column grid view displaying all explore decks belonging to a
/// specific featured category without the 15-item carousel cap, featuring a
/// sticky header bar with back navigation, category icon & title, live total
/// count badge, and quick reset button.
class ExploreCategoryDrillDownView extends ConsumerWidget {
  final String category;
  final VoidCallback? onBack;
  final List<ExploreDeckWithVote>? customDecks;
  final ValueChanged<ExploreDeckWithVote>? onTapDeck;

  const ExploreCategoryDrillDownView({
    super.key,
    required this.category,
    this.onBack,
    this.customDecks,
    this.onTapDeck,
  });

  IconData _resolveCategoryIcon() {
    switch (category) {
      case 'Suggested Commanders':
        return Icons.shield_rounded;
      case 'From Top Deck Builders':
        return Icons.workspace_premium_rounded;
      case 'Popular Standard Decks':
        return Icons.trending_up_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _resolveAccentColor() {
    switch (category) {
      case 'Suggested Commanders':
        return AppColors.accentCyan;
      case 'From Top Deck Builders':
        return AppColors.accentAmber;
      case 'Popular Standard Decks':
        return AppColors.accentEmerald;
      default:
        return AppColors.accentCyan;
    }
  }

  void _handleBack(BuildContext context, WidgetRef ref) {
    if (onBack != null) {
      onBack!();
    } else {
      final currentCategory = ref.read(exploreDrillDownCategoryProvider);
      if (currentCategory != null) {
        ref.read(exploreDrillDownCategoryProvider.notifier).state = null;
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildStickyHeader({
    required BuildContext context,
    required WidgetRef ref,
    required int totalCount,
    required Color accentColor,
    required IconData categoryIcon,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final isLargeText = textScaler.scale(1.0) > 1.2;
        final isExtremeNarrow = constraints.maxWidth < 320;
        final isNarrow = constraints.maxWidth < 420 || isLargeText;
        final showTextReset = constraints.maxWidth >= 540 && !isLargeText;

        final double horizontalPadding = isExtremeNarrow ? 6.0 : (isNarrow ? 8.0 : 12.0);
        final double maxBadgeWidth = math.min(
          isExtremeNarrow ? 68.0 : (isNarrow ? 82.0 : 110.0),
          constraints.maxWidth * 0.28,
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: isExtremeNarrow ? 6.0 : 8.0,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            border: Border(
              bottom: BorderSide(
                color: AppColors.surfaceBorderSubtle,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Back button
              IconButton(
                key: const Key('explore_drill_down_back_button'),
                icon: const Icon(Icons.arrow_back_rounded),
                iconSize: isExtremeNarrow ? 18 : (isNarrow ? 20 : 24),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size(
                    isExtremeNarrow ? 28 : (isNarrow ? 32 : 40),
                    isExtremeNarrow ? 28 : (isNarrow ? 32 : 40),
                  ),
                  padding: EdgeInsets.zero,
                ),
                constraints: BoxConstraints(
                  minWidth: isExtremeNarrow ? 28 : (isNarrow ? 32 : 40),
                  minHeight: isExtremeNarrow ? 28 : (isNarrow ? 32 : 40),
                ),
                color: AppColors.textPrimary,
                tooltip: 'Back to Explore Feed',
                onPressed: () => _handleBack(context, ref),
              ),
              SizedBox(width: isExtremeNarrow ? 4 : (isNarrow ? 4 : 6)),

              // Category Icon Badge
              Container(
                padding: EdgeInsets.all(isExtremeNarrow ? 3 : (isNarrow ? 4 : 6)),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(isExtremeNarrow ? 5 : (isNarrow ? 6 : 8)),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  categoryIcon,
                  size: isExtremeNarrow ? 12 : (isNarrow ? 14 : 16),
                  color: accentColor,
                ),
              ),
              SizedBox(width: isExtremeNarrow ? 4 : (isNarrow ? 6 : 10)),

              // Category Title
              Expanded(
                child: Text(
                  category,
                  key: const Key('explore_drill_down_title'),
                  style: AppTypography.heading2.copyWith(
                    fontSize: isExtremeNarrow ? 13 : (isNarrow ? 14 : 16),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: isExtremeNarrow ? 4 : (isNarrow ? 6 : 8)),

              // Total Count Badge (annotated with both drill-down key and general explore badge key)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxBadgeWidth,
                ),
                child: Container(
                  key: const Key('explore_decks_count_badge'),
                  padding: EdgeInsets.symmetric(
                    horizontal: isExtremeNarrow ? 5 : (isNarrow ? 6 : 8),
                    vertical: isExtremeNarrow ? 2 : (isNarrow ? 3 : 4),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorderSubtle),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$totalCount decks',
                      key: const Key('explore_drill_down_count_badge'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: isExtremeNarrow ? 10 : (isNarrow ? 11 : 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isExtremeNarrow ? 4 : (isNarrow ? 4 : 8)),

              // Reset Button
              if (showTextReset)
                TextButton.icon(
                  key: const Key('explore_drill_down_reset_button'),
                  onPressed: () => _handleBack(context, ref),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                )
              else
                IconButton(
                  key: const Key('explore_drill_down_reset_button'),
                  icon: Icon(Icons.close_rounded, size: isExtremeNarrow ? 16 : 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size(
                      isExtremeNarrow ? 28 : (isNarrow ? 32 : 36),
                      isExtremeNarrow ? 28 : (isNarrow ? 32 : 36),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  constraints: BoxConstraints(
                    minWidth: isExtremeNarrow ? 28 : (isNarrow ? 32 : 36),
                    minHeight: isExtremeNarrow ? 28 : (isNarrow ? 32 : 36),
                  ),
                  color: AppColors.textMuted,
                  tooltip: 'Reset',
                  onPressed: () => _handleBack(context, ref),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<ExploreDeckWithVote> decks) {
    if (decks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_rounded,
                size: 40,
                color: AppColors.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No decks found in $category',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.52,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final deck = decks[index];
            return ExploreDeckCard(
              deckWithVote: deck,
              onTap: onTapDeck != null ? () => onTapDeck!(deck) : null,
            );
          },
          childCount: decks.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = _resolveAccentColor();
    final categoryIcon = _resolveCategoryIcon();

    final decksAsync = customDecks != null
        ? AsyncValue.data(customDecks!)
        : ref.watch(featuredCategoryDecksStreamProvider(category));

    final countAsync = customDecks != null
        ? AsyncValue.data(customDecks!.length)
        : ref.watch(featuredCategoryDeckCountProvider(category));

    final decks = decksAsync.valueOrNull ?? const [];
    final totalCount = countAsync.valueOrNull ?? decks.length;

    return PopScope(
      key: const Key('explore_drill_down_pop_scope'),
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context, ref);
      },
      child: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // 1. Sticky / Pinned Header Bar
            _buildStickyHeader(
              context: context,
              ref: ref,
              totalCount: totalCount,
              accentColor: accentColor,
              categoryIcon: categoryIcon,
            ),

            // 2. Paginated 2-Column Grid
            Expanded(
              child: CustomScrollView(
                key: PageStorageKey('explore_drill_down_${category}_scroll_key'),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (decksAsync.isLoading && decks.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    )
                  else if (decksAsync.hasError && decks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Failed to load decks for $category',
                          style: const TextStyle(
                            color: AppColors.accentAmber,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildGrid(decks),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone full-screen route for category drill-down navigation push scenarios.
class ExploreCategoryDrillDownScreen extends ConsumerWidget {
  final String category;
  final ValueChanged<ExploreDeckWithVote>? onTapDeck;

  const ExploreCategoryDrillDownScreen({
    super.key,
    required this.category,
    this.onTapDeck,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ExploreCategoryDrillDownView(
          category: category,
          onTapDeck: onTapDeck,
          onBack: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              ref.read(exploreDrillDownCategoryProvider.notifier).state = null;
            }
          },
        ),
      ),
    );
  }
}

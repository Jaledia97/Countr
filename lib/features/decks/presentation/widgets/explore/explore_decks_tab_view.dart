import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_search_bar.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_carousel_section.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_search_results_view.dart';

/// Tab 1 host widget for "Explore Decks", maintaining independent scroll offsets via
/// [AutomaticKeepAliveClientMixin] and [PageStorageKey], providing top category pills,
/// embedded search and sort, multi-level search results, and a dynamic discovery feed
/// featuring a 2-column grid interspersed with horizontal category carousels.
class ExploreDecksTabView extends ConsumerStatefulWidget {
  const ExploreDecksTabView({super.key});

  @override
  ConsumerState<ExploreDecksTabView> createState() => _ExploreDecksTabViewState();
}

class _ExploreDecksTabViewState extends ConsumerState<ExploreDecksTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Widget _buildTopCategoryPills(ExploreCategory currentCategory) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.surfaceBorderSubtle,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ExploreCategoryPill(
              key: const Key('explore_pill_all'),
              label: 'All',
              isSelected: currentCategory == ExploreCategory.all,
              onTap: () {
                ref.read(activeExploreCategoryProvider.notifier).state =
                    ExploreCategory.all;
              },
            ),
            const SizedBox(width: 8),
            _ExploreCategoryPill(
              key: const Key('explore_pill_official'),
              label: 'Official (WotC)',
              isSelected: currentCategory == ExploreCategory.official,
              onTap: () {
                ref.read(activeExploreCategoryProvider.notifier).state =
                    ExploreCategory.official;
              },
            ),
            const SizedBox(width: 8),
            _ExploreCategoryPill(
              key: const Key('explore_pill_community'),
              label: 'Community',
              isSelected: currentCategory == ExploreCategory.community,
              onTap: () {
                ref.read(activeExploreCategoryProvider.notifier).state =
                    ExploreCategory.community;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSlice(List<ExploreDeckWithVote> slice) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final deck = slice[index];
            return ExploreDeckCard(deckWithVote: deck);
          },
          childCount: slice.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentCategory = ref.watch(activeExploreCategoryProvider);
    final searchQuery = ref.watch(exploreSearchQueryProvider);
    final exploreDecksAsync = ref.watch(exploreDecksStreamProvider);
    final isSearching = searchQuery.trim().isNotEmpty;

    final decks = exploreDecksAsync.valueOrNull ?? const [];
    final slice1 = decks.take(4).toList();
    final slice2 = decks.skip(4).take(4).toList();
    final slice3 = decks.skip(8).toList();

    return CustomScrollView(
      key: const PageStorageKey('explore_decks_scroll_key'),
      slivers: [
        // 1. Search Bar with embedded sort & filter trigger
        const SliverToBoxAdapter(
          child: ExploreSearchBar(),
        ),

        // 2. Top Category Pills
        SliverToBoxAdapter(
          child: _buildTopCategoryPills(currentCategory),
        ),

        // 3. Search Mode vs Discovery Feed Mode
        if (isSearching) ...[
          SliverToBoxAdapter(
            child: ExploreSearchResultsView(
              query: searchQuery,
              shrinkWrap: true,
            ),
          ),
        ] else ...[
          // Discovery Feed Mode
          // Carousel 1: Suggested Commanders
          const SliverToBoxAdapter(
            child: ExploreCarouselSection(
              category: 'Suggested Commanders',
            ),
          ),

          // Primary 2-Column Grid: Slice 1
          _buildGridSlice(slice1),

          // Carousel 2: From Top Deck Builders
          const SliverToBoxAdapter(
            child: ExploreCarouselSection(
              category: 'From Top Deck Builders',
            ),
          ),

          // Primary 2-Column Grid: Slice 2 (if present, else minimal sliver)
          if (slice2.isNotEmpty) _buildGridSlice(slice2),

          // Carousel 3: Popular Standard Decks
          const SliverToBoxAdapter(
            child: ExploreCarouselSection(
              category: 'Popular Standard Decks',
            ),
          ),

          // Primary 2-Column Grid: Slice 3 (if present)
          if (slice3.isNotEmpty) _buildGridSlice(slice3),

          // Empty state indicator if feed has no decks and is not loading
          if (decks.isEmpty && !exploreDecksAsync.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.explore_off_rounded,
                        size: 40,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No community or precon decks found in this category',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ],
    );
  }
}

class _ExploreCategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExploreCategoryPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

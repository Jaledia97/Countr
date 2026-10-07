import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_filter_modal.dart';

/// Dedicated search bar for the "Explore Decks" tab with an embedded sort popup menu button,
/// filter modal trigger button, and reactive query synchronization.
class ExploreSearchBar extends ConsumerStatefulWidget {
  const ExploreSearchBar({super.key});

  @override
  ConsumerState<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends ConsumerState<ExploreSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(exploreSearchQueryProvider);
    _controller = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep local controller in sync if provider updates externally
    ref.listen<String>(exploreSearchQueryProvider, (prev, next) {
      if (next != _controller.text) {
        _controller.text = next;
      }
    });

    final currentQuery = ref.watch(exploreSearchQueryProvider);
    final currentSort = ref.watch(activeExploreSortOptionProvider);
    final filterState = ref.watch(exploreFilterStateProvider);
    final hasActiveFilters = !filterState.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActiveFilters ? AppColors.accentCyan : AppColors.surfaceBorder,
          width: hasActiveFilters ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Search Icon
          const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ),

          // Search Text Input
          Expanded(
            child: TextField(
              key: const Key('explore_search_input'),
              controller: _controller,
              onChanged: (value) {
                ref.read(exploreSearchQueryProvider.notifier).state = value;
              },
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search decks, cards, creators...',
                hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Clear Button
          if (currentQuery.isNotEmpty)
            IconButton(
              key: const Key('explore_search_clear_button'),
              icon: const Icon(
                Icons.clear_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              tooltip: 'Clear search',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 16,
              onPressed: () {
                _controller.clear();
                ref.read(exploreSearchQueryProvider.notifier).state = '';
              },
            ),

          // Divider before embedded sort
          Container(
            width: 1,
            height: 22,
            color: AppColors.surfaceBorder,
            margin: const EdgeInsets.symmetric(horizontal: 2),
          ),

          // Embedded Sort Popup Menu Button
          PopupMenuButton<ExploreSortOption>(
            key: const Key('explore_search_sort_button'),
            initialValue: currentSort,
            tooltip: 'Sort options',
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.swap_vert_rounded,
              size: 20,
              color: AppColors.accentCyan,
            ),
            splashRadius: 18,
            color: AppColors.surface,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            onSelected: (option) {
              ref.read(activeExploreSortOptionProvider.notifier).state = option;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                key: Key('explore_sort_popular'),
                value: ExploreSortOption.popularity,
                child: Text('Most Popular / Upvotes'),
              ),
              const PopupMenuItem(
                key: Key('explore_sort_recent'),
                value: ExploreSortOption.recentlyAdded,
                child: Text('Recently Added'),
              ),
              const PopupMenuItem(
                key: Key('explore_sort_price_asc'),
                value: ExploreSortOption.priceLowToHigh,
                child: Text('Price: Low to High'),
              ),
              const PopupMenuItem(
                key: Key('explore_sort_price_desc'),
                value: ExploreSortOption.priceHighToLow,
                child: Text('Price: High to Low'),
              ),
              const PopupMenuItem(
                key: Key('explore_sort_alpha'),
                value: ExploreSortOption.alphabetical,
                child: Text('Alphabetical (A-Z)'),
              ),
            ],
          ),

          // Filter Modal Trigger Button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                key: const Key('explore_filter_button'),
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: hasActiveFilters ? AppColors.accentCyan : AppColors.textSecondary,
                ),
                tooltip: 'Filter explore decks',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                splashRadius: 18,
                onPressed: () {
                  ExploreFilterModal.show(context);
                },
              ),
              if (hasActiveFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.accentCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

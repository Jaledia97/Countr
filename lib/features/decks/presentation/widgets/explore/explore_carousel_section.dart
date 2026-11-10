import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';

/// Horizontal scrolling category carousel highlighting curated categories
/// ("Suggested Commanders", "From Top Deck Builders", "Popular Standard Decks").
class ExploreCarouselSection extends ConsumerWidget {
  final String category;
  final String? title;
  final Key? sectionKey;
  final List<ExploreDeckWithVote>? customDecks;
  final ValueChanged<ExploreDeckWithVote>? onTapDeck;
  final VoidCallback? onSeeMore;

  const ExploreCarouselSection({
    super.key,
    required this.category,
    this.title,
    this.sectionKey,
    this.customDecks,
    this.onTapDeck,
    this.onSeeMore,
  });

  Key _resolveKey() {
    if (sectionKey != null) return sectionKey!;
    switch (category) {
      case 'Suggested Commanders':
        return const Key('explore_carousel_suggested_commanders');
      case 'From Top Deck Builders':
        return const Key('explore_carousel_top_builders');
      case 'Popular Standard Decks':
        return const Key('explore_carousel_popular_standard');
      case "Today's Picks":
        return const Key('explore_carousel_todays_picks');
      case "This Week's Picks":
        return const Key('explore_carousel_this_weeks_picks');
      case "This Month's Picks":
        return const Key('explore_carousel_this_months_picks');
      default:
        final normalized = category
            .toLowerCase()
            .replaceAll("'", '')
            .replaceAll('(', '')
            .replaceAll(')', '')
            .replaceAll('<', '')
            .replaceAll(r'$', '')
            .replaceAll(' ', '_');
        return Key('explore_carousel_$normalized');
    }
  }

  String _resolveNormalizedCategory() {
    switch (category) {
      case 'Suggested Commanders':
        return 'suggested_commanders';
      case 'From Top Deck Builders':
        return 'top_builders';
      case 'Popular Standard Decks':
        return 'popular_standard';
      case "Today's Picks":
        return 'todays_picks';
      case "This Week's Picks":
        return 'this_weeks_picks';
      case "This Month's Picks":
        return 'this_months_picks';
      default:
        return category
            .toLowerCase()
            .replaceAll("'", '')
            .replaceAll('(', '')
            .replaceAll(')', '')
            .replaceAll('<', '')
            .replaceAll(r'$', '')
            .replaceAll(' ', '_');
    }
  }

  Key _resolveSeeMoreKey() {
    return Key('explore_carousel_see_more_${_resolveNormalizedCategory()}');
  }

  Key? _resolveSeeMoreAliasKey() {
    final literal = category.toLowerCase().replaceAll(' ', '_');
    final norm = _resolveNormalizedCategory();
    if (literal != norm) {
      return Key('explore_carousel_see_more_$literal');
    }
    return null;
  }

  IconData _resolveCategoryIcon() {
    switch (category) {
      case 'Suggested Commanders':
        return Icons.shield_rounded;
      case 'From Top Deck Builders':
        return Icons.workspace_premium_rounded;
      case 'Popular Standard Decks':
        return Icons.trending_up_rounded;
      case "Today's Picks":
      case "This Week's Picks":
      case "This Month's Picks":
        return Icons.local_fire_department_rounded;
      case 'Hot New Precons':
        return Icons.whatshot_rounded;
      case r'Trending Budget Brews (<$100)':
        return Icons.savings_rounded;
      case 'Most Upvoted Mono-Color Commanders':
        return Icons.palette_rounded;
      case 'Tribal Spotlight':
        return Icons.pets_rounded;
      case 'Rising Community Builders':
        return Icons.group_rounded;
      case 'Top Modern Decks':
        return Icons.flash_on_rounded;
      case 'Pioneer Showdown':
        return Icons.military_tech_rounded;
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
      case "Today's Picks":
        return AppColors.accentAmber;
      case "This Week's Picks":
        return AppColors.accentCyan;
      case "This Month's Picks":
        return AppColors.accentViolet;
      case r'Trending Budget Brews (<$100)':
        return AppColors.accentEmerald;
      case 'Most Upvoted Mono-Color Commanders':
        return AppColors.accentViolet;
      case 'Hot New Precons':
        return AppColors.accentAmber;
      case 'Tribal Spotlight':
        return AppColors.accentCyan;
      case 'Rising Community Builders':
        return AppColors.accentAmber;
      case 'Top Modern Decks':
        return AppColors.accentRose;
      case 'Pioneer Showdown':
        return AppColors.accentRose;
      default:
        return AppColors.accentCyan;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveKey = _resolveKey();
    final displayTitle = title ?? category;
    final accentColor = _resolveAccentColor();
    final categoryIcon = _resolveCategoryIcon();

    final decksAsync = customDecks != null
        ? AsyncValue.data(customDecks!)
        : ref.watch(featuredExploreCategoryStreamProvider(category));

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final carouselHeight = textScale > 1.2
        ? (350.0 + (textScale - 1.0) * 70.0)
        : 350.0;

    return Container(
      key: effectiveKey,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    categoryIcon,
                    size: 16,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: AppTypography.heading2.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: InkWell(
                      key: _resolveSeeMoreKey(),
                      onTap: () {
                        if (onSeeMore != null) {
                          onSeeMore!();
                        } else {
                          ref.read(exploreDrillDownCategoryProvider.notifier).state =
                              category;
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          key: _resolveSeeMoreAliasKey(),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'See More',
                              style: AppTypography.caption.copyWith(
                                color: accentColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          // Horizontal Carousel List
          SizedBox(
            height: carouselHeight,
            child: decksAsync.when(
              data: (decks) {
                if (decks.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          'No decks currently featured in $displayTitle',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: decks.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final deck = decks[index];
                    return SizedBox(
                      width: 175,
                      child: ExploreDeckCard(
                        deckWithVote: deck,
                        isCompact: true,
                        onTap: onTapDeck != null ? () => onTapDeck!(deck) : null,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentCyan,
                  ),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'Unable to load $displayTitle',
                    style: const TextStyle(color: AppColors.accentAmber, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

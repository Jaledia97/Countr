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

  const ExploreCarouselSection({
    super.key,
    required this.category,
    this.title,
    this.sectionKey,
    this.customDecks,
    this.onTapDeck,
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
      default:
        final normalized = category.toLowerCase().replaceAll(' ', '_');
        return Key('explore_carousel_$normalized');
    }
  }

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveKey = _resolveKey();
    final displayTitle = title ?? category;
    final accentColor = _resolveAccentColor();
    final categoryIcon = _resolveCategoryIcon();

    final decksAsync = customDecks != null
        ? AsyncValue.data(customDecks!)
        : ref.watch(featuredExploreCategoryStreamProvider(category));

    return Container(
      key: effectiveKey,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                Text(
                  'Featured',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Horizontal Carousel List
          SizedBox(
            height: 215,
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

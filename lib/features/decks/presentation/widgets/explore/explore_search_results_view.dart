import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';

/// Presentation view for partitioned Explore deck search results, categorized under
/// "in Deck Name", "in Deck Cards" (with contains: [Card Name] subtitle), and "by Username".
class ExploreSearchResultsView extends ConsumerWidget {
  final String query;
  final ExploreSearchResults? customResults;
  final ValueChanged<ExploreDeckWithVote>? onTapDeck;
  final bool shrinkWrap;

  const ExploreSearchResultsView({
    super.key,
    required this.query,
    this.customResults,
    this.onTapDeck,
    this.shrinkWrap = true,
  });

  Widget _buildSectionHeader({
    required Key key,
    required String title,
    required IconData icon,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            key: key,
            style: AppTypography.heading2.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accentCyan,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: AppColors.surfaceBorder,
        height: 1,
        thickness: 1,
      ),
    );
  }

  Widget _buildResultsContent(BuildContext context, ExploreSearchResults results) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 52,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                'No decks found',
                style: AppTypography.heading2.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                query.isNotEmpty
                    ? 'No explore decks match "$query".'
                    : 'Search across deck names, contained cards, or usernames.',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[
      // Tier 1: in Deck Name
      if (results.inDeckName.isNotEmpty) ...[
        _buildSectionHeader(
          key: const Key('explore_search_group_name'),
          title: 'in Deck Name',
          icon: Icons.style_rounded,
          count: results.inDeckName.length,
        ),
        for (final deck in results.inDeckName) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ExploreDeckCard(
              deckWithVote: deck,
              onTap: () => onTapDeck?.call(deck),
            ),
          ),
        ],
      ],

      // Divider if Tier 1 and Tier 2 both present
      if (results.inDeckName.isNotEmpty &&
          (results.inDeckCards.isNotEmpty || results.byUsername.isNotEmpty))
        _buildDivider(),

      // Tier 2: in Deck Cards (with contains: [Card Name] subtitle)
      if (results.inDeckCards.isNotEmpty) ...[
        _buildSectionHeader(
          key: const Key('explore_search_group_cards'),
          title: 'in Deck Cards',
          icon: Icons.filter_none_rounded,
          count: results.inDeckCards.length,
        ),
        for (final match in results.inDeckCards) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ExploreDeckCard(
              deckWithVote: match.deckWithVote,
              cardMatch: match,
              onTap: () => onTapDeck?.call(match.deckWithVote),
            ),
          ),
        ],
      ],

      // Divider if Tier 2 and Tier 3 both present
      if (results.inDeckCards.isNotEmpty && results.byUsername.isNotEmpty)
        _buildDivider(),

      // Tier 3: by Username
      if (results.byUsername.isNotEmpty) ...[
        _buildSectionHeader(
          key: const Key('explore_search_group_creator'),
          title: 'by Username',
          icon: Icons.account_circle_rounded,
          count: results.byUsername.length,
        ),
        for (final deck in results.byUsername) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ExploreDeckCard(
              deckWithVote: deck,
              onTap: () => onTapDeck?.call(deck),
            ),
          ),
        ],
      ],
    ];

    if (shrinkWrap) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customResults != null) {
      return _buildResultsContent(context, customResults!);
    }

    final resultsAsync = ref.watch(exploreSearchResultsProvider(query));

    return resultsAsync.when(
      data: (results) => _buildResultsContent(context, results),
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Error searching explore decks: $err',
            style: const TextStyle(color: AppColors.accentAmber),
          ),
        ),
      ),
    );
  }
}

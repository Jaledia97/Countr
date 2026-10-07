import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/domain/models/my_decks_search_result.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_deck_card.dart';

/// Presentation view for partitioned personal deck search results, categorized under
/// "in Deck Name" and "contains Card" headings with styled line-break dividers.
class MyDecksSearchResultsView extends StatelessWidget {
  final MyDecksSearchResults results;
  final String query;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<DeckSummary>? onTapDeck;
  final ValueChanged<DeckSummary>? onLongPressDeck;
  final ValueChanged<DeckSummary>? onShareToExplore;

  const MyDecksSearchResultsView({
    super.key,
    required this.results,
    this.query = '',
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.onTapDeck,
    this.onLongPressDeck,
    this.onShareToExplore,
  });

  Widget _buildSectionHeader({
    required Key key,
    required String title,
    required IconData icon,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            key: key,
            style: AppTypography.heading2.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accentCyan,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No decks found',
                style: AppTypography.heading2.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                query.isNotEmpty
                    ? 'No personal decks or cards match "$query".'
                    : 'Try searching by deck title or card name.',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        // Section 1: Matches in Deck Name
        if (results.inDeckName.isNotEmpty) ...[
          _buildSectionHeader(
            key: const Key('my_decks_search_header_name'),
            title: 'in Deck Name',
            icon: Icons.style_rounded,
            count: results.inDeckName.length,
          ),
          for (final deck in results.inDeckName)
            MyDeckCard(
              deck: deck,
              isSelectionMode: isSelectionMode,
              isSelected: selectedIds.contains(deck.id),
              onSelectedChanged: (_) => onToggleSelect?.call(deck.id),
              onTap: () => onTapDeck?.call(deck),
              onLongPress: () => onLongPressDeck?.call(deck),
              onShareToExplore: onShareToExplore,
            ),
        ],

        // Visual Divider separating Match Tiers
        if (results.inDeckName.isNotEmpty && results.inDeckCards.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              color: AppColors.surfaceBorder,
              height: 1,
              thickness: 1,
            ),
          ),
        ],

        // Section 2: Matches in Deck Cards
        if (results.inDeckCards.isNotEmpty) ...[
          _buildSectionHeader(
            key: const Key('my_decks_search_header_cards'),
            title: 'contains Card',
            icon: Icons.filter_none_rounded,
            count: results.inDeckCards.length,
          ),
          for (final match in results.inDeckCards)
            MyDeckCard(
              deck: match.deck,
              cardMatch: match,
              isSelectionMode: isSelectionMode,
              isSelected: selectedIds.contains(match.deck.id),
              onSelectedChanged: (_) => onToggleSelect?.call(match.deck.id),
              onTap: () => onTapDeck?.call(match.deck),
              onLongPress: () => onLongPressDeck?.call(match.deck),
              onShareToExplore: onShareToExplore,
            ),
        ],
      ],
    );
  }
}

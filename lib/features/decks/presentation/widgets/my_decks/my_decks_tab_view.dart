import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_decks_search_bar.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_decks_search_results_view.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_decks_selection_footer.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';

/// Tab 0 host widget for "My Decks", maintaining independent scroll offsets via
/// [AutomaticKeepAliveClientMixin] and [PageStorageKey], providing quick filter pills,
/// personal multi-tier search, and press-and-hold multi-selection sharing.
class MyDecksTabView extends ConsumerStatefulWidget {
  final ValueChanged<DeckSummary>? onShareDeckToExplore;

  const MyDecksTabView({
    super.key,
    this.onShareDeckToExplore,
  });

  @override
  ConsumerState<MyDecksTabView> createState() => _MyDecksTabViewState();
}

class _MyDecksTabViewState extends ConsumerState<MyDecksTabView>
    with AutomaticKeepAliveClientMixin {
  int _activeSubTab = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final db = ref.read(appDatabaseProvider);
        ExploreSeederService.seedIfNeeded(db);
        PreconHydrationService.seedHistoricalPrecons(db);
      });
    }
  }

  void _navigateToDeckBuilder(DeckSummary summary) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => DeckBuilderScreen(deck: summary.deck),
      ),
    );
  }

  void _handleDeckTap(DeckSummary summary, bool isSelectionMode, Set<String> selectedIds) {
    if (isSelectionMode) {
      _toggleSelection(summary.id);
    } else {
      _navigateToDeckBuilder(summary);
    }
  }

  void _handleDeckLongPress(DeckSummary summary) {
    final current = ref.read(myDecksSelectedIdsProvider);
    if (!current.contains(summary.id)) {
      ref.read(myDecksSelectedIdsProvider.notifier).state = {...current, summary.id};
    }
  }

  void _toggleSelection(String deckId) {
    final current = ref.read(myDecksSelectedIdsProvider);
    final updated = Set<String>.from(current);
    if (updated.contains(deckId)) {
      updated.remove(deckId);
    } else {
      updated.add(deckId);
    }
    ref.read(myDecksSelectedIdsProvider.notifier).state = updated;
  }

  void _exitSelectionMode() {
    ref.read(myDecksSelectedIdsProvider.notifier).state = <String>{};
  }

  void _shareSelectedDeck(List<DeckSummary> allDecks) {
    final selectedIds = ref.read(myDecksSelectedIdsProvider);
    if (selectedIds.length != 1) return;
    final targetId = selectedIds.first;
    final deck = allDecks.firstWhere(
      (d) => d.id == targetId,
      orElse: () => allDecks.first,
    );
    widget.onShareDeckToExplore?.call(deck);
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final activeFilter = ref.watch(activeDeckTcgFilterProvider);
    final allSummaries = ref.watch(myDecksCombinedSummariesProvider);
    final searchQuery = ref.watch(myDecksSearchQueryProvider).trim();
    final selectedIds = ref.watch(myDecksSelectedIdsProvider);
    final isSelectionMode = selectedIds.isNotEmpty;

    // Filter by TCG domain first
    final domainDecks = allSummaries.where((deck) {
      if (activeFilter == 'all') return true;
      return deck.tcgDomain == activeFilter;
    }).toList();

    // Filter by Subheader Tab next
    final filteredDecks = domainDecks.where((deck) {
      if (_activeSubTab == 1) {
        return deck.isCompetitive == true;
      } else if (_activeSubTab == 2) {
        return deck.isRegistered == false;
      }
      return true;
    }).toList();

    final searchResultsAsync = searchQuery.isNotEmpty
        ? ref.watch(myDecksSearchResultsProvider)
        : null;

    return Stack(
      children: [
        Column(
          children: [
            // Search Input
            const MyDecksSearchBar(),

            // Subheader Tab Filter Pills (All Decks, Competitive, Draft)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    _SubTabPill(
                      key: const Key('decks_tab_all'),
                      label: 'All Decks (${domainDecks.length})',
                      isSelected: _activeSubTab == 0,
                      onTap: () => setState(() => _activeSubTab = 0),
                    ),
                    const SizedBox(width: 8),
                    _SubTabPill(
                      key: const Key('decks_tab_competitive'),
                      label: 'Competitive',
                      isSelected: _activeSubTab == 1,
                      onTap: () => setState(() => _activeSubTab = 1),
                    ),
                    const SizedBox(width: 8),
                    _SubTabPill(
                      key: const Key('decks_tab_draft'),
                      label: 'Draft / In-Progress',
                      isSelected: _activeSubTab == 2,
                      onTap: () => setState(() => _activeSubTab = 2),
                    ),
                  ],
                ),
              ),
            ),

            // Main Deck List / Search Results View
            Expanded(
              child: searchQuery.isNotEmpty
                  ? (searchResultsAsync?.when(
                        data: (results) => MyDecksSearchResultsView(
                          results: results,
                          query: searchQuery,
                          isSelectionMode: isSelectionMode,
                          selectedIds: selectedIds,
                          onToggleSelect: _toggleSelection,
                          onTapDeck: (d) => _handleDeckTap(d, isSelectionMode, selectedIds),
                          onLongPressDeck: _handleDeckLongPress,
                          onShareToExplore: widget.onShareDeckToExplore,
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentCyan,
                          ),
                        ),
                        error: (err, _) => Center(
                          child: Text(
                            'Error searching decks: $err',
                            style: const TextStyle(color: AppColors.accentAmber),
                          ),
                        ),
                      ) ??
                      const SizedBox.shrink())
                  : (filteredDecks.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.style_outlined,
                                  size: 56,
                                  color: AppColors.textMuted.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No decks found',
                                  style: AppTypography.heading2.copyWith(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap "+ New Deck" to create one.',
                                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  key: const Key('decks_empty_wizard_button'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentCyan,
                                    foregroundColor: AppColors.textDark,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('+ New Deck', style: TextStyle(fontWeight: FontWeight.w700)),
                                  onPressed: () => DeckSetupWizardModal.show(
                                    context,
                                    initialTcgDomain: activeFilter,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: const PageStorageKey('my_decks_scroll_key'),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: filteredDecks.length,
                          itemBuilder: (context, index) {
                            final deck = filteredDecks[index];
                            final isSelected = selectedIds.contains(deck.id);

                            return MyDeckCard(
                              deck: deck,
                              isSelectionMode: isSelectionMode,
                              isSelected: isSelected,
                              onSelectedChanged: (_) => _toggleSelection(deck.id),
                              onTap: () => _handleDeckTap(deck, isSelectionMode, selectedIds),
                              onLongPress: () => _handleDeckLongPress(deck),
                              onShareToExplore: widget.onShareDeckToExplore,
                            );
                          },
                        )),
            ),
          ],
        ),

        // Multi-selection floating bottom action footer
        if (isSelectionMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MyDecksSelectionFooter(
              selectedCount: selectedIds.length,
              onShareToExplore: () => _shareSelectedDeck(allSummaries),
              onCancel: _exitSelectionMode,
            ),
          ),
      ],
    );
  }
}

class _SubTabPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubTabPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

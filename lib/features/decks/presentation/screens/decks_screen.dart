import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/core/state/tcg_context_sync.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/my_decks/my_decks_tab_view.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';

/// Root Dual-Tab Decks screen partitioning the experience into "My Decks" and "Explore Decks"
/// with independent scroll and filter preservation, top TabBar, and persistent action buttons.
class DecksScreen extends ConsumerStatefulWidget {
  const DecksScreen({super.key});

  @override
  ConsumerState<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends ConsumerState<DecksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<Map<String, dynamic>> _tcgOptions = [
    {
      'domain': 'all',
      'label': 'All Decks',
      'icon': Icons.all_inbox_rounded,
      'color': AppColors.accentCyan,
    },
    {
      'domain': 'mtg',
      'label': 'Magic: The Gathering',
      'icon': Icons.auto_awesome_rounded,
      'color': AppColors.accentViolet,
    },
    {
      'domain': 'pokemon',
      'label': 'Pokémon',
      'icon': Icons.catching_pokemon_rounded,
      'color': AppColors.accentAmber,
    },
    {
      'domain': 'lorcana',
      'label': 'Disney Lorcana',
      'icon': Icons.auto_stories_rounded,
      'color': AppColors.accentVioletLight,
    },
  ];

  String _getDropdownTitle(String activeFilter) {
    for (final option in _tcgOptions) {
      if (option['domain'] == activeFilter) {
        return option['label'] as String;
      }
    }
    return 'All Decks';
  }

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(decksTopTabProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTab.clamp(0, 1),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (ref.read(decksTopTabProvider) != _tabController.index) {
      ref.read(decksTopTabProvider.notifier).state = _tabController.index;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sharePersonalDeckToExplore(DeckSummary deck) async {
    try {
      final dao = ref.read(exploreDeckDaoProvider);
      await dao.sharePersonalDeckToExplore(
        personalDeckId: deck.id,
        creatorName: '@CurrentUser',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deck "${deck.name}" shared to Explore!'),
            backgroundColor: AppColors.surfaceHighlight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share "${deck.name}": $e'),
            backgroundColor: AppColors.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Synchronize tab controller if provider changes externally
    ref.listen<int>(decksTopTabProvider, (prev, next) {
      if (next != _tabController.index && next >= 0 && next < 2) {
        _tabController.animateTo(next);
      }
    });

    // Continuous synchronization from Vault game context to Decks filter
    ref.listen<String>(activeGameContextProvider, (previous, next) {
      if (previous != next) {
        final targetDomain = TcgContextSync.gameToDomain(next);
        if (ref.read(activeDeckTcgFilterProvider) != targetDomain) {
          ref.read(activeDeckTcgFilterProvider.notifier).state = targetDomain;
        }
      }
    });

    final activeFilter = ref.watch(activeDeckTcgFilterProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Deck Builder',
                      style: AppTypography.heading1,
                    ),
                    const SizedBox(width: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: AppColors.accentCyan.withValues(alpha: 0.12),
                        highlightColor: AppColors.accentCyan.withValues(alpha: 0.06),
                      ),
                      child: PopupMenuButton<String>(
                        key: const Key('decks_tcg_context_switcher'),
                        tooltip: 'Select TCG Domain',
                        initialValue: activeFilter,
                        offset: const Offset(0, 46),
                        color: AppColors.surfaceRaised,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        onSelected: (String selected) {
                          final domain = TcgContextSync.gameToDomain(selected);
                          ref.read(activeDeckTcgFilterProvider.notifier).state = domain;
                          final targetGame = TcgContextSync.domainToGame(domain);
                          if (ref.read(activeGameContextProvider) != targetGame) {
                            ref.read(activeGameContextProvider.notifier).state = targetGame;
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return _tcgOptions.map((item) {
                            final domain = item['domain'] as String;
                            final label = item['label'] as String;
                            final icon = item['icon'] as IconData;
                            final color = item['color'] as Color;
                            final isSelected = activeFilter == domain;

                            return PopupMenuItem<String>(
                              key: Key('tcg_filter_$domain'),
                              value: domain,
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_rounded, color: color, size: 16),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getDropdownTitle(activeFilter),
                                style: AppTypography.heading1.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentCyan,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AppColors.accentCyan,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('decks_privacy_mode_button'),
            icon: Icon(
              isPrivacyMode ? Icons.visibility_off : Icons.visibility,
              color: isPrivacyMode ? AppColors.accentAmber : AppColors.textSecondary,
            ),
            tooltip: isPrivacyMode ? 'Disable Privacy Mode' : 'Enable Privacy Mode',
            onPressed: () {
              ref.read(privacyModeProvider.notifier).state = !isPrivacyMode;
            },
          ),
          IconButton(
            key: const Key('deck_setup_wizard_button'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Deck',
            onPressed: () => DeckSetupWizardModal.show(
              context,
              initialTcgDomain: activeFilter,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.surfaceBorder,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accentCyan,
              indicatorWeight: 3,
              labelColor: AppColors.accentCyan,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(
                  key: Key('decks_top_tab_my_decks'),
                  text: 'My Decks',
                ),
                Tab(
                  key: Key('decks_top_tab_explore'),
                  text: 'Explore Decks',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (_tabController.index == 0 &&
              ref.watch(myDecksSelectedIdsProvider).isEmpty)
          ? FloatingActionButton.extended(
              key: const Key('decks_new_deck_fab'),
              onPressed: () => DeckSetupWizardModal.show(
                context,
                initialTcgDomain: activeFilter,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Deck'),
              backgroundColor: AppColors.accentCyan,
              foregroundColor: AppColors.textDark,
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          MyDecksTabView(
            onShareDeckToExplore: _sharePersonalDeckToExplore,
          ),
          const ExploreDecksTabView(),
        ],
      ),
    );
  }
}

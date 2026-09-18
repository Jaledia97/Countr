import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/presentation/controllers/hydration_state.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/hydration/presentation/widgets/hydration_progress_card.dart';
import 'dart:async';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/mtg_filter_sheet.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

/// Vault Screen (Safe / Collection Inventory).
/// Phase 2 & 3: Infinitely scalable, offline-first local database using Drift
/// with Polymorphic ledger engine, 2-Column Binder Grid, and live financial delta calculations.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  int _selectedFilterIndex = 0;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isFetchingMore = ref.read(vaultIsFetchingMoreProvider);

    if (maxScroll > 0 && currentScroll >= maxScroll - 300 && !isFetchingMore) {
      final currentLimit = ref.read(vaultPaginationLimitProvider);
      final currentItems = ref.read(vaultItemsStreamProvider).valueOrNull ?? [];
      if (currentItems.length >= currentLimit) {
        ref.read(vaultIsFetchingMoreProvider.notifier).state = true;
        ref.read(vaultPaginationLimitProvider.notifier).update((l) => l + 50);
      }
    }
  }

  final List<String> _filters = [
    'Owned',
    'Catalog (Ref)',
    'Graded Slabs',
    'Raw Singles',
    'Comics',
    'High P/L',
  ];

  static const List<Map<String, dynamic>> _collections = [
    {
      'title': 'All Collections',
      'icon': Icons.all_inbox_rounded,
      'color': AppColors.accentCyan,
    },
    {
      'title': 'Magic: The Gathering',
      'icon': Icons.auto_awesome_rounded,
      'color': AppColors.accentViolet,
    },
    {
      'title': 'Pokémon TCG',
      'icon': Icons.catching_pokemon_rounded,
      'color': AppColors.accentAmber,
    },
    {
      'title': 'Comic Books',
      'icon': Icons.menu_book_rounded,
      'color': AppColors.accentEmerald,
    },
    {
      'title': 'Sports Cards',
      'icon': Icons.sports_football_rounded,
      'color': AppColors.accentCyan,
    },
  ];

  String _getVaultTitle(String activeGame) {
    switch (activeGame) {
      case 'Magic: The Gathering':
        return 'MTG Vault';
      case 'Pokémon TCG':
        return 'Pokémon Vault';
      case 'Comic Books':
        return 'Comics Vault';
      case 'Sports Cards':
        return 'Sports Vault';
      case 'All Collections':
      default:
        return 'My Vault';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateBinderDialog(BuildContext context, String activeGame) async {
    final controller = TextEditingController();
    final dao = ref.read(vaultDaoProvider);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          title: Text(
            'New Binder for $activeGame',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a customized binder for storing and organizing cards.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Vintage Foil Collection',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accentCyan),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.textDark,
              ),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop();

                final binder = await dao.createBinder(
                  name: name,
                  collectionType: activeGame,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created Binder "${binder.name}"'),
                      backgroundColor: AppColors.accentEmerald,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Create Binder'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<VaultItem>>>(
      vaultItemsStreamProvider,
      (previous, next) {
        if (!next.isLoading) {
          ref.read(vaultIsFetchingMoreProvider.notifier).state = false;
        }
      },
    );

    final activeGame = ref.watch(activeGameContextProvider);
    final asyncItems = ref.watch(vaultItemsStreamProvider);
    final isFetchingMore = ref.watch(vaultIsFetchingMoreProvider);
    final summary = ref.watch(vaultPortfolioSummaryProvider);
    final hydrationState = ref.watch(hydrationControllerProvider);
    final viewMode = ref.watch(vaultViewModeProvider);
    final cardLayout = ref.watch(cardDisplayLayoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: Theme(
          data: Theme.of(context).copyWith(
            splashColor: AppColors.accentCyan.withValues(alpha: 0.12),
            highlightColor: AppColors.accentCyan.withValues(alpha: 0.06),
          ),
          child: PopupMenuButton<String>(
            tooltip: 'Select Vault Collection',
            initialValue: activeGame,
            offset: const Offset(0, 46),
            color: AppColors.surfaceRaised,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            onSelected: (String selected) {
              ref.read(activeGameContextProvider.notifier).state = selected;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accentEmerald,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Active Game Context: $selected'),
                    ],
                  ),
                ),
              );
            },
            itemBuilder: (BuildContext context) {
              return _collections.map((item) {
                final title = item['title'] as String;
                final icon = item['icon'] as IconData;
                final color = item['color'] as Color;
                final isSelected = activeGame == title;

                return PopupMenuItem<String>(
                  value: title,
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getVaultTitle(activeGame),
                      style: AppTypography.heading1.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.accentCyan,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: AppColors.accentCyan),
            tooltip: 'Hydrate MTG Dictionary',
            onPressed: () {
              ref.read(hydrationControllerProvider.notifier).startHydration();
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Reseed Database',
            onPressed: () async {
              await ref.read(vaultDaoProvider).seedDatabase();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Database verified and seeded.'),
                  ),
                );
              }
            },
          ),
          IconButton(
            key: const Key('vault_appbar_filter_button'),
            icon: Badge(
              isLabelVisible: ref.watch(mtgFilterProvider).isActive,
              label: Text('${ref.watch(mtgFilterProvider).activeCount}'),
              backgroundColor: AppColors.accentCyan,
              textColor: AppColors.textDark,
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'Filter Vault',
            onPressed: () => _openMtgFilterSheet(context),
          ),
        ],
      ),
      floatingActionButton: viewMode == VaultViewMode.binders
          ? FloatingActionButton.extended(
              key: const Key('vault_new_binder_fab'),
              onPressed: () => _showCreateBinderDialog(context, activeGame),
              icon: const Icon(Icons.add),
              label: const Text('New Binder'),
              backgroundColor: AppColors.accentCyan,
              foregroundColor: AppColors.textDark,
            )
          : null,
      body: CustomScrollView(
        key: const PageStorageKey<String>('vault_custom_scroll_view'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MTG Bulk Hydration Engine Live Status
                  if (hydrationState.status != HydrationStatus.idle) ...[
                    const HydrationProgressCard(),
                    const SizedBox(height: 16),
                  ],

                  // Dynamic Portfolio Summary Ledger Card
                  _buildPortfolioSummaryCard(summary),

                  const SizedBox(height: 16),

                  // Animated Full-Width Search & View Controls Bar
                  _buildSearchAndControlsBar(viewMode, cardLayout),

                  // Category Filter Chips (when Singles/All Vault is active)
                  if (viewMode == VaultViewMode.allVault) ...[
                    const SizedBox(height: 12),
                    _buildCategoryFilterChips(),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Content Sliver: Either 2-Column Binder Grid OR All Vault Card List
          if (viewMode == VaultViewMode.binders)
            _buildBindersGridSliver(context, activeGame)
          else
            _buildVaultCardsSliver(asyncItems, activeGame),

          // Bottom subtle loading spinner when fetching more items
          if (isFetchingMore || (asyncItems.isLoading && asyncItems.hasValue))
            const SliverToBoxAdapter(
              key: Key('vault_fetching_more_indicator'),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
              ),
            ),

          // State Freeze Status Callout at the bottom
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accentEmerald.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.ac_unit_rounded,
                        color: AppColors.accentEmerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'State Frozen: Item count (${summary.totalItemCount}) and search query ("${_searchController.text}") persist when switching between Feed, Vault, and Decks.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndControlsBar(
    VaultViewMode viewMode,
    CardDisplayLayout cardLayout,
  ) {
    final mtgFilter = ref.watch(mtgFilterProvider);
    final filterActive = mtgFilter.isActive;
    final activeCount = mtgFilter.activeCount;
    final isExpanded = _isSearchExpanded || _searchController.text.isNotEmpty;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState: isExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: SizedBox(
        height: 40,
        child: Row(
          children: [
            // View Toggle: [ Singles ] | [ Binders ] & Layout Switcher
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggle(viewMode),
                    if (viewMode == VaultViewMode.allVault) ...[
                      const SizedBox(width: 8),
                      _buildLayoutSwitcher(cardLayout),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Collapsed Search Trigger Icon
            IconButton(
              key: const Key('vault_search_expand_button'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.search, color: AppColors.accentCyan),
              tooltip: 'Search Vault',
              onPressed: () {
                setState(() {
                  _isSearchExpanded = true;
                });
              },
            ),
            const SizedBox(width: 4),

            // MTG Filter Sheet Trigger Button with Active Count Badge
            IconButton(
              key: const Key('vault_mtg_filter_button'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Badge(
                isLabelVisible: filterActive,
                label: Text('$activeCount'),
                backgroundColor: AppColors.accentCyan,
                textColor: AppColors.textDark,
                child: Icon(
                  Icons.tune_rounded,
                  color: filterActive ? AppColors.accentCyan : AppColors.textSecondary,
                ),
              ),
              tooltip: 'Filter Cards',
              onPressed: () => _openMtgFilterSheet(context),
            ),
          ],
        ),
      ),
      secondChild: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            const Icon(Icons.search, color: AppColors.accentCyan, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('vault_search_text_field'),
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search cards, sets, or cert numbers...',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() {});
                  _debounceTimer?.cancel();
                  _debounceTimer =
                      Timer(const Duration(milliseconds: 250), () {
                    ref.read(vaultSearchQueryProvider.notifier).state =
                        val.trim();
                    ref.read(vaultPaginationLimitProvider.notifier).state = 50;
                  });
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                key: const Key('vault_search_clear_button'),
                icon: const Icon(Icons.clear,
                    size: 18, color: AppColors.textMuted),
                tooltip: 'Clear query',
                onPressed: () {
                  _debounceTimer?.cancel();
                  setState(() {
                    _searchController.clear();
                  });
                  ref.read(vaultSearchQueryProvider.notifier).state = '';
                  ref.read(vaultPaginationLimitProvider.notifier).state = 50;
                },
              ),
            IconButton(
              key: const Key('vault_mtg_filter_button_expanded'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Badge(
                isLabelVisible: filterActive,
                label: Text('$activeCount'),
                backgroundColor: AppColors.accentCyan,
                textColor: AppColors.textDark,
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: filterActive ? AppColors.accentCyan : AppColors.textSecondary,
                ),
              ),
              tooltip: 'Filter Cards',
              onPressed: () => _openMtgFilterSheet(context),
            ),
            IconButton(
              key: const Key('vault_search_collapse_button'),
              icon: const Icon(Icons.close,
                  size: 20, color: AppColors.textSecondary),
              tooltip: 'Close search',
              onPressed: () {
                _debounceTimer?.cancel();
                setState(() {
                  _searchController.clear();
                  _isSearchExpanded = false;
                });
                ref.read(vaultSearchQueryProvider.notifier).state = '';
                ref.read(vaultPaginationLimitProvider.notifier).state = 50;
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle(VaultViewMode viewMode) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: const Key('vault_view_singles_toggle'),
            onTap: () => ref
                .read(vaultViewModeProvider.notifier)
                .state = VaultViewMode.allVault,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: viewMode == VaultViewMode.allVault
                    ? AppColors.surfaceRaised
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'Singles',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: viewMode == VaultViewMode.allVault
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: viewMode == VaultViewMode.allVault
                      ? AppColors.accentCyan
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            key: const Key('vault_view_binders_toggle'),
            onTap: () => ref
                .read(vaultViewModeProvider.notifier)
                .state = VaultViewMode.binders,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: viewMode == VaultViewMode.binders
                    ? AppColors.surfaceRaised
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'Binders',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: viewMode == VaultViewMode.binders
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: viewMode == VaultViewMode.binders
                      ? AppColors.accentCyan
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutSwitcher(CardDisplayLayout cardLayout) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'List layout',
            child: Tooltip(
              message: 'List layout',
              child: GestureDetector(
                key: const Key('vault_layout_list_button'),
                onTap: () => ref
                    .read(cardDisplayLayoutProvider.notifier)
                    .state = CardDisplayLayout.list,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardLayout == CardDisplayLayout.list
                        ? AppColors.surfaceRaised
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.view_list_rounded,
                    size: 18,
                    color: cardLayout == CardDisplayLayout.list
                        ? AppColors.accentCyan
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: 'Grid layout',
            child: Tooltip(
              message: 'Grid layout',
              child: GestureDetector(
                key: const Key('vault_layout_grid_button'),
                onTap: () => ref
                    .read(cardDisplayLayoutProvider.notifier)
                    .state = CardDisplayLayout.grid,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardLayout == CardDisplayLayout.grid
                        ? AppColors.surfaceRaised
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 18,
                    color: cardLayout == CardDisplayLayout.grid
                        ? AppColors.accentCyan
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: Key(
                'vault_filter_chip_${_filters[index].toLowerCase().replaceAll(' ', '_')}',
              ),
              selected: isSelected,
              label: Text(_filters[index]),
              onSelected: (selected) {
                setState(() {
                  _selectedFilterIndex = index;
                  if (index == 1) {
                    ref.read(vaultShowCatalogProvider.notifier).state = true;
                  } else {
                    ref.read(vaultShowCatalogProvider.notifier).state = false;
                  }
                });
              },
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.accentCyan
                    : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
              side: BorderSide(
                color: isSelected
                    ? AppColors.accentCyan
                    : AppColors.surfaceBorder,
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 2-Column GridView displaying custom Vault Binders
  Widget _buildBindersGridSliver(BuildContext context, String activeGame) {
    final bindersAsync = ref.watch(bindersStreamProvider);
    final countsAsync = ref.watch(binderItemCountsProvider);
    final counts = countsAsync.valueOrNull ?? const {};

    return bindersAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(
          child: Text('Error loading binders: $err',
              style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
      data: (binders) {
        if (binders.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    const Icon(Icons.folder_open_rounded,
                        size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No Binders in $activeGame',
                      style: AppTypography.heading2,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Organize your cards into custom binders by game, set, or rarity.',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.textDark,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('+ Create First Binder'),
                      onPressed: () => _showCreateBinderDialog(context, activeGame),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            key: const PageStorageKey<String>('vault_binders_sliver_grid'),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final binder = binders[index];
                final cardCount = counts[binder.id] ?? 0;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => BinderDetailScreen.show(context, binder),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.folder_rounded,
                                    color: AppColors.accentCyan,
                                    size: 22,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    binder.collectionType.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.bottomLeft,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        binder.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.style_outlined,
                                              size: 13,
                                              color: cardCount > 0
                                                  ? AppColors.accentEmerald
                                                  : AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$cardCount ${cardCount == 1 ? "Card" : "Cards"}',
                                              style: TextStyle(
                                                color: cardCount > 0
                                                    ? AppColors.accentEmerald
                                                    : AppColors.textMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
              childCount: binders.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVaultCardsSliver(
      AsyncValue<List<VaultItem>> asyncItems, String activeGame) {
    if (asyncItems.hasValue) {
      final items = asyncItems.value!;
      // Apply local search query
      final query = _searchController.text.toLowerCase().trim();
      var filtered = items.where((item) {
        if (query.isEmpty) return true;
        return item.name.toLowerCase().contains(query) ||
            (item.flavorName?.toLowerCase().contains(query) ?? false) ||
            item.setOrSeries.toLowerCase().contains(query) ||
            item.condition.toLowerCase().contains(query) ||
            item.dynamicData.toLowerCase().contains(query);
      }).toList();

      // Apply quick filter chips
      if (_selectedFilterIndex == 2) {
        filtered = filtered.where((i) => i.isGraded).toList();
      } else if (_selectedFilterIndex == 3) {
        filtered = filtered.where((i) => !i.isGraded).toList();
      } else if (_selectedFilterIndex == 4) {
        filtered = filtered
            .where((i) => i.collectionType == 'comic')
            .toList();
      } else if (_selectedFilterIndex == 5) {
        filtered = filtered
            .where((i) => i.currentMarketPrice > i.acquiredPrice)
            .toList();
      }

      if (filtered.isEmpty) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 44,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFilterIndex == 1
                        ? 'No catalog cards found'
                        : 'No owned items in $activeGame',
                    style: AppTypography.heading2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedFilterIndex == 1
                        ? 'Hydrate the MTG dictionary or modify your search filter.'
                        : 'Tap below to seed initial mock ledger records or hydrate catalog.',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCyan,
                          foregroundColor: AppColors.textDark,
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Seed Database'),
                        onPressed: () async {
                          await ref.read(vaultDaoProvider).seedDatabase();
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentViolet,
                          side: const BorderSide(color: AppColors.accentViolet),
                        ),
                        icon: const Icon(Icons.bolt_rounded),
                        label: const Text('Hydrate MTG Catalog'),
                        onPressed: () {
                          ref
                              .read(hydrationControllerProvider.notifier)
                              .startHydration();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final cardLayout = ref.watch(cardDisplayLayoutProvider);

      if (cardLayout == CardDisplayLayout.grid) {
        final screenWidth = MediaQuery.of(context).size.width;
        final columns = _calculateGridColumns(screenWidth);

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            key: const PageStorageKey<String>('vault_cards_sliver_grid'),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.64,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return VaultItemTile(
                  item: filtered[index],
                  onTap: () => _openCardDetail(filtered, index),
                );
              },
              childCount: filtered.length,
            ),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        sliver: SliverList.builder(
          key: const PageStorageKey<String>('vault_cards_sliver_list'),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return VaultItemCard(
              item: filtered[index],
              onTap: () => _openCardDetail(filtered, index),
            );
          },
        ),
      );
    }

    if (asyncItems.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accentCyan),
          ),
        ),
      );
    }

    if (asyncItems.hasError) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentRose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentRose),
            ),
            child: Text(
              'Database Ledger Error: ${asyncItems.error}',
              style: const TextStyle(color: AppColors.accentRose),
            ),
          ),
        ),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  int _calculateGridColumns(double screenWidth) {
    if (screenWidth < 600) return 3;
    if (screenWidth < 900) return 4;
    if (screenWidth < 1200) return 5;
    return 6;
  }

  /// Smoothly scrolls the Vault grid or list so that [index] is centered
  /// in the viewport when swiping cards in CardDetailSheet or FullScreenCardViewer.
  void _scrollToCardIndex(int index, int totalCount) {
    if (!_scrollController.hasClients) return;
    if (index < 0 || index >= totalCount) return;

    final cardLayout = ref.read(cardDisplayLayoutProvider);
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenWidth = mediaQuery?.size.width ?? 390.0;
    final screenHeight = mediaQuery?.size.height ?? 844.0;

    // Header offset comprises top padding (16) + portfolio summary card (~140) +
    // search & controls bar (~52) + category filter chips (~48) + vertical gaps (48)
    const double headerOffset = 288.0;

    double targetOffset;
    if (cardLayout == CardDisplayLayout.grid) {
      final columns = _calculateGridColumns(screenWidth);
      final totalSpacing = (columns - 1) * 10.0;
      final gridWidth = screenWidth - 32.0; // 16px horizontal margins
      final itemWidth = (gridWidth - totalSpacing) / columns;
      final itemHeight = itemWidth / 0.64; // childAspectRatio: 0.64
      final rowHeight = itemHeight + 10.0; // mainAxisSpacing: 10.0
      final rowIndex = index ~/ columns;
      targetOffset = rowIndex == 0
          ? 0.0
          : headerOffset + (rowIndex * rowHeight) - (screenHeight / 3.5);
    } else {
      // List layout: item height (~124px) + margin bottom (12px) = ~136px
      const double listItemHeight = 136.0;
      targetOffset = index == 0
          ? 0.0
          : headerOffset + (index * listItemHeight) - (screenHeight / 3.5);
    }

    final maxScroll = _scrollController.position.hasContentDimensions
        ? _scrollController.position.maxScrollExtent
        : double.infinity;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// Opens the [CardDetailSheet] seeded with the current filtered list and active index,
  /// binding swiping gestures directly to programmatic background scrolling.
  void _openCardDetail(List<VaultItem> items, int index) {
    CardDetailSheet.show(
      context,
      items[index],
      items: items,
      initialIndex: index,
      onPageChanged: (newIndex) => _scrollToCardIndex(newIndex, items.length),
    );
  }

  void _openMtgFilterSheet(BuildContext context) {
    final currentFilter = ref.read(mtgFilterProvider);
    final allItems = ref.read(vaultItemsStreamProvider).valueOrNull ?? [];
    MtgFilterSheet.show(
      context,
      initialState: currentFilter,
      items: allItems,
      onApply: (newState) {
        ref.read(mtgFilterProvider.notifier).setFilter(newState);
      },
      onReset: () {
        ref.read(mtgFilterProvider.notifier).reset();
      },
    );
  }

  Widget _buildPortfolioSummaryCard(VaultPortfolioSummary summary) {
    final isProfit = summary.isProfitable;
    final pLColor = isProfit ? AppColors.accentEmerald : AppColors.accentRose;
    final pctSign = isProfit ? '+' : '';
    final deltaSign = isProfit ? '+' : '-';
    final totalCount = summary.totalItemCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F2633),
            Color(0xFF141923),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'ESTIMATED VAULT VALUE',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pLColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: pLColor.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: pLColor,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pctSign${summary.profitLossPercentage.toStringAsFixed(1)}% ($deltaSign\$${summary.totalProfitLoss.abs().toStringAsFixed(2)})',
                          style: TextStyle(
                            color: pLColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\$${summary.totalMarketValue.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Total Tracked Items: $totalCount',
                    style: AppTypography.bodySecondary,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                key: const Key('vault_add_item_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.textDark,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                onPressed: () {
                  ManualAddBottomSheet.show(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

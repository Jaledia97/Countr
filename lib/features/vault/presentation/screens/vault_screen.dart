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
import 'package:countr/features/vault/presentation/widgets/vault_import_bottom_sheet.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/mtg_filter_sheet.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

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
  Timer? _loadingTimeoutTimer;
  bool _isLoadingTimedOut = false;
  int _selectedFilterIndex = 0;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startLoadingTimeoutTimer();
  }

  void _startLoadingTimeoutTimer() {
    _loadingTimeoutTimer?.cancel();
    final current = ref.read(vaultItemsStreamProvider);
    if (current.hasValue) {
      _isLoadingTimedOut = false;
      return;
    }
    _loadingTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isLoadingTimedOut = true;
        });
      }
    });
  }

  void _resetLoadingTimeoutTimer() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
    if (_isLoadingTimedOut && mounted) {
      setState(() {
        _isLoadingTimedOut = false;
      });
    } else {
      _isLoadingTimedOut = false;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isFetchingMore = ref.read(vaultIsFetchingMoreProvider);

    if (maxScroll > 0 && currentScroll >= maxScroll - 300 && !isFetchingMore) {
      final currentLimit = ref.read(vaultPaginationLimitProvider);
      final currentItems = ref.read(vaultItemsStreamProvider).valueOrNull ?? [];
      final mtgFilter = ref.read(mtgFilterProvider);
      final searchQuery = ref.read(vaultSearchQueryProvider);
      final isFiltered = mtgFilter.isActive || searchQuery.trim().isNotEmpty;
      final shouldFetchMore = isFiltered
          ? currentItems.isNotEmpty
          : currentItems.length >= (currentLimit * 0.7).floor();

      if (shouldFetchMore) {
        ref.read(vaultIsFetchingMoreProvider.notifier).state = true;
        ref.read(vaultPaginationLimitProvider.notifier).update((l) => l + 50);
      }
    }
  }

  static const List<String> _polymorphicFilters = [
    'Owned',
    'All Cards',
    'Graded Slabs',
    'Raw Singles',
    'Comics',
    'Sports Cards',
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
      'title': 'Disney Lorcana',
      'icon': Icons.auto_stories_rounded,
      'color': AppColors.accentVioletLight,
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
      case 'Disney Lorcana':
        return 'Lorcana Vault';
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
    _loadingTimeoutTimer?.cancel();
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
        if (next.hasValue || next.hasError) {
          _resetLoadingTimeoutTimer();
        } else if (next.isLoading && !next.hasValue && _loadingTimeoutTimer == null && !_isLoadingTimedOut) {
          _startLoadingTimeoutTimer();
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
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);

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
              if (selected.toLowerCase().contains('magic') ||
                  selected.toLowerCase() == 'mtg') {
                ref
                    .read(mtgAutoHydrationCoordinatorProvider)
                    .checkAndTriggerAutoHydration();
              }
              setState(() {
                _selectedFilterIndex = ref.read(vaultShowCatalogProvider) ? 1 : 0;
                _isLoadingTimedOut = false;
              });
              _startLoadingTimeoutTimer();
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
        actions: const [],
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
        cacheExtent: 500,
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
                  _buildPortfolioSummaryCard(
                    summary,
                    allVaultCards: asyncItems.asData?.value ?? const [],
                    isPrivacyMode: isPrivacyMode,
                    currency: baseCurrency,
                  ),

                  const SizedBox(height: 16),

                  // Animated Full-Width Search & View Controls Bar
                  _buildSearchAndControlsBar(viewMode),

                  // Category Filter Chips with persistent left-anchored layout switcher (when Singles/All Vault is active)
                  if (viewMode == VaultViewMode.allVault) ...[
                    const SizedBox(height: 12),
                    _buildCategoryFilterChips(cardLayout),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Content Sliver: Either 2-Column Binder Grid OR Collections View OR All Vault Card List
          if (viewMode == VaultViewMode.binders)
            _buildBindersGridSliver(context, activeGame)
          else if (viewMode == VaultViewMode.collections)
            _buildCollectionsViewSliver(context, activeGame)
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
  ) {
    final mtgFilter = ref.watch(mtgFilterProvider);
    final filterActive = mtgFilter.isActive;
    final activeCount = mtgFilter.activeCount;
    final isExpanded = _isSearchExpanded || _searchController.text.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: SizedBox(
              height: 40,
              child: Row(
                children: [
                  // Primary View Switcher: [ Singles | Binders | Collections ]
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _buildViewToggle(viewMode),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Collapsed Search Trigger Icon
                  IconButton(
                    key: const Key('vault_search_expand_button'),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.search, color: AppColors.accentCyan),
                    tooltip: 'Search Vault',
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = true;
                      });
                    },
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
                  IconButton(
                    key: _searchController.text.isNotEmpty
                        ? const Key('vault_search_clear_button')
                        : const Key('vault_search_collapse_button'),
                    icon: const Icon(Icons.close,
                        size: 20, color: AppColors.textSecondary),
                    tooltip: _searchController.text.isNotEmpty
                        ? 'Clear query'
                        : 'Close search',
                    onPressed: () {
                      _debounceTimer?.cancel();
                      if (_searchController.text.isNotEmpty) {
                        setState(() {
                          _searchController.clear();
                        });
                        ref.read(vaultSearchQueryProvider.notifier).state = '';
                        ref.read(vaultPaginationLimitProvider.notifier).state = 50;
                      } else {
                        setState(() {
                          _searchController.clear();
                          _isSearchExpanded = false;
                        });
                        ref.read(vaultSearchQueryProvider.notifier).state = '';
                        ref.read(vaultPaginationLimitProvider.notifier).state = 50;
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // MTG Filter Sheet Trigger Button with Active Count Badge (permanently pinned to right)
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
          Semantics(
            button: true,
            selected: viewMode == VaultViewMode.allVault,
            label: 'Singles',
            child: GestureDetector(
              key: const Key('vault_view_singles_toggle'),
              behavior: HitTestBehavior.opaque,
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
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            selected: viewMode == VaultViewMode.binders,
            label: 'Binders',
            child: GestureDetector(
              key: const Key('vault_view_binders_toggle'),
              behavior: HitTestBehavior.opaque,
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
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            selected: viewMode == VaultViewMode.collections,
            label: 'Collections',
            child: GestureDetector(
              key: const Key('vault_view_collections_toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: () => ref
                  .read(vaultViewModeProvider.notifier)
                  .state = VaultViewMode.collections,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: viewMode == VaultViewMode.collections
                      ? AppColors.surfaceRaised
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Collections',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: viewMode == VaultViewMode.collections
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: viewMode == VaultViewMode.collections
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
            selected: cardLayout == CardDisplayLayout.list,
            label: 'List layout',
            child: Tooltip(
              message: 'List layout',
              child: GestureDetector(
                key: const Key('vault_layout_list_button'),
                behavior: HitTestBehavior.opaque,
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
            selected: cardLayout == CardDisplayLayout.grid,
            label: 'Grid layout',
            child: Tooltip(
              message: 'Grid layout',
              child: GestureDetector(
                key: const Key('vault_layout_grid_button'),
                behavior: HitTestBehavior.opaque,
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

  Widget _buildCategoryFilterChips(CardDisplayLayout cardLayout) {
    final activeGame = ref.watch(activeGameContextProvider);
    final isMtg = activeGame.toLowerCase().contains('magic') || activeGame.toLowerCase() == 'mtg';
    final showCatalog = ref.watch(vaultShowCatalogProvider);

    return Row(
      children: [
        _buildLayoutSwitcher(cardLayout),
        const SizedBox(width: 8),
        Expanded(
          child: isMtg
              ? _buildMtgCategoryFilterChips(showCatalog)
              : _buildPolymorphicCategoryFilterChips(showCatalog),
        ),
      ],
    );
  }

  Widget _buildPolymorphicCategoryFilterChips(bool showCatalog) {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('vault_polymorphic_filter_chips_scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_polymorphicFilters.length, (index) {
          final filterName = _polymorphicFilters[index];
          final isSelected = (index == 0 && !showCatalog && _selectedFilterIndex == 0) ||
              (index == 1 && showCatalog && _selectedFilterIndex == 1) ||
              (index >= 2 && _selectedFilterIndex == index);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: Key(
                index == 1
                    ? 'vault_filter_chip_catalog_(ref)'
                    : 'vault_filter_chip_${filterName.toLowerCase().replaceAll(' ', '_')}',
              ),
              selected: isSelected,
              label: Text(filterName),
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

  Widget _buildMtgCategoryFilterChips(bool showCatalog) {
    final mtgFilter = ref.watch(mtgFilterProvider);

    return SingleChildScrollView(
      key: const PageStorageKey<String>('vault_mtg_filter_chips_scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 1. Owned Chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: const Key('vault_filter_chip_owned'),
              selected: !showCatalog,
              label: const Text('Owned'),
              onSelected: (_) {
                setState(() {
                  _selectedFilterIndex = 0;
                  ref.read(vaultShowCatalogProvider.notifier).state = false;
                });
              },
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: !showCatalog ? AppColors.accentCyan : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
              side: BorderSide(
                color: !showCatalog ? AppColors.accentCyan : AppColors.surfaceBorder,
              ),
            ),
          ),

          // 2. All Cards Chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: const Key('vault_filter_chip_catalog_(ref)'),
              selected: showCatalog,
              label: const Text('All Cards'),
              onSelected: (_) {
                setState(() {
                  _selectedFilterIndex = 1;
                  ref.read(vaultShowCatalogProvider.notifier).state = true;
                });
                ref
                    .read(mtgAutoHydrationCoordinatorProvider)
                    .checkAndTriggerAutoHydration();
              },
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: showCatalog ? AppColors.accentCyan : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
              side: BorderSide(
                color: showCatalog ? AppColors.accentCyan : AppColors.surfaceBorder,
              ),
            ),
          ),

          // 3. Colors Dropdown Pill
          _buildMtgPill(
            key: const Key('vault_filter_chip_colors'),
            label: mtgFilter.colors.isEmpty
                ? 'Colors ▾'
                : 'Colors (${mtgFilter.colors.join()})',
            isActive: mtgFilter.colors.isNotEmpty,
            onTap: () => _showColorsFilterModal(context),
            onClear: () => ref.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {})),
          ),

          // 4. Mana Value Dropdown Pill
          _buildMtgPill(
            key: const Key('vault_filter_chip_mana_value'),
            label: (mtgFilter.cmcRange.start == 0 && mtgFilter.cmcRange.end >= 16)
                ? 'Mana Value ▾'
                : 'CMC ${mtgFilter.cmcRange.start.toInt()}-${mtgFilter.cmcRange.end.toInt() >= 16 ? '16+' : mtgFilter.cmcRange.end.toInt()}',
            isActive: mtgFilter.cmcRange.start > 0 || mtgFilter.cmcRange.end < 16,
            onTap: () => _showManaValueFilterModal(context),
            onClear: () => ref.read(mtgFilterProvider.notifier).setCmcRange(const RangeValues(0, 16)),
          ),

          // 5. Card Types Dropdown Pill
          _buildMtgPill(
            key: const Key('vault_filter_chip_card_types'),
            label: mtgFilter.typeLine.trim().isEmpty
                ? 'Card Types ▾'
                : 'Type: ${mtgFilter.typeLine}',
            isActive: mtgFilter.typeLine.trim().isNotEmpty,
            onTap: () => _showCardTypesFilterModal(context),
            onClear: () => ref.read(mtgFilterProvider.notifier).setTypeLine(''),
          ),

          // 6. Formats Dropdown Pill
          _buildMtgPill(
            key: const Key('vault_filter_chip_formats'),
            label: mtgFilter.formats.isEmpty
                ? 'Formats ▾'
                : 'Format: ${mtgFilter.formats.first}',
            isActive: mtgFilter.formats.isNotEmpty,
            onTap: () => _showFormatsFilterModal(context),
            onClear: () => ref.read(mtgFilterProvider.notifier).setFormats(const {}),
          ),

          // 7. Rarity Dropdown Pill
          _buildMtgPill(
            key: const Key('vault_filter_chip_rarity'),
            label: mtgFilter.rarities.isEmpty
                ? 'Rarity ▾'
                : 'Rarity (${mtgFilter.rarities.length})',
            isActive: mtgFilter.rarities.isNotEmpty,
            onTap: () => _showRarityFilterModal(context),
            onClear: () => ref.read(mtgFilterProvider.notifier).update((s) => s.copyWith(rarities: const {})),
          ),

          // 8. Sets Dropdown Pill
          _buildMtgPill(
            key: const Key('vault_filter_chip_sets'),
            label: mtgFilter.setCode.trim().isEmpty
                ? 'Sets ▾'
                : 'Set: ${mtgFilter.setCode.toUpperCase()}',
            isActive: mtgFilter.setCode.trim().isNotEmpty,
            onTap: () => _showSetsFilterModal(context),
            onClear: () => ref.read(mtgFilterProvider.notifier).setSetCode(''),
          ),

          // 9. Foils Dropdown Pill
          _buildMtgPill(
            key: const Key('vault_filter_chip_foils'),
            label: mtgFilter.finishes.isEmpty
                ? 'Foils ▾'
                : 'Foils (${mtgFilter.finishes.join(', ')})',
            isActive: mtgFilter.finishes.isNotEmpty,
            onTap: () => _showFoilsFilterModal(context),
            onClear: () => ref.read(mtgFilterProvider.notifier).update((s) => s.copyWith(finishes: const {})),
          ),
        ],
      ),
    );
  }

  Widget _buildMtgPill({
    required Key key,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentCyan.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppColors.accentCyan : AppColors.surfaceBorder,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.accentCyan : AppColors.textSecondary,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Sliver displaying set collections with completion progress bars and expandable cards
  Widget _buildCollectionsViewSliver(BuildContext context, String activeGame) {
    return VaultCollectionViewSliver(
      activeGame: activeGame,
      searchQuery: _searchController.text,
    );
  }

  /// 2-Column GridView displaying custom Vault Binders
  Widget _buildBindersGridSliver(BuildContext context, String activeGame) {
    final bindersAsync = ref.watch(bindersStreamProvider);
    final countsAsync = ref.watch(binderItemCountsProvider);
    final counts = countsAsync.valueOrNull ?? const {};

    return bindersAsync.when(
      loading: () {
        if (_isLoadingTimedOut) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 36, color: AppColors.accentAmber),
                  const SizedBox(height: 12),
                  const Text('Loading binders took longer than expected',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry Binders'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.textDark,
                    ),
                    onPressed: () {
                      setState(() => _isLoadingTimedOut = false);
                      _startLoadingTimeoutTimer();
                      ref.invalidate(bindersStreamProvider);
                    },
                  ),
                ],
              ),
            ),
          );
        }
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.accentCyan),
                const SizedBox(height: 16),
                const Text(
                  'Loading binders...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16, color: AppColors.accentCyan),
                  label: const Text('Refresh Data', style: TextStyle(color: AppColors.accentCyan)),
                  onPressed: () => ref.invalidate(bindersStreamProvider),
                ),
              ],
            ),
          ),
        );
      },
      error: (err, stack) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error loading binders: $err',
                    style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () => ref.invalidate(bindersStreamProvider),
                ),
              ],
            ),
          ),
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          key: const Key('vault_view_owned_singles_empty_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: AppColors.textDark,
                          ),
                          icon: const Icon(Icons.style_outlined),
                          label: const Text('View Owned Singles'),
                          onPressed: () {
                            ref.read(vaultViewModeProvider.notifier).state =
                                VaultViewMode.allVault;
                          },
                        ),
                        ElevatedButton.icon(
                          key: const Key('vault_create_first_binder_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceHighlight,
                            foregroundColor: AppColors.textPrimary,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('+ Create First Binder'),
                          onPressed: () => _showCreateBinderDialog(context, activeGame),
                        ),
                      ],
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

      // Apply polymorphic quick filter chips when NOT in MTG
      final isMtg = activeGame.toLowerCase().contains('magic') || activeGame.toLowerCase() == 'mtg';
      if (!isMtg) {
        if (_selectedFilterIndex == 2) {
          filtered = filtered.where((i) => i.isGraded).toList();
        } else if (_selectedFilterIndex == 3) {
          filtered = filtered.where((i) => !i.isGraded).toList();
        } else if (_selectedFilterIndex == 4) {
          filtered = filtered.where((i) => i.collectionType == 'comic').toList();
        } else if (_selectedFilterIndex == 5) {
          filtered = filtered.where((i) => i.collectionType == 'sports_card').toList();
        } else if (_selectedFilterIndex == 6) {
          filtered = filtered.where((i) => i.currentMarketPrice > i.acquiredPrice).toList();
        }
      }

      if (filtered.isEmpty) {
        final isCatalog = ref.watch(vaultShowCatalogProvider) || _selectedFilterIndex == 1;
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
                    isCatalog
                        ? 'No catalog cards found'
                        : 'No owned items in $activeGame',
                    style: AppTypography.heading2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCatalog
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
      final cardKeyCounts = <String, int>{};
      for (final item in filtered) {
        final key = VaultVariantHelper.resolveAbstractCardKey(item);
        cardKeyCounts[key] = (cardKeyCounts[key] ?? 0) + 1;
      }
      final multiVariantKeys = {
        for (final entry in cardKeyCounts.entries)
          if (entry.value > 1) entry.key,
      };

      if (cardLayout == CardDisplayLayout.grid) {
        final screenWidth = MediaQuery.of(context).size.width;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final columns = _calculateGridColumns(screenWidth, textScale);
        final dynamicAspectRatio = _calculateChildAspectRatio(context);

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            key: const PageStorageKey<String>('vault_cards_sliver_grid'),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: dynamicAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = filtered[index];
                final abstractKey = VaultVariantHelper.resolveAbstractCardKey(item);
                final hasMultipleVariants = multiVariantKeys.contains(abstractKey);

                return RepaintBoundary(
                  child: VaultItemTile(
                    item: item,
                    hasMultipleVariants: hasMultipleVariants,
                    onTap: () => _openCardDetail(filtered, index),
                  ),
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
            final item = filtered[index];
            final abstractKey = VaultVariantHelper.resolveAbstractCardKey(item);
            final hasMultipleVariants = multiVariantKeys.contains(abstractKey);

            return RepaintBoundary(
              child: VaultItemCard(
                item: item,
                initiallyExpanded: false,
                hasMultipleVariants: hasMultipleVariants,
                onTap: () => _openCardDetail(filtered, index),
              ),
            );
          },
        ),
      );
    }

    if (asyncItems.isLoading) {
      if (_isLoadingTimedOut) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 40,
                      color: AppColors.accentAmber,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading is taking longer than usual',
                    style: AppTypography.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The database ledger query or isolate initialization is experiencing delays.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.textDark,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _isLoadingTimedOut = false;
                      });
                      _startLoadingTimeoutTimer();
                      ref.invalidate(vaultItemsStreamProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.accentCyan),
                const SizedBox(height: 16),
                const Text(
                  'Loading collection...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16, color: AppColors.accentCyan),
                  label: const Text('Refresh Data', style: TextStyle(color: AppColors.accentCyan)),
                  onPressed: () => ref.invalidate(vaultItemsStreamProvider),
                ),
              ],
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Database Ledger Error: ${asyncItems.error}',
                  style: const TextStyle(color: AppColors.accentRose),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => ref.invalidate(vaultItemsStreamProvider),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  int _calculateGridColumns(double screenWidth, [double textScale = 1.0]) {
    if ((screenWidth < 360 && textScale > 1.1) ||
        (screenWidth < 450 && textScale > 1.6)) {
      return 2;
    }
    if (screenWidth < 600) return 3;
    if (screenWidth < 900) return 4;
    if (screenWidth < 1200) return 5;
    return 6;
  }

  double _calculateChildAspectRatio(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    if (textScale > 1.8) return 0.36;
    if (textScale > 1.3) return 0.44;
    return 0.54;
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
      final textScale = mediaQuery != null
          ? mediaQuery.textScaler.scale(1.0)
          : 1.0;
      final columns = _calculateGridColumns(screenWidth, textScale);
      final totalSpacing = (columns - 1) * 10.0;
      final gridWidth = screenWidth - 32.0; // 16px horizontal margins
      final itemWidth = (gridWidth - totalSpacing) / columns;
      final aspectRatio = _calculateChildAspectRatio(context);
      final itemHeight = itemWidth / aspectRatio;
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

  Future<void> _showQuickFilterModal({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext ctx, StateSetter setModalState) contentBuilder,
    required VoidCallback onClear,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 16,
                right: 16,
                top: 12,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: AppColors.surfaceBorder),
                  left: BorderSide(color: AppColors.surfaceBorder),
                  right: BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              onClear();
                              setModalState(() {});
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: AppColors.accentRose,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: AppColors.accentCyan,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.surfaceBorder),
                  const SizedBox(height: 8),
                  contentBuilder(ctx, setModalState),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showColorsFilterModal(BuildContext context) {
    _showQuickFilterModal(
      context: context,
      title: 'Colors & Identity',
      onClear: () {
        ref.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {}));
      },
      contentBuilder: (ctx, setModalState) {
        final mtgFilter = ref.watch(mtgFilterProvider);
        const manaColors = [
          {'symbol': 'W', 'name': 'White', 'bg': Color(0xFFFFFDE7)},
          {'symbol': 'U', 'name': 'Blue', 'bg': Color(0xFF0E68AB)},
          {'symbol': 'B', 'name': 'Black', 'bg': Color(0xFF211E1D)},
          {'symbol': 'R', 'name': 'Red', 'bg': Color(0xFFD3202A)},
          {'symbol': 'G', 'name': 'Green', 'bg': Color(0xFF00733E)},
          {'symbol': 'C', 'name': 'Colorless', 'bg': Color(0xFF9E9895)},
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: manaColors.map((c) {
                final symbol = c['symbol'] as String;
                final isSelected = mtgFilter.colors.contains(symbol);
                return Tooltip(
                  message: c['name'] as String,
                  child: InkWell(
                    key: Key('quick_filter_color_$symbol'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      ref.read(mtgFilterProvider.notifier).toggleColor(symbol);
                      setModalState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c['bg'] as Color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.accentCyan : Colors.transparent,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.accentCyan.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : [
                                const BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                )
                              ],
                      ),
                      child: Center(
                        child: ManaSymbolIcon(
                          symbolCode: symbol,
                          size: 26,
                          circular: true,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Match Mode', style: AppTypography.caption),
            const SizedBox(height: 6),
            SegmentedButton<ColorMatchMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.surface,
                selectedBackgroundColor: AppColors.accentCyan.withValues(alpha: 0.2),
                selectedForegroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: ColorMatchMode.including, label: Text('Including', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: ColorMatchMode.exactly, label: Text('Exactly', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: ColorMatchMode.atMost, label: Text('At most', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: ColorMatchMode.commander, label: Text('Commander', style: TextStyle(fontSize: 11))),
              ],
              selected: {mtgFilter.colorMatchMode},
              onSelectionChanged: (sel) {
                ref.read(mtgFilterProvider.notifier).setColorMatchMode(sel.first);
                setModalState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  void _showManaValueFilterModal(BuildContext context) {
    _showQuickFilterModal(
      context: context,
      title: 'Mana Value (CMC)',
      onClear: () {
        ref.read(mtgFilterProvider.notifier).setCmcRange(const RangeValues(0, 16));
      },
      contentBuilder: (ctx, setModalState) {
        final mtgFilter = ref.watch(mtgFilterProvider);
        final cmc = mtgFilter.cmcRange;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Range', style: AppTypography.caption),
                Text(
                  '${cmc.start.toInt()} to ${cmc.end.toInt() >= 16 ? '16+' : cmc.end.toInt()}',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            RangeSlider(
              key: const Key('quick_filter_cmc_slider'),
              values: cmc,
              min: 0,
              max: 16,
              divisions: 16,
              activeColor: AppColors.accentCyan,
              inactiveColor: AppColors.surfaceBorder,
              labels: RangeLabels(
                '${cmc.start.toInt()}',
                '${cmc.end.toInt() >= 16 ? '16+' : cmc.end.toInt()}',
              ),
              onChanged: (val) {
                ref.read(mtgFilterProvider.notifier).setCmcRange(val);
                setModalState(() {});
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...List.generate(7, (i) {
                  final isSelected = cmc.start.toInt() == i && cmc.end.toInt() == i;
                  return ChoiceChip(
                    label: Text('$i'),
                    selected: isSelected,
                    onSelected: (sel) {
                      ref.read(mtgFilterProvider.notifier).setCmcRange(
                        sel ? RangeValues(i.toDouble(), i.toDouble()) : const RangeValues(0, 16),
                      );
                      setModalState(() {});
                    },
                    selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                    ),
                  );
                }),
                ChoiceChip(
                  label: const Text('7+'),
                  selected: cmc.start.toInt() >= 7 && cmc.end.toInt() >= 16,
                  onSelected: (sel) {
                    ref.read(mtgFilterProvider.notifier).setCmcRange(
                      sel ? const RangeValues(7, 16) : const RangeValues(0, 16),
                    );
                    setModalState(() {});
                  },
                  selectedColor: AppColors.accentCyan.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (cmc.start.toInt() >= 7 && cmc.end.toInt() >= 16)
                        ? AppColors.accentCyan
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showCardTypesFilterModal(BuildContext context) {
    _showQuickFilterModal(
      context: context,
      title: 'Card Types',
      onClear: () {
        ref.read(mtgFilterProvider.notifier).setTypeLine('');
      },
      contentBuilder: (ctx, setModalState) {
        final mtgFilter = ref.watch(mtgFilterProvider);
        const types = [
          'Creature',
          'Instant',
          'Sorcery',
          'Artifact',
          'Enchantment',
          'Planeswalker',
          'Land',
          'Battle',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: types.map((t) {
                final isSelected = mtgFilter.typeLine.toLowerCase().contains(t.toLowerCase());
                return FilterChip(
                  label: Text(t),
                  selected: isSelected,
                  onSelected: (sel) {
                    ref.read(mtgFilterProvider.notifier).setTypeLine(sel ? t : '');
                    setModalState(() {});
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
                  side: BorderSide(
                    color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  void _showFormatsFilterModal(BuildContext context) {
    _showQuickFilterModal(
      context: context,
      title: 'Format Legality',
      onClear: () {
        ref.read(mtgFilterProvider.notifier).setFormats(const {});
      },
      contentBuilder: (ctx, setModalState) {
        final mtgFilter = ref.watch(mtgFilterProvider);
        const formats = [
          'Commander',
          'Modern',
          'Standard',
          'Pioneer',
          'Legacy',
          'Vintage',
          'Pauper',
          'Oathbreaker',
          'Brawl',
          'Historic',
          'Timeless',
          'Premodern',
        ];

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: formats.map((fmt) {
            final isSelected = mtgFilter.formats.contains(fmt.toLowerCase());
            return FilterChip(
              label: Text(fmt),
              selected: isSelected,
              onSelected: (_) {
                ref.read(mtgFilterProvider.notifier).toggleFormat(fmt.toLowerCase());
                setModalState(() {});
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
              side: BorderSide(
                color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
              ),
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showRarityFilterModal(BuildContext context) {
    _showQuickFilterModal(
      context: context,
      title: 'Card Rarity',
      onClear: () {
        ref.read(mtgFilterProvider.notifier).update((s) => s.copyWith(rarities: const {}));
      },
      contentBuilder: (ctx, setModalState) {
        final mtgFilter = ref.watch(mtgFilterProvider);
        const rarities = [
          'Common',
          'Uncommon',
          'Rare',
          'Mythic',
          'Special Card',
          'Art Card',
          'Bonus',
        ];

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: rarities.map((r) {
            final key = r == 'Special Card'
                ? 'special_card'
                : (r == 'Art Card' ? 'art_card' : r.toLowerCase());
            final isSelected = mtgFilter.rarities.contains(key) ||
                (key == 'special_card' && mtgFilter.rarities.contains('special'));
            return FilterChip(
              label: Text(r),
              selected: isSelected,
              onSelected: (_) {
                ref.read(mtgFilterProvider.notifier).toggleRarity(key);
                setModalState(() {});
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
              side: BorderSide(
                color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
              ),
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showSetsFilterModal(BuildContext context) {
    _showQuickFilterModal(
      context: context,
      title: 'Filter by Set',
      onClear: () {
        ref.read(mtgFilterProvider.notifier).setSetCode('');
      },
      contentBuilder: (ctx, setModalState) {
        final mtgFilter = ref.watch(mtgFilterProvider);
        const popularSets = [
          'MH3', 'OTJ', 'BLB', 'DSK', 'FDN', 'SLD',
          'MKM', 'LCI', 'WOE', 'MH2', 'MH1',
          'LTR', '40K', 'WHO', 'PIP', 'ACR',
          'CMM', '2XM', 'LEB', '3ED', 'USG', 'RAV', 'ISD',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: popularSets.map((s) {
                final isSelected = mtgFilter.setCode.toUpperCase() == s;
                return FilterChip(
                  label: Text(s),
                  selected: isSelected,
                  onSelected: (sel) {
                    ref.read(mtgFilterProvider.notifier).setSetCode(sel ? s : '');
                    setModalState(() {});
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
                  side: BorderSide(
                    color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  void _showFoilsFilterModal(BuildContext context) {
    _showQuickFilterModal(
      context: context,
      title: 'Treatments & Finishes',
      onClear: () {
        ref.read(mtgFilterProvider.notifier).update((s) => s.copyWith(finishes: const {}));
      },
      contentBuilder: (ctx, setModalState) {
        final mtgFilter = ref.watch(mtgFilterProvider);
        const finishes = [
          'Nonfoil',
          'Foil',
          'Etched',
          'Textured',
          'Surge',
          'Galaxy',
          'Step-and-Compleat',
          'Halo',
          'Confetti',
          'Serialized',
        ];

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: finishes.map((f) {
            final key = f.toLowerCase().replaceAll('-', '_');
            final isSelected = mtgFilter.finishes.contains(key) ||
                mtgFilter.finishes.contains(f.toLowerCase());
            return FilterChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (_) {
                ref.read(mtgFilterProvider.notifier).toggleFinish(key);
                setModalState(() {});
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
              side: BorderSide(
                color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
              ),
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPortfolioSummaryCard(
    VaultPortfolioSummary summary, {
    List<VaultItem> allVaultCards = const [],
    bool isPrivacyMode = false,
    AppCurrency currency = AppCurrency.usd,
  }) {
    final isProfit = summary.isProfitable;
    final pLColor = isProfit ? AppColors.accentEmerald : AppColors.accentRose;
    final totalCount = summary.totalItemCount;

    return Container(
      key: const Key('vault_portfolio_summary_card'),
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
              const Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
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
                          VaultPricingHelper.formatReturn(
                            summary.totalProfitLoss,
                            summary.profitLossPercentage,
                            currency: currency,
                            isPrivacyMode: isPrivacyMode,
                            amountFirst: false,
                          ),
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
              VaultPricingHelper.formatAmount(
                summary.totalMarketValue,
                currency: currency,
                isPrivacyMode: isPrivacyMode,
                allowZero: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Tracked Items: $totalCount',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  key: const Key('vault_import_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.textDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Import',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    VaultImportBottomSheet.show(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

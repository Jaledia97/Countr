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
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

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
    'All Vault',
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
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter Vault',
            onPressed: () {},
          ),
        ],
      ),
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

                  const SizedBox(height: 20),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search cards, sets, or cert numbers...',
                      hintStyle: AppTypography.bodySecondary,
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _debounceTimer?.cancel();
                                setState(() {
                                  _searchController.clear();
                                });
                                ref.read(vaultSearchQueryProvider.notifier).state = '';
                                ref.read(vaultPaginationLimitProvider.notifier).state = 50;
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.accentCyan),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
                        ref.read(vaultSearchQueryProvider.notifier).state = val.trim();
                        ref.read(vaultPaginationLimitProvider.notifier).state = 50;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Horizontal Scrolling Filter Row: [ All Vault | Binders Grid ] + [ + New Binder ] + Category Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // View Toggle: [ All Vault ] vs [ Binders Grid ]
                        Container(
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
                                onTap: () => ref
                                    .read(vaultViewModeProvider.notifier)
                                    .state = VaultViewMode.allVault,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: viewMode == VaultViewMode.allVault
                                        ? AppColors.surfaceRaised
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'All Vault',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          viewMode == VaultViewMode.allVault
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
                                onTap: () => ref
                                    .read(vaultViewModeProvider.notifier)
                                    .state = VaultViewMode.binders,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: viewMode == VaultViewMode.binders
                                        ? AppColors.surfaceRaised
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Binders Grid',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          viewMode == VaultViewMode.binders
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
                        ),
                        const SizedBox(width: 8),

                        // Display Layout Switcher: [ List | Tiles ] (When All Vault is active)
                        if (viewMode == VaultViewMode.allVault) ...[
                          Container(
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
                                  key: const Key('vault_layout_list_button'),
                                  onTap: () => ref
                                      .read(cardDisplayLayoutProvider.notifier)
                                      .state = CardDisplayLayout.list,
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: cardLayout == CardDisplayLayout.list
                                          ? AppColors.surfaceRaised
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.view_list_rounded,
                                          size: 16,
                                          color: cardLayout == CardDisplayLayout.list
                                              ? AppColors.accentCyan
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'List',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: cardLayout == CardDisplayLayout.list
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: cardLayout == CardDisplayLayout.list
                                                ? AppColors.accentCyan
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  key: const Key('vault_layout_grid_button'),
                                  onTap: () => ref
                                      .read(cardDisplayLayoutProvider.notifier)
                                      .state = CardDisplayLayout.grid,
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: cardLayout == CardDisplayLayout.grid
                                          ? AppColors.surfaceRaised
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.grid_view_rounded,
                                          size: 16,
                                          color: cardLayout == CardDisplayLayout.grid
                                              ? AppColors.accentCyan
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Tiles',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: cardLayout == CardDisplayLayout.grid
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: cardLayout == CardDisplayLayout.grid
                                                ? AppColors.accentCyan
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // [ + New Binder ] Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.accentCyan.withValues(alpha: 0.15),
                            foregroundColor: AppColors.accentCyan,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                  color: AppColors.accentCyan, width: 1),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'New Binder',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () =>
                              _showCreateBinderDialog(context, activeGame),
                        ),
                        const SizedBox(width: 8),

                        // Category Filter Chips (when All Vault is active)
                        if (viewMode == VaultViewMode.allVault)
                          ...List.generate(_filters.length, (index) {
                            final isSelected = _selectedFilterIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text(_filters[index]),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilterIndex = index;
                                    if (index == 1) {
                                      ref
                                          .read(vaultShowCatalogProvider.notifier)
                                          .state = true;
                                    } else {
                                      ref
                                          .read(vaultShowCatalogProvider.notifier)
                                          .state = false;
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
                                selectedColor:
                                    AppColors.accentCyan.withValues(alpha: 0.15),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.accentCyan
                                      : AppColors.surfaceBorder,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
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
                    child: Column(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            Row(
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
                          ],
                        ),
                      ],
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
            item.setOrSeries.toLowerCase().contains(query) ||
            item.condition.toLowerCase().contains(query);
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
                return VaultItemTile(item: filtered[index]);
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
            return VaultItemCard(item: filtered[index]);
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
    if (screenWidth < 420) return 2;
    if (screenWidth < 600) return 3;
    if (screenWidth < 900) return 4;
    if (screenWidth < 1200) return 5;
    return 6;
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
              const Text(
                'ESTIMATED VAULT VALUE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${summary.totalMarketValue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Total Tracked Items: $totalCount',
                style: AppTypography.bodySecondary,
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

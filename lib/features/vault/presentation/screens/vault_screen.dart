import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

/// Vault Screen (Safe / Collection Inventory).
/// Phase 2: Infinitely scalable, offline-first local database using Drift
/// with a Polymorphic JSON ledger engine and live financial delta calculations.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilterIndex = 0;
  int _manualItemCount = 0; // For local freeze demonstration

  final List<String> _filters = [
    'All Vault',
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGame = ref.watch(activeGameContextProvider);
    final asyncItems = ref.watch(vaultItemsStreamProvider);
    final summary = ref.watch(vaultPortfolioSummaryProvider);

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
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort By Value',
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Portfolio Summary Ledger Card
            _buildPortfolioSummaryCard(summary),

            const SizedBox(height: 20),

            // Interactive Search Field (Maintains state freeze)
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cards, sets, or cert numbers...',
                hintStyle: AppTypography.bodySecondary,
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentCyan),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(_filters[index]),
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilterIndex = index;
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
            ),

            const SizedBox(height: 20),

            // Live Drift Vault Items Stream
            asyncItems.when(
              data: (items) {
                // Apply local search query
                final query = _searchController.text.toLowerCase().trim();
                var filtered = items.where((item) {
                  if (query.isEmpty) return true;
                  return item.name.toLowerCase().contains(query) ||
                      item.setOrSeries.toLowerCase().contains(query) ||
                      item.condition.toLowerCase().contains(query);
                }).toList();

                // Apply quick filter chips
                if (_selectedFilterIndex == 1) {
                  filtered = filtered.where((i) => i.isGraded).toList();
                } else if (_selectedFilterIndex == 2) {
                  filtered = filtered.where((i) => !i.isGraded).toList();
                } else if (_selectedFilterIndex == 3) {
                  filtered = filtered.where((i) => i.collectionType == 'comic').toList();
                } else if (_selectedFilterIndex == 4) {
                  filtered = filtered
                      .where((i) => i.currentMarketPrice > i.acquiredPrice)
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Container(
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
                          'No items found in $activeGame',
                          style: AppTypography.heading2,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap below to seed initial mock ledger records.',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return VaultItemCard(item: filtered[index]);
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                ),
              ),
              error: (err, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentRose),
                ),
                child: Text(
                  'Database Ledger Error: $err',
                  style: const TextStyle(color: AppColors.accentRose),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // State Freeze Status Callout
            Container(
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
                      'State Frozen: Item count (${summary.totalItemCount + _manualItemCount}) and search query ("${_searchController.text}") persist when switching between Feed, Vault, and Decks.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioSummaryCard(VaultPortfolioSummary summary) {
    final isProfit = summary.isProfitable;
    final pLColor = isProfit ? AppColors.accentEmerald : AppColors.accentRose;
    final pctSign = isProfit ? '+' : '';
    final deltaSign = isProfit ? '+' : '-';
    final totalCount = summary.totalItemCount + _manualItemCount;

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
                  setState(() {
                    _manualItemCount++;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

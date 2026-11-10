import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

enum MasterSetFilter { all, owned, missing }

/// Full-screen 3x3 Master Set List screen.
/// Displays all cards in a set in a 3-column grid with live completion progress,
/// in-set search and filter chips, visual grayscale for unowned cards, and deep detail hydration on tap.
class MasterSetScreen extends ConsumerStatefulWidget {
  final VaultSetCollection collection;
  final String activeGame;

  const MasterSetScreen({
    super.key,
    required this.collection,
    required this.activeGame,
  });

  @override
  ConsumerState<MasterSetScreen> createState() => _MasterSetScreenState();
}

class _MasterSetScreenState extends ConsumerState<MasterSetScreen> {
  final TextEditingController _searchController = TextEditingController();
  MasterSetFilter _activeFilter = MasterSetFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _getCollectorNumber(VaultItem card) {
    if (card.dynamicData.isEmpty) return null;
    try {
      final parsed = jsonDecode(card.dynamicData);
      if (parsed is Map) {
        return parsed['collector_number']?.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(vaultDaoProvider);
    final collection = widget.collection;
    final setCode = collection.setCode.isNotEmpty ? collection.setCode : collection.setName;

    return Scaffold(
      key: const Key('master_set_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          key: const Key('master_set_back_button'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collection.setName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (setCode.isNotEmpty)
              Text(
                'Set: $setCode',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      body: StreamBuilder<List<VaultItem>>(
        stream: dao.watchItemsBySet(
          collection.setName,
          setCode: collection.setCode.isNotEmpty ? collection.setCode : null,
          collectionType: widget.activeGame,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading cards: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final allCards = snapshot.data ?? const <VaultItem>[];
          final distinctOwnedCards = allCards.where(_isCardOwned).map((c) => c.name).toSet().length;
          final ownedCount = distinctOwnedCards;
          final masterTotal = collection.totalCount > 0
              ? collection.totalCount
              : (allCards.isNotEmpty ? allCards.map((c) => c.name).toSet().length : 0);
          final totalCount = masterTotal;
          final pct = masterTotal > 0 ? (distinctOwnedCards / masterTotal).clamp(0.0, 1.0) : 0.0;

          // Filter by search query and filter chips
          final filteredCards = allCards.where((c) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesName = c.name.toLowerCase().contains(query);
              final colNum = _getCollectorNumber(c);
              final matchesNumber = colNum?.toLowerCase().contains(query) ?? false;
              if (!matchesName && !matchesNumber) return false;
            }
            switch (_activeFilter) {
              case MasterSetFilter.owned:
                return _isCardOwned(c);
              case MasterSetFilter.missing:
                return !_isCardOwned(c);
              case MasterSetFilter.all:
                return true;
            }
          }).toList();

          return CustomScrollView(
            slivers: [
              // Header Summary Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (collection.sampleImageUrl != null && collection.sampleImageUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CountrCachedImage(
                                    imageUrl: collection.sampleImageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.collections_bookmark_rounded,
                                  color: AppColors.accentCyan,
                                  size: 24,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Text(
                                          '$ownedCount / $totalCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'cards owned',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(1)}% complete',
                                    style: TextStyle(
                                      color: pct >= 1.0 ? AppColors.accentEmerald : AppColors.accentCyan,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor: AppColors.surfaceHighlight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pct >= 1.0 ? AppColors.accentEmerald : AppColors.accentCyan,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search Bar & Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const Key('master_set_search_field'),
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Search by card name or number...',
                                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val.trim();
                                  });
                                },
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All (${allCards.length})', MasterSetFilter.all),
                            const SizedBox(width: 8),
                            _buildFilterChip('Owned ($ownedCount)', MasterSetFilter.owned),
                            const SizedBox(width: 8),
                            _buildFilterChip('Missing (${(totalCount - ownedCount).clamp(0, totalCount)})', MasterSetFilter.missing),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // 3x3 Card Grid
              if (filteredCards.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No cards match your filter criteria',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    key: const Key('master_set_grid'),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final card = filteredCards[index];
                        final isOwned = _isCardOwned(card);
                        return _buildMasterSetCard(card, isOwned);
                      },
                      childCount: filteredCards.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _isCardOwned(VaultItem card) {
    if (card.quantity <= 0) return false;
    if (card.isTraded == true) return false;
    if (card.isWishlisted == true) return false;
    if (card.primaryBinderId?.startsWith('system_looking_for') ?? false) return false;
    return true;
  }

  Widget _buildFilterChip(String label, MasterSetFilter filter) {
    final isSelected = _activeFilter == filter;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _activeFilter = filter;
        });
      },
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
      ),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
      side: BorderSide(
        color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
      ),
    );
  }

  Widget _buildMasterSetCard(VaultItem card, bool isOwned) {
    String imageUrl = card.imageUrl;
    if (imageUrl.isEmpty) {
      try {
        final parsed = jsonDecode(card.dynamicData);
        if (parsed is Map) {
          imageUrl = parsed['image_uri'] as String? ??
              (parsed['image_uris'] is Map ? (parsed['image_uris']['normal'] as String? ?? '') : '');
        }
      } catch (_) {}
    }

    Widget cardImage = Container(
      key: isOwned ? const Key('master_set_owned_card') : null,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOwned
              ? AppColors.surfaceBorder
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? CountrCachedImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
            )
          : Container(
              color: AppColors.surfaceRaised,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(4),
              child: Text(
                card.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );

    if (!isOwned) {
      cardImage = ColorFiltered(
        key: Key('master_set_grayscale_${card.id}'),
        colorFilter: vaultGrayscaleColorFilter,
        child: Opacity(
          key: const Key('unowned_card_dimmed_opacity'),
          opacity: 0.55,
          child: cardImage,
        ),
      );
    }

    final colNum = _getCollectorNumber(card);

    return GestureDetector(
      key: Key('master_set_card_${card.id}'),
      onTap: () {
        CardDetailSheet.show(
          context,
          card,
          cardId: card.id,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          cardImage,
          // Quantity badge or unowned badge
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              key: isOwned ? const Key('master_set_quantity_badge') : null,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isOwned ? AppColors.accentCyan : AppColors.surfaceBorder,
                  width: 0.5,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isOwned ? 'x${card.quantity}' : 'Missing',
                  style: TextStyle(
                    color: isOwned ? AppColors.accentCyan : AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          if (colNum != null && colNum.isNotEmpty)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '#$colNum',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

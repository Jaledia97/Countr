import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';

/// Interactive modal allowing users to customize deck cover image / thumbnail
/// from cards within the deck or by searching the catalog.
class DeckThumbnailPickerModal extends ConsumerStatefulWidget {
  final Deck deck;

  const DeckThumbnailPickerModal({super.key, required this.deck});

  static Future<bool?> show(BuildContext context, {required Deck deck}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeckThumbnailPickerModal(deck: deck),
    );
  }

  @override
  ConsumerState<DeckThumbnailPickerModal> createState() =>
      _DeckThumbnailPickerModalState();
}

class _DeckThumbnailPickerModalState
    extends ConsumerState<DeckThumbnailPickerModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  List<VaultItem> _searchResults = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearching = true);
      try {
        final dao = ref.read(vaultDaoProvider);
        final results = await dao.searchCatalogCards(
          trimmed,
          collectionType: 'mtg',
          groupByOracleId: true,
          limit: 30,
        );
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  Future<void> _selectCover(String vaultItemId, String cardName) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final dao = ref.read(vaultDaoProvider);
      await dao.updateDeckCover(widget.deck.id, vaultItemId);

      ref.invalidate(deckProvider(widget.deck.id));
      ref.invalidate(deckSummariesProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deck cover updated to $cardName'),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update cover: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final dao = ref.read(vaultDaoProvider);
      await dao.updateDeckCover(widget.deck.id, null);

      ref.invalidate(deckProvider(widget.deck.id));
      ref.invalidate(deckSummariesProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deck cover reset to default Commander art'),
            backgroundColor: AppColors.surfaceHighlight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _extractArtCrop(String? dynamicData, String? fallbackUrl) {
    if (dynamicData != null && dynamicData.isNotEmpty) {
      try {
        final decoded = jsonDecode(dynamicData);
        if (decoded is Map<String, dynamic>) {
          if (decoded['image_uris'] is Map && decoded['image_uris']['art_crop'] != null) {
            return decoded['image_uris']['art_crop'] as String?;
          }
          if (decoded['card_faces'] is List && (decoded['card_faces'] as List).isNotEmpty) {
            final face0 = (decoded['card_faces'] as List).first;
            if (face0 is Map && face0['image_uris'] is Map) {
              return face0['image_uris']['art_crop'] as String?;
            }
          }
        }
      } catch (_) {}
    }
    return fallbackUrl;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final deckAsync = ref.watch(deckProvider(widget.deck.id));
    final activeDeck = deckAsync.value ?? widget.deck;

    return Container(
      key: const Key('deck_thumbnail_picker_modal'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined, color: AppColors.accentCyan, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Customize Deck Cover', style: AppTypography.heading2),
                      Text(
                        activeDeck.name,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (activeDeck.coverItemId != null)
                  TextButton.icon(
                    key: const Key('reset_deck_cover_button'),
                    icon: const Icon(Icons.refresh, size: 14, color: AppColors.textMuted),
                    label: const Text('Reset', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    onPressed: _isSaving ? null : _resetToDefault,
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accentCyan,
            labelColor: AppColors.accentCyan,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(key: Key('tab_cards_in_deck'), text: 'Cards in Deck'),
              Tab(key: Key('tab_search_catalog'), text: 'Search Catalog'),
            ],
          ),
          const Divider(height: 1, color: AppColors.surfaceBorderSubtle),

          // Tab Content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCardsInDeckTab(activeDeck),
                _buildSearchCatalogTab(activeDeck),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsInDeckTab(Deck activeDeck) {
    final deckItemsAsync = ref.watch(deckItemsProvider(widget.deck.id));

    return deckItemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No cards in this deck yet.\nSearch the catalog tab to pick cover art.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.72,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final cardId = item is DeckItemWithCard
                ? item.vaultItemId
                : (item['vault_item_id'] ?? item['id'] ?? '').toString();
            final cardName = item is DeckItemWithCard
                ? item.name
                : (item['name'] ?? 'Card').toString();
            final dynamicData = item is DeckItemWithCard
                ? item.dynamicData
                : item['dynamic_data'] as String?;
            final imageUrl = item is DeckItemWithCard
                ? item.imageUrl
                : item['image_url'] as String?;
            final artUrl = _extractArtCrop(dynamicData, imageUrl);
            final isSelected = activeDeck.coverItemId == cardId;

            return _buildCardGridTile(
              cardId: cardId,
              cardName: cardName,
              artUrl: artUrl,
              isSelected: isSelected,
              onTap: () => _selectCover(cardId, cardName),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildSearchCatalogTab(Deck activeDeck) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            key: const Key('deck_thumbnail_catalog_search_input'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search MTG card name...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_isSearching)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _searchController.text.trim().isEmpty
                    ? 'Type a card name to search the MTG catalog.'
                    : 'No catalog cards found.',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final card = _searchResults[index];
                final artUrl = _extractArtCrop(card.dynamicData, card.imageUrl);
                final isSelected = activeDeck.coverItemId == card.id;

                return _buildCardGridTile(
                  cardId: card.id,
                  cardName: card.name,
                  artUrl: artUrl,
                  isSelected: isSelected,
                  onTap: () => _selectCover(card.id, card.name),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCardGridTile({
    required String cardId,
    required String cardName,
    required String? artUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: Key('cover_card_tile_$cardId'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artUrl != null && artUrl.isNotEmpty)
              CountrCachedImage(imageUrl: artUrl, fit: BoxFit.cover)
            else
              Container(color: AppColors.surfaceRaised),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                color: Colors.black87,
                child: Text(
                  cardName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.accentCyan,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

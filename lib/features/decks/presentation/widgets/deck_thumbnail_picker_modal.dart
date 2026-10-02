import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

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
        var results = await dao.searchCatalogCards(
          trimmed,
          collectionType: 'mtg',
          groupByOracleId: true,
          limit: 30,
        );

        if (results.isEmpty) {
          try {
            final scryfall = ref.read(scryfallServiceProvider);
            final onlineCards = await scryfall.searchCards(trimmed);
            if (onlineCards != null && onlineCards.isNotEmpty) {
              final stubs = <VaultItem>[];
              for (final c in onlineCards) {
                final comp = mapScryfallCardToCompanion(c);
                stubs.add(
                  VaultItem(
                    id: comp.id.value,
                    collectionType: comp.collectionType.value,
                    name: comp.name.value,
                    flavorName: comp.flavorName.present ? comp.flavorName.value : null,
                    setOrSeries: comp.setOrSeries.value,
                    imageUrl: comp.imageUrl.value,
                    acquiredPrice: comp.acquiredPrice.value,
                    acquiredDate: comp.acquiredDate.value,
                    quantity: 0,
                    condition: comp.condition.value,
                    isGraded: comp.isGraded.value,
                    isAltered: false,
                    isMisprint: false,
                    isSigned: false,
                    personalNotes: comp.personalNotes.present ? comp.personalNotes.value : null,
                    currentMarketPrice: comp.currentMarketPrice.value,
                    lastPriceUpdate: comp.lastPriceUpdate.value,
                    dynamicData: comp.dynamicData.value,
                    isDeleted: false,
                    updatedAt: null,
                    primaryBinderId: null,
                    binderPage: null,
                    binderSlot: null,
                  ),
                );
              }
              results = stubs;
            }
          } catch (scryfallError) {
            debugPrint('[DeckThumbnailPickerModal] Scryfall online search fallback error: $scryfallError');
          }
        }

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

  Future<void> _selectCover(String vaultItemId, String cardName, {VaultItem? selectedStub}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final dao = ref.read(vaultDaoProvider);

      final existing = await dao.getItemById(vaultItemId);
      if (existing == null && selectedStub != null) {
        await dao.insertItem(
          VaultItemsCompanion(
            id: Value(selectedStub.id),
            collectionType: Value(selectedStub.collectionType),
            name: Value(selectedStub.name),
            flavorName: Value(selectedStub.flavorName),
            setOrSeries: Value(selectedStub.setOrSeries),
            imageUrl: Value(selectedStub.imageUrl),
            acquiredPrice: Value(selectedStub.acquiredPrice),
            acquiredDate: Value(selectedStub.acquiredDate),
            quantity: const Value(0),
            condition: Value(selectedStub.condition),
            isGraded: Value(selectedStub.isGraded),
            personalNotes: Value(selectedStub.personalNotes),
            currentMarketPrice: Value(selectedStub.currentMarketPrice),
            lastPriceUpdate: Value(selectedStub.lastPriceUpdate),
            dynamicData: Value(selectedStub.dynamicData),
            isDeleted: const Value(false),
          ),
        );
      }

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
        final decoded = ParsedJsonCache.parse(dynamicData);
        if (decoded.isNotEmpty) {
          if (decoded['image_uris'] is Map) {
            final uris = decoded['image_uris'] as Map;
            final url = uris['art_crop'] ??
                uris['normal'] ??
                uris['large'] ??
                uris['small'];
            if (url != null && url.toString().isNotEmpty) {
              return url.toString();
            }
          }
          if (decoded['card_faces'] is List) {
            for (final face in (decoded['card_faces'] as List)) {
              if (face is Map && face['image_uris'] is Map) {
                final uris = face['image_uris'] as Map;
                final url = uris['art_crop'] ??
                    uris['normal'] ??
                    uris['large'] ??
                    uris['small'];
                if (url != null && url.toString().isNotEmpty) {
                  return url.toString();
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    return fallbackUrl;
  }

  String? _extractManaCost(String? dynamicData) {
    if (dynamicData == null || dynamicData.isEmpty) return null;
    try {
      final decoded = ParsedJsonCache.parse(dynamicData);
      return decoded['mana_cost'] as String? ?? decoded['mana'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final deckAsync = ref.watch(deckProvider(widget.deck.id));
    final activeDeck = deckAsync.value ?? widget.deck;
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.85,
      child: Container(
        key: const Key('deck_thumbnail_picker_modal'),
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 1)),
        ),
        child: Column(
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
            Expanded(
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
            final manaCost = _extractManaCost(dynamicData);
            final isSelected = activeDeck.coverItemId == cardId;

            return _buildCardGridTile(
              cardId: cardId,
              cardName: cardName,
              artUrl: artUrl,
              manaCost: manaCost,
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
                final manaCost = _extractManaCost(card.dynamicData);
                final isSelected = activeDeck.coverItemId == card.id;

                return _buildCardGridTile(
                  cardId: card.id,
                  cardName: card.name,
                  artUrl: artUrl,
                  manaCost: manaCost,
                  isSelected: isSelected,
                  onTap: () => _selectCover(card.id, card.name, selectedStub: card),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCardPlaceholder(String cardName, {String? manaCost}) {
    String? symbol;
    if (manaCost != null && manaCost.isNotEmpty) {
      final match = RegExp(r'\{([^}]+)\}').firstMatch(manaCost);
      if (match != null) {
        symbol = match.group(0);
      }
    }
    symbol ??= '{C}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceRaised,
            AppColors.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ManaSymbolIcon(symbolCode: symbol, size: 28),
            const SizedBox(height: 8),
            Text(
              cardName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGridTile({
    required String cardId,
    required String cardName,
    required String? artUrl,
    String? manaCost,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final placeholder = _buildCardPlaceholder(cardName, manaCost: manaCost);

    return GestureDetector(
      key: Key('cover_card_tile_$cardId'),
      behavior: HitTestBehavior.opaque,
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
              IgnorePointer(
                child: CountrCachedImage(
                  imageUrl: artUrl,
                  fit: BoxFit.cover,
                  errorWidget: placeholder,
                ),
              )
            else
              placeholder,
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

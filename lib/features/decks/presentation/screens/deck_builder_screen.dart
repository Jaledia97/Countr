import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/decks/domain/legality_enforcer.dart';
import 'package:countr/features/decks/domain/deck_io_parser.dart';
import 'package:countr/features/decks/presentation/screens/deck_metadata_screen.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/decks/presentation/widgets/deck_swap_printing_sheet.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/decks/presentation/widgets/assembly_pick_list_dialog.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';

/// Available tabs in DeckBuilderScreen
enum DeckBuilderTab { details, valuesTab }

/// Presentation view modes in DeckBuilderScreen
enum DeckViewMode { list, grid }

class DeckBuilderScreen extends ConsumerStatefulWidget {
  final Deck deck;

  const DeckBuilderScreen({super.key, required this.deck});

  @override
  ConsumerState<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends ConsumerState<DeckBuilderScreen> {
  final ScrollController _scrollController = ScrollController();
  LegalityResult? _legalityResult;
  int _lastCheckedItemCount = -1;
  DeckBuilderTab _selectedTab = DeckBuilderTab.details;
  DeckViewMode _viewMode = DeckViewMode.list;
  bool _isInlineAnalyticsExpanded = false;


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLegality(List<VaultItem> items) async {
    String format = widget.deck.format.toLowerCase();
    if (format.contains('commander')) {
      format = 'commander';
    } else if (format.contains('modern')) {
      format = 'modern';
    } else if (format.contains('standard')) {
      format = 'standard';
    } else if (format.contains('pauper')) {
      format = 'pauper';
    } else if (format.contains('legacy')) {
      format = 'legacy';
    } else if (format.contains('vintage')) {
      format = 'vintage';
    }

    final result = await LegalityEnforcer.checkLegality(format, items);
    if (mounted) {
      setState(() {
        _legalityResult = result;
      });
    }
  }

  void _scrollToSection(int sectionIndex, List<int> sectionOffsets) {
    if (sectionIndex >= 0 && sectionIndex < sectionOffsets.length) {
      final targetOffset = sectionOffsets[sectionIndex].toDouble();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          min(targetOffset, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  String? _resolveDeckCoverArt(Deck activeDeck, List<dynamic> items, {DeckSummary? summary}) {
    // 1. Custom cover art takes highest priority over default commander art
    if (activeDeck.coverItemId != null) {
      for (final item in items) {
        final id = (item is DeckItemWithCard)
            ? item.vaultItemId
            : (item['vault_item_id'] ?? item['id'] ?? '');
        final cardId = (item is DeckItemWithCard)
            ? item.id
            : (item['id'] ?? item['vault_item_id'] ?? '');
        if (id == activeDeck.coverItemId || cardId == activeDeck.coverItemId) {
          final dyn = (item is DeckItemWithCard) ? item.dynamicData : (item['dynamic_data'] as String?);
          final img = (item is DeckItemWithCard) ? item.imageUrl : (item['image_url'] as String?);
          final res = _extractArtCrop(dyn, img);
          if (res != null && res.isNotEmpty && !res.contains('/back.jpg')) return res;
        }
      }
      final externalItem = ref.watch(vaultItemProvider(activeDeck.coverItemId!)).value;
      if (externalItem != null) {
        final res = _extractArtCrop(externalItem.dynamicData, externalItem.imageUrl);
        if (res != null && res.isNotEmpty && !res.contains('/back.jpg')) return res;
      }
    }
    // 2. Default commander art from summary
    if (summary != null) {
      final url = summary.commanderArtCrop ?? summary.commanderImageUrl;
      if (url != null && url.isNotEmpty && !url.contains('/back.jpg')) return url;
    }
    // 3. Commander card in deck items
    for (final item in items) {
      final zone = (item is DeckItemWithCard)
          ? item.boardZone
          : (item['board_zone'] as String? ?? '');
      if (zone.toLowerCase() == 'commander') {
        final dyn = (item is DeckItemWithCard) ? item.dynamicData : (item['dynamic_data'] as String?);
        final img = (item is DeckItemWithCard) ? item.imageUrl : (item['image_url'] as String?);
        final res = _extractArtCrop(dyn, img);
        if (res != null && res.isNotEmpty && !res.contains('/back.jpg')) return res;
      }
    }
    // 4. First item in deck
    if (items.isNotEmpty) {
      final first = items.first;
      final dyn = (first is DeckItemWithCard) ? first.dynamicData : (first['dynamic_data'] as String?);
      final img = (first is DeckItemWithCard) ? first.imageUrl : (first['image_url'] as String?);
      final res = _extractArtCrop(dyn, img);
      if (res != null && res.isNotEmpty && !res.contains('/back.jpg')) return res;
    }
    // 5. Named Scryfall fallback for commander
    if (summary?.commanderName != null &&
        summary!.commanderName!.isNotEmpty &&
        summary.commanderName != 'Unknown Card') {
      final clean = summary.commanderName!.contains('//')
          ? summary.commanderName!.split('//').first.trim()
          : summary.commanderName!.trim();
      return CountrCachedImage.buildScryfallNamedUrl(clean);
    }
    return null;
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
            if (url != null &&
                url.toString().isNotEmpty &&
                !url.toString().contains('/back.jpg')) {
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
                if (url != null &&
                    url.toString().isNotEmpty &&
                    !url.toString().contains('/back.jpg')) {
                  return url.toString();
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    if (fallbackUrl != null && !fallbackUrl.contains('/back.jpg')) {
      return fallbackUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final deckAsync = ref.watch(deckProvider(widget.deck.id));
    final activeDeck = deckAsync.when(
      data: (d) {
        if (widget.deck.name != d.name && widget.deck.name.isNotEmpty) {
          return d.copyWith(
            name: widget.deck.name,
            wins: widget.deck.wins > 0 ? widget.deck.wins : d.wins,
            losses: widget.deck.losses > 0 ? widget.deck.losses : d.losses,
          );
        }
        return d;
      },
      error: (err, stack) => widget.deck,
      loading: () => widget.deck,
    );
    final summariesAsync = ref.watch(deckSummariesProvider);
    final summaries = summariesAsync.value;
    final deckSummary = summaries?.where((s) => s.id == activeDeck.id).firstOrNull;

    final deckItemsAsync = ref.watch(deckItemsProvider(activeDeck.id));
    final analyticsAsync = ref.watch(deckAnalyticsProvider(activeDeck.id));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop(result);
          return;
        }
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop(result);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: deckItemsAsync.when(
        data: (items) {
          final coverArtUrl = _resolveDeckCoverArt(activeDeck, items, summary: deckSummary);

          // Construct VaultItem list safely without type cast exceptions
          final vaultItems = items.map((i) {
            if (i is DeckItemWithCard) {
              return i.toVaultItem();
            }
            final map = i;
            return VaultItem(
              id: map['id'] as String? ?? 'item-${map.hashCode}',
              name: map['name'] as String? ?? 'Unknown Card',
              setOrSeries: map['set_or_series'] as String? ?? 'MTG',
              imageUrl: map['image_url'] as String? ?? '',
              quantity: (map['vault_quantity'] as num?)?.toInt() ?? (map['quantity'] as num?)?.toInt() ?? 1,
              dynamicData: map['dynamic_data'] as String? ?? '',
              collectionType: map['collection_type'] as String? ?? 'mtg',
              acquiredPrice: (map['acquired_price'] as num?)?.toDouble() ?? 0.0,
              acquiredDate: DateTime.now(),
              lastPriceUpdate: DateTime.now(),
              currentMarketPrice:
                  (map['current_market_price'] as num?)?.toDouble() ?? 0.0,
              isGraded: map['is_graded'] == 1 || map['is_graded'] == true,
              condition: map['condition'] as String? ?? 'NM',
              isAltered: map['is_altered'] == 1 || map['is_altered'] == true,
              isMisprint: map['is_misprint'] == 1 || map['is_misprint'] == true,
              isSigned: map['is_signed'] == 1 || map['is_signed'] == true,
              dateObtained: map['date_obtained'] is DateTime
                  ? map['date_obtained'] as DateTime
                  : null,
              purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
              notes: map['notes'] as String?,
              protectionStatus: map['protection_status'] as String? ?? 'Sleeved',
              isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
              updatedAt: map['updated_at'] is DateTime ? map['updated_at'] as DateTime : null,
            );
          }).toList();

          // Re-trigger legality check whenever items load/change
          if (_lastCheckedItemCount != items.length && items.isNotEmpty) {
            _lastCheckedItemCount = items.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkLegality(vaultItems);
            });
          }

          // In grid mode: partition deck cards into MTG card type categories with fallback to board_zone.
          // In list mode: keep existing board_zone grouping intact.
          final Map<String, List<Map<String, dynamic>>> orderedGrouped = {};
          if (_viewMode == DeckViewMode.grid) {
            final Map<String, List<Map<String, dynamic>>> partitioned = {};
            for (final item in items) {
              final section = _classifyCardType(item);
              partitioned.putIfAbsent(section, () => []).add(item);
            }

            const canonicalSectionOrder = [
              'commander',
              'creatures',
              'planeswalkers',
              'instants',
              'sorceries',
              'artifacts',
              'enchantments',
              'battles',
              'lands',
              'mainboard',
              'sideboard',
              'maybeboard',
              'other',
            ];

            final sortedKeys = partitioned.keys.toList()
              ..sort((a, b) {
                final idxA = canonicalSectionOrder.indexOf(a.toLowerCase());
                final idxB = canonicalSectionOrder.indexOf(b.toLowerCase());
                if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
                if (idxA != -1) return -1;
                if (idxB != -1) return 1;
                return 0;
              });

            for (final k in sortedKeys) {
              orderedGrouped[k] = partitioned[k]!;
            }
          } else {
            for (final item in items) {
              final zone = (item is DeckItemWithCard)
                  ? item.boardZone
                  : (item['board_zone'] as String? ?? 'Mainboard');
              orderedGrouped.putIfAbsent(zone, () => []).add(item);
            }
          }

          // Build sections for scrollbar
          final sectionOffsets = <int>[];
          final sections = <ScrollbarSection>[];
          final int inlineAnalyticsOffset = items.isEmpty
              ? 0
              : (_isInlineAnalyticsExpanded ? 420 : 72) + 32; // card height + anchor bar height
          int currentEstimatedOffset = 180 + inlineAnalyticsOffset;

          int sIdx = 0;
          for (final entry in orderedGrouped.entries) {
            final zoneCards = entry.value;
            final zoneQty = zoneCards.fold<int>(
              0,
              (sum, i) => sum + ((i['deck_quantity'] as num?)?.toInt() ?? 1),
            );

            sectionOffsets.add(currentEstimatedOffset);
            final targetIdx = sIdx;
            sections.add(
              ScrollbarSection(
                label: entry.key,
                count: zoneQty,
                onTap: () => _scrollToSection(targetIdx, sectionOffsets),
              ),
            );

            // Estimate offset:
            // In list mode: 40px for header + 68px per tile
            // In grid mode: 40px for header + ~160px per row of 3
            final sectionContentHeight = _viewMode == DeckViewMode.grid
                ? ((zoneCards.length + 2) ~/ 3 * 160)
                : (zoneCards.length * 68);
            currentEstimatedOffset += 40 + sectionContentHeight;
            sIdx++;
          }

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildSliverAppBar(activeDeck, coverArtUrl, summary: deckSummary, items: items),
                  SliverToBoxAdapter(
                    child: _buildSegmentedTabControl(),
                  ),
                  if (_selectedTab == DeckBuilderTab.details) ...[
                    if (items.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: analyticsAsync.when(
                          data: (analytics) => InlineDeckAnalyticsCard(
                            analytics: analytics,
                            isExpanded: _isInlineAnalyticsExpanded,
                            onToggleExpand: () => setState(() => _isInlineAnalyticsExpanded = !_isInlineAnalyticsExpanded),
                            userNotes: activeDeck.description,
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (error, stack) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    if (items.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No cards in this deck yet.\nTap "Import" or add cards from Vault.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else if (_viewMode == DeckViewMode.grid)
                      for (final entry in orderedGrouped.entries) ...[
                        SliverToBoxAdapter(
                          child: _buildZoneHeader(entry.key, entry.value),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.714,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = entry.value[index];
                                return _buildGridCardCell(
                                  item,
                                  allDeckCards: vaultItems,
                                  activeDeck: activeDeck,
                                );
                              },
                              childCount: entry.value.length,
                            ),
                          ),
                        ),
                      ]
                    else
                      for (final entry in orderedGrouped.entries) ...[
                        SliverToBoxAdapter(
                          child: _buildZoneHeader(entry.key, entry.value),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final item = entry.value[index];
                            return _buildCardTile(item, allDeckCards: vaultItems, activeDeck: activeDeck);
                          }, childCount: entry.value.length),
                        ),
                      ],
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ] else ...[
                    ..._buildDeckValuesSlivers(items, vaultItems),
                  ],
                ],
              ),

              // Pinned Proportional Bubble Scrollbar Overlay (only in Details mode)
              if (_selectedTab == DeckBuilderTab.details && sections.isNotEmpty)
                Positioned(
                  right: 4,
                  top: 100,
                  bottom: 24,
                  child: RepaintBoundary(
                    child: ProportionalBubbleScrollbar(
                      controller: _scrollController,
                      sections: sections,
                      railWidth: 26,
                      railColor: AppColors.surfaceRaised.withValues(alpha: 0.85),
                      bubbleColor: AppColors.accentCyan,
                      onSectionTap: (idx) =>
                          _scrollToSection(idx, sectionOffsets),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => Scaffold(
          appBar: AppBar(title: Text(activeDeck.name)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Scaffold(
          appBar: AppBar(title: Text(activeDeck.name)),
          body: Center(child: Text('Error loading deck: $e')),
        ),
      ),
    ),
    );
  }

  Widget _buildSegmentedTabControl() {
    final isPrivacyActive = ref.watch(privacyModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        key: const Key('deck_builder_segmented_control'),
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('deck_builder_tab_details'),
                onTap: () => setState(() => _selectedTab = DeckBuilderTab.details),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _selectedTab == DeckBuilderTab.details
                        ? AppColors.surfaceHighlight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == DeckBuilderTab.details
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTab == DeckBuilderTab.details
                            ? AppColors.accentCyan
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                key: const Key('deck_builder_tab_values'),
                onTap: () => setState(() => _selectedTab = DeckBuilderTab.valuesTab),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _selectedTab == DeckBuilderTab.valuesTab
                        ? AppColors.surfaceHighlight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Values',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedTab == DeckBuilderTab.valuesTab
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedTab == DeckBuilderTab.valuesTab
                                ? AppColors.accentCyan
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (isPrivacyActive) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDeckValuesSlivers(
    List<dynamic> items,
    List<VaultItem> vaultItems,
  ) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);

    if (isPrivacyMode) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: LockedValuesView(
                key: Key('deck_builder_values_locked_container'),
              ),
            ),
          ),
        ),
      ];
    }

    if (items.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'No cards in this deck to analyze.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ];
    }

    // Compute financial summary
    final summary = ref.watch(deckFinancialSummaryProvider(widget.deck.id));
    final pareto = ref.watch(deckParetoDistributionProvider(widget.deck.id));

    final totalMarket = summary.totalMarketValue;
    final totalCost = summary.totalCostBasis;
    final delta = summary.dollarReturn;
    final pct = summary.percentageReturn;
    final isProfit = summary.isProfit;
    final totalCards = summary.totalCardCount;
    final returnColor = isProfit ? AppColors.accentEmerald : AppColors.accentRose;

    // Group zone values
    final Map<String, double> zoneMarketValues = {};
    final Map<String, double> zoneCostValues = {};
    for (final item in items) {
      final typedItem = item is DeckItemWithCard
          ? item
          : (item is Map<String, dynamic> ? DeckItemWithCard.fromRow(item) : null);
      final qty = typedItem != null
          ? (typedItem.deckQuantity > 0 ? typedItem.deckQuantity : 1)
          : ((item['deck_quantity'] as num?)?.toInt() ?? 1);
      final price = typedItem != null
          ? typedItem.resolveMarketPrice(baseCurrency)
          : ((item['current_market_price'] as num?)?.toDouble() ?? 0.0);
      final cost = typedItem != null
          ? typedItem.effectiveCostBasis
          : ((item['purchase_price'] as num?)?.toDouble() ??
              (item['acquired_price'] as num?)?.toDouble() ??
              0.0);
      final zone = typedItem != null
          ? typedItem.boardZone
          : (item['board_zone'] as String? ?? 'Mainboard');

      zoneMarketValues[zone] = (zoneMarketValues[zone] ?? 0.0) + (price * qty);
      zoneCostValues[zone] = (zoneCostValues[zone] ?? 0.0) + (cost * qty);
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            // 1. Deck Aggregate P&L Summary Card
            Container(
              key: const Key('deck_values_aggregate_card'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2633), Color(0xFF141923)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'AGGREGATE DECK VALUATION',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: returnColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: returnColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  color: returnColor,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  VaultPricingHelper.formatReturn(
                                    delta,
                                    pct,
                                    currency: baseCurrency,
                                    isPrivacyMode: false,
                                    amountFirst: true,
                                  ),
                                  style: TextStyle(
                                    color: returnColor,
                                    fontSize: 11,
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
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      VaultPricingHelper.formatAmount(
                        totalMarket,
                        currency: baseCurrency,
                        isPrivacyMode: false,
                        allowZero: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.surfaceBorderSubtle, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL COST BASIS',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                VaultPricingHelper.formatAmount(
                                  totalCost,
                                  currency: baseCurrency,
                                  isPrivacyMode: false,
                                  allowZero: true,
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'TOTAL CARDS',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalCards (${items.length} unique)',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Pareto Distribution Widget ("Heavy Hitters")
            ParetoDistributionWidget(
              result: pareto,
              currency: baseCurrency,
              isPrivacyMode: false,
            ),

            const SizedBox(height: 18),

            // 3. Deck Zone Breakdown Section
            _buildDeckValuesSectionHeader('Valuation by Zone'),
            const SizedBox(height: 8),
            for (final zoneEntry in zoneMarketValues.entries) ...[
              _buildZoneValueRow(
                zone: zoneEntry.key,
                marketValue: zoneEntry.value,
                costBasis: zoneCostValues[zoneEntry.key] ?? 0.0,
                totalDeckValue: totalMarket,
                currency: baseCurrency,
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 80),
          ]),
        ),
      ),
    ];
  }

  Widget _buildDeckValuesSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildZoneValueRow({
    required String zone,
    required double marketValue,
    required double costBasis,
    required double totalDeckValue,
    required AppCurrency currency,
  }) {
    final double pctOfTotal = totalDeckValue > 0 ? (marketValue / totalDeckValue) * 100 : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cost: ${VaultPricingHelper.formatAmount(costBasis, currency: currency, isPrivacyMode: false, allowZero: true)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                VaultPricingHelper.formatAmount(marketValue, currency: currency, isPrivacyMode: false, allowZero: true),
                style: const TextStyle(
                  color: AppColors.accentAmber,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${pctOfTotal.toStringAsFixed(1)}% of deck',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAssemblyToggle(Deck deck) async {
    final dao = ref.read(vaultDaoProvider);
    if (deck.isRegistered) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.undo_rounded, color: AppColors.accentAmber),
              SizedBox(width: 8),
              Text('Disassemble Deck?'),
            ],
          ),
          content: Text(
            'Disassembling "${deck.name}" will mark it as Draft and return all physical card assignments back to your Vault availability.',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              key: const Key('confirm_disassemble_button'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentAmber),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Disassemble',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await dao.setDeckRegistered(deck.id, false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${deck.name} disassembled (set to Draft).'),
              backgroundColor: AppColors.surfaceHighlight,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      await AssemblyPickListDialog.show(
        context,
        deck,
        onRegistrationChanged: (isRegistered) {
          ref.invalidate(deckProvider(deck.id));
          ref.invalidate(deckSummariesProvider);
        },
      );
    }
  }

  Widget _buildSliverAppBar(
    Deck activeDeck,
    String? coverArtUrl, {
    DeckSummary? summary,
    List<dynamic> items = const [],
  }) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.surface,
      leading: IconButton(
        key: const Key('deck_builder_back_button'),
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
            return;
          }
          final rootNav = Navigator.of(context, rootNavigator: true);
          if (rootNav.canPop()) {
            rootNav.pop();
          }
        },
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final double deltaExtent = (settings != null)
              ? (settings.maxExtent - settings.minExtent)
              : (180.0 - kToolbarHeight);
          final double t = (settings != null && deltaExtent > 0)
              ? (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent).clamp(0.0, 1.0)
              : (deltaExtent > 0
                  ? (1.0 - (constraints.maxHeight - kToolbarHeight) / deltaExtent).clamp(0.0, 1.0)
                  : 0.0);

          final bool hasLeading = (settings?.hasLeading ?? false) ||
              (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
          final double targetLeft = hasLeading ? 56.0 : 16.0;

          final double leftPadding = Tween<double>(begin: 16.0, end: targetLeft).transform(t);
          final double rightPadding = Tween<double>(begin: 16.0, end: 144.0).transform(t);
          final double availableWidth = constraints.maxWidth - leftPadding - rightPadding;
          final double maxTitleWidth = max(60.0, availableWidth);

          return FlexibleSpaceBar(
            expandedTitleScale: 1.15,
            titlePadding: EdgeInsets.only(
              left: leftPadding,
              bottom: 14.0,
              right: rightPadding,
            ),
            title: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTitleWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: max(160.0, maxTitleWidth)),
                      child: Text(
                        activeDeck.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.surfaceBorderSubtle,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'W:${activeDeck.wins} L:${activeDeck.losses}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.accentEmerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      key: const Key('deck_assembly_toggle_button'),
                      onTap: () => _handleAssemblyToggle(activeDeck),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: activeDeck.isRegistered
                              ? AppColors.accentEmerald.withValues(alpha: 0.20)
                              : AppColors.surfaceRaised.withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: activeDeck.isRegistered
                                ? AppColors.accentEmerald.withValues(alpha: 0.70)
                                : AppColors.accentCyan.withValues(alpha: 0.50),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activeDeck.isRegistered
                                  ? Icons.lock_rounded
                                  : Icons.build_circle_outlined,
                              size: 10,
                              color: activeDeck.isRegistered
                                  ? AppColors.accentEmerald
                                  : AppColors.accentCyan,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              activeDeck.isRegistered ? 'Assembled' : 'Draft',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: activeDeck.isRegistered
                                    ? AppColors.accentEmerald
                                    : AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_legalityResult != null &&
                        !_legalityResult!.isLegal) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: _legalityResult!.violations.join('\n'),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            background: _buildCoverArt(
              activeDeck,
              coverArtUrl,
              summary: summary,
              items: items,
            ),
          );
        },
      ),
      actions: [
        Tooltip(
          message: _viewMode == DeckViewMode.list ? 'Switch to Grid View' : 'Switch to List View',
          child: InkResponse(
            key: const Key('deck_builder_view_mode_toggle'),
            onTap: () {
              setState(() {
                _viewMode = _viewMode == DeckViewMode.list
                    ? DeckViewMode.grid
                    : DeckViewMode.list;
              });
            },
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                _viewMode == DeckViewMode.list
                    ? Icons.grid_view_rounded
                    : Icons.view_list_rounded,
              ),
            ),
          ),
        ),
        Tooltip(
          message: 'Fast-Draw 7',
          child: InkResponse(
            onTap: _showFastDraw,
            radius: 24,
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Icon(Icons.style_rounded),
            ),
          ),
        ),
        Tooltip(
          message: 'More Actions',
          child: InkResponse(
            onTap: () => _showQuickActions(activeDeck),
            radius: 24,
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Icon(Icons.more_vert),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverArt(
    Deck activeDeck,
    String? coverArtUrl, {
    DeckSummary? summary,
    List<dynamic> items = const [],
  }) {
    final commanderId = summary?.commanderCardId ??
        items.where((item) {
          final zone = (item is DeckItemWithCard)
              ? item.boardZone
              : (item['board_zone'] as String? ?? '');
          return zone.toLowerCase() == 'commander';
        }).map((item) {
          final vaultId = (item is DeckItemWithCard)
              ? item.vaultItemId
              : (item['vault_item_id'] as String? ?? '');
          if (vaultId.isNotEmpty) return vaultId;
          final id = (item is DeckItemWithCard)
              ? item.id
              : (item['id'] as String? ?? '');
          return id;
        }).firstOrNull;

    final isCommanderCover = activeDeck.coverItemId != null &&
        ((commanderId != null && activeDeck.coverItemId == commanderId) ||
            items.any((item) {
              final zone = (item is DeckItemWithCard)
                  ? item.boardZone
                  : (item['board_zone'] as String? ?? '');
              if (zone.toLowerCase() != 'commander') return false;
              final vaultId = (item is DeckItemWithCard)
                  ? item.vaultItemId
                  : (item['vault_item_id'] as String? ?? '');
              final id = (item is DeckItemWithCard)
                  ? item.id
                  : (item['id'] as String? ?? '');
              return activeDeck.coverItemId == vaultId || activeDeck.coverItemId == id;
            }));

    final hasCustomCover = activeDeck.coverItemId != null && !isCommanderCover;

    final dynamicCoverKey = hasCustomCover
        ? 'deck_cover_${activeDeck.id}_${activeDeck.coverItemId}'
        : 'deck_cover_${activeDeck.id}';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverArtUrl != null && coverArtUrl.isNotEmpty)
          CountrCachedImage(
            key: ValueKey(dynamicCoverKey),
            imageUrl: coverArtUrl,
            cacheKey: dynamicCoverKey,
            cardName: activeDeck.name,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorWidget: Container(
              color: AppColors.surfaceRaised,
              child: const Center(
                child: Icon(Icons.shield_outlined, size: 64, color: Colors.white12),
              ),
            ),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.surfaceRaised, AppColors.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const Center(
              child: Icon(Icons.shield_outlined, size: 64, color: Colors.white12),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 48,
          left: 56,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('deck_thumbnail_picker_button'),
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                DeckThumbnailPickerModal.show(context, deck: activeDeck);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white24,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Cover Art',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoneHeader(String zone, List<Map<String, dynamic>> items) {
    final qty = items.fold<int>(
      0,
      (sum, i) => sum + (i['deck_quantity'] as int? ?? 1),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(top: 8),
      color: AppColors.surfaceRaised.withValues(alpha: 0.6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              zone.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentCyan,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$qty',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.accentCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(
    Map<String, dynamic> item, {
    List<VaultItem>? allDeckCards,
    Deck? activeDeck,
  }) {
    final effectiveDeck = activeDeck ?? widget.deck;
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final isProxy = item['is_proxy'] == 1 || item['is_proxy'] == true;
    final name = item['name'] as String? ?? 'Unknown Card';
    final qty = item['deck_quantity'] as int? ?? (item['quantity'] as int? ?? 1);
    final typedItem = item is DeckItemWithCard
        ? item
        : DeckItemWithCard.fromRow(item);
    final price = typedItem.resolveMarketPrice(baseCurrency);
    final setCode = item['set_or_series'] as String? ?? '';
    final cardId = (item['id'] ?? item['vault_item_id'] ?? '').toString();
    final isArtSeries = _isArtSeriesLayout(item);
    final cardCacheKey = cardId.isNotEmpty
        ? (isArtSeries ? 'card_art_${cardId}_fallback' : 'card_art_$cardId')
        : null;

    final legality = CardLegality.evaluate(item['dynamic_data'], effectiveDeck.format);

    String? manaCost;
    String? typeLine;
    String? oracleText;
    final dynStr = item['dynamic_data'] as String?;
    if (dynStr != null && dynStr.isNotEmpty) {
      final data = ParsedJsonCache.parse(dynStr);
      if (data.isNotEmpty) {
        manaCost = data['mana_cost'] as String?;
        typeLine = data['type_line'] as String?;
        oracleText = data['oracle_text'] as String?;
        if ((oracleText == null || oracleText.isEmpty) &&
            data['card_faces'] is List &&
            (data['card_faces'] as List).isNotEmpty) {
          final faces = data['card_faces'] as List;
          final faceTexts = <String>[];
          for (final f in faces) {
            if (f is Map && f['oracle_text'] != null) {
              faceTexts.add(f['oracle_text'].toString());
            }
          }
          if (faceTexts.isNotEmpty) {
            oracleText = faceTexts.join('\n//\n');
          }
        }
      }
    }

    final tcgDomain = (item['collection_type'] as String?)?.toLowerCase() ??
        effectiveDeck.tcgDomain.toLowerCase();

    final resolvedImageUrl = _resolveCardPlayImageUrl(item, effectiveDeck);

    final subtitleParts = <String>[];
    if (setCode.isNotEmpty) subtitleParts.add(setCode.toUpperCase());
    if (typeLine != null && typeLine.isNotEmpty) subtitleParts.add(typeLine);
    final subtitleText = subtitleParts.join(' • ');

    void openDetail() => _openCardDetail(item, allDeckCards: allDeckCards, activeDeck: effectiveDeck);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isProxy
                ? Colors.redAccent.withValues(alpha: 0.4)
                : AppColors.surfaceBorderSubtle,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            listTileTheme: const ListTileThemeData(
              minVerticalPadding: 0,
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 0,
            ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.only(left: 0, right: 10),
            childrenPadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            minTileHeight: 56,
            leading: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: openDetail,
                  child: Container(
                    width: 40,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceRaised,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (resolvedImageUrl.isNotEmpty || (name.isNotEmpty && name != 'Unknown Card'))
                        ? CountrCachedImage(
                            imageUrl: resolvedImageUrl,
                            cacheKey: cardCacheKey,
                            cardName: name,
                            tcgDomain: tcgDomain,
                            width: 40,
                            height: 56,
                            fit: BoxFit.cover,
                            fallbackVersion: 'normal',
                            errorWidget: _buildTilePlaceholder(name, width: 40, height: 56),
                          )
                        : _buildTilePlaceholder(name, width: 40, height: 56),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'x$qty',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isProxy ? Colors.grey[400] : Colors.white,
                        ),
                      ),
                    ),
                    if (legality.hasWarning) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildLegalityBadge(
                            legality,
                            item['id'] as String?,
                            name,
                            effectiveDeck.format,
                          ),
                        ),
                      ),
                    ],
                    if (manaCost != null && manaCost.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80.0),
                          child: ManaCostBar(
                            manaCost: manaCost,
                            symbolSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (subtitleText.isNotEmpty)
                      Expanded(
                        child: Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          VaultPricingHelper.formatMarketPriceLabel(
                            price,
                            currency: baseCurrency,
                            isPrivacyMode: isPrivacyMode,
                            fallback: '—',
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentEmerald,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(
              Icons.expand_more,
              size: 20,
              color: AppColors.textSecondary,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: AppColors.surfaceBorderSubtle, height: 12),
                    if (oracleText != null && oracleText.trim().isNotEmpty) ...[
                      ManaText(
                        oracleText.trim(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                        symbolSize: 12,
                      ),
                      const SizedBox(height: 10),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildQuickActionBtn(
                            icon: Icons.info_outline,
                            label: 'Full Details',
                            onTap: openDetail,
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionBtn(
                            icon: Icons.tune,
                            label: 'Remove / Adjust',
                            onTap: () => _showQuantityAdjustDialog(item),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionBtn(
                            icon: Icons.swap_horiz,
                            label: 'Switch',
                            onTap: () {
                              DeckSwapPrintingSheet.show(
                                context,
                                deckId: widget.deck.id,
                                deckItem: item,
                                onSwapped: () {
                                  ref.invalidate(deckItemsProvider(widget.deck.id));
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCardCell(
    Map<String, dynamic> item, {
    required List<VaultItem> allDeckCards,
    required Deck activeDeck,
  }) {
    final name = item['name'] as String? ?? 'Unknown Card';
    final qty = item['deck_quantity'] as int? ?? (item['quantity'] as int? ?? 1);
    final cardId = (item['id'] ?? item['vault_item_id'] ?? '').toString();
    final isArtSeries = _isArtSeriesLayout(item);
    final cardCacheKey = cardId.isNotEmpty
        ? (isArtSeries ? 'card_art_${cardId}_fallback' : 'card_art_$cardId')
        : null;
    final resolvedImageUrl = _resolveCardPlayImageUrl(item, activeDeck);
    final isProxy = item['is_proxy'] == 1 || item['is_proxy'] == true;
    final tcgDomain = (item['collection_type'] as String?)?.toLowerCase() ??
        activeDeck.tcgDomain.toLowerCase();

    return GestureDetector(
      key: Key('deck_grid_card_${cardId.isNotEmpty ? cardId : name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openCardDetail(item, allDeckCards: allDeckCards, activeDeck: activeDeck),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isProxy
                ? Colors.redAccent.withValues(alpha: 0.6)
                : AppColors.surfaceBorderSubtle,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: (resolvedImageUrl.isNotEmpty || (name.isNotEmpty && name != 'Unknown Card'))
                  ? CountrCachedImage(
                      imageUrl: resolvedImageUrl,
                      cacheKey: cardCacheKey,
                      cardName: name,
                      tcgDomain: tcgDomain,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(6),
                      fallbackVersion: 'normal',
                      errorWidget: _buildTilePlaceholder(
                        name,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : _buildTilePlaceholder(
                      name,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(6),
                    ),
            ),
            if (qty > 1)
              Positioned(
                top: 4,
                left: 4,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: Text(
                      '${qty}x',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCardDetail(
    Map<String, dynamic> item, {
    List<VaultItem>? allDeckCards,
    required Deck activeDeck,
  }) {
    final id = (item['id'] ?? item['vault_item_id'] ?? 'item-${item.hashCode}').toString();
    final effectiveDeckCards = allDeckCards ?? [];
    final targetIndex = effectiveDeckCards.indexWhere((c) => c.id == id);
    final VaultItem targetItem = targetIndex >= 0
        ? effectiveDeckCards[targetIndex]
        : (item is DeckItemWithCard
            ? item.toVaultItem()
            : VaultItem(
                id: id,
                name: item['name'] as String? ?? 'Unknown Card',
                setOrSeries: item['set_or_series'] as String? ?? 'MTG',
                imageUrl: item['image_url'] as String? ?? '',
                quantity: (item['vault_quantity'] as num?)?.toInt() ?? 1,
                dynamicData: item['dynamic_data'] as String? ?? '',
                collectionType: item['collection_type'] as String? ?? 'mtg',
                acquiredPrice: (item['acquired_price'] as num?)?.toDouble() ?? 0.0,
                acquiredDate: DateTime.now(),
                lastPriceUpdate: DateTime.now(),
                currentMarketPrice: (item['current_market_price'] as num?)?.toDouble() ?? 0.0,
                isGraded: item['is_graded'] == 1 || item['is_graded'] == true,
                condition: item['condition'] as String? ?? 'NM',
                isAltered: item['is_altered'] == 1 || item['is_altered'] == true,
                isMisprint: item['is_misprint'] == 1 || item['is_misprint'] == true,
                isSigned: item['is_signed'] == 1 || item['is_signed'] == true,
                dateObtained: item['date_obtained'] is DateTime
                    ? item['date_obtained'] as DateTime
                    : null,
                purchasePrice: (item['purchase_price'] as num?)?.toDouble(),
                notes: item['notes'] as String?,
                protectionStatus: item['protection_status'] as String? ?? 'Sleeved',
                isDeleted: item['is_deleted'] == 1 || item['is_deleted'] == true,
                updatedAt: item['updated_at'] is DateTime ? item['updated_at'] as DateTime : null,
              ));
    CardDetailSheet.show(
      context,
      targetItem,
      items: effectiveDeckCards.isNotEmpty ? effectiveDeckCards : [targetItem],
      initialIndex: targetIndex >= 0 ? targetIndex : 0,
      boardZone: (item is DeckItemWithCard)
          ? item.boardZone
          : (item['board_zone'] as String? ?? 'Mainboard'),
      deckId: activeDeck.id,
      deck: activeDeck,
    );
  }

  static bool _isArtSeriesLayout(dynamic item) {
    String? rawLayout;
    String? name;
    String? typeLine;
    String? rawImageUrl;
    String? rawArtCropUrl;
    String? setCode;
    String? dynStr;

    if (item is DeckItemWithCard) {
      rawLayout = item['layout'] as String?;
      name = item.name;
      typeLine = item['type_line'] as String?;
      rawImageUrl = item.imageUrl;
      rawArtCropUrl = item['art_crop_url'] as String?;
      setCode = item.setOrSeries;
      dynStr = item.dynamicData;
    } else if (item is Map) {
      rawLayout = item['layout'] as String?;
      name = item['name'] as String?;
      typeLine = item['type_line'] as String?;
      rawImageUrl = item['image_url'] as String?;
      rawArtCropUrl = item['art_crop_url'] as String?;
      setCode = item['set_or_series'] as String? ?? item['set'] as String?;
      dynStr = item['dynamic_data'] as String?;
    }

    if (rawLayout?.toLowerCase() == 'art_series') return true;

    final nameLower = name?.toLowerCase() ?? '';
    if (nameLower.contains('art series') || nameLower.contains('art card')) {
      return true;
    }

    final typeLower = typeLine?.toLowerCase() ?? '';
    if (typeLower.contains('art series') || typeLower.contains('art card')) {
      return true;
    }

    if (rawImageUrl != null && rawImageUrl.contains('art_series')) {
      return true;
    }
    if (rawArtCropUrl != null && rawArtCropUrl.contains('art_series')) {
      return true;
    }

    final setCodeLower = setCode?.toLowerCase() ?? '';
    if (setCodeLower.length >= 4 &&
        setCodeLower.startsWith('a') &&
        RegExp(r'^a[a-z0-9]{3,4}$').hasMatch(setCodeLower)) {
      return true;
    }

    if (dynStr != null && dynStr.isNotEmpty) {
      try {
        final dynData = ParsedJsonCache.parse(dynStr);
        if (dynData.isNotEmpty) {
          if (dynData['layout']?.toString().toLowerCase() == 'art_series') return true;
          final dynType = dynData['type_line']?.toString().toLowerCase() ?? '';
          if (dynType.contains('art series') || dynType.contains('art card')) return true;
          final dynName = dynData['name']?.toString().toLowerCase() ?? '';
          if (dynName.contains('art series') || dynName.contains('art card')) return true;
          final dynSet = dynData['set']?.toString().toLowerCase() ?? '';
          if (dynSet.length >= 4 &&
              dynSet.startsWith('a') &&
              RegExp(r'^a[a-z0-9]{3,4}$').hasMatch(dynSet)) {
            return true;
          }
          if (dynData['image_uris'] is Map) {
            final uris = dynData['image_uris'] as Map;
            for (final u in uris.values) {
              if (u != null && u.toString().contains('art_series')) return true;
            }
          }
        }
      } catch (_) {
        if (dynStr.contains('"layout":"art_series"') ||
            dynStr.contains('"layout": "art_series"') ||
            dynStr.contains('art_series')) {
          return true;
        }
      }
    }
    return false;
  }

  static String _resolveCardPlayImageUrl(Map<String, dynamic> item, Deck activeDeck) {
    final rawImageUrl = item['image_url'] as String? ?? '';
    final dynStr = item['dynamic_data'] as String?;
    final name = item['name'] as String? ?? 'Unknown Card';
    final tcgDomain = (item['collection_type'] as String?)?.toLowerCase() ??
        activeDeck.tcgDomain.toLowerCase();

    // Explicitly filter out non-playable art cards (art_series layout).
    // Playable variants (borderless, showcase, retro frame, extended art) have playable layouts
    // and will not be filtered out.
    final bool isArtSeries = _isArtSeriesLayout(item);

    String resolvedImageUrl = isArtSeries ? '' : rawImageUrl.trim();
    if (!isArtSeries && (resolvedImageUrl.isEmpty || resolvedImageUrl.contains('/back.jpg') || resolvedImageUrl.contains('/art_crop/'))) {
      resolvedImageUrl = '';
      if (dynStr != null && dynStr.isNotEmpty) {
        try {
          final dynData = ParsedJsonCache.parse(dynStr);
          if (dynData['image_uris'] is Map) {
            final uris = dynData['image_uris'] as Map;
            final u = uris['normal'] ?? uris['large'] ?? uris['small'] ?? uris['art_crop'];
            if (u != null && u.toString().isNotEmpty && !u.toString().contains('/back.jpg')) {
              resolvedImageUrl = u.toString();
            }
          }
          if (resolvedImageUrl.isEmpty &&
              dynData['card_faces'] is List &&
              (dynData['card_faces'] as List).isNotEmpty) {
            final faces = dynData['card_faces'] as List;
            for (final f in faces) {
              if (f is Map && f['image_uris'] is Map) {
                final uris = f['image_uris'] as Map;
                final u = uris['normal'] ?? uris['large'] ?? uris['small'] ?? uris['art_crop'];
                if (u != null && u.toString().isNotEmpty && !u.toString().contains('/back.jpg')) {
                  resolvedImageUrl = u.toString();
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }
      if (resolvedImageUrl.isEmpty && rawImageUrl.isNotEmpty && !rawImageUrl.contains('/back.jpg')) {
        resolvedImageUrl = rawImageUrl.trim();
      }
    }

    if (resolvedImageUrl.isEmpty && name.isNotEmpty && name != 'Unknown Card' && tcgDomain == 'mtg') {
      String clean = name.contains('//') ? name.split('//').first.trim() : name.trim();
      clean = clean
          .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
          .trim();
      resolvedImageUrl = CountrCachedImage.buildScryfallNamedUrl(clean, version: 'normal');
    }

    return resolvedImageUrl;
  }

  static String _classifyCardType(dynamic item) {
    // 1. Commander zone takes priority
    final zone = (item is DeckItemWithCard
            ? item.boardZone
            : (item is Map ? (item['board_zone'] as String? ?? '') : ''))
        .trim();
    if (zone.toLowerCase() == 'commander') {
      return 'Commander';
    }
    if (zone.toLowerCase() == 'sideboard') {
      return 'Sideboard';
    }
    if (zone.toLowerCase() == 'maybeboard') {
      return 'Maybeboard';
    }

    // 2. Extract type_line from item or dynamic_data
    String typeLine = '';
    if (item is Map && item['type_line'] != null) {
      typeLine = item['type_line'].toString();
    }
    if (typeLine.isEmpty) {
      final dynStr = item is DeckItemWithCard
          ? item.dynamicData
          : (item is Map ? (item['dynamic_data'] as String?) : null);
      if (dynStr != null && dynStr.isNotEmpty) {
        final decoded = ParsedJsonCache.parse(dynStr);
        if (decoded['type_line'] != null) {
          typeLine = decoded['type_line'].toString();
        } else if (decoded['card_faces'] is List && (decoded['card_faces'] as List).isNotEmpty) {
          final f0 = (decoded['card_faces'] as List).first;
          if (f0 is Map && f0['type_line'] != null) {
            typeLine = f0['type_line'].toString();
          }
        }
      } else if (item is Map && item['dynamic_data'] is Map) {
        final decoded = item['dynamic_data'] as Map;
        if (decoded['type_line'] != null) {
          typeLine = decoded['type_line'].toString();
        } else if (decoded['card_faces'] is List && (decoded['card_faces'] as List).isNotEmpty) {
          final f0 = (decoded['card_faces'] as List).first;
          if (f0 is Map && f0['type_line'] != null) {
            typeLine = f0['type_line'].toString();
          }
        }
      }
    }

    final lowerType = typeLine.toLowerCase();

    // 3. Match MTG card type hierarchy:
    if (lowerType.contains('creature')) return 'Creatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('instant')) return 'Instants';
    if (lowerType.contains('sorcery')) return 'Sorceries';
    if (lowerType.contains('artifact')) return 'Artifacts';
    if (lowerType.contains('enchantment')) return 'Enchantments';
    if (lowerType.contains('battle')) return 'Battles';
    if (lowerType.contains('land')) return 'Lands';

    // Crucial fallback: If a card does not have a type_line or if type is not found,
    // fall back to board_zone (e.g. 'Mainboard', 'Commander', custom zone).
    if (zone.isNotEmpty && zone.toLowerCase() != 'other') {
      return zone[0].toUpperCase() + zone.substring(1);
    }

    return 'Other';
  }

  static Widget _buildTilePlaceholder(
    String name, {
    double? width = 40,
    double? height = 56,
    BorderRadius? borderRadius,
  }) {
    final initials = _getCardInitials(name);
    final effectiveWidth = width ?? 40;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2D37),
            Color(0xFF16181F),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: effectiveWidth < 36 ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              )
            : Icon(
                Icons.style_rounded,
                size: effectiveWidth < 36 ? 15 : 18,
                color: Colors.white24,
              ),
      ),
    );
  }

  static String _getCardInitials(String name) {
    if (name.isEmpty || name == 'Unknown Card') return '';
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildLegalityBadge(
    CardLegality legality,
    String? itemId,
    String cardName,
    String deckFormat,
  ) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String text;

    switch (legality.status) {
      case LegalityStatus.banned:
        bgColor = Colors.red.withValues(alpha: 0.2);
        borderColor = Colors.redAccent;
        textColor = Colors.redAccent;
        icon = Icons.block_rounded;
        text = 'BANNED';
        break;
      case LegalityStatus.restricted:
        bgColor = Colors.amber.withValues(alpha: 0.2);
        borderColor = Colors.amberAccent;
        textColor = Colors.amberAccent;
        icon = Icons.warning_amber_rounded;
        text = 'RESTRICTED';
        break;
      case LegalityStatus.notLegal:
      default:
        bgColor = Colors.deepOrange.withValues(alpha: 0.2);
        borderColor = Colors.deepOrangeAccent;
        textColor = Colors.deepOrangeAccent;
        icon = Icons.cancel_outlined;
        text = 'NOT LEGAL';
        break;
    }

    return Tooltip(
      message: '$cardName is $text in $deckFormat',
      child: DecoratedBox(
        key: Key('card_legality_badge_${itemId ?? 'unknown'}'),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          child: MediaQuery.withNoTextScaling(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: textColor),
                const SizedBox(width: 3),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.surfaceBorderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.accentCyan),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityAdjustDialog(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Card';
    final currentQty = item['deck_quantity'] as int? ?? (item['quantity'] as int? ?? 1);
    final vaultItemId = item['vault_item_id'] as String? ?? item['id'] as String?;
    final boardZone = item['board_zone'] as String? ?? 'Mainboard';
    final isProxy = item['is_proxy'] == 1 || item['is_proxy'] == true;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adjust Quantity: $name',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current count: $currentQty in $boardZone',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove All'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        if (vaultItemId != null) {
                          await ref.read(vaultDaoProvider).removeCardFromDeck(
                                widget.deck.id,
                                vaultItemId,
                                quantity: currentQty,
                                boardZone: boardZone,
                                isProxy: isProxy,
                              );
                          ref.invalidate(deckItemsProvider(widget.deck.id));
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text('-1'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        if (vaultItemId != null) {
                          await ref.read(vaultDaoProvider).removeCardFromDeck(
                                widget.deck.id,
                                vaultItemId,
                                quantity: 1,
                                boardZone: boardZone,
                                isProxy: isProxy,
                              );
                          ref.invalidate(deckItemsProvider(widget.deck.id));
                        }
                      },
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('+1'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        if (vaultItemId != null) {
                          await ref.read(vaultDaoProvider).addCardToDeck(
                                widget.deck.id,
                                vaultItemId,
                                quantity: 1,
                                boardZone: boardZone,
                                isProxy: isProxy,
                              );
                          ref.invalidate(deckItemsProvider(widget.deck.id));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFastDraw() {
    final itemsAsync = ref.read(deckItemsProvider(widget.deck.id));

    itemsAsync.whenData((items) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _FastDrawSheet(items: items),
      );
    });
  }

  void _showQuickActions([Deck? currentDeck]) {
    final activeDeck = currentDeck ?? widget.deck;
    final itemsAsync = ref.read(deckItemsProvider(activeDeck.id));
    final items = itemsAsync.value ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                activeDeck.isRegistered ? Icons.undo_rounded : Icons.build_circle_outlined,
                color: activeDeck.isRegistered ? AppColors.accentAmber : AppColors.accentEmerald,
              ),
              title: Text(activeDeck.isRegistered ? 'Disassemble Deck (Set to Draft)' : 'Assemble Deck'),
              onTap: () {
                Navigator.pop(ctx);
                _handleAssemblyToggle(activeDeck);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accentCyan),
              title: const Text('Change Deck Cover Art'),
              onTap: () {
                Navigator.pop(ctx);
                DeckThumbnailPickerModal.show(context, deck: activeDeck);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: AppColors.accentCyan),
              title: const Text('Deck Details & Notes'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeckMetadataScreen(deck: activeDeck),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.content_paste,
                color: AppColors.accentVioletLight,
              ),
              title: const Text('Import from Clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null && data!.text!.isNotEmpty) {
                  final parsed = DeckIOParser.parseList(data.text!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Parsed ${parsed.length} cards from clipboard!',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Clipboard is empty.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.accentEmerald),
              title: const Text('Export to Clipboard'),
              onTap: () {
                Navigator.pop(ctx);
                final buffer = StringBuffer();
                for (final item in items) {
                  final qty = item['deck_quantity'] as int? ?? 1;
                  final name = item['name'] as String? ?? 'Card';
                  buffer.writeln('$qty $name');
                }
                Clipboard.setData(ClipboardData(text: buffer.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Decklist copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.shopping_cart,
                color: Colors.orangeAccent,
              ),
              title: const Text('Export Missing / Proxy Cards'),
              onTap: () {
                Navigator.pop(ctx);
                final buffer = StringBuffer();
                for (final item in items) {
                  if (item['is_proxy'] == 1) {
                    final qty = item['deck_quantity'] as int? ?? 1;
                    final name = item['name'] as String? ?? 'Unknown Card';
                    buffer.writeln('$qty $name');
                  }
                }
                final missing = buffer.toString().trim();
                Clipboard.setData(ClipboardData(text: missing));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      missing.isEmpty
                          ? 'No proxy or missing cards found!'
                          : 'Missing cards copied to clipboard!',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Fast-Draw Playtester Sheet (In-Place Mulligan & 7-Card Hand)
// =============================================================================

class _FastDrawSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const _FastDrawSheet({required this.items});

  @override
  State<_FastDrawSheet> createState() => _FastDrawSheetState();
}

class _FastDrawSheetState extends State<_FastDrawSheet> {
  List<Map<String, dynamic>> _hand = [];
  late List<Map<String, dynamic>> _pool;

  @override
  void initState() {
    super.initState();
    _buildPool();
    _dealHand();
  }

  void _buildPool() {
    _pool = [];
    for (final item in widget.items) {
      final zone = (item['board_zone'] as String? ?? 'Mainboard').toLowerCase();
      // Fast-draw includes all cards except Sideboard and Maybeboard
      if (zone == 'sideboard' || zone == 'maybeboard') continue;

      final qty = item['deck_quantity'] as int? ?? 1;
      for (int i = 0; i < qty; i++) {
        _pool.add(item);
      }
    }
  }

  void _dealHand() {
    if (_pool.isEmpty) {
      _hand = [];
      return;
    }
    final shuffled = List<Map<String, dynamic>>.from(_pool)..shuffle();
    setState(() {
      _hand = shuffled.take(7).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    int landCount = 0;
    int spellCount = 0;
    double totalCmc = 0;

    for (final card in _hand) {
      final zone = (card['board_zone'] as String? ?? '').toLowerCase();
      String type = '';
      double cmc = 0;
      final dyn = card['dynamic_data'] as String?;
      if (dyn != null && dyn.isNotEmpty) {
        try {
          final data = jsonDecode(dyn) as Map<String, dynamic>;
          type = data['type_line'] as String? ?? '';
          cmc = (data['cmc'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }

      if (zone == 'lands' || type.toLowerCase().contains('land')) {
        landCount++;
      } else {
        spellCount++;
        totalCmc += cmc;
      }
    }

    final avgCmc = spellCount > 0 ? (totalCmc / spellCount) : 0.0;

    return Container(
      height: min(MediaQuery.of(context).size.height * 0.85, 560),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle & title
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Opening 7 Playtester',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Hand Statistics Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _HandStatPill(
                    label: 'Lands',
                    value: '$landCount',
                    color: Colors.amberAccent,
                  ),
                  _HandStatPill(
                    label: 'Spells',
                    value: '$spellCount',
                    color: AppColors.accentCyan,
                  ),
                  _HandStatPill(
                    label: 'Avg CMC',
                    value: avgCmc.toStringAsFixed(1),
                    color: AppColors.accentVioletLight,
                  ),
                ],
              ),
            ),

            // 7 Cards Display
            Expanded(
              child: _hand.isEmpty
                  ? const Center(
                      child: Text(
                        'Not enough cards in deck to draw 7.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _hand.length,
                      itemBuilder: (context, index) {
                        final card = _hand[index];
                        final name = card['name'] as String? ?? 'Unknown Card';
                        final imageUrl = card['image_url'] as String? ?? '';
                        String? manaCost;
                        String? typeLine;
                        final dyn = card['dynamic_data'] as String?;
                        if (dyn != null && dyn.isNotEmpty) {
                          try {
                            final data =
                                jsonDecode(dyn) as Map<String, dynamic>;
                            manaCost = data['mana_cost'] as String?;
                            typeLine = data['type_line'] as String?;
                          } catch (_) {}
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.surfaceBorderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.black26,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: (imageUrl.isNotEmpty || (name.isNotEmpty && name != 'Unknown Card'))
                                    ? CountrCachedImage(
                                        imageUrl: imageUrl,
                                        cacheKey: 'card_art_${card['id'] ?? name}',
                                        cardName: name,
                                        width: 32,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(4),
                                        fallbackVersion: 'normal',
                                        errorWidget: _DeckBuilderScreenState._buildTilePlaceholder(
                                          name,
                                          width: 32,
                                          height: 44,
                                        ),
                                      )
                                    : _DeckBuilderScreenState._buildTilePlaceholder(
                                        name,
                                        width: 32,
                                        height: 44,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (typeLine != null)
                                      Text(
                                        typeLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (manaCost != null && manaCost.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 100),
                                    child: ManaCostBar(
                                      manaCost: manaCost,
                                      symbolSize: 12.0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Mulligan Action Button (in-place reshuffle)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Mulligan (Draw New 7)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _dealHand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HandStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}


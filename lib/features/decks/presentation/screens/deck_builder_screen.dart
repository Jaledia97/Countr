import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/decks/domain/legality_enforcer.dart';
import 'package:countr/features/decks/domain/deck_io_parser.dart';
import 'package:countr/features/decks/presentation/screens/deck_metadata_screen.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Available tabs in DeckBuilderScreen
enum DeckBuilderTab { details, valuesTab }

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

  @override
  Widget build(BuildContext context) {
    final deckItemsAsync = ref.watch(deckItemsProvider(widget.deck.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: deckItemsAsync.when(
        data: (items) {
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
            );
          }).toList();

          // Re-trigger legality check whenever items load/change
          if (_lastCheckedItemCount != items.length && items.isNotEmpty) {
            _lastCheckedItemCount = items.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkLegality(vaultItems);
            });
          }

          // Group items by zone
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final item in items) {
            final zone = (item is DeckItemWithCard)
                ? item.boardZone
                : (item['board_zone'] as String? ?? 'Mainboard');
            grouped.putIfAbsent(zone, () => []).add(item);
          }

          // Build sections for scrollbar
          final sectionOffsets = <int>[];
          final sections = <ScrollbarSection>[];
          int currentEstimatedOffset = 180; // approximate app bar height

          int sIdx = 0;
          for (final entry in grouped.entries) {
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

            // Estimate 40px for zone header + 68px per card tile
            currentEstimatedOffset += 40 + (zoneCards.length * 68);
            sIdx++;
          }

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: _buildSegmentedTabControl(),
                  ),
                  if (_selectedTab == DeckBuilderTab.details) ...[
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
                    else
                      for (final entry in grouped.entries) ...[
                        SliverToBoxAdapter(
                          child: _buildZoneHeader(entry.key, entry.value),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final item = entry.value[index];
                            return _buildCardTile(item, allDeckCards: vaultItems);
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
                  child: ProportionalBubbleScrollbar(
                    sections: sections,
                    railWidth: 26,
                    railColor: Colors.black26,
                    bubbleColor: AppColors.accentCyan,
                    onSectionTap: (idx) =>
                        _scrollToSection(idx, sectionOffsets),
                  ),
                ),
            ],
          );
        },
        loading: () => Scaffold(
          appBar: AppBar(title: Text(widget.deck.name)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Scaffold(
          appBar: AppBar(title: Text(widget.deck.name)),
          body: Center(child: Text('Error loading deck: $e')),
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
      final qty = (item is DeckItemWithCard)
          ? item.deckQuantity
          : ((item['deck_quantity'] as num?)?.toInt() ?? 1);
      final price = (item is DeckItemWithCard)
          ? item.resolveMarketPrice(baseCurrency)
          : ((item['current_market_price'] as num?)?.toDouble() ?? 0.0);
      final cost = (item is DeckItemWithCard)
          ? item.effectiveCostBasis
          : ((item['purchase_price'] as num?)?.toDouble() ??
              (item['acquired_price'] as num?)?.toDouble() ??
              0.0);
      final zone = (item is DeckItemWithCard)
          ? item.boardZone
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.surface,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final maxTitleWidth = max(90.0, constraints.maxWidth - 120.0);
          return FlexibleSpaceBar(
            expandedTitleScale: 1.15,
            titlePadding: const EdgeInsets.only(
              left: 16,
              bottom: 14,
              right: 16,
            ),
            title: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTitleWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTitleWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        flex: 3,
                        fit: FlexFit.loose,
                        child: Text(
                          widget.deck.name,
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
                      Flexible(
                        flex: 2,
                        fit: FlexFit.loose,
                        child: Container(
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
                              'W:${widget.deck.wins} L:${widget.deck.losses}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.accentEmerald,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
            ),
            background: _buildCoverArt(),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.style_rounded),
          onPressed: _showFastDraw,
          tooltip: 'Fast-Draw 7',
        ),
        IconButton(
          icon: const Icon(Icons.analytics_rounded),
          onPressed: _showAnalytics,
          tooltip: 'Deck Analytics',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showQuickActions,
          tooltip: 'More Actions',
        ),
      ],
    );
  }

  Widget _buildCoverArt() {
    return Container(
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

  Widget _buildCardTile(Map<String, dynamic> item, {List<VaultItem>? allDeckCards}) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final isProxy = item['is_proxy'] == 1;
    final name = item['name'] as String? ?? 'Unknown Card';
    final qty = item['deck_quantity'] as int? ?? 1;
    final price = (item['current_market_price'] as num?)?.toDouble() ?? 0.0;
    final setCode = item['set_or_series'] as String? ?? '';
    final imageUrl = item['image_url'] as String? ?? '';

    String? manaCost;
    String? typeLine;
    final dynStr = item['dynamic_data'] as String?;
    if (dynStr != null && dynStr.isNotEmpty) {
      try {
        final data = jsonDecode(dynStr) as Map<String, dynamic>;
        manaCost = data['mana_cost'] as String?;
        typeLine = data['type_line'] as String?;
      } catch (_) {}
    }

    final subtitleText = [
      if (setCode.isNotEmpty) setCode.toUpperCase(),
      if (typeLine != null && typeLine.isNotEmpty) typeLine,
    ].join(' • ');

    return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final id = item['id'] as String? ?? 'item-${item.hashCode}';
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
                    ));
          CardDetailSheet.show(
            context,
            targetItem,
            items: effectiveDeckCards.isNotEmpty ? effectiveDeckCards : [targetItem],
            initialIndex: targetIndex >= 0 ? targetIndex : 0,
            deckId: widget.deck.id,
            deck: widget.deck,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Leading thumbnail Stack (fixed 38x50)
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.surfaceRaised,
                    ),
                    child: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.image_not_supported,
                                    size: 18,
                                    color: Colors.white24,
                                  ),
                            ),
                          )
                        : const Icon(
                            Icons.style_outlined,
                            size: 20,
                            color: Colors.white24,
                          ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // 2. Middle Text Block (Flexible Expanded)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isProxy ? Colors.grey[400] : Colors.white,
                      ),
                    ),
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 3. Trailing Metrics (Defensively constrained Column)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (manaCost != null && manaCost.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ManaCostBar(
                          manaCost: manaCost,
                          symbolSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isPrivacyMode
                            ? '****'
                            : (price > 0 ? '\$${price.toStringAsFixed(2)}' : '—'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentEmerald,
                        ),
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

  void _showAnalytics() {
    final analyticsAsync = ref.read(deckAnalyticsProvider(widget.deck.id));

    analyticsAsync.whenData((analytics) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _DeckAnalyticsSheet(analytics: analytics),
      );
    });
  }

  void _showQuickActions() {
    final itemsAsync = ref.read(deckItemsProvider(widget.deck.id));
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
              leading: const Icon(Icons.edit_note, color: AppColors.accentCyan),
              title: const Text('Deck Details & Notes'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeckMetadataScreen(deck: widget.deck),
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
                                child: imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.style_outlined,
                                                    size: 16,
                                                    color: Colors.white24,
                                                  ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.style_outlined,
                                        size: 16,
                                        color: Colors.white24,
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

// =============================================================================
// Deck Visual Analytics Modal (Mana Curve, Devotion, Bling Meter)
// =============================================================================

class _DeckAnalyticsSheet extends StatelessWidget {
  final DeckAnalytics analytics;

  const _DeckAnalyticsSheet({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: min(MediaQuery.of(context).size.height * 0.85, 580),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
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
                      'Deck Visual Analytics',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Mana Curve Section
                    _buildSectionTitle('Mana Curve (CMC 0 to 7+)'),
                    _buildManaCurveChart(analytics.manaCurve),
                    const SizedBox(height: 20),

                    // 2. Color Devotion Section
                    _buildSectionTitle('Color Devotion (Mana Pips)'),
                    _buildColorDevotionPips(analytics.colorDevotion),
                    const SizedBox(height: 20),

                    // 3. Bling Meter Section
                    _buildSectionTitle('Bling Meter'),
                    _buildBlingMeter(analytics.blingPercentage),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildManaCurveChart(Map<int, int> manaCurve) {
    // Find max count to scale histogram bars
    final buckets = [0, 1, 2, 3, 4, 5, 6, 7];
    int maxCount = 1;

    for (final cmc in buckets) {
      int count = 0;
      if (cmc == 7) {
        // Aggregate 7+
        count = manaCurve.entries
            .where((e) => e.key >= 7)
            .fold<int>(0, (sum, e) => sum + e.value);
      } else {
        count = manaCurve[cmc] ?? 0;
      }
      if (count > maxCount) maxCount = count;
    }

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets.map((cmc) {
          int count = 0;
          if (cmc == 7) {
            count = manaCurve.entries
                .where((e) => e.key >= 7)
                .fold<int>(0, (sum, e) => sum + e.value);
          } else {
            count = manaCurve[cmc] ?? 0;
          }

          final barProportion = (count / maxCount).clamp(0.05, 1.0);
          final barHeight = 70.0 * barProportion;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 22,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accentCyan, AppColors.accentVioletLight],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cmc == 7 ? '7+' : '$cmc',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildColorDevotionPips(Map<String, int> devotion) {
    final colors = [
      {
        'code': 'W',
        'name': 'White',
        'color': const Color(0xFFF8E7B9),
        'text': Colors.black87,
      },
      {
        'code': 'U',
        'name': 'Blue',
        'color': const Color(0xFF0E68AB),
        'text': Colors.white,
      },
      {
        'code': 'B',
        'name': 'Black',
        'color': const Color(0xFF212121),
        'text': Colors.white,
      },
      {
        'code': 'R',
        'name': 'Red',
        'color': const Color(0xFFD3202A),
        'text': Colors.white,
      },
      {
        'code': 'G',
        'name': 'Green',
        'color': const Color(0xFF00733E),
        'text': Colors.white,
      },
      {
        'code': 'C',
        'name': 'Colorless',
        'color': const Color(0xFF9E9E9E),
        'text': Colors.white,
      },
    ];

    final totalPips = devotion.values.fold<int>(0, (sum, v) => sum + v);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: colors.map((c) {
              final code = c['code'] as String;
              final count = devotion[code] ?? 0;
              final bg = c['color'] as Color;
              final fg = c['text'] as Color;

              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          if (totalPips > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: colors.map((c) {
                    final code = c['code'] as String;
                    final count = devotion[code] ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    final flex = max(1, count);
                    return Expanded(
                      flex: flex,
                      child: Container(color: c['color'] as Color),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlingMeter(double blingPercentage) {
    final pct = (blingPercentage * 100).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pct.toStringAsFixed(1)}% Bling',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Foils, Promos, Graded & Alters',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              width: double.infinity,
              color: Colors.black38,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentCyan,
                        AppColors.accentVioletLight,
                        Colors.amberAccent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

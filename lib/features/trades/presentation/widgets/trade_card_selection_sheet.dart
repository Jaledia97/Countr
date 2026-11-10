import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/trades/domain/models/trade_card_source_filter.dart';
import 'package:countr/features/trades/domain/services/trade_pricing_calculator.dart';

/// Bottom sheet for picking cards from a participant's inventory to include in "Sending".
class TradeCardSelectionSheet extends ConsumerStatefulWidget {
  final UserProfile user;
  final Set<String> currentlySelectedCardIds;
  final ValueChanged<VaultItem> onCardToggled;
  final bool isProposer;

  const TradeCardSelectionSheet({
    super.key,
    required this.user,
    required this.currentlySelectedCardIds,
    required this.onCardToggled,
    this.isProposer = false,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    required Set<String> currentlySelectedCardIds,
    required ValueChanged<VaultItem> onCardToggled,
    bool isProposer = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TradeCardSelectionSheet(
        user: user,
        currentlySelectedCardIds: currentlySelectedCardIds,
        onCardToggled: onCardToggled,
        isProposer: isProposer,
      ),
    );
  }

  @override
  ConsumerState<TradeCardSelectionSheet> createState() =>
      _TradeCardSelectionSheetState();
}

class _TradeCardSelectionSheetState
    extends ConsumerState<TradeCardSelectionSheet> {
  TradeCardSourceFilter? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final effectiveIsProposer =
        widget.isProposer || widget.user.id == currentUserId;

    final profileAsync = ref.watch(userProfileProvider(widget.user.id));
    final liveProfile = profileAsync.valueOrNull ?? widget.user;
    final isPartnerCollectionPublic =
        liveProfile.collectionVisibility == 'public';

    final canChooseSource = effectiveIsProposer || isPartnerCollectionPublic;
    final defaultFilter = effectiveIsProposer
        ? TradeCardSourceFilter.both
        : TradeCardSourceFilter.tradeBinder;
    final activeFilter = _selectedFilter ?? defaultFilter;
    final effectiveFilter =
        canChooseSource ? activeFilter : TradeCardSourceFilter.tradeBinder;

    final cardsAsync = ref.watch(
      userTradeCardsProvider(
        (
          userId: widget.user.id,
          filter: effectiveFilter,
          accountType: widget.user.accountType,
        ),
      ),
    );

    return Container(
      key: Key('trade_card_selection_sheet_${widget.user.id}'),
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.user.displayName}\'s Cards',
                      style: AppTypography.heading2.copyWith(fontSize: 16),
                    ),
                    Text(
                      'Tap cards to add to trade',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),

          // Filter Segmented Button or Privacy Locked Banner
          if (canChooseSource) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<TradeCardSourceFilter>(
                key: const Key('trade_card_source_filter_segmented'),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  selectedBackgroundColor:
                      AppColors.accentCyan.withValues(alpha: 0.2),
                  selectedForegroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.surfaceBorderSubtle),
                ),
                segments: const [
                  ButtonSegment<TradeCardSourceFilter>(
                    value: TradeCardSourceFilter.tradeBinder,
                    label: Text(
                      'Trade Binder',
                      key: Key('trade_card_source_trade_binder'),
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ButtonSegment<TradeCardSourceFilter>(
                    value: TradeCardSourceFilter.collection,
                    label: Text(
                      'Collection',
                      key: Key('trade_card_source_collection'),
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ButtonSegment<TradeCardSourceFilter>(
                    value: TradeCardSourceFilter.both,
                    label: Text(
                      'Both',
                      key: Key('trade_card_source_both'),
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                selected: {effectiveFilter},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedFilter = newSelection.first;
                  });
                },
              ),
            ),
          ] else ...[
            Container(
              key: const Key('partner_collection_private_banner'),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentAmber.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.accentAmber,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Partner\'s collection is Private (Trade Binder only)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 1, color: AppColors.surfaceBorder),

          // Cards list
          Expanded(
            child: cardsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              ),
              error: (err, stack) => Center(
                child: Text('Error loading cards: $err',
                    style: const TextStyle(color: AppColors.accentRose)),
              ),
              data: (cards) {
                if (cards.isEmpty) {
                  return const Center(
                    child: Text(
                      'No cards available in this binder',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final isSelected =
                        widget.currentlySelectedCardIds.contains(card.id);
                    final finish = TradePricingCalculator.resolveFinish(card);
                    final price = TradePricingCalculator.calculateCardPrice(
                      card,
                      finish: finish,
                    );
                    final imageUrl = card.imageUrl;

                    return ListTile(
                      key: Key('selection_card_tile_${card.id}'),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 36,
                          height: 50,
                          child: imageUrl.isNotEmpty
                              ? CountrCachedImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: AppColors.surfaceRaised,
                                  child: const Icon(Icons.style_rounded,
                                      size: 18, color: AppColors.accentCyan),
                                ),
                        ),
                      ),
                      title: Text(
                        card.name,
                        style: AppTypography.heading2.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          if (finish != 'non_foil')
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.accentAmber
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                finish.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentAmber,
                                ),
                              ),
                            ),
                          Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: AppColors.accentCyan,
                        onChanged: (_) {
                          widget.onCardToggled(card);
                        },
                      ),
                      onTap: () {
                        widget.onCardToggled(card);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/dialogs/large_value_difference_dialog.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/presentation/widgets/trade_fairness_gauge.dart';
import 'package:countr/features/trades/utils/card_name_resolver.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

/// Embedded Trade Offer Card rendered directly within Direct Message conversation bubbles.
class EmbeddedTradeOfferCard extends ConsumerStatefulWidget {
  final String proposalId;
  final String currentUserId;

  const EmbeddedTradeOfferCard({
    super.key,
    required this.proposalId,
    required this.currentUserId,
  });

  @override
  ConsumerState<EmbeddedTradeOfferCard> createState() =>
      _EmbeddedTradeOfferCardState();
}

class _EmbeddedTradeOfferCardState
    extends ConsumerState<EmbeddedTradeOfferCard> {
  bool _transferCardsChecked = true;

  Future<void> _handleAccept(
    BuildContext context,
    TradeProposalRecord proposal,
    TradeFairnessResult fairness,
  ) async {
    // 1. Large Value Difference Intercept:
    // If >= 15% OR >= $10.00 gap, show LargeValueDifferenceDialog
    if (fairness.isLargeGap) {
      final proceed = await LargeValueDifferenceDialog.checkAndConfirm(
        context: context,
        dollarGap: fairness.maxDollarGap,
        percentGap: fairness.maxGapPercent,
      );
      if (!proceed) return;
    }

    if (!context.mounted) return;

    // 2. Show Accept Confirmation Dialog with vault transfer checkbox
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.surfaceBorder),
              ),
              title: Row(
                children: const [
                  Icon(Icons.swap_horiz_rounded, color: AppColors.accentCyan),
                  SizedBox(width: 8),
                  Text('Confirm Trade', style: AppTypography.heading2),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proposal.isThreeWay
                        ? 'Accepting will finalize the 3-way pod trade.'
                        : 'Accepting will finalize the trade of \$${proposal.offeredTotalValue.toStringAsFixed(2)} for \$${proposal.requestedTotalValue.toStringAsFixed(2)}.',
                    style: AppTypography.body.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: CheckboxListTile(
                      key: const Key('trade_transfer_checkbox'),
                      value: _transferCardsChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          _transferCardsChecked = val ?? true;
                        });
                        setState(() {
                          _transferCardsChecked = val ?? true;
                        });
                      },
                      activeColor: AppColors.accentCyan,
                      title: const Text(
                        'Automatically mark traded cards as transferred',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Updates your vault inventory ownership immediately',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('confirm_accept_trade_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: AppColors.background,
                  ),
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    await ref.read(inboxDaoProvider).respondToTradeProposal(
                          proposal.id,
                          accept: true,
                          transferCards: _transferCardsChecked,
                          currentUserId: widget.currentUserId,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Trade proposal accepted successfully!'),
                          backgroundColor: AppColors.accentCyan,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Confirm & Accept',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<VaultItem>> _resolveCards(
    AppDatabase db,
    List<dynamic> cardIds,
    String ownerId,
  ) async {
    final strIds = cardIds.map((e) => e.toString()).toList();
    if (strIds.isEmpty) return [];

    final dbItems = await (db.select(db.vaultItems)
          ..where((t) => t.id.isIn(strIds)))
        .get();
    final itemsMap = {for (var item in dbItems) item.id: item};

    final result = <VaultItem>[];
    for (final id in strIds) {
      if (itemsMap.containsKey(id)) {
        result.add(itemsMap[id]!);
      } else {
        result.add(VaultItem(
          id: id,
          collectionType: 'mtg',
          name: CardNameResolver.formatSlug(id),
          setOrSeries: 'Default Set',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: 1,
          condition: 'Near Mint',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          currentMarketPrice: 0.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          userId: ownerId,
          isDeleted: false,
        ));
      }
    }
    return result;
  }

  Future<void> _handleEditTrade(
    BuildContext context,
    TradeProposalRecord proposal,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final proposerProfile =
        await db.userProfileDao.getProfile(proposal.proposerId);
    final receiverProfile =
        await db.userProfileDao.getProfile(proposal.receiverId);

    if (proposerProfile == null || receiverProfile == null) return;

    List<dynamic> offeredIds = [];
    List<dynamic> requestedIds = [];
    try {
      offeredIds = jsonDecode(proposal.offeredCardIdsJson);
      requestedIds = jsonDecode(proposal.requestedCardIdsJson);
    } catch (_) {}

    final proposerCards =
        await _resolveCards(db, offeredIds, proposal.proposerId);
    final receiverCards =
        await _resolveCards(db, requestedIds, proposal.receiverId);

    UserProfile? thirdProfile;
    if (proposal.thirdParticipantId != null &&
        proposal.thirdParticipantId!.isNotEmpty) {
      thirdProfile =
          await db.userProfileDao.getProfile(proposal.thirdParticipantId!);
    }

    final params = TradeProposalParams(
      currentUser: proposerProfile,
      partnerProfile: receiverProfile,
      initialThirdPartner: thirdProfile,
      mode: TradeProposalMode.edit,
      priorProposalId: proposal.id,
      preloadedCurrentUserCards: proposerCards,
      preloadedPartnerCards: receiverCards,
      initialNote: proposal.note,
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TradeScreen(params: params)),
    );
  }

  Future<void> _handleCounterTrade(
    BuildContext context,
    TradeProposalRecord proposal,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final recipientProfile =
        await db.userProfileDao.getProfile(widget.currentUserId);
    final proposerProfile =
        await db.userProfileDao.getProfile(proposal.proposerId);

    if (recipientProfile == null || proposerProfile == null) return;

    List<dynamic> offeredIds = [];
    List<dynamic> requestedIds = [];
    try {
      offeredIds = jsonDecode(proposal.offeredCardIdsJson);
      requestedIds = jsonDecode(proposal.requestedCardIdsJson);
    } catch (_) {}

    final myCards =
        await _resolveCards(db, requestedIds, widget.currentUserId);
    final partnerCards =
        await _resolveCards(db, offeredIds, proposal.proposerId);

    UserProfile? thirdProfile;
    if (proposal.thirdParticipantId != null &&
        proposal.thirdParticipantId!.isNotEmpty &&
        proposal.thirdParticipantId != widget.currentUserId) {
      thirdProfile =
          await db.userProfileDao.getProfile(proposal.thirdParticipantId!);
    }

    final params = TradeProposalParams(
      currentUser: recipientProfile,
      partnerProfile: proposerProfile,
      initialThirdPartner: thirdProfile,
      mode: TradeProposalMode.counter,
      priorProposalId: proposal.id,
      preloadedCurrentUserCards: myCards,
      preloadedPartnerCards: partnerCards,
      initialNote: proposal.note,
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TradeScreen(params: params)),
    );
  }

  Future<void> _handleCancelTrade(
    BuildContext context,
    TradeProposalRecord proposal,
  ) async {
    await ref.read(inboxDaoProvider).cancelTradeProposal(
          proposal.id,
          currentUserId: widget.currentUserId,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade proposal cancelled.'),
          backgroundColor: AppColors.accentRose,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return StreamBuilder<TradeProposalRecord?>(
      stream: (db.select(db.tradeProposals)
            ..where((t) => t.id.equals(widget.proposalId)))
          .watchSingleOrNull(),
      builder: (context, snapshot) {
        final proposal = snapshot.data;
        if (proposal == null) {
          return const SizedBox.shrink();
        }

        final isPending = proposal.status == 'pending';
        final isRecipient = proposal.receiverId == widget.currentUserId ||
            proposal.thirdParticipantId == widget.currentUserId;

        // Resolve fairness
        TradeFairnessResult fairness =
            TradeFairnessResult.tryParse(proposal.fairnessSummaryJson) ??
                _computeFallbackFairness(proposal);

        // Resolve transfers or fallback cards
        final transfers = TradeCardTransfer.listFromJson(proposal.cardTransfersJson);

        return Container(
          key: Key('embedded_trade_offer_card_${proposal.id}'),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPending
                  ? fairness.tier.color.withValues(alpha: 0.5)
                  : AppColors.surfaceBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Title & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: fairness.tier.color,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            proposal.isThreeWay
                                ? '3-Way Pod Trade'
                                : 'Trade Proposal',
                            style: AppTypography.heading2.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('trade_card_status_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(proposal.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _statusColor(proposal.status),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      proposal.status.toUpperCase(),
                      key: Key('embedded_trade_status_${proposal.id}'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _statusColor(proposal.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Compact Fairness Gauge
              TradeFairnessGauge(
                fairness: fairness,
                compact: true,
              ),
              const SizedBox(height: 10),

              // Card Previews
              if (transfers.isNotEmpty)
                _buildTransfersPreview(context, transfers)
              else
                _buildLegacyCardsPreview(context, proposal),

              // Action Buttons if pending & user is a recipient
              if (isPending && isRecipient) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 280) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            key: const Key('accept_trade_button'),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Accept Trade',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentCyan,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _handleAccept(context, proposal, fairness),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  key: const Key('trade_counter_offer_button'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accentViolet,
                                    side: const BorderSide(color: AppColors.accentViolet),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _handleCounterTrade(context, proposal),
                                  child: const Text('Counter'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  key: const Key('decline_trade_button'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accentRose,
                                    side: const BorderSide(color: AppColors.accentRose),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(inboxDaoProvider)
                                        .respondToTradeProposal(
                                          proposal.id,
                                          accept: false,
                                          transferCards: false,
                                          currentUserId: widget.currentUserId,
                                        );
                                  },
                                  child: const Text('Decline'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          key: const Key('accept_trade_button'),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Accept Trade',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _handleAccept(context, proposal, fairness),
                        ),
                        OutlinedButton(
                          key: const Key('trade_counter_offer_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentViolet,
                            side: const BorderSide(color: AppColors.accentViolet),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _handleCounterTrade(context, proposal),
                          child: const Text('Counter'),
                        ),
                        OutlinedButton(
                          key: const Key('decline_trade_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentRose,
                            side: const BorderSide(color: AppColors.accentRose),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            await ref
                                .read(inboxDaoProvider)
                                .respondToTradeProposal(
                                  proposal.id,
                                  accept: false,
                                  transferCards: false,
                                  currentUserId: widget.currentUserId,
                                );
                          },
                          child: const Text('Decline'),
                        ),
                      ],
                    );
                  },
                ),
              ] else if (isPending && !isRecipient) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 260) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            key: const Key('trade_edit_offer_button'),
                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Edit Trade',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentCyan,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _handleEditTrade(context, proposal),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            key: const Key('cancel_trade_button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentRose,
                              side: const BorderSide(color: AppColors.accentRose),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _handleCancelTrade(context, proposal),
                            child: const Text('Cancel Trade'),
                          ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          key: const Key('trade_edit_offer_button'),
                          icon: const Icon(
                            Icons.edit_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Edit Trade',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _handleEditTrade(context, proposal),
                        ),
                        OutlinedButton(
                          key: const Key('cancel_trade_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentRose,
                            side: const BorderSide(color: AppColors.accentRose),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _handleCancelTrade(context, proposal),
                          child: const Text('Cancel Trade'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransfersPreview(
    BuildContext context,
    List<TradeCardTransfer> transfers,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CARDS INVOLVED (${transfers.length})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: transfers.map((t) {
              return InkWell(
                onTap: () => CardDetailSheet.show(context, t.cardId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.surfaceBorder, width: 0.6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (t.imageUrl != null && t.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            width: 18,
                            height: 24,
                            child: CountrCachedImage(
                              imageUrl: t.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.style_rounded, size: 14, color: AppColors.accentCyan),
                      const SizedBox(width: 5),
                      Text(
                        t.cardName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\$${t.marketPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyCardsPreview(
    BuildContext context,
    TradeProposalRecord proposal,
  ) {
    List<dynamic> offered = [];
    List<dynamic> requested = [];
    try {
      offered = jsonDecode(proposal.offeredCardIdsJson);
      requested = jsonDecode(proposal.requestedCardIdsJson);
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFERED (${offered.length})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentAmber,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${proposal.offeredTotalValue.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted, size: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'REQUESTED (${requested.length})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentCyan,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${proposal.requestedTotalValue.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (offered.isNotEmpty || requested.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: offered.take(2).map((id) {
                      final name = CardNameResolver.formatSlug(id.toString());
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '• $name',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.accentCyan,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: requested.take(2).map((id) {
                      final name = CardNameResolver.formatSlug(id.toString());
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '• $name',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.accentCyan,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  TradeFairnessResult _computeFallbackFairness(TradeProposalRecord proposal) {
    final diff = (proposal.offeredTotalValue - proposal.requestedTotalValue).abs();
    final maxVal = proposal.offeredTotalValue > proposal.requestedTotalValue
        ? proposal.offeredTotalValue
        : proposal.requestedTotalValue;
    final pct = maxVal > 0 ? (diff / maxVal) * 100.0 : 0.0;

    final TradeFairnessTier tier;
    if (pct <= 10.0) {
      tier = TradeFairnessTier.fair;
    } else if (pct <= 25.0) {
      tier = TradeFairnessTier.moderate;
    } else {
      tier = TradeFairnessTier.lopsided;
    }

    return TradeFairnessResult(
      tier: tier,
      maxGapPercent: pct,
      maxDollarGap: diff,
      isLargeGap: pct >= 15.0 || diff >= 10.0,
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return AppColors.accentCyan;
      case 'countered':
        return AppColors.accentViolet;
      case 'declined':
      case 'cancelled':
        return AppColors.accentRose;
      case 'pending':
      default:
        return AppColors.accentAmber;
    }
  }
}

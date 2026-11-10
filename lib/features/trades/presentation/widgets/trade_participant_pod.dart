import 'package:flutter/material.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/presentation/widgets/trade_sending_card_tile.dart';

/// Renders a participant's complete trade section with "Sending" and "Receiving" blocks.
class TradeParticipantPod extends StatelessWidget {
  final TradeParticipant participant;
  final List<TradeParticipant> allParticipants;
  final bool isThreeWay;
  final VoidCallback onAddCards;
  final void Function(VaultItem item) onRemoveCard;
  final void Function(String cardId, String newRecipientId) onRecipientChanged;

  const TradeParticipantPod({
    super.key,
    required this.participant,
    required this.allParticipants,
    this.isThreeWay = false,
    required this.onAddCards,
    required this.onRemoveCard,
    required this.onRecipientChanged,
  });

  @override
  Widget build(BuildContext context) {
    final otherParticipants =
        allParticipants.where((p) => p.id != participant.id).toList();

    return Container(
      key: Key('trade_participant_pod_${participant.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: participant.hasLargeValueGap
              ? AppColors.accentRose.withValues(alpha: 0.5)
              : AppColors.surfaceBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Avatar, Name, and Total Pills
          _buildHeader(),

          const Divider(height: 1, color: AppColors.surfaceBorder),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. "Sending" Section
                _buildSendingSection(otherParticipants),

                const SizedBox(height: 14),

                // 2. "Receiving" Section (real-time calculated incoming cards)
                _buildReceivingSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceBorder,
            backgroundImage: participant.avatarUrl != null &&
                    participant.avatarUrl!.isNotEmpty
                ? NetworkImage(participant.avatarUrl!)
                : null,
            child: participant.avatarUrl == null || participant.avatarUrl!.isEmpty
                ? Text(
                    participant.displayName.isNotEmpty
                        ? participant.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Name and @username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.displayName,
                        style: AppTypography.heading2.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (participant.user.accountType == 'business') ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.accentCyan,
                      ),
                    ],
                  ],
                ),
                Text(
                  participant.username,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Quick Delta Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: participant.netDelta >= 0
                  ? AppColors.accentEmerald.withValues(alpha: 0.15)
                  : AppColors.accentRose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: participant.netDelta >= 0
                    ? AppColors.accentEmerald
                    : AppColors.accentRose,
                width: 0.8,
              ),
            ),
            child: Text(
              '${participant.netDelta >= 0 ? '+' : ''}\$${participant.netDelta.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: participant.netDelta >= 0
                    ? AppColors.accentEmerald
                    : AppColors.accentRose,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendingSection(List<TradeParticipant> otherParticipants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.accentAmber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'SENDING (${participant.sendingCards.length})',
                      key: Key('sending_header_${participant.id}'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentAmber,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${participant.sendingTotalValue.toStringAsFixed(2)}',
              key: Key('sending_total_${participant.id}'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // List of Sending Cards
        if (participant.sendingCards.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: const Text(
              'No cards selected yet',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          )
        else
          ...participant.sendingCards.map((card) {
            final transfer = participant.sendingTransfers.firstWhere(
              (t) => t.cardId == card.id,
              orElse: () => TradeCardTransfer.fromVaultItem(
                item: card,
                senderId: participant.id,
                recipientId: otherParticipants.isNotEmpty
                    ? otherParticipants.first.id
                    : '',
              ),
            );

            return TradeSendingCardTile(
              item: card,
              transfer: transfer,
              otherParticipants: otherParticipants,
              isThreeWay: isThreeWay,
              onRecipientChanged: (newRecipientId) =>
                  onRecipientChanged(card.id, newRecipientId),
              onRemove: () => onRemoveCard(card),
            );
          }),

        const SizedBox(height: 6),
        // Add Cards Button
        OutlinedButton.icon(
          key: Key('add_cards_button_${participant.id}'),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Select from ${participant.displayName}\'s Inventory'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentCyan,
            side: const BorderSide(color: AppColors.accentCyan, width: 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: onAddCards,
        ),
      ],
    );
  }

  Widget _buildReceivingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_downward_rounded,
                    color: AppColors.accentEmerald,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'RECEIVING (${participant.receivingTransfers.length})',
                      key: Key('receiving_header_${participant.id}'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentEmerald,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${participant.receivingTotalValue.toStringAsFixed(2)}',
              key: Key('receiving_total_${participant.id}'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // List of Real-Time Incoming Cards
        if (participant.receivingTransfers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: const Text(
              'No cards routed to this participant yet',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: participant.receivingTransfers.map((transfer) {
              return Container(
                key: Key('receiving_chip_${participant.id}_${transfer.cardId}'),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accentEmerald.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (transfer.imageUrl != null && transfer.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 24,
                          height: 32,
                          child: CountrCachedImage(
                            imageUrl: transfer.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.style_rounded, size: 16, color: AppColors.accentEmerald),
                    const SizedBox(width: 6),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              transfer.cardName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '\$${transfer.marketPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentEmerald,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

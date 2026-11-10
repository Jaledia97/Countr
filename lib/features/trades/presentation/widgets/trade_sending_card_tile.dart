import 'package:flutter/material.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/domain/services/trade_pricing_calculator.dart';

/// Card tile shown in a participant's "Sending" section.
/// In 3-way trades, displays a recipient dropdown allowing selection of which partner receives it.
class TradeSendingCardTile extends StatelessWidget {
  final VaultItem item;
  final TradeCardTransfer? transfer;
  final List<TradeParticipant> otherParticipants;
  final bool isThreeWay;
  final ValueChanged<String>? onRecipientChanged;
  final VoidCallback onRemove;

  const TradeSendingCardTile({
    super.key,
    required this.item,
    this.transfer,
    required this.otherParticipants,
    this.isThreeWay = false,
    this.onRecipientChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final finish = transfer?.finish ?? TradePricingCalculator.resolveFinish(item);
    final price = transfer?.marketPrice ??
        TradePricingCalculator.calculateCardPrice(item, finish: finish);
    final imageUrl = item.imageUrl;

    final currentRecipientId = transfer?.recipientId ??
        (otherParticipants.isNotEmpty ? otherParticipants.first.id : '');

    return Container(
      key: Key('trade_sending_card_${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 44,
              height: 60,
              child: imageUrl.isNotEmpty
                  ? CountrCachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.background,
                      child: const Icon(
                        Icons.style_rounded,
                        color: AppColors.accentCyan,
                        size: 20,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Details (Name, Finish, Price)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTypography.heading2.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (finish != 'non_foil')
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          finish.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
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
                if (isThreeWay && otherParticipants.length > 1) ...[
                  const SizedBox(height: 6),
                  // Recipient Dropdown in 3-Way Trades
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: Key('trade_card_recipient_dropdown_${item.id}'),
                        value: otherParticipants.any((p) => p.id == currentRecipientId)
                            ? currentRecipientId
                            : otherParticipants.first.id,
                        dropdownColor: AppColors.surfaceRaised,
                        isDense: true,
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.accentCyan,
                          size: 20,
                        ),
                        items: otherParticipants.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              'To: ${p.displayName}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newVal) {
                          if (newVal != null && onRecipientChanged != null) {
                            onRecipientChanged!(newVal);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Remove Button
          IconButton(
            key: Key('trade_remove_card_${item.id}'),
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textMuted,
            onPressed: onRemove,
            tooltip: 'Remove card',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/presentation/widgets/trade_fairness_gauge.dart';

/// Pinned/sticky Trade Value Meter showing live valuation, participant differentials,
/// and fairness gauge.
class StickyTradeValueMeter extends StatelessWidget {
  final List<TradeParticipant> participants;
  final TradeFairnessResult fairness;
  final bool compact;

  const StickyTradeValueMeter({
    super.key,
    required this.participants,
    required this.fairness,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sticky_trade_value_meter'),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fairness.tier.color.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Title & Fairness Gauge
          TradeFairnessGauge(
            fairness: fairness,
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 12),

          // Participant Value Breakdowns
          Row(
            children: participants.map((p) {
              return Expanded(
                child: _buildParticipantCard(p),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(TradeParticipant p) {
    final net = p.netDelta;
    final isPositive = net > 0.005;
    final isNegative = net < -0.005;

    final netColor = isPositive
        ? AppColors.accentEmerald
        : (isNegative ? AppColors.accentRose : AppColors.textSecondary);

    final netPrefix = isPositive ? '+' : (isNegative ? '-' : '');
    final netString = '$netPrefix\$${net.abs().toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: p.hasLargeValueGap
              ? AppColors.accentRose.withValues(alpha: 0.4)
              : AppColors.surfaceBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            p.displayName,
            key: Key('value_meter_participant_name_${p.id}'),
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Gives / Gets
          Text(
            'Gives: \$${p.sendingTotalValue.toStringAsFixed(2)}',
            style: AppTypography.caption.copyWith(
              fontSize: compact ? 9 : 10,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            'Gets: \$${p.receivingTotalValue.toStringAsFixed(2)}',
            style: AppTypography.caption.copyWith(
              fontSize: compact ? 9 : 10,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),

          // Net pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Net: $netString',
              key: Key('value_meter_participant_net_${p.id}'),
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: netColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

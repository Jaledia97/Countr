import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';

/// State of an active trade proposal builder.
class TradeProposalState {
  final List<TradeParticipant> participants;
  final List<TradeCardTransfer> transfers;
  final TradeFairnessResult fairness;
  final String note;
  final bool isSubmitting;
  final String? errorMessage;

  const TradeProposalState({
    required this.participants,
    this.transfers = const [],
    required this.fairness,
    this.note = '',
    this.isSubmitting = false,
    this.errorMessage,
  });

  bool get isThreeWay => participants.length >= 3;
  bool get canAddThirdPartner => participants.length < 3;
  bool get hasAnyCards => transfers.isNotEmpty;
  double get totalMarketVolume =>
      transfers.fold(0.0, (sum, t) => sum + t.marketPrice);

  TradeParticipant? getParticipant(String userId) {
    for (final p in participants) {
      if (p.id == userId) return p;
    }
    return null;
  }

  TradeProposalState copyWith({
    List<TradeParticipant>? participants,
    List<TradeCardTransfer>? transfers,
    TradeFairnessResult? fairness,
    String? note,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return TradeProposalState(
      participants: participants ?? this.participants,
      transfers: transfers ?? this.transfers,
      fairness: fairness ?? this.fairness,
      note: note ?? this.note,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

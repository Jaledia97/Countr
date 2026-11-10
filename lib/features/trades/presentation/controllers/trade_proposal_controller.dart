import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/daos/inbox_dao.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_state.dart';
import 'package:countr/features/trades/presentation/dialogs/large_value_difference_dialog.dart';

/// Mode for launching a trade proposal: fresh proposal, editing an existing proposal,
/// or countering a received proposal.
enum TradeProposalMode { create, edit, counter }

/// Configuration parameters for initializing a [TradeProposalController].
class TradeProposalParams {
  final UserProfile currentUser;
  final UserProfile partnerProfile;
  final UserProfile? initialThirdPartner;
  final VaultItem? initialPartnerCard;
  final TradeProposalMode mode;
  final String? priorProposalId;
  final List<VaultItem> preloadedCurrentUserCards;
  final List<VaultItem> preloadedPartnerCards;
  final String? initialNote;

  const TradeProposalParams({
    required this.currentUser,
    required this.partnerProfile,
    this.initialThirdPartner,
    this.initialPartnerCard,
    this.mode = TradeProposalMode.create,
    this.priorProposalId,
    this.preloadedCurrentUserCards = const [],
    this.preloadedPartnerCards = const [],
    this.initialNote,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeProposalParams &&
          runtimeType == other.runtimeType &&
          currentUser.id == other.currentUser.id &&
          partnerProfile.id == other.partnerProfile.id &&
          initialThirdPartner?.id == other.initialThirdPartner?.id &&
          initialPartnerCard?.id == other.initialPartnerCard?.id &&
          mode == other.mode &&
          priorProposalId == other.priorProposalId;

  @override
  int get hashCode =>
      currentUser.id.hashCode ^
      partnerProfile.id.hashCode ^
      (initialThirdPartner?.id.hashCode ?? 0) ^
      (initialPartnerCard?.id.hashCode ?? 0) ^
      mode.hashCode ^
      (priorProposalId?.hashCode ?? 0);
}

/// Riverpod StateNotifier managing 2-way and 3-way trade proposal state,
/// real-time card routing, and fairness evaluation.
class TradeProposalController extends StateNotifier<TradeProposalState> {
  final TradeProposalParams params;

  TradeProposalController(this.params)
      : super(
          _createInitialState(
            currentUser: params.currentUser,
            partnerProfile: params.partnerProfile,
            thirdPartner: params.initialThirdPartner,
            initialPartnerCard: params.initialPartnerCard,
            preloadedCurrentUserCards: params.preloadedCurrentUserCards,
            preloadedPartnerCards: params.preloadedPartnerCards,
            initialNote: params.initialNote,
          ),
        );

  static TradeProposalState _createInitialState({
    required UserProfile currentUser,
    required UserProfile partnerProfile,
    UserProfile? thirdPartner,
    VaultItem? initialPartnerCard,
    List<VaultItem> preloadedCurrentUserCards = const [],
    List<VaultItem> preloadedPartnerCards = const [],
    String? initialNote,
  }) {
    final transfers = <TradeCardTransfer>[];

    for (final card in preloadedCurrentUserCards) {
      transfers.add(TradeCardTransfer.fromVaultItem(
        item: card,
        senderId: currentUser.id,
        recipientId: partnerProfile.id,
      ));
    }

    final partnerCards = [...preloadedPartnerCards];
    if (initialPartnerCard != null &&
        !partnerCards.any((c) => c.id == initialPartnerCard.id)) {
      partnerCards.add(initialPartnerCard);
    }

    for (final card in partnerCards) {
      transfers.add(TradeCardTransfer.fromVaultItem(
        item: card,
        senderId: partnerProfile.id,
        recipientId: currentUser.id,
      ));
    }

    var userParticipant = TradeParticipant(
      user: currentUser,
      sendingCards: preloadedCurrentUserCards,
    );
    var partnerParticipant = TradeParticipant(
      user: partnerProfile,
      sendingCards: partnerCards,
    );

    final participants = <TradeParticipant>[
      userParticipant,
      partnerParticipant,
    ];
    if (thirdPartner != null) {
      participants.add(TradeParticipant(user: thirdPartner));
    }

    final recalculated = participants.map((p) {
      final sending = transfers.where((t) => t.senderId == p.id).toList();
      final receiving = transfers.where((t) => t.recipientId == p.id).toList();
      final sendingTotal =
          sending.fold<double>(0.0, (sum, t) => sum + t.marketPrice);
      final receivingTotal =
          receiving.fold<double>(0.0, (sum, t) => sum + t.marketPrice);

      return p.copyWith(
        sendingTransfers: sending,
        receivingTransfers: receiving,
        sendingTotalValue: sendingTotal,
        receivingTotalValue: receivingTotal,
      );
    }).toList();

    return TradeProposalState(
      participants: recalculated,
      transfers: transfers,
      fairness: TradeFairnessResult.evaluate(recalculated),
      note: initialNote ?? '',
    );
  }

  /// Adds a 3rd trade partner to convert this into a 3-way pod trade (max 3 users total).
  void addThirdParticipant(UserProfile partner) {
    if (state.participants.length >= 3) return;
    if (state.participants.any((p) => p.id == partner.id)) return;

    final updated = List<TradeParticipant>.from(state.participants)
      ..add(TradeParticipant(user: partner));

    _updateWithParticipantsAndTransfers(updated, state.transfers);
  }

  /// Removes the 3rd trade partner, returning to a 2-way trade.
  void removeThirdParticipant() {
    if (state.participants.length <= 2) return;

    final removed = state.participants.last;
    final remaining = state.participants.sublist(0, 2);

    // Filter out transfers sent by the removed partner, and reroute any transfers
    // targeted to the removed partner to the remaining partner.
    final updatedTransfers = <TradeCardTransfer>[];
    for (final t in state.transfers) {
      if (t.senderId == removed.id) continue;
      if (t.recipientId == removed.id) {
        // Reroute to the other remaining participant
        final other = remaining.firstWhere((p) => p.id != t.senderId);
        updatedTransfers.add(t.copyWith(recipientId: other.id));
      } else {
        updatedTransfers.add(t);
      }
    }

    _updateWithParticipantsAndTransfers(remaining, updatedTransfers);
  }

  /// Adds a card to the "Sending" section of [participantId].
  void addSendingCard(String participantId, VaultItem card) {
    final participant = state.getParticipant(participantId);
    if (participant == null) return;
    if (participant.sendingCards.any((c) => c.id == card.id)) return;

    // Determine default recipient
    final otherParticipants =
        state.participants.where((p) => p.id != participantId).toList();
    if (otherParticipants.isEmpty) return;

    final recipientId = otherParticipants.first.id;
    final transfer = TradeCardTransfer.fromVaultItem(
      item: card,
      senderId: participantId,
      recipientId: recipientId,
    );

    final updatedParticipants = state.participants.map((p) {
      if (p.id == participantId) {
        return p.copyWith(
          sendingCards: [...p.sendingCards, card],
        );
      }
      return p;
    }).toList();

    final updatedTransfers = [...state.transfers, transfer];
    _updateWithParticipantsAndTransfers(updatedParticipants, updatedTransfers);
  }

  /// Removes a card from the "Sending" section of [participantId].
  void removeSendingCard(String participantId, String cardId) {
    final participant = state.getParticipant(participantId);
    if (participant == null) return;

    final updatedParticipants = state.participants.map((p) {
      if (p.id == participantId) {
        return p.copyWith(
          sendingCards: p.sendingCards.where((c) => c.id != cardId).toList(),
        );
      }
      return p;
    }).toList();

    final updatedTransfers =
        state.transfers.where((t) => t.cardId != cardId).toList();

    _updateWithParticipantsAndTransfers(updatedParticipants, updatedTransfers);
  }

  /// In 3-way trades, updates which trade partner receives [cardId].
  void updateCardRecipient({
    required String cardId,
    required String newRecipientId,
  }) {
    final updatedTransfers = state.transfers.map((t) {
      if (t.cardId == cardId) {
        return t.copyWith(recipientId: newRecipientId);
      }
      return t;
    }).toList();

    _updateWithParticipantsAndTransfers(state.participants, updatedTransfers);
  }

  /// Updates proposal note.
  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  /// Recalculates all sending/receiving allocations, dollar values, net deltas, and fairness.
  void _updateWithParticipantsAndTransfers(
    List<TradeParticipant> participants,
    List<TradeCardTransfer> transfers,
  ) {
    // For each participant, recalculate incoming/outgoing transfers and totals
    final recalculated = participants.map((p) {
      final sending = transfers.where((t) => t.senderId == p.id).toList();
      final receiving = transfers.where((t) => t.recipientId == p.id).toList();

      final sendingTotal =
          sending.fold<double>(0.0, (sum, t) => sum + t.marketPrice);
      final receivingTotal =
          receiving.fold<double>(0.0, (sum, t) => sum + t.marketPrice);

      return p.copyWith(
        sendingTransfers: sending,
        receivingTransfers: receiving,
        sendingTotalValue: sendingTotal,
        receivingTotalValue: receivingTotal,
      );
    }).toList();

    final fairness = TradeFairnessResult.evaluate(recalculated);

    state = state.copyWith(
      participants: recalculated,
      transfers: transfers,
      fairness: fairness,
      errorMessage: null,
    );
  }

  /// Intercepts submission with [LargeValueDifferenceDialog] if a large value gap is present,
  /// then persists the proposal to [InboxDao] and sends DM attachments.
  Future<TradeProposalRecord?> submitProposal({
    required BuildContext context,
    required InboxDao inboxDao,
    required String currentUserId,
  }) async {
    // Check Large Value Difference Safeguard:
    // If >= 15% OR >= $10.00 difference, intercept with LargeValueDifferenceDialog
    if (state.fairness.isLargeGap) {
      final proceed = await LargeValueDifferenceDialog.checkAndConfirm(
        context: context,
        dollarGap: state.fairness.maxDollarGap,
        percentGap: state.fairness.maxGapPercent,
      );
      if (!proceed) {
        return null; // User chose [Review Trade] or dismissed
      }
    }

    state = state.copyWith(isSubmitting: true);

    try {
      final proposer = state.participants.firstWhere(
        (p) => p.id == currentUserId,
        orElse: () => state.participants.first,
      );

      final otherParticipants =
          state.participants.where((p) => p.id != proposer.id).toList();
      if (otherParticipants.isEmpty) {
        throw Exception('A trade requires at least one other partner.');
      }

      final receiver = otherParticipants.first;
      final thirdPartner =
          otherParticipants.length > 1 ? otherParticipants[1] : null;

      final offeredCards = state.transfers
          .where((t) => t.senderId == proposer.id)
          .map((t) => t.cardId)
          .toList();

      final requestedCards = state.transfers
          .where((t) => t.recipientId == proposer.id)
          .map((t) => t.cardId)
          .toList();

      if (params.mode == TradeProposalMode.counter &&
          params.priorProposalId != null) {
        final record = await inboxDao.counterTradeProposal(
          params.priorProposalId!,
          proposerId: proposer.id,
          receiverId: receiver.id,
          thirdParticipantId: thirdPartner?.id,
          isThreeWay: state.isThreeWay,
          cardTransfersJson: TradeCardTransfer.listToJson(state.transfers),
          fairnessSummaryJson: jsonEncode(state.fairness.toJson()),
          offeredCardIds: offeredCards,
          requestedCardIds: requestedCards,
          offeredTotalValue: proposer.sendingTotalValue,
          requestedTotalValue: proposer.receivingTotalValue,
          proposerCashDelta:
              proposer.receivingTotalValue - proposer.sendingTotalValue,
          note: state.note.isNotEmpty ? state.note : null,
        );

        state = state.copyWith(isSubmitting: false);
        return record;
      } else if (params.mode == TradeProposalMode.edit &&
          params.priorProposalId != null) {
        // Atomic edit: cancel prior proposal then create new proposal
        await inboxDao.cancelTradeProposal(
          params.priorProposalId!,
          currentUserId: proposer.id,
        );
      }

      final record = await inboxDao.createTradeProposal(
        proposerId: proposer.id,
        receiverId: receiver.id,
        thirdParticipantId: thirdPartner?.id,
        isThreeWay: state.isThreeWay,
        cardTransfersJson: TradeCardTransfer.listToJson(state.transfers),
        fairnessSummaryJson: jsonEncode(state.fairness.toJson()),
        offeredCardIds: offeredCards,
        requestedCardIds: requestedCards,
        offeredTotalValue: proposer.sendingTotalValue,
        requestedTotalValue: proposer.receivingTotalValue,
        proposerCashDelta:
            proposer.receivingTotalValue - proposer.sendingTotalValue,
        note: state.note.isNotEmpty ? state.note : null,
      );

      state = state.copyWith(isSubmitting: false);
      return record;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}

/// Provider family for accessing and managing a trade proposal state.
final tradeProposalControllerProvider = StateNotifierProvider.autoDispose
    .family<TradeProposalController, TradeProposalState, TradeProposalParams>(
  (ref, params) => TradeProposalController(params),
);

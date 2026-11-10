import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/widgets/add_third_partner_sheet.dart';
import 'package:countr/features/trades/presentation/widgets/sticky_trade_value_meter.dart';
import 'package:countr/features/trades/presentation/widgets/trade_card_selection_sheet.dart';
import 'package:countr/features/trades/presentation/widgets/trade_participant_pod.dart';

/// Full interactive Trade Screen supporting 2-way and 3-way pod trades,
/// sticky Trade Value Meter, recipient dropdowns, and safeguard interception.
class TradeScreen extends ConsumerStatefulWidget {
  final TradeProposalParams params;

  const TradeScreen({
    super.key,
    required this.params,
  });

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.params.initialNote != null &&
        widget.params.initialNote!.isNotEmpty) {
      _noteCtrl.text = widget.params.initialNote!;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradeProposalControllerProvider(widget.params));
    final controller =
        ref.read(tradeProposalControllerProvider(widget.params).notifier);

    final mediaQuery = MediaQuery.maybeOf(context);
    final screenWidth = mediaQuery?.size.width ?? 400.0;
    final textScale = mediaQuery?.textScaler.scale(1.0) ?? 1.0;
    final isCompact = screenWidth < 380 || textScale > 1.2;

    Future<void> onAddThirdPartner() async {
      final existingIds =
          state.participants.map((p) => p.id).toList();
      final selected = await AddThirdPartnerSheet.show(
        context,
        existingParticipantIds: existingIds,
      );
      if (selected != null) {
        controller.addThirdParticipant(selected);
      }
    }

    String screenTitle;
    if (widget.params.mode == TradeProposalMode.counter) {
      screenTitle = 'Counter Trade Offer';
    } else if (widget.params.mode == TradeProposalMode.edit) {
      screenTitle = 'Edit Trade Offer';
    } else if (state.isThreeWay) {
      screenTitle = '3-Way Pod Trade';
    } else {
      screenTitle = 'Propose Trade';
    }

    return Container(
      key: const Key('propose_trade_modal'),
      child: Scaffold(
        key: const Key('trade_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          screenTitle,
          style: AppTypography.heading2.copyWith(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // "+ Add 3rd Trade Partner" Button
          if (state.canAddThirdPartner)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: isCompact
                  ? IconButton(
                      key: const Key('add_third_trade_partner_button'),
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          size: 20, color: AppColors.accentCyan),
                      tooltip: 'Add 3rd Trade Partner',
                      onPressed: onAddThirdPartner,
                    )
                  : TextButton.icon(
                      key: const Key('add_third_trade_partner_button'),
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          size: 16, color: AppColors.accentCyan),
                      label: const Text(
                        '+ Add 3rd Trade Partner',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCyan,
                        ),
                      ),
                      onPressed: onAddThirdPartner,
                    ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                key: const Key('remove_third_trade_partner_button'),
                icon: const Icon(Icons.person_remove_rounded,
                    size: 18, color: AppColors.accentRose),
                tooltip: 'Revert to 2-way trade',
                onPressed: () => controller.removeThirdParticipant(),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pinned Sticky Trade Value Meter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: StickyTradeValueMeter(
                participants: state.participants,
                fairness: state.fairness,
                compact: isCompact,
              ),
            ),

            // Scrollable participant pods & notes
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Participant Pods
                  ...state.participants.map((participant) {
                    return TradeParticipantPod(
                      participant: participant,
                      allParticipants: state.participants,
                      isThreeWay: state.isThreeWay,
                      onAddCards: () {
                        final selectedIds = participant.sendingCards
                            .map((c) => c.id)
                            .toSet();
                        final isProposer = participant.user.id == widget.params.currentUser.id;
                        TradeCardSelectionSheet.show(
                          context,
                          user: participant.user,
                          currentlySelectedCardIds: selectedIds,
                          isProposer: isProposer,
                          onCardToggled: (card) {
                            if (selectedIds.contains(card.id)) {
                              controller.removeSendingCard(
                                  participant.id, card.id);
                            } else {
                              controller.addSendingCard(
                                  participant.id, card);
                            }
                          },
                        );
                      },
                      onRemoveCard: (card) {
                        controller.removeSendingCard(
                            participant.id, card.id);
                      },
                      onRecipientChanged: (cardId, newRecipientId) {
                        controller.updateCardRecipient(
                          cardId: cardId,
                          newRecipientId: newRecipientId,
                        );
                      },
                    );
                  }),

                  // Optional Note
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.surfaceBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Proposal Note (Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _noteCtrl,
                          onChanged: controller.setNote,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Add a message or condition notes...',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Sticky Proposal Submission Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                border: const Border(
                  top: BorderSide(color: AppColors.surfaceBorder, width: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('send_trade_proposal_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: state.isSubmitting
                          ? null
                          : () async {
                              final inboxDao = ref.read(inboxDaoProvider);
                              final result = await controller.submitProposal(
                                context: context,
                                inboxDao: inboxDao,
                                currentUserId: widget.params.currentUser.id,
                              );
                              if (result != null && context.mounted) {
                                Navigator.of(context).pop(result);
                                final String snackText;
                                if (widget.params.mode ==
                                    TradeProposalMode.counter) {
                                  snackText =
                                      'Counter offer sent successfully!';
                                } else if (widget.params.mode ==
                                    TradeProposalMode.edit) {
                                  snackText =
                                      'Trade offer updated successfully!';
                                } else if (state.isThreeWay) {
                                  snackText =
                                      '3-Way Pod Trade proposal sent!';
                                } else {
                                  snackText =
                                      'Trade proposal sent successfully!';
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(snackText),
                                    backgroundColor: AppColors.accentCyan,
                                  ),
                                );
                              }
                            },
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : Text(
                              widget.params.mode == TradeProposalMode.counter
                                  ? 'Send Counter Offer'
                                  : (widget.params.mode == TradeProposalMode.edit
                                      ? 'Update Trade Offer'
                                      : (state.isThreeWay
                                          ? 'Send 3-Way Trade Proposal'
                                          : 'Send Trade Proposal')),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
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
}

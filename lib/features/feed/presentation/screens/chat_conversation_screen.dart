import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../trades/presentation/controllers/trade_proposal_controller.dart';
import '../../../trades/presentation/dialogs/large_value_difference_dialog.dart';
import '../../../trades/presentation/screens/trade_screen.dart';
import '../../../trades/presentation/widgets/embedded_trade_offer_card.dart';
import '../../../trades/utils/card_name_resolver.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../../vault/presentation/widgets/card_detail_sheet.dart';
import '../providers/inbox_providers.dart';

/// Chat Conversation Screen (/inbox/chat/:conversationId)
/// Features:
/// - Real-time Drift message stream
/// - Text messaging with send button
/// - Card attachment preview bubbles with CardDetailSheet navigation
/// - Embedded interactive Trade Proposal comparison card
/// - Atomic trade acceptance engine confirmation dialog with auto-transfer checkbox
class ChatConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? contactId;

  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    this.contactId,
  });

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final currentUserId = ref.read(currentUserIdProvider);
    await ref
        .read(inboxDaoProvider)
        .markMessagesAsRead(widget.conversationId, currentUserId);
  }

  String _resolveContactId(List<MessageRecord> messages, String currentUserId) {
    if (widget.contactId != null && widget.contactId!.isNotEmpty) {
      return widget.contactId!;
    }
    for (final m in messages) {
      if (m.senderId != currentUserId) return m.senderId;
      if (m.recipientId != currentUserId) return m.recipientId;
    }
    return 'user-foil-collector-99';
  }

  Future<void> _handleSendMessage(String recipientId) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = ref.read(currentUserIdProvider);
    _textController.clear();

    await ref.read(inboxDaoProvider).sendMessage(
          senderId: currentUserId,
          recipientId: recipientId,
          messageText: text,
        );

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final messagesAsync =
        ref.watch(chatMessagesStreamProvider(widget.conversationId));

    return messagesAsync.when(
      data: (messages) {
        final contactId = _resolveContactId(messages, currentUserId);
        final db = ref.watch(appDatabaseProvider);

        return FutureBuilder<UserProfile?>(
          future: db.userProfileDao.getProfile(contactId),
          builder: (context, userSnapshot) {
            final contact = userSnapshot.data ??
                UserProfile(
                  id: contactId,
                  username: '@$contactId',
                  displayName: contactId,
                  accountType: 'individual',
                  isVerifiedBusiness: false,
                  friendCount: 0,
                  repCount: 0,
                  tier: 'free',
                  syncStatus: 'synced',
                  collectionVisibility: 'public',
                  createdAt: DateTime.now(),
                  isDeleted: false,
                );

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                titleSpacing: 0,
                title: InkWell(
                  onTap: () => context.push('/profile/$contactId'),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentViolet,
                              AppColors.accentCyan,
                            ],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.displayName,
                              style: AppTypography.heading2.copyWith(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              contact.username,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              body: Column(
                children: [
                  // Active Trade Proposal Stream
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: _ActiveTradeProposalBanner(
                      conversationId: widget.conversationId,
                      currentUserId: currentUserId,
                      contactId: contactId,
                    ),
                  ),

                  // Messages List
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Send a message to start trading or chatting!',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg.senderId == currentUserId;
                              return _MessageBubble(
                                message: msg,
                                isMe: isMe,
                                currentUserId: currentUserId,
                              );
                            },
                          ),
                  ),

                  // Bottom Message Input
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceRaised,
                      border: Border(
                        top: BorderSide(color: AppColors.surfaceBorder),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: TextField(
                                key: const Key('chat_message_input'),
                                controller: _textController,
                                style: AppTypography.body.copyWith(
                                  fontSize: 14,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) =>
                                    _handleSendMessage(contactId),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('chat_message_send_button'),
                            icon: const Icon(
                              Icons.send_rounded,
                              color: AppColors.accentCyan,
                            ),
                            onPressed: () => _handleSendMessage(contactId),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Error loading conversation: $err',
            style: const TextStyle(color: AppColors.accentRose),
          ),
        ),
      ),
    );
  }
}

/// Message Bubble widget rendering text and interactive card attachments
class _MessageBubble extends StatelessWidget {
  final MessageRecord message;
  final bool isMe;
  final String currentUserId;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accentCyan.withValues(alpha: 0.18)
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
          border: Border.all(
            color: isMe
                ? AppColors.accentCyan.withValues(alpha: 0.4)
                : AppColors.surfaceBorder,
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Card Attachment Preview
            if (message.attachmentType == 'card' &&
                message.attachmentCardId != null) ...[
              InkWell(
                key: Key('chat_card_attachment_${message.id}'),
                onTap: () {
                  CardDetailSheet.show(context, message.attachmentCardId!);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.style_rounded,
                        size: 20,
                        color: AppColors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Card Attachment',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentCyan,
                              ),
                            ),
                            Text(
                              message.attachmentCardId!,
                              style: AppTypography.heading2.copyWith(
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Embedded Trade Offer Card
            if (message.attachmentType == 'trade_proposal' ||
                message.attachmentTradeProposalId != null) ...[
              EmbeddedTradeOfferCard(
                proposalId: message.attachmentTradeProposalId ?? message.id,
                currentUserId: currentUserId,
              ),
              const SizedBox(height: 6),
            ],

            // Message text
            Text(
              message.messageText,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Time
            Text(
              _formatTime(message.createdAt),
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}

/// Active Trade Proposal comparison banner and acceptance engine
class _ActiveTradeProposalBanner extends ConsumerStatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String contactId;

  const _ActiveTradeProposalBanner({
    required this.conversationId,
    required this.currentUserId,
    required this.contactId,
  });

  @override
  ConsumerState<_ActiveTradeProposalBanner> createState() =>
      _ActiveTradeProposalBannerState();
}

class _ActiveTradeProposalBannerState
    extends ConsumerState<_ActiveTradeProposalBanner> {
  bool _transferCardsChecked = true;

  Future<void> _handleAcceptTrade(
    BuildContext context,
    TradeProposalRecord proposal,
  ) async {
    final diff = (proposal.offeredTotalValue - proposal.requestedTotalValue).abs();
    final maxVal = math.max(proposal.offeredTotalValue, proposal.requestedTotalValue);
    final pct = maxVal > 0 ? (diff / maxVal) * 100.0 : 0.0;

    if (diff >= 10.0 || pct >= 15.0) {
      final proceed = await LargeValueDifferenceDialog.checkAndConfirm(
        context: context,
        dollarGap: diff,
        percentGap: pct,
      );
      if (!proceed) return;
    }

    if (!context.mounted) return;
    _showAcceptConfirmationDialog(context, proposal);
  }

  void _showAcceptConfirmationDialog(
    BuildContext context,
    TradeProposalRecord proposal,
  ) {
    showDialog(
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
                  Icon(Icons.swap_horiz_rounded, color: AppColors.accentAmber),
                  SizedBox(width: 8),
                  Text('Confirm Trade', style: AppTypography.heading2),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accepting will finalize the trade of \$${proposal.offeredTotalValue.toStringAsFixed(2)} for \$${proposal.requestedTotalValue.toStringAsFixed(2)}.',
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

    return StreamBuilder<List<TradeProposalRecord>>(
      stream: (db.select(db.tradeProposals)
            ..where((t) =>
                ((t.proposerId.equals(widget.currentUserId) &
                        t.receiverId.equals(widget.contactId)) |
                    (t.proposerId.equals(widget.contactId) &
                        t.receiverId.equals(widget.currentUserId))) &
                t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .watch(),
      builder: (context, snapshot) {
        final proposals = snapshot.data ?? [];
        if (proposals.isEmpty) return const SizedBox.shrink();

        final proposal = proposals.first;
        // Pinned Banner Requirement: only render if proposal is active pending
        if (proposal.status != 'pending') return const SizedBox.shrink();

        final isRecipient = proposal.receiverId == widget.currentUserId;
        final isPending = proposal.status == 'pending';

        final List<dynamic> offeredCardIds =
            jsonDecode(proposal.offeredCardIdsJson);
        final List<dynamic> requestedCardIds =
            jsonDecode(proposal.requestedCardIdsJson);

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPending
                    ? AppColors.accentAmber.withValues(alpha: 0.6)
                    : AppColors.surfaceBorder,
                width: 1.2,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Title & Status Pill
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.accentAmber,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Active Trade Proposal',
                              style: AppTypography.heading2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        key: const Key('trade_card_status_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(proposal.status).withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _statusColor(proposal.status),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          proposal.status.toUpperCase(),
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

              // Side-by-side comparison of Offered vs Requested
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offered Section
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OFFERED (${offeredCardIds.length})',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentAmber,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${proposal.offeredTotalValue.toStringAsFixed(2)}',
                            style: AppTypography.heading2.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          ...offeredCardIds.take(2).map((id) {
                            final cardName =
                                CardNameResolver.formatSlug(id.toString());
                            return InkWell(
                              onTap: () =>
                                  CardDetailSheet.show(context, id.toString()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '• $cardName',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 11,
                                    color: AppColors.accentCyan,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Requested Section
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REQUESTED (${requestedCardIds.length})',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${proposal.requestedTotalValue.toStringAsFixed(2)}',
                            style: AppTypography.heading2.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          ...requestedCardIds.take(2).map((id) {
                            final cardName =
                                CardNameResolver.formatSlug(id.toString());
                            return InkWell(
                              onTap: () =>
                                  CardDetailSheet.show(context, id.toString()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '• $cardName',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 11,
                                    color: AppColors.accentCyan,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Action Buttons if pending
              if (isPending && isRecipient) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      key: const Key('chat_accept_trade_button'),
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
                      onPressed: () =>
                          _handleAcceptTrade(context, proposal),
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
                      onPressed: () =>
                          _handleCounterTrade(context, proposal),
                      child: const Text('Counter'),
                    ),
                    OutlinedButton(
                      key: const Key('chat_decline_trade_button'),
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
                ),
              ] else if (isPending && !isRecipient) ...[
                const SizedBox(height: 12),
                Wrap(
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
                      onPressed: () =>
                          _handleEditTrade(context, proposal),
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
                      onPressed: () =>
                          _handleCancelTrade(context, proposal),
                      child: const Text('Cancel Trade'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
      },
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

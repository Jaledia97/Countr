import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/social/notifications_table.dart';
import '../../../../core/database/tables/social/messages_table.dart';
import '../../../../core/database/tables/social/trade_proposals_table.dart';
import '../../../../core/database/tables/social/friendships_table.dart';
import '../../../../core/database/tables/user_profiles_table.dart';
import '../../../../core/database/tables/vault_binders_table.dart';
import '../../../../core/database/tables/vault_items_table.dart';

part 'inbox_dao.g.dart';

@DriftAccessor(tables: [
  Notifications,
  Messages,
  TradeProposals,
  Friendships,
  UserProfiles,
  VaultBinders,
  VaultItems,
])
class InboxDao extends DatabaseAccessor<AppDatabase> with _$InboxDaoMixin {
  InboxDao(super.db);

  static int _proposalSequence = 0;

  /// Builds a deterministic conversation ID between two user IDs.
  static String getConversationId(String u1, String u2) {
    return u1.compareTo(u2) < 0 ? '${u1}_$u2' : '${u2}_$u1';
  }

  // ==========================================
  // NOTIFICATIONS
  // ==========================================

  /// Streams notifications for a user, ordered chronologically descending.
  Stream<List<NotificationRecord>> watchNotifications(
    String userId, {
    String filter = 'all',
  }) {
    return (select(notifications)
          ..where((t) {
            var predicate = t.userId.equals(userId) &
                t.actorId.equals(userId).not() &
                t.isDeleted.equals(false);
            if (filter == 'requests') {
              predicate = predicate & t.type.equals('friend_request');
            } else if (filter == 'trades') {
              predicate = predicate &
                  t.type.isIn(const ['trade_proposal', 'trade_match']);
            } else if (filter == 'activity') {
              predicate = predicate &
                  t.type.isIn(const [
                    'post_like',
                    'post_comment',
                    'deck_upvote',
                    'mention',
                    'milestone',
                  ]);
            }
            return predicate;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Computes smart default inbox tab:
  /// Returns 1 (Messages tab) if latest incoming message is newer than latest notification,
  /// else returns 0 (Notifications tab).
  Future<int> getSmartInboxInitialIndex(String userId) async {
    final latestNotif = await (select(notifications)
          ..where((t) =>
              t.userId.equals(userId) &
              t.actorId.equals(userId).not() &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();

    final latestMsg = await (select(messages)
          ..where((t) => t.recipientId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();

    final notifTime = latestNotif?.createdAt;
    final msgTime = latestMsg?.createdAt;

    if (msgTime != null) {
      if (notifTime == null || msgTime.isAfter(notifTime)) {
        return 1; // Messages tab
      }
    }
    return 0; // Notifications tab (default)
  }

  /// Streams the unread notification count for a user.
  Stream<int> watchUnreadNotificationCount(String userId) {
    final count = notifications.id.count();
    final query = selectOnly(notifications)
      ..addColumns([count])
      ..where(
        notifications.userId.equals(userId) &
            notifications.actorId.equals(userId).not() &
            notifications.isRead.equals(false) &
            notifications.isDeleted.equals(false),
      );

    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Marks a specific notification as read.
  Future<void> markNotificationAsRead(String notificationId) async {
    final now = DateTime.now();
    await (update(notifications)..where((t) => t.id.equals(notificationId))).write(
      NotificationsCompanion(
        isRead: const Value(true),
        status: const Value('read'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Marks all unread notifications for a user as read.
  Future<void> markAllNotificationsAsRead(String userId) async {
    final now = DateTime.now();
    await (update(notifications)
          ..where((t) =>
              t.userId.equals(userId) &
              t.actorId.equals(userId).not() &
              t.isRead.equals(false) &
              t.isDeleted.equals(false)))
        .write(
      NotificationsCompanion(
        isRead: const Value(true),
        status: const Value('read'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Responds to an interactive friend request notification.
  /// Updates notification status, creates/updates friendship record, and increments friend count if accepted.
  Future<void> respondToFriendRequest({
    required String notificationId,
    required bool accept,
  }) {
    return transaction(() async {
      final notif = await (select(notifications)
            ..where((t) => t.id.equals(notificationId)))
          .getSingleOrNull();

      if (notif == null) return;
      // Idempotency: Guard against duplicate approvals/denials
      if (notif.isActioned) return;

      final now = DateTime.now();
      final newStatus = accept ? 'accepted' : 'declined';
      final requesterId = notif.actorId;
      final recipientId = notif.userId;

      // Atomically update all matching friend request notifications between these users
      await (update(notifications)
            ..where((t) =>
                t.userId.equals(recipientId) &
                t.actorId.equals(requesterId) &
                t.type.equals('friend_request')))
          .write(
        NotificationsCompanion(
          isActioned: const Value(true),
          isRead: const Value(true),
          status: Value(newStatus),
          updatedAt: Value(now),
        ),
      );

      // Update friendship table
      final existingFriendship = await (select(friendships)
            ..where((t) =>
                (t.userId.equals(requesterId) & t.friendId.equals(recipientId)) |
                (t.userId.equals(recipientId) & t.friendId.equals(requesterId))))
          .getSingleOrNull();

      if (existingFriendship != null) {
        if (existingFriendship.status == newStatus) return;
        await (update(friendships)..where((t) => t.id.equals(existingFriendship.id)))
            .write(
          FriendshipsCompanion(
            status: Value(newStatus),
            updatedAt: Value(now),
          ),
        );
      } else {
        await into(friendships).insert(
          FriendshipsCompanion.insert(
            id: 'friend_${requesterId}_$recipientId',
            userId: requesterId,
            friendId: recipientId,
            status: Value(newStatus),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      // If accepted, increment friend counts for both users
      if (accept) {
        final u1 = await (select(userProfiles)
              ..where((t) => t.id.equals(requesterId)))
            .getSingleOrNull();
        if (u1 != null) {
          await (update(userProfiles)..where((t) => t.id.equals(requesterId))).write(
            UserProfilesCompanion(
              friendCount: Value(u1.friendCount + 1),
              updatedAt: Value(now),
            ),
          );
        }

        final u2 = await (select(userProfiles)
              ..where((t) => t.id.equals(recipientId)))
            .getSingleOrNull();
        if (u2 != null) {
          await (update(userProfiles)..where((t) => t.id.equals(recipientId))).write(
            UserProfilesCompanion(
              friendCount: Value(u2.friendCount + 1),
              updatedAt: Value(now),
            ),
          );
        }
      }
    });
  }

  // ==========================================
  // DIRECT MESSAGING & CHAT
  // ==========================================

  /// Streams all messages for a given user, ordered by creation date desc.
  Stream<List<MessageRecord>> watchAllUserMessages(String userId) {
    return (select(messages)
          ..where((t) =>
              (t.senderId.equals(userId) | t.recipientId.equals(userId)) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Streams active messages for a specific conversation ordered chronologically ascending.
  Stream<List<MessageRecord>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((t) =>
              t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Streams total unread messages count for a user.
  Stream<int> watchUnreadMessageCount(String userId) {
    final count = messages.id.count();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(
        messages.recipientId.equals(userId) &
            messages.isRead.equals(false) &
            messages.isDeleted.equals(false),
      );

    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Sends a direct message with optional attachment (card or trade proposal).
  Future<MessageRecord> sendMessage({
    required String senderId,
    required String recipientId,
    required String messageText,
    String attachmentType = 'none',
    String? attachmentCardId,
    String? attachmentCardJson,
    String? attachmentTradeProposalId,
  }) async {
    final now = DateTime.now();
    final conversationId = getConversationId(senderId, recipientId);
    final messageId = 'msg_${now.microsecondsSinceEpoch}_${senderId}_$recipientId';

    final companion = MessagesCompanion.insert(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      recipientId: recipientId,
      messageText: messageText,
      attachmentType: Value(attachmentType),
      attachmentCardId: Value(attachmentCardId),
      attachmentCardJson: Value(attachmentCardJson),
      attachmentTradeProposalId: Value(attachmentTradeProposalId),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await into(messages).insert(companion);
    return (select(messages)..where((t) => t.id.equals(messageId))).getSingle();
  }

  /// Marks all incoming messages in a conversation as read.
  Future<void> markMessagesAsRead(String conversationId, String currentUserId) async {
    final now = DateTime.now();
    await (update(messages)
          ..where((t) =>
              t.conversationId.equals(conversationId) &
              t.recipientId.equals(currentUserId) &
              t.isRead.equals(false)))
        .write(
      MessagesCompanion(
        isRead: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  // ==========================================
  // TRADE PROPOSALS & TRANSFER ENGINE
  // ==========================================

  /// Streams a trade proposal by ID.
  Stream<TradeProposalRecord?> watchTradeProposal(String proposalId) {
    return (select(tradeProposals)..where((t) => t.id.equals(proposalId)))
        .watchSingleOrNull();
  }

  /// Fetches a trade proposal by ID.
  Future<TradeProposalRecord?> getTradeProposal(String proposalId) {
    return (select(tradeProposals)..where((t) => t.id.equals(proposalId)))
        .getSingleOrNull();
  }

  /// Creates a new trade proposal, writes to [TradeProposals], embeds into chat, and notifies recipient(s).
  Future<TradeProposalRecord> createTradeProposal({
    required String proposerId,
    required String receiverId,
    String? thirdParticipantId,
    bool isThreeWay = false,
    String? cardTransfersJson,
    String? fairnessSummaryJson,
    required List<String> offeredCardIds,
    required List<String> requestedCardIds,
    double proposerCashDelta = 0.0,
    double offeredTotalValue = 0.0,
    double requestedTotalValue = 0.0,
    String? note,
    String? offeredCardsSnapshotJson,
    String? requestedCardsSnapshotJson,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final seq = ++_proposalSequence;
      final proposalId = 'trade_${now.microsecondsSinceEpoch}_${proposerId}_$seq';
      final effectiveIsThreeWay =
          isThreeWay || (thirdParticipantId != null && thirdParticipantId.isNotEmpty);

      final companion = TradeProposalsCompanion.insert(
        id: proposalId,
        proposerId: proposerId,
        receiverId: receiverId,
        thirdParticipantId: Value(thirdParticipantId),
        isThreeWay: Value(effectiveIsThreeWay),
        cardTransfersJson: Value(cardTransfersJson),
        fairnessSummaryJson: Value(fairnessSummaryJson),
        offeredCardIdsJson: jsonEncode(offeredCardIds),
        requestedCardIdsJson: jsonEncode(requestedCardIds),
        offeredCardsSnapshotJson: Value(offeredCardsSnapshotJson),
        requestedCardsSnapshotJson: Value(requestedCardsSnapshotJson),
        proposerCashDelta: Value(proposerCashDelta),
        offeredTotalValue: Value(offeredTotalValue),
        requestedTotalValue: Value(requestedTotalValue),
        note: Value(note),
        status: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await into(tradeProposals).insert(companion);

      // Embed in chat with receiver
      await sendMessage(
        senderId: proposerId,
        recipientId: receiverId,
        messageText: note != null && note.isNotEmpty
            ? (isThreeWay ? '3-Way Trade Offer: $note' : 'Trade Offer: $note')
            : (isThreeWay ? 'Proposed a 3-way pod trade!' : 'Proposed a new card trade!'),
        attachmentType: 'trade_proposal',
        attachmentTradeProposalId: proposalId,
      );

      // Query proposer's profile for real username and avatar
      final proposerProfile = await (select(userProfiles)
            ..where((t) => t.id.equals(proposerId)))
          .getSingleOrNull();
      final proposerUsername = proposerProfile?.username ?? '@collector_me';
      final proposerDisplayName = proposerProfile?.displayName;
      final proposerAvatarUrl = proposerProfile?.avatarUrl;

      // Create notification for receiver (defense-in-depth: receiverId != proposerId)
      if (receiverId != proposerId) {
        await into(notifications).insert(
          NotificationsCompanion.insert(
            id: 'notif_trade_$proposalId',
            userId: receiverId,
            actorId: proposerId,
            actorUsername: proposerUsername,
            actorDisplayName: Value(proposerDisplayName),
            actorAvatarUrl: Value(proposerAvatarUrl),
            type: 'trade_proposal',
            title: isThreeWay ? 'New 3-Way Trade Offer' : 'New Trade Offer',
            body: isThreeWay
                ? 'included you in a 3-way pod trade proposal (\$${offeredTotalValue.toStringAsFixed(2)} offered)'
                : 'sent you a trade proposal (\$${offeredTotalValue.toStringAsFixed(2)} offered)',
            targetEntityId: Value(proposalId),
            targetEntityType: const Value('trade'),
            createdAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      // If 3-way trade, also embed in chat and notify third participant
      if (effectiveIsThreeWay && thirdParticipantId != null && thirdParticipantId.isNotEmpty) {
        await sendMessage(
          senderId: proposerId,
          recipientId: thirdParticipantId,
          messageText: note != null && note.isNotEmpty
              ? '3-Way Trade Offer: $note'
              : 'Proposed a 3-way pod trade!',
          attachmentType: 'trade_proposal',
          attachmentTradeProposalId: proposalId,
        );

        if (thirdParticipantId != proposerId) {
          await into(notifications).insert(
            NotificationsCompanion.insert(
              id: 'notif_trade_p3_$proposalId',
              userId: thirdParticipantId,
              actorId: proposerId,
              actorUsername: proposerUsername,
              actorDisplayName: Value(proposerDisplayName),
              actorAvatarUrl: Value(proposerAvatarUrl),
              type: 'trade_proposal',
              title: 'New 3-Way Trade Offer',
              body: 'included you in a 3-way pod trade proposal (\$${offeredTotalValue.toStringAsFixed(2)} offered)',
              targetEntityId: Value(proposalId),
              targetEntityType: const Value('trade'),
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }

      return (select(tradeProposals)..where((t) => t.id.equals(proposalId))).getSingle();
    });
  }

  /// Responds to a trade proposal.
  /// If [accept] is true and [transferCards] is true, executes the atomic trade transfer engine:
  /// Marks offered cards as traded (`isTraded = true` or updates `userId = receiverId`),
  /// transfers requested cards (`isTraded = true` or `userId = proposerId`),
  /// Explicit method alias for executing an atomic trade transfer.
  Future<void> executeTradeTransfer(
    String proposalId, {
    required String currentUserId,
  }) {
    return respondToTradeProposal(
      proposalId,
      accept: true,
      transferCards: true,
      currentUserId: currentUserId,
    );
  }

  /// Responds to a trade proposal.
  /// If [accept] is true and [transferCards] is true, executes the atomic trade transfer engine:
  /// For 3-way trades (or when `cardTransfersJson` is present), reassigns each card atomically to
  /// its designated recipient's Trade Block binder in SQLite.
  /// For legacy 2-way trades, marks offered cards as traded (`isTraded = true`, reassigns `userId = receiverId`),
  /// and requested cards (`userId = proposerId`).
  /// Updates proposal status to 'accepted', and appends confirmation messages.
  Future<void> respondToTradeProposal(
    String proposalId, {
    required bool accept,
    bool transferCards = true,
    required String currentUserId,
  }) {
    return transaction(() async {
      final proposal = await (select(tradeProposals)
            ..where((t) => t.id.equals(proposalId)))
          .getSingleOrNull();

      if (proposal == null) return;
      if (proposal.status != 'pending') return;

      final now = DateTime.now();
      final newStatus = accept ? 'accepted' : 'declined';

      await (update(tradeProposals)..where((t) => t.id.equals(proposalId))).write(
        TradeProposalsCompanion(
          status: Value(newStatus),
          isTransferred: Value(accept && transferCards),
          updatedAt: Value(now),
        ),
      );

      // Helper to resolve or create a participant's system trade block binder
      Future<String> getOrCreateTradeBlockBinder(String userId) async {
        var tradeBlock = await (select(vaultBinders)
              ..where((b) =>
                  b.userId.equals(userId) &
                  b.systemBinderType.equals('trade_block') &
                  b.isDeleted.equals(false)))
            .getSingleOrNull();

        if (tradeBlock == null) {
          final defaultBinderId = 'system_trade_block_$userId';
          await into(vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: defaultBinderId,
              name: 'Trade Block',
              collectionType: 'mtg',
              isSystemBinder: const Value(true),
              systemBinderType: const Value('trade_block'),
              userId: Value(userId),
              createdAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
          tradeBlock = await (select(vaultBinders)
                ..where((b) => b.id.equals(defaultBinderId)))
              .getSingleOrNull();
        }
        return tradeBlock?.id ?? 'system_trade_block_$userId';
      }

      // If accepted and automatic transfer requested, execute inventory updates
      if (accept && transferCards) {
        if (proposal.cardTransfersJson != null &&
            proposal.cardTransfersJson!.isNotEmpty &&
            proposal.cardTransfersJson != '[]') {
          // Atomic 3-way or structured transfers
          final List<dynamic> rawTransfers = jsonDecode(proposal.cardTransfersJson!);
          for (final raw in rawTransfers) {
            if (raw is Map) {
              final cardId = raw['cardId']?.toString();
              final recipientId = raw['recipientId']?.toString();
              if (cardId != null && cardId.isNotEmpty && recipientId != null && recipientId.isNotEmpty) {
                final recipientBinderId = await getOrCreateTradeBlockBinder(recipientId);
                await (update(vaultItems)..where((t) => t.id.equals(cardId))).write(
                  VaultItemsCompanion(
                    userId: Value(recipientId),
                    primaryBinderId: Value(recipientBinderId),
                    isTraded: const Value(true),
                    updatedAt: Value(now),
                  ),
                );
              }
            }
          }
        } else {
          // Legacy 2-party fallback
          final List<dynamic> offeredCardIds = jsonDecode(proposal.offeredCardIdsJson);
          final List<dynamic> requestedCardIds = jsonDecode(proposal.requestedCardIdsJson);

          final receiverTradeBlockBinderId =
              await getOrCreateTradeBlockBinder(proposal.receiverId);

          for (final cardId in offeredCardIds) {
            final strId = cardId.toString();
            await (update(vaultItems)..where((t) => t.id.equals(strId))).write(
              VaultItemsCompanion(
                userId: Value(proposal.receiverId),
                primaryBinderId: Value(receiverTradeBlockBinderId),
                isTraded: const Value(true),
                updatedAt: Value(now),
              ),
            );
          }

          final proposerTradeBlockBinderId =
              await getOrCreateTradeBlockBinder(proposal.proposerId);

          for (final cardId in requestedCardIds) {
            final strId = cardId.toString();
            await (update(vaultItems)..where((t) => t.id.equals(strId))).write(
              VaultItemsCompanion(
                userId: Value(proposal.proposerId),
                primaryBinderId: Value(proposerTradeBlockBinderId),
                isTraded: const Value(true),
                updatedAt: Value(now),
              ),
            );
          }
        }
      }

      // Post system confirmation into chat threads
      final confirmationText = accept
          ? (transferCards
              ? '✓ Trade accepted! Cards have been transferred in Vault inventory.'
              : '✓ Trade accepted! (Manual inventory transfer chosen).')
          : '✗ Trade proposal was declined.';

      // Determine participants to notify
      final participantsToNotify = <String>{
        proposal.proposerId,
        proposal.receiverId,
      };
      if (proposal.thirdParticipantId != null && proposal.thirdParticipantId!.isNotEmpty) {
        participantsToNotify.add(proposal.thirdParticipantId!);
      }
      participantsToNotify.remove(currentUserId);

      for (final targetId in participantsToNotify) {
        await sendMessage(
          senderId: currentUserId,
          recipientId: targetId,
          messageText: confirmationText,
          attachmentType: 'none',
        );
      }
    });
  }

  /// Cancels an active pending trade proposal in an atomic transaction.
  ///
  /// - Guards against non-existent or non-pending proposals.
  /// - Enforces that only the proposer can cancel the trade.
  /// - Atomically updates [TradeProposals] status to 'cancelled'.
  /// - Actions and updates associated notifications.
  /// - Emits a system cancellation message into the conversation thread.
  Future<void> cancelTradeProposal(
    String proposalId, {
    required String currentUserId,
  }) {
    return transaction(() async {
      final proposal = await (select(tradeProposals)
            ..where((t) => t.id.equals(proposalId)))
          .getSingleOrNull();

      if (proposal == null) return;
      if (proposal.status != 'pending') return;
      if (proposal.proposerId != currentUserId) return;

      final now = DateTime.now();

      // 1. Update proposal status to 'cancelled'
      await (update(tradeProposals)..where((t) => t.id.equals(proposalId))).write(
        TradeProposalsCompanion(
          status: const Value('cancelled'),
          updatedAt: Value(now),
        ),
      );

      // 2. Action associated trade notifications
      await (update(notifications)
            ..where((t) =>
                t.targetEntityId.equals(proposalId) &
                t.type.isIn(const ['trade_proposal', 'trade_match'])))
          .write(
        NotificationsCompanion(
          isActioned: const Value(true),
          isRead: const Value(true),
          status: const Value('cancelled'),
          updatedAt: Value(now),
        ),
      );

      // 3. Post cancellation notice into conversation thread(s)
      final participantsToNotify = <String>{
        proposal.proposerId,
        proposal.receiverId,
      };
      if (proposal.thirdParticipantId != null &&
          proposal.thirdParticipantId!.isNotEmpty) {
        participantsToNotify.add(proposal.thirdParticipantId!);
      }
      participantsToNotify.remove(currentUserId);

      for (final targetId in participantsToNotify) {
        await sendMessage(
          senderId: currentUserId,
          recipientId: targetId,
          messageText: '✗ Trade proposal was cancelled.',
          attachmentType: 'none',
        );
      }
    });
  }

  /// Submits a counter-offer for an active trade proposal in an atomic transaction.
  ///
  /// - Transitions [priorProposalId] status to 'countered'.
  /// - Actions prior notifications.
  /// - Inserts a new counter [TradeProposals] record with status 'pending'.
  /// - Embeds the counter-offer proposal into the chat thread.
  /// - Creates a new notification for the counterparty.
  Future<TradeProposalRecord> counterTradeProposal(
    String priorProposalId, {
    required String proposerId,
    required String receiverId,
    String? thirdParticipantId,
    bool isThreeWay = false,
    String? cardTransfersJson,
    String? fairnessSummaryJson,
    required List<String> offeredCardIds,
    required List<String> requestedCardIds,
    double proposerCashDelta = 0.0,
    double offeredTotalValue = 0.0,
    double requestedTotalValue = 0.0,
    String? note,
    String? offeredCardsSnapshotJson,
    String? requestedCardsSnapshotJson,
  }) {
    return transaction(() async {
      final prior = await (select(tradeProposals)
            ..where((t) => t.id.equals(priorProposalId)))
          .getSingleOrNull();

      if (prior == null) {
        throw ArgumentError('Prior proposal $priorProposalId does not exist.');
      }
      if (prior.status != 'pending') {
        throw StateError('Cannot counter trade proposal with status: ${prior.status}');
      }

      final now = DateTime.now();

      // 1. Mark prior proposal as countered
      await (update(tradeProposals)..where((t) => t.id.equals(priorProposalId))).write(
        TradeProposalsCompanion(
          status: const Value('countered'),
          updatedAt: Value(now),
        ),
      );

      // 2. Action previous notifications
      await (update(notifications)
            ..where((t) =>
                t.targetEntityId.equals(priorProposalId) &
                t.type.isIn(const ['trade_proposal', 'trade_match'])))
          .write(
        NotificationsCompanion(
          isActioned: const Value(true),
          isRead: const Value(true),
          status: const Value('countered'),
          updatedAt: Value(now),
        ),
      );

      // 3. Create new counter-proposal
      final seq = ++_proposalSequence;
      final newProposalId = 'trade_${now.microsecondsSinceEpoch}_${proposerId}_$seq';
      final effectiveIsThreeWay =
          isThreeWay || (thirdParticipantId != null && thirdParticipantId.isNotEmpty);

      final companion = TradeProposalsCompanion.insert(
        id: newProposalId,
        proposerId: proposerId,
        receiverId: receiverId,
        thirdParticipantId: Value(thirdParticipantId),
        isThreeWay: Value(effectiveIsThreeWay),
        cardTransfersJson: Value(cardTransfersJson),
        fairnessSummaryJson: Value(fairnessSummaryJson),
        offeredCardIdsJson: jsonEncode(offeredCardIds),
        requestedCardIdsJson: jsonEncode(requestedCardIds),
        offeredCardsSnapshotJson: Value(offeredCardsSnapshotJson),
        requestedCardsSnapshotJson: Value(requestedCardsSnapshotJson),
        proposerCashDelta: Value(proposerCashDelta),
        offeredTotalValue: Value(offeredTotalValue),
        requestedTotalValue: Value(requestedTotalValue),
        note: Value(note),
        status: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await into(tradeProposals).insert(companion);

      // 4. Embed in chat
      await sendMessage(
        senderId: proposerId,
        recipientId: receiverId,
        messageText: note != null && note.isNotEmpty
            ? (effectiveIsThreeWay ? '3-Way Counter Offer: $note' : 'Counter Offer: $note')
            : (effectiveIsThreeWay ? 'Submitted a 3-way counter-offer!' : 'Submitted a counter-offer!'),
        attachmentType: 'trade_proposal',
        attachmentTradeProposalId: newProposalId,
      );

      // 5. Query proposer profile and notify recipient
      final proposerProfile = await (select(userProfiles)
            ..where((t) => t.id.equals(proposerId)))
          .getSingleOrNull();
      final proposerUsername = proposerProfile?.username ?? '@collector_me';
      final proposerDisplayName = proposerProfile?.displayName;
      final proposerAvatarUrl = proposerProfile?.avatarUrl;

      if (receiverId != proposerId) {
        await into(notifications).insert(
          NotificationsCompanion.insert(
            id: 'notif_trade_$newProposalId',
            userId: receiverId,
            actorId: proposerId,
            actorUsername: proposerUsername,
            actorDisplayName: Value(proposerDisplayName),
            actorAvatarUrl: Value(proposerAvatarUrl),
            type: 'trade_proposal',
            title: effectiveIsThreeWay ? 'New 3-Way Counter Offer' : 'New Counter Trade Offer',
            body: effectiveIsThreeWay
                ? 'included you in a counter-offer (\$${offeredTotalValue.toStringAsFixed(2)} offered)'
                : 'sent you a counter-offer (\$${offeredTotalValue.toStringAsFixed(2)} offered)',
            targetEntityId: Value(newProposalId),
            targetEntityType: const Value('trade'),
            createdAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      // If 3-way, also notify third participant
      if (effectiveIsThreeWay && thirdParticipantId != null && thirdParticipantId.isNotEmpty) {
        await sendMessage(
          senderId: proposerId,
          recipientId: thirdParticipantId,
          messageText: note != null && note.isNotEmpty
              ? '3-Way Counter Offer: $note'
              : 'Submitted a 3-way counter-offer!',
          attachmentType: 'trade_proposal',
          attachmentTradeProposalId: newProposalId,
        );

        if (thirdParticipantId != proposerId) {
          await into(notifications).insert(
            NotificationsCompanion.insert(
              id: 'notif_trade_p3_$newProposalId',
              userId: thirdParticipantId,
              actorId: proposerId,
              actorUsername: proposerUsername,
              actorDisplayName: Value(proposerDisplayName),
              actorAvatarUrl: Value(proposerAvatarUrl),
              type: 'trade_proposal',
              title: 'New 3-Way Counter Offer',
              body: 'included you in a counter-offer (\$${offeredTotalValue.toStringAsFixed(2)} offered)',
              targetEntityId: Value(newProposalId),
              targetEntityType: const Value('trade'),
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }

      return (select(tradeProposals)..where((t) => t.id.equals(newProposalId))).getSingle();
    });
  }
}

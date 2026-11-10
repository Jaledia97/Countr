import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../data/daos/inbox_dao.dart';

class ChatThreadSummary {
  final String conversationId;
  final UserProfile contactUser;
  final MessageRecord lastMessage;
  final int unreadCount;
  final bool hasActiveTrade;
  final double? tradeValue;

  const ChatThreadSummary({
    required this.conversationId,
    required this.contactUser,
    required this.lastMessage,
    this.unreadCount = 0,
    this.hasActiveTrade = false,
    this.tradeValue,
  });
}

/// Provider exposing [InboxDao].
final inboxDaoProvider = Provider<InboxDao>((ref) {
  return ref.watch(appDatabaseProvider).inboxDao;
});

/// Streams unread notification count for current user.
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(inboxDaoProvider);
  final userId = ref.watch(currentUserIdProvider);
  return dao.watchUnreadNotificationCount(userId);
});

/// Streams unread direct message count for current user.
final unreadMessageCountProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(inboxDaoProvider);
  final userId = ref.watch(currentUserIdProvider);
  return dao.watchUnreadMessageCount(userId);
});

/// Total combined unread count (Notifications + Messages) for the top AppBar bell badge.
final totalInboxUnreadCountProvider = Provider<int>((ref) {
  final notifCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
  final msgCount = ref.watch(unreadMessageCountProvider).valueOrNull ?? 0;
  return notifCount + msgCount;
});

/// Selected filter chip on Notifications Tab ('all', 'requests', 'trades', 'activity').
final notificationsFilterProvider = StateProvider<String>((ref) => 'all');

/// Streams notifications for current user with active category filter applied.
final notificationsStreamProvider = StreamProvider<List<NotificationRecord>>((ref) {
  final dao = ref.watch(inboxDaoProvider);
  final userId = ref.watch(currentUserIdProvider);
  final filter = ref.watch(notificationsFilterProvider);
  return dao.watchNotifications(userId, filter: filter);
});

/// Streams chat threads summaries for Messages Tab.
final chatThreadsStreamProvider = StreamProvider<List<ChatThreadSummary>>((ref) {
  final dao = ref.watch(inboxDaoProvider);
  final db = ref.watch(appDatabaseProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  return dao.watchAllUserMessages(currentUserId).asyncMap((allMsgs) async {
    // Group messages by conversationId, keeping the latest message per conversation
    final convMap = <String, MessageRecord>{};
    final unreadMap = <String, int>{};

    for (final msg in allMsgs) {
      if (!convMap.containsKey(msg.conversationId)) {
        convMap[msg.conversationId] = msg;
      }
      if (!msg.isRead && msg.recipientId == currentUserId) {
        unreadMap[msg.conversationId] = (unreadMap[msg.conversationId] ?? 0) + 1;
      }
    }

    final threads = <ChatThreadSummary>[];

    for (final entry in convMap.entries) {
      final msg = entry.value;
      final contactId = msg.senderId == currentUserId ? msg.recipientId : msg.senderId;

      final contact = await db.userProfileDao.getProfile(contactId) ??
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

      // Check for active trade proposal between users
      final activeTrades = await (db.select(db.tradeProposals)
            ..where((t) =>
                ((t.proposerId.equals(currentUserId) & t.receiverId.equals(contactId)) |
                    (t.proposerId.equals(contactId) & t.receiverId.equals(currentUserId))) &
                t.status.equals('pending') &
                t.isDeleted.equals(false)))
          .get();

      final hasActiveTrade = activeTrades.isNotEmpty;
      final tradeVal = hasActiveTrade ? activeTrades.first.offeredTotalValue : null;

      threads.add(ChatThreadSummary(
        conversationId: entry.key,
        contactUser: contact,
        lastMessage: msg,
        unreadCount: unreadMap[entry.key] ?? 0,
        hasActiveTrade: hasActiveTrade,
        tradeValue: tradeVal,
      ));
    }

    threads.sort((a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt));
    return threads;
  });
});

/// Streams messages for a single conversation thread.
final chatMessagesStreamProvider =
    StreamProvider.family<List<MessageRecord>, String>((ref, conversationId) {
  final dao = ref.watch(inboxDaoProvider);
  return dao.watchMessages(conversationId);
});

/// Streams a specific trade proposal by ID.
final tradeProposalStreamProvider =
    StreamProvider.family<TradeProposalRecord?, String>((ref, proposalId) {
  final dao = ref.watch(inboxDaoProvider);
  return dao.watchTradeProposal(proposalId);
});

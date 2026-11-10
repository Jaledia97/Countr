import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/daos/inbox_dao.dart';
import '../providers/inbox_providers.dart';
import '../widgets/inbox_user_picker_modal.dart';
import '../../../trades/presentation/screens/trade_modal_sheet.dart';
import '../../../vault/presentation/providers/vault_providers.dart';

/// 2-Tab Inbox Hub Screen (/inbox)
/// Displays:
/// - Tab 0: Notifications (Filter chips: All, Friend Requests, Trades, Activity; interactive accept/decline/review)
/// - Tab 1: Messages (Chat threads list with active trade badges, unread badges)
class InboxHubScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  final int? initialIndex;

  const InboxHubScreen({
    super.key,
    this.initialTab,
    this.initialIndex,
  });

  @override
  ConsumerState<InboxHubScreen> createState() => _InboxHubScreenState();
}

class _InboxHubScreenState extends ConsumerState<InboxHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOpeningUserPicker = false;

  @override
  void initState() {
    super.initState();
    final defaultIndex = widget.initialIndex ??
        (widget.initialTab == 'messages' ? 1 : 0);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: defaultIndex,
    );
    _tabController.addListener(_handleTabChanged);

    if (widget.initialTab == null && widget.initialIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final currentUserId = ref.read(currentUserIdProvider);
        final smartIndex = await ref
            .read(inboxDaoProvider)
            .getSmartInboxInitialIndex(currentUserId);
        if (mounted && smartIndex != _tabController.index) {
          _tabController.animateTo(smartIndex);
        }
      });
    }
  }

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleOpenCompose() async {
    if (_isOpeningUserPicker) return;
    _isOpeningUserPicker = true;
    try {
      await InboxUserPickerModal.show(context);
    } finally {
      if (mounted) {
        _isOpeningUserPicker = false;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final unreadNotifCount =
        ref.watch(unreadNotificationCountProvider).value ?? 0;
    final unreadMsgCount =
        ref.watch(unreadMessageCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Inbox', style: AppTypography.brandHeader),
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.sizeOf(context).width;
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final useCompact =
                  screenWidth < 360 || (textScale > 1.2 && screenWidth < 500);

              if (useCompact) {
                return IconButton(
                  key: const Key('inbox_mark_all_read_button'),
                  icon: const Icon(Icons.done_all_rounded, size: 22),
                  tooltip: 'Mark all read',
                  color: AppColors.accentCyan,
                  onPressed: () async {
                    await ref
                        .read(inboxDaoProvider)
                        .markAllNotificationsAsRead(currentUserId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications marked as read'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                );
              }

              return TextButton.icon(
                key: const Key('inbox_mark_all_read_button'),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentCyan,
                ),
                onPressed: () async {
                  await ref
                      .read(inboxDaoProvider)
                      .markAllNotificationsAsRead(currentUserId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          indicatorWeight: 3,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.heading2.copyWith(fontSize: 14),
          unselectedLabelStyle: AppTypography.body.copyWith(fontSize: 14),
          tabs: [
            Tab(
              key: const Key('inbox_tab_notifications'),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Notifications'),
                    if (unreadNotifCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadNotifCount',
                          style: const TextStyle(
                            color: AppColors.background,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Tab(
              key: const Key('inbox_tab_messages'),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Messages'),
                    if (unreadMsgCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadMsgCount',
                          style: const TextStyle(
                            color: AppColors.background,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _NotificationsTabView(),
          _MessagesTabView(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              key: const Key('inbox_compose_button'),
              backgroundColor: AppColors.accentCyan,
              foregroundColor: AppColors.background,
              onPressed: _handleOpenCompose,
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }
}

/// Tab 1: Notifications Tab View
class _NotificationsTabView extends ConsumerWidget {
  const _NotificationsTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final activeFilter = ref.watch(notificationsFilterProvider);
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Column(
      children: [
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildFilterChip(
                context,
                ref,
                key: const Key('inbox_filter_all'),
                label: 'All',
                filterValue: 'all',
                isActive: activeFilter == 'all',
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                ref,
                key: const Key('inbox_filter_friend_requests'),
                label: 'Friend Requests',
                filterValue: 'requests',
                isActive: activeFilter == 'requests',
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                ref,
                key: const Key('inbox_filter_trades'),
                label: 'Trades',
                filterValue: 'trades',
                isActive: activeFilter == 'trades',
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                ref,
                key: const Key('inbox_filter_activity'),
                label: 'Activity',
                filterValue: 'activity',
                isActive: activeFilter == 'activity',
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.surfaceBorder),

        // Notifications List
        Expanded(
          child: notificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return Center(
                  key: const Key('inbox_notifications_empty'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications in this tab',
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: AppColors.surfaceBorder),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _NotificationCard(
                    key: Key('notif_card_${notif.id}'),
                    notification: notif,
                    currentUserId: currentUserId,
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error loading notifications: $err',
                style: const TextStyle(color: AppColors.accentRose),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required String label,
    required String filterValue,
    required bool isActive,
  }) {
    return FilterChip(
      key: key,
      selected: isActive,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? AppColors.accentCyan : AppColors.textSecondary,
      ),
      backgroundColor: AppColors.surfaceRaised,
      selectedColor: AppColors.accentCyan.withValues(alpha: 0.15),
      checkmarkColor: AppColors.accentCyan,
      side: BorderSide(
        color: isActive ? AppColors.accentCyan : AppColors.surfaceBorder,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        ref.read(notificationsFilterProvider.notifier).state = filterValue;
      },
    );
  }
}

/// Notification card widget handling all notification types
class _NotificationCard extends ConsumerWidget {
  final NotificationRecord notification;
  final String currentUserId;

  const _NotificationCard({
    super.key,
    required this.notification,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = !notification.isRead;
    final initials = (notification.actorDisplayName ?? notification.actorUsername)
        .replaceAll('@', '')
        .trim();
    final avatarLetter = initials.isNotEmpty ? initials[0].toUpperCase() : 'U';

    return InkWell(
      onTap: () {
        if (isUnread) {
          ref.read(inboxDaoProvider).markNotificationAsRead(notification.id);
        }
        _handleTap(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.surfaceRaised.withValues(alpha: 0.6)
              : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Actor Avatar
            GestureDetector(
              onTap: () => context.push('/profile/${notification.actorId}'),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.accentViolet, AppColors.accentCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceRaised,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: notification.actorUsername,
                          style: AppTypography.heading2.copyWith(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: notification.body,
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),

                  // Specialized Action Buttons
                  if (notification.type == 'friend_request') ...[
                    const SizedBox(height: 10),
                    if (notification.isActioned ||
                        notification.status.toLowerCase() == 'accepted' ||
                        notification.status.toLowerCase() == 'declined') ...[
                      if (notification.status.toLowerCase() == 'accepted')
                        Container(
                          key: Key('notif_status_accepted_${notification.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Accepted',
                                style: TextStyle(
                                  color: AppColors.accentEmerald,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          key: Key('notif_status_declined_${notification.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.remove_circle_outline_rounded, color: AppColors.textMuted, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Declined',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ElevatedButton(
                            key: Key('notif_approve_fr_${notification.id}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentCyan,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              minimumSize: const Size(54, 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () async {
                              await ref
                                  .read(inboxDaoProvider)
                                  .respondToFriendRequest(
                                    notificationId: notification.id,
                                    accept: true,
                                  );
                            },
                            child: const Text(
                              'Approve',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          OutlinedButton(
                            key: Key('notif_deny_fr_${notification.id}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(
                                color: AppColors.surfaceBorder,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: const Size(54, 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () async {
                              await ref
                                  .read(inboxDaoProvider)
                                  .respondToFriendRequest(
                                    notificationId: notification.id,
                                    accept: false,
                                  );
                            },
                            child: const Text(
                              'Deny',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else if (notification.type == 'trade_proposal') ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      key: Key('notif_review_trade_${notification.id}'),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text(
                        'Review Offer',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAmber,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: const Size(100, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () {
                        final convId = InboxDao.getConversationId(
                          currentUserId,
                          notification.actorId,
                        );
                        context.push(
                          '/inbox/chat/$convId?contactId=${notification.actorId}',
                        );
                      },
                    ),
                  ] else if (notification.type == 'trade_match') ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      key: Key('notif_propose_trade_${notification.id}'),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text(
                        'Propose Trade',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: const Size(100, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () {
                        if (isUnread) {
                          ref.read(inboxDaoProvider).markNotificationAsRead(notification.id);
                        }
                        _handleTradeMatchTap(context, ref);
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Unread Dot
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentCyan,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    if (notification.type == 'trade_match' || notification.targetEntityType == 'trade_match') {
      _handleTradeMatchTap(context, ref);
    } else if (notification.type == 'trade_proposal') {
      final convId = InboxDao.getConversationId(currentUserId, notification.actorId);
      context.push('/inbox/chat/$convId?contactId=${notification.actorId}');
    } else if (notification.type == 'friend_request' || notification.targetEntityType == 'profile') {
      context.push('/profile/${notification.actorId}');
    } else if (notification.type == 'deck_upvote' || notification.targetEntityType == 'deck') {
      final deckId = notification.targetEntityId ?? '';
      if (deckId.isNotEmpty) {
        context.push('/explore/deck/$deckId');
      } else {
        context.push('/explore');
      }
    } else if (notification.type == 'mention' ||
        notification.type == 'milestone' ||
        notification.type == 'post_like' ||
        notification.type == 'post_comment' ||
        notification.targetEntityType == 'post') {
      final postId = notification.targetEntityId ?? '';
      if (postId.isNotEmpty) {
        final openComments = notification.type == 'mention' || notification.type == 'post_comment';
        context.push('/post/$postId?comments=$openComments');
      } else {
        context.push('/feed');
      }
    } else {
      context.push('/profile/${notification.actorId}');
    }
  }

  Future<void> _handleTradeMatchTap(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final myProfile = await db.userProfileDao.getProfile(currentUserId);
    final partnerProfile =
        await db.userProfileDao.getProfile(notification.actorId);

    final currentUser = myProfile ??
        UserProfile(
          id: currentUserId,
          username: '@collector_me',
          displayName: 'Me',
          accountType: 'individual',
          isVerifiedBusiness: false,
          friendCount: 0,
          repCount: 0,
          tier: 'collector',
          syncStatus: 'synced',
          collectionVisibility: 'public',
          isDeleted: false,
          createdAt: DateTime.now(),
        );

    final partner = partnerProfile ??
        UserProfile(
          id: notification.actorId,
          username: notification.actorUsername,
          displayName:
              notification.actorDisplayName ?? notification.actorUsername,
          avatarUrl: notification.actorAvatarUrl,
          accountType: 'individual',
          isVerifiedBusiness: false,
          friendCount: 0,
          repCount: 0,
          tier: 'collector',
          syncStatus: 'synced',
          collectionVisibility: 'public',
          isDeleted: false,
          createdAt: DateTime.now(),
        );

    VaultItem? matchedCard;
    if (notification.targetEntityId != null) {
      matchedCard = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals(notification.targetEntityId!)))
          .getSingleOrNull();
    }

    if (!context.mounted) return;
    TradeModalSheet.show(
      context,
      currentUser: currentUser,
      partnerProfile: partner,
      initialPartnerCard: matchedCard,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Tab 2: Messages Tab View
class _MessagesTabView extends ConsumerWidget {
  const _MessagesTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsStreamProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return threadsAsync.when(
      data: (threads) {
        if (threads.isEmpty) {
          return Center(
            key: const Key('inbox_messages_empty'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: 48,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No conversations yet',
                  style: AppTypography.bodySecondary.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: threads.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: AppColors.surfaceBorder),
          itemBuilder: (context, index) {
            final thread = threads[index];
            final contact = thread.contactUser;
            final initials = (contact.displayName.isNotEmpty
                    ? contact.displayName
                    : contact.username)
                .replaceAll('@', '');
            final avatarLetter =
                initials.isNotEmpty ? initials[0].toUpperCase() : 'U';

            return InkWell(
              key: Key('chat_thread_tile_${thread.conversationId}'),
              onTap: () async {
                if (thread.unreadCount > 0) {
                  await ref.read(inboxDaoProvider).markMessagesAsRead(
                        thread.conversationId,
                        currentUserId,
                      );
                }
                if (context.mounted) {
                  context.push(
                    '/inbox/chat/${thread.conversationId}?contactId=${contact.id}',
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentViolet,
                            AppColors.accentCyan,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceRaised,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          avatarLetter,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  contact.displayName,
                                  style: AppTypography.heading2.copyWith(
                                    fontSize: 15,
                                    fontWeight: thread.unreadCount > 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  contact.username,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Active Trade Badge if proposal exists
                          if (thread.hasActiveTrade ||
                              thread.lastMessage.attachmentType == 'trade_proposal') ...[
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                key: Key(
                                  'chat_thread_active_trade_badge_${thread.conversationId}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentAmber.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.accentAmber.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '[Trade Proposal]',
                                      style: TextStyle(
                                        color: AppColors.accentAmber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (thread.tradeValue != null &&
                                        thread.tradeValue! > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '• \$${thread.tradeValue!.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppColors.accentAmber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Last message snippet
                          Text(
                            thread.lastMessage.messageText,
                            style: AppTypography.bodySecondary.copyWith(
                              fontSize: 13,
                              color: thread.unreadCount > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: thread.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Timestamp and Unread Pill
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatRelativeTime(thread.lastMessage.createdAt),
                              style: AppTypography.caption.copyWith(
                                color: thread.unreadCount > 0
                                    ? AppColors.accentCyan
                                    : AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: thread.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (thread.unreadCount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  key: Key(
                                    'chat_thread_unread_dot_${thread.conversationId}',
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accentCyan,
                                  ),
                                ),
                                if (thread.unreadCount > 1) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${thread.unreadCount}',
                                    style: const TextStyle(
                                      color: AppColors.accentCyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accentCyan),
      ),
      error: (err, _) => Center(
        child: Text(
          'Error loading chats: $err',
          style: const TextStyle(color: AppColors.accentRose),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      if (now.day == time.day && now.month == time.month && now.year == time.year) {
        return '${diff.inHours}h ago';
      } else {
        return 'Yesterday';
      }
    }
    if (diff.inDays == 1 || (diff.inDays < 2 && now.day != time.day)) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}';
  }
}

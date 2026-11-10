import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../../vault/presentation/widgets/card_detail_sheet.dart';
import '../../data/daos/friends_dao.dart';
import '../../data/daos/inbox_dao.dart';
import '../providers/friends_providers.dart';
import '../providers/group_game_providers.dart';
import '../widgets/group_game_card.dart';

/// Friends & Groups Hub Screen (/friends)
/// Features:
/// - Strictly 2 Tabs: Friends (3-section layout + Find Friends) and Groups (EDH Pods)
/// - TabController length: 2, TabBar has Key('friends_hub_tab_bar')
class FriendsHubScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  final String? userId;

  const FriendsHubScreen({super.key, this.initialTab, this.userId});

  @override
  ConsumerState<FriendsHubScreen> createState() => _FriendsHubScreenState();
}

class _FriendsHubScreenState extends ConsumerState<FriendsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'groups' ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Friends & Groups', style: AppTypography.brandHeader),
        bottom: TabBar(
          key: const Key('friends_hub_tab_bar'),
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          indicatorWeight: 3,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.heading2.copyWith(fontSize: 14),
          unselectedLabelStyle: AppTypography.body.copyWith(fontSize: 14),
          tabs: const [
            Tab(
              key: Key('friends_tab_friends'),
              text: 'Friends',
            ),
            Tab(
              key: Key('friends_tab_groups'),
              text: 'Groups',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsTabView(
            initialTab: widget.initialTab,
            userId: widget.userId,
          ),
          const _GroupsTabView(),
        ],
      ),
    );
  }
}

/// Tab 2: Groups Tab View for EDH Pods & Waitlists
class _GroupsTabView extends ConsumerWidget {
  const _GroupsTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(groupGamesProvider);

    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text('No Active Pods', style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text(
              'No active group games reported at nearby stores.',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: games.length,
      itemBuilder: (context, index) {
        return GroupGameCard(game: games[index]);
      },
    );
  }
}

/// Consolidated Friends Tab View hosting:
/// 1. Top: Friend Requests (inline 2-3 items + See More)
/// 2. Middle: Friends List (searchable list of accepted friends)
/// 3. Bottom: Sent Requests (inline 2-3 items + See More + Cancel)
/// 4. Bottom Discovery: Integrated Find Friends search
class _FriendsTabView extends ConsumerStatefulWidget {
  final String? initialTab;
  final String? userId;

  const _FriendsTabView({this.initialTab, this.userId});

  @override
  ConsumerState<_FriendsTabView> createState() => _FriendsTabViewState();
}

class _FriendsTabViewState extends ConsumerState<_FriendsTabView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _findController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _findDebounce;
  bool _expandIncoming = false;
  bool _expandOutgoing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          ref.read(friendsSearchQueryProvider.notifier).state =
              _searchController.text.trim();
        }
      });
    });

    _findController.addListener(() {
      _findDebounce?.cancel();
      _findDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          ref.read(findFriendsQueryProvider.notifier).state =
              _findController.text.trim();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _findDebounce?.cancel();
    _searchController.dispose();
    _findController.dispose();
    super.dispose();
  }

  void _showTradeBlockModal(BuildContext context, UserProfile friend) {
    final db = ref.read(appDatabaseProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${friend.displayName}\'s Trade Block',
                          style: AppTypography.heading2.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Cards available for trade',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<VaultItem>>(
                  future: (db.select(db.vaultItems)
                        ..where((t) =>
                            t.userId.equals(friend.id) &
                            t.isDeleted.equals(false)))
                      .get(),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'No cards currently in Trade Block',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return GridView.builder(
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return InkWell(
                          onTap: () {
                            CardDetailSheet.show(context, item.id);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.accentCyan.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (item.imageUrl.isNotEmpty)
                                  Image.network(
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 24,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  )
                                else
                                  const Center(
                                    child: Icon(
                                      Icons.style_rounded,
                                      size: 24,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                PositionBottom(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    color: Colors.black.withValues(alpha: 0.75),
                                    child: Text(
                                      '\$${item.currentMarketPrice.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.accentCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final targetUserId = widget.userId ?? currentUserId;
    final friendsAsync = ref.watch(userFriendsStreamProvider(targetUserId));
    final incomingRequestsAsync =
        ref.watch(incomingFriendRequestsStreamProvider);
    final outgoingRequestsAsync =
        ref.watch(outgoingFriendRequestsStreamProvider);
    final searchResultsAsync = ref.watch(findFriendsSearchResultsProvider);
    final searchQuery = ref.watch(friendsSearchQueryProvider);
    final db = ref.watch(appDatabaseProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // =====================================================================
        // SECTION 1: TOP — FRIEND REQUESTS (Incoming)
        // =====================================================================
        KeyedSubtree(
          key: const Key('friends_tab_requests'),
          child: Container(
            key: const Key('friend_requests_section'),
            child: incomingRequestsAsync.when(
              data: (incoming) {
                if (incoming.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No pending requests',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final displayed =
                    _expandIncoming ? incoming : incoming.take(3).toList();
                final remaining = incoming.length - 3;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Friend Requests (${incoming.length})',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.accentAmber,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (incoming.length > 3)
                            TextButton(
                              onPressed: () => setState(
                                () => _expandIncoming = !_expandIncoming,
                              ),
                              child: Text(
                                _expandIncoming
                                    ? 'Show Less'
                                    : (remaining > 0
                                        ? 'See More ($remaining)'
                                        : 'See More'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...displayed.map((req) => _buildIncomingRequestItem(
                          context,
                          db,
                          req,
                          currentUserId,
                        )),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.surfaceBorder),
                    const SizedBox(height: 8),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),

        // =====================================================================
        // SECTION 2: MIDDLE — FRIENDS LIST (Searchable Accepted Friends)
        // =====================================================================
        KeyedSubtree(
          key: const Key('friends_tab_my_friends'),
          child: Container(
            key: const Key('friends_list_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: TextField(
                    key: const Key('friends_search_input'),
                    controller: _searchController,
                    style: AppTypography.body.copyWith(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Filter your friends...',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.accentCyan,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),

              friendsAsync.when(
                data: (friends) {
                  if (friends.isEmpty) {
                    if (searchQuery.isNotEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No friends match your search',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      );
                    }
                    return Center(
                      key: const Key('my_friends_empty'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "You don't have any friends yet",
                              style: AppTypography.bodySecondary.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AppColors.surfaceBorder,
                    ),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return _buildFriendCard(context, friend, currentUserId);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error loading friends: $err',
                    style: const TextStyle(color: AppColors.accentRose),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),

        // =====================================================================
        // SECTION 3: BOTTOM — SENT REQUESTS (Pending Outgoing)
        // =====================================================================
        Container(
          key: const Key('sent_requests_section'),
          child: outgoingRequestsAsync.when(
            data: (outgoing) {
              if (outgoing.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.outbox_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No sent requests',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final displayed =
                  _expandOutgoing ? outgoing : outgoing.take(3).toList();
              final remaining = outgoing.length - 3;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Sent Requests (${outgoing.length})',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (outgoing.length > 3)
                          TextButton(
                            onPressed: () => setState(
                              () => _expandOutgoing = !_expandOutgoing,
                            ),
                            child: Text(
                              _expandOutgoing
                                  ? 'Show Less'
                                  : (remaining > 0
                                      ? 'See More ($remaining)'
                                      : 'See More'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...displayed.map((req) => _buildOutgoingRequestItem(
                        context,
                        db,
                        req,
                        currentUserId,
                      )),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  const SizedBox(height: 12),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),

        // =====================================================================
        // SECTION 4: INTEGRATED FIND FRIENDS (User Discovery)
        // =====================================================================
        _buildFindFriendsSection(context, searchResultsAsync, currentUserId),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestItem(
    BuildContext context,
    AppDatabase db,
    FriendshipRecord req,
    String currentUserId,
  ) {
    return FutureBuilder<UserProfile?>(
      future: db.userProfileDao.getProfile(req.userId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ?? req.userId;
        final handle = profile?.username ?? '@${req.userId}';

        final avatarWidget = Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentAmber,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: AppColors.background,
              fontWeight: FontWeight.w800,
            ),
          ),
        );

        final nameColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: AppTypography.heading2.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              handle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        final approveButton = ElevatedButton(
          key: Key('friend_request_accept_${req.id}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.background,
            minimumSize: const Size(60, 32),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () async {
            await ref.read(friendsDaoProvider).respondToFriendRequest(
                  currentUserId,
                  req.userId,
                  accept: true,
                );
          },
          child: KeyedSubtree(
            key: Key('friend_request_approve_${req.id}'),
            child: KeyedSubtree(
              key: Key('friend_request_approve_${req.userId}'),
              child: KeyedSubtree(
                key: Key('friend_request_accept_${req.userId}'),
                child: KeyedSubtree(
                  key: const Key('friend_request_approve_button'),
                  child: const Text(
                    'Approve',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final denyButton = OutlinedButton(
          key: Key('friend_request_decline_${req.id}'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.surfaceBorder),
            minimumSize: const Size(60, 32),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () async {
            await ref.read(friendsDaoProvider).respondToFriendRequest(
                  currentUserId,
                  req.userId,
                  accept: false,
                );
          },
          child: KeyedSubtree(
            key: Key('friend_request_decline_${req.userId}'),
            child: KeyedSubtree(
              key: Key('friend_request_deny_${req.id}'),
              child: KeyedSubtree(
                key: Key('friend_request_deny_${req.userId}'),
                child: KeyedSubtree(
                  key: const Key('friend_request_deny_button'),
                  child: const Text(
                    'Deny',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final shouldReflow = constraints.maxWidth <
                  (280 * textScale).clamp(280.0, 560.0);

              if (shouldReflow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        avatarWidget,
                        const SizedBox(width: 10),
                        Expanded(child: nameColumn),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        approveButton,
                        denyButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  avatarWidget,
                  const SizedBox(width: 10),
                  Expanded(child: nameColumn),
                  approveButton,
                  const SizedBox(width: 6),
                  denyButton,
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOutgoingRequestItem(
    BuildContext context,
    AppDatabase db,
    FriendshipRecord req,
    String currentUserId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Request to ${req.friendId}',
              style: AppTypography.body.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: Key('friend_request_cancel_${req.id}'),
            onPressed: () async {
              await ref.read(friendsDaoProvider).cancelFriendRequest(
                    currentUserId,
                    req.friendId,
                  );
            },
            child: KeyedSubtree(
              key: Key('friend_request_cancel_${req.friendId}'),
              child: KeyedSubtree(
                key: Key('sent_request_cancel_${req.id}'),
                child: KeyedSubtree(
                  key: Key('sent_request_cancel_${req.friendId}'),
                  child: KeyedSubtree(
                    key: const Key('sent_request_cancel_button'),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.accentRose,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(
    BuildContext context,
    UserProfile friend,
    String currentUserId,
  ) {
    final initials = (friend.displayName.isNotEmpty
            ? friend.displayName
            : friend.username)
        .replaceAll('@', '');
    final avatarLetter =
        initials.isNotEmpty ? initials[0].toUpperCase() : 'U';

    return Container(
      key: Key('friend_card_${friend.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('friend_row_${friend.id}'),
            onTap: () => context.push('/profile/${friend.id}'),
            borderRadius: BorderRadius.circular(8),
            child: KeyedSubtree(
              key: Key('friend_item_${friend.id}'),
              child: Row(
                children: [
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
                      ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.displayName,
                          style: AppTypography.heading2.copyWith(
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          friend.username,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${friend.friendCount} Friends',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickAction(
                context,
                key: Key('friend_action_profile_${friend.id}'),
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onTap: () => context.push('/profile/${friend.id}'),
              ),
              const SizedBox(width: 6),
              _buildQuickAction(
                context,
                key: Key('friend_action_trade_block_${friend.id}'),
                icon: Icons.grid_view_rounded,
                label: 'Trade Block',
                onTap: () => _showTradeBlockModal(context, friend),
              ),
              const SizedBox(width: 6),
              _buildQuickAction(
                context,
                key: Key('friend_action_propose_trade_${friend.id}'),
                icon: Icons.swap_horiz_rounded,
                label: 'Propose Trade',
                color: AppColors.accentAmber,
                onTap: () {
                  final convId = InboxDao.getConversationId(
                    currentUserId,
                    friend.id,
                  );
                  context.push(
                    '/inbox/chat/$convId?contactId=${friend.id}',
                  );
                },
              ),
              const SizedBox(width: 6),
              _buildQuickAction(
                context,
                key: Key('friend_action_message_${friend.id}'),
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Message',
                color: AppColors.accentCyan,
                onTap: () {
                  final convId = InboxDao.getConversationId(
                    currentUserId,
                    friend.id,
                  );
                  context.push(
                    '/inbox/chat/$convId?contactId=${friend.id}',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFindFriendsSection(
    BuildContext context,
    AsyncValue<List<UserProfileWithStatus>> searchResultsAsync,
    String currentUserId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FIND FRIENDS',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: TextField(
                  key: const Key('find_friends_search_input'),
                  controller: _findController,
                  style: AppTypography.body.copyWith(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search by @handle or name...',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.person_search_rounded,
                      size: 20,
                      color: AppColors.accentCyan,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        searchResultsAsync.when(
          data: (rawResults) {
            final results = rawResults
                .where((item) => item.status != 'pending_received')
                .toList();
            if (results.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No users found matching your search',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.surfaceBorder),
              itemBuilder: (context, index) {
                final item = results[index];
                final profile = item.profile;
                final status = item.status;
                final initials = (profile.displayName.isNotEmpty
                        ? profile.displayName
                        : profile.username)
                    .replaceAll('@', '');
                final avatarLetter =
                    initials.isNotEmpty ? initials[0].toUpperCase() : 'U';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final avatar = GestureDetector(
                        onTap: () => context.push('/profile/${profile.id}'),
                        child: Container(
                          width: 40,
                          height: 40,
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
                            avatarLetter,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );

                      final nameCol = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: AppTypography.heading2.copyWith(
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            profile.username,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );

                      final textScale =
                          MediaQuery.textScalerOf(context).scale(1.0);
                      final shouldReflow = constraints.maxWidth <
                          (260 * textScale).clamp(260.0, 520.0);

                      if (shouldReflow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                avatar,
                                const SizedBox(width: 12),
                                Expanded(child: nameCol),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildStatusAction(
                              context,
                              profile,
                              status,
                              currentUserId,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          avatar,
                          const SizedBox(width: 12),
                          Expanded(child: nameCol),
                          const SizedBox(width: 8),
                          _buildStatusAction(
                            context,
                            profile,
                            status,
                            currentUserId,
                          ),
                        ],
                      );
                    },
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
              'Error searching users: $err',
              style: const TextStyle(color: AppColors.accentRose),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.textSecondary,
  }) {
    return Expanded(
      child: Material(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusAction(
    BuildContext context,
    UserProfile profile,
    String status,
    String currentUserId,
  ) {
    if (status == 'friends') {
      return Container(
        key: Key('find_friends_connected_${profile.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.accentCyan),
        ),
        child: const Text(
          'Friends',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (status == 'pending_sent' || status == 'pending') {
      return Container(
        key: Key('find_friends_pending_${profile.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        key: Key('find_friends_add_${profile.id}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentCyan,
          foregroundColor: AppColors.background,
          minimumSize: const Size(80, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: () async {
          await ref.read(friendsDaoProvider).sendFriendRequest(
                currentUserId,
                profile.id,
              );
          ref.invalidate(findFriendsSearchResultsProvider);
        },
        child: const Text(
          '+ Add Friend',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }
  }
}

class PositionBottom extends StatelessWidget {
  final Widget child;
  const PositionBottom({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: child,
    );
  }
}

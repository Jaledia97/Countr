import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/mock_feed_data.dart';
import '../../data/social_seed_service.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../providers/feed_providers.dart';
import '../providers/inbox_providers.dart';
import '../widgets/home_search_results_view.dart';
import '../widgets/post_card.dart';
import '../widgets/post_composer_modal.dart';

/// The Social Feed (Home Screen).
/// Features:
/// - Expanding search bar with 200ms debounce
/// - Home Search Categorized Discovery (People, LGS & Businesses, Posts)
/// - Top AppBar: Countr title, Search toggle, Friends Hub icon, Live Notification Bell Badge
/// - 100% interactive feed with Drift real-time posts stream
/// - Floating Action Button opening PostComposerModal
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    Future.microtask(() async {
      if (!mounted) return;
      final db = ref.read(appDatabaseProvider);
      await SocialSeedService(db).seedSocialData();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        ref.read(homeSearchQueryProvider.notifier).state =
            _searchController.text.trim();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (_isSearchOpen) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        ref.read(homeSearchQueryProvider.notifier).state = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _debounceTimer?.cancel();
      _searchController.clear();
      ref.read(homeSearchQueryProvider.notifier).state = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(homeSearchQueryProvider);
    final unreadNotificationCount = ref.watch(totalInboxUnreadCountProvider);
    final postsAsync = ref.watch(feedPostsStreamProvider);
    final searchResultsAsync = ref.watch(homeSearchResultsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: _isSearchOpen
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: TextField(
                  key: const Key('home_search_input'),
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: AppTypography.body.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search people, stores, cards, posts...',
                    hintStyle: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.accentCyan,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            key: const Key('home_search_clear_button'),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: _clearSearch,
                          )
                        : IconButton(
                            key: const Key('home_search_close_button'),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: _toggleSearch,
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                ),
              )
            : const Text(
                'Countr',
                style: AppTypography.brandHeader,
              ),
        actions: [
          // Search Toggle Button (only when search is closed; when search is open, clear/close 'X' is housed inside suffixIcon)
          if (!_isSearchOpen)
            IconButton(
              key: const Key('feed_appbar_search_button'),
              icon: const Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
              tooltip: 'Search Discovery',
              onPressed: _toggleSearch,
            ),
          // Friends Hub Button
          IconButton(
            key: const Key('feed_appbar_friends_button'),
            icon: const Icon(Icons.people_outline_rounded, size: 22),
            tooltip: 'Friends & Groups',
            onPressed: () => context.push('/friends'),
          ),
          // Inbox Hub with live Red Dot Unread Indicator
          IconButton(
            key: const Key('feed_appbar_notification_bell'),
            icon: Badge(
              key: const Key('feed_bell_red_dot'),
              isLabelVisible: unreadNotificationCount > 0,
              backgroundColor: AppColors.accentRose,
              smallSize: 9,
              child: const Icon(Icons.notifications_none_rounded, size: 22),
            ),
            tooltip: 'Inbox Hub',
            onPressed: () async {
              final currentUserId = ref.read(currentUserIdProvider);
              final smartIndex = await ref
                  .read(inboxDaoProvider)
                  .getSmartInboxInitialIndex(currentUserId);
              if (!context.mounted) return;
              final tabParam = smartIndex == 1 ? 'messages' : 'notifications';
              context.push('/inbox?tab=$tabParam&initialIndex=$smartIndex');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: searchQuery.isNotEmpty
          ? searchResultsAsync.when(
              data: (results) => HomeSearchResultsView(results: results),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading search results: $err',
                  style: const TextStyle(color: AppColors.accentRose),
                ),
              ),
            )
          : RefreshIndicator(
              color: AppColors.accentCyan,
              backgroundColor: AppColors.surfaceRaised,
              onRefresh: () async {
                ref.invalidate(feedPostsStreamProvider);
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: postsAsync.when(
                data: (dbPosts) {
                  final posts =
                      dbPosts.isNotEmpty ? dbPosts : MockFeedData.posts;
                  return ListView.builder(
                    clipBehavior: Clip.none,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(post: posts[index]);
                    },
                  );
                },
                loading: () => ListView.builder(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: MockFeedData.posts.length,
                  itemBuilder: (context, index) {
                    return PostCard(post: MockFeedData.posts[index]);
                  },
                ),
                error: (context, error) => ListView.builder(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: MockFeedData.posts.length,
                  itemBuilder: (context, index) {
                    return PostCard(post: MockFeedData.posts[index]);
                  },
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('feed_create_post_fab'),
        onPressed: () => PostComposerModal.show(context),
        backgroundColor: AppColors.accentCyan,
        foregroundColor: AppColors.background,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

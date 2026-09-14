import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/mock_feed_data.dart';
import '../widgets/post_card.dart';

/// The Social Feed (Home Screen).
/// Header App Bar has Text("Countr") on the left,
/// and Search, Inbox/Mail, and Notification/Toggle icons on the right.
/// Renders a ListView.builder of modular Feed posts.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late final List _posts;

  @override
  void initState() {
    super.initState();
    _posts = MockFeedData.posts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'Countr',
          style: AppTypography.brandHeader,
        ),
        actions: [
          // Right: Search Icon
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            tooltip: 'Search',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search activated')),
              );
            },
          ),
          // Right: Inbox/Mail Icon
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded, size: 22),
            tooltip: 'Inbox',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Inbox / Direct Messages')),
              );
            },
          ),
          // Right: Generic Toggle/Notification Icon
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications')),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentCyan,
        backgroundColor: AppColors.surfaceRaised,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            setState(() {});
          }
        },
        child: ListView.builder(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            return PostCard(post: _posts[index]);
          },
        ),
      ),
    );
  }
}

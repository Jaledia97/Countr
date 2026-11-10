import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/cache/countr_cached_image.dart';
import '../../../../core/database/app_database.dart';
import '../../../auth/presentation/widgets/verified_store_badge.dart';
import '../../../symbology/presentation/widgets/mana_text.dart';
import '../../../vault/presentation/widgets/card_detail_sheet.dart';
import '../../domain/models/feed_post.dart';
import '../../domain/models/home_search_results.dart';

/// Renders categorized search results for Home Screen Search Discovery:
/// 1. "People" (individual collectors/creators)
/// 2. "Local Game Stores & Businesses" (verified stores like TBS Comics)
/// 3. "Posts" (matching text, cards, or locations)
class HomeSearchResultsView extends StatelessWidget {
  final HomeSearchResults results;
  final VoidCallback? onClear;

  const HomeSearchResultsView({
    super.key,
    required this.results,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No results found for "${results.query}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching for @usernames, store names (e.g. TBS Comics), card names, or locations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: const Key('home_search_results_list'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        if (results.people.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'People',
            count: results.people.length,
            icon: Icons.person_outline_rounded,
            sectionKey: const Key('search_result_people_section'),
          ),
          ...results.people.map((person) => _buildPersonTile(context, person)),
          const SizedBox(height: 16),
        ],
        if (results.stores.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Local Game Stores & Businesses',
            count: results.stores.length,
            icon: Icons.storefront_outlined,
            sectionKey: const Key('search_result_stores_section'),
          ),
          ...results.stores.map((store) => _buildStoreTile(context, store)),
          const SizedBox(height: 16),
        ],
        if (results.posts.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Posts',
            count: results.posts.length,
            icon: Icons.article_outlined,
            sectionKey: const Key('search_result_posts_section'),
          ),
          ...results.posts.map((post) => _buildPostTile(context, post)),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Key sectionKey,
  }) {
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6366F1)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonTile(BuildContext context, UserProfile person) {
    return InkWell(
      key: Key('search_person_${person.id}'),
      onTap: () => context.push('/profile/${person.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A2D3A),
              ),
              clipBehavior: Clip.antiAlias,
              child: (person.avatarUrl != null && person.avatarUrl!.isNotEmpty)
                  ? CountrCachedImage(
                      imageUrl: person.avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: Center(
                        child: Text(
                          person.displayName.isNotEmpty
                              ? person.displayName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        person.displayName.isNotEmpty
                            ? person.displayName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        person.username.startsWith('@')
                            ? person.username
                            : '@${person.username}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${person.friendCount} friends',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreTile(BuildContext context, UserProfile store) {
    return InkWell(
      key: Key('search_store_${store.id}'),
      onTap: () => context.push('/profile/${store.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E212D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          store.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (store.isVerifiedBusiness) ...[
                        const SizedBox(width: 6),
                        VerifiedStoreBadge(
                          key: Key('verified_store_badge_${store.id}'),
                          iconSize: 11,
                          fontSize: 8.5,
                          label: 'VERIFIED STORE',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (store.storeAddress != null && store.storeAddress!.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            store.storeAddress!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (store.storePhone != null && store.storePhone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            store.storePhone!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTile(BuildContext context, FeedPost post) {
    return InkWell(
      key: Key('search_post_${post.id}'),
      onTap: () {
        if (post.cardId != null && post.cardId!.isNotEmpty) {
          CardDetailSheet.show(context, post.cardId!);
        } else {
          context.push('/profile/${post.effectiveAuthorId}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2A2D3A),
              child: Text(
                post.avatarInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${post.timestamp}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (post.cardTitle != null && post.cardTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        post.cardTitle!,
                        style: const TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (post.textContent != null && post.textContent!.isNotEmpty)
                    ManaText(
                      post.textContent!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (post.cardImageUrl != null && post.cardImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CountrCachedImage(
                  imageUrl: post.cardImageUrl!,
                  width: 36,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

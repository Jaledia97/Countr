import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/trades/domain/models/trade_card_source_filter.dart';

/// Active authenticated user ID ('user-current-me', auth ID, or guest)
final currentUserIdProvider = StateProvider<String>((ref) {
  final authUser = ref.watch(currentUserProvider);
  if (authUser.isGuest) return 'user-current-me';
  return authUser.id;
});

/// Streams a UserProfile record by ID (resolving 'me' to active user ID)
final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, userId) async* {
  final effectiveId =
      userId == 'me' ? ref.watch(currentUserIdProvider) : userId;
  final db = ref.watch(appDatabaseProvider);
  final existing = await db.userProfileDao.getProfile(effectiveId);
  if (existing == null) {
    await db.userProfileDao.seedDefaultProfiles();
  }
  yield* db.userProfileDao.watchProfile(effectiveId);
});

/// Convenience provider for the active user's profile
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  final currentId = ref.watch(currentUserIdProvider);
  return ref.watch(userProfileProvider(currentId)).valueOrNull;
});

/// Current user account tier
final currentUserTierProvider = Provider<AccountTier>((ref) {
  final authUser = ref.watch(currentUserProvider);
  return authUser.tier;
});

/// Stream provider for user's system binder cards (looking_for, trade_block, store_inventory, store_buylist)
final userSystemBinderCardsProvider = StreamProvider.family<
    List<VaultItem>,
    ({String userId, String binderType})>((ref, arg) {
  final effectiveId =
      arg.userId == 'me' ? ref.watch(currentUserIdProvider) : arg.userId;
  final db = ref.watch(appDatabaseProvider);
  return db.vaultDao.watchSystemBinderItems(effectiveId, arg.binderType);
});

/// Stream provider for user cards available for trade proposals, filtered by [TradeCardSourceFilter].
final userTradeCardsProvider = StreamProvider.family<
    List<VaultItem>,
    ({String userId, TradeCardSourceFilter filter, String accountType})>((ref, arg) {
  final db = ref.watch(appDatabaseProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final effectiveId =
      arg.userId == 'me' ? currentUserId : arg.userId;
  return db.vaultDao.watchUserTradeCards(
    effectiveId,
    filter: arg.filter,
    isBusiness: arg.accountType == 'business',
    currentUserId: currentUserId,
  );
});

/// Stream provider for user's shared explore decks
final userSharedDecksProvider =
    StreamProvider.family<List<ExploreDeck>, String>((ref, userId) {
  final effectiveId =
      userId == 'me' ? ref.watch(currentUserIdProvider) : userId;
  final db = ref.watch(appDatabaseProvider);
  return db.exploreDeckDao.watchExploreDecks().map(
        (deckWithVotes) => deckWithVotes
            .map((v) => v.deck)
            .where((d) {
              final cleanCreator = d.creatorName.replaceAll('@', '').replaceAll('_', '').replaceAll('-', '').toLowerCase();
              final cleanId = effectiveId.replaceAll('user-', '').replaceAll('store-', '').replaceAll('_', '').replaceAll('-', '').toLowerCase();
              return d.authorId == effectiveId ||
                  d.authorId == '@$effectiveId' ||
                  cleanCreator == cleanId ||
                  d.creatorName.toLowerCase() == effectiveId.toLowerCase() ||
                  d.creatorName.toLowerCase() == '@${effectiveId.replaceAll('user-', '').toLowerCase()}';
            })
            .toList(),
      );
});

/// Provider for user's Activity Wall posts, reactively scoped to authored or shared posts via feedDao
final userWallPostsProvider =
    Provider.family<List<FeedPost>, String>((ref, userId) {
  final effectiveId =
      userId == 'me' ? ref.watch(currentUserIdProvider) : userId;
  final postsAsync = ref.watch(userWallPostsStreamProvider(effectiveId));
  return postsAsync.value ?? const <FeedPost>[];
});

/// Streams whether the current user is following [targetUserId]
final isFollowingProvider =
    StreamProvider.family<bool, String>((ref, targetUserId) {
  final db = ref.watch(appDatabaseProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return db.feedDao.watchIsFollowing(currentUserId, targetUserId);
});

/// Streams follower count for [targetUserId]
final followersCountProvider =
    StreamProvider.family<int, String>((ref, targetUserId) {
  final db = ref.watch(appDatabaseProvider);
  return db.feedDao.watchFollowersCount(targetUserId);
});


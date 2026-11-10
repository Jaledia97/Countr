import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../data/daos/friends_dao.dart';

/// Provider exposing [FriendsDao].
final friendsDaoProvider = Provider<FriendsDao>((ref) {
  return ref.watch(appDatabaseProvider).friendsDao;
});

/// Search query string for filtering "My Friends" list.
final friendsSearchQueryProvider = StateProvider<String>((ref) => '');

/// Streams list of accepted friends for the current user.
final myFriendsStreamProvider = StreamProvider<List<UserProfile>>((ref) {
  final dao = ref.watch(friendsDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final query = ref.watch(friendsSearchQueryProvider);
  return dao.watchFriends(currentUserId, searchQuery: query);
});

/// Streams pending incoming friend requests for the current user.
final incomingFriendRequestsStreamProvider =
    StreamProvider<List<FriendshipRecord>>((ref) {
  final dao = ref.watch(friendsDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return dao.watchIncomingRequests(currentUserId);
});

/// Streams pending outgoing friend requests sent by the current user.
final outgoingFriendRequestsStreamProvider =
    StreamProvider<List<FriendshipRecord>>((ref) {
  final dao = ref.watch(friendsDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return dao.watchOutgoingRequests(currentUserId);
});

/// Query string for "Find Friends" search bar.
final findFriendsQueryProvider = StateProvider<String>((ref) => '');

/// Searches user profiles with friendship status for "Find Friends".
final findFriendsSearchResultsProvider =
    FutureProvider<List<UserProfileWithStatus>>((ref) async {
  final dao = ref.watch(friendsDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final query = ref.watch(findFriendsQueryProvider);
  return dao.searchUsersWithFriendshipStatus(currentUserId, query);
});

/// Streams friendship status between current user and [otherUserId].
final friendshipStatusProvider =
    StreamProvider.family<String, String>((ref, otherUserId) {
  final dao = ref.watch(friendsDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return dao.watchFriendshipStatus(currentUserId, otherUserId);
});

/// Streams the reactive count of accepted friends for a specific user:
/// SELECT COUNT(*) FROM friendships WHERE (user_id = ? OR friend_id = ?) AND status = 'accepted' AND is_deleted = 0
final friendCountStreamProvider =
    StreamProvider.family<int, String>((ref, userId) {
  final dao = ref.watch(friendsDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final targetUserId = userId == 'me' ? currentUserId : userId;
  return dao.watchFriendCount(targetUserId);
});

/// Streams accepted friends scoped to a specific user.
final userFriendsStreamProvider =
    StreamProvider.family<List<UserProfile>, String>((ref, userId) {
  final dao = ref.watch(friendsDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final targetUserId = userId == 'me' ? currentUserId : userId;
  final query = ref.watch(friendsSearchQueryProvider);
  return dao.watchFriends(targetUserId, searchQuery: query);
});


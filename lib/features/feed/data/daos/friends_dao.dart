import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/social/friendships_table.dart';
import '../../../../core/database/tables/social/notifications_table.dart';
import '../../../../core/database/tables/user_profiles_table.dart';

part 'friends_dao.g.dart';

class UserProfileWithStatus {
  final UserProfile profile;
  final String status; // 'friends', 'pending_sent', 'pending_received', 'none'

  const UserProfileWithStatus({required this.profile, required this.status});
}

@DriftAccessor(tables: [Friendships, UserProfiles, Notifications])
class FriendsDao extends DatabaseAccessor<AppDatabase> with _$FriendsDaoMixin {
  FriendsDao(super.db);

  /// Streams accepted friends for a user, optionally filtered by a search query.
  Stream<List<UserProfile>> watchFriends(String userId, {String? searchQuery}) {
    // Select accepted friendships where user is either side
    final friendshipsQuery = select(friendships)
      ..where((t) =>
          (t.userId.equals(userId) | t.friendId.equals(userId)) &
          t.status.equals('accepted') &
          t.isDeleted.equals(false));

    return friendshipsQuery.watch().asyncMap((friendshipList) async {
      final friendIds = friendshipList
          .map((f) => f.userId == userId ? f.friendId : f.userId)
          .toSet();

      if (friendIds.isEmpty) return <UserProfile>[];

      final profilesQuery = select(userProfiles)
        ..where((p) {
          var pred = p.id.isIn(friendIds) & p.isDeleted.equals(false);
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final clean = searchQuery.trim().replaceAll('@', '');
            pred = pred &
                (p.username.like('%$clean%') | p.displayName.like('%$clean%'));
          }
          return pred;
        })
        ..orderBy([(p) => OrderingTerm.asc(p.displayName)]);

      return profilesQuery.get();
    });
  }

  /// Streams reactive count of accepted friendships for a user:
  /// SELECT COUNT(*) FROM friendships WHERE (user_id = ? OR friend_id = ?) AND status = 'accepted' AND is_deleted = 0
  Stream<int> watchFriendCount(String userId) {
    final countCol = friendships.id.count();
    final query = selectOnly(friendships)
      ..addColumns([countCol])
      ..where((friendships.userId.equals(userId) |
              friendships.friendId.equals(userId)) &
          friendships.status.equals('accepted') &
          friendships.isDeleted.equals(false));

    return query.map((row) => row.read(countCol) ?? 0).watchSingle();
  }

  /// Fetches count of accepted friendships for a user.
  Future<int> getFriendCount(String userId) {
    final countCol = friendships.id.count();
    final query = selectOnly(friendships)
      ..addColumns([countCol])
      ..where((friendships.userId.equals(userId) |
              friendships.friendId.equals(userId)) &
          friendships.status.equals('accepted') &
          friendships.isDeleted.equals(false));

    return query.map((row) => row.read(countCol) ?? 0).getSingle();
  }

  /// Streams pending incoming friend requests for a user.
  Stream<List<FriendshipRecord>> watchIncomingRequests(String userId) {
    return (select(friendships)
          ..where((t) =>
              t.friendId.equals(userId) &
              t.status.equals('pending') &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Streams pending outgoing friend requests sent by a user.
  Stream<List<FriendshipRecord>> watchOutgoingRequests(String userId) {
    return (select(friendships)
          ..where((t) =>
              t.userId.equals(userId) &
              t.status.equals('pending') &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Streams the friendship status between two users.
  /// Returns 'friends', 'pending_sent', 'pending_received', 'blocked', 'blocked_by', or 'none'.
  Stream<String> watchFriendshipStatus(String currentUserId, String otherUserId) {
    return (select(friendships)
          ..where((t) =>
              ((t.userId.equals(currentUserId) & t.friendId.equals(otherUserId)) |
                  (t.userId.equals(otherUserId) & t.friendId.equals(currentUserId))) &
              t.isDeleted.equals(false)))
        .watch()
        .map((records) {
      if (records.isEmpty) return 'none';
      final record = records.first;
      if (record.status == 'blocked') {
        return record.userId == currentUserId ? 'blocked' : 'blocked_by';
      }
      if (record.status == 'accepted') return 'friends';
      if (record.status == 'pending') {
        return record.userId == currentUserId ? 'pending_sent' : 'pending_received';
      }
      return 'none';
    });
  }

  /// Sends a friend request from [currentUserId] to [targetUserId].
  Future<void> sendFriendRequest(String currentUserId, String targetUserId) {
    return transaction(() async {
      // Defense-in-depth: Never send friend request to self
      if (currentUserId == targetUserId) return;

      final now = DateTime.now();

      final existing = await (select(friendships)
            ..where((t) =>
                ((t.userId.equals(currentUserId) & t.friendId.equals(targetUserId)) |
                    (t.userId.equals(targetUserId) & t.friendId.equals(currentUserId)))))
          .getSingleOrNull();

      if (existing != null) {
        if (existing.status == 'accepted') return;
        await (update(friendships)..where((t) => t.id.equals(existing.id))).write(
          FriendshipsCompanion(
            status: const Value('pending'),
            userId: Value(currentUserId),
            friendId: Value(targetUserId),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      } else {
        await into(friendships).insert(
          FriendshipsCompanion.insert(
            id: 'friend_${currentUserId}_$targetUserId',
            userId: currentUserId,
            friendId: targetUserId,
            status: const Value('pending'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      // Create notification for target user
      final senderProfile = await (select(userProfiles)
            ..where((t) => t.id.equals(currentUserId)))
          .getSingleOrNull();

      if (currentUserId != targetUserId) {
        await into(notifications).insert(
          NotificationsCompanion.insert(
            id: 'notif_fr_${currentUserId}_$targetUserId',
            userId: targetUserId,
            actorId: currentUserId,
            actorUsername: senderProfile?.username ?? '@collector_me',
            actorDisplayName: Value(senderProfile?.displayName),
            actorAvatarUrl: Value(senderProfile?.avatarUrl),
            type: 'friend_request',
            title: 'Friend Request',
            body: 'sent you a friend request',
            targetEntityId: Value(currentUserId),
            targetEntityType: const Value('profile'),
            createdAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Cancels an outgoing pending friend request.
  Future<void> cancelFriendRequest(String currentUserId, String targetUserId) {
    return transaction(() async {
      final now = DateTime.now();
      await (update(friendships)
            ..where((t) =>
                t.userId.equals(currentUserId) &
                t.friendId.equals(targetUserId) &
                t.status.equals('pending')))
          .write(
        FriendshipsCompanion(
          status: const Value('declined'),
          isDeleted: const Value(true),
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Atomically update associated notification for recipient
      await (update(notifications)
            ..where((t) =>
                t.userId.equals(targetUserId) &
                t.actorId.equals(currentUserId) &
                t.type.equals('friend_request')))
          .write(
        NotificationsCompanion(
          isActioned: const Value(true),
          isRead: const Value(true),
          status: const Value('declined'),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Responds to an incoming friend request (accept or decline).
  Future<void> respondToFriendRequest(
    String currentUserId,
    String requesterId, {
    required bool accept,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final newStatus = accept ? 'accepted' : 'declined';

      final pending = await (select(friendships)
            ..where((t) =>
                t.userId.equals(requesterId) &
                t.friendId.equals(currentUserId) &
                t.status.equals('pending') &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (pending == null) {
        // Idempotent: already actioned or nonexistent
        return;
      }

      await (update(friendships)..where((t) => t.id.equals(pending.id))).write(
        FriendshipsCompanion(
          status: Value(newStatus),
          updatedAt: Value(now),
        ),
      );

      // Also mark the notification as actioned and read if it exists
      await (update(notifications)
            ..where((t) =>
                t.userId.equals(currentUserId) &
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
              ..where((t) => t.id.equals(currentUserId)))
            .getSingleOrNull();
        if (u2 != null) {
          await (update(userProfiles)..where((t) => t.id.equals(currentUserId))).write(
            UserProfilesCompanion(
              friendCount: Value(u2.friendCount + 1),
              updatedAt: Value(now),
            ),
          );
        }
      }
    });
  }

  /// Removes an existing friend.
  Future<void> removeFriend(String currentUserId, String targetUserId) {
    return transaction(() async {
      final now = DateTime.now();

      await (update(friendships)
            ..where((t) =>
                ((t.userId.equals(currentUserId) & t.friendId.equals(targetUserId)) |
                    (t.userId.equals(targetUserId) & t.friendId.equals(currentUserId))) &
                t.status.equals('accepted')))
          .write(
        FriendshipsCompanion(
          status: const Value('declined'),
          isDeleted: const Value(true),
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Decrement friend counts
      final u1 = await (select(userProfiles)..where((t) => t.id.equals(currentUserId)))
          .getSingleOrNull();
      if (u1 != null && u1.friendCount > 0) {
        await (update(userProfiles)..where((t) => t.id.equals(currentUserId))).write(
          UserProfilesCompanion(
            friendCount: Value(u1.friendCount - 1),
            updatedAt: Value(now),
          ),
        );
      }

      final u2 = await (select(userProfiles)..where((t) => t.id.equals(targetUserId)))
          .getSingleOrNull();
      if (u2 != null && u2.friendCount > 0) {
        await (update(userProfiles)..where((t) => t.id.equals(targetUserId))).write(
          UserProfilesCompanion(
            friendCount: Value(u2.friendCount - 1),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Blocks a user. Soft-deletes existing friendship or inserts a blocked record.
  /// Decrements friend counts if previously accepted.
  Future<void> blockUser(String currentUserId, String targetUserId) {
    return transaction(() async {
      final now = DateTime.now();
      final existing = await (select(friendships)
            ..where((t) =>
                ((t.userId.equals(currentUserId) & t.friendId.equals(targetUserId)) |
                    (t.userId.equals(targetUserId) & t.friendId.equals(currentUserId)))))
          .getSingleOrNull();

      final wasAccepted = existing?.status == 'accepted' && !(existing?.isDeleted ?? true);

      if (existing != null) {
        await (update(friendships)..where((t) => t.id.equals(existing.id))).write(
          FriendshipsCompanion(
            status: const Value('blocked'),
            userId: Value(currentUserId),
            friendId: Value(targetUserId),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      } else {
        await into(friendships).insert(
          FriendshipsCompanion.insert(
            id: 'block_${currentUserId}_$targetUserId',
            userId: currentUserId,
            friendId: targetUserId,
            status: const Value('blocked'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      if (wasAccepted) {
        final u1 = await (select(userProfiles)..where((t) => t.id.equals(currentUserId))).getSingleOrNull();
        if (u1 != null && u1.friendCount > 0) {
          await (update(userProfiles)..where((t) => t.id.equals(currentUserId))).write(
            UserProfilesCompanion(friendCount: Value(u1.friendCount - 1), updatedAt: Value(now)),
          );
        }
        final u2 = await (select(userProfiles)..where((t) => t.id.equals(targetUserId))).getSingleOrNull();
        if (u2 != null && u2.friendCount > 0) {
          await (update(userProfiles)..where((t) => t.id.equals(targetUserId))).write(
            UserProfilesCompanion(friendCount: Value(u2.friendCount - 1), updatedAt: Value(now)),
          );
        }
      }
    });
  }

  /// Unblocks a user. Sets status to declined / soft-deleted.
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    final now = DateTime.now();
    await (update(friendships)
          ..where((t) =>
              t.userId.equals(currentUserId) &
              t.friendId.equals(targetUserId) &
              t.status.equals('blocked')))
        .write(
      FriendshipsCompanion(
        status: const Value('declined'),
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Searches users and augments each with their current friendship status with [currentUserId].
  Future<List<UserProfileWithStatus>> searchUsersWithFriendshipStatus(
    String currentUserId,
    String query, {
    int limit = 20,
  }) async {
    final cleanQuery = query.trim().replaceAll('@', '');
    List<UserProfile> profiles;

    if (cleanQuery.isEmpty) {
      // Return top suggested profiles excluding self
      profiles = await (select(userProfiles)
            ..where((t) => t.id.isNotValue(currentUserId) & t.isDeleted.equals(false))
            ..limit(limit))
          .get();
    } else {
      profiles = await (select(userProfiles)
            ..where((t) =>
                t.id.isNotValue(currentUserId) &
                t.isDeleted.equals(false) &
                (t.username.like('%$cleanQuery%') |
                    t.displayName.like('%$cleanQuery%')))
            ..limit(limit))
          .get();
    }

    // Get all friendships for current user to compute status in memory
    final userFriendships = await (select(friendships)
          ..where((t) =>
              (t.userId.equals(currentUserId) | t.friendId.equals(currentUserId)) &
              t.isDeleted.equals(false)))
        .get();

    final statusMap = <String, String>{};
    for (final f in userFriendships) {
      final otherId = f.userId == currentUserId ? f.friendId : f.userId;
      if (f.status == 'accepted') {
        statusMap[otherId] = 'friends';
      } else if (f.status == 'pending') {
        statusMap[otherId] =
            f.userId == currentUserId ? 'pending_sent' : 'pending_received';
      }
    }

    return profiles.map((p) {
      return UserProfileWithStatus(
        profile: p,
        status: statusMap[p.id] ?? 'none',
      );
    }).toList();
  }
}

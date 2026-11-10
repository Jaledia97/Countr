// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_dao.dart';

// ignore_for_file: type=lint
mixin _$FeedDaoMixin on DatabaseAccessor<AppDatabase> {
  $FeedPostsTable get feedPosts => attachedDatabase.feedPosts;
  $PostLikesTable get postLikes => attachedDatabase.postLikes;
  $PostCommentsTable get postComments => attachedDatabase.postComments;
  $NotificationsTable get notifications => attachedDatabase.notifications;
  $UserFollowsTable get userFollows => attachedDatabase.userFollows;
  $UserProfilesTable get userProfiles => attachedDatabase.userProfiles;
  $PostVotesTable get postVotes => attachedDatabase.postVotes;
  $PostReactionsTable get postReactions => attachedDatabase.postReactions;
  $CommentReactionsTable get commentReactions =>
      attachedDatabase.commentReactions;
  $SavedPostsTable get savedPosts => attachedDatabase.savedPosts;
  FeedDaoManager get managers => FeedDaoManager(this);
}

class FeedDaoManager {
  final _$FeedDaoMixin _db;
  FeedDaoManager(this._db);
  $$FeedPostsTableTableManager get feedPosts =>
      $$FeedPostsTableTableManager(_db.attachedDatabase, _db.feedPosts);
  $$PostLikesTableTableManager get postLikes =>
      $$PostLikesTableTableManager(_db.attachedDatabase, _db.postLikes);
  $$PostCommentsTableTableManager get postComments =>
      $$PostCommentsTableTableManager(_db.attachedDatabase, _db.postComments);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db.attachedDatabase, _db.notifications);
  $$UserFollowsTableTableManager get userFollows =>
      $$UserFollowsTableTableManager(_db.attachedDatabase, _db.userFollows);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db.attachedDatabase, _db.userProfiles);
  $$PostVotesTableTableManager get postVotes =>
      $$PostVotesTableTableManager(_db.attachedDatabase, _db.postVotes);
  $$PostReactionsTableTableManager get postReactions =>
      $$PostReactionsTableTableManager(_db.attachedDatabase, _db.postReactions);
  $$CommentReactionsTableTableManager get commentReactions =>
      $$CommentReactionsTableTableManager(
        _db.attachedDatabase,
        _db.commentReactions,
      );
  $$SavedPostsTableTableManager get savedPosts =>
      $$SavedPostsTableTableManager(_db.attachedDatabase, _db.savedPosts);
}

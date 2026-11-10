import '../../../../core/database/app_database.dart';

class PostComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorUsername;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final String? parentCommentId;

  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
  });

  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  factory PostComment.fromRecord(PostCommentRecord record) {
    return PostComment(
      id: record.id,
      postId: record.postId,
      authorId: record.authorId,
      authorUsername: record.authorUsername,
      authorDisplayName: record.authorDisplayName,
      authorAvatarUrl: record.authorAvatarUrl,
      content: record.content,
      createdAt: record.createdAt,
      parentCommentId: record.parentCommentId,
    );
  }

  PostComment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    String? content,
    DateTime? createdAt,
    String? parentCommentId,
  }) {
    return PostComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
    );
  }
}

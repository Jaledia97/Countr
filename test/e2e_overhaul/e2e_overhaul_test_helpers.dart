import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
/// Test User Profile record for social, feed, friends, and trade tests.
class TestUserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String accountType;
  final bool isVerifiedBusiness;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TestUserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.accountType = 'individual',
    this.isVerifiedBusiness = false,
    required this.createdAt,
    this.updatedAt,
  });
}

/// Standard mock persona profiles for Overhaul tests.
List<TestUserProfile> getStandardOverhaulProfiles() {
  final now = DateTime.now();
  return [
    TestUserProfile(
      id: 'user_spicy',
      username: '@SpicyBrewMaster',
      displayName: 'Spicy Brewmaster',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      accountType: 'individual',
      isVerifiedBusiness: false,
      createdAt: now,
      updatedAt: now,
    ),
    TestUserProfile(
      id: 'user_edh',
      username: '@EDH_Rec_Fanatic',
      displayName: 'EDH Rec Fanatic',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      accountType: 'individual',
      isVerifiedBusiness: false,
      createdAt: now,
      updatedAt: now,
    ),
    TestUserProfile(
      id: 'user_foil',
      username: '@FoilCollector99',
      displayName: 'Foil Collector 99',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
      accountType: 'individual',
      isVerifiedBusiness: false,
      createdAt: now,
      updatedAt: now,
    ),
    TestUserProfile(
      id: 'store_tbs',
      username: '@TBSComics',
      displayName: 'TBS Comics - Fort Walton Beach',
      avatarUrl: 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=150',
      accountType: 'business',
      isVerifiedBusiness: true,
      createdAt: now,
      updatedAt: now,
    ),
    TestUserProfile(
      id: 'user_me',
      username: '@collector_me',
      displayName: 'Me (Current User)',
      avatarUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150',
      accountType: 'individual',
      isVerifiedBusiness: false,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

/// Helper to wrap widgets in MaterialApp and ProviderScope.
Widget wrapWithOverhaulScope(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

// =============================================================================
// DOMAIN CONTRACT MODELS & ENGINE FOR OVERHAUL SPECIFICATION VERIFICATION
// =============================================================================

/// Vote direction in Reddit voting pill.
enum PostVoteType { upvote, downvote, none }

/// Post attachment type for dynamic transform.
enum PostAttachmentType { textOnly, singleCard, multiCard, image, mixedMedia }

/// Contract for Feature 1 & 10: Post Votes
class PostVoteRecordContract {
  final String postId;
  final String userId;
  final int vote; // +1, -1, 0
  final DateTime updatedAt;

  const PostVoteRecordContract({
    required this.postId,
    required this.userId,
    required this.vote,
    required this.updatedAt,
  });
}

/// Contract for Feature 1, 11, 16: Reactions
class ReactionRecordContract {
  final String targetId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const ReactionRecordContract({
    required this.targetId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });
}

/// Contract for Feature 14 & 15: Nested Comment Tree Node
class NestedCommentNode {
  final String id;
  final String postId;
  final String? parentCommentId;
  final String authorId;
  final String authorUsername;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final List<NestedCommentNode> replies;
  final Map<String, int> reactions;

  NestedCommentNode({
    required this.id,
    required this.postId,
    this.parentCommentId,
    required this.authorId,
    required this.authorUsername,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    List<NestedCommentNode>? replies,
    Map<String, int>? reactions,
  })  : replies = replies ?? [],
        reactions = reactions ?? {};

  /// Recursively counts all comments in subtree including self.
  int get totalSubtreeCount => 1 + replies.fold(0, (sum, r) => sum + r.totalSubtreeCount);

  /// Computes max nesting depth of replies from this node (0 if leaf).
  int get maxDepth => replies.isEmpty ? 0 : 1 + replies.map((r) => r.maxDepth).reduce((a, b) => a > b ? a : b);
}

/// Engine to assemble flat comment list with parentCommentId into hierarchical tree.
class NestedCommentTreeEngine {
  static List<NestedCommentNode> buildTree(List<Map<String, dynamic>> rawComments) {
    final Map<String, NestedCommentNode> nodeMap = {};
    final List<NestedCommentNode> roots = [];

    // First pass: create all nodes
    for (final raw in rawComments) {
      final node = NestedCommentNode(
        id: raw['id'] as String,
        postId: raw['post_id'] as String,
        parentCommentId: raw['parent_comment_id'] as String?,
        authorId: raw['author_id'] as String,
        authorUsername: raw['author_username'] as String,
        authorDisplayName: raw['author_display_name'] as String,
        authorAvatarUrl: raw['author_avatar_url'] as String?,
        content: raw['content'] as String,
        createdAt: raw['created_at'] is DateTime
            ? raw['created_at'] as DateTime
            : DateTime.parse(raw['created_at'].toString()),
        reactions: raw['reactions'] is Map ? Map<String, int>.from(raw['reactions'] as Map) : {},
      );
      nodeMap[node.id] = node;
    }

    // Second pass: link parent-child hierarchy
    for (final node in nodeMap.values) {
      if (node.parentCommentId != null && nodeMap.containsKey(node.parentCommentId) && node.parentCommentId != node.id) {
        nodeMap[node.parentCommentId]!.replies.add(node);
      } else {
        roots.add(node);
      }
    }

    // Detect and break any circular references (unanchored cycles)
    final Set<String> visited = {};
    void markReachable(NestedCommentNode node) {
      if (visited.add(node.id)) {
        for (final child in node.replies) {
          markReachable(child);
        }
      }
    }
    for (final r in roots) {
      markReachable(r);
    }
    for (final node in nodeMap.values) {
      if (!visited.contains(node.id)) {
        node.replies.clear();
        roots.add(node);
        visited.add(node.id);
      }
    }

    // Sort chronologically ascending with cycle guard
    final Set<String> sortVisited = {};
    void sortSubtree(NestedCommentNode parent) {
      if (!sortVisited.add(parent.id)) return;
      parent.replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final child in parent.replies) {
        sortSubtree(child);
      }
    }

    roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final r in roots) {
      sortSubtree(r);
    }

    return roots;
  }

  /// Calculates true total comment count across all depths.
  static int calculateTotalCount(List<NestedCommentNode> roots) {
    return roots.fold(0, (sum, r) => sum + r.totalSubtreeCount);
  }
}

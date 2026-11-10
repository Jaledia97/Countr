import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/cache/countr_cached_image.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../symbology/presentation/widgets/mana_text.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../domain/models/feed_post.dart';
import '../../domain/models/post_comment.dart';
import '../providers/feed_providers.dart';

/// Hierarchical tree node representing a comment and its nested replies.
class CommentNode {
  final PostComment comment;
  final List<CommentNode> children;

  CommentNode({
    required this.comment,
    required this.children,
  });

  int get totalSubtreeCount => 1 + children.fold(0, (sum, c) => sum + c.totalSubtreeCount);
}

/// Modal bottom sheet providing deep nested comments tree, reply threads, and emoji reactions.
class PostCommentsSheet extends ConsumerStatefulWidget {
  final FeedPost post;

  const PostCommentsSheet({super.key, required this.post});

  static Future<void> show(BuildContext context, FeedPost post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(post: post),
    );
  }

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;

  /// Currently targeted parent comment when composing a reply
  PostComment? _replyingToComment;

  /// Comment ID whose 5 MRU reaction bar is currently expanded
  String? _activeReactionCommentId;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CommentNode> _buildCommentTree(List<PostComment> allComments) {
    final Map<String, CommentNode> nodeMap = {};
    for (final comment in allComments) {
      nodeMap[comment.id] = CommentNode(comment: comment, children: []);
    }

    final List<CommentNode> rootNodes = [];
    for (final comment in allComments) {
      final node = nodeMap[comment.id]!;
      if (comment.parentCommentId != null &&
          nodeMap.containsKey(comment.parentCommentId) &&
          comment.parentCommentId != comment.id) {
        nodeMap[comment.parentCommentId]!.children.add(node);
      } else {
        rootNodes.add(node);
      }
    }

    // Sort chronologically ascending
    void sortSubtree(CommentNode parent) {
      parent.children.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
      for (final child in parent.children) {
        sortSubtree(child);
      }
    }

    rootNodes.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
    for (final r in rootNodes) {
      sortSubtree(r);
    }

    return rootNodes;
  }

  void _startReply(PostComment comment) {
    setState(() {
      _replyingToComment = comment;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToComment = null;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final feedDao = ref.read(feedDaoProvider);
      final currentUserId = ref.read(currentUserIdProvider);
      final db = ref.read(appDatabaseProvider);
      final profile = await db.userProfileDao.getProfile(currentUserId);

      await feedDao.addComment(
        postId: widget.post.id,
        authorId: currentUserId,
        authorUsername: profile?.username ?? '@collector_me',
        authorDisplayName: profile?.displayName ?? 'Current Collector',
        authorAvatarUrl: profile?.avatarUrl,
        content: text,
        parentCommentId: _replyingToComment?.id,
      );

      _commentController.clear();
      setState(() {
        _replyingToComment = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(postCommentsStreamProvider(widget.post.id));
    final liveTotalCount = ref.watch(postCommentCountProvider(widget.post.id)).valueOrNull ??
        commentsAsync.valueOrNull?.length ??
        widget.post.commentCount;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF161822),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with true total count across all depths
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              key: const Key('comments_sheet_header'),
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: Color(0xFF818CF8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comments ($liveTotalCount)',
                    key: const Key('post_comments_count_header'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('post_comments_close_button'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Comment list / tree
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 44,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Be the first to share your thoughts!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final treeRoots = _buildCommentTree(comments);

                return ListView.builder(
                  key: const Key('post_comments_list'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: treeRoots.length,
                  itemBuilder: (ctx, index) {
                    final rootNode = treeRoots[index];
                    return _buildCommentTreeNode(rootNode, depth: 0);
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),

          const Divider(height: 1, color: Colors.white10),

          // Replying to @username banner
          if (_replyingToComment != null)
            Container(
              key: const Key('replying_to_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E2235),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: Color(0xFF818CF8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to @${_replyingToComment!.authorUsername.replaceAll('@', '')} [X]',
                      key: const Key('comment_replying_banner'),
                      style: const TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    key: const Key('dismiss_reply_banner_button'),
                    onTap: _cancelReply,
                    child: const Padding(
                      key: Key('comment_reply_cancel_button'),
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

          // Pinned bottom input
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF1E212D),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF12141C),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: TextField(
                        key: const Key('post_comment_input'),
                        controller: _commentController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _replyingToComment != null
                              ? 'Reply to @${_replyingToComment!.authorUsername.replaceAll('@', '')}...'
                              : 'Add a comment (supports {W}{U}{B}{R}{G})...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('post_comment_submit_button'),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                          )
                        : const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a comment item and recurses through all child replies with vertical thread guide line.
  Widget _buildCommentTreeNode(CommentNode node, {required int depth}) {
    final comment = node.comment;
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentCard(comment, depth: depth),
        if (hasChildren)
          Container(
            key: const Key('thread_guide_line'),
            margin: EdgeInsets.only(left: depth >= 3 ? 6.0 : 14.0),
            padding: EdgeInsets.only(left: depth >= 3 ? 6.0 : 10.0),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Color(0xFF33384B),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map((childNode) => _buildCommentTreeNode(childNode, depth: depth + 1))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentCard(PostComment comment, {required int depth}) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final reactionsAsync = ref.watch(commentReactionSummaryProvider(comment.id));
    final mruEmojis = ref.watch(mruReactionEmojisProvider);
    final isReactionMenuOpen = _activeReactionCommentId == comment.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Avatar
          InkWell(
            onTap: () => context.push('/profile/${comment.authorId}'),
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A2D3A),
              ),
              clipBehavior: Clip.antiAlias,
              child: (comment.authorAvatarUrl != null && comment.authorAvatarUrl!.isNotEmpty)
                  ? CountrCachedImage(
                      imageUrl: comment.authorAvatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: Center(
                        child: Text(
                          comment.authorUsername.isNotEmpty
                              ? comment.authorUsername.replaceAll('@', '').substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        comment.authorUsername.isNotEmpty
                            ? comment.authorUsername.replaceAll('@', '').substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Comment body & action controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author & relative timestamp
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => context.push('/profile/${comment.authorId}'),
                        child: Text(
                          comment.authorDisplayName.isNotEmpty
                              ? comment.authorDisplayName
                              : comment.authorUsername,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        comment.relativeTime,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),

                // Comment Content with ManaText
                ManaText(
                  comment.content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),

                // Compact reaction pills beneath comment
                reactionsAsync.when(
                  data: (summaries) {
                    if (summaries.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        key: const Key('comment_reaction_pills_row'),
                        spacing: 6,
                        runSpacing: 4,
                        children: summaries.map((summary) {
                          return InkWell(
                            key: Key('comment_pill_${summary.emoji}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final dao = ref.read(feedDaoProvider);
                              await dao.toggleCommentReaction(comment.id, currentUserId, summary.emoji);
                              ref.read(mruReactionEmojisProvider.notifier).recordEmojiUsage(summary.emoji);
                            },
                            child: Container(
                              key: Key('comment_reaction_pill_${comment.id}_${summary.emoji}'),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: summary.userReacted
                                    ? const Color(0xFF4338CA).withValues(alpha: 0.6)
                                    : const Color(0xFF232736),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: summary.userReacted
                                      ? const Color(0xFF818CF8)
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(summary.emoji, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${summary.count}',
                                    style: TextStyle(
                                      color: summary.userReacted ? Colors.white : Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Action Row: [Reply] and [React]
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        // Reply button
                        InkWell(
                          key: Key('comment_reply_button_${comment.id}'),
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _startReply(comment),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply_rounded, size: 14, color: Colors.white60),
                                SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // React emoji button
                        InkWell(
                          key: Key('comment_react_button_${comment.id}'),
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            setState(() {
                              _activeReactionCommentId = isReactionMenuOpen ? null : comment.id;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Icon(
                              isReactionMenuOpen
                                  ? Icons.emoji_emotions_rounded
                                  : Icons.add_reaction_outlined,
                              size: 14,
                              color: isReactionMenuOpen ? const Color(0xFF818CF8) : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5 MRU suggestions bar
                if (isReactionMenuOpen)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      key: Key('comment_mru_bar_${comment.id}'),
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: mruEmojis.map((emoji) {
                          return InkWell(
                            key: Key('comment_reaction_mru_${comment.id}_$emoji'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final dao = ref.read(feedDaoProvider);
                              await dao.toggleCommentReaction(comment.id, currentUserId, emoji);
                              ref.read(mruReactionEmojisProvider.notifier).recordEmojiUsage(emoji);
                              setState(() {
                                _activeReactionCommentId = null;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              child: Text(emoji, style: const TextStyle(fontSize: 16)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

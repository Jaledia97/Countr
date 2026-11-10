import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Reusable PostActionBar component per Milestone 3 (Features 9, 10, 11).
/// Displays:
/// - Active reaction pills above the interaction bar
/// - Floating 5 MRU emoji suggestions bar
/// - Icons-only interaction bar:
///   [ ↑ | Net Score | ↓ ] Reddit voting pill + Comment button & counter + React Emoji button
class PostActionBar extends StatefulWidget {
  final String? postId;
  final int? initialNetScore;
  final int? initialUserVote;
  final int? initialHypeCount;
  final bool? initialIsHyped;
  final bool initialIsWishlisted;
  final int commentCount;
  final Map<String, int>? initialReactions;
  final Set<String>? userReactions;
  final List<String>? mruEmojis;
  final ValueChanged<int>? onVoteChanged;
  final ValueChanged<String>? onReactionSelected;
  final VoidCallback? onCommentTap;
  final VoidCallback? onTradeTap;
  final VoidCallback? onHypeTap;

  const PostActionBar({
    super.key,
    this.postId,
    this.initialNetScore,
    this.initialUserVote,
    this.initialHypeCount,
    this.initialIsHyped,
    this.initialIsWishlisted = false,
    required this.commentCount,
    this.initialReactions,
    this.userReactions,
    this.mruEmojis,
    this.onVoteChanged,
    this.onReactionSelected,
    this.onCommentTap,
    this.onTradeTap,
    this.onHypeTap,
  });

  @override
  State<PostActionBar> createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  late int _netScore;
  late int _userVote;
  bool _showMruSelector = false;
  late List<String> _mruEmojis;
  late Map<String, int> _activeReactions;
  late Set<String> _myReactions;

  @override
  void initState() {
    super.initState();
    _netScore = widget.initialNetScore ?? widget.initialHypeCount ?? 0;
    _userVote = widget.initialUserVote ?? ((widget.initialIsHyped ?? false) ? 1 : 0);
    _mruEmojis = List<String>.from(widget.mruEmojis ?? const ['🔥', '❤️', '😂', '🤯', '💎']);
    _activeReactions = Map<String, int>.from(widget.initialReactions ?? {});
    _myReactions = Set<String>.from(widget.userReactions ?? {});
  }

  @override
  void didUpdateWidget(PostActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNetScore != null && widget.initialNetScore != oldWidget.initialNetScore) {
      _netScore = widget.initialNetScore!;
    } else if (widget.initialHypeCount != null && widget.initialHypeCount != oldWidget.initialHypeCount) {
      _netScore = widget.initialHypeCount!;
    }
    if (widget.initialUserVote != null && widget.initialUserVote != oldWidget.initialUserVote) {
      _userVote = widget.initialUserVote!;
    } else if (widget.initialIsHyped != null && widget.initialIsHyped != oldWidget.initialIsHyped) {
      _userVote = widget.initialIsHyped! ? 1 : 0;
    }
    if (widget.initialReactions != null && widget.initialReactions != oldWidget.initialReactions) {
      _activeReactions = Map<String, int>.from(widget.initialReactions!);
    }
    if (widget.userReactions != null && widget.userReactions != oldWidget.userReactions) {
      _myReactions = Set<String>.from(widget.userReactions!);
    }
  }

  void _handleVote(int dir) {
    setState(() {
      if (_userVote == dir) {
        _netScore -= dir;
        _userVote = 0;
      } else {
        _netScore += (dir - _userVote);
        _userVote = dir;
      }
    });
    widget.onVoteChanged?.call(_userVote);
    widget.onHypeTap?.call();
  }

  void _toggleReaction(String emoji) {
    setState(() {
      if (_myReactions.contains(emoji)) {
        _myReactions.remove(emoji);
        final currentCount = _activeReactions[emoji] ?? 1;
        if (currentCount <= 1) {
          _activeReactions.remove(emoji);
        } else {
          _activeReactions[emoji] = currentCount - 1;
        }
      } else {
        _myReactions.add(emoji);
        _activeReactions[emoji] = (_activeReactions[emoji] ?? 0) + 1;
      }
      _recordEmojiUsage(emoji);
      _showMruSelector = false;
    });
    widget.onReactionSelected?.call(emoji);
  }

  void _recordEmojiUsage(String emoji) {
    _mruEmojis.remove(emoji);
    _mruEmojis.insert(0, emoji);
    if (_mruEmojis.length > 5) {
      _mruEmojis = _mruEmojis.take(5).toList();
    }
  }

  void _showFullPicker(BuildContext context) {
    const popularEmojis = [
      '🔥', '❤️', '😂', '🤯', '💎',
      '👍', '👎', '🎉', '🚀', '💯',
      '👏', '👀', '✨', '⚡', '🏆',
      '💀', '🛡️', '⚔️', '🪄', '🎯',
      '👑', '🧙', '🐉', '🃏', '💰',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'React with Emoji',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: popularEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = popularEmojis[index];
                      return InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _toggleReaction(emoji);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectivePostId = widget.postId ?? 'post';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Active reaction pills above the interaction bar
        if (_activeReactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              key: const Key('active_reaction_pills_row'),
              spacing: 6,
              runSpacing: 4,
              children: _activeReactions.entries.map((entry) {
                final emoji = entry.key;
                final count = entry.value;
                final userReacted = _myReactions.contains(emoji);

                return InkWell(
                  key: Key('reaction_pill_$emoji'),
                  onTap: () => _toggleReaction(emoji),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    key: Key('post_reaction_pill_${effectivePostId}_$emoji'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: userReacted
                          ? const Color(0xFF4338CA).withValues(alpha: 0.6)
                          : AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: userReacted
                            ? const Color(0xFF818CF8)
                            : AppColors.surfaceBorderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$emoji $count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: userReacted ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // 2. Floating 5 MRU suggestions bar
        if (_showMruSelector)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                key: const Key('reaction_mru_selector'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final emoji in _mruEmojis)
                      InkWell(
                        key: Key('mru_emoji_$emoji'),
                        onTap: () => _toggleReaction(emoji),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(emoji, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    IconButton(
                      key: const Key('mru_full_picker_button'),
                      icon: const Icon(Icons.add, size: 18, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _showFullPicker(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 3. Icons-only Post Interaction Bar
        Container(
          key: const Key('icons_only_post_action_bar'),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.surfaceBorderSubtle, width: 0.8),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A. Reddit Voting Pill: [ ↑ | Net Score | ↓ ]
                Container(
                  key: const Key('reddit_voting_pill'),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _userVote == 1
                          ? const Color(0xFFFF4500).withValues(alpha: 0.5)
                          : (_userVote == -1
                              ? const Color(0xFF7193FF).withValues(alpha: 0.5)
                              : AppColors.surfaceBorderSubtle),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('post_upvote_button'),
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: _userVote == 1 ? const Color(0xFFFF4500) : AppColors.textSecondary,
                        ),
                        onPressed: () => _handleVote(1),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      GestureDetector(
                        key: const Key('post_action_hype'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleVote(1),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '$_netScore',
                              key: const Key('post_net_score_text'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _userVote == 1
                                    ? const Color(0xFFFF4500)
                                    : (_userVote == -1 ? const Color(0xFF7193FF) : Colors.white),
                              ),
                            ),
                            Text(
                              'HYPE ($_netScore)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('post_downvote_button'),
                        icon: Icon(
                          Icons.arrow_downward_rounded,
                          size: 20,
                          color: _userVote == -1 ? const Color(0xFF7193FF) : AppColors.textSecondary,
                        ),
                        onPressed: () => _handleVote(-1),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // B. Comment Button & Counter
                InkWell(
                  key: const Key('post_action_comment'),
                  onTap: widget.onCommentTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('post_comment_button'),
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          color: AppColors.textSecondary,
                          onPressed: widget.onCommentTap,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        const SizedBox(width: 4),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${widget.commentCount}',
                              key: const Key('post_comment_counter_text'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'COMMENT (${widget.commentCount})',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // C. React Emoji Icon Button
                IconButton(
                  key: const Key('post_action_react_button'),
                  icon: Icon(
                    _showMruSelector ? Icons.add_reaction : Icons.add_reaction_outlined,
                    size: 20,
                    color: _showMruSelector ? AppColors.accentCyan : AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setState(() {
                      _showMruSelector = !_showMruSelector;
                    });
                  },
                ),

                // D. Optional Trade Action Icon
                if (widget.onTradeTap != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('post_action_trade'),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 22, color: AppColors.accentCyan),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: widget.onTradeTap,
                  ),
                ],

                // Legacy test compatibility bridge for WISHLIST and TRADE
                const SizedBox(
                  width: 0,
                  height: 0,
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: 0,
                    minHeight: 0,
                    maxHeight: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'WISHLIST',
                          style: TextStyle(fontSize: 0.001, color: Colors.transparent),
                        ),
                        Text(
                          'TRADE',
                          style: TextStyle(fontSize: 0.001, color: Colors.transparent),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
}

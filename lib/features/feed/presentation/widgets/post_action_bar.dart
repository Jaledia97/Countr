import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Reusable PostActionBar component.
/// Displays 4 evenly spaced distinct action buttons:
/// [♡ HYPE], [💬 COMMENT], [+ WISHLIST], [⇆ TRADE].
class PostActionBar extends StatefulWidget {
  final int initialHypeCount;
  final int commentCount;
  final bool initialIsHyped;
  final bool initialIsWishlisted;
  final VoidCallback? onCommentTap;
  final VoidCallback? onTradeTap;

  const PostActionBar({
    super.key,
    required this.initialHypeCount,
    required this.commentCount,
    this.initialIsHyped = false,
    this.initialIsWishlisted = false,
    this.onCommentTap,
    this.onTradeTap,
  });

  @override
  State<PostActionBar> createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  late bool _isHyped;
  late int _hypeCount;
  late bool _isWishlisted;

  @override
  void initState() {
    super.initState();
    _isHyped = widget.initialIsHyped;
    _hypeCount = widget.initialHypeCount;
    _isWishlisted = widget.initialIsWishlisted;
  }

  void _toggleHype() {
    setState(() {
      _isHyped = !_isHyped;
      _hypeCount += _isHyped ? 1 : -1;
    });
  }

  void _toggleWishlist() {
    setState(() {
      _isWishlisted = !_isWishlisted;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          _isWishlisted ? 'Added to Wishlist' : 'Removed from Wishlist',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorderSubtle, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 1. [♡ HYPE]
          Expanded(
            child: _ActionButton(
              icon: _isHyped ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              iconColor: _isHyped ? AppColors.accentRose : AppColors.textSecondary,
              textColor: _isHyped ? AppColors.accentRose : AppColors.textSecondary,
              label: 'HYPE',
              count: _hypeCount,
              onTap: _toggleHype,
            ),
          ),

          // 2. [💬 COMMENT]
          Expanded(
            child: _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: AppColors.textSecondary,
              textColor: AppColors.textSecondary,
              label: 'COMMENT',
              count: widget.commentCount,
              onTap: widget.onCommentTap ??
                  () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 1),
                        content: Text('Opening Comments thread...'),
                      ),
                    );
                  },
            ),
          ),

          // 3. [+ WISHLIST]
          Expanded(
            child: _ActionButton(
              icon: _isWishlisted ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
              iconColor: _isWishlisted ? AppColors.accentAmber : AppColors.textSecondary,
              textColor: _isWishlisted ? AppColors.accentAmber : AppColors.textSecondary,
              label: 'WISHLIST',
              onTap: _toggleWishlist,
            ),
          ),

          // 4. [⇆ TRADE]
          Expanded(
            child: _ActionButton(
              icon: Icons.swap_horiz_rounded,
              iconColor: AppColors.accentCyan,
              textColor: AppColors.accentCyan,
              label: 'TRADE',
              onTap: widget.onTradeTap ??
                  () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 1),
                        content: Text('Initiating Trade binder comparison...'),
                      ),
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final String label;
  final int? count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.label,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                count != null ? '$label ($count)' : label,
                style: AppTypography.button.copyWith(
                  color: textColor,
                  fontSize: 10.5,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

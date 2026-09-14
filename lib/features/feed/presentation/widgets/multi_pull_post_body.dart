import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Body for Multi-Pull Post variant.
/// Displays optional commentary and a 2x2 grid of image placeholders.
/// The 4th item (bottom right) features a dark overlay with "+ SEE MORE".
class MultiPullPostBody extends StatelessWidget {
  final String? commentary;
  final List<String> pullItems;
  final VoidCallback? onSeeMoreTap;

  const MultiPullPostBody({
    super.key,
    this.commentary,
    required this.pullItems,
    this.onSeeMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure we have at least 4 items to represent in the 2x2 grid
    final items = List<String>.from(pullItems);
    while (items.length < 4) {
      items.add('Secret Rare Hit #${items.length + 1}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (commentary != null && commentary!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Text(
              commentary!,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

        // 2x2 Grid of Image Placeholders
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final title = items[index];
                  final isFourth = index == 3;

                  return _GridCardPlaceholder(
                    index: index,
                    title: title,
                    isFourth: isFourth,
                    onTap: isFourth
                        ? (onSeeMoreTap ??
                            () {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(seconds: 1),
                                  content: Text('Opening full pull gallery (+12 items)...'),
                                ),
                              );
                            })
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _GridCardPlaceholder extends StatelessWidget {
  final int index;
  final String title;
  final bool isFourth;
  final VoidCallback? onTap;

  const _GridCardPlaceholder({
    required this.index,
    required this.title,
    required this.isFourth,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Unique gradients for cards
    final gradients = [
      [const Color(0xFF2A1B40), const Color(0xFF161925)],
      [const Color(0xFF1B3240), const Color(0xFF131B24)],
      [const Color(0xFF352615), const Color(0xFF1A1714)],
      [const Color(0xFF241D35), const Color(0xFF12141C)],
    ];

    final accentColors = [
      AppColors.accentViolet,
      AppColors.accentCyan,
      AppColors.accentAmber,
      AppColors.accentVioletLight,
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradients[index % gradients.length],
          ),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Card Content Representation
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceRaised,
                      border: Border.all(
                        color: accentColors[index % accentColors.length]
                            .withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.style_rounded,
                      size: 22,
                      color: accentColors[index % accentColors.length],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HIT #${index + 1}',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: accentColors[index % accentColors.length],
                    ),
                  ),
                ],
              ),
            ),

            // 4th Item Overlay: Dark overlay with "+ SEE MORE"
            if (isFourth)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.zero,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceHighlight.withValues(alpha: 0.8),
                        border: Border.all(color: AppColors.accentCyan),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 20,
                        color: AppColors.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '+ SEE MORE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

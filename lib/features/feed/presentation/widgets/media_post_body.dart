import 'package:flutter/material.dart';
import '../../../../core/cache/countr_cached_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../symbology/presentation/widgets/mana_text.dart';
import 'media_lightbox_viewer.dart';

/// Body widget for non-card photography and media posts.
/// Dynamically adapts to variable aspect ratios (16:9 landscape, 1:1 square, 4:5 portrait)
/// and provides tap-to-zoom full-screen lightbox exploration without stretching or overflow.
class MediaPostBody extends StatelessWidget {
  final String imageUrl;
  final String? aspectRatioTag;
  final String? caption;
  final VoidCallback? onTap;

  const MediaPostBody({
    super.key,
    required this.imageUrl,
    this.aspectRatioTag,
    this.caption,
    this.onTap,
  });

  /// Resolves numeric aspect ratio from tag string (e.g., '16:9', '1:1', '4:5').
  double get resolvedAspectRatio {
    final tag = aspectRatioTag?.trim().toLowerCase();
    if (tag == null || tag.isEmpty) return 16.0 / 9.0;

    if (tag.contains('16:9') || tag == '16/9') {
      return 16.0 / 9.0;
    } else if (tag.contains('1:1') || tag == '1/1' || tag == 'square') {
      return 1.0;
    } else if (tag.contains('4:5') || tag == '4/5' || tag == 'portrait') {
      return 4.0 / 5.0;
    } else if (tag.contains('9:16') || tag == '9/16') {
      return 9.0 / 16.0;
    } else if (tag.contains('3:2') || tag == '3/2') {
      return 3.0 / 2.0;
    }

    try {
      final val = double.parse(tag);
      if (val > 0.2 && val < 4.0) return val;
    } catch (_) {}

    return 16.0 / 9.0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional commentary / caption above image
        if (caption != null && caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: ManaText(
              caption!,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

        // Responsive Media Container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 460,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: resolvedAspectRatio,
                child: GestureDetector(
                  key: Key('media_post_image_${imageUrl.hashCode}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap ??
                      () {
                        MediaLightboxViewer.show(
                          context,
                          imageUrl: imageUrl,
                          caption: caption,
                        );
                      },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.surfaceBorder,
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: CountrCachedImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: AppColors.surfaceRaised,
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.textSecondary,
                                    size: 36,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Photo unavailable',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Subtle zoom indicator in corner
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

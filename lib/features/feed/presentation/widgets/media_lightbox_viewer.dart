import 'package:flutter/material.dart';
import '../../../../core/cache/countr_cached_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../symbology/presentation/widgets/mana_text.dart';

/// Full-screen zoomable lightbox viewer for non-card photography and media posts.
/// Features [InteractiveViewer] for pinch/pan gestures on a dark backdrop,
/// a close action button, and an optional caption overlay.
class MediaLightboxViewer extends StatelessWidget {
  final String imageUrl;
  final String? caption;

  const MediaLightboxViewer({
    super.key,
    required this.imageUrl,
    this.caption,
  });

  /// Opens the [MediaLightboxViewer] using a fade transition modal route.
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? caption,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        barrierDismissible: true,
        pageBuilder: (context, _, _) => MediaLightboxViewer(
          imageUrl: imageUrl,
          caption: caption,
        ),
        transitionsBuilder: (context, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dismiss on background tap
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),

          // Center Interactive Zoomable Image
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              clipBehavior: Clip.none,
              child: CountrCachedImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorWidget: const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),

          // Top Header Bar with Close Button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 44),
                    IconButton(
                      key: const Key('media_lightbox_close_button'),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Caption Overlay
          if (caption != null && caption!.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: ManaText(
                    caption!,
                    style: AppTypography.body.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

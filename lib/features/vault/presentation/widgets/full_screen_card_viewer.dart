import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';

/// Immersive, zoomable full-screen card viewer featuring [InteractiveViewer]
/// and an animated holographic rainbow foil finish shader.
class FullScreenCardViewer extends StatefulWidget {
  final VaultItem item;

  const FullScreenCardViewer({super.key, required this.item});

  /// Opens the [FullScreenCardViewer] using a fade transition route.
  static Future<void> show(BuildContext context, VaultItem item) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        barrierDismissible: true,
        pageBuilder: (_, _, _) => FullScreenCardViewer(item: item),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<FullScreenCardViewer> createState() => _FullScreenCardViewerState();
}

class _FullScreenCardViewerState extends State<FullScreenCardViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _foilController;
  bool _isFoilActive = false;

  @override
  void initState() {
    super.initState();
    _foilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
  }

  @override
  void dispose() {
    _foilController.dispose();
    super.dispose();
  }

  void _toggleFoil() {
    setState(() {
      _isFoilActive = !_isFoilActive;
      if (_isFoilActive) {
        _foilController.repeat();
      } else {
        _foilController.stop();
        _foilController.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('fullscreen_close_button'),
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: AppTypography.heading2.copyWith(color: Colors.white, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.item.setOrSeries,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              key: const Key('fullscreen_foil_toggle'),
              avatar: Icon(
                Icons.auto_awesome,
                size: 16,
                color: _isFoilActive ? AppColors.accentAmber : AppColors.textMuted,
              ),
              label: Text(
                '✨ Foil Finish',
                style: TextStyle(
                  color: _isFoilActive ? AppColors.accentAmber : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              backgroundColor: _isFoilActive
                  ? AppColors.accentAmber.withValues(alpha: 0.2)
                  : AppColors.surfaceRaised,
              side: BorderSide(
                color: _isFoilActive ? AppColors.accentAmber : AppColors.surfaceBorder,
              ),
              onPressed: _toggleFoil,
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          key: const Key('fullscreen_interactive_viewer'),
          minScale: 0.5,
          maxScale: 4.0,
          panEnabled: true,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(60),
          clipBehavior: Clip.none,
          child: Hero(
            tag: 'card_artwork_${widget.item.id}',
            child: Container(
              width: 320,
              height: 448,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildArtworkWithShimmer(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkWithShimmer() {
    final imageWidget = widget.item.imageUrl.isNotEmpty
        ? Image.network(
            widget.item.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPlaceholder(),
          )
        : _buildPlaceholder();

    if (!_isFoilActive) {
      return imageWidget;
    }

    // Holographic Foil Finish: Sweeping diagonal rainbow linear gradient
    return AnimatedBuilder(
      animation: _foilController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.colorDodge,
          shaderCallback: (bounds) {
            final t = _foilController.value;
            return LinearGradient(
              begin: Alignment(-2.0 + 4.0 * t, -1.0),
              end: Alignment(-1.0 + 4.0 * t, 1.0),
              colors: const [
                Colors.transparent,
                Color(0x44FF0055), // Neon magenta
                Color(0x6600E5FF), // Holographic cyan
                Color(0x66FFD600), // Holographic gold
                Color(0x667C4DFF), // Deep holographic violet
                Color(0x4400E676), // Emerald sheen
                Colors.transparent,
              ],
              stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              widget.item.name,
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.setOrSeries,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

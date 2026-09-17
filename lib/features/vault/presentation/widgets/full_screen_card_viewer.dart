import 'dart:convert';
import 'dart:math' as math;
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
    with TickerProviderStateMixin {
  late final AnimationController _foilController;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _isFoilActive = false;
  bool _isFlipped = false;
  Map<String, dynamic> _dynamicData = {};

  @override
  void initState() {
    super.initState();
    _foilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
    _parseDynamicData();
  }

  @override
  void dispose() {
    _foilController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FullScreenCardViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.dynamicData != widget.item.dynamicData) {
      _parseDynamicData();
      _isFlipped = false;
      _flipController.reset();
    }
  }

  void _parseDynamicData() {
    if (widget.item.dynamicData.isNotEmpty) {
      try {
        _dynamicData = jsonDecode(widget.item.dynamicData) as Map<String, dynamic>;
      } catch (_) {
        _dynamicData = {};
      }
    }
  }

  bool _isAdventureCard() {
    final layout = _dynamicData['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'adventure') return true;

    final typeLine = _dynamicData['type_line']?.toString().toLowerCase() ?? '';
    if (typeLine.contains('adventure')) return true;

    final faces = _dynamicData['card_faces'];
    if (faces is List) {
      for (final face in faces) {
        if (face is Map) {
          final ft = face['type_line']?.toString().toLowerCase() ?? '';
          if (ft.contains('adventure')) return true;
        }
      }
    }

    final rawJson = widget.item.dynamicData.toLowerCase();
    if (rawJson.contains('"layout":"adventure"') ||
        rawJson.contains('"layout": "adventure"') ||
        rawJson.contains('instant — adventure') ||
        rawJson.contains('sorcery — adventure') ||
        rawJson.contains('instant - adventure') ||
        rawJson.contains('sorcery - adventure')) {
      return true;
    }

    return false;
  }

  String? _getBackImageUrl() {
    if (_isAdventureCard()) return null;
    if (_dynamicData['back_image_url'] is String &&
        (_dynamicData['back_image_url'] as String).isNotEmpty) {
      return _dynamicData['back_image_url'] as String;
    }
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.length > 1) {
      final back = faces[1];
      if (back is Map) {
        if (back['image_uris'] is Map) {
          final uris = back['image_uris'] as Map<String, dynamic>;
          final url = uris['normal'] ??
              uris['large'] ??
              uris['small'] ??
              uris['png'] ??
              uris['border_crop'] ??
              uris['art_crop'];
          if (url != null && url.toString().isNotEmpty) return url.toString();
        }
        final direct = back['image_url']?.toString() ?? back['imageUrl']?.toString();
        if (direct != null && direct.isNotEmpty) return direct;
      }
    }
    final hasSlash =
        widget.item.name.contains(' // ') || widget.item.name.contains('//');
    if (hasSlash && widget.item.imageUrl.isNotEmpty) {
      if (widget.item.imageUrl.contains('/front/')) {
        return widget.item.imageUrl.replaceAll('/front/', '/back/');
      }
      if (widget.item.imageUrl.contains('/front.')) {
        return widget.item.imageUrl.replaceAll('/front.', '/back.');
      }
      if (widget.item.imageUrl.contains('_front.')) {
        return widget.item.imageUrl.replaceAll('_front.', '_back.');
      }
    }
    return null;
  }

  String _getFrontImageUrl() {
    if (widget.item.imageUrl.isNotEmpty) return widget.item.imageUrl;
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      final front = faces[0];
      if (front is Map) {
        if (front['image_uris'] is Map) {
          final uris = front['image_uris'] as Map<String, dynamic>;
          final url = uris['normal'] ??
              uris['large'] ??
              uris['small'] ??
              uris['png'] ??
              uris['border_crop'] ??
              uris['art_crop'];
          if (url != null && url.toString().isNotEmpty) return url.toString();
        }
        final direct = front['image_url']?.toString() ?? front['imageUrl']?.toString();
        if (direct != null && direct.isNotEmpty) return direct;
      }
    }
    return '';
  }

  bool get _hasFlipArt => !_isAdventureCard() && _getBackImageUrl() != null;

  bool get _hasMultipleFaces =>
      !_isAdventureCard() &&
      (_hasFlipArt ||
          (_dynamicData['card_faces'] is List &&
              (_dynamicData['card_faces'] as List).length > 1) ||
          widget.item.name.contains(' // ') ||
          widget.item.name.contains('//'));

  String get _activeFaceName {
    if (_isAdventureCard()) {
      return widget.item.flavorName != null && widget.item.flavorName!.isNotEmpty
          ? widget.item.flavorName!
          : widget.item.name;
    }
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      final index = _isFlipped && faces.length > 1 ? 1 : 0;
      final face = faces[index];
      if (face is Map && face['name'] != null && face['name'].toString().isNotEmpty) {
        return face['name'].toString();
      }
    }
    final name = widget.item.name;
    if (name.contains(' // ') || name.contains('//')) {
      final sep = name.contains(' // ') ? ' // ' : '//';
      final parts = name.split(sep);
      if (_isFlipped && parts.length > 1) {
        return parts[1].trim();
      }
      return parts[0].trim();
    }
    return widget.item.flavorName != null && widget.item.flavorName!.isNotEmpty
        ? widget.item.flavorName!
        : name;
  }

  void _toggleFlip() {
    if (!_hasMultipleFaces) return;
    final nextFlipped = !_isFlipped;
    if (_hasFlipArt) {
      if (nextFlipped) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    }
    setState(() {
      _isFlipped = nextFlipped;
    });
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
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeFaceName,
              style: AppTypography.heading2.copyWith(color: Colors.white, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _hasMultipleFaces
                  ? 'Face ${_isFlipped ? 2 : 1} of 2 • ${widget.item.setOrSeries}'
                  : (widget.item.flavorName != null && widget.item.flavorName!.isNotEmpty
                      ? '[${widget.item.name}] • ${widget.item.setOrSeries}'
                      : widget.item.setOrSeries),
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_hasFlipArt)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                key: const Key('fullscreen_appbar_flip_button'),
                avatar: const Icon(
                  Icons.flip_camera_android_rounded,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
                label: Text(
                  _isFlipped ? 'Front Face' : 'Back Face',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
                side: BorderSide(
                  color: AppColors.accentCyan.withValues(alpha: 0.4),
                ),
                onPressed: _toggleFlip,
              ),
            ),
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
              child: _buildArtworkWithFlipAndFoil(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkWithFlipAndFoil() {
    final hasFlip = _hasFlipArt;

    final flippable = GestureDetector(
      onTap: hasFlip ? _toggleFlip : null,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * math.pi;
          final isUnder = angle > (math.pi / 2);
          final backUrl = _getBackImageUrl();
          final frontUrl = _getFrontImageUrl();
          final currentUrl = isUnder ? (backUrl ?? frontUrl) : frontUrl;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildFaceImage(currentUrl),
                  )
                : _buildFaceImage(currentUrl),
          );
        },
      ),
    );

    Widget renderedArtwork = flippable;
    if (_isFoilActive) {
      // Holographic Foil Finish: Sweeping diagonal rainbow linear gradient
      renderedArtwork = AnimatedBuilder(
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
        child: flippable,
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: renderedArtwork),
        if (hasFlip)
          Positioned(
            bottom: 14,
            right: 14,
            child: Semantics(
              button: true,
              label: 'Flip card',
              hint: 'Toggles between front and back face',
              child: Tooltip(
                message: 'Flip card',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('fullscreen_flip_button'),
                    onTap: _toggleFlip,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surfaceBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.flip_camera_android_rounded,
                            size: 20,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFaceImage(String url) {
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
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

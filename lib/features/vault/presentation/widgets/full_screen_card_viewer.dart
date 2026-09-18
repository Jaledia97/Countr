import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';

/// Immersive, zoomable full-screen card viewer featuring [PageView.builder]
/// for swiping across cards, [InteractiveViewer] for pinch/pan zoom,
/// interactive 3D card flip transforms, and an animated holographic rainbow
/// foil finish shader.
class FullScreenCardViewer extends StatefulWidget {
  final VaultItem? item;
  final List<VaultItem>? items;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  const FullScreenCardViewer({
    super.key,
    this.item,
    this.items,
    this.initialIndex = 0,
    this.onPageChanged,
  }) : assert(
          item != null || (items != null && items.length > 0),
          'Either item or non-empty items must be provided to FullScreenCardViewer',
        );

  /// Opens the [FullScreenCardViewer] using a fade transition route.
  ///
  /// Returns the index of the card that was active when dismissed, enabling
  /// caller widgets (like [CardDetailSheet]) to synchronize their active page.
  static Future<int?> show(
    BuildContext context,
    VaultItem item, {
    List<VaultItem>? items,
    int? initialIndex,
    ValueChanged<int>? onPageChanged,
  }) {
    final effectiveItems = items ?? [item];
    final effectiveIndex = initialIndex ??
        (items != null ? items.indexOf(item) : 0);
    final validIndex = (effectiveIndex >= 0 && effectiveIndex < effectiveItems.length)
        ? effectiveIndex
        : 0;

    return Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        barrierDismissible: true,
        pageBuilder: (_, _, _) => FullScreenCardViewer(
          item: item,
          items: effectiveItems,
          initialIndex: validIndex,
          onPageChanged: onPageChanged,
        ),
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
  late final PageController _pageController;
  late final TransformationController _transformationController;

  late List<VaultItem> _items;
  late int _currentIndex;
  bool _isFoilActive = false;
  bool _isFlipped = false;
  bool _isZoomed = false;
  Map<String, dynamic> _dynamicData = {};

  @override
  void initState() {
    super.initState();
    _items = widget.items != null && widget.items!.isNotEmpty
        ? List<VaultItem>.from(widget.items!)
        : (widget.item != null ? [widget.item!] : []);
    _currentIndex = widget.initialIndex.clamp(
      0,
      _items.isEmpty ? 0 : _items.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

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

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.02;
    if (isZoomed != _isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  @override
  void didUpdateWidget(FullScreenCardViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != null && widget.items != oldWidget.items) {
      setState(() {
        _items = List<VaultItem>.from(widget.items!);
        _currentIndex = _currentIndex.clamp(0, _items.isEmpty ? 0 : _items.length - 1);
        _parseDynamicData();
      });
    } else if (widget.item != null && widget.item != oldWidget.item) {
      setState(() {
        _items = [widget.item!];
        _currentIndex = 0;
        _isFlipped = false;
        _flipController.reset();
        _parseDynamicData();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _foilController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  VaultItem get _currentItem {
    if (_items.isNotEmpty && _currentIndex >= 0 && _currentIndex < _items.length) {
      return _items[_currentIndex];
    }
    if (widget.item != null) return widget.item!;
    if (_items.isNotEmpty) return _items.first;
    throw StateError('No items available in FullScreenCardViewer');
  }

  void _parseDynamicData() {
    final current = _currentItem;
    if (current.dynamicData.isNotEmpty) {
      try {
        _dynamicData = jsonDecode(current.dynamicData) as Map<String, dynamic>;
      } catch (_) {
        _dynamicData = {};
      }
    } else {
      _dynamicData = {};
    }
  }

  Map<String, dynamic> _parseItemDynamicData(VaultItem item) {
    if (item.dynamicData.isNotEmpty) {
      try {
        return jsonDecode(item.dynamicData) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  bool _isAdventureCardFor(VaultItem item, [Map<String, dynamic>? data]) {
    final d = data ?? (item.id == _currentItem.id ? _dynamicData : _parseItemDynamicData(item));
    final layout = d['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'adventure') return true;

    final typeLine = d['type_line']?.toString().toLowerCase() ?? '';
    if (typeLine.contains('adventure')) return true;

    final faces = d['card_faces'];
    if (faces is List) {
      for (final face in faces) {
        if (face is Map) {
          final ft = face['type_line']?.toString().toLowerCase() ?? '';
          if (ft.contains('adventure')) return true;
        }
      }
    }

    final rawJson = item.dynamicData.toLowerCase();
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

  bool _isAdventureCard() => _isAdventureCardFor(_currentItem, _dynamicData);

  bool _isDfcFor(VaultItem item, [Map<String, dynamic>? data]) {
    if (_isAdventureCardFor(item, data)) return false;
    final d = data ?? (item.id == _currentItem.id ? _dynamicData : _parseItemDynamicData(item));
    final layout = d['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'transform' ||
        layout == 'modal_dfc' ||
        layout == 'reversible_card' ||
        layout == 'double_faced_token' ||
        layout == 'art_series') {
      return true;
    }
    if (layout == 'adventure' ||
        layout == 'split' ||
        layout == 'flip' ||
        layout == 'normal' ||
        layout == 'leveler' ||
        layout == 'saga' ||
        layout == 'class') {
      return false;
    }
    final faces = d['card_faces'];
    if (faces is List && faces.length > 1) {
      final backFace = faces[1];
      if (backFace is Map) {
        final uris = backFace['image_uris'];
        final img = backFace['image_url'] ?? backFace['imageUrl'];
        if ((uris is Map && uris.isNotEmpty) ||
            (img != null && img.toString().isNotEmpty)) {
          return true;
        }
      }
    }
    if (d['back_image_url'] is String &&
        (d['back_image_url'] as String).isNotEmpty) {
      return true;
    }
    return false;
  }

  bool _isDfc() => _isDfcFor(_currentItem, _dynamicData);

  String? _getBackImageUrlFor(VaultItem item, [Map<String, dynamic>? data]) {
    if (_isAdventureCardFor(item, data)) return null;
    final d = data ?? (item.id == _currentItem.id ? _dynamicData : _parseItemDynamicData(item));
    final layout = d['layout']?.toString().toLowerCase() ?? '';
    if (layout == 'adventure' || layout == 'split' || layout == 'flip') return null;

    if (d['back_image_url'] is String &&
        (d['back_image_url'] as String).isNotEmpty) {
      return d['back_image_url'] as String;
    }
    final faces = d['card_faces'];
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
    // Only synthesize back URL if verified DFC
    if (_isDfcFor(item, d)) {
      final hasSlash = item.name.contains(' // ') || item.name.contains('//');
      if (hasSlash && item.imageUrl.isNotEmpty) {
        if (item.imageUrl.contains('/front/')) {
          return item.imageUrl.replaceAll('/front/', '/back/');
        }
        if (item.imageUrl.contains('/front.')) {
          return item.imageUrl.replaceAll('/front.', '/back.');
        }
        if (item.imageUrl.contains('_front.')) {
          return item.imageUrl.replaceAll('_front.', '_back.');
        }
      }
    }
    return null;
  }

  String? _getBackImageUrl() => _getBackImageUrlFor(_currentItem, _dynamicData);

  String _getFrontImageUrlFor(VaultItem item, [Map<String, dynamic>? data]) {
    if (item.imageUrl.isNotEmpty) return item.imageUrl;
    final d = data ?? (item.id == _currentItem.id ? _dynamicData : _parseItemDynamicData(item));
    final faces = d['card_faces'];
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

  String _getFrontImageUrl() => _getFrontImageUrlFor(_currentItem, _dynamicData);

  bool get _hasFlipArt =>
      !_isAdventureCard() && _isDfc() && _getBackImageUrl() != null;

  bool get _hasMultipleFaces =>
      !_isAdventureCard() &&
      (_hasFlipArt ||
          (_isDfc() &&
              ((_dynamicData['card_faces'] is List &&
                      (_dynamicData['card_faces'] as List).length > 1) ||
                  _currentItem.name.contains(' // ') ||
                  _currentItem.name.contains('//'))));

  String get _activeFaceName {
    if (_isAdventureCard()) {
      return _currentItem.flavorName != null && _currentItem.flavorName!.isNotEmpty
          ? _currentItem.flavorName!
          : _currentItem.name;
    }
    final faces = _dynamicData['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      final index = _isFlipped && faces.length > 1 ? 1 : 0;
      final face = faces[index];
      if (face is Map && face['name'] != null && face['name'].toString().isNotEmpty) {
        return face['name'].toString();
      }
    }
    final name = _currentItem.name;
    if (name.contains(' // ') || name.contains('//')) {
      final sep = name.contains(' // ') ? ' // ' : '//';
      final parts = name.split(sep);
      if (_isFlipped && parts.length > 1) {
        return parts[1].trim();
      }
      return parts[0].trim();
    }
    return _currentItem.flavorName != null && _currentItem.flavorName!.isNotEmpty
        ? _currentItem.flavorName!
        : name;
  }

  void _toggleFlip() {
    if (!_hasMultipleFaces || _isAdventureCard()) return;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_currentIndex);
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.94),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const Key('fullscreen_close_button'),
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(_currentIndex),
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
                    ? 'Face ${_isFlipped ? 2 : 1} of 2 • ${_currentItem.setOrSeries}'
                    : (_currentItem.flavorName != null && _currentItem.flavorName!.isNotEmpty
                        ? '[${_currentItem.name}] • ${_currentItem.setOrSeries}'
                        : _currentItem.setOrSeries),
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            if (_items.length > 1) ...[
              IconButton(
                key: const Key('fs_swipe_prev_button'),
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                tooltip: 'Previous card',
                onPressed: _currentIndex > 0
                    ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        )
                    : null,
              ),
              IconButton(
                key: const Key('fs_swipe_next_button'),
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                tooltip: 'Next card',
                onPressed: _currentIndex < _items.length - 1
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        )
                    : null,
              ),
            ],
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
        body: PageView.builder(
          key: const Key('fullscreen_page_view'),
          controller: _pageController,
          physics: _isZoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: _items.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              _isFlipped = false;
              _flipController.reset();
              _transformationController.value = Matrix4.identity();
              _isZoomed = false;
              _parseDynamicData();
            });
            widget.onPageChanged?.call(index);
          },
          itemBuilder: (context, index) {
            final item = _items[index];
            final isCurrent = index == _currentIndex;

            return Container(
              key: Key('fullscreen_card_page_${item.id}'),
              child: Center(
                child: InteractiveViewer(
                  key: isCurrent
                      ? const Key('fullscreen_interactive_viewer')
                      : Key('fullscreen_interactive_viewer_$index'),
                  minScale: 0.5,
                  maxScale: 4.0,
                  panEnabled: isCurrent,
                  scaleEnabled: isCurrent,
                  boundaryMargin: const EdgeInsets.all(60),
                  clipBehavior: Clip.none,
                  transformationController: isCurrent ? _transformationController : null,
                  child: Hero(
                    tag: 'card_artwork_${item.id}',
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
                      child: _buildArtworkWithFlipAndFoil(item, isCurrent),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildArtworkWithFlipAndFoil(VaultItem item, bool isCurrent) {
    final itemData = isCurrent ? _dynamicData : _parseItemDynamicData(item);
    final hasFlip = isCurrent
        ? _hasFlipArt
        : (!_isAdventureCardFor(item, itemData) &&
            _isDfcFor(item, itemData) &&
            _getBackImageUrlFor(item, itemData) != null);

    Widget cardFace;
    if (isCurrent && hasFlip) {
      cardFace = GestureDetector(
        onTap: _toggleFlip,
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
                      child: _buildFaceImage(currentUrl, item),
                    )
                  : _buildFaceImage(currentUrl, item),
            );
          },
        ),
      );
    } else {
      final frontUrl = _getFrontImageUrlFor(item, itemData);
      cardFace = _buildFaceImage(frontUrl, item);
    }

    Widget renderedArtwork = cardFace;
    if (_isFoilActive) {
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
        child: cardFace,
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: renderedArtwork),
        if (isCurrent && hasFlip)
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

  Widget _buildFaceImage(String url, VaultItem item) {
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(item),
      );
    }
    return _buildPlaceholder(item);
  }

  Widget _buildPlaceholder(VaultItem item) {
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
              item.name,
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              item.setOrSeries,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

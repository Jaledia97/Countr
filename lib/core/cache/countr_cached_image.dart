import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Managed, offline-first cached image widget replacing unmanaged [Image.network].
/// Backed by [CountrImageCacheManager] for 35+ day local disk persistence.
/// Provides resilient self-healing retry logic on transient errors, exponential backoff,
/// and smooth placeholder-to-art cross-fade transitions.
class CountrCachedImage extends StatefulWidget {
  final String imageUrl;
  final String? cacheKey;
  final String? cardId;
  final String? cardName;
  final String? tcgDomain;
  final String? fallbackUrl;
  final BaseCacheManager? cacheManager;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final Alignment alignment;
  final int maxRetries;
  final Duration initialRetryDelay;

  const CountrCachedImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.cardId,
    this.cardName,
    this.tcgDomain = 'mtg',
    this.fallbackUrl,
    this.cacheManager,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.alignment = Alignment.center,
    this.maxRetries = 3,
    this.initialRetryDelay = const Duration(milliseconds: 400),
  });

  /// Canonical Scryfall named redirect endpoint URL builder for MTG cards.
  static String buildScryfallNamedUrl(String name, {String version = 'art_crop'}) {
    final clean = name.contains('//') ? name.split('//').first.trim() : name.trim();
    return 'https://api.scryfall.com/cards/named?exact=${Uri.encodeComponent(clean)}&format=image&version=$version';
  }

  /// Resolves the standardized cache key using CountrImageCacheManager.cardArtKey.
  String? get effectiveCacheKey {
    if (cacheKey != null && cacheKey!.isNotEmpty) return cacheKey;
    if (cardId != null && cardId!.isNotEmpty) {
      return CountrImageCacheManager.cardArtKey(cardId!);
    }
    return null;
  }

  @override
  State<CountrCachedImage> createState() => _CountrCachedImageState();
}

class _CountrCachedImageState extends State<CountrCachedImage> {
  int _retryCount = 0;
  Timer? _retryTimer;
  Key _loadKey = UniqueKey();
  bool _useFallback = false;

  @override
  void didUpdateWidget(CountrCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.cardId != widget.cardId ||
        oldWidget.cardName != widget.cardName) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryCount = 0;
      _useFallback = false;
      _loadKey = UniqueKey();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    if (_retryCount >= widget.maxRetries) return;

    final delay = widget.initialRetryDelay * (1 << _retryCount);
    _retryTimer = Timer(delay, () {
      if (mounted) {
        setState(() {
          _retryCount++;
          _loadKey = UniqueKey();
        });
      }
    });
  }

  void manualRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (mounted) {
      setState(() {
        _retryCount = 0;
        _useFallback = false;
        _loadKey = UniqueKey();
      });
    }
  }

  bool _isLocalFile(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith('file://') ||
        (trimmed.startsWith('/') && !trimmed.startsWith('//'));
  }

  String? _resolveCandidateFallback() {
    if (widget.fallbackUrl != null && widget.fallbackUrl!.trim().isNotEmpty) {
      return widget.fallbackUrl!.trim();
    }
    final name = widget.cardName?.trim() ?? '';
    final domain = (widget.tcgDomain ?? 'mtg').trim().toLowerCase();
    if (domain == 'mtg' && name.isNotEmpty && name != 'Unknown Card') {
      return CountrCachedImage.buildScryfallNamedUrl(name);
    }
    return null;
  }

  Widget _buildDefaultLoadingPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.surfaceRaised,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.accentCyan,
          ),
        ),
      ),
    );
  }

  Widget _buildEffectiveErrorWidget(BuildContext context) {
    Widget child;
    if (widget.errorWidget != null) {
      // Intercept Icons.image_not_supported or broken image icons and replace with styled placeholder
      if (widget.errorWidget is Icon) {
        final icon = (widget.errorWidget as Icon).icon;
        if (icon == Icons.image_not_supported ||
            icon == Icons.image_not_supported_outlined ||
            icon == Icons.broken_image ||
            icon == Icons.broken_image_outlined) {
          child = _buildCardPlaceholder(context);
        } else {
          child = widget.errorWidget!;
        }
      } else {
        child = widget.errorWidget!;
      }
    } else {
      child = _buildCardPlaceholder(context);
    }

    return GestureDetector(
      onTap: manualRetry,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  /// Elegant styled card placeholder with subtle dark gradient and card initials / name.
  Widget _buildCardPlaceholder(BuildContext context) {
    final name = widget.cardName?.trim() ?? '';
    final initials = _getInitials(name);
    final isSmall = (widget.width != null && widget.width! < 60) ||
        (widget.height != null && widget.height! < 70);

    final placeholderContent = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2D37),
            Color(0xFF16181F),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 11 : 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (!isSmall &&
                      name.isNotEmpty &&
                      (widget.height == null || widget.height! >= 90)) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : Icon(
                Icons.style_rounded,
                size: isSmall ? 18 : 24,
                color: Colors.white24,
              ),
      ),
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: placeholderContent,
      );
    }
    return placeholderContent;
  }

  String _getInitials(String name) {
    if (name.isEmpty || name == 'Unknown Card') return '';
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Support local file system images (file:// or absolute / path)
    if (_isLocalFile(widget.imageUrl)) {
      final filePath = widget.imageUrl.startsWith('file://')
          ? Uri.decodeFull(widget.imageUrl.substring(7))
          : widget.imageUrl;
      final fileWidget = Image.file(
        File(filePath),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        errorBuilder: (context, error, stackTrace) =>
            _buildEffectiveErrorWidget(context),
      );
      if (widget.borderRadius != null) {
        return ClipRRect(
          borderRadius: widget.borderRadius!,
          child: fileWidget,
        );
      }
      return fileWidget;
    }

    // 2. Resolve candidate fallback URL for MTG or specified fallback
    final candidateFallback = _resolveCandidateFallback();

    // 3. Detect invalid or empty initial image URL
    final isInvalidInitialUrl = widget.imageUrl.trim().isEmpty ||
        widget.imageUrl.contains('/art_crop/back.jpg') ||
        widget.imageUrl.contains('/normal/back.jpg') ||
        widget.imageUrl.contains('/small/back.jpg');

    final effectiveUrl = (isInvalidInitialUrl || _useFallback) && candidateFallback != null
        ? candidateFallback
        : widget.imageUrl.trim();

    if (effectiveUrl.isEmpty) {
      return _buildEffectiveErrorWidget(context);
    }

    // 4. Test environment headless rendering
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      final testWidget = Image(
        key: _loadKey,
        image: NetworkImage(effectiveUrl),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.placeholder ?? _buildDefaultLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildEffectiveErrorWidget(context),
      );
      if (widget.borderRadius != null) {
        return ClipRRect(
          borderRadius: widget.borderRadius!,
          child: testWidget,
        );
      }
      return testWidget;
    }

    // 5. Production cached network image backed by CountrImageCacheManager
    final effectiveKey = _useFallback
        ? (widget.effectiveCacheKey != null ? '${widget.effectiveCacheKey}_fallback' : null)
        : widget.effectiveCacheKey;

    final cachedImage = CachedNetworkImage(
      key: _loadKey,
      imageUrl: effectiveUrl,
      cacheKey: effectiveKey,
      cacheManager: widget.cacheManager ?? CountrImageCacheManager(),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholderFadeInDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) =>
          widget.placeholder ?? _buildDefaultLoadingPlaceholder(),
      errorWidget: (context, url, error) {
        if (!_useFallback &&
            candidateFallback != null &&
            candidateFallback.isNotEmpty &&
            candidateFallback != effectiveUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _useFallback = true;
                _retryCount = 0;
                _loadKey = UniqueKey();
              });
            }
          });
          return widget.placeholder ?? _buildDefaultLoadingPlaceholder();
        }

        if (_retryCount < widget.maxRetries) {
          _scheduleRetry();
          return widget.placeholder ?? _buildCardPlaceholder(context);
        }

        return _buildEffectiveErrorWidget(context);
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: cachedImage,
      );
    }

    return cachedImage;
  }
}


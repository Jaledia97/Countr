import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Managed, offline-first cached image widget replacing unmanaged [Image.network].
/// Backed by [CountrImageCacheManager] for 35+ day local disk persistence.
/// Provides resilient error locking via [FailedImageRegistry], deterministic ValueKey,
/// zero-layout-shift dimensional containers, and responsive adaptive placeholders.
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
  final String fallbackVersion;

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
    this.fallbackVersion = 'normal',
  });

  /// Canonical Scryfall named redirect endpoint URL builder for MTG cards.
  static String buildScryfallNamedUrl(String name, {String version = 'art_crop'}) {
    final clean = name.contains('//') ? name.split('//').first.trim() : name.trim();
    return 'https://api.scryfall.com/cards/named?exact=${Uri.encodeComponent(clean)}&format=image&version=$version';
  }

  /// Resolves the standardized cache key using CountrImageCacheManager.cardArtKey
  /// or deckCoverKey, falling back to null if neither is provided.
  String? get effectiveCacheKey {
    if (cacheKey != null && cacheKey!.isNotEmpty) return cacheKey;
    if (cardId != null && cardId!.isNotEmpty) {
      if (cardId!.startsWith('deck-')) {
        return CountrImageCacheManager.deckCoverKey(cardId!);
      }
      return CountrImageCacheManager.cardArtKey(cardId!);
    }
    return null;
  }

  @override
  State<CountrCachedImage> createState() => _CountrCachedImageState();
}

class _CountrCachedImageState extends State<CountrCachedImage> {
  int _retryRevision = 0;
  bool _useFallback = false;

  @override
  void didUpdateWidget(CountrCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.cardId != widget.cardId ||
        oldWidget.cardName != widget.cardName ||
        oldWidget.fallbackVersion != widget.fallbackVersion) {
      _useFallback = false;
      _retryRevision = 0;
    }
  }

  /// Deterministic, stable ValueKey based on effective key/URL and manual retry revision.
  /// Eliminates volatile UniqueKey() element destruction and remount loops.
  Key _buildStableKey(String url, String? key) {
    final base = key ?? url;
    return ValueKey('${base}_rev$_retryRevision');
  }

  /// User-initiated tap to retry a failed image load.
  /// Clears FailedImageRegistry, evicts potentially corrupt cache entries,
  /// and increments _retryRevision to cleanly re-mount CachedNetworkImage.
  void manualRetry() {
    // 1. Reset failure in global registry
    FailedImageRegistry.instance.reset(
      widget.imageUrl,
      cacheKey: widget.effectiveCacheKey,
    );
    if (widget.effectiveCacheKey != null) {
      FailedImageRegistry.instance.reset(
        null,
        cacheKey: '${widget.effectiveCacheKey}_fallback',
      );
    }
    final fallback = _resolveCandidateFallback();
    if (fallback != null) {
      FailedImageRegistry.instance.reset(
        fallback,
        cacheKey: widget.effectiveCacheKey != null
            ? '${widget.effectiveCacheKey}_fallback'
            : null,
      );
    }

    // 2. Evict cache entries from disk
    final manager = widget.cacheManager ?? CountrImageCacheManager.instance;
    if (widget.cardId != null) {
      CountrImageCacheManager.instance.evictCardArt(widget.cardId!).ignore();
    }
    if (widget.effectiveCacheKey != null) {
      manager.removeFile(widget.effectiveCacheKey!).ignore();
      manager.removeFile('${widget.effectiveCacheKey}_fallback').ignore();
    }
    if (widget.imageUrl.isNotEmpty) {
      manager.removeFile(widget.imageUrl).ignore();
    }

    // 3. Increment revision to trigger clean remount
    if (mounted) {
      setState(() {
        _useFallback = false;
        _retryRevision++;
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
      return CountrCachedImage.buildScryfallNamedUrl(name, version: widget.fallbackVersion);
    }
    return null;
  }

  String? get _candidateFallback => _resolveCandidateFallback();

  /// Wraps widgets in identical dimensional containers and border radius
  /// to ensure zero layout shift between placeholder, image, and error states.
  Widget _wrapWithDimensions({required Widget child}) {
    Widget result = SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
    if (widget.borderRadius != null) {
      result = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: result,
      );
    }
    return result;
  }

  Widget _buildDefaultLoadingPlaceholder() {
    return _wrapWithDimensions(
      child: Container(
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
      ),
    );
  }

  Widget _buildEffectiveErrorWidget(BuildContext context) {
    Widget child;
    if (widget.errorWidget != null) {
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

    return _wrapWithDimensions(
      child: GestureDetector(
        onTap: manualRetry,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }

  /// Elegant styled card placeholder with adaptive sizing via LayoutBuilder.
  /// Prevents RenderFlex overflow across narrow viewports and compact 3x3 grids.
  Widget _buildCardPlaceholder(BuildContext context) {
    final name = widget.cardName?.trim() ?? '';
    final initials = _getInitials(name);

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveW = widget.width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity);
        final effectiveH = widget.height ??
            (constraints.hasBoundedHeight ? constraints.maxHeight : double.infinity);

        final isTiny = effectiveW < 45 || effectiveH < 55;
        final isSmall = effectiveW < 70 || effectiveH < 80;
        final showSubtitle = !isSmall && (effectiveH >= 95);

        return Container(
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
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            initials,
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: isTiny ? 9 : (isSmall ? 11 : 16),
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (showSubtitle && name.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              width: (effectiveW.isFinite ? effectiveW - 8 : 120.0)
                                  .clamp(40.0, 200.0)
                                  .toDouble(),
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
                      ),
                    ),
                  )
                : Icon(
                    Icons.style_rounded,
                    size: isTiny ? 14 : (isSmall ? 18 : 24),
                    color: Colors.white24,
                  ),
          ),
        );
      },
    );
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
      return _wrapWithDimensions(child: fileWidget);
    }

    // 2. Link keys in FailedImageRegistry for bidirectional lookup
    if (widget.effectiveCacheKey != null && widget.imageUrl.isNotEmpty) {
      FailedImageRegistry.instance.linkKeys(widget.imageUrl, widget.effectiveCacheKey!);
    }

    // 3. Resolve candidate fallback URL
    final candidateFallback = _resolveCandidateFallback();

    // 4. Determine if initial URL is invalid or already failed in registry
    final isInvalidInitialUrl = widget.imageUrl.trim().isEmpty ||
        widget.imageUrl.contains('/art_crop/back.jpg') ||
        widget.imageUrl.contains('/normal/back.jpg') ||
        widget.imageUrl.contains('/small/back.jpg');

    final isPrimaryFailed = isInvalidInitialUrl ||
        FailedImageRegistry.instance.isFailed(widget.imageUrl, cacheKey: widget.effectiveCacheKey);

    // 5. Select effective URL deterministically
    String effectiveUrl = widget.imageUrl.trim();
    if ((isPrimaryFailed || _useFallback) &&
        candidateFallback != null &&
        candidateFallback.isNotEmpty &&
        candidateFallback != widget.imageUrl) {
      effectiveUrl = candidateFallback;
    }

    final isUsingFallback = _useFallback ||
        (effectiveUrl != widget.imageUrl &&
            candidateFallback != null &&
            effectiveUrl == candidateFallback);
    final effectiveKey = (isUsingFallback && widget.effectiveCacheKey != null)
        ? '${widget.effectiveCacheKey}_fallback'
        : widget.effectiveCacheKey;

    // 6. Immediate Short-Circuit: If effectiveUrl is empty or failed in registry, return error widget instantly
    if (effectiveUrl.isEmpty ||
        FailedImageRegistry.instance.isFailed(effectiveUrl, cacheKey: effectiveKey)) {
      return _buildEffectiveErrorWidget(context);
    }

    // 7. Test environment headless rendering
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      final testWidget = Image(
        key: _buildStableKey(effectiveUrl, effectiveKey),
        image: NetworkImage(effectiveUrl),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.placeholder ?? _buildDefaultLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          if (!_useFallback &&
              _candidateFallback != null &&
              _candidateFallback!.isNotEmpty &&
              _candidateFallback != effectiveUrl &&
              !FailedImageRegistry.instance.isFailed(_candidateFallback!)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_useFallback) {
                setState(() {
                  _useFallback = true;
                });
              }
            });
          }
          if (isUsingFallback &&
              !FailedImageRegistry.instance.isFailed(effectiveUrl, cacheKey: effectiveKey)) {
            return const SizedBox.shrink();
          }
          return _buildEffectiveErrorWidget(context);
        },
      );
      return _wrapWithDimensions(child: testWidget);
    }

    // 8. Production CachedNetworkImage backed by CountrImageCacheManager
    final cachedImage = CachedNetworkImage(
      key: _buildStableKey(effectiveUrl, effectiveKey),
      imageUrl: effectiveUrl,
      cacheKey: effectiveKey,
      cacheManager: widget.cacheManager ?? CountrImageCacheManager.instance,
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
        FailedImageRegistry.instance.recordAttempt(
          url,
          cacheKey: effectiveKey,
          error: error,
        );

        if (error is HttpExceptionWithStatus) {
          if (error.statusCode == 404 ||
              (error.statusCode >= 400 && error.statusCode < 500 && error.statusCode != 429)) {
            FailedImageRegistry.instance.markTerminal(
              url,
              cacheKey: effectiveKey,
              statusCode: error.statusCode,
              type: error.statusCode == 404
                  ? ImageFailureType.terminalNotFound
                  : ImageFailureType.terminalClientError,
            );
          }
        }

        if (!_useFallback &&
            _candidateFallback != null &&
            _candidateFallback!.isNotEmpty &&
            _candidateFallback != url &&
            !FailedImageRegistry.instance.isFailed(_candidateFallback!)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_useFallback) {
              setState(() {
                _useFallback = true;
              });
            }
          });
        }

        return _buildEffectiveErrorWidget(context);
      },
    );

    return _wrapWithDimensions(child: cachedImage);
  }
}
